extends Node
var checks := 0
var failures := 0
var main

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed = 0
	var ui = main.get_meta("modern_interface")
	var inspector = ui.province_inspector
	var own_id: String = main.game.house().capital
	main._on_province_selected(own_id)
	inspector.show_section("buildings")
	await settle()
	check(inspector.get("focus_picker") != null and inspector.action_buttons.has("province_focus"), "Eigene Provinz bietet einen Schwerpunkt mit bewusstem Wechselknopf")
	if inspector.get("focus_picker") == null or not inspector.action_buttons.has("province_focus"):
		finish()
		return
	var game = main.game
	var gold: int = game.house().gold
	var picker: OptionButton = inspector.focus_picker
	check(picker.item_count == 4 and picker.get_item_metadata(3)=="workshops","Vier ausschließende Ausrichtungen einschließlich Werkstätten ohne zusätzlichen Hauptreiter")
	picker.select(1)
	picker.item_selected.emit(1)
	await settle()
	check(int(game.house().gold) == gold and game.province(own_id).economic_focus == "balanced", "Vorschau bucht weder Geld noch Schwerpunkt")
	var preview: Dictionary = game.province_economy_preview(own_id,"agriculture")
	var expected_income := ("%.2f" % float(preview.projected_income)).replace(".",",")
	check(inspector.fields.focus_preview.text.contains(expected_income) and inspector.fields.focus_preview.text.contains(str(preview.projected_supply)), "Vorschau zeigt die tatsächlich berechneten Einkommens- und Versorgungsfolgen")
	check(not inspector.action_buttons.province_focus.disabled,"Erster Wechsel ist mit echter Startkasse möglich")
	inspector.action_buttons.province_focus.pressed.emit()
	await settle()
	check(game.province(own_id).economic_focus == "agriculture" and int(game.house().gold) == gold-int(preview.cost), "Echter UI-Befehl bezahlt den Kornkammerschwerpunkt genau einmal")
	picker.select(2)
	picker.item_selected.emit(2)
	await settle()
	check(inspector.action_buttons.province_focus.disabled and inspector.fields.focus_preview.text.contains("12"), "Zwölfmonatige Bindung wird sichtbar erklärt und gesperrt")
	inspector.show_section("army")
	await settle()
	check(inspector.fields.supply.text.contains("Bedarf") and inspector.fields.supply.text.contains("Import") and inspector.fields.supply.text.contains("jährlich"), "Gemeinsame Versorgungsbilanz und tatsächlicher Verlusttermin sind sichtbar")
	var foreign := ""
	for p in game.provinces:
		if int(p.owner) != game.player: foreign = p.id; break
	main._on_province_selected(foreign)
	await settle()
	check(not inspector.focus_picker.is_visible_in_tree() and not inspector.action_buttons.province_focus.is_visible_in_tree(), "Fremdes Land enthält keinen eigenen Schwerpunktwechsel")
	main._on_province_selected(own_id)
	inspector.show_section("buildings")
	await settle()
	check(picker.get_item_metadata(picker.selected) == "agriculture", "Rückwechsel zeigt den tatsächlichen aktuellen Schwerpunkt")
	main._set_map_mode("economy")
	main.map_view.zoom = 1.8
	main.map_view.center_on(main.map_view._label_point(game.province(own_id)))
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		await settle()
		var scroll: Node = inspector.get_parent()
		while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
		if scroll is ScrollContainer:
			scroll.ensure_control_visible(inspector.action_buttons.province_focus)
			await settle()
		check(inspector.action_buttons.province_focus.custom_minimum_size.y >= 44, "Schwerpunktwechsel bleibt mit Touch bedienbar")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(main.map_view.economic_markers_drawn.any(func(marker): return marker.id==own_id and marker.focus=="agriculture"), "Realer Karten-Draw zeigt die gewählte Kornkammer")
			get_viewport().get_texture().get_image().save_png("res://build/verify/economy-focus-%d.png" % int(scale*100))
	finish()

func settle() -> void:
	for i in 4: await get_tree().process_frame

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PROVINCEECONOMYUITEST FAIL: "+message)

func finish() -> void:
	print("PROVINCEECONOMYUITEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
