// SPDX-License-Identifier: AGPL-3.0-only

using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace CouchSubs.Translation;

/// <summary>
/// Marian kodlayıcı/kod çözücüsünü ONNX Runtime (CPU) ile çalıştırır: açgözlü kod çözme, KV önbellekli.
/// Birleşik kod çözücü (decoder_model_merged) ilk adımda çapraz dikkat anahtarlarını üretir,
/// sonraki adımlarda yalnızca yeni belirteci işler (use_cache_branch).
/// </summary>
internal sealed class OnnxMarianEngine : ISentenceEngine
{
    public static readonly string[] RequiredFiles =
        [ModelStore.EncoderFile, ModelStore.DecoderFile, ModelStore.SourceSpmFile, ModelStore.VocabFile];

    /// <summary>tc-big en-tr tek hedef dilli; dil belirteci gerekmez, kod çözme &lt;pad&gt; ile başlar.</summary>
    private const int DecoderStartId = MarianTokenizer.PadId;
    private const int HeadCount = 16;
    private const int HeadSize = 64;
    /// <summary>Çok uzun girdi kesilir; altyazı cümlesi bunun çok altında kalır.</summary>
    private const int MaxInputTokens = 256;

    private readonly MarianTokenizer _tokenizer;
    private readonly InferenceSession _encoder;
    private readonly InferenceSession _decoder;
    private readonly int _maxOutputTokens;
    private readonly string[] _pastNames;
    private readonly string[] _decoderInputNames;
    private readonly string[] _decoderOutputNames;
    /// <summary>Her present çıktısının hangi past girdisine döndüğü; kodlayıcı kısımları yalnızca ilk adımda alınır.</summary>
    private readonly bool[] _isSelfAttention;

    public OnnxMarianEngine(string modelDirectory, int maxOutputTokens)
    {
        _maxOutputTokens = maxOutputTokens;
        _tokenizer = MarianTokenizer.Load(
            Path.Combine(modelDirectory, ModelStore.SourceSpmFile), Path.Combine(modelDirectory, ModelStore.VocabFile));

        using var options = new SessionOptions
        {
            GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
            ExecutionMode = ExecutionMode.ORT_SEQUENTIAL,
        };
        // Bellek havuzunu ya da ağırlık ön paketlemeyi kapatmak denendi: yüklemede bellek düşse de
        // çeviriler başladıktan sonra bellek artıyor, satır süresi de %20'ye kadar uzuyordu. Varsayılanlar kalır.
        _encoder = new InferenceSession(Path.Combine(modelDirectory, ModelStore.EncoderFile), options);
        try
        {
            _decoder = new InferenceSession(Path.Combine(modelDirectory, ModelStore.DecoderFile), options);
        }
        catch
        {
            _encoder.Dispose();
            throw;
        }

        _pastNames = _decoder.InputNames.Where(n => n.StartsWith("past_key_values.", StringComparison.Ordinal)).ToArray();
        _decoderInputNames = ["input_ids", "encoder_attention_mask", "encoder_hidden_states", "use_cache_branch", .. _pastNames];
        _decoderOutputNames = ["logits", .. _pastNames.Select(n => "present." + n["past_key_values.".Length..])];
        _isSelfAttention = _pastNames.Select(n => n.EndsWith(".decoder.key", StringComparison.Ordinal) ||
                                                  n.EndsWith(".decoder.value", StringComparison.Ordinal)).ToArray();
    }

    public string Translate(string sentence, CancellationToken cancellationToken)
    {
        var ids = _tokenizer.Encode(sentence);
        if (ids.Length > MaxInputTokens)
        {
            ids = ids[..MaxInputTokens];
            ids[^1] = MarianTokenizer.EosId;
        }
        var output = Generate(ids, cancellationToken);
        return _tokenizer.Decode(output);
    }

    private List<int> Generate(int[] sourceIds, CancellationToken cancellationToken)
    {
        var length = sourceIds.Length;
        var inputIds = sourceIds.Select(i => (long)i).ToArray();
        var mask = Enumerable.Repeat(1L, length).ToArray();
        long[] sourceShape = [1, length];

        using var inputValue = OrtValue.CreateTensorValueFromMemory(inputIds, sourceShape);
        using var maskValue = OrtValue.CreateTensorValueFromMemory(mask, sourceShape);
        using var runOptions = new RunOptions();
        using var encoderOutputs = _encoder.Run(runOptions, ["input_ids", "attention_mask"], [inputValue, maskValue],
            ["last_hidden_state"]);
        var hidden = encoderOutputs[0];

        var past = new OrtValue[_pastNames.Length];
        for (var i = 0; i < past.Length; i++)
            past[i] = OrtValue.CreateAllocatedTensorValue(OrtAllocator.DefaultInstance, TensorElementType.Float,
                [1, HeadCount, 0, HeadSize]);

        var result = new List<int>();
        var token = new long[1];
        var useCache = new bool[1];
        // Türkçe çıktı İngilizce girdiden biraz uzun olur; sınır döngüye giren çözmeyi keser.
        var limit = Math.Min(_maxOutputTokens, 2 * length + 16);
        try
        {
            token[0] = DecoderStartId;
            for (var step = 0; step < limit; step++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                useCache[0] = step > 0;
                using var tokenValue = OrtValue.CreateTensorValueFromMemory(token, [1, 1]);
                using var cacheValue = OrtValue.CreateTensorValueFromMemory(useCache, [1]);
                OrtValue[] inputs = [tokenValue, maskValue, hidden, cacheValue, .. past];
                // Çıktılar tek tek sahiplenilir: present değerleri bir sonraki adımın past girdisi olur.
                var outputs = _decoder.Run(runOptions, _decoderInputNames, inputs, _decoderOutputNames);
                int next;
                using (var logits = outputs[0])
                    next = ArgMax(logits.GetTensorDataAsSpan<float>());
                for (var i = 0; i < past.Length; i++)
                {
                    var present = outputs[i + 1];
                    if (step == 0 || _isSelfAttention[i])
                    {
                        past[i].Dispose();
                        past[i] = present;
                    }
                    else
                    {
                        present.Dispose();
                    }
                }
                if (next == MarianTokenizer.EosId) break;
                result.Add(next);
                token[0] = next;
            }
        }
        finally
        {
            foreach (var value in past) value.Dispose();
        }
        return result;
    }

    /// <summary>En olası belirteç; &lt;pad&gt; hiçbir zaman üretilmez (modelin bad_words_ids ayarı).</summary>
    private static int ArgMax(ReadOnlySpan<float> logits)
    {
        var best = 0;
        var bestValue = float.NegativeInfinity;
        for (var i = 0; i < logits.Length; i++)
        {
            if (i == MarianTokenizer.PadId) continue;
            if (logits[i] > bestValue)
            {
                bestValue = logits[i];
                best = i;
            }
        }
        return best;
    }

    public void Dispose()
    {
        _decoder.Dispose();
        _encoder.Dispose();
    }
}
