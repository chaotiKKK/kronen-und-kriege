extends Node
## Prüft die Hauswahl: Das Startmenü muss mindestens drei europäische Häuser
## anbieten, und drei verschiedene Häuser müssen startbar sein und spielen können.
## Aufruf: godot --path . res://tests/HouseTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

var main
var frames: int = 0
var played: Array = []
var _checks: int = 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("HOUSETEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 5:
		return
	if main.start_layer == null or not main.start_layer.visible:
		_fail("Startmenü ist beim Start nicht sichtbar")
		return
	var entries: int = main.start_box.get_child_count()
	if entries < 3:
		_fail("Startmenü bietet nur %d Häuser an, mindestens 3 sind nötig" % entries)
		return
	print("Startmenü: %d Häuser wählbar" % entries)
	if not _check(entries >= 3, "Das Startmenü bietet weniger als drei Häuser."):
		return

	for idx in [2, 4, 5]:
		main._start(idx)
		if main.game == null:
			_fail("Spiel wurde für Haus %d nicht erzeugt" % idx)
			return
		if int(main.game.player) != idx:
			_fail("Gewähltes Haus %d, gestartet als %d" % [idx, int(main.game.player)])
			return
		var owned: Array = main.game.owned()
		if owned.is_empty():
			_fail("Haus %d besitzt keine Provinz" % idx)
			return
		var province: Dictionary = owned[0]
		var gold_before: int = int(main.game.house()["gold"])
		if not main.game.can_develop(province["id"]):
			_fail("Haus %d kann %s nicht ausbauen" % [idx, province["id"]])
			return
		var result: Dictionary = main.game.develop(province["id"])
		if not bool(result["ok"]) or int(main.game.house()["gold"]) >= gold_before:
			_fail("Aktion als Haus %d blieb wirkungslos" % idx)
			return
		played.append("%s (%s, %d Provinz(e))" % [
			main.game.house()["name"], main.game.house()["ruler"]["name"], owned.size()
		])
		if not _check(int(main.game.player) == idx and not owned.is_empty() and int(main.game.house()["gold"]) < gold_before, "Haus %d wurde nicht vollständig gespielt." % idx):
			return

	if played.size() < 3:
		_fail("Nur %d Häuser gespielt" % played.size())
		return
	print("HOUSETEST OK: %d europäische Häuser gespielt: %s; %d Prüfungen." % [played.size(), ", ".join(played), _checks])
	get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false
