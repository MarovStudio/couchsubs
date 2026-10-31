# CouchSubs

**TR** — PS5 oyunlarındaki İngilizce altyazıyı anlık okuyup Türkçesini TV'de oyun görüntüsünün üstünde
gösterir. Oyunu her zamanki gibi TV'de, kendi kolunuzla oynarsınız; çeviri bilgisayarınızda (ileride
telefonunuzda), internete gerek olmadan, cihaz üstünde yapılır.

**EN** — Reads the English subtitles of PS5 games in real time and shows a translation on your TV, on top
of the game picture. You keep playing on the TV with your own controller; text recognition and
translation run on-device on your computer (later your phone), with no internet connection required.

> Geliştirme aşamasında. / Work in progress.

## Nasıl çalışır / How it works

```
PS5 ──HDMI──▶ TV app (HDMI full screen + subtitle layer)
 │                         ▲
 └─Remote Play ──▶ CouchSubs (Mac) ── local network
   (second PSN account)   reads → translates → sends
```

- `core/` — platform-independent logic (subtitle stabilizer, local subtitle server, LG TV pairing)
- `tv-webos/` — LG webOS TV app
- `prototip/` — the original prototype (kept for reference)
- `docs/` — design and plans

## Lisans / License

AGPL-3.0. CouchSubs uses the Remote Play library of [chiaki-ng](https://github.com/chiaki-ng/chiaki-ng)
(AGPL-3.0 with OpenSSL exception).

CouchSubs, Sony Interactive Entertainment ile bağlantılı değildir. "PlayStation" ve "PS5", Sony
Interactive Entertainment Inc.'in ticari markalarıdır. / CouchSubs is not affiliated with Sony Interactive
Entertainment. "PlayStation" and "PS5" are trademarks of Sony Interactive Entertainment Inc.
