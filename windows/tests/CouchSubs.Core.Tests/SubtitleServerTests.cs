// SPDX-License-Identifier: AGPL-3.0-only

using System.Net;
using CouchSubs.Core;

namespace CouchSubs.Core.Tests;

public class SubtitleServerTests
{
    private static readonly HttpClient Http = new() { Timeout = Timeout.InfiniteTimeSpan };

    private static async Task WaitUntil(Func<bool> condition, int timeoutMs = 3000)
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (!condition())
        {
            Assert.True(DateTime.UtcNow < deadline, "Koşul zamanında sağlanmadı");
            await Task.Delay(20);
        }
    }

    private static async Task<List<string>> ReadLines(StreamReader reader, string until)
    {
        var lines = new List<string>();
        while (await reader.ReadLineAsync() is { } line)
        {
            lines.Add(line);
            if (line == until) break;
        }
        return lines;
    }

    [Fact]
    public async Task StreamsSubtitleAndClearEventsWithCors()
    {
        using var server = new SubtitleServer(0);
        var port = await server.StartAsync();

        using var response = await Http.GetAsync($"http://127.0.0.1:{port}/events", HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("*", response.Headers.GetValues("Access-Control-Allow-Origin").Single());
        Assert.StartsWith("text/event-stream", response.Content.Headers.ContentType?.ToString());

        await WaitUntil(() => server.ConnectedClients == 1);
        server.SendSubtitle("Merhaba", 4000);
        server.Clear();

        using var reader = new StreamReader(await response.Content.ReadAsStreamAsync());
        var lines = await ReadLines(reader, "event: clear");
        Assert.Contains("event: subtitle", lines);
        Assert.Contains(lines, l => l.StartsWith("data:") && l.Contains("\"text\":\"Merhaba\"") && l.Contains("\"duration\":4000"));
    }

    [Fact]
    public async Task TurkishTextIsSentAsUtf8()
    {
        using var server = new SubtitleServer(0);
        var port = await server.StartAsync();
        using var response = await Http.GetAsync($"http://127.0.0.1:{port}/events", HttpCompletionOption.ResponseHeadersRead);
        await WaitUntil(() => server.ConnectedClients == 1);
        server.SendSubtitle("Kapıyı tut, evlat!", 4000);
        using var reader = new StreamReader(await response.Content.ReadAsStreamAsync());
        var lines = await ReadLines(reader, "");
        lines = await ReadLines(reader, "");
        Assert.Contains(lines, l => l.Contains("Kapıyı tut, evlat!"));
    }

    [Fact]
    public async Task NewClientReceivesLastStyle()
    {
        using var server = new SubtitleServer(0);
        var port = await server.StartAsync();
        server.SendStyle(new SubtitleStyle(58, 10));

        using var response = await Http.GetAsync($"http://127.0.0.1:{port}/events", HttpCompletionOption.ResponseHeadersRead);
        using var reader = new StreamReader(await response.Content.ReadAsStreamAsync());
        string? data = null;
        while (await reader.ReadLineAsync() is { } line)
            if (line.StartsWith("data:")) { data = line; break; }
        Assert.Contains("\"fontSize\":58", data);
        Assert.Contains("\"bottomPercent\":10", data);
    }

    [Fact]
    public async Task ClientCountDropsWhenClientDisconnects()
    {
        using var server = new SubtitleServer(0);
        var port = await server.StartAsync();
        var response = await Http.GetAsync($"http://127.0.0.1:{port}/events", HttpCompletionOption.ResponseHeadersRead);
        await WaitUntil(() => server.ConnectedClients == 1);
        response.Dispose();
        await WaitUntil(() => server.ConnectedClients == 0);
    }

    [Fact]
    public async Task HelloIdentifiesTheApp()
    {
        using var server = new SubtitleServer(0);
        var port = await server.StartAsync();
        using var http = new HttpClient();
        Assert.Equal("{\"app\":\"couchsubs\"}", await http.GetStringAsync($"http://127.0.0.1:{port}/hello"));
    }

    [Fact]
    public async Task UnknownPathIs404()
    {
        using var server = new SubtitleServer(0);
        var port = await server.StartAsync();
        using var response = await Http.GetAsync($"http://127.0.0.1:{port}/nope");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
