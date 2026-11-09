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
	_check(first.text.contains("Verkaufen") and first.text.contains("+45 Gold"), "Verkauf und Goldgewinn müssen in demselben Button stehen.")
	_check(third.text.contains("−20 Gold") and third.text.contains("+12 Prestige"), "Kosten und Wirkung des Erntefests müssen im Button stehen.")
	for row in rows:
		_check(row.get_child_count() == 1 and row.get_child(0) is Button, "Werte stehen weiterhin außerhalb der klickbaren Fläche.")
	var node: Node = main.event_title
	while node != null and not (node is PanelContainer):
		node = node.get_parent()
	_check(node != null and node.get_theme_stylebox("panel").bg_color.a == 0, "Große undurchsichtige Ereigniskarte verdeckt das Spiel.")
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
