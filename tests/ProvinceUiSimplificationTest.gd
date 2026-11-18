extends Node
## Reale Main-Navigation: ein Provinzinspektor statt zusätzlicher Modalansicht.
## Keine Produktlogik; optionale echte Root-Viewport-Belege nur mit Renderer.
## Exportlauf: -- --proof-dir=C:/absoluter/Belegordner
var checks := 0
var failures := 0
var results: Array = []
var main
var ui
var inspector
var game
var home := ""
var border := ""
var remote := ""
var inspector_identity := 0
var proof_dir := ""
var proof_images: Array = []

func _ready() -> void:
	if not configure_proof_output():
		get_tree().quit(2)
		return
	seed(20261118)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	game = main.game
	game.speed = 0
	ui = main.get_meta("modern_interface")
	inspector = ui.province_inspector
	inspector_identity = inspector.get_instance_id()
	ui.set_appearance(3)
	home = str(game.house().capital)
	for p in game.provinces:
		if int(p.owner) == game.player: continue
		var id := str(p.id)
		if border.is_empty() and game.is_border_province(game.player,id): border = id
		if remote.is_empty() and not game.is_border_province(game.player,id) and not game.is_coastal(id): remote = id
	check(not home.is_empty() and not border.is_empty() and not remote.is_empty(), "Echte eigene, fremde Grenz- und entfernte Binnenregion vorhanden")
	if home.is_empty() or border.is_empty() or remote.is_empty():
		finish()
		return
	await settle()
	var before := world_hash()
	await test_canonical_entries()
	await test_sidebar()
	await test_foreign_contexts()
	await test_global_research()
	await test_metadata()
	await test_touch_details()
	await test_touch_and_scroll()
	check(world_hash() == before, "Auswahl, Reiter, Forschungsplan und Touchlayout verändern keine Spielwelt")
	await test_maximum_buildings()
	finish()

func test_canonical_entries() -> void:
	for id in [home,remote,border]:
		for entry in ["alias","activation","management"]:
			close_optional_modals()
			main._on_province_selected(id)
			ui.show_section("family")
			match entry:
				"alias": main._show_province()
				"activation": main._on_province_activated(id)
				"management": main._open_province_management()
			await settle()
			check_canonical(id,"%s/%s" % [entry,id])
	# Alle noch angebotenen Alt-Callbacks müssen ebenfalls denselben Inspector öffnen.
	for button in buttons_calling(main,"_show_province"):
		close_optional_modals()
		main._on_province_selected(home)
		ui.show_section("family")
		button.pressed.emit()
		await settle()
		check_canonical(home,"pressed "+button.text)
	for modal in ["rule","chronicle"]:
		close_optional_modals()
		main._on_province_selected(home)
		main.call("_show_"+modal)
		await settle()
		var offered: Array = []
		for button in buttons_calling(main,"_open_province_management"):
			if button.is_visible_in_tree(): offered.append(button)
		check(offered.size() == 1, "%s bietet genau einen sichtbaren Verweis zur Provinzverwaltung" % modal)
		if offered.size() == 1:
			offered[0].pressed.emit()
			await settle()
			check_canonical(home,modal+" pressed")
	# Regression: Ein Aufruf desselben Ortes darf Wissen nicht durch Krieg ersetzen.
	close_optional_modals()
	main._on_province_selected(home)
	main._set_map_mode("war")
	inspector.show_section("research")
	main._show_province()
	await settle()
	check(inspector.current_section == "research" and inspector.sections.research.is_visible_in_tree(), "Alias bewahrt eigene Wissenssektion auch im Kartenmodus Krieg")
	for button in buttons_calling(main,"_show_province"):
		close_optional_modals()
		inspector.show_section("research")
		button.pressed.emit()
		await settle()
		check(inspector.current_section == "research" and inspector.sections.research.is_visible_in_tree(), "Provinz-Callback bewahrt Wissen im Kriegsmodus")
	close_optional_modals()
	main._set_map_mode("political")

