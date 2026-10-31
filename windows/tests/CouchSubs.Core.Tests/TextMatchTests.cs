// SPDX-License-Identifier: AGPL-3.0-only

using CouchSubs.Core;

namespace CouchSubs.Core.Tests;

public class TextMatchTests
{
    [Fact]
    public void NormalizeStripsPunctuationAndCase() =>
        Assert.Equal("kratos we do not have time boy", TextMatch.Normalize("Kratos: We do NOT have time, boy."));

    [Fact]
    public void SimilarToleratesOcrNoise() => Assert.True(TextMatch.IsSimilar("the gate will not hold", "the gale will not hold"));

    [Fact]
    public void DifferentLinesAreNotSimilar() => Assert.False(TextMatch.IsSimilar("we do not have time", "the gate will not hold"));

    [Fact]
    public void EmptyIsNeverSimilarToText() => Assert.False(TextMatch.IsSimilar("", "abc"));
}
