# CouchSubs TV uygulamasını kurma

TV uygulamaları henüz mağazalarda yok. Kurmak için TV'nizde geliştirici modunu açmanız gerekir. Bu ücretsizdir ve
TV'ye zarar vermez. Önce TV'nizin hangi gruba girdiğine bakın:

| TV | Durum | Rehber |
|---|---|---|
| **LG** (webOS 4 ve üstü) | Gerçek TV'de denendi. CouchSubs TV uygulamasını kendisi kurar | [LG](#lg-tv) |
| **Samsung** (Tizen) | Gerçek TV'de henüz denenmedi. Kendi Samsung sertifikanız gerekir | [Samsung](#samsung-tv) |
| **Android TV / Google TV** (Vestel, Arçelik, Beko, Grundig, Philips ve diğerleri) | Gerçek TV'de henüz denenmedi | [Android TV](#android-tv--google-tv) |
| **Vestel, Arçelik, Beko, Grundig'in Linux modelleri, Philips Saphi ve Titan OS** | Desteklenmiyor: bu TV'lere uygulama kurmanın bir yolunu bulamadık | |

**TV'm Android mi?** Ana ekranda Google Play Store ya da Google TV yazıyorsa Android'dir. Üreticinin kendi uygulama
mağazası varsa ve Play Store yoksa büyük olasılıkla değildir.

Bilgisayar ve TV aynı ev ağında olmalıdır.

## LG TV

### 1. LG geliştirici hesabı açın

