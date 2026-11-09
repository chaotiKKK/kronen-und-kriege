extends Node
## Verhindert verdeckte Navigation und überladene, gleichzeitig offene Bereiche.
var main
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start(0)
	await get_tree().process_frame
	var mode_row: Control = main.map_mode_buttons["political"].get_parent()
	var nav: Control = mode_row.get_parent()
	_check(not nav.get_global_rect().intersects(main.side_panel.get_global_rect()), "Kartenmodi überlappen das Seitenpanel.")
	for button in main.map_mode_buttons.values():
		_check(button.size.y >= 44, "Kartenmodus besitzt keine ausreichend große Touchfläche.")
	if not main.has_meta("modern_interface"):
		_check(false, "Hauptansicht hat keine geordneten Navigationsbereiche.")
		_finish()
		return
	var ui = main.get_meta("modern_interface")
	if not ui.has_method("set_appearance"):
		_check(false, "Umschaltbare Lesbarkeitsthemen fehlen.")
		_finish()
		return
	ui.set_appearance(1)
	_check(main.side_panel.get_theme_stylebox("panel").bg_color.get_luminance() < 0.05, "Kontrastthema braucht eine dunkle Fläche.")
	ui.set_appearance(2)
	_check(main.side_panel.get_theme_stylebox("panel").bg_color.get_luminance() > 0.8, "Helles Thema braucht eine helle Fläche.")
	_check(main.title_label.get_theme_color("font_color").get_luminance() < 0.2, "Helles Thema braucht dunklen Text.")
	_check(main.map_mode_buttons["political"].get_theme_color("font_pressed_color").get_luminance() < 0.2, "Aktiver Kartenmodus ist im hellen Thema nicht lesbar.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/verify/bq-modern-light.png")
	ui.set_appearance(0)
	_check(main.opt_window_mode.get_theme_stylebox("normal").bg_color.get_luminance() < 0.3, "Eingabefeld wird beim Wechsel zurück nicht dunkel.")
	if not ui.has_method("set_text_scale"):
		_check(false, "200-%-Textskalierung fehlt.")
		_finish()
		return
	ui.set_text_scale(2.0)
	main._show_options()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main.research_label.get_theme_font_size("font_size") == 24, "Text wird nicht auf 200 % vergrößert.")
	_check(ui.dialogs.size() > 0, "Dialoge benötigen erreichbare Rollbereiche.")
	for dialog in ui.dialogs:
		_check(dialog.card.get_global_rect().size.y <= main.get_viewport_rect().size.y, "Vergrößerter Dialog passt nicht auf den Bildschirm.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/verify/bq-modern-200.png")
	main._hide_options()
	ui.set_text_scale(1.0)
	_check(ui.section_buttons.size() == 4, "Vier eindeutig getrennte Seitenbereiche fehlen.")
	for section in ["overview", "politics", "family", "world"]:
		ui.show_section(section)
		var visible_count := 0
		for page in ui.pages.values():
			if page.visible:
				visible_count += 1
		_check(visible_count == 1 and ui.pages[section].visible, "Seitenbereiche sind nicht exklusiv sichtbar.")
	ui.show_section("overview")
	_check(not main.info_label.text.contains("Nachbarn:"), "Die Hofübersicht dupliziert lange Provinzdetails.")
	for size in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(size)
		await get_tree().process_frame
		await get_tree().process_frame
		ui.fit_layout()
		_check(ui.navigation.get_global_rect().end.x <= main.map_view.get_global_rect().end.x + 2, "Navigation läuft aus der Kartenfläche.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png("res://build/verify/bq-modern-game.png") == OK, "Modernisierte Hauptansicht nicht aufnehmbar.")
		main.start_layer.visible = true
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png("res://build/verify/bq-modern-menu.png") == OK, "Modernisiertes Hauptmenü nicht aufnehmbar.")
	_finish()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MODERNUITEST FAIL: " + message)

func _finish() -> void:
	print("MODERNUITEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
