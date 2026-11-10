#!/usr/bin/env bash
# Sammellauf aller Godot-Testsuiten von "Kronen und Kriege".
#
# Headless-Suiten laufen ohne Fenster. Render-, Touch- und Screenshot-Suiten
# brauchen einen echten Viewport und laufen mit --resolution 1280x720.
# Jede Suite schreibt ein eigenes Log unter build/tests/.
#
# Der Runner entdeckt alle Szenen im Repo und bricht ab, wenn eine Testszene
# außerhalb von tests/ liegt, ein Testskript keine Szene hat oder eine Suite
# nicht in HEADLESS/WINDOWED registriert ist. Nach jedem Lauf muss das Log eine
# positive Zahl "N Prüfungen" enthalten und darf weder skip/pending/todo/ignored
# noch einen FAIL-/SCRIPT-ERROR-Marker enthalten. Die Summary enthält JEDE
# entdeckte Suite mit Status PASS/FAIL, damit eine rote Suite nicht nur im
# Aggregat, sondern auch als rote Summary-Zeile sichtbar und auditierbar ist.
#
# Aufruf: tools/run_all_tests.sh
# Exit 0 = alle Suiten grün, 1 = mindestens eine Suite rot, leer oder unentdeckt.

set -u

cd "$(dirname "$0")/.." || exit 1
TOOLS=".tools"
GODOT="$TOOLS/godot.exe"
export APPDATA="$PWD/$TOOLS/appdata"
LOGDIR="build/tests"
TIMEOUT_SECONDS=300
RESOLUTION="1280x720"
WINDOW_POSITION="${GODOT_WINDOW_POSITION:-2020,60}"

if [ ! -x "$GODOT" ]; then
	echo "FEHLER: $GODOT fehlt. Die lokale Godot-Binary muss unter .tools/ bereitstehen." >&2
	exit 1
fi

mkdir -p "$LOGDIR"

# Logik- und UI-Tests ohne Renderpfad.
HEADLESS=(
	AtlasCoverageSemanticsTest
	AtlasDataTest
	CampaignTest
	InfrastructureTest
	LoadingStatusTest
	MapDataTest
	MapAssetTest
	MapTest
	HouseTest
	HousePlayTest
	IntrigueTest
	CustomizeTest
	PortraitTest
	SaveMigrationTest
	DynastyTest
	DynastyUiTest
	SystemicDepthTest
	FullDepthTest
	StoryTest
	UiKernelTest
	EventArtTest
	NavalTest
	CouncilTest
	CouncilUiTest
	CourtTest
	CourtUiTest
	FaithTest
	FaithUiTest
	TickBench
)

# Suiten, die einen echten Viewport brauchen.
# CourtShotTest gehört ebenfalls hierher; es war zuvor nicht registriert.
WINDOWED=(
	AtlasIntegrationTest
	EventChoiceTest
	MaterialThemeTest
	ModernUiTest
	InfrastructureUiTest
	TouchTest
	ShotTest
	TitleShot
	NavalRenderTest
	MapPerfTest
	FaithShotTest
	CourtShotTest
)

failed=()
passed=()
assertion_total=0
declare -A suite_assertions=()
declare -A suite_modes=()

for suite in "${HEADLESS[@]}"; do suite_modes["$suite"]="headless"; done
for suite in "${WINDOWED[@]}"; do suite_modes["$suite"]="window"; done

