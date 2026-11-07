// SPDX-License-Identifier: AGPL-3.0-only

using CouchSubs.Core.Dubbing;

namespace CouchSubs.Core;

/// <summary>Bir satırı oyun dilinden hedef dile çevirir (cihaz üstünde).</summary>
public interface ITextTranslator
{
    Task<string> TranslateAsync(string text, CancellationToken cancellationToken = default);

    /// <summary>Son çevrilen altyazının seslendirilecek cümleleri (konuşmacısıyla); dublaj için.</summary>
    IReadOnlyList<SpokenLine> SpokenLines(string text) => [];
}

public enum TranslatorStatus
{
    Ready,
    /// <summary>Çeviri modeli henüz indirilmedi.</summary>
    NeedsDownload,
    /// <summary>Bu dil çifti desteklenmiyor.</summary>
    Unsupported,
}

/// <summary>Kullanıcının düzeltebileceği çeviri hatası (model eksik, dil desteklenmiyor).</summary>
public sealed class TranslatorException(TranslatorStatus status)
    : Exception($"Translator not available: {status}")
{
    public TranslatorStatus Status { get; } = status;
}
