#!/usr/bin/env bash
# Prüft die ausgelieferte APK kryptografisch und per Manifest/Badging.
# Aufruf: bash tools/verify_android_apk.sh [APK]
set -euo pipefail

APK="${1:-F:/banger-queens.apk}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${ANDROID_SDK_ROOT:-/c/Users/HP/AppData/Local/Android/Sdk}"
BT="${ANDROID_BUILD_TOOLS:-$SDK/build-tools/36.1.0}"
JDK="$HERE/.tools/jdk17"
OUT="$HERE/build/verify"
mkdir -p "$OUT"

[ -f "$APK" ] || { echo "FEHLER: APK fehlt: $APK" >&2; exit 1; }
[ -f "$BT/apksigner.bat" ] || { echo "FEHLER: apksigner fehlt: $BT" >&2; exit 1; }
[ -f "$BT/aapt.exe" ] || { echo "FEHLER: aapt fehlt: $BT" >&2; exit 1; }
[ -f "$BT/zipalign.exe" ] || { echo "FEHLER: zipalign fehlt: $BT" >&2; exit 1; }

export JAVA_HOME="$JDK"
export PATH="$JDK/bin:$PATH"

SIG="$OUT/apk-signature.txt"
BADGING="$OUT/apk-badging.txt"
ALIGN="$OUT/apk-zipalign.txt"

"$BT/apksigner.bat" verify --verbose --print-certs "$APK" > "$SIG"
"$BT/aapt.exe" dump badging "$APK" > "$BADGING"
"$BT/zipalign.exe" -c -v 4 "$APK" > "$ALIGN"

grep -q "Verifies" "$SIG" || { echo "FEHLER: apksigner meldet keine gültige Signatur." >&2; exit 1; }
grep -q "Verified using v2 scheme (APK Signature Scheme v2): true" "$SIG" || { echo "FEHLER: APK-Signature-v2 fehlt." >&2; exit 1; }
grep -q "Number of signers: 1" "$SIG" || { echo "FEHLER: Kein eindeutiger Signer." >&2; exit 1; }
grep -q "Signer #1 certificate SHA-256 digest:" "$SIG" || { echo "FEHLER: Zertifikatsdigest fehlt." >&2; exit 1; }

grep -q "^package: name='org.example.kronen' versionCode='9' versionName='1.6.0'" "$BADGING" || { echo "FEHLER: Paketname/Version weicht ab." >&2; exit 1; }
grep -q "^sdkVersion:'24'" "$BADGING" || { echo "FEHLER: minSdk ist nicht 24." >&2; exit 1; }
grep -q "^targetSdkVersion:'35'" "$BADGING" || { echo "FEHLER: targetSdk ist nicht 35." >&2; exit 1; }
grep -q "^launchable-activity: name='com.godot.game.GodotApp'" "$BADGING" || { echo "FEHLER: Einstiegs-Activity fehlt." >&2; exit 1; }
grep -q "native-code: 'arm64-v8a' 'armeabi-v7a'" "$BADGING" || { echo "FEHLER: Erwartete ABIs fehlen." >&2; exit 1; }

CERT=$(grep -m1 "Signer #1 certificate SHA-256 digest:" "$SIG" | sed 's/.*: //' | tr -d '\r')
PKG=$(grep -m1 "^package:" "$BADGING" | tr -d '\r')
SDK_LINE=$(grep -m1 "^sdkVersion:" "$BADGING" | tr -d '\r')
TARGET_LINE=$(grep -m1 "^targetSdkVersion:" "$BADGING" | tr -d '\r')
ACTIVITY=$(grep -m1 "^launchable-activity:" "$BADGING" | tr -d '\r')
ABIS=$(grep -m1 "^native-code:" "$BADGING" | tr -d '\r')
SIZE=$(stat -c %s "$APK")
HASH=$(sha256sum "$APK" | awk '{print $1}')

echo "ANDROID_APK OK"
echo "APK=$APK"
echo "SIZE=$SIZE"
echo "SHA256=$HASH"
echo "CERT_SHA256=$CERT"
echo "PACKAGE=$PKG"
echo "MIN_SDK=$SDK_LINE"
echo "TARGET_SDK=$TARGET_LINE"
echo "ACTIVITY=$ACTIVITY"
echo "ABIS=$ABIS"
echo "SIGNATURE_SCHEME=V2"
echo "ZIPALIGN=ok"
echo "REPORT_DIR=$OUT"