func check_canonical(id: String, context: String) -> void:
	check(ui.province_inspector.get_instance_id() == inspector_identity and inspector.selected_id == id, context+": derselbe Inspector zeigt die gewählte Region")
	check(ui.current_section == "overview" and main.side_panel.is_visible_in_tree() and inspector.is_visible_in_tree() and main.side_panel.is_ancestor_of(inspector), context+": rechte Provinzseite wird sichtbar")
	check(main.kernel.top_modal() == "game" and visible_dialogs() == 0, context+": keine zusätzliche Provinz-Modalebene")

func test_sidebar() -> void:
	main._on_province_selected(home)
	await settle()
	check(not inspector.action_buttons.province_focus.is_visible_in_tree() and not inspector.fields.focus_preview.text.contains("→"), "Bereits gewählter Schwerpunkt zeigt weder 0-Gold-Wechsel noch identische Vorher-/Nachherwerte")
	inspector.focus_picker.select(1)
	inspector.focus_picker.item_selected.emit(1)
	await settle()
	check(inspector.action_buttons.province_focus.visible and inspector.fields.focus_preview.text.contains("→"), "Eine tatsächlich andere Ausrichtung behält nachvollziehbare Vorschau und Wechselaktion")
	inspector.focus_picker.select(0)
	inspector.focus_picker.item_selected.emit(0)
	await settle()
	var labels: Array = []
	for child in ui.sidebar_tabs.get_children():
		if child is Button and child.visible: labels.append(child.text)
	labels.sort()
	check(labels == ["Familie","Politik","Provinz"], "Sidebar bietet nur Provinz, Politik und Familie; keinen Welt-Doppelzugang")
	for id in ["politics","family","overview"]:
		var button: Button = ui.section_buttons.get(id)
		check(button != null and button.is_visible_in_tree(), "Sidebarzugang %s bleibt sichtbar" % id)
		if button != null:
			button.pressed.emit()
			await settle()
			check(ui.pages[id].is_visible_in_tree(), "Sidebar-Button %s öffnet seine echte Seite" % id)

func test_foreign_contexts() -> void:
	main._on_province_selected(remote)
	await settle()
	check(inspector.current_section == "achievements" and inspector.sections.achievements.is_visible_in_tree(), "Entferntes Fremdland zeigt unmittelbar Diplomatie")
	check(not inspector.section_tabs.is_visible_in_tree(), "Ein alleiniger Diplomatiebereich braucht keine sichtbare Reiterleiste")
	check_foreign_administration("entfernt")
	await capture_proof("foreign-diplomacy")
	main._on_province_selected(border)
	await settle()
	check(inspector.section_tabs.is_visible_in_tree(), "Fremde Grenze behält die zwei sinnvollen navigierbaren Bereiche")
	var visible := 0
	for button in inspector.section_buttons.values():
		if button.is_visible_in_tree(): visible += 1
	check(visible == 2, "Grenzkontext zeigt genau Krieg und Diplomatie")
	for id in ["achievements","army"]:
		var button: Button = inspector.section_buttons[id]
		check(button.is_visible_in_tree() and not button.disabled, "Grenzreiter %s ist wirklich bedienbar" % id)
		button.pressed.emit()
		await settle()
		check(inspector.current_section == id and inspector.sections[id].is_visible_in_tree(), "Realer Grenzreiter %s wechselt die sichtbare Sektion" % id)
	check_foreign_administration("Grenze")
	await capture_proof("foreign-border-war")

func check_foreign_administration(context: String) -> void:
	var vm: Dictionary = load("res://scripts/ViewModelBuilder.gd").province(game,inspector.selected_id)
	check(vm.buildings.is_empty() and vm.research.is_empty(), context+": ViewModel enthält keinen fremden Bau-/Forschungsaktionskatalog")
	check(not inspector.section_buttons.buildings.is_visible_in_tree() and not inspector.section_buttons.research.is_visible_in_tree(), context+": keine fremden Ausbau-/Wissensreiter")
	for key in ["build:market","build:barracks","build:walls","province_focus","research_plan"]:
		check(not inspector.action_buttons[key].is_visible_in_tree(), context+": fremde Verwaltungsaktion %s bleibt geschlossen" % key)
	check(not main.develop_btn.is_visible_in_tree(), context+": keine fremde Entwicklungskaufaktion")

