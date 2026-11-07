CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir ve isterseniz Türkçe seslendirir.

**İndir:** [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (kurulum)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe)

**Bu sürümde yeni**

- **Windows'ta İngilizce yazı tanıma paketi uyarısı.** Paket yüklü değilse Windows altyazıyı Türkçe okuyordu ("T hıs", "NiÖlence") ve çeviri anlamsızlaşıyordu. CouchSubs artık bunu ana ekranda söyler; **Yazı tanımayı kur** düğmesi paketi Windows'un izniyle kurar.
- **Menü, gösterge ve kumanda ipuçları altyazıya karışmıyor.** Durdurma menüsü ("MAP / HELP / SETTINGS"), "PHOTO MODE L1 + R1", "23m" mesafe işareti ve satır başına yapışan sayılar çevrilmez. TV'deki koyu kutu yalnız altyazının kendisini kaplar.
- **Dublaj yazının gerisinde kalmıyor.** Yeni altyazı gelince eski cümlenin sesi kesilir, sıra hemen yeni altyazıya geçer.
- **Windows'ta altyazı alanı fareyle çiziliyor** ve ek bölgeler (görev paneli, notlar) Num 1/2/3 ile bir kez okunup çevriliyor; Num 0 canlı altyazıyı duraklatır. Katkı: [sadumqn](https://github.com/sadumqn).
- **Samsung'da eski kurulum yeni sürümü engellemiyor.** Başka sertifikayla kurulmuş eski uygulama kaldırılıp yeniden kurulur ("Author certificate not match").
- TV uygulaması 0.9.4.

**beta.13'te gelenler:** parlak sahnede doğru okuma, üst üste binen ve boş kalan kutuların kalkması, kurulum hatasında TV'nin verdiği sebep.

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

New beta. Windows now warns when the English text recognition pack is missing (it was reading English subtitles as Turkish, which garbled translations) and installs it with one button. Menus, gauges, distance markers and button prompts no longer mix into subtitles, and the TV box covers only the subtitle. Dubbing is cut when a new subtitle arrives so it never lags behind. Windows gets mouse-drawn areas and extra regions (Num 1/2/3, Num 0 pause) contributed by sadumqn. Samsung reinstalls over an old copy signed with another certificate. TV app 0.9.4. Download: [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (installer)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe).
