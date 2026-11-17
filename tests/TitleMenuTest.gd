extends Node
## Guards artwork visibility, reachable title actions and independent version placement.
var main
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var ui = main.get_meta("modern_interface")
	for sample in [[Vector2i(1280,720),1.0,false],[Vector2i(1024,768),1.0,false],[Vector2i(1280,720),2.0,false],[Vector2i(1280,600),2.0,true]]:
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(sample[0])
		ui.set_touch_layout(sample[2])
		ui.set_text_scale(sample[1])
		await settle()
		check_layout(sample[1],sample[2])
	for theme in 6:
		ui.set_appearance(theme)
		await settle()
		var version = version_label()
		check(version != null and version.get_theme_color("font_color").is_equal_approx(Color.WHITE),"Versionsnummer bleibt in jedem Theme weiß")
	ui.set_appearance(3)
	ui.set_touch_layout(false)
	ui.set_text_scale(1.0)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(1280,720))
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/verify"))
		get_viewport().get_texture().get_image().save_png("res://build/verify/title-menu-191.png")
	var actions = buttons()
	if actions.size() == 5:
		actions[0].pressed.emit()
		check(main.newgame_layer.visible,"Neues Spiel bleibt über das Titelmenü erreichbar")
		main._hide_newgame()
		main.title_status.text = "Kein Spielstand vorhanden."
		await settle()
		check(main.get_viewport_rect().encloses(main.title_status.get_global_rect()),"Ladehinweis bleibt im Bild erreichbar")
	print("TITLEMENUTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)

func buttons() -> Array:
	return main.start_layer.find_children("*","Button",true,false)

func version_label():
	for label in main.start_layer.find_children("*","Label",true,false):
		if label.text.begins_with("VERSION "): return label
	return null

func check_layout(scale: float, touch: bool) -> void:
	var actions = buttons()
	check(actions.size() == 5,"Alle fünf Titelaktionen bleiben vorhanden")
	if actions.size() != 5: return
	var viewport: Rect2 = main.get_viewport_rect()
	var bounds: Rect2 = actions[0].get_global_rect()
	for button in actions:
		var rect: Rect2 = button.get_global_rect()
		bounds = bounds.merge(rect)
		check(viewport.grow(1).encloses(rect),"Titelaktion bleibt vollständig im Fenster")
		if touch: check(rect.size.y >= 44,"Titelaktion behält Touch-Trefferfläche")
	check(absf(bounds.get_center().x-viewport.get_center().x) <= 2,"Hauptmenü ist horizontal mittig")
	check(bounds.position.y >= viewport.size.y*0.65,"Titelbild bleibt über den unteren Menübereich hinaus frei")
	check(bounds.size.y <= viewport.size.y*0.3,"Hauptmenü verdeckt höchstens den unteren Bildbereich")
	var version = version_label()
	check(version != null,"Versionsnummer ist sichtbar")
	if version == null:return
	var rect: Rect2 = version.get_global_rect()
	check(version.text == "VERSION "+str(ProjectSettings.get_setting("application/config/version")),"Versionsanzeige stimmt mit der laufenden Fassung überein")
	check(viewport.grow(1).encloses(rect) and viewport.end.x-rect.end.x <= 24 and viewport.end.y-rect.end.y <= 24,"Versionsnummer liegt unten rechts im sichtbaren Bild")
	check(not rect.intersects(bounds),"Versionsnummer überlappt keine Menüaktion")
	check(version.get_theme_color("font_color").is_equal_approx(Color.WHITE),"Versionsnummer ist weiß")

func settle() -> void:
	for frame in 8: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("TITLEMENUTEST FAIL: "+message)
