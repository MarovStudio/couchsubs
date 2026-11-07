// SPDX-License-Identifier: AGPL-3.0-only

using CouchSubs.Core;
using CouchSubs.Core.Dubbing;
using Xunit;

namespace CouchSubs.Shell.Tests;

public class DubberTests
{
    private sealed class FakeSynth : ISpeechSynthesizer
    {
        public List<(string Text, Uri Voice)> Calls { get; } = [];
        public Task StartAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task<SpeechAudio> SynthesizeAsync(string text, Uri voice, CancellationToken cancellationToken = default)
        {
            lock (Calls) Calls.Add((text, voice));
            // 0,05 sn ses: testler hızlı biter.
            return Task.FromResult(new SpeechAudio([.. Enumerable.Range(0, 1200).Select(i => MathF.Sin(i * 0.1f) * 0.5f)], 24000));
        }
        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }

    private sealed class FakeModel(FakeSynth synth) : IDubbingModel
    {
        public bool IsInstalled => true;
        public long DownloadBytes => 0;
        public Task DownloadAsync(IProgress<double> progress, CancellationToken cancellationToken) => Task.CompletedTask;
        public byte[] VoiceFile(DubbingVoice voice) => [1, 2, 3];
        public ISpeechSynthesizer CreateSynthesizer() => synth;
    }

    private sealed class FakeAudio : IAudioOutput
    {
        public int Played;
        public void Play(byte[] wav) => Interlocked.Increment(ref Played);
        public void Stop() { }
    }

    private static async Task WaitUntil(Func<bool> condition)
    {
        var deadline = DateTime.UtcNow.AddSeconds(5);
        while (!condition())
        {
            Assert.True(DateTime.UtcNow < deadline, "Koşul zamanında sağlanmadı");
            await Task.Delay(20);
        }
    }

    [Fact]
    public async Task LinesAreVoicedInOrderWithEmotionAndTheCharactersVoice()
    {
        var synth = new FakeSynth();
        var audio = new FakeAudio();
        using var server = new SubtitleServer(0);
        VoiceCast? saved = null;
        var dubber = new Dubber(new FakeModel(synth), audio, () => server, () => 8787, action => action())
        {
            Output = DubbingOutput.Computer,
        };
        dubber.CastChanged += cast => saved = cast;
        dubber.Speak([new SpokenLine("Get back!", "Geri çekil!", "KRATOS"), new SpokenLine("Okay.", "Tamam.", "Freya")]);
        await WaitUntil(() => audio.Played == 2);

        Assert.Equal("[kızgın] geri çekil!", synth.Calls[0].Text);
        Assert.Equal("tamam.", synth.Calls[1].Text);
        Assert.StartsWith("http://127.0.0.1:8787/voices/male_", synth.Calls[0].Voice.AbsoluteUri);
        Assert.StartsWith("http://127.0.0.1:8787/voices/female_", synth.Calls[1].Voice.AbsoluteUri);
        Assert.NotNull(saved);
        Assert.Equal(2, saved!.Assignments.Count);
        await dubber.DisposeAsync();
    }

    [Fact]
    public async Task OldLinesAreDroppedWhenSpeechFallsBehind()
    {
        var synth = new FakeSynth();
        var audio = new FakeAudio();
        using var server = new SubtitleServer(0);
        var dubber = new Dubber(new FakeModel(synth), audio, () => server, () => 8787, action => action()) { Output = DubbingOutput.Computer };
        dubber.Speak([.. Enumerable.Range(1, 6).Select(i => new SpokenLine($"Line {i}.", $"Satır {i}."))]);
        await WaitUntil(() => audio.Played == Dubber.Backlog);
        await Task.Delay(200);
        Assert.Equal(Dubber.Backlog, audio.Played);
        Assert.Equal("satır dört.", synth.Calls[0].Text);
        await dubber.DisposeAsync();
    }

    [Fact]
    public async Task PreviewAlwaysPlaysOnTheComputer()
    {
        var synth = new FakeSynth();
        var audio = new FakeAudio();
        using var server = new SubtitleServer(0);
        var dubber = new Dubber(new FakeModel(synth), audio, () => server, () => 8787, action => action()) { Output = DubbingOutput.Tv };
        dubber.Preview(DubbingVoice.Female2);
        await WaitUntil(() => audio.Played == 1);
        Assert.EndsWith("/voices/female_2.wav", synth.Calls[0].Voice.AbsoluteUri);
        await dubber.DisposeAsync();
    }
}
