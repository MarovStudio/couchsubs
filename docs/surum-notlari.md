CouchSubs'ın yeni deneme sürümü. Türkçe dil desteği olmayan PS5 oyunlarının İngilizce altyazısını okur, Türkçesini TV'de oyunun üstünde gösterir.

**İndir:** [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip)

**Bu sürümde yeni**

- **Çeviri İngilizce altyazının yerine oturur.** CouchSubs oyundaki altyazının ekrandaki yerini okur; Türkçe çeviri TV'de onun üstünü örter. İsterseniz ayarlardan İngilizcenin hemen üstüne, altına ya da eskisi gibi sabit bir yere alabilirsiniz.
- **Kumanda ipuçları çevrilmez.** "R2 Swing", "△ Pick up", "Press ✕ to jump" gibi satırlar artık altyazı sanılıp çevrilmiyor.
- **Karakter adları çevrilmez.** "Kratos:", "ATREUS:" gibi konuşmacı adları olduğu gibi kalıyor; CouchSubs bu adları öğrenip cümle içinde de koruyor.
- **Daha düzgün çeviri.** Alt alta sarılmış satırlar tek cümle olarak çevriliyor; tümü büyük harfli satırlar da düzgün çevriliyor (Mac'te de artık cümle cümle çeviri).
- **Yeni görünüm ayarları:** "Çok büyük" yazı boyutu, arka plan koyuluğu ve kalın yazı.
- TV uygulaması 0.8.0 oldu (LG, Samsung, Android TV). CouchSubs açılınca TV'deki uygulamayı kendisi günceller.

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

- Altyazının yeri, oyunun altyazısı ekrandayken okunur. Oyun altyazıyı çok kısa gösterirse çeviri bir an sabit yerde görünebilir.
- Ekran koruyucuyu engelleme LG'de TV'nin güç servisine yanıt vererek, Samsung'da Samsung'un resmî API'siyle yapılıyor; bazı eski modellerde çalışmayabilir. TV yine uykuya geçerse modelinizi yazın.
- Samsung ve Android TV kurulumu gerçek TV'de henüz az denendi. Sorun olursa TV modelinizle birlikte [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından yazın; elle kurulum yolları [rehberde](https://github.com/yorulmazsinan/couchsubs/blob/main/docs/tv-kurulum.md) duruyor.
- Windows paketi imzasız: "Windows bilgisayarınızı korudu" uyarısında **Ek bilgi › Yine de çalıştır**. İlk açılışta çeviri modeli için yaklaşık 530 MB indirilir.
- PS5 aynı anda tek Remote Play bağlantısına izin verdiği için oyun PS Remote Play uygulamasıyla oynanırken CouchSubs kullanılamaz; PS5'in TV'ye HDMI ile bağlı olması gerekir.
- Mağaza sürümleri henüz yok. Vestel, Arçelik, Beko ve Grundig'in Linux modelleri ile Philips Saphi ve Titan OS desteklenmiyor.

---

New beta. The Turkish translation now sits where the game shows its own subtitle and covers it (or goes just above or below it, or stays at a fixed height, as you choose). Controller hints such as "R2 Swing" are no longer translated, and speaker names such as "Kratos:" are kept as they are. Lines wrapped over two rows are translated as one sentence. New settings: extra-large text, background darkness and bold text. TV app 0.8.0 (LG, Samsung, Android TV); CouchSubs updates it by itself. Download: [Mac](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-macos.zip) · [Windows](https://github.com/yorulmazsinan/couchsubs/releases/latest/download/CouchSubs-windows-x64.zip).
