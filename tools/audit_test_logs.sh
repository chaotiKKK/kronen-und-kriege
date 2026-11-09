#!/usr/bin/env bash
# Strenger Audit des letzten Godot-Sammellaufs.
#
# Es gibt keine Ausnahmen und keine Whitelist: JEDES Log unter build/tests/
# wird auf übersprungene/ausstehende Fälle und Fehlermarker geprüft, auch das
# Aggregatlog. Zusätzlich muss jede Test-Szene unter tests/ ein eigenes Log mit
# einer positiven Assertion-Zahl besitzen. Die Summary muss jede Suite genau
# einmal mit Status PASS und demselben Zähler wie ihr Log enthalten; das
# Aggregat muss 30 grün / 0 rot und dieselbe Assertion-Summe ausweisen.
#
# Aufruf: tools/audit_test_logs.sh
# Exit 0 = Audit bestanden; 1 = mindestens ein Log, eine Summary-Zeile oder
# das Aggregat verletzt die Regel.

set -u

cd "$(dirname "$0")/.." || exit 1
LOGDIR="build/tests"
SUMMARY="$LOGDIR/run_all_summary.tsv"
AGGREGATE="$LOGDIR/run_all_latest.log"

shopt -s nullglob
logs=("$LOGDIR"/*.log)
if [ "${#logs[@]}" -eq 0 ]; then
	echo "AUDIT FEHLER: keine Logs unter $LOGDIR" >&2
	exit 1
fi
if [ ! -s "$AGGREGATE" ]; then
	echo "AUDIT FEHLER: Aggregatlog $AGGREGATE fehlt oder ist leer" >&2
	exit 1
fi
if [ ! -f "$SUMMARY" ]; then
	echo "AUDIT FEHLER: $SUMMARY fehlt" >&2
	exit 1
fi

suite_count=0
for scene in tests/*.tscn; do
	[ -f "$scene" ] || continue
	suite_count=$((suite_count + 1))
done

# --- 1. Summary zuerst: rote Zeilen sind ein harter Fehlschlag ------------
summary_rows=0
summary_total=""
summary_status=""
declare -A summary_seen=()
declare -A summary_counts=()
while IFS=$'\t' read -r suite mode assertions status; do
	[ "$suite" = "suite" ] && continue
	[ -z "${suite:-}" ] && continue
	if [ "$suite" = "TOTAL" ]; then
		summary_total="$assertions"
		summary_status="$status"
		continue
	fi
	if [ -z "${status:-}" ]; then
		echo "AUDIT FEHLER: Summary-Zeile für $suite hat keinen Status" >&2
		exit 1
	fi
	if [ -n "${summary_seen[$suite]:-}" ]; then
		echo "AUDIT FEHLER: Summary enthält $suite mehrfach" >&2
		exit 1
	fi
	if [ "$status" != "PASS" ]; then
		echo "AUDIT FEHLER: Summary-Zeile $suite ist $status (rote Suite)" >&2
		exit 1
	fi
	if [ "$mode" != "headless" ] && [ "$mode" != "window" ]; then
		echo "AUDIT FEHLER: Summary-Zeile $suite hat unbekannten Modus '$mode'" >&2
		exit 1
	fi
	if ! [[ "$assertions" =~ ^[0-9]+$ ]] || [ "$assertions" -le 0 ]; then
		echo "AUDIT FEHLER: Summary-Zeile $suite hat keine positive Assertion-Zahl" >&2
		exit 1
	fi
	summary_seen["$suite"]=1
	summary_counts["$suite"]="$assertions"
	summary_rows=$((summary_rows + 1))
done < "$SUMMARY"

for scene in tests/*.tscn; do
	[ -f "$scene" ] || continue
	suite="$(basename "$scene" .tscn)"
	if [ -z "${summary_seen[$suite]:-}" ]; then
		echo "AUDIT FEHLER: Summary-Zeile für $suite fehlt" >&2
		exit 1
	fi
done

if [ "$summary_rows" -ne "$suite_count" ]; then
	echo "AUDIT FEHLER: Summary hat $summary_rows Suiten, erwartet $suite_count" >&2
	exit 1
fi
if [ -z "$summary_total" ] || ! [[ "$summary_total" =~ ^[0-9]+$ ]]; then
	echo "AUDIT FEHLER: Summary-Total '$summary_total' ist keine Zahl" >&2
	exit 1
fi
if [ "$summary_status" != "PASS" ]; then
	echo "AUDIT FEHLER: Summary-Total ist $summary_status (rote Suite)" >&2
	exit 1
fi

# --- 2. Jede Testszene braucht ein eigenes, positives Log -----------------
actual_total=0
declare -A log_counts=()
for scene in tests/*.tscn; do
	[ -f "$scene" ] || continue
	suite="$(basename "$scene" .tscn)"
	log="$LOGDIR/$suite.log"
	if [ ! -s "$log" ]; then
		echo "AUDIT FEHLER: Log für $suite fehlt oder ist leer" >&2
		exit 1
	fi
	count="$(grep -Eo '[0-9]+ Prüfungen' "$log" | tail -n 1 | awk '{print $1}')"
	if [ -z "$count" ] || [ "$count" -le 0 ]; then
		echo "AUDIT FEHLER: $suite hat keine positive Assertion-Zahl" >&2
		exit 1
	fi
	log_counts["$suite"]="$count"
	actual_total=$((actual_total + count))
done

# --- 3. Summary-Zähler und Log-Zähler müssen exakt übereinstimmen ---------
for scene in tests/*.tscn; do
	[ -f "$scene" ] || continue
	suite="$(basename "$scene" .tscn)"
	if [ -z "${log_counts[$suite]:-}" ]; then
		echo "AUDIT FEHLER: Log für $suite fehlt" >&2
		exit 1
	fi
	if [ "${summary_counts[$suite]}" -ne "${log_counts[$suite]}" ]; then
		echo "AUDIT FEHLER: Summary-Zähler $suite=${summary_counts[$suite]} != Log=${log_counts[$suite]}" >&2
		exit 1
	fi
done
if [ "$summary_total" -ne "$actual_total" ]; then
	echo "AUDIT FEHLER: Summary-Total '$summary_total' != Log-Summe $actual_total" >&2
	exit 1
fi

# --- 4. Aggregat: 30 grün / 0 rot, keine roten Zeilen, exakte Summe -------
expected="== Ergebnis: ${suite_count} grün, 0 rot =="
if ! grep -Fqx "$expected" "$AGGREGATE"; then
	echo "AUDIT FEHLER: Aggregat meldet nicht '$expected'" >&2
	exit 1
fi
expected="== Assertions: ${actual_total} in ${suite_count} von ${suite_count} Suiten =="
if ! grep -Fqx "$expected" "$AGGREGATE"; then
	echo "AUDIT FEHLER: Aggregat meldet nicht '$expected'" >&2
	exit 1
fi
pass_lines="$(grep -c '^PASS ' "$AGGREGATE" || true)"
fail_lines="$(grep -c '^FAIL ' "$AGGREGATE" || true)"
rot_lines="$(grep -c '^Rot:' "$AGGREGATE" || true)"
if [ "$pass_lines" -ne "$suite_count" ]; then
	echo "AUDIT FEHLER: Aggregat hat $pass_lines PASS-Zeilen, erwartet $suite_count" >&2
	exit 1
fi
if [ "$fail_lines" -ne 0 ] || [ "$rot_lines" -ne 0 ]; then
	echo "AUDIT FEHLER: Aggregat enthält $fail_lines FAIL- und $rot_lines Rot-Zeilen" >&2
	exit 1
fi

# --- 5. Genau ein Log pro Suite plus Aggregat ----------------------------
if [ "${#logs[@]}" -ne "$((suite_count + 1))" ]; then
	echo "AUDIT FEHLER: ${#logs[@]} Logs, erwartet $((suite_count + 1)) (Suiten + Aggregat)" >&2
	exit 1
fi

# --- 6. Keine Marker, keine Ausnahme für Aggregat/Screenshot/Asset-Logs ----
marker_re='\<(skip|skipped|pending|todo|ignored)\>|0 Prüfungen|FAIL:|SCRIPT ERROR'
if matches="$(grep -Eni "$marker_re" "${logs[@]}")"; then
	printf 'AUDIT FEHLER: Marker in erzeugten Logs:\n%s\n' "$matches" >&2
	exit 1
fi

printf 'AUDIT OK: %d Logs, %d Suiten, %d Assertions, 0 Marker, keine 0-Prüfungs-Suite, Summary/Aggregat 30/30 grün\n' \
	"${#logs[@]}" "$suite_count" "$actual_total"
exit 0
