#!/bin/zsh
# TV uygulamasını Mac'in IP adresiyle paketler, LG TV'ye kurar ve açar.
# Önce bir kez: npm install -g @webos-tools/cli  ve  ares-setup-device ile "tv" cihazını ekle.
set -e
cd "${0:A:h}"

DEVICE="${DEVICE:-tv}"
PORT="${PORT:-8787}"
APP_ID="com.ps5altyazi.test"

if ! command -v ares-package >/dev/null; then
  echo "webOS CLI yok. Kur: npm install -g @webos-tools/cli"
  exit 1
fi

IP="${IP:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1)}"
if [[ -z "$IP" ]]; then
  echo "Mac'in yerel IP adresi bulunamadı. IP=192.168.x.x ./kur.sh şeklinde çalıştır."
  exit 1
fi

cat > tv-webos/config.js <<EOF
// kur.sh bu dosyayı Mac'in yerel IP adresiyle yeniden yazar.
window.ALTYAZI_CONFIG = {
  server: 'http://$IP:$PORT',
  hdmi: 1
};
EOF
echo "Sunucu adresi: http://$IP:$PORT"

rm -rf dist && mkdir dist
ares-package tv-webos -o dist
ares-install -d "$DEVICE" dist/*.ipk
ares-launch -d "$DEVICE" "$APP_ID"
echo "Kuruldu ve açıldı."