1. Bilgisayardan [webostv.developer.lge.com](https://webostv.developer.lge.com) adresine gidin.
2. Sağ üstten **SIGN IN**, ardından **Create Account** seçin ve ücretsiz hesap açın.

### 2. TV'de geliştirici modunu açın

1. TV'nin internete bağlı olduğundan emin olun.
2. TV'de LG Content Store'u açın, **Developer Mode** diye aratıp uygulamayı kurun.
3. Developer Mode uygulamasını açın, hesabınızın e-postası ve şifresiyle giriş yapın.
4. **Dev Mode Status**'u açın. TV yeniden başlar.

### 3. CouchSubs'ın TV uygulamasını kurmasını sağlayın

1. Bilgisayarda CouchSubs'ı açın. Kurulumdaki TV adımında TV'nizi seçip **Bağlan**'a basın, TV'deki izni onaylayın.
2. TV'de Developer Mode uygulamasını yeniden açın ve **Key Server**'ı açın. Uygulamayı ekranda bırakın.
3. TV ekranının sol altında 6 karakterli **Passphrase** görünür. Büyük ve küçük harfe dikkat ederek CouchSubs'a yazın.
4. **TV'ye kur**'a basın.

Parola yalnız bir kez sorulur. Yeni sürümleri CouchSubs, çeviriyi başlattığınızda kendisi kurar.

### Süreyi uzatın

Developer Mode uygulamasındaki **Remain Session** kalan süreyi gösterir (en çok 1000 saat). Süre dolmadan TV internete
bağlıyken **EXTEND**'e basın. Süre dolarsa geliştirici modu kapanır ve TV uygulaması silinir; süre dolduktan sonra
uzatılamaz, baştan kurmanız gerekir. TV internetsiz 10 kez yeniden başlarsa da aynısı olur.

Modu kapatıp yeniden açarsanız TV yeni anahtar üretir ve parola bir kez daha sorulur.

### Elle kurulum

Otomatik kurulum çalışmazsa [Node.js](https://nodejs.org) kurup Terminal'de (Windows'ta PowerShell'de):

```bash
npm install -g @webos-tools/cli
ares-setup-device --add tv --info "{'host':'TV_IP_ADRESI','port':'9922','username':'prisoner'}"
ares-novacom --device tv --getkey
ares-install -d tv com.couchsubs.tv_0.7.0_all.ipk
```

Paketi [Sürümler](https://github.com/yorulmazsinan/couchsubs/releases) sayfasından indirin.

## Samsung TV

Samsung, uygulamanın her TV için ayrı imzalanmasını ister. Bu yüzden CouchSubs kurulumu sizin yerinize yapamaz ve
adımlar LG'den uzundur. Gerçek TV'de henüz denenmedi; sorun olursa
[Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından yazın.

### 1. TV'de geliştirici modunu açın

1. TV'de **Uygulamalar** ekranını açın.
2. Kumandayla ya da ekran klavyesiyle `12345` yazın. Geliştirici modu penceresi açılır.
3. **Developer mode**'u **On** yapın.
4. Bilgisayarınızın IP adresini yazıp **OK**'e basın.
5. TV'yi yeniden başlatın. Uygulamalar ekranında **Develop Mode** yazısı görünür.

### 2. Bilgisayarı hazırlayın

1. [Tizen Studio](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/installing-tv-sdk.html)'yu ve
   Package Manager'dan **Samsung Certificate Extension**'ı kurun.
2. **Tools › Device Manager**'dan TV'yi IP adresiyle ekleyip bağlanın.
3. **Tools › Certificate Manager**'dan **Samsung** türünde sertifika profili oluşturun ve Samsung hesabınızla giriş yapın.
   Distributor sertifikasına Device Manager'daki TV'nin DUID'ini ekleyin.

### 3. Uygulamayı imzalayıp kurun

[Sürümler](https://github.com/yorulmazsinan/couchsubs/releases) sayfasından `CouchSubs-samsung-kaynak.zip` dosyasını bir klasöre açın ve:

```bash
tizen package -t wgt -s SERTIFIKA_PROFILI -- KLASOR
tizen install -n KLASOR/CouchSubs.wgt -t TV_ADI
```

### 4. Bağlayın

CouchSubs'ın TV adımında Samsung TV'nizi seçip **Bağlan**'a basın ve TV'deki izni onaylayın. Uygulama açılmazsa TV'den
kendiniz açın; bilgisayarı ağda kendisi bulur.

## Android TV / Google TV

Gerçek TV'de henüz denenmedi. Bazı TV'ler HDMI görüntüsünü başka uygulamaya vermeyebilir; böyle bir durumda altyazılar
görünür ama arkası siyah kalır. Lütfen [Issues](https://github.com/yorulmazsinan/couchsubs/issues) sayfasından
TV modelinizle birlikte yazın.

### 1. TV'de bilinmeyen kaynağa izin verin

1. **Ayarlar › Cihaz Tercihleri › Hakkında**'ya girin (Google TV'de **Ayarlar › Sistem › Hakkında**).
2. **Yapı numarası**'nın üstünde Tamam tuşuna 7 kez basın. "Geliştiricisiniz" uyarısı çıkar.
3. **Ayarlar › Uygulamalar › Güvenlik ve kısıtlamalar › Bilinmeyen kaynaklar**'dan dosya yöneticisine izin verin.

Menü adları markaya göre biraz değişebilir.

### 2. Uygulamayı kurun

1. [Sürümler](https://github.com/yorulmazsinan/couchsubs/releases) sayfasından `CouchSubs-androidtv.apk` dosyasını indirin.
2. Dosyayı bir USB belleğe kopyalayıp TV'ye takın.
3. TV'de dosya yöneticisiyle dosyayı açıp kurun. TV'nizde dosya yöneticisi yoksa Play Store'dan ücretsiz birini kurun.

Yeni sürüme geçerken önce eski CouchSubs'ı TV'den kaldırın. Paket şimdilik geçici bir imza taşıdığı için üzerine kurulmaz.

### 3. Bağlayın

1. CouchSubs'ın TV adımında **Android TV / Google TV**'yi seçin.
2. TV'de CouchSubs'ı açın. Bilgisayarı ağda kendisi bulur.
3. Görüntü gelmezse Tamam ile paneli açıp sol ve sağ tuşlarıyla doğru HDMI girişini seçin.
