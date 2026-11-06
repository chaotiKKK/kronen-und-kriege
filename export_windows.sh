#!/usr/bin/env bash
# Windows-Export: einzelne EXE mit eingebettetem PCK unter F:/ck3-kronen-kriege.exe.
set -euo pipefail

NAME="ck3-kronen-kriege"
TARGET="F:/${NAME}.exe"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$HERE/.tools"
GODOT="$TOOLS/godot.exe"
RCEDIT="$TOOLS/rcedit-x64.exe"
TEMPLATES="$TOOLS/appdata/Godot/export_templates/4.5.stable"

fail() { echo "FEHLER: $*" >&2; exit 1; }

[ -f "$GODOT" ] || fail "Godot fehlt: $GODOT"
[ -f "$RCEDIT" ] || fail "rcedit fehlt: $RCEDIT"
[ -f "$TEMPLATES/windows_release_x86_64.exe" ] || fail "Windows-Exportvorlage fehlt: $TEMPLATES/windows_release_x86_64.exe"

mkdir -p "$HERE/build"
rm -f "$TARGET"

echo "Exportiere nach $TARGET"
APPDATA="$TOOLS/appdata" \
"$GODOT" --headless --path "$HERE" --export-release "Windows Desktop" "$TARGET"

[ -f "$TARGET" ] || fail "Export ohne Fehlercode, aber $TARGET fehlt"
SIZE=$(stat -c %s "$TARGET")
[ "$SIZE" -gt 1000000 ] || fail "EXE ist zu klein ($SIZE Bytes)"
grep -aq "assets/audio/ambient.wav" "$TARGET" || fail "EXE enthält keine eingebettete PCK (Icon-Export prüfen)"

echo "OK: $TARGET ($SIZE Bytes)"
sha256sum "$TARGET"
