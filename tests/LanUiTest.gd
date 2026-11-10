extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/LanMenu.gd"):
		check(false, "Die deutsche WLAN-Lobby fehlt.")
		finish()
		return
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var entry = main.find_child("LanEntryButton", true, false)
	check(entry != null and entry.text.contains("WLAN"), "WLAN-Einstieg fehlt im Hauptmenü.")
	var menu = main.lan_menu
	main.lan_session.discovery_enabled = false
	main.lan_session.game_port = 45000 + OS.get_process_id() % 1000
	menu.port_box.value = main.lan_session.game_port
	entry.pressed.emit()
	await get_tree().process_frame
	check(menu.visible, "Lobby öffnet sich nicht.")
	menu.address.text = "keine IP"
	menu.join_game()
	check(menu.status_label.text.contains("IP"), "Ungültige IP wird nicht verständlich erklärt.")
	menu.host_game()
	await get_tree().process_frame
	check(main.lan_session.phase == "lobby" and main.lan_session.is_host, "Host-Lobby wurde nicht geöffnet.")
	check(menu.start_button.disabled, "Einzelner Host darf Mehrspielerpartie starten.")
	main.get_meta("modern_interface").set_text_scale(2.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_viewport().get_visible_rect().grow(1).encloses(menu.back_button.get_global_rect()), "Zurück liegt bei200% außerhalb.")
	check(get_viewport().get_visible_rect().grow(1).encloses(menu.start_button.get_global_rect()), "Start liegt bei200% außerhalb.")
	check(menu.scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Lobby erzwingt horizontales Scrollen.")
	menu.back_button.pressed.emit()
	check(not menu.visible and main.lan_session.phase == "idle", "Zurück hinterlässt offene Lobby.")
	main._start(0)
	check(main.game != null and not main.start_layer.visible, "Einzelspieler nach LAN-Abbruch gestört.")
	main.queue_free()
	await get_tree().process_frame
	finish()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("LANUITEST FAIL: ", message)

func finish() -> void:
	print("LANUITEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
