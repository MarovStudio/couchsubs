// SPDX-License-Identifier: AGPL-3.0-only

using CouchSubs.Core;

namespace CouchSubs.Core.Tests;

public class ReadingSplitTests
{
    [Fact]
    public void FarApartMenuAndGaugeAreSeparated() =>
        // 1920 genişlikte, 30 piksel yüksek yazılar arasında 900 piksel: soldaki menü, sağdaki gösterge.
        Assert.True(Reading.IsSeparateText(900, 30, 1920));

    [Fact]
    public void MissedWordsInsideASubtitleDoNotSplitIt()
    {
        // GTA V: açık zeminde okunamayan iki-üç sözcüğün bıraktığı 150-200 piksellik boşluk aynı cümledir.
        Assert.False(Reading.IsSeparateText(150, 30, 1920));
        Assert.False(Reading.IsSeparateText(200, 30, 1920));
    }

    [Fact]
    public void WideGapOnSmallTextIsStillOneLineUnlessFarAcrossTheScreen() =>
        // Küçük yazıda satır yüksekliğinin 4 katı dar kalır; görüntünün %12'sini de geçmeli.
        Assert.False(Reading.IsSeparateText(120, 20, 1920));
}
