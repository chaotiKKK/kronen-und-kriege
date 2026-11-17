extends Node
## Headless prüft tatsächliche VM-/Kartendaten ohne Main. Fensterlauf prüft
## genau eine echte Main mit expliziten kontrollierten Kriegslagen.
const Game=preload("res://scripts/Game.gd")
const Data=preload("res://scripts/GameRegionData.gd")
const VM=preload("res://scripts/ViewModelBuilder.gd")
const Map=preload("res://scripts/MapView.gd")
const HOME:="britannien__03"
const TARGET:="gallien__04"
var checks:=0
var failures:=0
var main
var ui
var inspector

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		_headless()
	else:
		await _ui()
	print("FORTRESSCAMPAIGNUITEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func setup(game) -> int:
	var enemy: int=game.province(TARGET).owner
	game.house().gold=1000
	game.house().ruler.martial=12
	game.house().doctrine="balanced"
	game.house().research.known=[]
	game.houses[enemy].research.known=[]
	game.house().armies=[{"id":77,"province":TARGET,"strength":600,"morale":100,"upkeep":2,"last_siege_month":0}]
	game.house().claims=[{"province":TARGET,"strength":1,"expires":game._now()+24}]
	game.houses[enemy].armies=[]
	game.province(TARGET).levy=400
	game.province(TARGET).defense=100
	game.province(TARGET).terrain_defense=0
	game.province(TARGET).terrain_supply=20
	game.province(TARGET).buildings.walls=3
	game.province(TARGET).siege=30
	game.province(TARGET).siege_owner=2
	return enemy

func _headless() -> void:
	var game=Game.new(Data,2)
	setup(game)
	var before: Dictionary=game.snapshot()
	var vm: Dictionary=VM.province(game,TARGET)
	if check(vm.has("military"),"Gemeinsames tatsächliches Provinz-ViewModel enthält Festungs-/Kampfbefehle"):
		var military: Dictionary=vm.military
		check(military.siege.progress==16 and military.siege.current==30 and military.siege.next==46,"UI benutzt genau die tatsächliche Festungsvorschau16/30/46")
		check(military.siege.garrison==400 and military.siege.wall_level==3,"UI übernimmt tatsächliche Garnison und Mauern aus Modellvorschau")
		check(game.snapshot()==before,"Militär-ViewModel verändert keine Welt oder History")
	var map=Map.new()
	map.game=game
	map.map_mode="war"
	if check(map.has_method("siege_markers"),"Tatsächlicher Kartenzeichenpfad besitzt gemeinsame Belagerungsgeometrie"):
		var markers: Array=map.siege_markers()
		check(markers.size()==1 and markers[0].province==TARGET and markers[0].house==2,"Belagerungsmarker gehört zum echten Besieger und Ziel")
		if not markers.is_empty():
			check(is_equal_approx(float(markers[0].end_angle)-float(markers[0].start_angle),TAU*.3),"30Prozent belegen einen tatsächlichen30Prozent-Bogen statt eines Vollrings")
			check(markers[0].color==game.houses[2].color,"Belagerungsbogen verwendet die tatsächliche Hausfarbe")
		game.province(TARGET).siege=0
		check(map.siege_markers().is_empty(),"Beendete Belagerung entfernt die Zeichenmetadaten")
	map.free()

func _ui() -> void:
	main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(2)
	main.game.speed=0
	main.settings.autosave=false
	ui=main.get_meta("modern_interface")
	ui.set_appearance(3)
	ui.set_text_scale(1.0)
	ui.set_touch_layout(false)
	inspector=ui.province_inspector
	var game=main.game
	var enemy:=setup(game)
	main._on_province_selected(TARGET)
	main._set_map_mode("war")
	await settle()
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible,"Fremde Festung öffnet keine eigene Bau-/Forschungsverwaltung")
	check(inspector.fields.battle.is_visible_in_tree() and inspector.fields.battle.text.contains("Mauern") and inspector.fields.battle.text.contains("30 → 46"),"Eine gemeinsame sichtbare Festungsvorschau zeigt tatsächlichen nächsten Schritt")
	if not check(inspector.action_buttons.has("relieve") and inspector.action_buttons.has("recover_army") and inspector.action_buttons.has("disband_army"),"Bestehendes Militärpanel enthält die drei kontextuellen Kampagnenaktionen"):
		return
	check(not inspector.action_buttons.recover_army.visible and not inspector.action_buttons.disband_army.visible and not inspector.action_buttons.relieve.visible,"Fremdgebiet zeigt keine eigenen Feldlager-/Auflösungs-/Entsatzaktionen")
	check(inspector.action_buttons.siege.is_visible_in_tree() and not inspector.action_buttons.siege.disabled,"Tatsächliche Belagerungsaktion ist an der feindlichen Festung bedienbar")
	main.map_view.zoom=3.0
	main.map_view.center_on(main.map_view._label_point(game.province(TARGET)))
	await shot("fortress-ready")
	inspector.action_buttons.siege.pressed.emit()
	await settle()
	check(int(game.province(TARGET).siege)==46 and inspector.action_buttons.siege.disabled and main.attack_btn.disabled,"Wirkliche Belagerung erzeugt16Punkte und sperrt auch den Sturm im selben Monat")
	var before: Dictionary=game.snapshot()
	main.attack_btn.pressed.emit()
	await settle()
	check(game.snapshot()==before,"Auch verspäteter Sturmaufruf umgeht verbrauchte Heeresaktion nicht und schreibt keine Fehlerchronik")
	# Neuer kontrollierter Feldlagerfall, kein Feldzug-/Budgetbeleg.
	game.month+=1
	game.army_for().province=HOME
	game.army_for().strength=100
	game.army_for().morale=40
	game.province(HOME).levy=500
	game.province(TARGET).siege=0
	game.province(TARGET).siege_owner=-1
	main._on_province_selected(HOME)
	inspector.show_section("army")
	await settle()
	check(inspector.action_buttons.recover_army.is_visible_in_tree() and not inspector.action_buttons.recover_army.disabled,"Eigenes beschädigtes tatsächliches Heerlager bietet bezahltes Auffüllen")
	check(inspector.fields.battle.text.contains("100 → 200") and inspector.fields.battle.text.contains("40 → 60"),"Gemeinsame Feldlagervorschau zeigt tatsächliche Soldaten- und Moralfolge")
	before=game.snapshot()
	inspector.action_buttons.disband_army.pressed.emit()
	await settle()
	check(inspector.disband_box.is_visible_in_tree() and game.snapshot()==before,"Sekundäres Auflösen öffnet nur eine bewusste lokale Bestätigung ohne Mutation")
	inspector.action_buttons.disband_cancel.pressed.emit()
	check(not inspector.disband_box.visible and game.snapshot()==before,"Abbrechen schließt die Auflösungsabsicht ohne Spielaktion")
	var gold: int=game.house().gold
	inspector.action_buttons.recover_army.pressed.emit()
	await settle()
	check(int(game.army_for().strength)==200 and int(game.army_for().morale)==60 and int(game.house().gold)==gold-15 and int(game.province(HOME).levy)==400,"Tatsächlicher Feldlagerbutton bezahlt15Gold und überträgt100örtliche Soldaten")
	check(inspector.action_buttons.recover_army.disabled and inspector.action_buttons.disband_army.disabled,"Feldlager und Auflösen teilen die bestehende Monatsaktion")
	game.month+=1
	game.house().armies.append({"id":78,"province":HOME,"strength":50,"morale":70,"upkeep":1,"last_siege_month":0})
	main.refresh()
	inspector.action_buttons.disband_army.pressed.emit()
	await settle()
	inspector.army_picker.select(1)
	inspector.army_picker.item_selected.emit(1)
	await settle()
	check(int(game.army_for().id)==78 and not inspector.disband_box.visible,"Echte Wahl eines anderen Legacy-Heers verwirft alte Armee-ID-Bestätigung")
	inspector.action_buttons.disband_army.pressed.emit()
	before=game.snapshot()
	main._on_province_selected(TARGET)
	await settle()
	check(not inspector.disband_box.visible and game.snapshot()==before,"Provinzwechsel verwirft alte Auflösung ohne fremde Aktion")
	main._set_map_mode("political")
	main._on_province_selected(HOME)
	inspector.show_section("research")
	main._on_province_selected(TARGET)
	await settle()
	check(not inspector.action_buttons["build:market"].is_visible_in_tree() and not inspector.action_buttons.research_plan.is_visible_in_tree(),"Echter Fremdbesitzwechsel entfernt eigene Bau- und Forschungsaktionen selbst")
	inspector.show_section("research")
	check(not inspector.sections.research.visible,"Alter eigener Wissensaufruf öffnet im fremden Ziel keine Verwaltung")
	main._on_province_selected(HOME)
	await settle()
	check(inspector.current_section=="research","Politische Karte erhält die gewählte eigene Wissenssektion nach fremder Inspektion")
	game.province(HOME).owner=enemy
	main.refresh()
	await settle()
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible and not inspector.action_buttons.recover_army.visible and not inspector.action_buttons.disband_army.visible,"Besitzverlust derselben Auswahl schließt eigene Verwaltung und Feldlager sofort")
	game.province(HOME).owner=2
	main.refresh()
	await settle()
	check(inspector.current_section=="research" and inspector.section_buttons.buildings.visible and inspector.section_buttons.research.visible,"Rückgewonnener eigener Besitz stellt gewählte Wissenssektion und echten Ausbaukontext wieder her")
	inspector.show_section("army")
	gold=game.house().gold
	var levy: int=game.province(HOME).levy
	inspector.action_buttons.disband_army.pressed.emit()
	await settle()
	inspector.action_buttons.disband_confirm.pressed.emit()
	await settle()
	check(game.house().armies.size()==1 and int(game.army_for().id)==77 and int(game.house().gold)==gold and int(game.province(HOME).levy)==levy,"Bewusst bestätigte ID78wird allein und ohne Ressourcenrefund aufgelöst")
	game.month+=1
	game.army_for().morale=100
	game.houses[enemy].armies=[{"id":88,"province":HOME,"strength":100,"morale":100,"upkeep":1,"last_siege_month":0}]
	game.province(HOME).siege=40
	game.province(HOME).siege_owner=enemy
	game.attack_roll_override=1.15
	main.refresh()
	await settle()
	check(inspector.action_buttons.relieve.is_visible_in_tree() and not inspector.action_buttons.relieve.disabled and not inspector.action_buttons.recover_army.visible and not inspector.action_buttons.disband_army.visible,"Eigener bedrohte Ort bündelt tatsächlichen Entsatz statt freier Feldlagerverwaltung")
	inspector.action_buttons.relieve.pressed.emit()
	await settle()
	check(int(game.province(HOME).owner)==2 and int(game.province(HOME).siege)==0 and int(game.house().gold)==gold,"Tatsächlicher Entsatz beendet Feindbelagerung ohne Goldpreis und Besitzwechsel")
	# Kontrollierte Festungsvorschau für große Texte und echte Scroll-/Touchfläche.
	game.month+=1
	setup(game)
	main._set_map_mode("war")
	main._on_province_selected(TARGET)
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		await settle()
		var scroll: Node=inspector.get_parent()
		while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
		if scroll is ScrollContainer:
			scroll.ensure_control_visible(inspector.action_buttons.siege)
			await settle()
			check(scroll.get_global_rect().encloses(inspector.action_buttons.siege.get_global_rect()),"Belagerungsbutton bleibt bei100/200Prozent vollständig in den Rollbereich bringbar")
		check(inspector.action_buttons.siege.custom_minimum_size.y>=44,"Bestehender Feldzugsbutton bleibt eine mindestens44Pixel große Touchfläche")
		await shot("fortress-touch-%d" % int(scale*100))

func settle() -> void:
	for index in 5: await get_tree().process_frame

func shot(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://fortress-campaign-ui/screenshots")
	check(get_viewport().get_texture().get_image().save_png("user://fortress-campaign-ui/screenshots/%s.png" % name)==OK,"Tatsächlicher Rendererbeleg gespeichert: "+name)

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("FORTRESSCAMPAIGNUITEST FAIL: "+message)
	return ok
