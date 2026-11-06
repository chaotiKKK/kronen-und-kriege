extends Node
## 30-Monats-Story-Smoke-Test: spielt eine zusammenhängende Partie mit
## Entscheidungen aus Herrschaft, Dynastie, Krieg und KI, speichert mehrfach
## und prüft, dass der Zustand verlustfrei zurückkommt.
##
## Aufruf: godot --headless --path . res://tests/StoryTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGame = preload("res://scripts/SaveGame.gd")

var _failed := false
var _checks := 0
var _decisions := 0
var _saves := 0
var _seen: Dictionary = {}

func _ready() -> void:
	seed(20261106)
	var g = GameScript.new(DataScript, 0)
	var house: Dictionary = g.house()
	house["ruler"]["age"] = 18
	house["ruler"]["health"] = 100
	house["gold"] = 2000
	house["spouse"] = {}
	var target: String = _border_target(g, 0)
	for month in 120:
		if g.pending_event != null:
			g.apply_event(0)
		g.advance_month()
		_check(not g.game_over, "Die Story-Partie endete vorzeitig in Monat %d." % month)
		if _failed:
			return
		for entry in g.effect_log:
			_seen[str(entry.get("edge", ""))] = true
		if g.month == 1:
			_run_year(g)
			target = _valid_target(g, target)
		if month == 29 or month == 59 or month == 89:
			_check_roundtrip(g, "Monat %d" % month)
			if _failed:
				return

	_check(g.log_lines.size() > 0, "Die Story erzeugt keine Chronik.")
	_check(_decisions >= 12, "Zu wenige nachvollziehbare Entscheidungen: %d." % _decisions)
	_check(_saves == 3, "Es wurden nicht drei Speicherstände geprüft.")
	var dynastic := _count_prefix("D")
	var war := _count_prefix("K")
	var ai := _count_prefix("AI")
	_check(dynastic >= 3, "Zu wenige dynastische Kanten in der Story: %d." % dynastic)
	_check(war >= 3, "Zu wenige Kriegs-/Diplomatiekanten in der Story: %d." % war)
	_check(ai >= 2, "Zu wenige KI-Kanten in der Story: %d." % ai)
	_check(_seen.size() >= 10, "Zu wenige verschiedene Systemkanten: %d." % _seen.size())
	if _failed:
		return
	print("STORYTEST OK: 120 Monate, %d Entscheidungen, %d Speicher-Roundtrips, %d Kanten (D/K/AI: %d/%d/%d), Chronik %d Zeilen." % [
		_decisions, _saves, _seen.size(), dynastic, war, ai, g.log_lines.size()
	])
	get_tree().quit(0)

func _run_year(g) -> void:
	var house: Dictionary = g.house()
	var capital: Dictionary = _capital(g, 0)
	if capital.is_empty():
		return
	var martial: int = _best(house["courtiers"], "martial")
	_decide(g.assign_council("marshal", martial)["ok"])
	_decide(g.assign_council("chancellor", _best(house["courtiers"], "diplomacy"))["ok"])
	_decide(g.assign_council("steward", _best(house["courtiers"], "stewardship"))["ok"])
	_decide(g.set_law("tax", "2")["ok"])
	for key in ["market", "barracks", "walls"]:
		if g.can_build(str(capital["id"]), key):
			_decide(g.build(str(capital["id"]), key)["ok"])
	if g.can_develop(str(capital["id"])):
		_decide(g.develop(str(capital["id"]))["ok"])
	if g.can_recruit(str(capital["id"])):
		_decide(g.recruit(str(capital["id"]))["ok"])
	if g.can_court():
		_decide(g.court()["ok"])
	if house["spouse"].is_empty():
		_decide(g.settle_marriage(1)["ok"])
	var target: String = _valid_target(g, "")
	if target != "":
		if not g.has_claim(target):
			_decide(g.fabricate_claim(target)["ok"])
		if g.has_claim(target):
			_decide(g.press_claim(target)["ok"])
			if g.army_for(0).is_empty():
				_decide(g.raise_army(str(capital["id"]))["ok"])
			if not g.army_for(0).is_empty():
				_decide(g.advance_siege(target)["ok"])
		var target_house: int = int(g.province(target).get("owner", -1))
		if target_house >= 0 and target_house != 0:
			_decide(g.make_peace(target_house)["ok"])
			_decide(g.discover_secret(target_house)["ok"])
			_decide(g.expose_secret(target_house)["ok"])

func _valid_target(g, fallback: String) -> String:
	if fallback != "" and not g.province(fallback).is_empty() and int(g.province(fallback)["owner"]) != 0:
		return fallback
	return _border_target(g, 0)

func _check_roundtrip(g, label: String) -> void:
	var snapshot: Dictionary = g.snapshot()
	var restored = GameScript.new(DataScript, 0)
	_check(restored.restore(snapshot), "Speicherstand %s ließ sich nicht laden." % label)
	var actual: Dictionary = restored.snapshot()
	var errors: Array = SaveGame.diff(snapshot, actual)
	_check(errors.is_empty(), "Roundtrip %s verliert Zustand: %s" % [label, "; ".join(errors)])
	if errors.is_empty():
		_saves += 1

func _decide(ok: bool) -> void:
	if ok:
		_decisions += 1

func _count_prefix(prefix: String) -> int:
	var count: int = 0
	for edge in _seen.keys():
		if str(edge).begins_with(prefix) and str(edge) != "":
			count += 1
	return count

func _border_target(g, house_index: int) -> String:
	for p in g.provinces:
		if int(p["owner"]) != house_index:
			continue
		for n in g.neighbours(str(p["id"])):
			var q: Dictionary = g.province(str(n))
			if not q.is_empty() and int(q["owner"]) != house_index:
				return str(n)
	return ""

func _capital(g, house_index: int) -> Dictionary:
	var h: Dictionary = g.houses[house_index]
	var p: Dictionary = g.province(str(h.get("capital", "")))
	if not p.is_empty():
		return p
	for q in g.provinces:
		if int(q["owner"]) == house_index:
			return q
	return {}

func _best(courtiers: Array, stat: String) -> int:
	var best: int = 0
	var value: int = -999
	for i in courtiers.size():
		var current: int = int(courtiers[i].get(stat, 0))
		if current > value:
			value = current
			best = i
	return best

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition or _failed:
		return
	_failed = true
	print("STORYTEST FAIL: " + message)
	get_tree().quit(1)
