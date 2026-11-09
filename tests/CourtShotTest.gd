extends Node
## Nimmt den Hofbildschirm und die freie Hofhallen-Kulisse in einem echten
## Godot-Fenster auf. Kein Headless: sonst liefert der Viewport kein Bild.
##
## Aufruf: godot --path . res://tests/CourtShotTest.tscn --resolution 1600x900

var main
var frames: int = 0
var shots: int = 0
var _checks: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("COURTSHOT FAIL: Godot läuft headless; der Viewport wird nicht gerendert.")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "res://build/%s.png" % name
	var err := img.save_png(path)
	if err != OK:
		print("COURTSHOT FAIL: %s konnte nicht gespeichert werden (%d)." % [path, err])
		get_tree().quit(1)
		return
	if not _check(err == OK and img.get_width() > 0 and img.get_height() > 0, "%s ist leer oder fehlerhaft." % path):
		return
	shots += 1
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])

func _process(_delta: float) -> void:
	frames += 1
	match frames:
		8:
			main._start(0)
			main.game.speed = 0
			var h: Dictionary = main.game.house()
			h["gold"] = 2000
			h["prestige"] = 400
			h["legitimacy"] = 55
			for relic_id in main.game.RELIC_ORDER:
				var forged: Dictionary = main.game.forge_relic(str(relic_id))
				if not forged.get("ok", false):
					print("COURTSHOT FAIL: Reliquie %s nicht schmiedbar: %s" % [str(relic_id), str(forged.get("msg", ""))])
					get_tree().quit(1)
					return
			for i in 2:
				var built: Dictionary = main.game.upgrade_court_hall()
				if not built.get("ok", false):
					print("COURTSHOT FAIL: Hofhalle Stufe %d nicht ausbaubar: %s" % [i + 1, str(built.get("msg", ""))])
					get_tree().quit(1)
					return
			for amenity_id in ["table", "table", "chambers", "retinue"]:
				var furnished: Dictionary = main.game.upgrade_court_amenity(str(amenity_id))
				if not furnished.get("ok", false):
					print("COURTSHOT FAIL: Ausstattung %s nicht ausbaubar: %s" % [str(amenity_id), str(furnished.get("msg", ""))])
					get_tree().quit(1)
					return
			main._show_court()
		40:
			if main.court_hall_preview == null or not main.court_hall_preview.is_visible_in_tree():
				print("COURTSHOT FAIL: Hofhallen-Vorschau fehlt im normalen Hofbildschirm.")
				get_tree().quit(1)
				return
			if not main.court_hall_stage_label.text.contains("Stufe 2/3"):
				print("COURTSHOT FAIL: Hofhallen-Stufe 2/3 fehlt in der Vorschau.")
				get_tree().quit(1)
				return
			if not main.court_hall_stats_label.text.contains("Hofpracht 100/100 · Reliquien 3/3"):
				print("COURTSHOT FAIL: Hofwerte fehlen in der Vorschau.")
				get_tree().quit(1)
				return
			if main.court_expectation_label == null or not main.court_expectation_label.text.contains("Erwartet") or not main.court_expectation_label.text.contains("Aktuell 100"):
				print("COURTSHOT FAIL: Zielkorridor fehlt in der Hallenvorschau.")
				get_tree().quit(1)
				return
			if main.game.court_amenity_total() != 4 or main.game.court_amenity_upkeep() != 32:
				print("COURTSHOT FAIL: Ausstattungsstufen oder Unterhalt stimmen nicht.")
				get_tree().quit(1)
				return
			for amenity_id in main.game.COURT_AMENITY_ORDER:
				if main.game.court_amenity_level(str(amenity_id)) < 1 or not main.court_amenity_buttons.has(str(amenity_id)):
					print("COURTSHOT FAIL: Ausstattungslinie %s fehlt." % str(amenity_id))
					get_tree().quit(1)
					return
			_shot("ui_court_hall3")
			# Für die Asset-Prüfung die Kulisse ohne Panel und Abdunklung zeigen.
			main.court_layer.get_child(1).visible = false
			main.court_layer.get_child(2).visible = false
		48:
			_shot("ui_court_hall_asset")
			print("COURTSHOT OK: %d echte Fenster-Screenshots; %d Prüfungen." % [shots, _checks])
			get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	print("COURTSHOT FAIL: " + message)
	get_tree().quit(1)
	return false