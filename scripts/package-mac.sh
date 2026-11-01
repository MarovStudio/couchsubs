#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# CouchSubs'ın macOS sürümünü derler ve dist/CouchSubs-<sürüm>-macos.zip olarak paketler.
# DEVELOPER_ID ("Developer ID Application: ... (TAKIM)") verilirse imzalar; NOTARY_PROFILE
# (xcrun notarytool store-credentials ile kaydedilmiş profil) da verilirse Apple'a onaylatır.
# Profil varsayılan anahtar zincirinde değilse NOTARY_KEYCHAIN ile yolu verilir (CI).
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
  TEAM="${DEVELOPER_ID##*\(}"; TEAM="${TEAM%\)}"
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM"
             OTHER_CODE_SIGN_FLAGS="--timestamp")
fi

xcodebuild -project mac/CouchSubs.xcodeproj -scheme CouchSubs -configuration Release \
  -derivedDataPath "$BUILD" "${SIGN_ARGS[@]}" build > "$BUILD.log" 2>&1 \
  || { grep -E "error:" "$BUILD.log" | head -20; echo "Derleme başarısız, ayrıntı: $BUILD.log"; exit 1; }

APP="$BUILD/Build/Products/Release/CouchSubs.app"
[[ -d "$APP" ]] || { echo "Derleme başarısız."; exit 1; }
if [[ -n "$DEVELOPER_ID" ]]; then
  codesign --verify --deep --strict "$APP" || { echo "İmza doğrulanamadı."; exit 1; }
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
mkdir -p dist
ZIP="dist/CouchSubs-$VERSION-macos.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "$DEVELOPER_ID" && -n "$NOTARY_PROFILE" ]]; then
  KEYCHAIN_ARGS=()
  [[ -n "$NOTARY_KEYCHAIN" ]] && KEYCHAIN_ARGS=(--keychain "$NOTARY_KEYCHAIN")
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" "${KEYCHAIN_ARGS[@]}" --wait \
    | tee "$BUILD-notary.log"
  grep -q "status: Accepted" "$BUILD-notary.log" || { echo "Apple onayı reddedildi, ayrıntı: $BUILD-notary.log"; exit 1; }
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose "$APP"
  rm -f "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
  echo "İmzalandı ve onaylandı."
else
  echo "Uyarı: imzasız paket. İlk açılışta Sistem Ayarları › Gizlilik ve Güvenlik › Yine de Aç gerekir."
fi
echo "Hazır: $ZIP"
