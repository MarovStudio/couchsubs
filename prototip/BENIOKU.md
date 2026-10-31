# PS5 Altyazı — geliştirme sürümü

PS5 oyunlarındaki İngilizce altyazıyı okuyup Türkçesini TV'de oyunun üstüne basar.

```
PS5 ──HDMI──▶ LG TV ── uygulama: HDMI tam ekran + Türkçe altyazı katmanı
  │                          ▲
  └─Remote Play─▶ Mac        │ yerel ağ (Server-Sent Events)
                  okuyucu ──▶ sunucu
                  (OCR + çeviri)
```

- `tv-webos/` — TV uygulaması (HDMI'ı gösterir, altyazıyı üstüne basar)
- `sunucu/server.mjs` — Mac'te çalışan altyazı sunucusu ve kontrol sayfası
- `okuyucu/` — Remote Play penceresindeki altyazıyı okuyup (Apple Vision) cihaz üstünde
  Türkçeye çeviren (Apple Translation) ve sunucuya gönderen araç
- `kur.sh` — TV uygulamasını paketleyip TV'ye kurar
- `ornekler/` — okuyucuyu denemek için örnek oyun karesi

## 1. TV'yi hazırla (bir kez)

1. TV'de LG Content Store'dan **Developer Mode** uygulamasını kur, LG hesabınla gir.
2. **Dev Mode Status**'u aç, TV yeniden başlar. **Key Server**'ı da aç.
3. Uygulamada görünen TV IP adresini ve **Passphrase**'i not et.
   (Geliştirici modu süresi dolunca bu uygulamadan uzatılır.)

## 2. Mac'i hazırla (bir kez)

```bash
npm install -g @webos-tools/cli
```

```bash
ares-setup-device --add tv --info "{'host':'TV_IP_ADRESI','port':'9922','username':'prisoner'}"
```

```bash
ares-novacom --device tv --getkey
```

Son komut TV'deki Passphrase'i sorar.

## 3. Çalıştır

Sunucuyu başlat (macOS gelen bağlantı izni sorarsa izin ver):

```bash
node sunucu/server.mjs --demo
```

Başka bir terminalde uygulamayı kur:

```bash
./kur.sh
```

Kontrol sayfası sunucunun yazdığı adreste açılır (telefondan da açılabilir).
Terminale yazdığın satırlar da TV'ye altyazı olarak gider.

## 4. Oyun altyazısını çevir (okuyucu)

Gereken: macOS 26+, Xcode Command Line Tools, PS Remote Play. Sistem Ayarları → Genel → Dil ve
Bölge → Çeviri Dilleri'nden İngilizce ve Türkçe indirilmiş olmalı.

```bash
okuyucu/derle.sh
```

```bash
okuyucu/okuyucu
```

PS Remote Play'i açıp PS5'e bağlan; okuyucu pencereyi kendisi bulur. İlk çalıştırmada macOS
**Ekran ve Sistem Sesi Kaydı** izni ister. Oyunun altyazısı farklı bir yerdeyse `--bolge 0.62:0.97`
ve `--yatay 0.14:0.86` ile ayarla; `--onizleme kirpim.png` okunan bölgeyi kaydeder.

Remote Play olmadan denemek için örnek kareyi Önizleme'de açıp:

```bash
okuyucu/okuyucu --uygulama Preview --bolge 0.6:0.99
```

Tek bir görüntüyü okuyup çevirmek için: `okuyucu/okuyucu --dosya ornekler/oyun-karesi.png`

## Kumanda tuşları

| Tuş | İşlev |
| --- | --- |
| 1–4 | HDMI girişini elle seç (normalde PS5 otomatik bulunur) |
| 0 | Elle seçimi unut, PS5'i yeniden otomatik bul |
| Kırmızı | Sunucusuz yerel test altyazısı |
| Yeşil | Durum panelini aç/kapat |
| Sarı | Yazı boyutu |

## Neye bakacağız

1. PS5 görüntüsü uygulamanın içinde geliyor mu? (Panelde "görüntü geldi/oynatılıyor")
2. Kırmızı tuşla altyazı oyunun **üstünde** görünüyor mu?
3. Panelde "Bağlantı: bağlı" yazıyor mu, sunucudan gelen altyazılar düşüyor mu?
4. Oyunda gecikme hissediliyor mu? Ses geliyor mu? HDR/oyun modu kapanıyor mu?

## Doğrulananlar

- 2026-10-31 — LG 55UK7550 (webOS 4.4): PS5 HDMI görüntüsü uygulama içinde tam ekran geliyor,
  yerel ağdan gönderilen altyazı oyun görüntüsünün üstünde görünüyor.

## Öğrenilenler

- **Sayfa şeffaf olmalı.** webOS HDMI görüntüsünü sayfanın altındaki ayrı bir katmanda çiziyor.
- **PS5 girişi otomatik bulunuyor.** `luna://com.webos.service.eim/getAllInputStatus` TV'nin giriş
  listesini veriyor; PS5 `spdSourceDeviceInfo: "GAME"` ve `label: "PlayStation 5"` ile görünüyor.
  webOS 4.4'te ek izin (ACG) gerekmedi; yeni sürümlerde gerekebilir.
- **Uygulama arka plana düşebiliyor.** PS5 açılınca TV kendiliğinden kendi HDMI girişine geçebiliyor
  (SimpLink / HDMI-CEC). Arka plandaki sayfa donduğu için altyazı basılmıyor; uygulamayı yeniden öne
  getirmek gerekiyor.
- **Key Server kısa süre açık kalıyor.** `ares-novacom --getkey` zamanlaması tutmazsa anahtar
  `http://TV_IP:9991/webos_rsa` adresinden indirilip `~/.ssh/tv_webos` olarak kaydedilebilir, sonra
  `ares-setup-device --modify tv --info "{'privatekey':'tv_webos','passphrase':'KOD'}"`.

- **Okuyucu ölçümleri (Apple Silicon Mac, macOS 27).** Yazı tanıma ilk çalıştırmada modeli bir kez
  derliyor (~34 sn); sonra kare başına 0,1–0,6 sn. Çeviri ilk cümlede ~4 sn, sonra 0,7–1 sn.
  Altyazı iki kare üst üste aynı okununca gönderiliyor (daktilo efektinde metin tamamlanınca gider).
- **Komut satırında ekran yakalama** için önce `CGMainDisplayID()` çağrılmalı; yoksa
  `CGS_REQUIRE_INIT` ile çöküyor. Uygulama adları sistem diline göre değiştiği için (Preview →
  "Önizleme") pencere paket kimliğiyle de aranıyor.

## Geliştirme aracı

`ares-inspect -d tv -a com.ps5altyazi.test` açıkken TV'deki uygulamada uzaktan JavaScript çalıştırmak için:

```bash
node araclar/tv-eval.mjs "document.visibilityState"
```
