// SPDX-License-Identifier: AGPL-3.0-only

namespace CouchSubs.Core;

/// <summary>Bir satırı oyun dilinden hedef dile çevirir (cihaz üstünde).</summary>
public interface ITextTranslator
{
    Task<string> TranslateAsync(string text, CancellationToken cancellationToken = default);
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
