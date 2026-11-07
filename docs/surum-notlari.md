CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir ve isterseniz Türkçe seslendirir.

**İndir:** [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (kurulum)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe)

**Bu sürümde yeni**

- **Windows'ta altyazılar daha doğru okunuyor.** Parlak sahnelerde (kum, gökyüzü) beyaz altyazı "CESAREiVJütt'h" gibi okunuyordu. Her kare artık bir de yalnız beyaz yazı bırakılarak okunur, daha anlamlı okuma seçilir.
- **TV'de altyazılar üst üste binmiyor.** Önceki satırı gösteren ikinci kutu kaldırıldı; yeni satır eskisinin yerine geçer. Altyazı yokken kalan boş siyah kutu da çıkmıyor (TV uygulaması 0.9.3).
- **Dublaj altyazıyla birlikte geliyor.** Yeni altyazı gelince eski cümlelerin bekleyen sesleri atlanır; seslendirme işlemciyi altyazı okuma ve çeviriden sonra kullanır.
- **Kurulum hatasında sebep görünüyor.** TV uygulaması kurulamazsa "boş alanı kontrol edin" yerine TV'nin verdiği asıl sebep yazar.
- **Samsung kurulum notları** [TV kurulum rehberine](https://github.com/yorulmazsinan/couchsubs/blob/main/docs/tv-kurulum.md#samsung-tv) eklendi.

**beta.12'de gelenler:** Android TV'de altyazının yeniden görünmesi, yazı boyutu kaydırıcısı, aynı cümlenin iki kez çıkmaması, anlamsız harflerin ayıklanması.

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

New beta. Windows reads subtitles on bright scenes much better (each frame is also read with only the white text kept). The TV no longer shows two overlapping boxes or an empty black box (TV app 0.9.3). Dubbing stays with the subtitle instead of lagging behind. A failed TV install now shows the TV's own reason. Download: [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (installer)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe).
