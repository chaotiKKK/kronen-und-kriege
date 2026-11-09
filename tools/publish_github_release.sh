#!/usr/bin/env bash
# Veröffentlicht die lokal gebauten Testversionen als GitHub-Release.
#
# Aufruf nach einem Versionssprung und beiden Exporten:
#   bash tools/publish_github_release.sh
#
# Das Skript liest die Version aus project.godot, verlangt einen sauberen
# main-Arbeitsbaum, prüft die APK-Signatur, pusht Commit und Tag und lädt APK,
# EXE sowie SHA256SUMS.txt als Pre-Release hoch. Ein vorhandener Release kann
# neue Assets erhalten, sofern der Tag auf dem aktuellen Commit liegt;
# gleichnamige Assets werden nicht überschrieben. Mit --dry-run werden nur
# Prüfungen und die geplanten Schritte ausgegeben; mit --skip-verify entfällt
# die APK-Signaturprüfung.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot | head -n 1)}"
TAG="${TAG:-v$VERSION}"
APK="${APK:-F:/banger-queens.apk}"
EXE="${EXE:-F:/banger-queens.exe}"
REPO="${GH_REPO:-}"
DRY_RUN=0
SKIP_VERIFY=0

usage() {
	echo "Aufruf: bash tools/publish_github_release.sh [--dry-run] [--skip-verify]"
	echo "Umgebung: VERSION, TAG, APK, EXE, GH_REPO"
}

fail() {
	echo "FEHLER: $*" >&2
	exit 1
}

for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY_RUN=1 ;;
		--skip-verify) SKIP_VERIFY=1 ;;
		-h|--help) usage; exit 0 ;;
		*) fail "Unbekannte Option: $arg" ;;
	esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || fail "Ungültige Version aus project.godot: '$VERSION'"
[[ "$TAG" == v* ]] || fail "Tag muss mit 'v' beginnen: '$TAG'"

command -v gh >/dev/null 2>&1 || fail "GitHub CLI 'gh' fehlt."
gh auth status >/dev/null 2>&1 || fail "GitHub CLI ist nicht angemeldet. Bitte 'gh auth login' ausführen."
[ -f "$APK" ] || fail "APK fehlt: $APK"
[ -f "$EXE" ] || fail "EXE fehlt: $EXE"
[ "$(stat -c %s "$APK")" -gt 1000000 ] || fail "APK ist zu klein: $APK"
[ "$(stat -c %s "$EXE")" -gt 1000000 ] || fail "EXE ist zu klein: $EXE"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || fail "Release nur von 'main' aus, aktuell: '$BRANCH'."
[ -z "$(git status --porcelain)" ] || fail "Arbeitsbaum ist nicht sauber. Erst committen, dann veröffentlichen."
git remote get-url origin >/dev/null 2>&1 || fail "Kein Git-Remote 'origin' gesetzt."
if [ -z "$REPO" ]; then
	REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || fail "Ziel-Repository konnte nicht ermittelt werden. GH_REPO setzen."
fi
[[ "$REPO" == */* ]] || fail "Ungültiges Ziel-Repository: '$REPO'"

if [ "$SKIP_VERIFY" -eq 0 ]; then
	echo "Prüfe APK-Signatur und Manifest ..."
	bash "$ROOT/tools/verify_android_apk.sh" "$APK"
else
	echo "APK-Signaturprüfung übersprungen (--skip-verify)."
fi

APK_SHA="$(sha256sum "$APK" | awk '{print $1}')"
EXE_SHA="$(sha256sum "$EXE" | awk '{print $1}')"
APK_NAME="$(basename "$APK")"
EXE_NAME="$(basename "$EXE")"
HEAD_SHA="$(git rev-parse HEAD)"
SHORT_SHA="$(git rev-parse --short HEAD)"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/banger-queens-release.XXXXXX")"
CHECKSUMS="$WORK_DIR/SHA256SUMS.txt"
NOTES="$WORK_DIR/release-notes.md"
trap 'rm -rf "$WORK_DIR"' EXIT

printf '%s  %s\n%s  %s\n' "$APK_SHA" "$APK_NAME" "$EXE_SHA" "$EXE_NAME" > "$CHECKSUMS"

cat > "$NOTES" <<EOF
# Banger Queens $VERSION – Testversion

Quellstand: \`$SHORT_SHA\` auf \`main\`

## Downloads

- **Android:** \`$APK_NAME\` (Debug-signiert, APK Signature Scheme v2)
- **Windows:** \`$EXE_NAME\` (x86_64, PCK eingebettet)
- **Prüfsummen:** \`SHA256SUMS.txt\`

## SHA-256

\`\`\`
$(cat "$CHECKSUMS")
\`\`\`

Dies ist eine Testversion. Die APK ist mit dem Android-Debug-Zertifikat
signiert und für die Installation über \`adb install -r\` oder direkt auf dem
Gerät gedacht. Die Windows-EXE startet ohne Installation.
EOF

TAG_EXISTS=0
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
	TAG_EXISTS=1
	TAG_SHA="$(git rev-list -n 1 "$TAG")"
	[ "$TAG_SHA" = "$HEAD_SHA" ] || fail "Tag $TAG zeigt auf $TAG_SHA, HEAD ist $HEAD_SHA. Version erhöhen oder Tag prüfen."
fi

echo "Repository: $REPO"
echo "Version:    $VERSION"
echo "Tag:        $TAG ($HEAD_SHA)"
echo "APK:        $APK ($APK_SHA)"
echo "EXE:        $EXE ($EXE_SHA)"

if [ "$DRY_RUN" -eq 1 ]; then
	echo "DRY RUN: Es wird nichts gepusht oder hochgeladen."
	echo "--- Release-Notizen ---"
	cat "$NOTES"
	echo "--- Prüfsummen ---"
	cat "$CHECKSUMS"
	exit 0
fi

git push origin HEAD:main
if [ "$TAG_EXISTS" -eq 0 ]; then
	git tag -a "$TAG" -m "Banger Queens $VERSION"
fi
git push origin "$TAG"

if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
	echo "Aktualisiere vorhandenen Release $TAG ..."
	gh release upload "$TAG" "$APK" "$EXE" "$CHECKSUMS" -R "$REPO"
	gh release edit "$TAG" -R "$REPO" --title "Banger Queens $VERSION" --notes-file "$NOTES" --prerelease
else
	echo "Erzeuge Release $TAG ..."
	gh release create "$TAG" -R "$REPO" --title "Banger Queens $VERSION" --notes-file "$NOTES" --prerelease --verify-tag
	gh release upload "$TAG" "$APK" "$EXE" "$CHECKSUMS" -R "$REPO"
fi

echo "Release veröffentlicht:"
gh release view "$TAG" -R "$REPO" --json url,assets --jq '{url: .url, assets: [.assets[] | {name, size}]}'
