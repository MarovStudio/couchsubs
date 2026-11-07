// SPDX-License-Identifier: AGPL-3.0-only

using System.Runtime.InteropServices.WindowsRuntime;
using CouchSubs.Core;
using Windows.Globalization;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;

namespace CouchSubs.App.Services;

/// <summary>
/// Windows'un cihaz üstü yazı tanıması. Oyun dilinin OCR paketi yoksa kullanıcının yüklü dillerinden
/// biri kullanılır (Latin alfabeli diller İngilizce altyazıyı da okuyabilir). Satırlar yukarıdan aşağı sıralanır.
/// </summary>
public sealed class WindowsOcrReader : ITextReader
{
    private readonly OcrEngine engine;

    private WindowsOcrReader(OcrEngine engine) => this.engine = engine;

    /// <summary>Hiçbir OCR dili yüklü değilse null.</summary>
    public static WindowsOcrReader? Create(string language)
    {
        var engine = OcrEngine.TryCreateFromLanguage(new Language(language))
                     ?? OcrEngine.TryCreateFromUserProfileLanguages();
        return engine is null ? null : new WindowsOcrReader(engine);
    }

    /// <summary>Oyun dilinin kendi OCR paketi yüklü mü (değilse ayarlarda eklenmesi önerilir).</summary>
    public static bool HasLanguage(string language) => OcrEngine.IsLanguageSupported(new Language(language));

    public string Read(Frame image) => Read(image, deep: true);

    public string Read(Frame image, bool deep) => string.Join(' ', ReadLines(image, deep).Lines.Select(line => line.Text));

    public Reading ReadLines(Frame image, bool deep) => deep ? ReadingFallback.FirstLines(image, Recognize) : Recognize(image);

    private Reading Recognize(Frame image)
    {
        // OCR motoru çok küçük ya da çok büyük görüntüyü reddeder.
        if (image.Width < 40 || image.Height < 40 || image.Width > OcrEngine.MaxImageDimension || image.Height > OcrEngine.MaxImageDimension)
            return Reading.Empty;
        using var bitmap = new SoftwareBitmap(BitmapPixelFormat.Bgra8, image.Width, image.Height, BitmapAlphaMode.Premultiplied);
        bitmap.CopyFromBuffer(image.Pixels.AsBuffer());
        var result = engine.RecognizeAsync(bitmap).AsTask().GetAwaiter().GetResult();
        double width = image.Width, height = image.Height;
        var lines = result.Lines
            .Select(line =>
            {
                // Satırın kutusu sözcük kutularının birleşimidir; görüntünün kenarlarına oranla verilir.
                TextBox? box = null;
                foreach (var word in line.Words)
                {
                    var r = word.BoundingRect;
                    var wordBox = new TextBox(r.X / width, r.Y / height, (r.X + r.Width) / width, (r.Y + r.Height) / height);
                    box = box?.Union(wordBox) ?? wordBox;
                }
                return new TextLine(line.Text.Trim(), box);
            })
            .OrderBy(line => line.Box?.Top ?? 0);
        return new Reading(lines);
    }
}
