// SPDX-License-Identifier: AGPL-3.0-only

namespace CouchSubs.Core;

/// <summary>Kare → bölge → yazı tanıma → kararlılık → çeviri → TV.</summary>
public sealed class SubtitlePipeline(ITextReader reader, ITextTranslator translator, ISubtitleSender sender)
{
    private readonly object gate = new();
    /// <summary>Kareler saniyede ~15 kez okunur; yaklaşık 0,3 sn boş kalan bölge altyazının kalktığı anlamına gelir.</summary>
    private readonly SubtitleStabilizer stabilizer = new(emptyFramesToClear: 4);
    private readonly Dictionary<int, Task> translations = [];
    /// <summary>
    /// Her çeviri isteği sıra numarası alır. Hızlı konuşmada çeviriler sırasız dönebilir:
    /// daha yeni bir satırın çevirisi gösterilmediyse eski satırınki yine gösterilir.
    /// </summary>
    private int lastRequested;
    private int lastShown;
    /// <summary>Şu an oyun ekranında duran satırın numarası (bölge boşalınca null).</summary>
    private int? lineOnScreen;
    /// <summary>Okuma durdurulunca artar; önceki oturumdan dönen çeviriler gösterilmez.</summary>
    private int session;

    public (string Source, string Translation)? LastPair { get; private set; }
    public TranslatorStatus? LastError { get; private set; }

    /// <summary>Yeni çeviri gösterilince çağrılır (kaynak, çeviri).</summary>
    public event Action<string, string>? PairShown;
    /// <summary>Her çeviri denemesinden sonra çağrılır (başarılıysa null).</summary>
    public event Action<TranslatorStatus?>? TranslationResult;

    /// <summary>Okuma çeviriyi beklemez; böylece çeviri sürerken gelen satırlar da yakalanır.</summary>
    public async Task ProcessAsync(Frame frame, CropRegion region)
    {
        // Yazı tanıma uzun sürebilir; çağıranı (arayüzü) bekletmemek için iş parçacığı havuzunda yapılır.
        var text = await Task.Run(() =>
        {
            try { return reader.Read(RegionCropper.Crop(frame, region)); }
            catch { return ""; }
        });

        lock (gate)
        {
            var action = stabilizer.Feed(text);
            switch (action.Kind)
            {
                case StabilizerKind.Clear:
                    lineOnScreen = null;
                    sender.Clear();
                    break;
                case StabilizerKind.Translate:
                    var number = ++lastRequested;
                    var current = session;
                    lineOnScreen = number;
                    translations[number] = Task.Run(async () =>
                    {
                        await Translate(action.Text!, number, current);
                        lock (gate) translations.Remove(number);
                    });
                    break;
            }
        }
    }

    /// <summary>Süren bütün çevirilerin bitmesini bekler.</summary>
    public async Task WaitForTranslationsAsync()
    {
        while (true)
        {
            Task[] pending;
            lock (gate) pending = [.. translations.Values];
            if (pending.Length == 0) return;
            await Task.WhenAll(pending);
        }
    }

    /// <summary>Satır ekrandan kalktıktan sonra gelen çevirinin TV'de kalacağı süre (TV uygulamasıyla aynı kural).</summary>
    public static int ReadingTime(string text) => Math.Min(8000, 2000 + (text.Length * 60));

    private async Task Translate(string source, int number, int current)
    {
        string translated;
        try
        {
            translated = await translator.TranslateAsync(source);
        }
        catch (Exception error)
        {
            lock (gate)
            {
                if (current != session) return;
                // Model eksikse ya da geçici bir hata olduysa satır ekranda kaldıkça yeniden denenir.
                LastError = (error as TranslatorException)?.Status;
                if (number == lineOnScreen) stabilizer.ForgetSent();
            }
            TranslationResult?.Invoke(LastError);
            return;
        }

        lock (gate)
        {
            if (current != session) return;
            LastError = null;
        }
        TranslationResult?.Invoke(null);

        lock (gate)
        {
            if (number <= lastShown || !stabilizer.ShouldSend(source, translated)) return;
            lastShown = number;
            // Satır hâlâ ekrandaysa kalkınca silinir; kalktıysa okunacak kadar gösterilir.
            sender.SendSubtitle(translated, number == lineOnScreen ? 15000 : ReadingTime(translated));
            LastPair = (source, translated);
        }
        PairShown?.Invoke(source, translated);
    }

    /// <summary>Okuma durunca TV'deki son altyazıyı kaldırır.</summary>
    public void Reset()
    {
        lock (gate)
        {
            session++;
            lineOnScreen = null;
            if (stabilizer.Reset() == StabilizerAction.Clear) sender.Clear();
        }
    }
}
