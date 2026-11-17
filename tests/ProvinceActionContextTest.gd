extends Node
## Tatsächliche Main und UI-Befehle. Die Zusatzarmee ist ein ausdrücklich
## kontrollierter Legacy-Spielstandfall; keine reguläre Kampagnenbehauptung.
var main
var ui
var inspector
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed = 0
	main.settings.autosave = false
	ui = main.get_meta("modern_interface")
	ui.set_appearance(3)
	ui.set_text_scale(1.0)
	ui.set_touch_layout(false)
	inspector = ui.province_inspector
	var game = main.game
	var home: String = game.house().capital
	var remote := ""
	for province in game.provinces:
		if int(province.owner)!=game.player and str(province.kingdom)=="anatolien" and not game.is_border_province(game.player,str(province.id)):
			remote = province.id
			break
	if not check(not remote.is_empty(),"Tatsächliches fremdes Ferngebiet für Besitz- und Aktionswechsel vorhanden"):
		finish()
		return
	main._on_province_selected(home)
	inspector.show_section("research")
	await settle()
	check(inspector.action_buttons.research_plan.is_visible_in_tree(),"Eigenes Wissen führt weiterhin zum gemeinsamen Forschungsplan")
	main._on_province_selected(remote)
	await settle()
	check(inspector.current_section=="achievements" and not inspector.section_buttons.army.visible,"Fremdes Ferngebiet bietet nur sinnvolle Diplomatie statt eines leeren Kriegsreiters")
	check(inspector.section_tabs.columns==1,"Ein verbleibender Kontext nutzt die volle verfügbare Reiterbreite")
	inspector.show_section("army")
	check(inspector.current_section=="achievements","Ein alter Kriegsaufruf öffnet im strukturell unerreichbaren Ferngebiet keinen leeren Bereich")
	check_admin_closed("Fremdbesitz")
	var before: Dictionary = game.snapshot()
	inspector.action_buttons.research_plan.pressed.emit()
	check(not main.infrastructure_layer.visible,"Ein verspäteter Forschungsaufruf aus fremdem Provinzkontext öffnet keinen eigenen Verwaltungsplan")
	main._hide_infrastructure()
	inspector._command({"id":"build","key":"market"})
	inspector._apply_focus()
	check(game.snapshot()==before,"Veraltete Verwaltungsaufrufe auf fremdem Land verändern auch die History nicht")
	await shot("foreign-context")
	main._on_province_selected(home)
	inspector.show_section("buildings")
	await settle()
	check(inspector.focus_picker.item_count==3 and inspector.action_buttons["build:market"].visible,"Rückkehr zum Eigenbesitz stellt echte Verwaltungsaktionen wieder her")
	main._on_province_selected("")
	await settle()
	check_admin_closed("Leerauswahl")
	var stale_actions := 0
	for button in inspector.action_buttons.values():
		if button.visible or not button.disabled: stale_actions+=1
	check(stale_actions==0,"Leerauswahl räumt alle alten Kontextaktionen ab, statt nur den übergeordneten Bereich zu verdecken")
	before = game.snapshot()
	inspector.action_buttons.research_plan.pressed.emit()
	inspector._command({"id":"build","key":"market"})
	check(not main.infrastructure_layer.visible and game.snapshot()==before,"Leerer Kontext führt weder Verwaltungsnavigation noch abgewiesene Logbuchbefehle aus")
	main._hide_infrastructure()
	# Kontrollierte Kasse nur für die anschließenden tatsächlichen UI-Befehle.
	game.house().gold = 1000
	main._on_province_selected(home)
	inspector.show_section("buildings")
	await settle()
	var level: int = game.province(home).buildings.market
	var gold: int = game.house().gold
	inspector.action_buttons["build:market"].pressed.emit()
	await settle()
	check(int(game.province(home).buildings.market)==level+1 and int(game.house().gold)<gold,"Wiederhergestellter Baubutton baut tatsächlich einmal und bezahlt seine Kosten")
	var original_owner: int = game.province(home).owner
	game.province(home).owner = game.province(remote).owner
	main.refresh()
	await settle()
	check_admin_closed("Besitzverlust derselben Auswahl")
	game.province(home).owner = original_owner
	main.refresh()
	inspector.show_section("army")
	await settle()
	inspector.action_buttons.army.pressed.emit()
	await settle()
	check(not game.army_for().is_empty(),"Der wiederhergestellte eigene Militärbereich stellt ein wirklich bezahltes Heer auf")
	if game.army_for().is_empty():
		finish()
		return
	var first: Dictionary = game.army_for()
	var unit_text := "%d Mann" % int(first.strength)
	check(inspector.fields.field_army.text.contains(unit_text) and not inspector.fields.army.text.contains(unit_text),"Das ausgewählte örtliche Feldheer wird einmal zusammengefasst statt erneut in der Ortsliste")
	main._on_province_selected(remote)
	await settle()
	check(not inspector.section_buttons.army.visible and not inspector.fields.field_army.visible and not inspector.action_buttons.focus_army.visible,"Ein weit entferntes eigenes Heer öffnet im fremden Ferngebiet keine sinnlose Militärverwaltung")
	# Eine zweite, erhaltene Legacy-Armee steht tatsächlich im fremden Ziel.
	var second_id := int(first.id)+1
	game.house().armies.append({"id":second_id,"province":remote,"strength":321,"morale":73,"upkeep":2,"last_siege_month":-1})
	main.refresh()
	await settle()
	check(inspector.section_buttons.army.visible,"Eine andere eigene Armee im fremden Ziel erhält den Kriegskontext auch bei abweichender aktiver Armee")
	inspector.show_section("army")
	check(inspector.army_picker.visible and inspector.army_picker.item_count==2,"Mehrere erhaltene Heere bleiben ausdrücklich auswählbar")
	inspector.army_picker.select(1)
	inspector.army_picker.item_selected.emit(1)
	await settle()
	check(int(game.army_for().id)==second_id and inspector.fields.field_army.text.contains("321 Mann"),"Der echte Armeewähler wechselt auf den örtlichen Verband")
	check(not inspector.fields.army.text.contains("321 Mann"),"Auch das ausgewählte Legacy-Heer wird nicht doppelt aufgelistet")
	# Aktive Kampfstellung und Anspruch bleiben sichtbar, obwohl die Aktion
	# vorübergehend im selben Monat gesperrt ist.
	game.house().claims.append({"province":remote,"strength":1,"expires":game._now()+24})
	game.army_for().last_siege_month = game._now()
	main.refresh()
	await settle()
	check(inspector.section_buttons.army.visible and inspector.action_buttons.siege.visible and inspector.action_buttons.siege.disabled,"Ein monatsgesperrtes Feldheer im Ziel behält die tatsächliche Belagerungsaktion mit Sperre")
	var staging: String = game.neighbours(remote)[0]
	game.army_for().province = staging
	main.refresh()
	await settle()
	var reason: String = game.siege_reason(remote)
	check(not reason.is_empty() and inspector.fields.orders.text.count(reason)==1,"Gleiche Monatsgründe für Marsch und Belagerung erscheinen einmal statt doppelt")
	game.army_for().province = home
	main.refresh()
	await settle()
	check(inspector.section_buttons.army.visible,"Ein bestehender aktiver Fernanspruch bleibt als militärisches Vorhaben auffindbar")
	game.house().claims = []
	game.province(remote).siege = 30
	game.province(remote).siege_owner = game.player
	main.refresh()
	await settle()
	check(inspector.section_buttons.army.visible,"Eine laufende Belagerung wird auch ohne gegenwärtige Anmarschreichweite nicht verborgen")
	game.province(remote).siege = 0
	game.province(remote).siege_owner = -1
	main.refresh()
	await settle()
	check(not inspector.section_buttons.army.visible and inspector.current_section=="achievements","Endet die letzte relevante Kampfstellung, fällt die Auswahl auf Diplomatie zurück")
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		await settle()
		check(inspector.section_tabs.columns==1 and inspector.section_buttons.achievements.custom_minimum_size.y>=44,"Einfacher Fremdkontext bleibt bei 100/200 Prozent vollständig touchbedienbar")
		await shot("foreign-touch-%d" % int(scale*100))
	finish()

func check_admin_closed(context: String) -> void:
	check(not inspector.sections.buildings.visible and not inspector.sections.research.visible,context+": eigene Verwaltungsbereiche sind geschlossen")
	check(not inspector.action_buttons.research_plan.visible and inspector.action_buttons.research_plan.disabled,context+": Forschungszugang selbst ist entfernt und gesperrt")
	check(not inspector.action_buttons["build:market"].visible and inspector.action_buttons["build:market"].disabled,context+": eigener Baubutton selbst ist entfernt und gesperrt")
	check(inspector.focus_picker.item_count==0 and inspector.fields.research.text.is_empty(),context+": alte Fokusauswahl und eigener Forschungsinhalt werden nicht weitergetragen")

func settle() -> void:
	for index in 5: await get_tree().process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/verify/context-simplification/screenshots")
	check(get_viewport().get_texture().get_image().save_png("res://build/verify/context-simplification/screenshots/%s.png" % name)==OK,"Realer Rendererbeleg gespeichert: "+name)

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PROVINCEACTIONCONTEXTTEST FAIL: "+message)
	return ok

func finish() -> void:
	print("PROVINCEACTIONCONTEXTTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
