#!/usr/bin/env bash
# Einziger Exportweg für dieses Projekt.
# Schreibt immer F:/ck3-kronen-kriege.apk – Name und Ort sind hier und in
# export_presets.cfg identisch hinterlegt. Kein manueller Pfad nötig.
set -euo pipefail

NAME="ck3-kronen-kriege"
TARGET="F:/${NAME}.apk"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$HERE/.tools"
GODOT="$TOOLS/godot.exe"
JDK="$TOOLS/jdk17"

fail() { echo "FEHLER: $*" >&2; exit 1; }

[ -f "$GODOT" ] || fail "Godot fehlt: $GODOT"
[ -f "$JDK/bin/java.exe" ] || fail "JDK 17 fehlt: $JDK"
[ -d "$TOOLS/appdata/Godot/export_templates/4.5.stable" ] || fail "Godot-4.5-Exportvorlagen fehlen"
[ -d "$HERE/android/build" ] || fail "Android-Buildvorlage fehlt: $HERE/android/build"

mkdir -p "$HERE/build"
rm -f "$TARGET"

echo "Exportiere nach $TARGET"
APPDATA="$TOOLS/appdata" \
JAVA_HOME="$JDK" \
PATH="$JDK/bin:$PATH" \
"$GODOT" --headless --path "$HERE" --export-debug "Android" "$TARGET"

[ -f "$TARGET" ] || fail "Export ohne Fehlercode, aber $TARGET fehlt"
SIZE=$(stat -c %s "$TARGET")
[ "$SIZE" -gt 1000000 ] || fail "APK ist zu klein ($SIZE Bytes)"

echo "OK: $TARGET ($SIZE Bytes)"
sha256sum "$TARGET"
