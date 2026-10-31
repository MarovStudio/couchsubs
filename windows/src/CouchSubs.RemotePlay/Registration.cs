// SPDX-License-Identifier: AGPL-3.0-only

using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace CouchSubs.RemotePlay;

public static class Registration
{
    /// <summary>libchiaki'nin CHIAKI_RP_APPLICATION_REASON_INVALID_PSN_ID değeri.</summary>
    internal const uint InvalidPsnIdReason = 0x80108b02;

    /// <summary>PS5'in "Cihazı Bağla" ekranındaki 8 haneli kodla kayıt olur. Başarısızlıkta
    /// <see cref="RegistrationException"/>; iptal beklemeyi bırakır (OperationCanceledException), PS5'le
    /// konuşma kendi zaman aşımında (en çok ~30 sn) biter.</summary>
    public static Task<RegisteredConsole> RegisterAsync(string host, byte[] accountId, uint pin, CancellationToken ct = default)
    {
        if (accountId.Length != 8) throw new ArgumentException("PSN account id must be 8 bytes", nameof(accountId));
        return Task.Factory.StartNew(() => Register(host, accountId, pin), CancellationToken.None,
                                     TaskCreationOptions.LongRunning, TaskScheduler.Default).WaitAsync(ct);
    }

    /// <summary>PS5'in bildirdiği nedenden kullanıcıya anlatılacak hata.</summary>
    internal static RegistrationFailure FailureFrom(uint? reason) =>
        reason == InvalidPsnIdReason ? RegistrationFailure.WrongAccount : RegistrationFailure.Failed;

    private static unsafe RegisteredConsole Register(string host, byte[] accountId, uint pin)
    {
        NativeMethods.EnsureInitialized();
        NativeMethods.RegisteredConsoleNative output;
        uint reason;
        int result;
        delegate* unmanaged[Cdecl]<int, byte*, nint, void> log = &OnLog;
        fixed (byte* account = accountId)
            result = NativeMethods.cs_register(host, account, pin, &output, &reason, (nint)log, 0);

        switch (result)
        {
            case 0:
                return new RegisteredConsole(host, NativeMethods.FixedString(output.Nickname, 0x20),
                                             new ReadOnlySpan<byte>(output.RegistKey, 0x10).ToArray(),
                                             new ReadOnlySpan<byte>(output.Morning, 0x10).ToArray());
            case 2:
                throw new RegistrationException(RegistrationFailure.Canceled);
            case 1:
                throw new RegistrationException(FailureFrom(reason == 0 ? null : reason));
            default:
                throw new RegistrationException(RegistrationFailure.Failed);
        }
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
    private static unsafe void OnLog(int level, byte* message, nint user) => RemotePlayLog.Write(level, NativeMethods.Utf8(message));
}
