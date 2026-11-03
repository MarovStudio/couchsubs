# Samsung TV (Tizen) uygulaması

Durum: uygulama yazıldı, tarayıcıda sahte Tizen arayüzüyle denendi. **Gerçek Samsung TV'de denenmedi.** Kurulum
adımları: [tv-kurulum.md](tv-kurulum.md#samsung-tv).

## Yapı

Arayüz kodu LG ile ortaktır (`tv-webos/`). Samsung'a özgü olanlar `tv-tizen/` içindedir:

- `platform.js`: HDMI görüntüsü (`tizen.tvwindow`, `BEHIND`), kumanda tuşları, başlatma parametreleri
- `config.xml`: uygulama kimliği ve izinler

`./scripts/package-tizen.sh` bunları `dist/tv-tizen/app` altında toplar.

## Denenecekler

- HDMI görüntüsü altyazının arkasında görünüyor mu, ses geliyor mu?
- Tek bağlı HDMI otomatik seçiliyor mu?
- Sayı ve renk tuşu olmayan kumandada Tamam paneli açıyor, sol ve sağ HDMI girişini değiştiriyor mu?
- Bilgisayardan `ed.apps.launch` ile uygulama açılabiliyor mu? Yeni modellerde çalışmadığını bildirenler var.

## LG'den farkı

Samsung'da paket, TV'nin DUID'ini içeren distributor sertifikasıyla imzalanır. Bu yüzden tek bir paketi herkesin
TV'sine kurmak büyük olasılıkla mümkün değildir. Herkes için asıl yol mağaza yayınıdır (`docs/magaza.md`).
