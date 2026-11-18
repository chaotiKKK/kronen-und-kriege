extends Node
## Realer Inspector: Besitzwechsel dürfen keine fremden Verwaltungsaktionen
## oder einen zweiten Forschungsplan offen lassen.
var checks := 0
var failures := 0
var main
var ui
var inspector

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed = 0
	ui = main.get_meta("modern_interface")
	inspector = ui.province_inspector
	ui.set_appearance(3)
	ui.set_text_scale(1.0)
	var game = main.game
	main._on_province_selected("")
	await settle()
	check(not inspector.section_tabs.visible, "Ohne Auswahl stehen keine toten Provinzreiter im Weg")
	var home: String = game.house().capital
	main._on_province_selected(home)
	inspector.show_section("research")
	await settle()
	check(not inspector.section_buttons.achievements.visible, "Hausweites Vermächtnis erzeugt keinen vierten örtlichen Verwaltungsbereich")
	check(inspector.section_tabs.columns == 3, "Eigener Besitz bündelt drei kompakte Bereiche in einer Zeile")
	var duplicate := 0
	for button in inspector.sections.research.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.text.contains("Gold"): duplicate += 1
	check(duplicate == 0, "Wissen dupliziert keine kostenpflichtigen Forschungsstartbuttons")
	var plan: Button = inspector.action_buttons.get("research_plan")
	check(plan != null and plan.is_visible_in_tree(), "Eigene Provinz führt zum einen vollständigen Forschungsplan")
	await shot("own-knowledge-before")
	if plan != null:
		var before: int = game.house().gold
		plan.pressed.emit()
		await settle()
		check(main.infrastructure_layer.visible and main.research_buttons.surveying.is_visible_in_tree(), "Provinzverweis öffnet die echten gemeinsamen Forschungsaktionen")
		check(int(game.house().gold) == before, "Öffnen des Plans bezahlt noch kein Projekt")
		main.research_buttons.surveying.pressed.emit()
		await settle()
		check(game.house().research.active == "surveying" and int(game.house().gold) == before-20, "Gemeinsamer Forschungsplan startet Vermessung genau einmal für20Gold")
		main._hide_infrastructure()
		check(inspector.fields.research.text.contains("Vermessung") and inspector.fields.research.text.contains("6"), "Provinzkurzstatus zeigt tatsächliches Projekt und Restzeit")
	var border := ""
	var remote := ""
	for province in game.provinces:
		if int(province.owner) == game.player: continue
		if border.is_empty() and game.is_border_province(game.player,str(province.id)): border = province.id
		if remote.is_empty() and str(province.kingdom) == "anatolien": remote = province.id
	if remote.is_empty():
		for province in game.provinces:
			if int(province.owner) != game.player and not game.is_border_province(game.player,str(province.id)):
				remote = province.id
	check(not border.is_empty() and not remote.is_empty(), "Echte Grenz- und Fernregionen für Kontextwechsel vorhanden")
	check(game.has_method("attack_in_range"), "Angriffsreichweite besitzt dieselbe reine Abfrage für Regeln und Oberfläche")
	if game.has_method("attack_in_range"):
		check(not game.attack_in_range(border) and not game.attack_in_range(remote), "Ohne tatsächlich vorhandenes Feldheer ersetzt auch die eigene Grenze keine militärische Reichweite")
	var world_before: String = main.LanSessionScript.Protocol.world_hash(game.snapshot())
	main._on_province_selected(remote)
	await settle()
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible, "Fremdregion bietet keinen Ausbau und keine Wissensverwaltung")
	check(inspector.current_section == "achievements", "Fernes Land öffnet Diplomatie statt einer Liste unerreichbarer Kriegsbefehle")
	await shot("foreign-diplomacy")
	inspector.show_section("army")
	check(not inspector.action_buttons.claim.visible and not inspector.action_buttons.siege.visible and not main.attack_btn.visible, "Ohne Grenze, Anspruch oder Feldheer keine sinnlosen Anspruchs-/Belagerungs-/Angriffsbuttons")
	await shot("foreign-remote-before")
	main._on_province_selected(home)
	await settle()
	check(inspector.current_section == "research" and inspector.sections.research.visible, "Eigener Wissensbereich kehrt nach fremder Inspektion zurück")
	main._on_province_activated(home)
	await settle()
	check(main.side_panel.visible and inspector.is_visible_in_tree() and inspector.selected_id == home and not main.kernel.modal_stack.has("provinz"), "Aktivierung nutzt dieselbe rechte Provinzseite statt eines zweiten großen Dialogs")
	check(main.LanSessionScript.Protocol.world_hash(game.snapshot()) == world_before, "Auswahl, Ansicht und Aktivierung verändern keine Spielwelt")
	main._on_province_selected(border)
	await settle()
	check(inspector.current_section == "army", "Fremde Grenzregion führt direkt zum passenden Kriegskontext")
	check(inspector.action_buttons.claim.is_visible_in_tree() and not inspector.action_buttons.claim.disabled, "Benötigter Anspruch bleibt als nächster Schritt sichtbar")
	check(not main.attack_btn.visible and not inspector.action_buttons.siege.visible, "Vor dem Anspruch werden nachfolgende Kriegsaktionen nicht doppelt angeboten")
	var gold: int = game.house().gold
	inspector.action_buttons.claim.pressed.emit()
	await settle()
	check(game.has_claim(border) and int(game.house().gold) == gold-40, "Sichtbarer Anspruch führt echten bestehenden40GoldBefehl aus")
	check(inspector.status.is_visible_in_tree() and not inspector.status.text.is_empty(), "Ausgeführte Kontextaktion bestätigt ihr Ergebnis sichtbar")
	check(not main.attack_btn.visible and not game.attack_in_range(border), "Ein Anspruch allein erzeugt keinen nationalen Ersatzangriff ohne Feldheer")
	# Ab hier kontrollierte militärische UI-Lage, kein regulärer Budgetbeleg.
	game.house().gold = 1000
	var staging := ""
	for neighbor in game.neighbours(border):
		if int(game.province(neighbor).owner) == game.player:
			staging = neighbor
			break
	check(not staging.is_empty(), "Eigene tatsächliche Aufstellungsregion grenzt unmittelbar ans gewählte Ziel")
	main._on_province_selected(staging)
	var formation_gold: int = game.house().gold
	check(main._dispatch({"id":"army"}).ok and int(game.house().gold)==formation_gold-50, "Tatsächliches Feldheer wird über echten UI-Aufstellungsbefehl für50Gold aufgestellt")
	# Der Kontexttest prüft Verfügbarkeit, nicht Festungsbalance: kontrollierte
	# geringe Garnison lässt das wirklich aufgestellte Heer ausreichend drücken.
	game.province(border).levy = 100
	game.province(border).defense = 0
	game.province(border).terrain_defense = 0
	main._on_province_selected(border)
	await settle()
	check(main.attack_btn.is_visible_in_tree() and not main.attack_btn.disabled, "Anspruch plus bereites echtes Nachbarheer bieten den tatsächlichen Sturm an")
	game.house().gold = 0
	main.refresh()
	check(main.attack_btn.visible and main.attack_btn.disabled and inspector.fields.orders.text.contains("25"), "Kurzzeitiger Goldmangel erklärt im gemeinsamen Aktionsstatus den weiterhin passenden Sturm")
	check(game.attack_in_range(border) and not game.can_attack(border), "Reine Reichweite bleibt bei Goldmangel erhalten, tatsächlicher Angriff bleibt gesperrt")
	var original_owner: int = game.province(border).owner
	game.province(border).owner = game.player
	main.refresh()
	await settle()
	check(inspector.section_buttons.buildings.visible and inspector.section_buttons.research.visible and not inspector.section_buttons.achievements.visible, "Besitzerwechsel derselben Auswahl stellt auf eigene Verwaltung um")
	game.province(border).owner = original_owner
	main.refresh()
	await settle()
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible, "Besitzverlust derselben Auswahl blendet Verwaltung sofort aus")
	game.house().gold = 1000
	if not staging.is_empty():
		main._on_province_selected(staging)
		check(str(game.army_for().get("province",""))==staging, "Das tatsächlich bezahlte Feldheer bleibt am überprüften Ausgangsstandort")
		main._on_province_selected(border)
		await settle()
		check(inspector.action_buttons.siege.is_visible_in_tree() and not inspector.action_buttons.siege.disabled, "Anspruch plus nahes Heer bieten die tatsächliche Belagerung an")
		var before_siege: int = game.province(border).siege
		inspector.action_buttons.siege.pressed.emit()
		await settle()
		check(int(game.province(border).siege) > before_siege, "Sichtbare Belagerung bewirkt echten Fortschritt")
		check(inspector.action_buttons.siege.visible and inspector.action_buttons.siege.disabled and inspector.action_buttons.siege.tooltip_text.contains("Monat"), "Monatssperre erklärt die weiter passende Belagerungsaktion")
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		main._on_province_selected(home)
		inspector.show_section("research")
		await settle()
		if plan != null:
			check(plan.custom_minimum_size.y >= 44, "Gemeinsamer Forschungszugang bleibt bei100/200Prozent eine Touchfläche")
			var scroll: Node = inspector.get_parent()
			while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
			if scroll is ScrollContainer:
				scroll.ensure_control_visible(plan)
				await settle()
				check(scroll.get_global_rect().encloses(plan.get_global_rect()), "Forschungsplan bleibt bei100/200Prozent vollständig in den sichtbaren Rollbereich bringbar")
		await shot("own-knowledge-%d" % int(scale*100))
	finish()

func settle() -> void:
	for index in 5: await get_tree().process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/verify/context-ui/screenshots")
	get_viewport().get_texture().get_image().save_png("res://build/verify/context-ui/screenshots/%s.png" % name)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PROVINCECONTEXTTEST FAIL: "+message)

func finish() -> void:
	print("PROVINCECONTEXTTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
