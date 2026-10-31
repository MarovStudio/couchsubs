# CouchSubs

**TR** — PS5 oyunlarındaki İngilizce altyazıyı anlık okuyup Türkçesini TV'de oyun görüntüsünün üstünde
gösterir. Oyunu her zamanki gibi TV'de, kendi kolunuzla oynarsınız; çeviri bilgisayarınızda (ileride
telefonunuzda), internete gerek olmadan, cihaz üstünde yapılır.

**EN** — Reads the English subtitles of PS5 games in real time and shows a translation on your TV, on top
of the game picture. You keep playing on the TV with your own controller; text recognition and
translation run on-device on your computer (later your phone), with no internet connection required.

> Geliştirme aşamasında. / Work in progress.

## Nasıl çalışır / How it works

```
PS5 ──HDMI──▶ TV app (HDMI full screen + subtitle layer)
 │                         ▲
 └─Remote Play ──▶ CouchSubs (Mac) ── local network
   (second PSN account)   reads → translates → sends
```

- `mac/` — macOS app (SwiftUI): setup assistant, text recognition (Vision), on-device translation (Translation)
- `core/` — platform-independent logic (subtitle stabilizer, local subtitle server, LG TV pairing)
- `remoteplay/` — Remote Play connection on top of chiaki-ng's `libchiaki` (PS5 discovery, pairing, H.264 decoding)
- `tv-webos/` — LG webOS TV app
- `prototip/` — the original prototype (kept for reference)
- `docs/` — design, plans and the TV setup guide

## Gereksinimler / Requirements

- Mac with Apple Silicon, macOS 26 or later
- PS5 and LG TV (webOS 4+) on the same network as the Mac
- A free second PlayStation Network account — Remote Play with your own account would turn off your
  controller; with a second account you keep playing undisturbed
- English and Turkish downloaded in System Settings › General › Language & Region › Translation Languages

## Kurulum / Setup

1. TV app: [docs/tv-kurulum.md](docs/tv-kurulum.md) (TR) · [docs/tv-setup.md](docs/tv-setup.md) (EN)
2. Mac app: download `CouchSubs-<version>-macos.zip`, open it and follow the setup assistant. Unsigned
   beta builds need **System Settings › Privacy & Security › Open Anyway** the first time.

## Derleme / Building

```bash
brew install cmake ninja pkg-config protobuf openssl@3 json-c libevent miniupnpc xcodegen
git submodule update --init third-party/chiaki-ng
./scripts/build-chiaki-macos.sh     # libchiaki → third-party/build/CChiaki.xcframework
./scripts/package-mac.sh            # → dist/CouchSubs-<version>-macos.zip
```

Tests: `swift test` in `core/` and `remoteplay/`, `xcodebuild test -project mac/CouchSubs.xcodeproj -scheme CouchSubs`
(after `xcodegen generate` in `mac/`).

## Lisans / License

AGPL-3.0. CouchSubs uses the Remote Play library of [chiaki-ng](https://github.com/chiaki-ng/chiaki-ng)
(AGPL-3.0 with OpenSSL exception).

CouchSubs, Sony Interactive Entertainment ile bağlantılı değildir. "PlayStation" ve "PS5", Sony
Interactive Entertainment Inc.'in ticari markalarıdır. / CouchSubs is not affiliated with Sony Interactive
Entertainment. "PlayStation" and "PS5" are trademarks of Sony Interactive Entertainment Inc.
