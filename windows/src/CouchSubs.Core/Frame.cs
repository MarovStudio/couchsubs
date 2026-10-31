// SPDX-License-Identifier: AGPL-3.0-only

namespace CouchSubs.Core;

/// <summary>BGRA (piksel başına 4 bayt) görüntü. PS5 akışından gelen kareler ve kırpılmış bölgeler.</summary>
public sealed class Frame(byte[] pixels, int width, int height, int stride)
{
    public byte[] Pixels { get; } = pixels;
    public int Width { get; } = width;
    public int Height { get; } = height;
    public int Stride { get; } = stride;

    public static Frame Blank(int width, int height) => new(new byte[width * height * 4], width, height, width * 4);

    /// <summary>Yerel kodun verdiği tamponun kopyası (tampon yalnız geri çağrı süresince geçerlidir).</summary>
    public static unsafe Frame Copy(IntPtr bgra, int width, int height, int stride)
    {
        var pixels = new byte[width * height * 4];
        var source = (byte*)bgra;
        fixed (byte* target = pixels)
            for (var y = 0; y < height; y++)
                Buffer.MemoryCopy(source + ((long)y * stride), target + ((long)y * width * 4), width * 4, width * 4);
        return new Frame(pixels, width, height, width * 4);
    }

    public Frame Crop(int x, int y, int width, int height)
    {
        x = Math.Clamp(x, 0, Width);
        y = Math.Clamp(y, 0, Height);
        width = Math.Clamp(width, 0, Width - x);
        height = Math.Clamp(height, 0, Height - y);
        var result = Blank(width, height);
        for (var row = 0; row < height; row++)
            Buffer.BlockCopy(Pixels, ((y + row) * Stride) + (x * 4), result.Pixels, row * result.Stride, width * 4);
        return result;
    }

    /// <summary>İki doğrusal (bilinear) büyütme; kısa satırların okunmasına yardım eder.</summary>
    public Frame Scaled(int factor)
    {
        var result = Blank(Width * factor, Height * factor);
        for (var ty = 0; ty < result.Height; ty++)
        {
            var sy = Math.Min(((ty + 0.5) / factor) - 0.5, Height - 1.0);
            if (sy < 0) sy = 0;
            var y0 = (int)sy;
            var y1 = Math.Min(y0 + 1, Height - 1);
            var fy = sy - y0;
            for (var tx = 0; tx < result.Width; tx++)
            {
                var sx = Math.Min(((tx + 0.5) / factor) - 0.5, Width - 1.0);
                if (sx < 0) sx = 0;
                var x0 = (int)sx;
                var x1 = Math.Min(x0 + 1, Width - 1);
                var fx = sx - x0;
                for (var c = 0; c < 4; c++)
                {
                    double P(int x, int y) => Pixels[(y * Stride) + (x * 4) + c];
                    var top = P(x0, y0) + ((P(x1, y0) - P(x0, y0)) * fx);
                    var bottom = P(x0, y1) + ((P(x1, y1) - P(x0, y1)) * fx);
                    result.Pixels[(ty * result.Stride) + (tx * 4) + c] = (byte)Math.Round(top + ((bottom - top) * fy));
                }
            }
        }
        return result;
    }
}

/// <summary>Görüntüde altyazının arandığı bölge, kenarlara oranla (0–1, üstten ve soldan).</summary>
public sealed record CropRegion(double Top = 0.62, double Bottom = 0.97, double Left = 0.14, double Right = 0.86);

public static class RegionCropper
{
    public static Frame Crop(Frame image, CropRegion region)
    {
        // Mac'teki CGRect.integral ile aynı: kenarlar dışa yuvarlanır.
        var left = (int)Math.Floor(image.Width * region.Left);
        var top = (int)Math.Floor(image.Height * region.Top);
        var right = (int)Math.Ceiling(image.Width * region.Right);
        var bottom = (int)Math.Ceiling(image.Height * region.Bottom);
        return image.Crop(left, top, right - left, bottom - top);
    }
}

/// <summary>Bir görüntüdeki yazıyı okur (Windows'ta Windows.Media.Ocr).</summary>
public interface ITextReader
{
    string Read(Frame image);
}

/// <summary>
/// OCR geniş bölgede "Go!" gibi kısa satırları sık sık hiç bulmaz. Bölgede yazı çıkmazsa
/// ortadaki şerit (altyazılar ortalıdır) ve bölgenin tamamı büyütülerek aynı anda yeniden okunur;
/// ikisi de yazı bulursa şeridinki seçilir. Aynı anda okumak, boş karede yeni satırı geç fark etmeyi önler.
/// </summary>
public static class ReadingFallback
{
    public static string FirstReading(Frame image, Func<Frame, string> recognize)
    {
        var text = recognize(image);
        if (text.Length > 0) return text;

        Func<Frame>[] fallbacks =
        [
            () => CenterStrip(image, 0.4).Scaled(2),
            () => image.Scaled(2),
        ];
        var results = new string[fallbacks.Length];
        Parallel.For(0, fallbacks.Length, index => results[index] = recognize(fallbacks[index]()));
        return results.FirstOrDefault(r => r.Length > 0) ?? "";
    }

    private static Frame CenterStrip(Frame image, double widthFraction)
    {
        var width = image.Width * widthFraction;
        var left = (image.Width - width) / 2;
        var x = (int)Math.Floor(left);
        return image.Crop(x, 0, (int)Math.Ceiling(left + width) - x, image.Height);
    }
}
