CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir ve isterseniz Türkçe seslendirir.

**İndir:** [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (kurulum)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe)

**Bu sürümde yeni**

- **Kurulum dosyaları ve otomatik güncelleme.** Windows'ta tek bir `CouchSubs-windows-Setup.exe`: yönetici izni istemeden kurulur, Başlat menüsüne ve masaüstüne kısayol koyar. Mac'te `CouchSubs-macos.dmg`: CouchSubs'ı Uygulamalar klasörüne sürükleyin. Bundan sonra uygulama yeni sürümleri kendisi bulur: Windows'ta ana ekranda **Şimdi güncelle**, Mac'te **CouchSubs › Güncellemeleri denetle…** Önceki sürümü zip'ten kullananların bu sürümü bir kez elle kurması gerekir.
- **Windows'ta Türkçe dublaj.** Mac'teki dublaj Windows'a da geldi: 3 kadın, 3 erkek ses; her karakter kendi sesiyle, duygu cümleden. **Ayarlar › Türkçe dublaj** bölümünden açılır, sesler bir kez indirilir (440 MB). Ses TV'den ya da bilgisayardan çalar.
- **Samsung: PS5 kolu artık düşmez.** Çeviri sürerken CouchSubs Samsung TV'ye birkaç saniyede bir bağlanıp TV'de "uzaktan kumanda bağlandı" bildirimi çıkarıyor, PS5 kolunu kapatıyordu. Artık TV uygulaması bilgisayara bağlıyken TV'ye hiç dokunulmuyor.
- **Samsung kurulumu Windows'ta yarıda kalmaz.** Bazı bilgisayarlarda (ör. Samsung M7 monitör) Samsung girişinden sonra "TV uygulaması kurulamadı" çıkıyordu; sebep, kurulumdan sonra geçici dosyanın silinememesiydi.
- Samsung'un bazı yeni modellerinde (ör. 2025 QN90F) geliştirici modu **Uygulamalar › Uygulama Ayarları** ekranında `12345` ile açılır; rehbere eklendi.

**İndirme**

| Dosya | Ne için |
|---|---|
| `CouchSubs-macos.dmg` | Mac kurulumu (Apple Silicon, macOS 26+) |
| `CouchSubs-windows-Setup.exe` | Windows 10 (2004) / 11 kurulumu, 64 bit |
| `CouchSubs-macos.zip`, `CouchSubs-windows-x64.zip` | Kurulumsuz kullanmak isteyenler için |
| `com.couchsubs.tv_…_all.ipk` | LG TV uygulaması, elle kurmak isteyenler için |
| `CouchSubs-samsung-kaynak.zip` | Samsung TV uygulaması, Tizen Studio ile elle kurmak isteyenler için |
| `CouchSubs-androidtv.apk` | Android TV / Google TV uygulaması, USB bellekle kurmak isteyenler için |
| `appcast.xml`, `releases.win.json`, `*.nupkg` | Uygulama içi güncelleme dosyaları (elle indirmeyin) |
| `SHA256SUMS.txt` | Dosyaların doğrulama özetleri |

**Bilinen durumlar**

- Windows kurulum dosyası imzasız: "Windows bilgisayarınızı korudu" uyarısında **Ek bilgi › Yine de çalıştır**. Uyarı yalnız ilk kurulumda çıkar; güncellemelerde çıkmaz.
- Dublaj yeni: sesin TV'den oyunun sesiyle birlikte çalması her TV'de henüz denenmedi. TV'den ses gelmezse ayarlardan sesi bilgisayara alın ve modelinizi yazın. Oyunun ses ayarlarından konuşma (diyalog) sesini kısın.
- Sesler yapaydır, gerçek kişilere ait değildir: Pocket TTS Turkish (wite-tech, CC BY 4.0), Kyutai'nin pocket-tts programıyla.
- Samsung ve Android TV kurulumu gerçek TV'de henüz az denendi. Sorun olursa TV modelinizle birlikte [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından yazın; Windows'ta günlükler `%LOCALAPPDATA%\CouchSubs` klasöründe (`hata.log`, `remoteplay.log`).
- PS5 aynı anda tek Remote Play bağlantısına izin verdiği için oyun PS Remote Play uygulamasıyla oynanırken CouchSubs kullanılamaz; PS5'in TV'ye HDMI ile bağlı olması gerekir.
- Mağaza sürümleri henüz yok. Vestel, Arçelik, Beko ve Grundig'in Linux modelleri ile Philips Saphi ve Titan OS desteklenmiyor.

---

New beta. Installers and in-app updates: a Windows `Setup.exe` (no admin rights needed) and a Mac DMG; from now on CouchSubs finds new versions and updates itself (zip users need to install this version once by hand). Turkish dubbing now also on Windows. Samsung: the PS5 controller no longer drops while translating, and installing the TV app on Windows no longer fails after Samsung sign-in. Download: [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (installer)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe).
