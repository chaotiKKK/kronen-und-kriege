extends Node
## Prüft den Seekrieg ohne Szene: Küsten, Flottenaufstellung, Blockade,
## Seeschlacht, monatlichen Druck, Frieden und Save-Roundtrip.
## Aufruf: godot --headless --path . res://tests/NavalTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGame = preload("res://scripts/SaveGame.gd")

var _failed := false
var _checks := 0

func _ready() -> void:
	seed(20261109)
	if not _test_coast():
		return
	if not _test_raise_and_blockade():
		return
	if not _test_naval_battle():
		return
	if _failed:
		return
	print("NAVALTEST OK: Küstenerkennung, Flottenaufstellung, Blockade, Seeschlacht, monatlicher Druck, Frieden und Schema-11-Roundtrip; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _test_coast() -> bool:
	_check(DataScript.is_coastal("cantium"), "Cantium wurde nicht als Küste erkannt.")
	_check(not DataScript.is_coastal("aedui"), "Aedui wurde fälschlich als Küste erkannt.")
	return not _failed

func _test_raise_and_blockade() -> bool:
	var g = GameScript.new(DataScript, 2)
	var port := _coastal_owned(g, g.player)
	if not _check(not port.is_empty(), "Keine eigene Küstenprovinz gefunden."):
		return false
	var land := g.province("aedui")
	land["owner"] = g.player
	g.house()["gold"] = 500
	_check(not g.can_raise_fleet("aedui"), "Flotte konnte im Binnenland aufgestellt werden.")
	if _failed:
		return false
	var gold_before: int = int(g.house()["gold"])
	var raised: Dictionary = g.raise_fleet(str(port["id"]))
	if not _check(bool(raised["ok"]), "Flottenaufstellung wurde abgelehnt."):
		return false
	var fleet: Dictionary = g.fleet_for(g.player)
	_check(not fleet.is_empty(), "Flotte fehlt nach der Aufstellung.")
	_check(int(fleet.get("ships", 0)) > 0, "Flotte hat keine Schiffe.")
	_check(int(g.house()["gold"]) == gold_before - 60, "Flottenaufstellung kostet nicht 60 Gold.")
	_check(not g.can_raise_fleet(str(port["id"])), "Zweite Flotte wurde erlaubt.")
	if _failed:
		return false

	var target := _blockade_target(g, str(port["id"]))
	if not _check(not target.is_empty(), "Kein erreichbares Küstenziel gefunden."):
		return false
	var defender: int = int(target["owner"])
	g.houses[defender]["fleets"] = []
	g.houses[defender]["gold"] = 100
	var target_levy: int = int(target["levy"])
	var player_gold: int = int(g.house()["gold"])
	var defender_gold: int = int(g.houses[defender]["gold"])
	var blocked: Dictionary = g.blockade(str(target["id"]))
	if not _check(bool(blocked["ok"]), "Blockade wurde abgelehnt."):
		return false
	_check(int(target.get("blockade", 0)) == 6, "Blockade hat nicht sechs Monate.")
	_check(str(fleet.get("station", "")) == str(target["id"]), "Flotte liegt nicht vor dem Ziel.")
	_check(int(target["levy"]) < target_levy, "Blockade senkt das Aufgebot nicht.")
	_check(int(g.house()["gold"]) > player_gold, "Blockade bringt keine Beute.")
	_check(int(g.houses[defender]["gold"]) < defender_gold, "Ziel verliert keine Beute.")
	if _failed:
		return false

	var blockade_before: int = int(target["blockade"])
	var gold_before_tick: int = int(g.house()["gold"])
	g._tick_naval()
	_check(int(target["blockade"]) == blockade_before - 1, "Blockade zählt monatlich nicht herunter.")
	_check(int(g.house()["gold"]) > gold_before_tick, "Monatlicher Blockadedruck bringt keine Beute.")
	if _failed:
		return false

	var snapshot: Dictionary = g.snapshot()
	_check(SaveGame.validate(snapshot).is_empty(), "Schema-11-Validierung scheitert: %s" % "; ".join(SaveGame.validate(snapshot)))
	_check(not (snapshot["houses"][g.player]["fleets"] as Array).is_empty(), "Flotte fehlt im Snapshot.")
	_check(int(_find_province(snapshot["provinces"], str(target["id"])).get("blockade", 0)) == int(target["blockade"]), "Blockade fehlt im Snapshot.")
	var loaded = GameScript.new(DataScript, 2)
	if not _check(loaded.restore(snapshot), "Seekriegs-Snapshot wurde nicht geladen."):
		return false
	var loaded_fleet: Dictionary = loaded.fleet_for(loaded.player)
	_check(not loaded_fleet.is_empty(), "Flotte fehlt nach dem Laden.")
	_check(str(loaded_fleet.get("station", "")) == str(target["id"]), "Flottenposition ging beim Laden verloren.")
	_check(int(loaded.province(str(target["id"])).get("blockade", 0)) == int(target["blockade"]), "Blockade ging beim Laden verloren.")
	if _failed:
		return false

	var peace: Dictionary = g.make_peace(defender)
	if not _check(bool(peace["ok"]), "Frieden mit dem Blockadeziel wurde abgelehnt."):
		return false
	_check(int(target.get("blockade", 0)) == 0, "Frieden beendet die Blockade nicht.")
	_check(str(fleet.get("station", "")) == str(port["id"]), "Flotte kehrt nach Frieden nicht in den Hafen zurück.")
	return not _failed

func _test_naval_battle() -> bool:
	var g = GameScript.new(DataScript, 2)
	var port := _coastal_owned(g, g.player)
	if not _check(not port.is_empty(), "Kein Hafen für die Seeschlacht gefunden."):
		return false
	g.house()["gold"] = 500
	g.raise_fleet(str(port["id"]))
	var target := _blockade_target(g, str(port["id"]))
	if not _check(not target.is_empty(), "Kein Ziel für die Seeschlacht gefunden."):
		return false
	var defender: int = int(target["owner"])
	g.houses[defender]["fleets"] = [{
		"id": 1, "province": str(target["id"]), "station": str(target["id"]),
		"ships": 6, "upkeep": 1, "morale": 100,
	}]
	g.attack_roll_override = 2.0
	var won: Dictionary = g.blockade(str(target["id"]))
	_check(bool(won["ok"]), "Seesieg wurde nicht als Blockade gewertet.")
	_check((g.houses[defender]["fleets"] as Array).is_empty() or int(g.houses[defender]["fleets"][0]["ships"]) < 6, "Seesieg versenkt keine Schiffe.")
	_check(int(target.get("blockade", 0)) == 6, "Seesieg errichtet keine Blockade.")
	if _failed:
		return false

	var lost = GameScript.new(DataScript, 2)
	var lost_port := _coastal_owned(lost, lost.player)
	lost.house()["gold"] = 500
	lost.raise_fleet(str(lost_port["id"]))
	var lost_target := _blockade_target(lost, str(lost_port["id"]))
	var lost_defender: int = int(lost_target["owner"])
	lost.houses[lost_defender]["fleets"] = [{
		"id": 1, "province": str(lost_target["id"]), "station": str(lost_target["id"]),
		"ships": 30, "upkeep": 3, "morale": 100,
	}]
	var ships_before: int = int(lost.fleet_for(lost.player).get("ships", 0))
	lost.attack_roll_override = 0.1
	var defeat: Dictionary = lost.blockade(str(lost_target["id"]))
	_check(not bool(defeat["ok"]), "Seeniederlage wurde als Erfolg gewertet.")
	_check(int(lost_target.get("blockade", 0)) == 0, "Seeniederlage errichtet eine Blockade.")
	var survivor: Dictionary = lost.fleet_for(lost.player)
	_check(survivor.is_empty() or int(survivor.get("ships", 0)) < ships_before, "Seeniederlage kostet keine Schiffe.")
	return not _failed

func _coastal_owned(g, house_index: int) -> Dictionary:
	for p in g.provinces:
		if int(p["owner"]) == house_index and g.is_coastal(str(p["id"])):
			return p
	return {}

func _blockade_target(g, port_id: String) -> Dictionary:
	for p in g.provinces:
		if int(p["owner"]) == g.player or not g.is_coastal(str(p["id"])):
			continue
		if not g._maritime_reachable(port_id, str(p["id"])):
			continue
		if g.truce_until(int(p["owner"]), g.player) > g._now():
			continue
		return p
	return {}

func _find_province(provinces: Array, id: String) -> Dictionary:
	for p in provinces:
		if str(p.get("id", "")) == id:
			return p
	return {}

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failed = true
	print("NAVALTEST FAIL: " + message)
	get_tree().quit(1)
	return false
