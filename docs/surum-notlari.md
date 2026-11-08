CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir ve isterseniz Türkçe seslendirir.

**İndir:** [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (kurulum)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe)

**Bu sürümde yeni**

- **Daha doğru çeviri.** Windows'taki çeviri modeli artık her cümle için birkaç çeviriyi birlikte dener ve en iyisini seçer ("Bu yer hakkında bir şeyler yanlış" yerine "Bu yerde bir terslik var").
- **Oyun ifadeleri doğru çevriliyor.** "They're friendlies", "I've got your six", "Heads up", "Lock and load", "Took you long enough" gibi kelime kelime çevrilince saçmalayan ifadeler artık anlamıyla çevrilir ("Onlar dost canlısı" değil "Onlar müttefik"; "Altını aldım" değil "Arkanı kollarım"). Mac'te de geçerli.
- **İsteğe bağlı DeepL çevirisi (Mac ve Windows).** Ayarlar › **Çevrimiçi çeviri (DeepL)** kartına kendi ücretsiz DeepL anahtarınızı girerseniz çeviriler DeepL'le yapılır. Ücretsiz anahtar ayda 500.000 karakter verir, uzun bir oyuna yeter. Önceki altyazı bağlam olarak gider, oyun dili "siz" değil "sen"dir. DeepL'e ulaşılamazsa ya da sınır dolarsa bilgisayardaki model kaldığı yerden devam eder. Açmazsanız hiçbir şey internete gitmez.
- **Windows'ta hızlı Türkçe ses.** Dublaj ayarında **Ses: Doğal / Hızlı** seçimi var. Hızlı ses Windows'un kendi Türkçe sesini kullanır: indirme gerekmez, cümle anında okunur ve altyazıyla birlikte gelir. Doğal ses daha insansıdır ama daha geç başlar. Karakterlere göre ses tonu yine ayrılır.

**beta.14'te gelenler:** Windows'ta İngilizce yazı tanıma paketi uyarısı ve tek düğmeyle kurulumu, menü/gösterge/kumanda ipuçlarının altyazıya karışmaması, yeni altyazı gelince eski dublaj cümlesinin kesilmesi, fareyle çizilen alan ve Num 1/2/3 ek bölgeler (katkı: [sadumqn](https://github.com/sadumqn)), Samsung'da eski kurulumun yeni sürümü engellememesi, TV uygulaması 0.9.4.

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

New beta. Better translations: the Windows model now weighs several candidate translations per sentence (beam search), common game phrases ("friendlies", "got your six", "heads up", "lock and load") are translated by meaning on Mac and Windows, and you can optionally use your own free DeepL API key for online translation (falls back to the local model when DeepL is unreachable; nothing is sent unless you turn it on). Windows dubbing gets a fast voice option: Windows' own Turkish voice, no download, speaks instantly. Also includes everything from beta.14. Download: [Mac (DMG)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.dmg) · [Windows (installer)](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-Setup.exe).
