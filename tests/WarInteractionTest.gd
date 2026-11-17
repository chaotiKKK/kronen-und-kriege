extends Node
## Reale Hauptszene: Auswahl ist Navigation, Befehle laufen über den Kernel.
var checks := 0
var failures := 0
var main

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed = 0
	main.game.house().gold = 1000
	var ui = main.get_meta("modern_interface")
	var inspector = ui.province_inspector
	var home: String = main.game.owned()[0].id
	main._set_map_mode("war")
	main._on_province_selected(home)
	await settle()
	check(inspector.current_section == "army", "Kriegskarte öffnet direkt Militär statt Bauverwaltung")
	check(inspector.action_buttons.has("march") and inspector.action_buttons.has("siege"), "Provinzseite enthält erreichbare Feldarmeebefehle")
	check(main.map_view.has_method("army_markers"), "Armeemarker besitzen gemeinsame Darstellungs- und Treffergeometrie")
	if main.map_view.has_method("army_markers") and inspector.action_buttons.has("march"):
		await exercise_army(inspector,home)
	main._on_province_selected(home)
	main._show_rule()
	await settle()
	check(not _has_button(main.rule_body,"Anspruch schmieden") and not _has_button(main.rule_body,"Armee aufstellen") and not _has_button(main.rule_body,"Markt:"), "Herrschaft dupliziert keine örtlichen Verwaltungsbefehle")
	check(_has_button(main.rule_body,"Provinzverwaltung"), "Herrschaft führt zur gemeinsamen Provinzverwaltung")
	main._hide_rule()
	main._show_chronicle()
	await settle()
	check(not _has_button(main.chronicle_body,"Truppen werben") and not _has_button(main.chronicle_body,"Armee aufstellen") and not _has_button(main.chronicle_body,"Ausbauen"), "Chronik dupliziert keine Bau- oder Militärbefehle")
	main._hide_chronicle()
	if DisplayServer.get_name() != "headless":
		ui.set_touch_layout(false)
		ui.set_text_scale(1.0)
		await settle()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/verify/war-desktop.png")
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		main._on_province_selected(home)
		await settle()
		for key in ["march","siege"]:
			if inspector.action_buttons.has(key):
				check(inspector.action_buttons[key].custom_minimum_size.y >= 44, "Feldarmeebefehl bleibt eine ausreichend große Touchfläche")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/verify/war-context-%d.png" % int(scale*100))
	print("WARINTERACTIONTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func exercise_army(inspector, home: String) -> void:
	var g = main.game
	check(bool(main._dispatch({"id":"army"}).ok), "Aufstellung erfolgt über echten lokalen Router")
	await settle()
	var markers: Array = main.map_view.army_markers()
	check(markers.size() == 1 and str(markers[0].province) == home, "Aufgestellte Armee wird an ihrem tatsächlichen Ort angeboten")
	if markers.is_empty(): return
	var before: String = main.LanSessionScript.Protocol.world_hash(g.snapshot())
	var marker: Dictionary = markers[0]
	var touch := InputEventScreenTouch.new()
	touch.position = marker.rect.get_center()
	touch.pressed = true
	main.map_view._gui_input(touch)
	await settle()
	check(main.selected == home and inspector.current_section == "army", "Touch auf Armee öffnet unmittelbar ihren Militärkontext")
	check(main.LanSessionScript.Protocol.world_hash(g.snapshot()) == before, "Armeeauswahl führt keinen Marsch oder Angriff aus")
	var next := ""
	for id in g.neighbours(home):
		if int(g.province(id).owner) == g.player:
			next = id
			break
	check(not next.is_empty(), "Angrenzende eigene Marschregion vorhanden")
	if not next.is_empty():
		main._on_province_selected(next)
		await settle()
		check(inspector.action_buttons.march.is_visible_in_tree() and not inspector.action_buttons.march.disabled, "Erreichbarer Marsch ist direkt auswählbar")
		inspector.action_buttons.march.pressed.emit()
		await settle()
		check(str(g.army_for().province) == next, "Tatsächlicher Provinzbutton bewegt die Armee")
		main._on_province_selected(home)
		await settle()
		check(inspector.action_buttons.march.disabled, "Zweiter Marsch im selben Monat wird bereits in der UI gesperrt")
		check(inspector.fields.orders.text.contains("Monat"), "Sperre erklärt die Monatsgrenze")
	var foreign := ""
	for p in g.provinces:
		if int(p.owner) != g.player and g.is_border_province(g.player,p.id):
			foreign = p.id
			break
	g._remove_claim(foreign,g.player)
	main._on_province_selected(foreign)
	await settle()
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible, "Fremde Region hat keine eigene Verwaltung")
	check(not inspector.action_buttons.siege.visible, "Ohne Anspruch erscheint keine nachgelagerte Belagerungsaktion")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/verify/war-foreign.png")
	main._on_province_selected(home)
	await settle()
	check(inspector.section_buttons.buildings.visible and inspector.section_buttons.research.visible, "Eigene Verwaltung kehrt beim Rückwechsel zurück")
	var old: Dictionary = g.snapshot()
	old.houses[g.player].armies.append({"id":99,"province":home,"strength":120,"upkeep":1,"morale":80})
	check(g.restore(old), "Ältere Partie mit mehreren Feldarmeen bleibt ladbar")
	main.refresh()
	check(inspector.get("army_picker") != null, "Zusätzliche gespeicherte Armeen sind ausdrücklich auswählbar")
	if inspector.get("army_picker") != null:
		var picker: OptionButton = inspector.army_picker
		check(picker.visible and picker.item_count == 2, "Armeewähler zeigt alle eigenen Verbände")
		var gold: int = g.house().gold
		picker.select(1)
		picker.item_selected.emit(1)
		await settle()
		check(int(g.army_for().id) == 99 and g.house().gold == gold and g.house().armies.size() == 2, "Explizite Auswahl aktiviert gespeichertes Heer ohne Einheitenverlust oder Kosten")
		check(not inspector.action_buttons.march.visible, "Befehle folgen dem Standort der ausdrücklich gewählten Armee")
	main._show_province()
	await settle()
	check(not _has_button(main.province_layer,"Ausbauen") and not _has_button(main.province_layer,"Truppen werben"), "Provinzdetail zeigt Informationen und führt zur einen Verwaltung")
	main._hide_province()

func _has_button(node: Node, prefix: String) -> bool:
	for button in node.find_children("*","Button",true,false):
		if button.visible and button.text.begins_with(prefix): return true
	return false

func settle() -> void:
	for i in 4: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("WARINTERACTIONTEST FAIL: " + message)
