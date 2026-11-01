# Gizlilik / Privacy

*Son güncelleme / Last updated: 2026-11-01*

## Türkçe

CouchSubs, Enmera tarafından yayınlanan açık kaynaklı bir uygulamadır. Hiçbir kişisel veriyi toplamaz,
saklamak üzere kendi sunucularımıza göndermez; bizim bir sunucumuz yoktur. Reklam, analiz ya da izleme
kodu içermez.

**Bilgisayarda kalanlar**

- PS5'ten gelen oyun görüntüsü yalnız altyazıyı okumak için bellekte işlenir; kaydedilmez, hiçbir yere
  gönderilmez.
- Okunan altyazılar ve çevirileri bilgisayarda üretilir ve yalnız ev ağınızdaki TV'ye gönderilir.
- PlayStation Network hesap kimliği (sayısal), PS5 eşleme anahtarı ve TV eşleme anahtarı bilgisayarda
  saklanır: Mac'te Anahtar Zinciri'nde, Windows'ta yalnız sizin kullanıcı hesabınızın açabileceği
  şifreli bir dosyada (DPAPI).

**Dışarıyla kurulan bağlantılar**

- **Sony:** PlayStation Network girişi doğrudan Sony'nin sayfasında yapılır; şifrenizi CouchSubs görmez.
  Girişten sonra Sony'den yalnız hesap kimliği alınır, oturum anahtarı saklanmaz.
- **Hugging Face (yalnız Windows):** ilk açılışta çeviri modeli `huggingface.co` adresinden bir kez indirilir.
- **Apple (yalnız Mac):** çeviri dilleri macOS tarafından indirilir ve yönetilir.
- **Ev ağı:** PS5 ve LG TV'yi bulmak ve onlarla eşleşmek için yalnız yerel ağ kullanılır.

TV uygulaması altyazıları yalnız ev ağındaki CouchSubs bilgisayarından alır ve internete bağlanmaz.

Sorularınız için: https://github.com/yorulmazsinan/couchsubs/issues

## English

CouchSubs is open-source software published by Enmera. It does not collect personal data and does not
send any data to servers of ours (we do not operate any). It contains no advertising, analytics or
tracking code.

**Stays on your computer:** the game picture received from the PS5 is processed in memory only to read
subtitles and is never stored or uploaded. Subtitles and translations are produced on your computer and
sent only to the TV on your home network. Your numeric PlayStation Network account ID and the PS5 and TV
pairing keys are stored locally (Keychain on Mac; a file encrypted for your Windows user account with
DPAPI on Windows).

**External connections:** PlayStation Network sign-in happens on Sony's own page, and CouchSubs never sees
your password; afterwards only the account ID is requested from Sony, and no session token is kept. On
Windows, the translation model is downloaded once from `huggingface.co`. On Mac, translation languages are
downloaded and managed by macOS. PS5 and TV discovery and pairing use your local network only.

The TV app receives subtitles only from the CouchSubs computer on your home network and does not connect
to the internet.

Contact: https://github.com/yorulmazsinan/couchsubs/issues
