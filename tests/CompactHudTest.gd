extends Node
var main
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	var ui = main.get_meta("modern_interface")
	ui.set_text_scale(1.0)
	await settle()
	var viewport: Vector2 = main.get_viewport_rect().size
	var map: Rect2 = main.map_view.get_global_rect()
	check(map.size.x * map.size.y / (viewport.x * viewport.y) >= 0.57, "Karte belegt mindestens 57 Prozent der normalen Hauptansicht")
	check(map.position.y <= viewport.y * 0.25, "Leisten verbrauchen höchstens ein Viertel der Höhe")
	check(main.side_panel.size.x <= viewport.x * 0.24, "Hof braucht höchstens 24 Prozent der Breite")
	check(main.develop_btn.size.y < 42, "Desktop-Aktion ist kompakt")
	check(main.develop_btn.get_theme_font_size("font_size") >= 12, "Kompakte Beschriftung bleibt lesbar")
	check(main.side_panel.get_theme_stylebox("panel").bg_color.a < 1.0, "Hof besitzt eine transparente Materialfläche")
	main._toggle_side_panel()
	await settle()
	check(main.map_view.size.x > map.size.x + 100, "Hof lässt sich zugunsten der Karte einklappen")
	main._toggle_side_panel()
	if ui.has_method("set_touch_layout"):
		ui.set_touch_layout(true)
		await settle()
		for button in main.map_mode_buttons.values():
			check(button.size.y >= 44, "Touch-Kartenmodus hat 44 Einheiten Trefferhöhe")
		check(main.develop_btn.size.y >= 44, "Touch-Aktion hat 44 Einheiten Trefferhöhe")
		ui.set_touch_layout(false)
	else:
		check(false, "Touch-Layout ist gesondert prüfbar")
	ui.set_text_scale(2.0)
	await settle()
	check(main.develop_btn.get_theme_font_size("font_size") >= 24, "200 Prozent Textskalierung bleibt verfügbar")
	check(main.get_viewport_rect().encloses(main.side_panel.get_global_rect()), "Skalierter Hof bleibt innerhalb des Fensters")
	ui.set_text_scale(1.0)
	ui.set_appearance(3)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/verify/bq-compact-hud.png")
	print("COMPACTHUDTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func settle() -> void:
	for index in 5:
		await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("COMPACTHUDTEST FAIL: " + message)
