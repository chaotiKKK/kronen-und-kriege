extends Node
## Erzeugt Prüfbilder der Oberfläche (Start, Erstellung, Spiel, Kartenmodi).
## Aufruf: godot --path . res://tests/ShotTest.tscn --resolution 1280x720
## Kein Headless, damit der Viewport tatsächlich gerendert wird.

var main
var frames: int = 0
var shots: int = 0
var _checks: int = 0

func _ready() -> void:
	# Ein frischer Checkout enthält build/ nicht; die Bildpfade müssen trotzdem
	# beschreibbar sein, bevor der erste Screenshot fällt.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("SHOTTESTS FAIL: " + msg)
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

func _mode_shot(mode: String) -> void:
	var dir := "res://build/verify/map-modes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img := get_viewport().get_texture().get_image()
	var width := img.get_width()
	var path := "%s/%s_%d.png" % [dir, mode, width]
	var err := img.save_png(path)
	if err != OK:
		_fail("%s konnte nicht gespeichert werden (%d)." % [path, err])
		return
	if not _check(err == OK and width > 0 and img.get_height() > 0, "%s ist leer oder fehlerhaft." % path):
		return
	shots += 1
	print("SHOT MODE %s %dx%d -> %s" % [mode, width, img.get_height(), path])

func _hover_world_map() -> void:
	var owned: Array = main.game.owned()
	if owned.is_empty():
		return
	var p: Dictionary = owned[0]
	var fit: Array = main.map_view._fit()
	var pos: Vector2 = main.map_view._label_point(p) * float(fit[0]) + (fit[1] as Vector2)
	main.map_view.hover_at(pos)

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
			var owned: Array = main.game.owned()
			if not owned.is_empty():
				main.map_view.select(str(owned[0]["id"]))
				main._on_province_selected(str(owned[0]["id"]))
			for target_id in ["makedonia", "boiohaemum", "borysthenes", "latium"]:
				var target = main.game.province(target_id)
				if not target.is_empty() and int(target["owner"]) != main.game.player:
					target["siege"] = 42
					target["siege_owner"] = main.game.player
					break
			main.map_view.queue_redraw()
			main._set_map_mode("political")
		84:
			_mode_shot("political")
			main._set_map_mode("terrain")
		88:
			_mode_shot("terrain")
			main._set_map_mode("duchy")
		92:
			_mode_shot("duchy")
			main._set_map_mode("kingdom")
		96:
			_mode_shot("kingdom")
			main._set_map_mode("development")
		100:
			_mode_shot("development")
			main._set_map_mode("war")
		104:
			_mode_shot("war")
			main._set_map_mode("political")
		106:
			_hover_world_map()
		108:
			_shot("ui_hover")
		110:
			main._toggle_map_legend()
		112:
			_shot("ui_legend")
		114:
			main._toggle_map_legend()
			main._show_tree()
		116:
			_shot("ui_tree")
		118:
			main._hide_tree()
			main._open_customizer()
		138:
			_shot("ui_customize")
		140:
			print("SHOTTESTS OK: %d Bilder; %d Prüfungen." % [shots, _checks])
			get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false
