extends Node
## Folgen gehören zur klickbaren Entscheidung; Ereignisse verdecken weniger Karte.
const DataScript = preload("res://scripts/Data.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start(0)
	for event in DataScript.events():
		if str(event.id) == "ernte":
			main.game.pending_event = event
	main._show_event()
	await get_tree().process_frame
	var rows: Array = main.event_buttons.get_children()
	_check(rows.size() == 4, "Vier Ernteentscheidungen fehlen.")
	var first: Button = rows[0].get_child(0)
	var third: Button = rows[2].get_child(0)
	var driver = load("res://scripts/AcceptanceDriver.gd").new()
	_check(driver._buttons(main.event_layer, "Verkaufen").size() == 1, "Bedienprüfung muss den zugänglichen Aktionsnamen finden.")
	driver.free()
	var positive_labels: Array = first.find_children("*", "RichTextLabel", true, false)
	_check(not positive_labels.is_empty(), "Farbige Werte innerhalb des Buttons fehlen.")
	if not positive_labels.is_empty():
		var pattern := RegEx.new()
		pattern.compile("\\[color=(#[0-9a-fA-F]+)\\]")
		var match_result = pattern.search(positive_labels[0].text)
		_check(match_result != null, "Pluswert besitzt keine Farbauszeichnung.")
		if match_result != null:
			var color := Color(match_result.get_string(1))
			_check(color.g > color.r, "Pluswert ist nicht grün.")
		var negative_labels: Array = third.find_children("*", "RichTextLabel", true, false)
		if not negative_labels.is_empty():
			var colors: Array = pattern.search_all(negative_labels[0].text)
			_check(colors.size() == 2, "Erntefest benötigt getrennte Farben für Kosten und Prestige.")
			if colors.size() == 2:
				var negative := Color(colors[0].get_string(1))
				var positive := Color(colors[1].get_string(1))
				_check(negative.r > negative.g and positive.g > positive.r, "Minus und Plus sind nicht rot/grün unterschieden.")
	_check(first.accessibility_name.contains("Verkaufen") and first.accessibility_name.contains("+45 Gold"), "Verkauf und Goldgewinn müssen im zugänglichen Buttonnamen stehen.")
	_check(third.accessibility_name.contains("−20 Gold") and third.accessibility_name.contains("+12 Prestige"), "Kosten und Wirkung des Erntefests müssen im zugänglichen Buttonnamen stehen.")
	if not positive_labels.is_empty():
		var ui = main.get_meta("modern_interface")
		var pattern := RegEx.new()
		pattern.compile("\\[color=(#[0-9a-fA-F]+)\\]")
		for theme in 3:
			ui.set_appearance(theme)
			var positive_match = pattern.search(positive_labels[0].text)
			_check(positive_match != null and Color(positive_match.get_string(1)).g > Color(positive_match.get_string(1)).r, "Themenwechsel verliert die Plusfarbe.")
			var neutral_markup: String = main.ModernInterfaceScript.effect_markup("[color=#d8c9a6]Unverändert[/color]")
			var neutral_match = pattern.search(neutral_markup)
			var neutral_color := Color(neutral_match.get_string(1))
			_check(neutral_color.r >= neutral_color.g and neutral_color.g > neutral_color.b, "Neutrale Werte müssen gelb/amber bleiben.")
		ui.set_appearance(0)
		ui.set_text_scale(2.0)
		_check(first.custom_minimum_size.y >= 128 and positive_labels[0].get_theme_font_size("normal_font_size") == 28, "Werte und Trefferbereich skalieren nicht auf 200 Prozent.")
		ui.set_text_scale(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(positive_labels[0].get_global_rect().end.y <= first.get_global_rect().end.y + 1, "Wertzeile läuft nach Textgrößenwechsel aus dem Button.")
		_check(first.get_global_rect().end.y <= rows[1].get_child(0).get_global_rect().position.y + 1, "Ereignisbuttons überlappen nach dem Textgrößenwechsel.")
	for row in rows:
		_check(row.get_child_count() == 1 and row.get_child(0) is Button, "Werte stehen weiterhin außerhalb der klickbaren Fläche.")
	var node: Node = main.event_title
	while node != null and not (node is PanelContainer):
		node = node.get_parent()
	_check(node != null and is_equal_approx(node.get_theme_stylebox("panel").bg_color.a, 0.1), "Ereignisfläche braucht zehn Prozent Deckkraft.")
	_check(node != null and node.get_theme_stylebox("panel").border_width_left > 0 and node.get_theme_stylebox("panel").shadow_size > 0, "Dezente Kontur und Schatten fehlen.")
	_check(main.event_art.get_parent().custom_minimum_size.y <= 110, "Ereignisbild ist nicht kompakter.")
	var scroller: Node = first.get_parent()
	while scroller != null and not (scroller is ScrollContainer):
		scroller = scroller.get_parent()
	_check(scroller != null and rows[3].get_global_rect().end.y <= scroller.get_global_rect().end.y + 1, "Ereignisaktionen werden beim Öffnen abgeschnitten.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/verify/bq-event-compact.png")
	var before: int = int(main.game.house().gold)
	first.pressed.emit()
	_check(int(main.game.house().gold) == before + 45 and main.game.pending_event == null, "Kompakter Button führt die Entscheidung nicht korrekt aus.")
	print("EVENTCHOICETEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("EVENTCHOICETEST FAIL: " + message)
