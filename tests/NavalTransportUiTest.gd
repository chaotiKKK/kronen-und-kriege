extends Node
## Eine echte Main-Instanz, kontrollierte1000Gold-Kasse. Kein regulärer
## Kampagnen-Budgetbeleg; tatsächliche Buttons/Renderer/Save/Touchgrößen.
const HOME := "britannien__03"
const TARGET := "gallien__04"
var main
var inspector
var ui
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(2)
	main.game.speed = 0
	main.settings.autosave = false
	main.game.house().gold = 1000
	ui = main.get_meta("modern_interface")
	ui.set_appearance(3)
	ui.set_text_scale(1.0)
	ui.set_touch_layout(false)
	inspector = ui.province_inspector
	main._on_province_selected(HOME)
	inspector.show_section("army")
	await settle()
	check(inspector.action_buttons.army.is_visible_in_tree() and inspector.action_buttons.fleet.is_visible_in_tree(),"Echter Wessex-Hafen bietet bezahlte Heer-/Flottenaufstellung")
	inspector.action_buttons.army.pressed.emit()
	inspector.action_buttons.fleet.pressed.emit()
	await settle()
	check(not main.game.army_for().is_empty() and not main.game.fleet_for().is_empty() and int(main.game.house().gold)==890,"Tatsächliche Aufstellungsbuttons bezahlen50und60Gold")
	main._set_map_mode("political")
	main._on_province_selected(TARGET)
	await settle()
	check(inspector.current_section=="army","Geprüftes Küstenziel öffnet auch ohne Landgrenze den passenden Militärbereich")
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible,"Küstenreichweite öffnet keine fremde Bau-/Wissensverwaltung")
	check(inspector.action_buttons.claim.is_visible_in_tree() and not inspector.action_buttons.claim.disabled,"Vorhandenes Geleit bietet den wirklichen40Gold-Küstenanspruch sichtbar an")
	if not check(inspector.action_buttons.has("transport_army"),"Ein kontextueller Seetransportbutton fehlt im vorhandenen Militärbereich"):
		finish()
		return
	var transport: Button = inspector.action_buttons.transport_army
	check(transport.is_visible_in_tree() and transport.disabled,"Vor einem Anspruch erklärt der vorhandene Transportbutton die gesperrte Landung")
	check(inspector.fields.transport.text.contains("London") and inspector.fields.transport.text.contains("Schiffe") and inspector.fields.transport.text.contains("Kapazität") and inspector.fields.transport.text.contains("Anspruch"),"Kurze echte Vorschau enthält Abfahrt, Geleitkapazität und tatsächlichen Anspruchsgrund")
	check(inspector.action_buttons.focus_army.is_visible_in_tree() and not inspector.action_buttons.focus_army.disabled,"Navigation zum eigenen Heer wird nach leerem oder fremdem Kontext wieder bedienbar")
	var before: Dictionary = main.game.snapshot()
	main.refresh()
	await settle()
	check(main.game.snapshot()==before,"Kontextvorschau und Refresh verändern keine Spielwelt")
	var gold: int = main.game.house().gold
	inspector.action_buttons.claim.pressed.emit()
	await settle()
	check(main.game.claim_active(TARGET) and int(main.game.house().gold)==gold-40,"Sichtbarer Küstenanspruch läuft durch den wirklichen Kernel und bezahlt40Gold")
	check(transport.is_visible_in_tree() and not transport.disabled,"Bezahlter Anspruch schaltet den tatsächlichen Landungsbutton frei")
	check(not inspector.fields.transport.text.contains("%d Mann" % int(main.game.army_for().strength)),"Transportvorschau wiederholt nicht die bereits angezeigte Stärke des ausgewählten Heers")
	check(not inspector.fields.battle.text.contains("+0 Kampfkraft"),"Angriffsprognose zeigt keinen wirkungslosen Nullbonus des Feldheers")
	check(not inspector.fields.army.text.contains("Heeresunterhalt des Hauses"),"Fremder Provinzkontext führt keinen irrelevanten hausweiten Heeresunterhalt auf")
	main._set_map_mode("war")
	main.map_view.zoom = 4.0
	main.map_view.center_on(Vector2(257.31868,408.1794))
	await settle()
	if check(main.map_view.has_method("naval_route_overlay"),"Kriegskarte besitzt eine an die tatsächliche Auswahl gebundene Wasserwegvorschau"):
		var overlay: Dictionary = main.map_view.naval_route_overlay()
		check(not overlay.is_empty() and str(overlay.origin)==HOME and str(overlay.target)==TARGET,"Kartenvorschau folgt dem ausgewählten tatsächlichen Heer und Ziel")
		if not overlay.is_empty():
			var anchors: PackedVector2Array = overlay.map_points
			check(anchors.size()==2 and anchors[0].distance_to(Vector2(244.58000027674163,408.30999989005585))<0.0001,"Karte verwendet bewiesenen Küstenanker statt Londoner Stadtlabel")
	await shot("ready-channel")
	gold = main.game.house().gold
	var owner: int = main.game.province(TARGET).owner
	transport.pressed.emit()
	await settle()
	check(str(main.game.army_for().province)==TARGET and str(main.game.fleet_for().station)==TARGET,"Sichtbarer Seetransport versetzt das wirkliche Heer und sein Geleit")
	check(int(main.game.house().gold)==gold and int(main.game.province(TARGET).owner)==owner and int(main.game.province(TARGET).siege)==0,"Landung kassiert kein Reisegold und erobert oder belagert nicht automatisch")
	check(inspector.action_buttons.siege.is_visible_in_tree() and inspector.action_buttons.siege.disabled,"Landung zeigt die Belagerung mit der bestehenden gemeinsamen Monatssperre")
	main._on_province_selected(HOME)
	inspector.show_section("army")
	await settle()
	check(transport.is_visible_in_tree() and transport.disabled and inspector.fields.transport.text.contains("Monat"),"Auch die Rückfahrt zeigt die wirkliche verbrauchte Monatsaktion")
	check(main._save().ok,"Tatsächliche Main speichert den Transportstand")
	main._load()
	main.game.speed = 0
	main._on_province_selected(HOME)
	inspector.show_section("army")
	await settle()
	check(str(main.game.army_for().province)==TARGET and transport.disabled and inspector.fields.transport.text.contains("Monat"),"Wirkliches Main-Wiederladen erhält Aufenthaltsort und UI-Monatssperre")
	main.game.advance_month()
	main.game.house().gold = 0
	main.game.house().claims = []
	main.game.house().truces[str(owner)] = main.game._now()+24
	main.refresh()
	await settle()
	check(transport.is_visible_in_tree() and not transport.disabled,"Eigene Rückküste bleibt bei leerer Kasse, Frieden und fehlendem Invasionsanspruch bedienbar")
	transport.pressed.emit()
	await settle()
	check(str(main.game.army_for().province)==HOME and str(main.game.fleet_for().province)==HOME and str(main.game.fleet_for().station)==HOME and int(main.game.house().gold)==0,"Wirklicher Rückfahrtsbutton bringt Heer und Geleit ohne Geldänderung nach London")
	main._on_province_selected("germanien__01")
	await settle()
	check(not transport.is_visible_in_tree(),"Ungeprüftes Binnenziel zeigt keinen sinnlosen Seetransportbutton")
	if main.map_view.has_method("naval_route_overlay"):
		check(main.map_view.naval_route_overlay().is_empty(),"Unpassende Auswahl entfernt die alte Routenzeichnung")
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		main._on_province_selected(TARGET)
		check(inspector.current_section=="army","Auch ein vorübergehend monatsgesperrtes Küstenziel behält den sinnvollen Kriegskontext")
		inspector.show_section("army")
		await settle()
		var scroll: Node = inspector.get_parent()
		while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
		if scroll is ScrollContainer:
			scroll.ensure_control_visible(transport)
			await settle()
			check(scroll.get_global_rect().encloses(transport.get_global_rect()),"Landungsbutton bleibt bei100/200Prozent vollständig in den sichtbaren Rollbereich bringbar")
		check(transport.custom_minimum_size.y>=44,"Landungsbutton bleibt bei100/200Prozent eine ausreichend große Touchfläche")
		await shot("naval-touch-%d" % int(scale*100))
	finish()

func settle() -> void:
	for index in 5: await get_tree().process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/verify/naval-gameplay/ui/screenshots")
	check(get_viewport().get_texture().get_image().save_png("res://build/verify/naval-gameplay/ui/screenshots/%s.png" % name)==OK,"Tatsächlicher Rendererbeleg gespeichert: "+name)

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("NAVALTRANSPORTUITEST FAIL: "+message)
	return ok

func finish() -> void:
	print("NAVALTRANSPORTUITEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
