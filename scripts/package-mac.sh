#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# CouchSubs'ın macOS sürümünü derler ve dist/CouchSubs-<sürüm>-macos.zip olarak paketler.
# DEVELOPER_ID ("Developer ID Application: ...") verilirse imzalar; NOTARY_PROFILE
# (xcrun notarytool store-credentials ile kaydedilmiş profil) da verilirse Apple'a onaylatır.
set -e
setopt pipefail
cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

[[ -f third-party/build/CChiaki.xcframework/Info.plist ]] || ./scripts/build-chiaki-macos.sh

BUILD="$PWD/build/mac"
rm -rf "$BUILD"
mkdir -p build
(cd mac && xcodegen generate --quiet)

SIGN_ARGS=(CODE_SIGN_IDENTITY="-")
if [[ -n "$DEVELOPER_ID" ]]; then
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime")
fi

xcodebuild -project mac/CouchSubs.xcodeproj -scheme CouchSubs -configuration Release \
  -derivedDataPath "$BUILD" "${SIGN_ARGS[@]}" build > "$BUILD.log" 2>&1 \
  || { grep -E "error:" "$BUILD.log" | head -20; echo "Derleme başarısız, ayrıntı: $BUILD.log"; exit 1; }

APP="$BUILD/Build/Products/Release/CouchSubs.app"
[[ -d "$APP" ]] || { echo "Derleme başarısız."; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
mkdir -p dist
ZIP="dist/CouchSubs-$VERSION-macos.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "$DEVELOPER_ID" && -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
  echo "İmzalandı ve onaylandı."
else
  echo "Uyarı: imzasız paket. İlk açılışta Sistem Ayarları › Gizlilik ve Güvenlik › Yine de Aç gerekir."
fi
echo "Hazır: $ZIP"
