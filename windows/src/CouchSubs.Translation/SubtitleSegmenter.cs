// SPDX-License-Identifier: AGPL-3.0-only

using System.Text;
using System.Text.RegularExpressions;

namespace CouchSubs.Translation;

/// <summary>
/// Altyazıyı modele cümle cümle verir. Denemede bütün metin tek seferde çevrilince model kısa cümleleri
/// ("Boy!", "What is that?") ve ikinci satırı sık sık düşürdü; cümle başına çeviri hiçbirini kaybetmedi.
/// Konuşmacı etiketi ("ATREUS:") ve diyalog tirelerine dokunulmaz, çünkü model onları siliyor.
/// </summary>
internal static partial class SubtitleSegmenter
{
    /// <summary>Çevrilecek bir parça ya da olduğu gibi kalacak ayraç/etiket.</summary>
    internal readonly record struct Piece(string Text, bool Translate);

    // Etiket: satır ya da cümle başında, en az iki büyük harfli ad ve iki nokta.
    [GeneratedRegex(@"^(?<label>\p{Lu}[\p{Lu}\d'’.\-]+(?:[ ]\p{Lu}[\p{Lu}\d'’.\-]*){0,2}:)\s+")]
    private static partial Regex SpeakerLabel();

    [GeneratedRegex(@"^(?<dash>[-–—]+)\s*")]
    private static partial Regex DialogueDash();

    // Cümle sonu: . ! ? … (yinelenebilir), ardından isteğe bağlı kapanış tırnağı/parantez ve boşluk.
    [GeneratedRegex(@"(?<=[.!?…]+[""'”’)\]]*)\s+")]
    private static partial Regex SentenceGap();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();

    /// <summary>Noktadan sonra cümle bitmeyen kısaltmalar ("Mr. Smith").</summary>
    private static readonly HashSet<string> Abbreviations = new(StringComparer.OrdinalIgnoreCase)
    {
        "mr", "mrs", "ms", "dr", "st", "jr", "sr", "prof", "mt", "vs", "etc", "e.g", "i.e", "lt", "sgt", "capt", "gen", "col",
    };

    public static List<Piece> Split(string text)
    {
        var pieces = new List<Piece>();
        var lines = text.Replace("\r\n", "\n").Split('\n');
        var block = new StringBuilder();
        var pendingSeparator = "";

        void FlushBlock()
        {
            if (block.Length == 0) return;
            if (pendingSeparator.Length > 0) pieces.Add(new Piece(pendingSeparator, false));
            AddBlock(pieces, block.ToString());
            block.Clear();
            pendingSeparator = "\n";
        }

        foreach (var raw in lines)
        {
            var line = raw.Trim();
            if (line.Length == 0) continue;
            // Etiketli ya da tireli satır yeni bir konuşmadır; diğer satırlar sarmadır, birleştirilir.
            if (SpeakerLabel().IsMatch(line) || DialogueDash().IsMatch(line)) FlushBlock();
            if (block.Length > 0) block.Append(' ');
            block.Append(line);
        }
        FlushBlock();
        return pieces;
    }

    private static void AddBlock(List<Piece> pieces, string block)
    {
        block = Whitespace().Replace(block, " ");
        var dash = DialogueDash().Match(block);
        if (dash.Success)
        {
            pieces.Add(new Piece(dash.Groups["dash"].Value + " ", false));
            block = block[dash.Length..];
        }

        var first = true;
        foreach (var sentence in SplitSentences(block))
        {
            if (!first) pieces.Add(new Piece(" ", false));
            first = false;
            var body = sentence;
            var label = SpeakerLabel().Match(body);
            if (label.Success)
            {
                pieces.Add(new Piece(label.Groups["label"].Value + " ", false));
                body = body[label.Length..];
            }
            if (body.Length > 0) pieces.Add(new Piece(body, HasLetter(body)));
        }
    }

    private static IEnumerable<string> SplitSentences(string block)
    {
        var start = 0;
        foreach (Match gap in SentenceGap().Matches(block))
        {
            var candidate = block[start..gap.Index];
            var next = gap.Index + gap.Length < block.Length ? block[gap.Index + gap.Length] : '\0';
            // "wait... what" gibi küçük harfle süren yer ve kısaltmalar cümle sonu değildir.
            if (char.IsLower(next) || EndsWithAbbreviation(candidate)) continue;
            yield return candidate;
            start = gap.Index + gap.Length;
        }
        if (start < block.Length) yield return block[start..];
    }

    private static bool EndsWithAbbreviation(string sentence)
    {
        if (!sentence.EndsWith('.')) return false;
        var lastSpace = sentence.LastIndexOf(' ');
        var word = sentence[(lastSpace + 1)..^1];
        // Tek harf ad baş harfidir ("J. R. R.").
        return (word.Length == 1 && char.IsUpper(word[0])) || Abbreviations.Contains(word);
    }

    /// <summary>
    /// Tümü büyük harfli cümleyi ("THE GATE WILL NOT HOLD.") cümle düzenine çevirir; model büyük harfli
    /// sözcükleri ad sanıp çevirmeden bırakıyordu ("GATE daha fazla dayanamaz"). Tek sözcüğe dokunulmaz.
    /// </summary>
    public static string NormalizeCase(string sentence)
    {
        var letters = 0;
        foreach (var c in sentence)
        {
            if (char.IsLower(c)) return sentence;
            if (char.IsLetter(c)) letters++;
        }
        if (letters < 2 || !sentence.Trim().Contains(' ')) return sentence;

        var chars = sentence.ToLowerInvariant().ToCharArray();
        var startOfSentence = true;
        for (var i = 0; i < chars.Length; i++)
        {
            if (char.IsLetter(chars[i]))
            {
                // İngilizcede "I" her zaman büyük.
                var standaloneI = chars[i] == 'i' && (i == 0 || !char.IsLetter(chars[i - 1])) &&
                                  (i + 1 == chars.Length || !char.IsLetter(chars[i + 1]));
                if (startOfSentence || standaloneI) chars[i] = char.ToUpperInvariant(chars[i]);
                startOfSentence = false;
            }
            else if (chars[i] is '.' or '!' or '?' or '…')
            {
                startOfSentence = true;
            }
        }
        return new string(chars);
    }

    /// <summary>Harfsiz parça ("...", "?!", "3") modele gitmez; olduğu gibi kalır.</summary>
    private static bool HasLetter(string text)
    {
        foreach (var c in text)
            if (char.IsLetter(c)) return true;
        return false;
    }
}
