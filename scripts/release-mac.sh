#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Sürümün imzalı ve Apple onaylı Mac paketini (zip, DMG, appcast.xml) bu Mac'te üretir.
# Anahtar zincirindeki Developer ID sertifikasını ve notarytool profilini (couchsubs) kullanır.
# Kullanım: release-mac.sh <sürümün Android TV APK'sı>
set -e
setopt pipefail
cd "${0:A:h}/.."
[[ -f "$1" ]] || { echo "Kullanım: $0 <CouchSubs-androidtv.apk>"; exit 1; }
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export ANDROID_APK="${1:A}"
export DEVELOPER_ID="Developer ID Application: ENMERA YAZILIM EGITIM REKLAM DANISMANLIK TICARET LIMITED SIRKETI (79N3CT6T46)"
export NOTARY_PROFILE=couchsubs
~/Projeler/Web/enmera/ekip/heavy-job.sh ./scripts/package-mac.sh
