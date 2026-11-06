CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir.

**İndir:** [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip)

**Bu sürümde yenilikler**

- **Kurulum çok daha kolay.** TV uygulamasını artık her markada CouchSubs kendisi kuruyor. TV'de geliştirici modunu açmanız yeter; adımları uygulama ekranda gösterir ve TV'yi kendisi bekler.
  - **Samsung:** Tizen Studio, sertifika yöneticisi ve komut satırı gerekmez. Tarayıcıda bir kez Samsung hesabınızla giriş yaparsınız, CouchSubs TV'nize özel imzayı alır ve kurar.
  - **Android TV:** USB bellek gerekmez. TV'de hata ayıklamayı açın, TV'nin sorusuna "İzin ver" deyin; CouchSubs uygulamayı ağ üzerinden kurar.
  - **LG:** geliştirici modunun 1000 saatlik süresini CouchSubs her kullanışınızda kendisi baştan başlatır.
- **Tek tıkla indirme.** Dosya adları artık sürüm numarası taşımıyor; yukarıdaki bağlantılar hep en son sürümü indirir.

**İndirme**

| Dosya | Ne için |
|---|---|
| `CouchSubs-macos.zip` | Mac (Apple Silicon, macOS 26+) |
| `CouchSubs-windows-x64.zip` | Windows 10 (2004) / 11, 64 bit |
| `com.couchsubs.tv_…_all.ipk` | LG TV uygulaması, elle kurmak isteyenler için |
| `CouchSubs-samsung-kaynak.zip` | Samsung TV uygulaması, Tizen Studio ile elle kurmak isteyenler için |
| `CouchSubs-androidtv.apk` | Android TV / Google TV uygulaması, USB bellekle kurmak isteyenler için |
| `SHA256SUMS.txt` | Dosyaların doğrulama özetleri |

**Bilinen durumlar**

- Samsung ve Android TV kurulumu gerçek TV'de henüz denenmedi. Sorun olursa TV modelinizle birlikte [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından yazın; elle kurulum yolları [rehberde](https://github.com/yorulmazsinan/couchsubs/blob/main/docs/tv-kurulum.md) duruyor.
- Samsung'da geliştirici modunda girilen bilgisayar adresi değişirse TV bilgisayarı tanımaz; adresi yeniden girin.
- Android TV paketi geçici imzalı: CouchSubs eski kopyayı gerekirse kendisi kaldırıp yenisini kurar.
- Windows sürümü henüz gerçek bir bilgisayarda denenmedi. Paket imzasız: "Windows bilgisayarınızı korudu" uyarısında **Ek bilgi › Yine de çalıştır**. İlk açılışta çeviri modeli için yaklaşık 530 MB indirilir.
- Mağaza sürümleri henüz yok. Vestel, Arçelik, Beko ve Grundig'in Linux modelleri ile Philips Saphi ve Titan OS desteklenmiyor.

Sorunları [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından bildirebilirsiniz.

---

New beta. Setup is much simpler: CouchSubs now installs the TV app on every supported TV by itself. Samsung needs a one-time Samsung account sign-in instead of Tizen Studio; Android TV installs over the network instead of a USB stick; on LG, CouchSubs restarts the 1000-hour developer mode session each time you use it. Download links no longer change between versions: [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip). Samsung and Android TV installs are not tested on real TVs yet. Setup: see the [README](https://github.com/yorulmazsinan/couchsubs#english).
