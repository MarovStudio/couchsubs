// SPDX-License-Identifier: AGPL-3.0-only

using System.Net;
using System.Net.Sockets;
using System.Text;

namespace CouchSubs.Core.LgTv;

public sealed record LgTv(string Name, string Host);

/// <summary>Yerel ağdaki LG webOS TV'leri SSDP ile bulur.</summary>
public static class LgDiscovery
{
    internal const string SearchTarget = "urn:lge-com:service:webos-second-screen:1";
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(2) };

    public static async Task<IReadOnlyList<LgTv>> SearchAsync(TimeSpan? timeout = null, CancellationToken cancellationToken = default)
    {
        var hosts = await CollectResponses(timeout ?? TimeSpan.FromSeconds(3), cancellationToken);
        var tvs = new List<LgTv>();
        foreach (var host in hosts.Distinct().Order(StringComparer.Ordinal))
            tvs.Add(new LgTv(await FriendlyName(host) ?? "LG TV", host));
        return tvs;
    }

    /// <summary>SSDP yanıtından TV'nin adresini çıkarır; LG'nin ikinci ekran servisi değilse null.</summary>
    public static string? HostFromSsdpResponse(string response)
    {
        string? location = null;
        var isLg = false;
        foreach (var line in response.Split("\r\n"))
        {
            var colon = line.IndexOf(':');
            if (colon < 0) continue;
            var name = line[..colon].Trim().ToUpperInvariant();
            var value = line[(colon + 1)..].Trim();
            if (name == "LOCATION") location = value;
            else if (name is "ST" or "NT") isLg = isLg || value == SearchTarget;
        }
        return isLg && Uri.TryCreate(location, UriKind.Absolute, out var url) ? url.Host : null;
    }

    private static async Task<List<string>> CollectResponses(TimeSpan timeout, CancellationToken cancellationToken)
    {
        var hosts = new List<string>();
        using var udp = new UdpClient(AddressFamily.InterNetwork);
        var request = Encoding.ASCII.GetBytes(
            $"M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: {SearchTarget}\r\n\r\n");
        var target = new IPEndPoint(IPAddress.Parse("239.255.255.250"), 1900);
        for (var i = 0; i < 2; i++) await udp.SendAsync(request, target, cancellationToken);

        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(timeout);
        try
        {
            while (true)
            {
                var result = await udp.ReceiveAsync(deadline.Token);
                if (HostFromSsdpResponse(Encoding.UTF8.GetString(result.Buffer)) is { } host) hosts.Add(host);
            }
        }
        catch (OperationCanceledException) { }
        return hosts;
    }

    /// <summary>TV'nin ağdaki adını (ör. "[LG] webOS TV UK7550") cihaz tanımından okur.</summary>
    private static async Task<string?> FriendlyName(string host)
    {
        // webOS cihaz tanımı 1990 numaralı portta yayınlanır; okunamazsa genel ad kullanılır.
        try
        {
            var xml = await Http.GetStringAsync($"http://{host}:1990/");
            var start = xml.IndexOf("<friendlyName>", StringComparison.Ordinal);
            var end = start < 0 ? -1 : xml.IndexOf("</friendlyName>", start, StringComparison.Ordinal);
            return end < 0 ? null : xml[(start + "<friendlyName>".Length)..end];
        }
        catch
        {
            return null;
        }
    }
}
