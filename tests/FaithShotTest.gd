extends Node
## Erzeugt echte, gerenderte Screenshots des Glaubensbildschirms (oben und
## gescrollt bis Ketzerei/Reform/heiliger Krieg) und des Hofbildschirms.
## Braucht ein echtes Fenster, kein Headless.
##
## Aufruf: godot --path . res://tests/FaithShotTest.tscn --resolution 1280x720

var main
var frames: int = 0
var shots: int = 0
var _checks: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAITHSHOT FAIL: Godot läuft headless; der Viewport wird nicht gerendert.")
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
		print("FAITHSHOT FAIL: %s konnte nicht gespeichert werden (%d)." % [path, err])
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
			h["gold"] = 1000
			h["prestige"] = 100
			h["faith"]["piety"] = 80
			h["faith"]["heresy"] = 65
			h["faith"]["reform"] = 2
			main.game._refresh_faith_power(0)
			var war: Dictionary = main.game.declare_holy_war(2)
			if not war.get("ok", false):
				print("FAITHSHOT FAIL: heiliger Krieg konnte nicht erklärt werden: %s" % str(war.get("message", "")))
				get_tree().quit(1)
				return
			main._show_faith()
		32:
			_shot("ui_faith")
			var scroll := main.faith_body.get_parent() as ScrollContainer
			if scroll != null:
				scroll.scroll_vertical = 240
		48:
			if main.faith_war_marker == null or not main.faith_war_marker.visible:
				print("FAITHSHOT FAIL: Kriegsziel-Marker fehlt im Screenshot.")
				get_tree().quit(1)
				return
			_shot("ui_faith_wave10")
			main._hide_faith()
			main._show_court()
		64:
			_shot("ui_court")
			print("FAITHSHOT OK: %d echte Screenshots; %d Prüfungen." % [shots, _checks])
			get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	print("FAITHSHOT FAIL: " + message)
	get_tree().quit(1)
	return false
