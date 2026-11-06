CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir.

**İndir:** [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip)

**Bu sürümde düzeltilenler**

- **Windows'ta program açılmıyordu.** Pencere simgesi pakete eklenmemişti; düzeldi. Bildiren herkese teşekkürler.
- **Windows'ta PSN girişi sırasında çökme** (`BrowserMetrics… is denied`) düzeldi. Giriş başarılı olsa bile çökme yüzünden sonuç kayboluyordu.
- **TV oyun oynarken uykuya geçiyordu.** Oyun kumandayla oynandığı için TV kendini boşta sanıp ekran koruyucuyu açıyor, sonra uykuya geçiyordu. LG ve Samsung TV uygulaması (0.7.1) artık buna izin vermiyor. CouchSubs açılınca TV'deki uygulamayı kendisi günceller.
- **Samsung TV ağda bulunamıyordu.** TV araması artık bilgisayarın her ağ bağlantısından yapılıyor (VPN ya da sanal ağ bağdaştırıcısı olan bilgisayarlarda istek TV'ye gitmiyordu). TV yine yanıt vermezse ev ağı taranıp Samsung TV bulunuyor.
- **Hatalar artık görünür.** Beklenmeyen bir hata olursa program kapanmak yerine pencerede gösteriyor ve `%LOCALAPPDATA%\CouchSubs\hata.log` dosyasına yazıyor (Windows). TV kurulumu başarısız olursa ayrıntısı da bu dosyaya yazılıyor; sorun bildirirken eklerseniz çok yardımcı olur.

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

- Windows'ta LG TV'ye kurulum bazı bilgisayarlarda "TV uygulaması kurulamadı" diyor; nedenini arıyoruz. Bu sürüm ayrıntıyı `hata.log` dosyasına yazıyor, dosyayı [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasına eklerseniz hızla çözeriz. Mac'te LG kurulumu sorunsuz.
- Ekran koruyucuyu engelleme LG'de TV'nin güç servisine yanıt vererek, Samsung'da Samsung'un resmî API'siyle yapılıyor; bazı eski modellerde çalışmayabilir. TV yine uykuya geçerse modelinizi yazın.
- Samsung ve Android TV kurulumu gerçek TV'de henüz az denendi. Sorun olursa TV modelinizle birlikte [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından yazın; elle kurulum yolları [rehberde](https://github.com/yorulmazsinan/couchsubs/blob/main/docs/tv-kurulum.md) duruyor.
- Windows paketi imzasız: "Windows bilgisayarınızı korudu" uyarısında **Ek bilgi › Yine de çalıştır**. İlk açılışta çeviri modeli için yaklaşık 530 MB indirilir.
- PS5 aynı anda tek Remote Play bağlantısına izin verdiği için oyun PS Remote Play uygulamasıyla oynanırken CouchSubs kullanılamaz; PS5'in TV'ye HDMI ile bağlı olması gerekir.
- Mağaza sürümleri henüz yok. Vestel, Arçelik, Beko ve Grundig'in Linux modelleri ile Philips Saphi ve Titan OS desteklenmiyor.

---

New beta. Fixes: the Windows app did not open (missing window icon); a crash after PSN sign-in on Windows; the TV going to screen saver and sleep during play (LG and Samsung TV app 0.7.1; CouchSubs updates it by itself); Samsung TVs not being found on some networks (search now goes out on every network adapter and falls back to scanning the home network). Errors are now shown instead of the app closing silently, and written to `%LOCALAPPDATA%\CouchSubs\hata.log` on Windows. Known issue: LG install from Windows fails on some PCs; please attach `hata.log` to an issue. Download: [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip).
