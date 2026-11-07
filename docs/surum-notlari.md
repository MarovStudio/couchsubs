CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir. Bu sürümle Mac'te Türkçesini sesli de okur.

**İndir:** [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip)

**Bu sürümde yeni**

- **Türkçe dublaj (Mac, deneme).** Çeviri Türkçe seslendirilir: 3 kadın, 3 erkek ses. Altyazıda konuşmacı adı varsa ("KRATOS:") her karakter oyun boyunca kendi sesiyle konuşur; karşılıklı konuşmalar iki ayrı sesle okunur. Duygu cümleden seçilir (kızgın, üzgün, şaşkın, sakin, mutlu). Ses TV'den ya da Mac'ten çalar. **Ayarlar › Türkçe dublaj** bölümünden açılır; sesler ilk kullanımda bir kez indirilir (440 MB). Oyunun ses ayarlarından konuşma (diyalog) sesini kısın, müzik ve efektler kalsın. Windows'a da geliyor.
- **Windows'ta LG kurulumu düzeldi.** Bazı bilgisayarlarda TV uygulaması kurulduğu hâlde "TV'de sürüm görünmedi" hatası çıkıyordu. CouchSubs artık TV'ye Windows'un ssh aracı yerine kendi içinden bağlanıyor.
- TV uygulaması 0.9.0 oldu (LG, Samsung, Android TV): bilgisayardan gelen dublaj sesini çalar. CouchSubs açılınca TV'deki uygulamayı kendisi günceller.

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

- Dublaj yeni: sesin TV'den oyunun sesiyle birlikte çalması her TV'de henüz denenmedi. TV'den ses gelmezse ayarlardan **Bu Mac**'i seçin ve modelinizi yazın.
- Sesler yapaydır, gerçek kişilere ait değildir: Pocket TTS Turkish (wite-tech, CC BY 4.0), Kyutai'nin pocket-tts programıyla.
- Altyazının yeri, oyunun altyazısı ekrandayken okunur. Oyun altyazıyı çok kısa gösterirse çeviri bir an sabit yerde görünebilir.
- Samsung ve Android TV kurulumu gerçek TV'de henüz az denendi. Sorun olursa TV modelinizle birlikte [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından yazın; elle kurulum yolları [rehberde](https://github.com/yorulmazsinan/couchsubs/blob/main/docs/tv-kurulum.md) duruyor.
- Windows paketi imzasız: "Windows bilgisayarınızı korudu" uyarısında **Ek bilgi › Yine de çalıştır**. İlk açılışta çeviri modeli için yaklaşık 530 MB indirilir.
- PS5 aynı anda tek Remote Play bağlantısına izin verdiği için oyun PS Remote Play uygulamasıyla oynanırken CouchSubs kullanılamaz; PS5'in TV'ye HDMI ile bağlı olması gerekir.
- Mağaza sürümleri henüz yok. Vestel, Arçelik, Beko ve Grundig'in Linux modelleri ile Philips Saphi ve Titan OS desteklenmiyor.

---

New beta. Turkish dubbing on Mac (preview): the translation is read aloud with 3 female and 3 male synthetic voices; each named character keeps its own voice, and the emotion follows the line. It plays on the TV or the Mac; turn it on in Settings › Turkish dubbing (voices download once, 440 MB). Windows: installing the LG TV app no longer fails with "version did not appear". TV app 0.9.0 (LG, Samsung, Android TV); CouchSubs updates it by itself. Download: [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip).
