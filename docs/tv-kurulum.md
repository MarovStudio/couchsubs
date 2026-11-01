# CouchSubs TV uygulamasını LG TV'ye kurma

CouchSubs TV uygulaması LG mağazasında yayınlanana kadar TV'ye geliştirici modu ile kurulur. Bunu bir kez
yaparsınız. Mağaza sürümü çıkınca bu adımlara gerek kalmayacak.

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

[nodejs.org](https://nodejs.org) adresinden Node.js'i kurun (Mac'te `brew install node` de olur). Sonra
Terminal'de (Windows'ta PowerShell'de):

```bash
npm install -g @webos-tools/cli
ares-setup-device --add tv --info "{'host':'TV_IP_ADRESI','port':'9922','username':'prisoner'}"
ares-novacom --device tv --getkey
```

Son komut Passphrase'i sorar. "Failed to get ssh private key" hatası alırsanız Key Server kapanmıştır:
TV'de tekrar açıp komutu hemen çalıştırın. Zamanlama tutmazsa Mac'te anahtarı doğrudan indirip
Passphrase'i sonra girebilirsiniz:

```bash
curl -o ~/.ssh/tv_webos http://TV_IP_ADRESI:9991/webos_rsa && chmod 600 ~/.ssh/tv_webos
ares-setup-device --modify tv --info "{'privatekey':'tv_webos','passphrase':'PASSPHRASE'}"
```

## 3. TV uygulamasını kurun

[Sürümler](https://github.com/yorulmazsinan/couchsubs/releases/latest) sayfasından
`com.couchsubs.tv_…_all.ipk` dosyasını indirin ve indirdiğiniz klasörde çalıştırın:

```bash
ares-install -d tv com.couchsubs.tv_0.6.0_all.ipk
```

(Kaynak koddan kuruyorsanız: `ares-package tv-webos -o dist` ve `ares-install -d tv dist/com.couchsubs.tv_*.ipk`.)

Ardından bilgisayarda CouchSubs'ı açın; kurulum sihirbazı TV'yi bulur ve uygulamayı kendisi başlatır.