func test_global_research() -> void:
	main._on_province_selected(remote)
	await settle()
	var global_entries: Array = []
	for button in buttons_calling(main,"_show_infrastructure"):
		if not inspector.is_ancestor_of(button): global_entries.append(button)
	check(global_entries.size() == 1, "Genau ein globaler Forschungsplan-Zugang außerhalb des eigenen Wissen-Shortcuts")
	var toolbar: Button = null
	for button in global_entries:
		if ui.navigation.is_ancestor_of(button): toolbar = button
	check(toolbar != null and toolbar.is_visible_in_tree(), "Globaler Forschungsplan ist in der Kartenwerkzeugleiste erreichbar")
	if toolbar != null:
		toolbar.pressed.emit()
		await settle()
		var presenter = main.get_meta("research_panel")
		check(main.infrastructure_layer.is_visible_in_tree() and main.research_buttons.surveying.is_visible_in_tree(), "Globaler Toolbar-Button öffnet den tatsächlichen Forschungsplan bei Fremdauswahl")
		check(presenter.scope_label.text.contains(str(game.house().name)) and not presenter.scope_label.text.contains(str(game.province(remote).name)), "Globale Forschung bleibt beim eigenen Haus ohne fremden Ortsgeltungsbereich")
		main._hide_infrastructure()
	main._on_province_selected(home)
	inspector.show_section("research")
	await settle()
	var shortcut: Button = inspector.action_buttons.research_plan
	check(shortcut.is_visible_in_tree() and not shortcut.disabled, "Eigener Wissensbereich behält seinen Shortcut zum gemeinsamen Forschungsplan")
	shortcut.pressed.emit()
	await settle()
	check(main.infrastructure_layer.is_visible_in_tree(), "Eigener Wissen-Shortcut öffnet denselben echten Forschungsplan")
	main._hide_infrastructure()

func test_metadata() -> void:
	for id in [home,remote]:
		main._on_province_selected(id)
		await settle()
		var p: Dictionary = game.province(id)
		var tooltip: String = inspector.summary.tooltip_text
		for key in ["kingdom_name","duchy_name","empire_name","terrain_name"]:
			check(tooltip.contains(str(p[key])), "Inspector-Metadaten bewahren %s für %s" % [key,id])
		check(tooltip.contains(str(game.army_supply_capacity(id,int(p.owner)))), "Inspector-Metadaten bewahren tatsächliche örtliche Versorgung")
		var neighbours: Array = game.neighbours(id)
		check(not neighbours.is_empty(), "Metadatenfixture hat einen echten Nachbarn")
		if not neighbours.is_empty():
			check(tooltip.contains(str(game.province(str(neighbours[0])).name)), "Inspector-Metadaten bewahren Nachbarorte der ehemaligen Detailansicht")

func test_touch_details() -> void:
	var available: bool = inspector.action_buttons.has("details") and inspector.fields.has("details")
	check(available, "Touchzugängliche Provinzdetails haben echten Details-Button und aufklappbaren Text")
	if not available: return
	main._on_province_selected(home)
	await settle()
	var toggle: Button = inspector.action_buttons.details
	var detail: Label = inspector.fields.details
	check(toggle.is_visible_in_tree() and not toggle.disabled and not detail.is_visible_in_tree(), "Gültige Provinz startet mit kompakt geschlossenen Details")
	toggle.pressed.emit()
	await settle()
	check(detail.is_visible_in_tree(), "Realer Details-Button öffnet die Metadaten für Touch")
	await capture_proof("own-details-open")
	for id in [home,remote]:
		main._on_province_selected(id)
		await settle()
		if not detail.is_visible_in_tree():
			toggle.pressed.emit()
			await settle()
		var p: Dictionary = game.province(id)
		for key in ["kingdom_name","duchy_name","empire_name","terrain_name"]:
			check(detail.text.contains(str(p[key])), "Touchdetails bewahren %s für %s" % [key,id])
		check(detail.text.contains(str(game.army_supply_capacity(id,int(p.owner)))), "Touchdetails bewahren örtliche Versorgung")
		var neighbours: Array = game.neighbours(id)
		if not neighbours.is_empty():
			check(detail.text.contains(str(game.province(str(neighbours[0])).name)), "Touchdetails aktualisieren Nachbarorte nach Auswahlwechsel")
	main._on_province_selected("")
	await settle()
	check(not detail.is_visible_in_tree() and (not toggle.is_visible_in_tree() or toggle.disabled), "Leere Auswahl schließt Details und bietet keinen toten Details-Button")
	main._on_province_selected(home)
	await settle()
