extends Node
## Spielbarkeits-Test: wählt drei europäische Häuser über die echten Buttons des
## Startmenüs, führt eine Aktion aus, simuliert 18 Monate, speichert, läuft weiter
## und lädt den Stand wieder. Prüft danach Jahr, Monat, Gold und Provinzzahl.
## Aufruf: godot --headless --path . res://tests/HousePlayTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

var main
var frames: int = 0

func _ready() -> void:
	seed(424242)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("PLAYTEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 5:
		return
	if main.start_layer == null or not main.start_layer.visible:
		_fail("Startmenü ist nicht sichtbar")
		return
	var entries: int = main.start_box.get_child_count()
	if entries < 3:
		_fail("Startmenü bietet nur %d Häuser" % entries)
		return
	print("Startmenü: %d Häuser wählbar" % entries)

	var results: Array = []
	for id in [2, 4, 8]:
		if id >= entries:
			_fail("Haus-Index %d fehlt im Menü" % id)
			return
		var button := main.start_box.get_child(id) as Button
		if button == null:
			_fail("Kein Button für Haus %d" % id)
			return
		button.pressed.emit()
		if main.game == null:
			_fail("Start als Haus %d erzeugte kein Spiel" % id)
			return
		if int(main.game.player) != id:
			_fail("Haus %d startete als %d" % [id, int(main.game.player)])
			return
		var owned: Array = main.game.owned()
		if owned.is_empty():
			_fail("Haus %d besitzt keine Provinz" % id)
			return
		var province: Dictionary = owned[0]
		if main.game.can_develop(province["id"]):
			main.game.develop(province["id"])
		for i in 18:
			if main.game.pending_event != null:
				main.game.apply_event(0)
			main.game.advance_month()
		if main.game.pending_event != null:
			main.game.apply_event(0)
		if main.game.game_over:
			_fail("Partie von Haus %d endete vorzeitig" % id)
			return
		var year_before: int = main.game.year
		var month_before: int = main.game.month
		var gold_before: int = int(main.game.house()["gold"])
		var count_before: int = main.game.owned().size()
		main._save()
		if not FileAccess.file_exists("user://spielstand.json"):
			_fail("Spielstand für Haus %d wurde nicht geschrieben" % id)
			return
		for i in 3:
			if main.game.pending_event != null:
				main.game.apply_event(1)
			main.game.advance_month()
		main._load()
		if main.game == null:
			_fail("Laden zerstörte das Spiel von Haus %d" % id)
			return
		if main.game.year != year_before or main.game.month != month_before:
			_fail("Laden ergab %d-%d statt %d-%d (Haus %d)" % [main.game.year, main.game.month, year_before, month_before, id])
			return
		if int(main.game.house()["gold"]) != gold_before:
			_fail("Gold nach Laden %d statt %d (Haus %d)" % [int(main.game.house()["gold"]), gold_before, id])
			return
		if main.game.owned().size() != count_before:
			_fail("Provinzzahl nach Laden verändert (Haus %d)" % id)
			return
		results.append("%d:%s (%d Monate, Stand %d-%02d, Gold %d, %d Provinzen)" % [
			id, main.game.house()["name"], 18, year_before, month_before, gold_before, count_before
		])

	print("PLAYTEST OK: 3 Häuser ausgewählt, gespielt, gespeichert und geladen -> " + " | ".join(results))
	get_tree().quit(0)
