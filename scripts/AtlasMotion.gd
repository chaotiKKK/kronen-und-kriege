extends Node2D
## Screen-space feedback. Updating effects never rebuilds the map or labels.
const LIMIT := 24
const STEP := 1.0 / 24.0
var host
var enabled := true
var paths: Array[PackedVector2Array] = []
var _elapsed := 0.0
var _transition := 0.0
var _selection := 0.0
var _accumulated := 0.0

func _ready() -> void:
	set_process(false)
	visibility_changed.connect(refresh_activity)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_transition = 0.0
		_selection = 0.0
	refresh_activity()

func play_transition() -> void:
	_transition = 0.30 if enabled else 0.0
	_selection = 0.0
	refresh_activity()

func play_selection() -> void:
	_selection = 0.38 if enabled else 0.0
	refresh_activity()

func set_deliveries(flows: Array) -> void:
	paths.clear()
	for delivery in flows:
		if paths.size() >= LIMIT:
			break
		if int(delivery.get("amount_u", 0)) <= 0:
			continue
		var points := PackedVector2Array()
		for id in delivery.get("path", []):
			var province: Dictionary = host.game.province(str(id))
			if not province.is_empty():
				points.append(host._label_point(province))
		if points.size() >= 2:
			paths.append(points)
	refresh_activity()

func refresh_activity() -> void:
	var moving: bool = is_visible_in_tree() and enabled and (_transition > 0 or _selection > 0 or (host.map_mode == "economy" and not paths.is_empty()))
	set_process(moving)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 720.0)
	_transition = maxf(0.0, _transition - delta)
	_selection = maxf(0.0, _selection - delta)
	_accumulated += delta
	if _accumulated >= STEP or (_transition == 0 and _selection == 0 and (host.map_mode != "economy" or paths.is_empty())):
		_accumulated = 0.0
		refresh_activity()

func _draw() -> void:
	if host.game == null:
		return
	var fit: Array = host._fit()
	var scale := float(fit[0])
	var offset := Vector2(fit[1])
	var canvas := Rect2(Vector2.ZERO, host.size)
	if host.map_mode == "economy":
		for index in paths.size():
			var points: PackedVector2Array = paths[index]
			var phase := fposmod(_elapsed * .53 + index * .21, 1.0) if enabled else .5
			var leg := phase * float(points.size() - 1)
			var from := mini(int(leg), points.size() - 2)
			var pos: Vector2 = points[from].lerp(points[from + 1], leg - from) * scale + offset
			if canvas.grow(-5).has_point(pos):
				draw_circle(pos, 4, Color("152830"), true, -1, true)
				draw_circle(pos, 2.5, Color("fff0a7"), true, -1, true)
	if not enabled:
		return
	if _selection > 0 and not host.selected.is_empty():
		var province: Dictionary = host.game.province(host.selected)
		if not province.is_empty():
			var anchor: Vector2 = host._label_point(province) * scale + offset
			var remaining := _selection / .38
			if canvas.grow(-30).has_point(anchor):
				draw_arc(anchor, lerpf(27.0, 10.0, remaining), 0, TAU, 32, Color(.99, .85, .49, remaining * .87), 2, true)
	if _transition > 0:
		var fraction := _transition / .30
		draw_rect(canvas, Color(.045, .06, .075, .21 * fraction))
