// SPDX-License-Identifier: AGPL-3.0-only

namespace CouchSubs.Core.LgTv;

/// <summary>
/// TV uygulamasını açık tutar: TV kendi HDMI ya da yayın girişine geçerse (SimpLink/CEC) uygulamayı
/// yeniden öne getirir. TV kapalıysa ya da bağlantı koparsa bir sonraki kontrolde yeniden bağlanır.
/// </summary>
public sealed class TvKeeper(Func<Task<ITvControl>> connect, string appId, IReadOnlyDictionary<string, string> parameters) : IDisposable
{
    private readonly SemaphoreSlim tickLock = new(1, 1);
    private ITvControl? control;
    private CancellationTokenSource? loop;

    /// <summary>Kullanıcının bilerek açtığı uygulamalara (Netflix vb.) dokunulmaz; yalnız giriş ve yayın ekranları.</summary>
    public static bool IsInputOrLiveTv(string appId) =>
        appId.StartsWith("com.webos.app.hdmi", StringComparison.Ordinal)
        || appId.StartsWith("com.webos.app.externalinput", StringComparison.Ordinal)
        || appId == "com.webos.app.livetv";

    /// <summary>Bir kontrol. Hata fırlatmaz; bağlantı sorununda bir sonraki kontrolde yeniden dener.</summary>
    public async Task TickAsync()
    {
        await tickLock.WaitAsync();
        try
        {
            if (control is null)
            {
                var fresh = await connect();
                control = fresh;
                await fresh.LaunchAsync(appId, parameters);
                return;
            }
            var current = await control.ForegroundAppIdAsync();
            if (IsInputOrLiveTv(current)) await control.LaunchAsync(appId, parameters);
        }
        catch
        {
            control?.Dispose();
            control = null;
        }
        finally
        {
            tickLock.Release();
        }
    }

    public void Start(TimeSpan? interval = null)
    {
        loop?.Cancel();
        var cancellation = new CancellationTokenSource();
        loop = cancellation;
        var delay = interval ?? TimeSpan.FromSeconds(5);
        _ = Task.Run(async () =>
        {
            while (!cancellation.IsCancellationRequested)
            {
                await TickAsync();
                try { await Task.Delay(delay, cancellation.Token); } catch (OperationCanceledException) { }
            }
        });
    }

    /// <summary>Bilgisayar uykudan uyandığında: bağlantıyı yenile.</summary>
    public void Reconnect()
    {
        control?.Dispose();
        control = null;
    }

    public void Stop()
    {
        loop?.Cancel();
        loop = null;
        control?.Dispose();
        control = null;
    }

    public void Dispose() => Stop();
}
