# CouchSubs TV uygulamasını LG TV'ye kurma

CouchSubs TV uygulaması LG mağazasında yayınlanana kadar TV'ye geliştirici modu ile kurulur. Geliştirici
modunu siz açarsınız, uygulamayı Mac ya da Windows'taki CouchSubs kurar ve sonraki sürümlere kendisi
günceller. Mağaza sürümü çıkınca bu adımlara gerek kalmayacak.

## 1. TV'de geliştirici modu

1. [webostv.developer.lge.com](https://webostv.developer.lge.com) adresinde ücretsiz bir LG geliştirici
   hesabı açın (sağ üstte **Sign In › Create Account**).
2. TV'de LG Content Store'dan **Developer Mode** uygulamasını kurun ve açın.
3. Kullanıcı adı olarak e-posta adresinizi, şifre olarak hesabınızın şifresini girin.
4. **Dev Mode Status**'u açın; TV yeniden başlar.
5. Developer Mode uygulamasını tekrar açın, **Key Server**'ı açın ve **uygulamayı ekranda açık bırakın**
   (başka bir şeye geçince Key Server kapanır). Ekranda TV'nin IP adresi ve bir **Passphrase** görünür.

Geliştirici modu belirli bir süre sonra kapanır; Developer Mode uygulamasından süreyi uzatabilirsiniz.

## 2. Bilgisayarda

1. CouchSubs'ı açın. Kurulumdaki TV adımında TV'nizi seçip **Bağlan**'a basın ve TV'deki izni onaylayın.
2. Ekranda parola sorulunca TV'de Developer Mode uygulamasını açın, **Key Server**'ı açın ve uygulamayı
   ekranda bırakın.
3. TV'de görünen **Passphrase**'i yazıp **TV'ye kur**'a basın.

Parola yalnız bir kez sorulur. Sonraki sürümleri CouchSubs, çeviriyi başlattığınızda kendisi kurar. Kurulumu
tamamladıysanız aynı kart **Ayarlar**'da da görünür. Geliştirici modunu kapatıp yeniden açarsanız TV yeni
anahtar üretir ve parola bir kez daha sorulur.

## Elle kurulum

Otomatik kurulum çalışmazsa [Node.js](https://nodejs.org) kurup Terminal'de (Windows'ta PowerShell'de):

```bash
npm install -g @webos-tools/cli
ares-setup-device --add tv --info "{'host':'TV_IP_ADRESI','port':'9922','username':'prisoner'}"
ares-novacom --device tv --getkey
ares-install -d tv com.couchsubs.tv_0.6.1_all.ipk
```

Paketi [Sürümler](https://github.com/yorulmazsinan/couchsubs/releases/latest) sayfasından indirin.
"Failed to get ssh private key" hatası alırsanız Key Server kapanmıştır: TV'de tekrar açıp komutu hemen
çalıştırın.