# --- Discovery: alle Szenen im Repo, nicht nur tests/*.tscn -----------------
# Test-Suiten liegen unter tests/. Szenen außerhalb werden nur dann als Test
# akzeptiert, wenn ihr Skript echte Testmarker enthält; solche Suiten müssen
# bewusst in die Registrierung aufgenommen werden. Unreferenzierte Testskripte
# und Testskripte außerhalb von tests/ werden als Lücke gemeldet.
discovered=()
all_scenes=()
external_test_scenes=()
nested_test_scenes=()
while IFS= read -r scene; do
	rel="${scene#./}"
	all_scenes+=("$rel")
	case "$rel" in
		tests/*)
			if [ "$(dirname "$rel")" = "tests" ]; then
				discovered+=("$(basename "$rel" .tscn)")
			else
				nested_test_scenes+=("$rel")
			fi
			;;
		*)
			for script in $(grep -oE 'path="res://[^"]+\.gd"' "$scene" | sed -e 's/^path="res:\/\///' -e 's/"$//'); do
				if [ -f "$script" ] && grep -Eq 'func (_check|_expect|_need|_deny)\(|TEST OK|BENCH OK|SHOTS? OK|FAITHSHOT OK|COURTSHOT OK|NAVALRENDERTEST OK' "$script"; then
					external_test_scenes+=("$rel")
					break
				fi
			done
			;;
	esac
done < <(find . -type f -name '*.tscn' -not -path './.tools/*' -not -path './.godot/*' -not -path './build/*' -print | sort)

orphan_test_scripts=()
for script in tests/*.gd; do
	[ -f "$script" ] || continue
	base="$(basename "$script" .gd)"
	if grep -Eq 'func (_check|_expect|_need|_deny)\(|TEST OK|BENCH OK|SHOTS? OK|FAITHSHOT OK|COURTSHOT OK|NAVALRENDERTEST OK' "$script" \
		&& { [ ! -f "tests/$base.tscn" ] || ! grep -q "res://tests/$base.gd" "tests/$base.tscn"; }; then
		orphan_test_scripts+=("$script")
	fi
done

external_test_scripts=()
while IFS= read -r script; do
	if grep -Eq 'func (_check|_expect|_need|_deny)\(|TEST OK|BENCH OK|SHOTS? OK|FAITHSHOT OK|COURTSHOT OK|NAVALRENDERTEST OK' "$script"; then
		external_test_scripts+=("$script")
	fi
done < <(find . -type f -name '*.gd' -not -path './tests/*' -not -path './.tools/*' -not -path './.godot/*' -not -path './build/*' -print | sort)

registered=("${HEADLESS[@]}" "${WINDOWED[@]}")
missing=()
for suite in "${discovered[@]}"; do
	found=0
	for candidate in "${registered[@]}"; do
		if [ "$candidate" = "$suite" ]; then
			found=1
			break
		fi
	done
	if [ "$found" -eq 0 ]; then
		missing+=("$suite")
	fi
done

missing_scenes=()
for suite in "${registered[@]}"; do
	if [ ! -f "tests/$suite.tscn" ]; then
		missing_scenes+=("$suite")
	fi
done

echo "== Kronen und Kriege · Godot-Sammellauf =="
echo "Godot: $("$GODOT" --version 2>/dev/null | tail -n 1)"
echo "Discovery: ${#discovered[@]} Suiten unter tests/, ${#registered[@]} registriert, ${#all_scenes[@]} Szenen im Repo"
echo "Logs:  $LOGDIR"

if [ "${#external_test_scenes[@]}" -ne 0 ]; then
	printf 'FEHLER: Test-Szene außerhalb von tests/: %s\n' "${external_test_scenes[*]}" >&2
	exit 1
fi
if [ "${#nested_test_scenes[@]}" -ne 0 ]; then
	printf 'FEHLER: verschachtelte Test-Szene außerhalb der flachen Discovery: %s\n' "${nested_test_scenes[*]}" >&2
	exit 1
fi
if [ "${#orphan_test_scripts[@]}" -ne 0 ]; then
	printf 'FEHLER: Testskript ohne zugehörige Szene: %s\n' "${orphan_test_scripts[*]}" >&2
	exit 1
fi
if [ "${#external_test_scripts[@]}" -ne 0 ]; then
	printf 'FEHLER: Testskript außerhalb von tests/: %s\n' "${external_test_scripts[*]}" >&2
	exit 1
fi
if [ "${#missing[@]}" -ne 0 ]; then
	printf 'FEHLER: nicht registrierte Test-Szenen: %s\n' "${missing[*]}" >&2
	exit 1
fi
if [ "${#missing_scenes[@]}" -ne 0 ]; then
	printf 'FEHLER: registrierte, aber fehlende Szenen: %s\n' "${missing_scenes[*]}" >&2
	exit 1
fi
if [ "${#registered[@]}" -ne "${#discovered[@]}" ]; then
	echo "FEHLER: ${#discovered[@]} Test-Szenen, aber ${#registered[@]} Registrierungen (Duplikat?)." >&2
	exit 1
fi
echo

run_suite() {
	local name="$1"
	local mode="$2"
	local log="$LOGDIR/$name.log"
	local rc=0
	if [ "$mode" = "headless" ]; then
		timeout "$TIMEOUT_SECONDS" "$GODOT" --headless --path . "res://tests/$name.tscn" >"$log" 2>&1
		rc=$?
	else
		timeout "$TIMEOUT_SECONDS" "$GODOT" --path . "res://tests/$name.tscn" --resolution "$RESOLUTION" --position "$WINDOW_POSITION" >"$log" 2>&1
		rc=$?
	fi

	if [ "$rc" -ne 0 ]; then
		printf 'FAIL  %-18s %s (Exit %d, Log %s)\n' "$name" "$mode" "$rc" "$log"
		tail -n 12 "$log" | sed 's/^/      /'
		failed+=("$name")
		return
	fi

	local reason=""
	local count=""
	if grep -Eqi '\<(skip|skipped|pending|todo|ignored)\>' "$log"; then
		reason="Log enthält skip/pending/todo/ignored"
	elif grep -Eq 'SCRIPT ERROR|FAIL:' "$log"; then
		reason="Log enthält Fehler-/FAIL-Marker"
	elif ! grep -Eq 'OK[:;.]|OK$' "$log"; then
		reason="Log enthält keine Erfolgszeile"
	else
		count="$(grep -Eo '[0-9]+ Prüfungen' "$log" | tail -n 1 | awk '{print $1}')"
		if [ -z "$count" ]; then
			reason="Log enthält keine Assertion-Zahl"
		elif [ "$count" -le 0 ]; then
			reason="Log meldet 0 Assertions"
		fi
	fi

	if [ -n "$reason" ]; then
		printf 'FAIL  %-18s %s (%s, Log %s)\n' "$name" "$mode" "$reason" "$log"
		tail -n 12 "$log" | sed 's/^/      /'
		failed+=("$name")
		return
	fi

	printf 'PASS  %-18s %-6s %5d Prüfungen\n' "$name" "$mode" "$count"
	passed+=("$name")
	assertion_total=$((assertion_total + count))
	suite_assertions["$name"]="$count"
	suite_modes["$name"]="$mode"
}

for suite in "${HEADLESS[@]}"; do
	run_suite "$suite" headless
done
for suite in "${WINDOWED[@]}"; do
	run_suite "$suite" window
done

summary="$LOGDIR/run_all_summary.tsv"
summary_status="PASS"
if [ "${#failed[@]}" -ne 0 ] || [ "${#passed[@]}" -ne "${#discovered[@]}" ]; then
	summary_status="FAIL"
fi
{
	printf 'suite\tmode\tassertions\tstatus\n'
	for suite in "${discovered[@]}"; do
		if [ -n "${suite_assertions[$suite]:-}" ]; then
			printf '%s\t%s\t%s\tPASS\n' "$suite" "${suite_modes[$suite]}" "${suite_assertions[$suite]}"
		else
			printf '%s\t%s\t0\tFAIL\n' "$suite" "${suite_modes[$suite]}"
		fi
	done
	printf 'TOTAL\t-\t%d\t%s\n' "$assertion_total" "$summary_status"
} > "$summary"

echo
echo "== Ergebnis: ${#passed[@]} grün, ${#failed[@]} rot =="
echo "== Assertions: $assertion_total in ${#passed[@]} von ${#discovered[@]} Suiten =="
echo "== Report: $summary =="
if [ "${#failed[@]}" -ne 0 ]; then
	printf 'Rot: %s\n' "${failed[*]}"
	exit 1
fi
if [ "${#passed[@]}" -ne "${#discovered[@]}" ]; then
	echo "FEHLER: Nicht alle entdeckten Suiten wurden ausgeführt." >&2
	exit 1
fi
echo "Alle ${#discovered[@]} Godot-Suiten grün, mit Assertions-Nachweis und ohne übersprungene oder ausstehende Fälle."
exit 0
