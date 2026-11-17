extends Node
var checks := 0
var failures := 0
var main

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/MapModes.gd"):
		check(false, "Eigenständige aussagekräftige Kartenpolitik fehlt")
		finish()
		return
	var policy = load("res://scripts/MapModes.gd")
	check(policy.IDS.size() == 5, "Fünf getrennte Spielzwecke statt doppelter Titelansichten")
	check(policy.canonical("duchy") == "titles" and policy.canonical("kingdom") == "titles", "Alte Titelansichten bleiben als Aliase gültig")
	check(policy.canonical("development") == "economy", "Alte Wirtschaftskennung bleibt gültig")
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	var ui = main.get_meta("modern_interface")
	ui.set_text_scale(1.0)
	await settle()
	var before: String = main.LanSessionScript.Protocol.world_hash(main.game.snapshot())
	var p: Dictionary = main.game.owned()[0]
	var colors := {}
	for mode in policy.IDS:
		main._set_map_mode(mode)
		await settle()
		if DisplayServer.get_name() != "headless" and mode == "terrain":
			await RenderingServer.frame_post_draw
			check(int(main.map_view._base.border_counts.get("empire",0)) > 0, "Geländekarte zeichnet echte feste Reichsgrenzen")
		colors[str(main.map_view._fill_color(p))] = true
		check(main.map_view.map_mode == mode, "Kartenmodus %s ist bedienbar" % mode)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/verify/strategy-mode-%s.png" % mode)
	check(colors.size() == 5, "Alle fünf Ansichten verwenden erkennbar eigene Flächenpolitik")
	check(policy.border_styles("terrain").empire[1] > policy.border_styles("political").empire[1], "Gelände betont feste Reichsgrenzen")
	check(main.LanSessionScript.Protocol.world_hash(main.game.snapshot()) == before, "Ansichtswechsel ändert keine Spielwelt")
	ui.show_section("family")
	main._on_province_selected(str(p.id))
	await settle()
	check(main.side_panel.visible and ui.current_section == "overview", "Einfacher Provinzklick öffnet direkt die rechte Provinzseite")
	check(ui.has_meta("province_inspector") or ui.get("province_inspector") != null, "Provinzinspektor vorhanden")
	var inspector = ui.get("province_inspector")
	if inspector != null:
		check(inspector.selected_id == str(p.id), "Provinzseite zeigt die tatsächlich ausgewählte Region")
		for section in ["buildings", "army", "research", "achievements"]:
			check(inspector.section_buttons.has(section), "Direkter Provinzbereich %s vorhanden" % section)
		inspector.show_section("buildings")
		await settle()
		var level := int(main.game.province(str(p.id)).buildings.market)
		main.game.house().gold = 1000
		main.refresh()
		inspector.action_buttons["build:market"].pressed.emit()
		check(int(main.game.province(str(p.id)).buildings.market) == level + 1, "Bauen auf der Provinzseite führt echte lokale Aktion aus")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/verify/strategy-province-buildings.png")
		inspector.show_section("research")
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/verify/strategy-province-research.png")
	main._show_house_designer()
	var designer = main.get_meta("singleplayer_designer")
	check(is_instance_valid(designer) and main.kernel.top_modal() == "house_designer", "Einzelspieler öffnet denselben gemeinsamen Hausdesigner")
	main._unhandled_input(_escape())
	check(main.kernel.top_modal() != "house_designer", "Escape bricht den Entwurf ohne Spielmutation ab")
	for child in ui.pages.world.find_children("*", "Button", true, false):
		check(not child.text.contains("speichern") and not child.text.contains("laden") and not child.text.contains("WLAN"), "Welt enthält keine Datei-/Lobbyverwaltung")
	await _network_designers()
	finish()

func _network_designers() -> void:
	var guest = load("res://scenes/Main.tscn").instantiate()
	add_child(guest)
	guest.hide()
	await settle()
	var host_session = main.lan_session
	var guest_session = guest.lan_session
	host_session.discovery_enabled = false
	guest_session.discovery_enabled = false
	var port := 48200 + OS.get_process_id() % 500
	check(bool(host_session.host("Designer UI", "Host", 0, port).ok), "Echte Gastgeberlobby für den UI-Designer")
	check(bool(guest_session.join("127.0.0.1", "Gast", port).ok), "Echter Gast verbindet den UI-Designer")
	if not await _until(func(): return guest_session.phase == "lobby" and host_session.players.size() == 2):
		check(false,"Beide tatsächlichen Hauptszenen erreichen die Lobby")
		host_session.close_session()
		guest_session.close_session()
		guest.queue_free()
		return
	main.lan_menu._open_designer()
	var host_dialog = main.lan_menu.designer
	check(is_instance_valid(host_dialog), "Host öffnet den Designer über die tatsächliche Lobby")
	host_dialog.fields.house.text = "Haus UI Host"
	host_dialog.fields.ruler.text = "UI Host"
	host_dialog.home_picker.select(0)
	host_dialog.doctrine_picker.select(1)
	host_dialog.apply_button.pressed.emit()
	guest.lan_menu._open_designer()
	var guest_dialog = guest.lan_menu.designer
	check(is_instance_valid(guest_dialog), "Gast öffnet denselben Designer über die tatsächliche Lobby")
	guest_dialog.fields.house.text = "Haus UI Gast"
	guest_dialog.fields.ruler.text = "UI Gast"
	guest_dialog.home_picker.select(1)
	guest_dialog.doctrine_picker.select(2)
	guest_dialog.apply_button.pressed.emit()
	await settle()
	check(await _until(func(): return host_session.players.size() == 2 and host_session.players.values().all(func(seat): return not seat.get("design",{}).is_empty())), "Beide Entwürfe erreichen den autoritativen Gastgeber")
	host_session.set_ready(true)
	guest_session.set_ready(true)
	check(await _until(func(): return host_session.players.values().all(func(seat): return seat.ready)), "Bestätigte Hausentwürfe werden gemeinsam bereit")
	check(bool(host_session.start_match().ok), "Gemeinsamer Start mit beiden UI-Hausentwürfen")
	check(await _until(func(): return guest_session.phase == "playing"), "Gast erhält die echte gestaltete Welt")
	if guest_session.game != null and host_session.game != null:
		check(host_session.game.house().name == "Haus UI Host" and guest_session.game.house().name == "Haus UI Gast", "Jede tatsächliche Spielansicht erhält ihr selbst gestaltetes Haus")
		check(host_session.game.house().doctrine == "infantry" and guest_session.game.house().doctrine == "cavalry", "Armeedoktrinen gelangen vom Editor in beide Spielwelten")
		check(main.LanSessionScript.Protocol.world_hash(host_session.game.snapshot()) == main.LanSessionScript.Protocol.world_hash(guest_session.game.snapshot()), "UI-Gründung ergibt auf beiden Peers dieselbe Welt")
	host_session.close_session()
	guest_session.close_session()
	guest.queue_free()

func _until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+8000
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await get_tree().create_timer(.02).timeout
	return condition.call()

func settle() -> void:
	for index in 4:
		await get_tree().process_frame

func _escape() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	return event

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("STRATEGYUITEST FAIL: " + text)

func finish() -> void:
	print("STRATEGYUITEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
