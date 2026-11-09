extends Node
## Erzeugt Prüfbilder von Titelbild, Hausauswahl und Ladebildschirm.
## Aufruf: godot --path . res://tests/TitleShot.tscn --resolution 1280x720

var main
var loading
var frames := 0
var shots := 0
var _checks := 0

func _ready() -> void:
	# Ein frischer Checkout enthält build/ nicht; die Bildpfade müssen trotzdem
	# beschreibbar sein, bevor der erste Screenshot fällt.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("TITLESHOTS FAIL: " + msg)
	get_tree().quit(1)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "res://build/%s.png" % name
	var err := img.save_png(path)
	if err != OK:
		_fail("%s konnte nicht gespeichert werden (%d)." % [path, err])
		return
	if not _check(err == OK and img.get_width() > 0 and img.get_height() > 0, "%s ist leer oder fehlerhaft." % path):
		return
	shots += 1
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])

func _process(_delta: float) -> void:
	frames += 1
	match frames:
		24:
			_shot("ui_title")
		26:
			main._show_newgame()
		44:
			_shot("ui_newgame")
		46:
			main._hide_newgame()
		52:
			loading = load("res://scenes/Loading.tscn").instantiate()
			add_child(loading)
		110:
			_shot("ui_loading")
		116:
			print("TITLESHOTS OK: %d Bilder; %d Prüfungen." % [shots, _checks])
			get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false
