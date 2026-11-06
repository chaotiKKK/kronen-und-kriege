extends Node
## Prüft die Bronzezeit-Funktionen: eigenes Haus/Land, Heirat, Beilager,
## Verführen, Mord, Entführung, Speichern und Laden.
## Aufruf: godot --headless --path . res://tests/IntrigueTest.tscn

var main
var frames: int = 0
var started: bool = false

func _ready() -> void:
	seed(20261106)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("INTRIGUETEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 5 or started:
		return
	started = true
	_run()

func _run() -> void:
	if main.start_box.get_child_count() != 9:
		_fail("Startmenü hat %d statt 9 Häuser" % main.start_box.get_child_count())
		return

	# Eigenes Haus und Land gründen
	main.edit_ruler.text = "Ari"
	main.edit_house.text = "Haus Aria"
	main.edit_land.text = "Arialand"
	main.create_sex.selected = 0
	main.create_home.selected = 0
	var home_id := str(main.create_home.get_item_metadata(0))
	main.stat_values = {"martial": 20, "diplomacy": 20, "stewardship": 20, "intrigue": 20}
	main._create_begin()
	var g = main.game
	if g == null:
		_fail("Erstellung erzeugte kein Spiel")
		return
	if g.player != 9 or g.houses.size() != 10:
		_fail("Eigenes Haus nicht angelegt (player=%d, Häuser=%d)" % [g.player, g.houses.size()])
		return
	if g.year != -2000 or not g.date_text().contains("v. Chr."):
		_fail("Startjahr ist nicht 2000 v. Chr.: %s" % g.date_text())
		return
	var cap: Dictionary = g.province(home_id)
	if int(cap["owner"]) != 9 or str(cap["name"]) != "Arialand":
		_fail("Eigenes Land nicht übernommen (owner=%d, Name=%s)" % [int(cap["owner"]), cap["name"]])
		return
	print("ERSTELLUNG OK: %s · %s · %s · Start %s" % [
		g.house()["name"], g.house()["ruler"]["name"], cap["name"], g.date_text()
	])

	# Heirat (mehrere Versuche, Abklingzeit im Test zurückgesetzt)
	g.house()["gold"] = 500
	var married := false
	for t in [1, 5, 7, 0, 3, 6, 8]:
		if not g.can_marry(t):
			continue
		var r: Dictionary = g.marry(t)
		if r["ok"]:
			married = true
			break
		g.cooldowns.clear()
		g.house()["gold"] = 500
	if not married or g.house()["spouse"].is_empty():
		_fail("Heirat gelang in sieben Versuchen nicht")
		return
	print("HEIRAT OK: %s aus %s" % [g.house()["spouse"]["name"], g.houses[int(g.house()["spouse"]["house"])]["name"]])

	# Beilager bis Schwangerschaft oder Geburt
	var kids_before: int = g.house()["children"].size()
	var pregnant := false
	for i in 18:
		if g.can_bed():
			g.bed()
		if int(g.house()["pregnant"]) > 0:
			pregnant = true
		g.advance_month()
		if g.house()["children"].size() > kids_before:
			break
	if not pregnant and g.house()["children"].size() == kids_before:
		_fail("Beilager brachte keine Schwangerschaft")
		return
	print("BEILAGER OK: Kinder %d, schwanger %d" % [g.house()["children"].size(), int(g.house()["pregnant"])])

	# Verführen (mehrere Ziele, Abklingzeit im Test zurückgesetzt)
	g.house()["gold"] = 500
	var seduced := false
	var sed_target := -1
	for t in [0, 2, 4, 6, 8]:
		if not g.can_seduce(t):
			continue
		var sed: Dictionary = g.seduce(t)
		if sed["ok"]:
			seduced = true
			sed_target = t
			break
		g.cooldowns.clear()
		g.house()["gold"] = 500
	if not seduced or int(g.house()["lover_house"]) != sed_target:
		_fail("Verführen gelang in fünf Versuchen nicht")
		return
	print("VERFÜHREN OK: Geliebte/r aus %s" % g.houses[sed_target]["name"])

	# Mord mit Nachfolge
	var murdered := false
	var victim := ""
	var new_ruler := ""
	for t in [2, 3, 4, 6, 8]:
		g.house()["gold"] = 500
		if not g.can_murder(t):
			continue
		victim = str(g.houses[t]["ruler"]["name"])
		var mur: Dictionary = g.murder(t)
		if mur["ok"]:
			if str(g.houses[t]["ruler"]["name"]) == victim:
				_fail("Mord ohne Nachfolge")
				return
			new_ruler = str(g.houses[t]["ruler"]["name"])
			murdered = true
			break
		g.cooldowns.clear()
	if not murdered:
		_fail("Mord gelang in fünf Versuchen nicht")
		return
	print("MORD OK: Opfer %s, neuer Herrscher %s" % [victim, new_ruler])

	# Entführen und Lösegeld
	var kidnapped := false
	for t in [3, 0, 4, 6, 8]:
		g.house()["gold"] = 500
		if not g.can_kidnap(t):
			continue
		var kid: Dictionary = g.kidnap(t)
		if kid["ok"]:
			kidnapped = true
			break
		g.cooldowns.clear()
	if not kidnapped or g.captive.is_empty():
		_fail("Entführung gelang in fünf Versuchen nicht")
		return
	var gold_before: int = int(g.house()["gold"])
	var ran: Dictionary = g.ransom_captive()
	if not ran["ok"] or not g.captive.is_empty() or int(g.house()["gold"]) < gold_before + 70:
		_fail("Lösegeld wirkte nicht")
		return
	print("ENTFÜHRUNG OK: Gefangener genommen und Lösegeld kassiert")

	# Speichern und Laden
	var year: int = g.year
	var month: int = g.month
	var gold: int = int(g.house()["gold"])
	var spouse_name: String = ""
	if not g.house()["spouse"].is_empty():
		spouse_name = str(g.house()["spouse"]["name"])
	var province_count: int = g.provinces.size()
	main._save()
	main._load()
	var g2 = main.game
	if g2 == null or g2.player != 9 or g2.houses.size() != 10:
		_fail("Laden verlor das eigene Haus")
		return
	if g2.year != year or g2.month != month or int(g2.house()["gold"]) != gold:
		_fail("Laden verlor Zeit oder Gold")
		return
	if str(g2.province(home_id)["name"]) != "Arialand":
		_fail("Laden verlor den Landesnamen")
		return
	if spouse_name != "" and g2.house()["spouse"].is_empty():
		_fail("Laden verlor den Gemahl")
		return
	if g2.provinces.size() != province_count or g2.opinion.size() != g2.houses.size():
		_fail("Laden verlor Provinzen oder Haltungen")
		return
	print("SPEICHERN/LADEN OK: %s, %d Provinzen, Haltungen %d" % [
		g2.date_text(), g2.provinces.size(), g2.opinion.size()
	])

	# Stammbaum und Erbfolge
	main._show_tree()
	if not main.tree_layer.visible:
		_fail("Stammbaum-Overlay öffnet nicht")
		return
	if main.tree_view.game != main.game or not str(main.tree_title.text).begins_with("Stammbaum"):
		_fail("Stammbaum ist nicht gefüllt")
		return
	var rows := 0
	for node in main.tree_list.get_children():
		if node is HBoxContainer:
			rows += 1
	if rows != g2.house()["children"].size():
		_fail("Erbfolge zeigt %d von %d Kindern" % [rows, g2.house()["children"].size()])
		return
	for child in g2.house()["children"]:
		if not child.has("portrait") or int(child["portrait"]) < 0 or int(child["portrait"]) >= 12:
			_fail("Kind ohne gültiges Porträt")
			return
	main._hide_tree()
	if main.tree_layer.visible:
		_fail("Stammbaum schließt nicht")
		return
	print("STAMMBAUM OK: %d Kinder mit Porträt, Erbfolge vollständig" % rows)
	print("INTRIGUETEST OK: eigenes Haus, Heirat, Beilager, Verführen, Mord, Entführung, Stammbaum, Speichern/Laden")
	get_tree().quit(0)
