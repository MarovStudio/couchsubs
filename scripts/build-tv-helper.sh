#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Mac uygulamasına gömülen Samsung ve Android TV kurulum yardımcısını (windows/src/CouchSubs.TvHelper) Native AOT ile
# derler: dist/tv-helper/couchsubs-tv-helper. Ardından XML imzasının AOT ile çalıştığını sınar.
set -e
setopt pipefail
cd "${0:A:h}/.."

OUT=dist/tv-helper
rm -rf "$OUT"
dotnet publish windows/src/CouchSubs.TvHelper -c Release -r osx-arm64 -o "$OUT" -nologo -v q
# Hata ayıklama sembolleri pakete girmesin.
rm -rf "$OUT"/*.dSYM(N) "$OUT"/*.dbg(N) "$OUT"/*.pdb(N)
[[ -x "$OUT/couchsubs-tv-helper" ]] || { echo "Yardımcı derlenemedi."; exit 1; }
# Homebrew'un kaynaktan derlenmiş .NET'i Homebrew kitaplıklarına bağlar; öyle bir dosya başka Mac'te açılmaz.
# Yayın derlemesi Microsoft'un .NET'iyle (actions/setup-dotnet) yapılır. Yerel sınama için ALLOW_LOCAL_LIBS=1.
if otool -L "$OUT/couchsubs-tv-helper" | grep -q /opt/homebrew && [[ -z "$ALLOW_LOCAL_LIBS" ]]; then
  echo "Yardımcı Homebrew kitaplıklarına bağlı; Microsoft'un .NET SDK'sıyla derleyin."; exit 1
fi
"$OUT/couchsubs-tv-helper" self-test | grep -q '"event":"done"' || { echo "Yardımcı sınaması başarısız."; exit 1; }
echo "Hazır: $OUT/couchsubs-tv-helper ($(du -h "$OUT/couchsubs-tv-helper" | cut -f1))"
