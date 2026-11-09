extends Node
## Materialthemen bleiben lesbar, bedienbar und ohne veraltete Farben wechselbar.
const DataScript = preload("res://scripts/Data.gd")
var checks := 0
var failures := 0
var main

func _ready() -> void:
	var defaults = load("res://scenes/Main.tscn").instantiate()
	_check(int(defaults.settings.get("ui_theme", -1)) == 3, "Eine neue Konfiguration muss mit dem Holzthema beginnen.")
	defaults.free()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main.opt_theme.item_count == 6, "Alle sechs Lesbarkeits- und Materialthemen müssen auswählbar sein.")
	var ui = main.get_meta("modern_interface")
	ui.set_appearance(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png("res://build/verify/bq-theme-menu.png") == OK, "Holz-Hauptmenü ist nicht aufnehmbar.")
	main._start(0)
	await get_tree().process_frame
	var original_dark: Color
	ui.set_appearance(0)
	original_dark = main.side_panel.get_theme_stylebox("panel").bg_color
	var swatches: Array = []
	for candidate in main.find_children("*", "Button", true, false):
		if candidate.tooltip_text == "Hausfarbe wählen":
			swatches.append(candidate)
	_check(swatches.size() == 10, "Die zehn unterschiedlichen Hausfarben müssen auswählbar bleiben.")
	for theme in [3, 4, 5, 1, 2, 0]:
		ui.set_appearance(theme)
		await get_tree().process_frame
		_check(int(main.settings["ui_theme"]) == theme, "Materialthema %d wird nicht wirksam übernommen." % theme)
		var bg: Color = main.side_panel.get_theme_stylebox("panel").bg_color
		var fg: Color = main.title_label.get_theme_color("font_color")
		_check(_contrast(fg, bg) >= 4.5, "Titelkontrast im Thema %d liegt unter 4,5:1." % theme)
		if swatches.size() >= 2:
			_check(swatches[0].get_theme_stylebox("normal").bg_color.is_equal_approx(Color(0.68, 0.30, 0.20)), "Die rote Hausfarbe wird im Thema %d zur Materialfarbe umgefärbt." % theme)
			_check(swatches[1].get_theme_stylebox("normal").bg_color.is_equal_approx(Color(0.22, 0.38, 0.62)), "Die blaue Hausfarbe wird im Thema %d zur Materialfarbe umgefärbt." % theme)
		for field in main.find_children("*", "LineEdit", true, false):
			var field_bg: Color = field.get_theme_stylebox("normal").bg_color
			_check(_contrast(_on_background(field.get_theme_color("caret_color"), field_bg), field_bg) >= 4.5, "Einfügecursor ist im Thema %d auf seinem Eingabefeld nicht lesbar." % theme)
			if not field.placeholder_text.is_empty():
				_check(_contrast(_on_background(field.get_theme_color("font_placeholder_color"), field_bg), field_bg) >= 4.5, "Platzhalter ist im Thema %d auf seinem Eingabefeld nicht lesbar." % theme)
		var action: Button = main.opt_save_btn
		var normal_style: StyleBoxFlat = action.get_theme_stylebox("normal")
		var focus_style: StyleBoxFlat = action.get_theme_stylebox("focus")
		_check(focus_style.border_width_left >= 2 and is_zero_approx(focus_style.bg_color.a), "Tastaturfokus braucht im Thema %d eine deutliche Kontur ohne verdeckende Fläche." % theme)
		_check(_contrast(focus_style.border_color, normal_style.bg_color) >= 3.0, "Fokusmarkierung hebt sich im Thema %d nicht ausreichend von der Buttonfläche ab." % theme)
		_check(not action.get_theme_color("font_disabled_color").is_equal_approx(action.get_theme_color("font_color")), "Deaktivierte Aktionen sind im Thema %d von verfügbaren Aktionen nicht unterscheidbar." % theme)
		for speed_button in main.speed_buttons:
			var speed_fg: Color = speed_button.get_theme_color("font_color") * speed_button.modulate
			var speed_bg: Color = speed_button.get_theme_stylebox("normal").bg_color * speed_button.modulate
			_check(_contrast(speed_fg, speed_bg) >= 4.5, "Temposchalter wird im Thema %d durch Abdunklung unlesbar." % theme)
		var grain = main.side_panel.get_node_or_null("MaterialGrain")
		if theme in [3, 4]:
			_check(grain != null and grain.visible, "Holzthema %d zeigt keine Maserung." % theme)
			if grain != null:
				_check(grain.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Die Maserung blockiert Touch-Eingaben.")
				_check(grain.custom_minimum_size == Vector2.ZERO, "Die Maserung darf keine zusätzliche Layoutgröße erzwingen.")
		else:
			_check(grain == null or not grain.visible, "Ein holzfreies Thema enthält noch die vorherige Maserung.")
		if theme in [4, 5]:
			_check(fg.get_luminance() < 0.2 and bg.get_luminance() > 0.35, "Helles Material benötigt dunkle Schrift auf heller Fläche.")
		if theme in [3, 4, 5] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png("res://build/verify/bq-theme-%d.png" % theme) == OK, "Materialthema %d ist nicht aufnehmbar." % theme)
	_check(main.side_panel.get_theme_stylebox("panel").bg_color.is_equal_approx(original_dark), "Der Rückwechsel stellt die Atlasfarbe nicht wieder her.")
	for event in DataScript.events():
		if str(event.id) == "ernte":
			main.game.pending_event = event
	main._show_event()
	await get_tree().process_frame
	var first: Button = main.event_buttons.get_child(0).get_child(0)
	var third: Button = main.event_buttons.get_child(2).get_child(0)
	var positives: Array = first.find_children("*", "RichTextLabel", true, false)
	var mixed: Array = third.find_children("*", "RichTextLabel", true, false)
	var pattern := RegEx.new()
	pattern.compile("\\[color=(#[0-9a-fA-F]+)\\]")
	for theme in 6:
		ui.set_appearance(theme)
		var expected_light := theme in [2, 4, 5]
		for outlined in [main.event_title, main.event_text]:
			var outline: Color = outlined.get_theme_color("font_outline_color")
			_check(outline.get_luminance() > 0.8 if expected_light else outline.get_luminance() < 0.05, "Bereits geöffneter Ereignistext behält im Thema %d eine unpassende Outline." % theme)
		var positive_match = pattern.search(positives[0].text) if not positives.is_empty() else null
		_check(positive_match != null, "Pluswerte fehlen im Materialthema %d." % theme)
		if positive_match != null:
			var positive := Color(positive_match.get_string(1))
			_check(positive.g > positive.r, "Pluswerte verlieren im Thema %d ihre grüne Farbe." % theme)
		var negative_match = pattern.search(mixed[0].text) if not mixed.is_empty() else null
		_check(negative_match != null, "Minuswerte fehlen im Materialthema %d." % theme)
		if negative_match != null:
			var negative := Color(negative_match.get_string(1))
			_check(negative.r > negative.g, "Minuswerte verlieren im Thema %d ihre rote Farbe." % theme)
		var neutral_match = pattern.search(main.ModernInterfaceScript.effect_markup("[color=#d8c9a6]Unverändert[/color]"))
		_check(neutral_match != null, "Neutrale Werte fehlen im Materialthema %d." % theme)
		if neutral_match != null:
			var neutral := Color(neutral_match.get_string(1))
			_check(neutral.r >= neutral.g and neutral.g > neutral.b, "Neutrale Werte verlieren im Thema %d ihre gelbe Farbe." % theme)
		var event_panel: Node = main.event_title
		while event_panel != null and not (event_panel is PanelContainer):
			event_panel = event_panel.get_parent()
		_check(event_panel != null and is_equal_approx(event_panel.get_theme_stylebox("panel").bg_color.a, 0.1), "Materialthema %d macht den Ereignishintergrund wieder undurchsichtig." % theme)
	ui.set_appearance(3)
	var before: int = int(main.game.house().gold)
	first.pressed.emit()
	_check(int(main.game.house().gold) == before + 45 and main.game.pending_event == null, "Holzthema verhindert die Ereignisentscheidung.")
	print("MATERIALTHEMETEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func _luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	for i in channels.size():
		channels[i] = channels[i] / 12.92 if channels[i] <= 0.04045 else pow((channels[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

func _contrast(a: Color, b: Color) -> float:
	var first := _luminance(a)
	var second := _luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)

func _on_background(foreground: Color, background: Color) -> Color:
	return Color(foreground.r * foreground.a + background.r * (1.0 - foreground.a), foreground.g * foreground.a + background.g * (1.0 - foreground.a), foreground.b * foreground.a + background.b * (1.0 - foreground.a))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MATERIALTHEMETEST FAIL: " + message)
