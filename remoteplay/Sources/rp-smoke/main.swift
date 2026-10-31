// SPDX-License-Identifier: AGPL-3.0-only
// Geliştirme aracı: gerçek PS5 ile bulma, PSN kimliği, kayıt ve görüntü akışı denemesi.
//   swift run rp-smoke discover [ps5-ip]
//   swift run rp-smoke psn-url                      → tarayıcıda açılacak giriş adresi
//   swift run rp-smoke psn-code '<yönlendirme adresi>' → hesap kimliği (base64)
//   swift run rp-smoke register <ps5-ip> <hesap-kimliği-base64> <8 haneli kod>
//   swift run rp-smoke stream [saniye]               → kare sayısı + son kare ~/couchsubs-kare.png

import CoreGraphics
import Foundation
import ImageIO
import RemotePlay
import UniformTypeIdentifiers

setvbuf(stdout, nil, _IOLBF, 0)
let args = Array(CommandLine.arguments.dropFirst())
let home = FileManager.default.homeDirectoryForCurrentUser
let consoleFile = home.appendingPathComponent(".couchsubs-console.json")
let accountFile = home.appendingPathComponent(".couchsubs-account")

switch args.first {
case "discover":
    for console in await Console.discover(host: args.dropFirst().first) { print("\(console.name) \(console.host) \(console.isAwake ? "uyanık" : "uyuyor")") }
case "psn-url":
    print(PSNAccount.authorizeURL.absoluteString)
case "psn-code":
    guard args.count > 1, let url = URL(string: args[1]), let code = PSNAccount.code(fromRedirect: url) else { print("Geçersiz adres"); exit(1) }
    let id = try await PSNAccount.accountId(code: code).base64EncodedString()
    try id.write(to: accountFile, atomically: true, encoding: .utf8)
    print("Hesap kimliği: \(id)")
case "register":
    guard args.count > 3, let account = Data(base64Encoded: args[2]), let pin = UInt32(args[3]) else { print("Kullanım: register <ip> <kimlik> <kod>"); exit(1) }
    let console = try await Registration.register(host: args[1], accountId: account, pin: pin)
    try JSONEncoder().encode(console).write(to: consoleFile)
    try account.base64EncodedString().write(to: accountFile, atomically: true, encoding: .utf8)
    print("Kayıt tamam: \(console.name)")
case "stream":
    let seconds = Double(args.dropFirst().first ?? "10") ?? 10
    let console = try JSONDecoder().decode(RegisteredConsole.self, from: Data(contentsOf: consoleFile))
    let account = Data(base64Encoded: try String(contentsOf: accountFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
    let session = StreamSession(console: console, accountId: account)
    var frames = 0
    var last: CGImage?
    session.onState = { print("Durum: \($0)") }
    session.onFrame = { frames += 1; last = $0 }
    session.start()
    try await Task.sleep(for: .seconds(seconds))
    session.stop()
    print("\(Int(seconds)) sn'de \(frames) kare alındı.")
    if let last, let destination = CGImageDestinationCreateWithURL(home.appendingPathComponent("couchsubs-kare.png") as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(destination, last, nil)
        CGImageDestinationFinalize(destination)
        print("Son kare: ~/couchsubs-kare.png (\(last.width)x\(last.height))")
    }
default:
    print("Komutlar: discover | psn-url | psn-code | register | stream")
}
