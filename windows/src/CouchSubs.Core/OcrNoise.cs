// SPDX-License-Identifier: AGPL-3.0-only

using System.Globalization;
using System.Text.RegularExpressions;

namespace CouchSubs.Core;

/// <summary>
/// Süslü yazı tiplerinde, solan ya da titreyen altyazıda yazı tanıma bazı sözcükleri harf, rakam ve simge
/// karışımı çöpe çevirir ("ou$3e", "waters2aljd"). Bunlar hiçbir dilde sözcük değildir; çevirmen onları
/// olduğu gibi taşır. Sözcük ortasında simge ya da harflerle rakamların iç içe geçtiği parçalar atılır;
/// gerçek bir sözcüğe yapışmış çöp ("waters2aljd") sözcükten ayrılır. "PS5", "R2", "2nd", "100m", "$500"
/// gibi olağan biçimler korunur (Mac'teki OcrNoise ile aynı kurallar).
/// </summary>
public static partial class OcrNoise
{
    private const string Symbols = "$@#%^*_=|\\~<>{}¢£¥§©®°±µ¶¤";

    public static string Clean(string line)
    {
        var kept = new List<string>();
        foreach (var token in line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries))
        {
            var (lead, core, trail) = Split(token);
            if (CleanCore(core) is { } fixedCore)
                kept.Add(lead + fixedCore + trail);
            else if (trail.Length > 0 && kept.Count > 0)
                // Atılan çöpün ardındaki noktalama cümleye aittir ("ou$3e," → virgül kalır).
                kept[^1] += trail;
        }
        return string.Join(' ', kept);
    }

    /// <summary>Sözcüğün kendisi; null ise tamamen çöptür.</summary>
    private static string? CleanCore(string core)
    {
        var letters = core.Count(char.IsLetter);
        var digits = core.Count(char.IsNumber);
        var hasSymbol = core.Any(c => Symbols.Contains(c));
        if (letters == 0) return core;  // "24", "$500", "…"
        if (!hasSymbol && digits == 0) return core;
        if (!hasSymbol && IsUsualMix(core)) return core;
        // Gerçek sözcüğe yapışmış çöp: baştaki en az 3 harf korunur ("waters2aljd" → "waters").
        var prefix = new string(core.TakeWhile(c => char.IsLetter(c) || c is '\'' or '’' or '-').ToArray());
        return prefix.Count(char.IsLetter) >= 3 ? prefix : null;
    }

    /// <summary>"PS5", "R2", "MK2", "2nd", "100m", "4K", "60fps", "x2", "1980s", "R2-D2": olağan harf-rakam karışımları.</summary>
    private static bool IsUsualMix(string core) =>
        core.Split('-').All(part => !part.Any(char.IsNumber) || Usual().IsMatch(part));

    [GeneratedRegex(@"^(?:[A-Za-z]{1,4}\d{1,4}|\d+(?:st|nd|rd|th|s|k|K|m|km|kg|cm|mm|p|x|fps|hp|HP|XP|xp|v|V|D|d)|[xX]\d{1,3}|\d+[.,]\d+[A-Za-z]{0,3}|\d{1,2}[:.]\d{2}(?:am|pm|AM|PM)?)$")]
    private static partial Regex Usual();

    private static bool IsEdge(char c) =>
        !Symbols.Contains(c) && (char.IsPunctuation(c) || char.IsSymbol(c) || "\"'“”‘’«»()[]".Contains(c));

    private static (string Lead, string Core, string Trail) Split(string token)
    {
        int start = 0, end = token.Length;
        while (start < end && IsEdge(token[start])) start++;
        while (end > start && IsEdge(token[end - 1])) end--;
        return (token[..start], token[start..end], token[end..]);
    }
}
