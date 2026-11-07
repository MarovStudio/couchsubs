#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Türkçe dublajın ses motoru: Kyutai'nin pocket-tts programı (MIT, https://github.com/kyutai-labs/pocket-tts).
# Sabit sürüm indirilir, özeti denetlenir: dist/tts/pocket-tts (Mac, Apple Silicon) ya da pocket-tts.exe (Windows).
# Kullanım: fetch-pocket-tts.sh [mac|windows]
set -e
setopt pipefail
cd "${0:A:h}/.."

RELEASE=v4.0.1
case "${1:-mac}" in
  mac)
    ASSET=pocket-tts-3.3.0-aarch64-apple-darwin.tar.gz
    SHA=ee9ca6c7c000ee72c5846e3a8ba01d08f56636d94a614d2259c3f12b8fd69afa
    NAME=pocket-tts ;;
  windows)
    ASSET=pocket-tts-3.3.0-x86_64-pc-windows-msvc.zip
    SHA=98753041f2e65744b989776f87bccb93f1f574a08afe1890c5427ec94cd6309c
    NAME=pocket-tts.exe ;;
  *) echo "Kullanım: $0 [mac|windows]"; exit 1 ;;
esac

OUT=dist/tts
rm -rf "$OUT" && mkdir -p "$OUT/indir"
curl -sfL -o "$OUT/indir/$ASSET" "https://github.com/kyutai-labs/pocket-tts/releases/download/$RELEASE/$ASSET"
echo "$SHA  $OUT/indir/$ASSET" | shasum -a 256 -c - > /dev/null || { echo "pocket-tts özeti tutmadı."; exit 1; }
case "$ASSET" in
  *.zip) unzip -q -o "$OUT/indir/$ASSET" -d "$OUT/indir" ;;
  *) tar xzf "$OUT/indir/$ASSET" -C "$OUT/indir" ;;
esac
FOUND=("$OUT"/indir/**/$NAME(N.))
(( ${#FOUND} == 1 )) || { echo "$NAME pakette bulunamadı."; exit 1; }
mv "$FOUND[1]" "$OUT/$NAME"
rm -rf "$OUT/indir"
chmod +x "$OUT/$NAME"
echo "Hazır: $OUT/$NAME ($(du -h "$OUT/$NAME" | cut -f1))"
