// SPDX-License-Identifier: AGPL-3.0-only

using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using CouchSubs.Core;
using CouchSubs.Core.Dubbing;

namespace CouchSubs.Translation;

/// <summary>
/// İsteğe bağlı çevrimiçi çeviri: kullanıcının kendi Anthropic (Claude) anahtarıyla. Ayarlardaki çevrimiçi
/// çeviri anahtarı "sk-ant-" ile başlıyorsa DeepL yerine bu kullanılır. Önceki altyazı bağlam olarak gider.
/// Claude'a ulaşılamazsa o satır cihaz üstü modelle çevrilir; oyun hiç altyazısız kalmaz.
/// </summary>
public sealed class ClaudeTranslator : ITextTranslator
{
    /// <summary>Hızlı ve ucuz model; oyun altyazısı için yeterli.</summary>
    public const string Model = "claude-haiku-5-5";

    private const int CacheLimit = 4096;
    private static readonly TimeSpan RetryAfter = TimeSpan.FromMinutes(1);
    private static readonly Uri Endpoint = new("https://api.anthropic.com/v1/messages");
    private static readonly Lazy<HttpClient> SharedClient = new(() => new HttpClient { Timeout = TimeSpan.FromSeconds(6) });

    private const string SystemPrompt =
        "You translate English video game subtitles into natural, informal Turkish (use \"sen\", not \"siz\"). " +
        "Reply with the Turkish translation only: no quotes, no notes, no explanations. " +
        "Keep speaker labels such as \"LUCIA:\" and all character, place and brand names unchanged. " +
        "Keep line breaks. Slang and swearing should sound natural in Turkish.";

    private readonly string _key;
    private readonly ITextTranslator? _fallback;
    private readonly HttpClient _http;
    private readonly ConcurrentDictionary<string, string> _cache = new(StringComparer.Ordinal);
    private string? _previous;
    private DateTimeOffset _pausedUntil = DateTimeOffset.MinValue;

    public ClaudeTranslator(string key, ITextTranslator? fallback, HttpClient? http = null)
    {
        _key = key.Trim();
        _fallback = fallback;
        _http = http ?? SharedClient.Value;
    }

    /// <summary>Anthropic anahtarları bu önekle başlar.</summary>
    public static bool IsClaudeKey(string? key) => key?.Trim().StartsWith("sk-ant-", StringComparison.Ordinal) == true;

    public OnlineKeyState? LastError { get; private set; }

    public async Task<string> TranslateAsync(string text, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(text);
        if (_cache.TryGetValue(text, out var cached)) return cached;
        if (DateTimeOffset.UtcNow < _pausedUntil) return await FallbackAsync(text, cancellationToken).ConfigureAwait(false);

        string result;
        try
        {
            var prompt = _previous is null
                ? text
                : $"(Previous subtitle, for context only, do not translate: {_previous})\n\n{text}";
            result = await RequestAsync(_http, _key, prompt, 300, cancellationToken).ConfigureAwait(false);
            if (string.IsNullOrWhiteSpace(result)) throw new ClaudeException(OnlineKeyState.Unreachable);
            LastError = null;
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException or ClaudeException
                                      && !cancellationToken.IsCancellationRequested)
        {
            LastError = error is ClaudeException claude ? claude.State : OnlineKeyState.Unreachable;
            _pausedUntil = DateTimeOffset.UtcNow + RetryAfter;
            return await FallbackAsync(text, cancellationToken).ConfigureAwait(false);
        }

        result = result.Trim();
        if (_cache.Count >= CacheLimit) _cache.Clear();
        _cache[text] = result;
        _previous = text;
        return result;
    }

    public IReadOnlyList<SpokenLine> SpokenLines(string text) =>
        _cache.TryGetValue(text, out var translation) ? [new SpokenLine(text, translation)]
        : _fallback?.SpokenLines(text) ?? [];

    private async Task<string> FallbackAsync(string text, CancellationToken cancellationToken) =>
        _fallback is null ? throw new TranslatorException(TranslatorStatus.NeedsDownload)
            : await _fallback.TranslateAsync(text, cancellationToken).ConfigureAwait(false);

    private static async Task<string> RequestAsync(HttpClient http, string key, string text, int maxTokens, CancellationToken cancellationToken)
    {
        var body = new ClaudeRequest(Model, maxTokens, 0, SystemPrompt, [new ClaudeMessage("user", text)]);
        using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint)
        {
            Content = JsonContent.Create(body, ClaudeJson.Default.ClaudeRequest),
        };
        request.Headers.Add("x-api-key", key);
        request.Headers.Add("anthropic-version", "2023-06-01");
        using var response = await http.SendAsync(request, cancellationToken).ConfigureAwait(false);
        ThrowIfFailed(response);
        var reply = await response.Content.ReadFromJsonAsync(ClaudeJson.Default.ClaudeResponse, cancellationToken).ConfigureAwait(false);
        return string.Concat(reply?.Content?.Where(c => c.Type == "text").Select(c => c.Text) ?? []);
    }

    /// <summary>Ayarlardaki "Dene" düğmesi: anahtarla küçük bir çeviri denenir.</summary>
    public static async Task<OnlineKeyCheck> CheckAsync(string key, HttpClient? http = null, CancellationToken cancellationToken = default)
    {
        key = key.Trim();
        if (key.Length == 0) return new(OnlineKeyState.Invalid);
        try
        {
            await RequestAsync(http ?? SharedClient.Value, key, "Hi", 5, cancellationToken).ConfigureAwait(false);
            return new(OnlineKeyState.Valid);
        }
        catch (ClaudeException error) { return new(error.State); }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException && !cancellationToken.IsCancellationRequested)
        {
            return new(OnlineKeyState.Unreachable);
        }
    }

    private static void ThrowIfFailed(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode) return;
        throw new ClaudeException(response.StatusCode switch
        {
            HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden => OnlineKeyState.Invalid,
            HttpStatusCode.PaymentRequired => OnlineKeyState.QuotaExceeded,
            // Kredi bitince Anthropic 400 "credit balance is too low" döner.
            HttpStatusCode.BadRequest => OnlineKeyState.QuotaExceeded,
            _ => OnlineKeyState.Unreachable,
        });
    }
}

internal sealed class ClaudeException(OnlineKeyState state) : Exception($"Claude: {state}")
{
    public OnlineKeyState State { get; } = state;
}

internal sealed record ClaudeRequest(
    [property: JsonPropertyName("model")] string Model,
    [property: JsonPropertyName("max_tokens")] int MaxTokens,
    [property: JsonPropertyName("temperature")] double Temperature,
    [property: JsonPropertyName("system")] string System,
    [property: JsonPropertyName("messages")] IReadOnlyList<ClaudeMessage> Messages);

internal sealed record ClaudeMessage(
    [property: JsonPropertyName("role")] string Role,
    [property: JsonPropertyName("content")] string Content);

internal sealed record ClaudeResponse([property: JsonPropertyName("content")] IReadOnlyList<ClaudeContent>? Content);

internal sealed record ClaudeContent(
    [property: JsonPropertyName("type")] string Type,
    [property: JsonPropertyName("text")] string? Text);

[JsonSerializable(typeof(ClaudeRequest))]
[JsonSerializable(typeof(ClaudeResponse))]
internal sealed partial class ClaudeJson : JsonSerializerContext;