func test_touch_and_scroll() -> void:
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		main._on_province_selected(home)
		inspector.show_section("research")
		await settle()
		var own_sections := 0
		for button in inspector.section_buttons.values():
			if button.is_visible_in_tree():
				own_sections += 1
				check(button.size.y >= 44.0, "Eigener Reiter hat44px Touchhöhe bei%dProzent" % int(scale*100))
		check(own_sections == 3, "Eigene Provinz behält ihre drei Bereiche bei%dProzent" % int(scale*100))
		await check_scroll_reachable(inspector.action_buttons.research_plan, "Wissen-Shortcut",scale)
		await capture_proof("own-knowledge-touch-%d" % int(scale*100))
		inspector.section_buttons.buildings.pressed.emit()
		await settle()
		var scroll: Node = inspector.get_parent()
		while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
		# Godots skalierte Font-Grundlinie kann einen Pixel über dem Inhaltsrand liegen.
		if scroll is ScrollContainer and not scroll.get_global_rect().grow(1).encloses(inspector.title.get_global_rect()):
			print("SCROLL_DIAGNOSTIC: ",JSON.stringify({"scale":scale,"vertical":scroll.scroll_vertical,"scroll_rect":str(scroll.get_global_rect()),"title_rect":str(inspector.title.get_global_rect()),"inspector_rect":str(inspector.get_global_rect()),"section":inspector.current_section}))
		check(scroll is ScrollContainer and scroll.scroll_vertical == 0 and scroll.get_global_rect().grow(1).encloses(inspector.title.get_global_rect()), "Reiterwechsel zeigt zuerst den Provinzkopf statt die alte Scrollposition bei%dProzent" % int(scale*100))
		if is_equal_approx(scale,1.0): await capture_proof("own-buildings")
		await check_scroll_reachable(inspector.action_buttons["build:walls"], "letzte Gebäudeaktion",scale)
		if scroll is ScrollContainer:
			var scrolled: int = scroll.scroll_vertical
			main.refresh()
			await settle()
			check(scroll.scroll_vertical==scrolled, "Unveränderte Aktualisierung bewahrt die bewusst gewählte Scrollposition bei%dProzent" % int(scale*100))
		main._on_province_selected(border)
		await settle()
		for id in ["army","achievements"]:
			var button: Button = inspector.section_buttons[id]
			check(button.is_visible_in_tree() and button.size.y >= 44.0, "Grenzreiter %s hat44px bei%dProzent" % [id,int(scale*100)])
			button.pressed.emit()
			await settle()
			check(inspector.sections[id].is_visible_in_tree(), "Grenzbereich %s bleibt bei%dProzent navigierbar" % [id,int(scale*100)])
		main._on_province_selected(remote)
		await settle()
		check(not inspector.section_tabs.is_visible_in_tree() and inspector.sections.achievements.is_visible_in_tree(), "Einzelne Diplomatie bleibt ohne Reiter bei%dProzent sichtbar" % int(scale*100))

func check_scroll_reachable(control: Control, label: String, scale: float) -> void:
	check(control.is_visible_in_tree() and control.size.y >= 44.0, "%s ist eine sichtbare44px Touchfläche bei%dProzent" % [label,int(scale*100)])
	var scroll: Node = control.get_parent()
	while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
	check(scroll is ScrollContainer, "%s liegt im echten Scrollbereich" % label)
	if scroll is ScrollContainer:
		scroll.ensure_control_visible(control)
		await settle()
		check(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()), "%s ist bei%dProzent vollständig ins Scrollfenster bringbar" % [label,int(scale*100)])

