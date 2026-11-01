<p align="center"><img src="design/logo-1024.png" width="120" alt="CouchSubs"></p>

# CouchSubs

PS5 oyunlarındaki İngilizce altyazıyı anlık okur, Türkçeye çevirir ve TV'de oyun görüntüsünün üstünde
gösterir. Oyunu her zamanki gibi TV'de, kendi kolunuzla oynarsınız. Yazı tanıma ve çeviri bilgisayarınızda
yapılır; altyazılar internete gönderilmez.

*English below.*

> **Beta.** Uygulama deneme aşamasındadır. Sorunları [Issues](https://github.com/yorulmazsinan/couchsubs/issues)
> sayfasından bildirebilirsiniz.

## Nasıl çalışır

```
PS5 ──HDMI──▶ TV (CouchSubs TV uygulaması: HDMI görüntüsü + altyazı katmanı)
 │                          ▲
 └─ Remote Play ──▶ CouchSubs (Mac / Windows) ── ev ağı
    (ikinci PSN hesabı)    okur → çevirir → TV'ye gönderir
```

Bilgisayar, PS5'e ikinci bir PlayStation Network hesabıyla Remote Play üzerinden bağlanır ve görüntüyü
yalnız altyazıyı okumak için kullanır. Siz oyunu HDMI'dan, gecikmesiz oynamaya devam edersiniz.

## Gerekenler

- **PS5** ve **LG TV** (webOS 4 ve üstü), bilgisayarla aynı ev ağında
- Ücretsiz **ikinci bir PlayStation Network hesabı** (kendi hesabınızla Remote Play kolunuzu
  kapatırdı; ikinci hesapla oyununuz kesilmez)
- Bilgisayar, şunlardan biri:
  - **Mac:** Apple Silicon (M1 ve sonrası), macOS 26 veya üstü
  - **Windows:** Windows 10 (2004) veya 11, 64 bit; ilk açılışta çeviri modeli için yaklaşık 530 MB indirme

Samsung TV desteği hazırlanıyor.

## Kurulum

1. **TV uygulaması:** [docs/tv-kurulum.md](docs/tv-kurulum.md). LG mağazasında yayınlanana kadar TV
   geliştirici modu ile bir kez kurulur.
2. **Bilgisayar uygulaması:** [Sürümler](https://github.com/yorulmazsinan/couchsubs/releases/latest)
   sayfasından indirin.
   - **Mac:** `CouchSubs-…-macos.zip` dosyasını açın, CouchSubs'ı **Uygulamalar** klasörüne taşıyıp açın.
   - **Windows:** `CouchSubs-…-windows-x64.zip` dosyasını bir klasöre çıkarın ve `CouchSubs.exe`'yi
     açın. "Windows bilgisayarınızı korudu" uyarısı çıkarsa **Ek bilgi › Yine de çalıştır**'a basın.
     Güvenlik duvarı sorarsa **Özel ağlar**'a izin verin (TV altyazıları bu bağlantıdan alır).
3. Kurulum sihirbazı gerisini adım adım anlatır: ikinci hesapla giriş, PS5 eşleme, TV eşleme ve deneme.

## Gizlilik

CouchSubs hesap şifrenizi görmez (giriş doğrudan Sony'nin sayfasında yapılır), altyazıları ve oyun
görüntüsünü hiçbir sunucuya göndermez. Ayrıntılar: [PRIVACY.md](PRIVACY.md).

## Derleme

**Mac**

```bash
brew install cmake ninja pkg-config protobuf openssl@3 json-c libevent miniupnpc xcodegen
git submodule update --init third-party/chiaki-ng
./scripts/build-chiaki-macos.sh     # libchiaki → third-party/build/CChiaki.xcframework
./scripts/package-mac.sh            # → dist/CouchSubs-<sürüm>-macos.zip
```

Testler: `core/` ve `remoteplay/` içinde `swift test`; `mac/` içinde `xcodegen generate` sonrası
`xcodebuild test -project mac/CouchSubs.xcodeproj -scheme CouchSubs -destination 'platform=macOS'`.

**Windows**

Yerel kütüphane (libchiaki + FFmpeg) MSYS2 ile derlenir; adımlar `.github/workflows/windows.yml` içinde.
.NET 10 ile `dotnet test windows/CouchSubs.Windows.slnx` (uygulamanın kendisi yalnız Windows'ta çalışır).

**TV**

```bash
npm install -g @webos-tools/cli
ares-package tv-webos -o dist
```

Sürümler `v*` etiketiyle `.github/workflows/release.yml` tarafından derlenip yayınlanır.

## Klasörler

- `mac/` – macOS uygulaması (SwiftUI, Vision, Translation)
- `windows/` – Windows uygulaması (WPF, Windows OCR, OPUS-MT çeviri modeli) ve yerel Remote Play kütüphanesi
- `core/` – platformdan bağımsız mantık (altyazı dengeleyici, yerel altyazı sunucusu, LG TV eşleme)
- `remoteplay/` – chiaki-ng'nin `libchiaki`'si üstünde Remote Play bağlantısı
- `tv-webos/` – LG webOS TV uygulaması
- `design/`, `docs/TASARIM.md` – logo ve ortak tasarım kuralları
- `prototip/` – ilk prototip (başvuru için saklanıyor)

## Lisans

[GNU AGPL-3.0](LICENSE). Kullanılan açık kaynak bileşenler ve lisansları:
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Remote Play bağlantısı
[chiaki-ng](https://github.com/chiaki-ng/chiaki-ng) sayesinde mümkün; geliştiricilerine teşekkürler.

Yayıncı: Enmera.

CouchSubs, Sony Interactive Entertainment ile bağlantılı değildir ve onun tarafından onaylanmamıştır.
"PlayStation" ve "PS5", Sony Interactive Entertainment Inc.'in ticari markalarıdır.

---

## English

CouchSubs reads the English subtitles of PS5 games in real time, translates them and shows the translation
on your TV on top of the game picture. You keep playing on the TV with your own controller; text recognition
and translation run on your computer, and subtitles are never sent to the internet.

**You need:** a PS5 and an LG TV (webOS 4+) on the same network as your computer, a free second
PlayStation Network account, and either a Mac with Apple Silicon on macOS 26+ or a 64-bit Windows 10 (2004)
or 11 PC.

**Setup:** install the TV app ([docs/tv-setup.md](docs/tv-setup.md)), download the Mac or Windows app from
[Releases](https://github.com/yorulmazsinan/couchsubs/releases/latest) and follow the setup assistant.
On Windows, if SmartScreen appears, choose **More info › Run anyway**.

Licensed under the [GNU AGPL-3.0](LICENSE); third-party components are listed in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). CouchSubs is not affiliated with or endorsed by Sony
Interactive Entertainment. "PlayStation" and "PS5" are trademarks of Sony Interactive Entertainment Inc.
