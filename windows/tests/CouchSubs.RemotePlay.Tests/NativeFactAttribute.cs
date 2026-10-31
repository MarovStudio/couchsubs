// SPDX-License-Identifier: AGPL-3.0-only

namespace CouchSubs.RemotePlay.Tests;

/// <summary>Yerel kütüphane (couchsubs_native) yüklenemiyorsa testi atlar: Mac'te ve DLL'siz derlemede.</summary>
public sealed class NativeFactAttribute : FactAttribute
{
    public NativeFactAttribute()
    {
        if (!NativeMethods.IsAvailable) Skip = "couchsubs_native is not available on this machine";
    }
}
