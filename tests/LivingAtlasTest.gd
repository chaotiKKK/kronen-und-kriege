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
	ui.set_text_scale(1.0)
	await _test_front_supply(main,proof)
	await _test_civic_freight(main,proof)
	await _test_irrigation(main,proof)
	main._stop_audio()
	print("LIVINGATLAS %s: %d Prüfungen, %d Fehler" % ["OK" if _failed == 0 else "FAIL", _checks, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _test_front_supply(main, proof: String) -> void:
	var game = main.game
	var mode_view = main.map_view
	var depot := "germanien__03"
	var border := "germanien__02"
	var target := "gallien__05"
	# Controlled on-map fixture. The ordinary NPC campaign proves paid construction separately.
	game.province(depot).logistics_sites.depot = 1
	game.province(depot).economic_focus = "agriculture"
	game.roads.append({"from":depot,"to":border,"state":"complete","months":0,"builder":0})
	game.house().armies.append({"id":1,"province":target,"strength":1800,"upkeep":30,"morale":85,"last_siege_month":-1})
	_check(game.neighbours(border).has(target) and not game.neighbours(depot).has(target),"Echter Grenzübergang liegt zwischen Depot und fremder Front")
	main._on_province_selected(target)
	main.refresh()
	mode_view.set_map_motion_enabled(true)
	await _wait_frames()
	_check(mode_view.frontier_supply_paths()==[[depot,border,target]],"Kriegskarte liest echte Depotroute aus der Simulationsbilanz")
	_check(mode_view._motion.is_processing() and not mode_view._motion.frontier_paths.is_empty(),"Eigener Frontnachschub wird im Kriegsreiter animiert")
	var inspector = main.get_meta("modern_interface").province_inspector
	_check(inspector.fields.battle.is_visible_in_tree() and inspector.fields.battle.text.contains("Frontnachschub") and inspector.fields.battle.text.contains(" über "),"Provinzleiste nennt im Krieg das Depot und den Grenzübergang")
	main._set_map_mode("economy")
	await _wait_frames()
	_check(mode_view.frontier_supply_paths().is_empty(),"Wirtschaftskarte erhält keine fremde Kriegslinie")
	main._set_map_mode("war")
	mode_view.set_map_motion_enabled(false)
	await _wait_frames()
	_check(not mode_view._motion.is_processing() and not mode_view.frontier_supply_paths().is_empty(),"Bewegung aus blendet Nachschubinformationen nicht aus")
	_check(get_viewport().get_texture().get_image().save_png(proof.path_join("war-front-supply.png")) == OK,"Frontnachschub ist im gerenderten Kriegsbild dokumentiert")

func _test_civic_freight(main, proof: String) -> void:
	var sample:=OS.get_environment("BQ_FREIGHT_CAMPAIGN_PROOF")
	if FileAccess.file_exists(sample):
		_check(main.game.restore(JSON.parse_string(FileAccess.get_file_as_string(sample))),"Finanzierte Nahrungsfracht wird mitsamt Monatsweg geladen")
	else:
		main._start(0)
		var source: Dictionary=main.game.province("germanien__03")
		source.economic_focus="agriculture"
		var food=load("res://scripts/CivicProvision.gd")
		source.provisioning.food_u=6*food.need_u(source)
		main.game.province("germanien__05").economic_focus="workshops"
		main.game.roads.append({"from":source.id,"to":"germanien__05","state":"complete","builder":0,"months":0,"construction":{}})
		main.game.advance_month()
	main.game.speed=0
	main._set_map_mode("economy")
	main._on_province_selected("germanien__05")
	main.refresh()
	var motion=main.map_view._motion
	main.map_view.set_map_motion_enabled(true)
	await _wait_frames()
	var focus: Array=main.game.provision_report().get("flows",[])
	_check(not focus.is_empty() and not motion.food_paths.is_empty() and motion.is_processing(),"Gebuchte Nahrungsfracht bewegt den Getreidewagen auf der Wirtschaftskarte")
	_check(motion.GRAIN_CART.get_size()==Vector2(128,128) and ResourceLoader.exists("res://assets/map/freight/grain_cart.glb"),"Eigenes Wagenmodell und transparenter Render sind im Kartenbestand verfügbar")
	var inspector=main.get_meta("modern_interface").province_inspector
	inspector.show_section("buildings")
	if not inspector.civic_panel.body.visible: inspector.civic_panel.toggle.pressed.emit()
	await _wait_frames()
	_check(inspector.civic_panel.balance_label.text.contains("Nahrungsfracht eingetroffen"),"Die Provinzbilanz benennt die tatsächlich eingegangene Menge")
	main.map_view.set_map_motion_enabled(false)
	await _wait_frames()
	_check(not motion.is_processing() and not motion.food_paths.is_empty(),"Reduzierte Bewegung hält den Wagen an seiner Route und erhält die Bilanz")
	_check(get_viewport().get_texture().get_image().save_png(proof.path_join("economy-grain-cart.png")) == OK,"Echte Nahrungsfracht ist im gerenderten Kartenbild sichtbar")

func _test_irrigation(main, proof: String) -> void:
	var inspector = main.get_meta("modern_interface").province_inspector
	if not inspector.action_buttons.has("build:irrigation_works") or not main.map_view.has_method("irrigation_markers"):
		_check(false,"Ein fertiges Bewässerungswerk besitzt Kartenbild und Provinzbedienung")
		return
	var sample := OS.get_environment("BQ_IRRIGATION_CAMPAIGN_PROOF")
	var site := "irrigation_works"
	var id := ""
	if FileAccess.file_exists(sample):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sample))
		_check(main.game.restore(saved),"Die bezahlte Anlage lädt im echten Spiel")
		for row in saved.provinces:
			if int(row.logistics_sites.get(site,0))==1: id = str(row.id); break
	else:
		for p in main.game.provinces:
			if not str(p.terrain) in ["plains","farmland","steppe"]: continue
			main.game.select_player_context(int(p.owner))
			main.game.house().research.known=["surveying","crop_rotation","irrigation"]
			p.logistics_sites[site] = 1
			id = str(p.id)
			break
	if id.is_empty(): _check(false,"Fertiges Werk trägt einen eindeutigen Standort"); return
	main.game.speed=0
	main._set_map_mode("economy")
	main._on_province_selected(id)
	main.map_view.center_on(main.map_view._label_point(main.game.province(id)))
	main.map_view.set_map_motion_enabled(true)
	await _wait_frames()
	_check(inspector.fields.completed_buildings.text.contains("Bewässerungswerk"),"Fertiges Werk steht im Provinzbestand")
	_check(not inspector.action_buttons["build:irrigation_works"].is_visible_in_tree(),"Fertiges Werk bietet keinen zweiten Bau")
	var markers: Array = main.map_view.irrigation_markers()
	_check(markers.any(func(marker): return marker.id==id and marker.rect.size.x>=30),"Fertige bewässerte Region besitzt genau am Standort einen Modellmarker")
	_check(main.map_view._motion.is_processing() and main.map_view.irrigation_flow_active(),"Wasser am ausgewählten Werk ist animiert")
	_check(ResourceLoader.exists("res://assets/map/irrigation/irrigation_works.glb"),"Eigenes Blender-Modell ist als Spielressource vorhanden")
	_check(get_viewport().get_texture().get_image().save_png(proof.path_join("irrigation-economy.png"))==OK,"Karte mit Anlage und Provinzbestand ist aufgezeichnet")
	main.map_view.set_map_motion_enabled(false)
	await _wait_frames()
	_check(not main.map_view._motion.is_processing() and not main.map_view.irrigation_markers().is_empty(),"Bei reduzierter Bewegung bleibt das Modell lesbar")
	main._set_map_mode("terrain")
	await _wait_frames()
	_check(main.map_view.irrigation_markers().is_empty(),"Geländekarte bleibt frei von Wirtschaftsmodellen")

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
