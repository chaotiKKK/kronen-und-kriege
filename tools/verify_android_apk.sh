#!/usr/bin/env bash
# Prüft die ausgelieferte APK kryptografisch und per Manifest/Badging.
# Aufruf: bash tools/verify_android_apk.sh [APK]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FEHLER: $*" >&2; exit 1; }
[ "$#" -le 1 ] || fail "Aufruf: bash tools/verify_android_apk.sh [APK]"
PYTHON_EXE="${BQ_PYTHON:-python}"
command -v "$PYTHON_EXE" >/dev/null || fail "Python fehlt: $PYTHON_EXE (überschreibbar mit BQ_PYTHON)"
# Die erwartete Androididentität stammt aus dem tatsächlich benutzten Preset.
mapfile -t SETTINGS < <("$PYTHON_EXE" - "$HERE" <<'PY'
import configparser, json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
config = configparser.ConfigParser(interpolation=None)
config.read(root / 'export_presets.cfg', encoding='utf-8-sig')
presets = [s for s in config.sections() if re.fullmatch(r'preset\.\d+', s)
           and json.loads(config[s].get('platform', '""')) == 'Android']
if len(presets) != 1:
    raise ValueError('Expected one Android export preset')
options = config[presets[0] + '.options']
version = json.loads(options['version/name'])
code = int(options['version/code'])
package = json.loads(options['package/unique_name'])
if not re.fullmatch(r'\d+\.\d+\.\d+', version) or code <= 0 or not re.fullmatch(r'[A-Za-z0-9_.]+', package):
    raise ValueError('Invalid Android package identity/version')
project_version = re.search(r'^config/version="([^"]+)"', (root/'project.godot').read_text(encoding='utf-8'), re.M)
if project_version is None or project_version[1] != version:
    raise ValueError('Project version and Android preset version differ')
print(version)
print(code)
print(package)
PY
)
[ "${#SETTINGS[@]}" -eq 3 ] || fail "Android-Preset konnte nicht gelesen werden"
VERSION="${SETTINGS[0]%$'\r'}"
VERSION_CODE="${SETTINGS[1]%$'\r'}"
PACKAGE_NAME="${SETTINGS[2]%$'\r'}"
APK="${1:-$HERE/build/exports/banger-queens-$VERSION.apk}"
SDK="${ANDROID_SDK_ROOT:-/c/Users/HP/AppData/Local/Android/Sdk}"
BT="${ANDROID_BUILD_TOOLS:-$SDK/build-tools/36.1.0}"
JDK="$HERE/.tools/jdk17"
OUT="$HERE/build/verify/apk-$VERSION"
mkdir -p "$OUT"

[ -f "$APK" ] || { echo "FEHLER: APK fehlt: $APK" >&2; exit 1; }
[ -f "$JDK/bin/java.exe" ] || fail "JDK fehlt: $JDK"
[ -f "$BT/lib/apksigner.jar" ] || { echo "FEHLER: apksigner fehlt: $BT" >&2; exit 1; }
[ -f "$BT/aapt.exe" ] || { echo "FEHLER: aapt fehlt: $BT" >&2; exit 1; }
[ -f "$BT/zipalign.exe" ] || { echo "FEHLER: zipalign fehlt: $BT" >&2; exit 1; }

JAVA_HOME="$JDK"
if command -v cygpath >/dev/null; then JAVA_HOME=$(cygpath -m "$JAVA_HOME"); fi
export JAVA_HOME
export PATH="$JDK/bin:$PATH"

SIG="$OUT/apk-signature.txt"
BADGING="$OUT/apk-badging.txt"
ALIGN="$OUT/apk-zipalign.txt"

"$JDK/bin/java.exe" -jar "$BT/lib/apksigner.jar" verify --verbose --print-certs "$APK" > "$SIG" 2>&1
"$BT/aapt.exe" dump badging "$APK" > "$BADGING"
"$BT/zipalign.exe" -c -v 4 "$APK" > "$ALIGN"

grep -q "Verifies" "$SIG" || { echo "FEHLER: apksigner meldet keine gültige Signatur." >&2; exit 1; }
grep -q "Verified using v2 scheme (APK Signature Scheme v2): true" "$SIG" || { echo "FEHLER: APK-Signature-v2 fehlt." >&2; exit 1; }
grep -q "Number of signers: 1" "$SIG" || { echo "FEHLER: Kein eindeutiger Signer." >&2; exit 1; }
grep -q "Signer #1 certificate SHA-256 digest:" "$SIG" || { echo "FEHLER: Zertifikatsdigest fehlt." >&2; exit 1; }

grep -Fq "package: name='$PACKAGE_NAME' versionCode='$VERSION_CODE' versionName='$VERSION'" "$BADGING" || { echo "FEHLER: Paketname/Version weicht vom aktuellen Android-Preset ab." >&2; exit 1; }
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
