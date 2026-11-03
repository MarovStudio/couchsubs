#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Samsung TV uygulamasını dist/tv-tizen/ altında toplar: ortak dosyalar tv-webos'tan, Tizen'e özgü olanlar
# tv-tizen'den gelir. TV'ye kurmak için Samsung sertifikasıyla imzalanmalıdır (docs/tv-samsung.md).
# TIZEN_PROFILE verilirse Tizen Studio'nun `tizen` aracıyla imzalı .wgt da üretir.
set -e
cd "$(dirname "$0")/.."
OUT=dist/tv-tizen/app
rm -rf dist/tv-tizen
mkdir -p "$OUT"
cp tv-webos/app.js tv-webos/i18n.js tv-webos/config.js tv-webos/index.html tv-webos/style.css tv-webos/largeIcon.png "$OUT/"
cp tv-webos/icon.png "$OUT/panel-icon.png"
cp tv-tizen/platform.js tv-tizen/config.xml tv-tizen/icon.png "$OUT/"
# Panel başlığındaki küçük simge webOS'taki gibi icon.png adını kullanamaz: Tizen'in simgesi büyüktür.
sed 's/src="icon.png"/src="panel-icon.png"/' tv-webos/index.html > "$OUT/index.html"
if [ -n "$TIZEN_PROFILE" ]; then
  tizen package -t wgt -s "$TIZEN_PROFILE" -o dist/tv-tizen -- "$OUT"
  ls dist/tv-tizen/*.wgt
else
  echo "İmzasız kaynak hazır: $OUT (imza için TIZEN_PROFILE verin)"
fi
