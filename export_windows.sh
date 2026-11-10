#!/usr/bin/env bash
# Nativer Windows-Export mit eingebetteter PCK.
# Aufruf: bash export_windows.sh [AUSGABE.exe]; relative Ziele gelten ab Projektwurzel.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$HERE/.tools"
GODOT="$TOOLS/godot.exe"
RCEDIT="$TOOLS/rcedit-x64.exe"
TEMPLATES="$TOOLS/appdata/Godot/export_templates/4.5.stable"
PYTHON_EXE="${BQ_PYTHON:-python}"

fail() { echo "FEHLER: $*" >&2; exit 1; }
[ "$#" -le 1 ] || fail "Aufruf: bash export_windows.sh [AUSGABE.exe]"
VERSION=$(sed -n 's/^config\/version="\([^"]*\)".*/\1/p' "$HERE/project.godot" | tr -d '\r')
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Ungültige Projektversion: $VERSION"
TARGET="${1:-$HERE/build/exports/banger-queens-$VERSION.exe}"
if command -v cygpath >/dev/null; then TARGET=$(cygpath -u "$TARGET"); fi
[[ "$TARGET" == /* ]] || TARGET="$HERE/$TARGET"
[[ "$TARGET" == *.exe ]] || fail "Die Ausgabedatei muss .exe heißen: $TARGET"
[ ! -e "$TARGET" ] || fail "Ausgabedatei existiert bereits; bitte einen neuen Pfad wählen: $TARGET"

[ -f "$GODOT" ] || fail "Godot fehlt: $GODOT"
[ -f "$RCEDIT" ] || fail "rcedit fehlt: $RCEDIT"
[ -f "$TEMPLATES/windows_release_x86_64.exe" ] || fail "Windows-Exportvorlage fehlt: $TEMPLATES/windows_release_x86_64.exe"
command -v "$PYTHON_EXE" >/dev/null || fail "Python fehlt: $PYTHON_EXE (überschreibbar mit BQ_PYTHON)"

# Branding und Originalmanifest werden auf einer privaten, ungepackten
# Vorlagenkopie vorbereitet. Die verpackte Spiel-EXE wird nicht nachbearbeitet.
"$PYTHON_EXE" "$HERE/tools/prepare_windows_export_template.py" --project "$HERE"
mkdir -p "$(dirname "$TARGET")"
BUILD_APPDATA="$TOOLS/appdata"
if command -v cygpath >/dev/null; then BUILD_APPDATA=$(cygpath -m "$BUILD_APPDATA"); fi

echo "Exportiere nach $TARGET"
APPDATA="$BUILD_APPDATA" \
"$GODOT" --headless --path "$HERE" --export-release "Windows Desktop" "$TARGET"

[ -f "$TARGET" ] || fail "Export ohne Fehlercode, aber $TARGET fehlt"
SIZE=$(stat -c %s "$TARGET")
[ "$SIZE" -gt 1000000 ] || fail "EXE ist zu klein ($SIZE Bytes)"
grep -aq "assets/audio/ambient.wav" "$TARGET" || fail "EXE enthält keine eingebettete PCK (Icon-Export prüfen)"

echo "OK: $TARGET ($SIZE Bytes)"
sha256sum "$TARGET"
