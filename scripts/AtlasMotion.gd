extends Node2D
## Screen-space feedback. Updating effects never rebuilds the map or labels.
const LIMIT := 24
const STEP := 1.0 / 24.0
const GRAIN_CART = preload("res://assets/map/freight/grain_cart.png")
const MARCH_PENNANT = preload("res://assets/map/war/march_pennant.png")
var host
var enabled := true
var paths: Array[PackedVector2Array] = []
var frontier_paths: Array[PackedVector2Array] = []
var food_paths: Array[PackedVector2Array] = []
var march_overlay: Dictionary = {}
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

func set_deliveries(flows: Array, front_supplies: Array = [], provisions: Array = []) -> void:
	paths = _map_paths(flows, "amount_u")
	frontier_paths = _map_paths(front_supplies, "amount")
	food_paths = _map_paths(provisions, "amount_u")
	refresh_activity()

func set_march_preview(preview: Dictionary) -> void:
	march_overlay = {}
	if preview.get("ok",false):
		var a: Dictionary = host.game.province(str(preview.origin))
		var b: Dictionary = host.game.province(str(preview.target))
		var points := PackedVector2Array([host._label_point(a),host._label_point(b)])
		march_overlay = {"origin":preview.origin,"target":preview.target,"points":points,
			"shortfall":int(preview.supply.shortfall)}
	refresh_activity()

func _map_paths(flows: Array, amount_field: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for delivery in flows:
		if result.size() >= LIMIT:
			break
		if int(delivery.get(amount_field, 0)) <= 0:
			continue
		var points := PackedVector2Array()
		for id in delivery.get("path", []):
			var province: Dictionary = host.game.province(str(id))
			if not province.is_empty():
				points.append(host._label_point(province))
		if points.size() >= 2:
			result.append(points)
	return result

func _current_paths() -> Array[PackedVector2Array]:
	match host.map_mode:
		"economy": return paths
		"war": return frontier_paths
	return []

func _has_routes() -> bool:
	return not _current_paths().is_empty() or (host.map_mode=="economy" and not food_paths.is_empty()) or (host.map_mode=="war" and not march_overlay.is_empty())

func refresh_activity() -> void:
	var moving: bool = is_visible_in_tree() and enabled and (_transition > 0 or _selection > 0 or _has_routes())
	set_process(moving)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 720.0)
	_transition = maxf(0.0, _transition - delta)
	_selection = maxf(0.0, _selection - delta)
	_accumulated += delta
	if _accumulated >= STEP or (_transition == 0 and _selection == 0 and not _has_routes()):
		_accumulated = 0.0
		refresh_activity()

func _draw() -> void:
	if host.game == null:
		return
	var fit: Array = host._fit()
	var scale := float(fit[0])
	var offset := Vector2(fit[1])
	var canvas := Rect2(Vector2.ZERO, host.size)
	var active_routes := _current_paths()
	var ink := Color("152830")
	var light := Color("a9fff0") if host.map_mode == "war" else Color("fff0a7")
	for index in active_routes.size():
		var points := active_routes[index]
		var pos := _cargo_position(points, index, .53) * scale + offset
		if canvas.grow(-5).has_point(pos):
			draw_circle(pos, 4, ink, true, -1, true)
			draw_circle(pos, 2.5, light, true, -1, true)
	if host.map_mode=="economy":
		for index in food_paths.size():
			var pos := _cargo_position(food_paths[index], index, .34) * scale + offset
			if canvas.grow(-16).has_point(pos):
				draw_circle(pos, 12.0, Color("293029"), true, -1.0, true)
				draw_circle(pos, 12.0, Color("dfc583"), false, 1.5, true)
				draw_texture_rect(GRAIN_CART, Rect2(pos-Vector2(15,17),Vector2(30,30)), false)
	if host.map_mode == "war" and not march_overlay.is_empty():
		_draw_march(scale,offset,canvas)
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


func _draw_march(scale: float, offset: Vector2, canvas: Rect2) -> void:
	var points: PackedVector2Array = march_overlay.points
	var a := points[0]*scale+offset
	var b := points[1]*scale+offset
	if a.distance_squared_to(b) < 4.0: return
	var heading := (b-a).normalized()
	var side := Vector2(-heading.y,heading.x)
	var light := Color("ffc0b4") if int(march_overlay.shortfall)>0 else Color("f5f1ca")
	var ink := Color("17242a")
	var left := b-heading*10+side*5
	var right := b-heading*10-side*5
	draw_line(a,b,ink,5.0,true)
	draw_dashed_line(a,b,light,2.4,6.0,true,true)
	draw_polyline(PackedVector2Array([left,b,right]),ink,6.0,true)
	draw_polyline(PackedVector2Array([left,b,right]),light,2.5,true)
	var t := .18+.52*fposmod(_elapsed*.42,1.0) if enabled else .5
	var pos := a.lerp(b,t)
	if canvas.grow(-13).has_point(pos):
		draw_circle(pos,10.0,ink,true,-1,true)
		draw_circle(pos,10.0,light,false,1.2,true)
		draw_texture_rect(MARCH_PENNANT,Rect2(pos-Vector2(13,14),Vector2(26,26)),false)

func _cargo_position(points: PackedVector2Array, index: int, velocity: float) -> Vector2:
	var phase := fposmod(_elapsed * velocity + index * .21, 1.0) if enabled else .5
	var leg := phase * float(points.size() - 1)
	var from := mini(int(leg), points.size() - 2)
	return points[from].lerp(points[from + 1], leg - from)
