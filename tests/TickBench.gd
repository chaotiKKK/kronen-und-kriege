extends Node
## Messwerkzeug für die Simulationslaufzeit. Kein Pass/Fail-Test: Es dient dem
## Vorher/Nachher-Vergleich eines vertikalen Schnitts mit identischem Seed.
##
## Aufruf: godot --headless --path . res://tests/TickBench.tscn

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")

var _checks: int = 0

func _ready() -> void:
	var ticks: Array = []
	var ai_ticks: Array = []
	for run in 3:
		seed(20261109 + run)
		var game = GameScript.new(DataScript, 0)
		var start: int = Time.get_ticks_usec()
		for month in 120:
			game.advance_month()
		ticks.append(Time.get_ticks_usec() - start)

		seed(20261109 + run)
		var ai_game = GameScript.new(DataScript, 0)
		var ai_start: int = Time.get_ticks_usec()
		for year in 10:
			ai_game.run_ai_turn()
		ai_ticks.append(Time.get_ticks_usec() - ai_start)
	ticks.sort()
	ai_ticks.sort()
	if not _expect(ticks.size() == 3, "Es fehlen Monatsmessungen."):
		return
	if not _expect(ai_ticks.size() == 3, "Es fehlen KI-Messungen."):
		return
	for value in ticks:
		if not _expect(int(value) > 0, "Eine Monatsmessung ist nicht positiv."):
			return
	for value in ai_ticks:
		if not _expect(int(value) > 0, "Eine KI-Messung ist nicht positiv."):
			return
	print("TICKBENCH 120 Monate: %d / %d / %d µs; Median %d µs (%.2f ms)" % [
		int(ticks[0]), int(ticks[1]), int(ticks[2]), int(ticks[1]), float(ticks[1]) / 1000.0
	])
	print("TICKBENCH 10 KI-Jahre: %d / %d / %d µs; Median %d µs (%.2f ms)" % [
		int(ai_ticks[0]), int(ai_ticks[1]), int(ai_ticks[2]), int(ai_ticks[1]),
		float(ai_ticks[1]) / 1000.0
	])
	print("TICKBENCH OK; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	print("TICKBENCH FAIL: " + message)
	get_tree().quit(1)
	return false
