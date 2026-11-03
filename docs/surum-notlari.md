CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini LG TV'de oyunun üstünde gösterir.

**Bu sürümde yenilikler**

- **TV uygulamasını CouchSubs kuruyor.** TV'de geliştirici modunu açın, ekrandaki parolayı bir kez yazın; sonraki sürümleri de kendisi kurar.
- **TV'nin ağ adresi değişse de bağlantı kopmuyor.** Uygulama TV'yi ağda yeniden bulur.
- **Altyazı daha sık kontrol ediliyor.** Saniyede 20 okuma; altyazı bölgesi değişmediyse yazı tanıma çalışmaz.
- **Mac paketi Apple onaylı.** İlk açılışta ek izin gerekmez.

**İndirme**

| Dosya | Ne için |
|---|---|
| `CouchSubs-…-macos.zip` | Mac (Apple Silicon, macOS 26+) |
| `CouchSubs-…-windows-x64.zip` | Windows 10 (2004) / 11, 64 bit |
| `com.couchsubs.tv_…_all.ipk` | LG TV uygulaması, elle kurmak isteyenler için ([kurulum](https://github.com/yorulmazsinan/couchsubs/blob/main/docs/tv-kurulum.md)) |
| `SHA256SUMS.txt` | Dosyaların doğrulama özetleri |

**Bilinen durumlar**

- Windows sürümü henüz gerçek bir bilgisayarda denenmedi; ilk deneyenlerin geri bildirimi çok değerli.
- Windows paketi imzasız: "Windows bilgisayarınızı korudu" uyarısında **Ek bilgi › Yine de çalıştır**. İlk açılışta çeviri modeli için yaklaşık 530 MB indirilir.
- Yalnız LG TV destekleniyor. Samsung desteği hazırlanıyor, LG mağazası sürümü de henüz yok.
- Geliştirici modu en çok 1000 saat açık kalır; süre dolmadan TV'den uzatın, yoksa TV uygulaması silinir.

Sorunları [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından bildirebilirsiniz.

---

New beta. Reads the English subtitles of PS5 games and shows a Turkish translation on an LG TV, on top of the game. The desktop app now installs the TV app itself once Developer Mode is on. Windows has not been tested on a real PC yet. Setup: see the [README](https://github.com/yorulmazsinan/couchsubs#english).
