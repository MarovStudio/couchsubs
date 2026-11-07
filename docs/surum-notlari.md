CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir ve isterseniz Türkçe seslendirir.

**İndir:** [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (kurulum)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe)

**Bu sürümde yeni**

- **Android TV / Google TV'de altyazı yeniden görünüyor.** beta.11'deki boyut düzeltmesi bazı TV'lerde sayfanın yalnızca sol üst çeyreğini gösteriyordu; altyazı ekranın dışında kalıyordu. TV uygulaması 0.9.2 sayfayı ekrana tam sığdırır; yazılar artık iki kat büyük de çıkmaz. CouchSubs açılınca TV'deki uygulamayı kendisi günceller.
- **Yazı boyutu kaydırıcıyla ayarlanıyor.** Dört sabit seçenek yerine Ayarlar › TV'de bölümünde 20–80 arası kaydırıcı var; en küçüğü eski "Küçük"ün yarısı kadar. Sürüklerken TV'de örnek altyazı görünür.
- **Aynı cümle iki kez çıkmıyor.** Süslü yazı tipli ya da solarak kaybolan altyazılarda aynı cümle her okunuşta biraz farklı algılanıp ikinci bir çeviri olarak gösteriliyordu.
- **Anlamsız harfler ayıklanıyor.** Yazı tanımanın bazı sözcükleri çevirdiği "ou$3e", "2aljd" gibi harf, rakam ve simge karışımları artık çevirmene gitmiyor.

**beta.11'de gelenler:** Android TV'de yazı boyutu düzeltmesi. **beta.10'da gelenler:** Windows kurulum dosyası ve Mac DMG, uygulama içi güncelleme, Windows'ta Türkçe dublaj.

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

New beta. Android TV / Google TV: subtitles show again (beta.11's size fix left them off screen on some TVs); TV app 0.9.2. Text size is now a slider (20–80). The same sentence no longer appears twice, and OCR garbage such as "ou$3e" is no longer translated. Download: [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (installer)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe).
