extends Node
## Renderer acceptance of the five existing mode controls and embedded miniatures.
const Modes = preload("res://scripts/MapModes.gd")
var _checks := 0
var _failed := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LivingAtlasTest needs a renderer.")
		get_tree().quit(2)
		return
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed = 0
	var mode_view = main.map_view
	var province: Dictionary = main.game.province(str(main.game.house().capital))
	main._on_province_selected(str(province.id))
	await _wait_frames()
	var original_state: Dictionary = main.game.snapshot()
	var zoom: float = mode_view.zoom
	var pan: Vector2 = mode_view.pan
	var miniature = main.get_meta("modern_interface").map_miniature
	var proof := OS.get_environment("BQ_LIVING_ATLAS_PROOF")
	if proof.is_empty():
		proof = "res://build/verify/living-atlas"
	var overlays := {}
	for mode in ["terrain", "titles", "economy", "war", "political"]:
		await _touch(main.map_mode_buttons[mode])
		await get_tree().create_timer(.42).timeout
		await _wait_frames()
		_check(mode_view.map_mode == mode and main.map_mode_buttons[mode].button_pressed, "Touch wählt "+mode)
		_check(main.selected == str(province.id) and is_equal_approx(mode_view.zoom, zoom) and mode_view.pan.is_equal_approx(pan), "Kartenauswahl und Kamera bleiben erhalten")
		_check(miniature.current_mode == mode and miniature._model != null, "GLB-Szene geladen: "+mode)
		var image: Image = miniature._viewport.get_texture().get_image()
		_check(image != null and not image.is_empty() and image.get_used_rect().get_area() > 300, "Echte 3D-Pixel im Kartenkopf: "+mode)
		if image != null and not image.is_empty(): overlays[image.get_data().hex_encode().sha256_text()] = true
		_check(main.map_header_meta.is_visible_in_tree() and main.map_header_meta.size.y > 0 and main.map_header_meta.get_visible_line_count() == 1, "Ortskontext hat sichtbare Zeilenhöhe: "+mode)
		_check(main.map_header_meta.text == Modes.context_line(main.game, province, mode, mode_view.title_level), "Passender Ortskontext: "+mode)
		_check(mode_view._base.border_counts.get("front", 0) > 0 if mode == "war" else mode_view._base.border_counts.get("front", 0) == 0, "Eigene Grenzlinie nur im Krieg")
		_check(get_viewport().get_texture().get_image().save_png(proof.path_join(mode+".png")) == OK, "Rendererbild gespeichert: "+mode)
	_check(overlays.size() == 5, "Fünf unterschiedliche Modelle gerendert")
	var neighbor: Dictionary = province.duplicate()
	neighbor.owner = (int(province.owner)+1) % main.game.houses.size()
	_check(Modes.border_key(province,neighbor,"political","kingdom",main.game.player) == "owner", "Politikgrenze reagiert auf Besitzer")
	_check(Modes.border_key(province,neighbor,"terrain","kingdom",main.game.player) == "province", "Geländegrenze bleibt bei Besitzerwechsel fest")
	neighbor.kingdom = "anderes_koenigreich"
	_check(Modes.border_key(province,neighbor,"terrain","kingdom",main.game.player) == "kingdom", "Feste Königreichsgrenze")
	var ui = main.get_meta("modern_interface")
	ui.set_text_scale(2.0)
	main._set_map_mode("economy")
	await _wait_frames()
	_check(main.map_mode_buttons.economy.custom_minimum_size.y >= 28, "Kartenreiter bleiben bei 200 Prozent verfügbar")
	_check(get_viewport().get_texture().get_image().save_png(proof.path_join("economy-200.png")) == OK, "Große Schrift gerendert")
	mode_view.set_map_motion_enabled(false)
	main.settings.map_motion = false
	main._set_map_mode("war")
	await _wait_frames()
	_check(not mode_view._motion.is_processing() and miniature._tween == null, "Reduzierte Bewegung stoppt alle Kartenübergänge")
	_check(preload("res://scripts/SaveGame.gd").diff(original_state, main.game.snapshot()).is_empty(), "Kartenansicht verändert keine Spielwerte")
	main._stop_audio()
	print("LIVINGATLAS %s: %d Prüfungen, %d Fehler" % ["OK" if _failed == 0 else "FAIL", _checks, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _wait_frames() -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _touch(button: Button) -> void:
	var point := button.get_viewport().get_screen_transform() * button.get_global_transform_with_canvas() * (button.size * .5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	_check(get_viewport().gui_get_hovered_control() == button, "Touch trifft sichtbaren Reiter "+button.text)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _check(ok: bool, explanation: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		print("LIVINGATLAS FAIL: "+explanation)
