extends Node
## Erzeugt Prüfbilder der Oberfläche (Start, Erstellung, Spiel).
## Aufruf: godot --path . res://tests/ShotTest.tscn --resolution 1280x720
## Kein Headless, damit der Viewport tatsächlich gerendert wird.

var main
var frames: int = 0
var shots: int = 0

func _ready() -> void:
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
			_shot("ui_start")
		26:
			main._show_create()
		44:
			_shot("ui_create")
		46:
			main._hide_create()
			main._start(2)
		78:
			_shot("ui_game")
		80:
			main._show_tree()
		100:
			_shot("ui_tree")
		102:
			main._hide_tree()
			main._open_customizer()
		120:
			_shot("ui_customize")
		122:
			print("SHOTTESTS OK: %d Bilder" % shots)
			get_tree().quit(0)
