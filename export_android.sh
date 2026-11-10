#!/usr/bin/env bash
# Nativer Android-Export mit dem vorbereiteten lokalen Godot/JDK-Profil.
# Aufruf: bash export_android.sh [AUSGABE.apk]; relative Ziele gelten ab Projektwurzel.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$HERE/.tools"
GODOT="$TOOLS/godot.exe"
JDK="$TOOLS/jdk17"

fail() { echo "FEHLER: $*" >&2; exit 1; }
[ "$#" -le 1 ] || fail "Aufruf: bash export_android.sh [AUSGABE.apk]"
VERSION=$(sed -n 's/^config\/version="\([^"]*\)".*/\1/p' "$HERE/project.godot" | tr -d '\r')
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Ungültige Projektversion: $VERSION"
TARGET="${1:-$HERE/build/exports/banger-queens-$VERSION.apk}"
if command -v cygpath >/dev/null; then TARGET=$(cygpath -u "$TARGET"); fi
[[ "$TARGET" == /* ]] || TARGET="$HERE/$TARGET"
[[ "$TARGET" == *.apk ]] || fail "Die Ausgabedatei muss .apk heißen: $TARGET"
[ ! -e "$TARGET" ] || fail "Ausgabedatei existiert bereits; bitte einen neuen Pfad wählen: $TARGET"

[ -f "$GODOT" ] || fail "Godot fehlt: $GODOT"
[ -f "$JDK/bin/java.exe" ] || fail "JDK 17 fehlt: $JDK"
[ -d "$TOOLS/appdata/Godot/export_templates/4.5.stable" ] || fail "Godot-4.5-Exportvorlagen fehlen"
[ -d "$HERE/android/build" ] || fail "Android-Buildvorlage fehlt: $HERE/android/build"

mkdir -p "$(dirname "$TARGET")"
BUILD_APPDATA="$TOOLS/appdata"
BUILD_JAVA_HOME="$JDK"
if command -v cygpath >/dev/null; then
    BUILD_APPDATA=$(cygpath -m "$BUILD_APPDATA")
    BUILD_JAVA_HOME=$(cygpath -m "$BUILD_JAVA_HOME")
fi

echo "Exportiere nach $TARGET"
APPDATA="$BUILD_APPDATA" \
JAVA_HOME="$BUILD_JAVA_HOME" \
PATH="$JDK/bin:$PATH" \
"$GODOT" --headless --path "$HERE" --export-debug "Android" "$TARGET"

[ -f "$TARGET" ] || fail "Export ohne Fehlercode, aber $TARGET fehlt"
SIZE=$(stat -c %s "$TARGET")
[ "$SIZE" -gt 1000000 ] || fail "APK ist zu klein ($SIZE Bytes)"

echo "OK: $TARGET ($SIZE Bytes)"
sha256sum "$TARGET"
