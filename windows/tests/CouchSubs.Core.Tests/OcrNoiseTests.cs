// SPDX-License-Identifier: AGPL-3.0-only

using CouchSubs.Core;

namespace CouchSubs.Core.Tests;

public class OcrNoiseTests
{
    /// Süslü yazıda bir sözcük her karede başka çöpe dönüşüyordu.
    [Theory]
    [InlineData("Across the deep waters, Pbo ou$3e went, hoping a boat would carry him home.",
                "Across the deep waters, Pbo went, hoping a boat would carry him home.")]
    [InlineData("Across the deep waters2aljd O went, Hoping a boat.", "Across the deep waters O went, Hoping a boat.")]
    [InlineData("He left 3e, at dawn.", "He left, at dawn.")]
    public void GarbledWordsAreRemoved(string line, string expected) => Assert.Equal(expected, OcrNoise.Clean(line));

    [Theory]
    [InlineData("Turn on the PS5 now.")]
    [InlineData("Hold R2-D2 still.")]
    [InlineData("It costs $500.")]
    [InlineData("Meet me at 3:00pm.")]
    [InlineData("The 2nd gate is 100m away.")]
    [InlineData("Run at 60fps, 4K.")]
    [InlineData("Score x2!")]
    [InlineData("Year 1984.")]
    [InlineData("I can't — wait…")]
    [InlineData("\"Kratos!\" she said.")]
    [InlineData("Mk2 rifle, 9.5kg.")]
    [InlineData("L1 + R1 Spartan Rage")]
    public void UsualTokensAreKept(string line) => Assert.Equal(line, OcrNoise.Clean(line));

    [Fact]
    public void ReadingDropsLinesThatWereOnlyNoise()
    {
        var reading = new Reading([new TextLine("We go now."), new TextLine("ou$3e 2aljd")]).WithoutOcrNoise();
        Assert.Equal("We go now.", reading.Text);
    }
}
