#!/bin/zsh
# TV uygulamasını paketler, LG TV'ye kurar ve Mac'in adresini başlatma parametresi olarak vererek açar.
# Önce bir kez: npm install -g @webos-tools/cli  ve  ares-setup-device ile "tv" cihazını ekle.
set -e
cd "${0:A:h}/.."

DEVICE="${DEVICE:-tv}"
PORT="${PORT:-8787}"
APP_ID="com.couchsubs.tv"

if ! command -v ares-package >/dev/null; then
  echo "webOS CLI yok. Kur: npm install -g @webos-tools/cli"
  exit 1
fi

IP="${IP:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1)}"
if [[ -z "$IP" ]]; then
  echo "Mac'in yerel IP adresi bulunamadı. IP=192.168.x.x ./kur.sh şeklinde çalıştır."
  exit 1
fi

echo "Sunucu adresi: http://$IP:$PORT"

rm -rf dist && mkdir dist
ares-package tv-webos -o dist
ares-install -d "$DEVICE" dist/*.ipk
ares-launch -d "$DEVICE" "$APP_ID" --params "{\"server\":\"http://$IP:$PORT\"}"
echo "Kuruldu ve açıldı."