func test_maximum_buildings() -> void:
	# Kontrollierte reine UI-Lage: volle Stufen bei ausreichender Kasse.
	# Kein Nachweis einer regulär finanzierten Aufbauspielpartie.
	var p: Dictionary = game.province(home)
	for key in ["market","barracks","walls"]: p.buildings[key] = 3
	game.house().gold = 1000
	main._on_province_selected(home)
	inspector.show_section("buildings")
	await settle()
	var before := world_hash()
	for key in ["market","barracks","walls"]:
		var button: Button = inspector.action_buttons["build:"+key]
		var detail: Label = inspector.fields["build:"+key]
		check(button.is_visible_in_tree() and button.disabled and button.text.contains("3/3"), "Maximales Gebäude %s zeigt seinen nicht kaufbaren Bestand" % key)
		check(not button.text.contains("Gold"), "Maximales Gebäude %s zeigt keinen nutzlosen Kaufpreis" % key)
		check(not detail.is_visible_in_tree() or not detail.text.contains("Höchste Stufe"), "Maximales Gebäude %s vermeidet zusätzlichen Höchste-Stufe-Text" % key)
	check(world_hash() == before, "Anzeigen maximaler Gebäude verändert keine Spielwelt")
	await capture_proof("max-buildings")

func buttons_calling(target: Object, method: String) -> Array:
	var found: Array = []
	for node in main.find_children("*","Button",true,false):
		for connection in node.get_signal_connection_list("pressed"):
			var callback: Callable = connection["callable"]
			if callback.get_object() == target and str(callback.get_method()) == method:
				found.append(node)
				break
	return found

func visible_dialogs() -> int:
	var count := 0
	for dialog in ui.dialogs:
		if is_instance_valid(dialog.card) and dialog.card.is_visible_in_tree(): count += 1
	return count

func close_optional_modals() -> void:
	for entry in [["_hide_rule","herrschaft"],["_hide_chronicle","chronik"],["_hide_infrastructure","infrastructure"]]:
		if main.has_method(entry[0]) and main.kernel.modal_stack.has(entry[1]): main.call(entry[0])

func world_hash() -> String:
	return main.LanSessionScript.Protocol.world_hash(game.snapshot())

func settle() -> void:
	for frame in 5: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	results.append({"ok":ok,"message":message})
	if not ok:
		failures += 1
		print("PROVINCEUISIMPLIFICATIONTEST FAIL: "+message)

func configure_proof_output() -> bool:
	proof_dir = ProjectSettings.globalize_path("res://build/verify/province-ui-simplification")
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--proof-dir="): continue
		var requested := argument.trim_prefix("--proof-dir=")
		if requested.is_empty() or not requested.is_absolute_path() or requested.begins_with("res://") or requested.begins_with("user://"):
			printerr("PROVINCEUISIMPLIFICATIONTEST: --proof-dir requires an absolute filesystem path")
			return false
		proof_dir = requested
	var error := DirAccess.make_dir_recursive_absolute(proof_dir)
	if error != OK:
		printerr("PROVINCEUISIMPLIFICATIONTEST: proof directory cannot be created: %s (%s)" % [proof_dir,error_string(error)])
		return false
	return true

func capture_proof(label: String) -> void:
	# Headless has no real rendered frame and must never emit screenshot evidence.
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var rendered: Image = get_viewport().get_texture().get_image()
	check(rendered != null and not rendered.is_empty(), "Echter gerenderter Viewport für Beleg "+label)
	if rendered == null or rendered.is_empty(): return
	var path := proof_dir.path_join(label+".png")
	var error := rendered.save_png(path)
	check(error == OK, "Gerendertes Fensterbild gespeichert: "+label)
	if error == OK:
		proof_images.append({"name":label,"path":path,"width":rendered.get_width(),"height":rendered.get_height(),"source":"root_viewport/frame_post_draw"})

func finish() -> void:
	var file := FileAccess.open(proof_dir.path_join("result.json"),FileAccess.WRITE)
	if file == null:
		check(false,"Ergebnisdatei kann im Belegordner nicht geschrieben werden: "+proof_dir)
	else:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"fixture":"Real Main scene, fresh house0 paused; controlled max-building fixture only at end","proof_dir":proof_dir,"display_server":DisplayServer.get_name(),"headless":DisplayServer.get_name()=="headless","screenshots_skipped":DisplayServer.get_name()=="headless","screenshots":proof_images},"\t",true))
		file.close()
	main._stop_audio()
	print("PROVINCEUISIMPLIFICATIONTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures == 0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
