extends Node
## Fenstertest für die Seekriegsmarker auf der echten Kriegskarte.
## Aufruf: godot --path . res://tests/NavalRenderTest.tscn --resolution 1600x900
## Geprüft werden der reale Draw-Pfad, sichtbare Pixel, Hausfarbenring,
## Schiffszahl und Provinzposition sowie das Markerende nach Frieden,
## Eroberung und Versenkung. Kein Headless: ohne Rendering gibt es keine Pixel.

const MAIN_SCENE := "res://scenes/Main.tscn"

var main
var game
var _checks := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("NavalRenderTest braucht ein echtes Fenster")
		return
	main = load(MAIN_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start(2)
	game = main.game
	game.speed = 0
	if main.ambient_player != null:
		main.ambient_player.stop()
	main._set_map_mode("war")
	_clear_selection()
	await _settle()
	await _run()

func _run() -> void:
	var port := _pick_port()
	if not _expect(not port.is_empty(), "Keine sichtbare eigene Küstenprovinz gefunden."):
		return
	var baseline: Image = await _capture()
	_expect(main.map_view.fleet_markers_drawn.is_empty(), "Vor der Flotte ist bereits ein Flottenmarker im Draw-Pfad.")
	if not _expect(main.map_view._unit_tex.get("fleet", null) != null, "unit_fleet.png wurde von MapView nicht geladen."):
		return

	game.house()["gold"] = 500
	var raised: Dictionary = _dispatch_on(port, "fleet")
	if not _expect(bool(raised.get("ok", false)), "Flottenaufstellung über die Szene scheiterte: %s" % str(raised.get("message", ""))):
		return
	var fleet: Dictionary = game.fleet_for()
	var ships := int(fleet.get("ships", 0))
	if not _expect(ships > 0 and str(fleet.get("station", "")) == str(port["id"]), "Flotte liegt nicht mit positiver Schiffszahl im Hafen."):
		return
	main.refresh()
	var port_image: Image = await _settle_and_capture()
	var port_marker := _check_marker(port, ships, port_image, baseline, "Hafen")
	if port_marker.is_empty():
		return

	var peace_target := _pick_target(port, -1)
	if peace_target.is_empty():
		_fail("Kein sichtbares Küstenziel für den Friedensfall gefunden.")
		return
	var peace_owner := int(peace_target["owner"])
	var blocked := _dispatch_on(peace_target, "blockade")
	if not _expect(bool(blocked.get("ok", false)), "Blockade für den Friedensfall scheiterte: %s" % str(blocked.get("message", ""))):
		return
	main.refresh()
	var blockade_image: Image = await _settle_and_capture()
	var blockade_marker := _check_marker(peace_target, ships, blockade_image, baseline, "Blockade")
	if blockade_marker.is_empty():
		return
	_expect(_marker_for(str(port["id"])).is_empty(), "Der Hafenmarker bleibt während der Blockade sichtbar.")
	_expect(_changed_pixels(port_image, blockade_image, _marker_rect(port_marker)) > 12, "Der Flottenmarker ist am Ziel nicht sichtbar verändert.")
	_expect(str(game.province(str(peace_target["id"])).get("blockade_owner", -1)) == str(game.player), "Die laufende Blockade gehört nicht dem Spielerhaus.")

	var peace: Dictionary = game.make_peace(peace_owner)
	if not _expect(bool(peace.get("ok", false)), "Frieden scheiterte: %s" % str(peace.get("msg", ""))):
		return
	main.refresh()
	var peace_image: Image = await _settle_and_capture()
	_expect(_marker_for(str(peace_target["id"])).is_empty(), "Der Blockademarker überlebt den Frieden.")
	_expect(_changed_pixels(blockade_image, peace_image, _marker_rect(blockade_marker)) > 12, "Der Blockademarker ist nach Frieden nicht sichtbar entfernt.")
	_expect(not _marker_for(str(port["id"])).is_empty(), "Die Flotte kehrt nach Frieden nicht als Hafenmarker zurück.")

	var capture_target := _pick_target(port, peace_owner)
	if capture_target.is_empty():
		_fail("Kein sichtbares Küstenziel für den Eroberungsfall gefunden.")
		return
	blocked = _dispatch_on(capture_target, "blockade")
	if not _expect(bool(blocked.get("ok", false)), "Blockade für den Eroberungsfall scheiterte: %s" % str(blocked.get("message", ""))):
		return
	main.refresh()
	var capture_before: Image = await _settle_and_capture()
	var capture_marker := _check_marker(capture_target, ships, capture_before, baseline, "Eroberung")
	if capture_marker.is_empty():
		return
	game._capture_province(str(capture_target["id"]), game.player)
	main.refresh()
	var capture_after: Image = await _settle_and_capture()
	_expect(_marker_for(str(capture_target["id"])).is_empty(), "Der Blockademarker überlebt die Eroberung.")
	_expect(int(game.province(str(capture_target["id"])).get("blockade", 0)) == 0, "Die Eroberung beendet die Blockade nicht.")
	_expect(_changed_pixels(capture_before, capture_after, _marker_rect(capture_marker)) > 12, "Der Blockademarker ist nach Eroberung nicht sichtbar entfernt.")
	_expect(not _marker_for(str(port["id"])).is_empty(), "Die Flotte kehrt nach Eroberung nicht als Hafenmarker zurück.")

	var sink_target := _pick_target(port, peace_owner)
	if sink_target.is_empty():
		_fail("Kein sichtbares Küstenziel für den Versenkungsfall gefunden.")
		return
	blocked = _dispatch_on(sink_target, "blockade")
	if not _expect(bool(blocked.get("ok", false)), "Blockade für den Versenkungsfall scheiterte: %s" % str(blocked.get("message", ""))):
		return
	main.refresh()
	var sink_before: Image = await _settle_and_capture()
	var sink_marker := _check_marker(sink_target, ships, sink_before, baseline, "Versenkung")
	if sink_marker.is_empty():
		return
	game._sink_fleet(game.player, game.fleet_for())
	main.refresh()
	var sink_after: Image = await _settle_and_capture()
	_expect(main.map_view.fleet_markers_drawn.is_empty(), "Nach der Versenkung bleibt ein Flottenmarker im Draw-Pfad.")
	_expect(_changed_pixels(sink_before, sink_after, _marker_rect(sink_marker)) > 12, "Der Flottenmarker ist nach Versenkung nicht sichtbar entfernt.")
	_expect(_changed_pixels(sink_before, sink_after, _marker_rect(port_marker)) <= 8, "Am Hafen erscheint nach der Versenkung fälschlich wieder ein Marker.")

	print("NAVALRENDERTEST OK: Kriegskarte, sichtbarer unit_fleet-Marker mit Hausfarbenring, %d Schiffen und Provinzposition; Marker verschwindet nach Frieden, Eroberung und Versenkung; %d Prüfungen." % [ships, _checks])
	get_tree().quit(0)

func _check_marker(province: Dictionary, ships: int, image: Image, baseline: Image, phase: String) -> Dictionary:
	var marker := _marker_for(str(province["id"]))
	if not _expect(not marker.is_empty(), "%s: kein Flottenmarker für %s im Draw-Pfad." % [phase, str(province["id"])]):
		return {}
	if not _expect(main.map_view.fleet_markers_drawn.size() == 1, "%s: es wird nicht genau ein Flottenmarker gezeichnet." % phase):
		return {}
	if not _expect(int(marker.get("house", -1)) == game.player, "%s: Marker gehört nicht zum Spielerhaus." % phase):
		return {}
	if not _expect(str(marker.get("token_path", "")).ends_with("unit_fleet.png"), "%s: Marker nutzt nicht den vorhandenen Flotten-Token." % phase):
		return {}
	if not _expect(int(marker.get("ships", -1)) == ships, "%s: Marker zeigt nicht die Flottenschiffszahl." % phase):
		return {}
	if not _expect(str(marker.get("label", "")) == str(ships), "%s: Marker beschriftet nicht die Schiffszahl." % phase):
		return {}
	var expected_pos := _expected_marker_pos(province)
	if not _expect((marker.get("pos", Vector2.ZERO) as Vector2).distance_to(expected_pos) < 0.01, "%s: Marker sitzt nicht an der erwarteten Provinzposition." % phase):
		return {}
	var expected_color: Color = game.houses[game.player].get("color", Color.WHITE)
	var ring_color: Color = marker.get("ring_color", Color.BLACK)
	if not _expect(_color_distance(ring_color, expected_color) < 0.02, "%s: Markerring hat nicht die Hausfarbe." % phase):
		return {}
	var center := _image_point(expected_pos, image)
	var scale := float(image.get_width()) / get_viewport().get_visible_rect().size.x
	var hits := _ring_hits(image, baseline, center, expected_color, scale)
	if not _expect(hits >= 20, "%s: Hausfarbenring ist nicht sichtbar (nur %d Farbtreffer)." % [phase, hits]):
		return {}
	var diff := _changed_pixels(baseline, image, _marker_rect(marker))
	if not _expect(diff >= 30, "%s: Flotten-Token verändert die Provinzposition nicht sichtbar (nur %d Pixel)." % [phase, diff]):
		return {}
	var label_diff := _changed_pixels(baseline, image, _label_rect(marker))
	if not _expect(label_diff >= 4, "%s: Schiffszahl ist nicht sichtbar beschriftet (nur %d Pixel)." % [phase, label_diff]):
		return {}
	print("NAVALRENDERTEST MARKER %s: house=%d province=%s ships=%s pos=%s ring_hits=%d diff=%d label_diff=%d" % [
		phase, game.player, str(province["id"]), str(marker.get("label", "")),
		str(marker.get("pos", Vector2.ZERO)), hits, diff, label_diff,
	])
	return marker

func _pick_port() -> Dictionary:
	for p in game.provinces:
		if int(p["owner"]) != game.player or not game.is_coastal(str(p["id"])):
			continue
		if _marker_is_safe(p):
			return p
	return {}

func _pick_target(port: Dictionary, excluded_owner: int) -> Dictionary:
	for p in game.provinces:
		if int(p["owner"]) == game.player or int(p["owner"]) == excluded_owner:
			continue
		if not game.is_coastal(str(p["id"])):
			continue
		if not _marker_is_safe(p):
			continue
		if not game._maritime_reachable(str(port["id"]), str(p["id"])):
			continue
		if int(p.get("blockade", 0)) > 0:
			continue
		return p
	return {}

func _marker_is_safe(p: Dictionary) -> bool:
	var local := _expected_marker_pos(p)
	var screen: Vector2 = main.map_view.get_global_transform_with_canvas() * local
	var rect: Rect2 = main.map_view.get_global_rect()
	if not rect.grow(-42).has_point(screen):
		return false
	# Kartenwerkzeuge oben rechts und Legende unten links nicht überdecken.
	if screen.x > rect.end.x - 180.0 and screen.y < rect.position.y + 66.0:
		return false
	if screen.x < rect.position.x + 286.0 and screen.y > rect.end.y - 154.0:
		return false
	return true

func _expected_marker_pos(p: Dictionary) -> Vector2:
	var fit: Array = main.map_view._fit()
	var pos: Vector2 = main.map_view._label_point(p) * float(fit[0]) + (fit[1] as Vector2) + Vector2(0, 22)
	if int(p.get("siege", 0)) > 0:
		pos += Vector2(20, 0)
	return pos

func _marker_for(province_id: String) -> Dictionary:
	for marker in main.map_view.fleet_markers_drawn:
		if str(marker.get("province", "")) == province_id:
			return marker
	return {}

func _dispatch_on(province: Dictionary, command: String) -> Dictionary:
	main.kernel.select_province(str(province["id"]))
	main.selected = str(province["id"])
	main.map_view.select(str(province["id"]))
	var result: Dictionary = main._dispatch({"id": command})
	_clear_selection()
	return result

func _clear_selection() -> void:
	if main == null:
		return
	main.kernel.select_province("")
	main.selected = ""
	main.map_view.select("")

func _settle() -> void:
	main.map_view.queue_redraw()
	if main.map_view._base != null:
		main.map_view._base.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _settle_and_capture() -> Image:
	await _settle()
	return await _capture()

func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _image_point(local: Vector2, image: Image) -> Vector2:
	var viewport_pos: Vector2 = main.map_view.get_global_transform_with_canvas() * local
	var scope: Vector2 = get_viewport().get_visible_rect().size
	return viewport_pos * Vector2(float(image.get_width()) / scope.x, float(image.get_height()) / scope.y)

func _marker_rect(marker: Dictionary) -> Rect2:
	return (marker.get("token_rect", Rect2()) as Rect2).grow(2.0)

func _label_rect(marker: Dictionary) -> Rect2:
	var pos: Vector2 = marker.get("label_pos", Vector2.ZERO)
	return Rect2(pos + Vector2(-1, -10), Vector2(30, 16))

func _ring_hits(image: Image, baseline: Image, center: Vector2, color: Color, scale: float) -> int:
	var hits := 0
	for k in 72:
		var angle: float = TAU * float(k) / 72.0
		for dr in [-1.0, 0.0, 1.0]:
			var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * (15.0 * scale + dr)
			var at := Vector2i(roundi(p.x), roundi(p.y))
			var c: Color = image.get_pixelv(at)
			var before: Color = baseline.get_pixelv(at)
			if _color_distance(c, color) < 0.24 and _color_distance(c, before) > 0.06:
				hits += 1
	return hits

func _changed_pixels(before: Image, after: Image, rect_local: Rect2) -> int:
	var a: Vector2 = _image_point(rect_local.position, before)
	var b: Vector2 = _image_point(rect_local.end, before)
	var x0: int = maxi(0, floori(minf(a.x, b.x)))
	var y0: int = maxi(0, floori(minf(a.y, b.y)))
	var x1: int = mini(before.get_width() - 1, ceili(maxf(a.x, b.x)))
	var y1: int = mini(before.get_height() - 1, ceili(maxf(a.y, b.y)))
	var changed := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _color_distance(before.get_pixel(x, y), after.get_pixel(x, y)) > 0.07:
				changed += 1
	return changed

func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false

func _fail(message: String) -> void:
	print("NAVALRENDERTEST FAIL: " + message)
	_dump()
	get_tree().quit(1)

func _dump() -> void:
	if main == null or main.map_view == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/verify"))
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://build/verify/naval-render-fail.png")
	print("NAVALRENDERTEST DUMP image=%dx%d viewport=%s map_rect=%s markers=%s" % [
		img.get_width(), img.get_height(), str(get_viewport().get_visible_rect().size),
		str(main.map_view.get_global_rect()), str(main.map_view.fleet_markers_drawn),
	])
