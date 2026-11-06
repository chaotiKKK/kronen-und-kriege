extends Node
## Automatischer Touch-Test: speist echte InputEventScreenTouch-Events in den
## Viewport ein und prüft, ob Provinzauswahl und Button-Aktion ausgelöst werden.
## Aufruf: godot --path . res://tests/TouchTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

var main
var frames: int = 0
var phase: int = 0
var last_pos := Vector2.ZERO
var dev_before: int = 0
var gold_before: int = 0
var touch_pos := Vector2.ZERO
var target_id: String = ""

func _ready() -> void:
	# Der Test rechnet in Fensterkoordinaten; 1:1 vermeidet Stretch-Umrechnung.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	# Hauswahl überspringen: als Falkenried starten, damit die Karte bedienbar ist.
	main._start(0)

func _centroid(poly: Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())

func _touch(pos: Vector2, pressed: bool) -> void:
	last_pos = pos
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _fail(msg: String) -> void:
	print("TOUCHTEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 30:
		return
	match phase:
		0:
			var owned: Array = main.game.owned()
			if owned.is_empty():
				_fail("Haus 0 besitzt keine Grafschaft")
				return
			target_id = str(owned[0]["id"])
			var p: Dictionary = main.game.province(target_id)
			var c := _centroid(p["points"])
			var fit: Array = main.map_view._fit()
			var local: Vector2 = c * float(fit[0]) + (fit[1] as Vector2)
			var screen: Vector2 = main.map_view.get_global_rect().position + local
			touch_pos = screen
			_touch(screen, true)
			phase = 1
		1:
			_touch(last_pos, false)
			phase = 2
		2:
			phase = 3
		3:
			if main.selected != target_id:
				var fit2: Array = main.map_view._fit()
				var mp: Vector2 = (touch_pos - (fit2[1] as Vector2)) / float(fit2[0])
				_fail("Grafschaft wurde nicht per ScreenTouch gewählt (selected='%s', erwartet '%s', Touch bei %s, MapView %s, fit %s, Punkt %s)" % [main.selected, target_id, str(touch_pos), str(main.map_view.size), str(fit2), str(mp)])
				return
			dev_before = int(main.game.province(target_id)["dev"])
			gold_before = int(main.game.house()["gold"])
			var r: Rect2 = main.develop_btn.get_global_rect()
			_touch(r.get_center(), true)
			phase = 4
		4:
			_touch(last_pos, false)
			phase = 5
		5:
			var dev_after: int = int(main.game.province(target_id)["dev"])
			var gold_after: int = int(main.game.house()["gold"])
			if dev_after != dev_before + 1:
				_fail("Ausbau-Button reagierte nicht auf Touch (Entwicklung %d -> %d)" % [dev_before, dev_after])
				return
			if not gold_after < gold_before:
				_fail("Gold wurde nicht abgezogen (%d -> %d)" % [gold_before, gold_after])
				return
			print("TOUCHTEST OK: Provinz per InputEventScreenTouch gewählt, Ausbau per Touch ausgelöst (%d -> %d Entwicklung, Gold %d -> %d)." % [dev_before, dev_after, gold_before, gold_after])
			get_tree().quit(0)
