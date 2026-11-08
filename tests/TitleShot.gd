extends Node
## Erzeugt Prüfbilder von Titelbild, Hausauswahl und Ladebildschirm.
## Aufruf: godot --path . res://tests/TitleShot.tscn --resolution 1280x720

var main
var loading
var frames := 0
var shots := 0

func _ready() -> void:
	# Ein frischer Checkout enthält build/ nicht; die Bildpfade müssen trotzdem
	# beschreibbar sein, bevor der erste Screenshot fällt.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://build/%s.png" % name)
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
			print("TITLESHOTS OK: %d Bilder" % shots)
			get_tree().quit(0)
