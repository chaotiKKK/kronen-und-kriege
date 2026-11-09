extends Node
## Reale Main-Buttons, Kartendaten und Screenshot des neuen Spielpfads.
var main
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start(0)
	if not main.has_method("_refresh_infrastructure"):
		_check(false, "Bedienbarer Forschungs-/Infrastrukturbereich fehlt.")
		_finish()
		return
	main.game.house().gold = 500
	main.refresh()
	if not main.has_method("_show_infrastructure"):
		_check(false, "Direkt erreichbarer Forschungsdialog fehlt.")
		_finish()
		return
	main._show_infrastructure()
	_check(main.infrastructure_layer.visible, "Forschungsdialog wird nicht sichtbar.")
	var button: Button = main.research_buttons["surveying"]
	_check(not button.disabled, "Vermessung ist trotz Voraussetzungen gesperrt.")
	button.pressed.emit()
	_check(main.game.house().research.active == "surveying", "Echter Forschungsbutton startet kein Projekt.")
	for i in 6:
		main.game.advance_month()
	main.refresh()
	main.research_buttons["road_building"].pressed.emit()
	for i in 12:
		main.game.advance_month()
	var a: String = str(main.game.provinces[0].id)
	var b: String = str(main.game.neighbours(a)[0])
	main.game.province(a).owner = 0
	main.game.province(b).owner = 0
	main.selected = a
	main.kernel.select_province(a)
	main.map_view.select(a)
	main.refresh()
	var road_button: Button = null
	for child in main.road_buttons.get_children():
		if child is Button and str(child.get_meta("to", "")) == b:
			road_button = child
	_check(road_button != null, "Straßenbutton zum Nachbarn fehlt.")
	if road_button != null:
		_check(not road_button.disabled, "Legaler Straßenbau ist nicht bedienbar.")
		road_button.pressed.emit()
		_check(main.game.roads.size() == 1, "Straßenbutton erzeugt keine Baustelle.")
		for i in 3:
			main.game.advance_month()
		main.refresh()
		_check(main.map_view.infrastructure_segments().size() == 1, "Fertige Straße fehlt im Kartenpfad.")
		_check(main.map_view.infrastructure_segments()[0].state == "complete", "Karte zeigt falschen Baustatus.")
		main.game.year = 2200
		main.game.month = 12
		main.refresh()
		_check(main.sandbox_button.visible, "Sandbox-Fortsetzung ist nicht bedienbar.")
		main.sandbox_button.pressed.emit()
		_check(main.game.campaign_sandbox, "Sandbox-Button verändert den Spielstand nicht.")
		main.game.year = -1999
		main.game.month = 10
		if main.game.pending_event != null:
			main._choose(0)
		main.refresh()
		main._show_infrastructure()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			_check(image.save_png("res://build/verify/banger-queens-infrastructure.png") == OK, "Ingame-Bild nicht speicherbar.")
	_finish()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("INFRASTRUCTUREUITEST FAIL: " + message)

func _finish() -> void:
	print("INFRASTRUCTUREUITEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
