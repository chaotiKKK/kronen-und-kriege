extends Node
## Kontrollierte Game-Integration; reguläre Finanzierungs-/NPC-Kampagne separat.
const GameScript = preload("res://scripts/Game.gd")
const DataScript = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	seed(20261118)
	var game = GameScript.new(DataScript,0)
	var available: bool = game.has_method("start_regional_project") and game.has_method("regional_production_report") and game.has_method("cancel_construction") and game.has_method("prioritize_construction")
	check(available,"Game besitzt die autoritative Produktions-/Projektstrecke")
	if not available:
		finish()
		return
	var id: String = game.house().capital
	var p: Dictionary = game.province(id)
	check(int(p.production.materials_u)==0 and p.regional_project.is_empty() and int(p.logistics_sites.depot)==0,"Frischer echter Regionsstart enthält keine geschenkten Materialien oder Anlagen")
	var original: Dictionary = game.snapshot()
	check(not original.is_empty() and Save.validate(original).is_empty(),"Aktueller Game-Snapshot ist tatsächlich gültig und nicht nur ein Fehlerwert")
	var preview: Dictionary = game.regional_project_preview(id,"market")
	check(preview.ok and int(preview.material_total_u)>0 and int(preview.work_total_u)>0,"Erster Markt hat echte gewichtete Material-/Arbeitsanforderungen")
	check(game.snapshot()==original,"Projektvorschau verändert weder Welt noch Seriennummer oder History")
	var gold: int = game.house().gold
	var level: int = p.buildings.market
	var serial: int = game.snapshot().project_serial
	check(game.build(id,"market").ok,"Bestehender Baubefehl startet das bezahlbare Vorhaben")
	check(int(game.house().gold)==gold-int(preview.gold) and int(p.buildings.market)==level,"Start zahlt genau einmal und erzeugt keinen sofortigen Fertigeffekt")
	check(int(p.regional_project.id)==serial+1 and int(p.regional_project.work_done_u)==0 and int(p.regional_project.material_spent_u)==0,"Auftrag erhält eindeutige Identität und beginnt ohne erfundenen Fortschritt")
	var project_id: int = p.regional_project.id
	var accepted: Dictionary = game.snapshot()
	check(not game.build(id,"walls").ok and game.snapshot()==accepted,"Zweiter Regionalbau am selben Ort bleibt vollständig zustandsneutral")
	check(not game.cancel_construction(id,project_id+1).ok and game.snapshot()==accepted,"Veraltete Abbruchkennung löscht oder erstattet nichts")
	check(not game.prioritize_construction(id,project_id,2).ok and game.snapshot()==accepted,"Ungültige Priorität verändert auch Seriennummer und Log nicht")
	check(game.prioritize_construction(id,project_id,1).ok and int(p.regional_project.priority)==1,"Vorrang verändert den tatsächlichen Auftrag")
	game.advance_month()
	check(int(p.regional_project.work_done_u)>0 and int(p.regional_project.material_spent_u)>0,"Regulärer Monatswechsel erzeugt reale Arbeit und verbraucht erzeugtes Material")
	var snapshot: Dictionary = game.snapshot()
	var restored = GameScript.new(DataScript,0)
	check(restored.restore(snapshot) and restored.snapshot()==snapshot,"Laufender Auftrag, Seriennummer und Materialreste überstehen echten Game-Roundtrip")
	var paid: int = p.regional_project.paid_gold
	gold = game.house().gold
	var stock: int = p.production.materials_u
	check(game.cancel_construction(id,project_id).ok,"Passender Auftrag lässt sich nach Fortschritt abbrechen")
	check(p.regional_project.is_empty() and int(p.buildings.market)==level and int(game.house().gold)==gold and int(p.production.materials_u)==stock and paid>0,"Abbruch bewahrt unbenutzten Vorrat und erstattet weder Gold noch verbrauchtes Material")
	var cancelled: Dictionary = game.snapshot()
	check(not game.cancel_construction(id,project_id).ok and game.snapshot()==cancelled,"Wiederholter Abbruch hat keinen zweiten Effekt")
	check(game.build(id,"market").ok and int(p.regional_project.id)>project_id,"Neuer Auftrag verwendet die alte Kennung nicht wieder")
	var ticks := 0
	while not p.regional_project.is_empty() and ticks<36 and not game.game_over:
		game.advance_month()
		ticks+=1
	check(p.regional_project.is_empty() and int(p.buildings.market)==level+1 and ticks>1,"Markt wird über echte Monate genau eine Stufe fertig")
	var completed_level: int = p.buildings.market
	game.advance_month()
	check(int(p.buildings.market)==completed_level,"Nachfolgender Monat wiederholt den Fertigeffekt nicht")
	await workshop_comparison()
	await capture_and_road_cases()
	development_events()
	finish()

func workshop_comparison() -> void:
	var times: Array = []
	for focus in ["balanced","workshops"]:
		seed(20261118)
		var game = GameScript.new(DataScript,0)
		var id: String = game.house().capital
		if focus=="workshops": check(game.set_province_focus(id,focus).ok,"Vierter Schwerpunkt ist über denselben bezahlten Game-Befehl wählbar")
		check(game.build(id,"market").ok,"Produktionsvergleich startet denselben realen Markt")
		var ticks := 0
		while not game.province(id).regional_project.is_empty() and ticks<36 and not game.game_over:
			game.advance_month()
			ticks+=1
		times.append(ticks)
		check(int(game.province(id).buildings.market)==1,"Beide Produktionswege erreichen tatsächlich den Fertigeffekt")
	check(int(times[1])<int(times[0]) and int(times[1])>=2,"Werkstätten beschleunigen denselben Bau durch endliche Ausbeute statt Sofortwirkung")

func capture_and_road_cases() -> void:
	seed(20261118)
	var game = GameScript.new(DataScript,0)
	var id: String = game.house().capital
	check(game.build(id,"market").ok,"Eroberungsfall beginnt mit tatsächlich bezahltem Auftrag")
	var stock: int = game.province(id).production.materials_u
	game._capture_province(id,1,false,false)
	check(game.province(id).regional_project.is_empty() and int(game.province(id).production.materials_u)==stock,"Echter Eroberungspfad beendet fremden Auftrag ohne Vorratsverdoppelung")
	var game2 = GameScript.new(DataScript,0)
	game2.house().research.known=["surveying","road_building"] # Kontrollierte Freischaltung, kein regulärer Forschungsnachweis.
	var from_id: String = game2.house().capital
	var to_id := ""
	for neighbour in game2.neighbours(from_id):
		if int(game2.province(neighbour).owner)==game2.player:
			to_id=neighbour
			break
	check(not to_id.is_empty(),"Echte eigene Landkante für das Straßenprojekt vorhanden")
	if to_id.is_empty(): return
	check(game2.build_road(from_id,to_id).ok and game2.roads.size()==1,"Straßenbefehl startet einen tatsächlichen neuen Auftrag")
	var road: Dictionary = game2.roads[0]
	check(str(road.state)=="building" and not road.get("construction",{}).is_empty() and road.construction.legs.size()==2,"Neue Straße enthält zwei bezahlte Arbeits-/Materialbeine statt eines freien Dreimonatstimers")
	var before: Dictionary = game2.snapshot()
	check(not before.is_empty() and Save.validate(before).is_empty(),"Neue Straßenrechnung ist im aktuellen Format wirklich serialisierbar")
	check(not game2.build_road(to_id,from_id).ok and game2.snapshot()==before,"Gegenläufiger Wiederholungsbefehl dupliziert keine Straße oder Kosten")

func development_events() -> void:
	for delta in [2,-1]:
		var game = GameScript.new(DataScript,0)
		var p: Dictionary=game.owned()[0]
		check(game.develop(str(p.id)).ok,"Ereignisfall beginnt mit regulär bezahltem Entwicklungsauftrag")
		var project: Dictionary=p.regional_project.duplicate(true)
		game._apply_effects({"dev":delta})
		var actual: int=p.dev
		check(Save.validate(game.snapshot()).is_empty(),"Normaler Entwicklungsgewinn/-verlust lässt den eingefrorenen Auftrag speicherbar")
		# Kontrollierter Abschluss-Unitfall; reale Monatsfertigstellung ist oben belegt.
		p.regional_project={}
		game._finish_regional_project(p,project)
		check(int(p.dev)==(actual+1 if actual<10 else actual),"Fertiger Ausbau addiert einen Schritt zum aktuellen Stand und überschreibt keine Ereignisfolge")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("CONSTRUCTIONGAMETEST FAIL: "+message)

func finish() -> void:
	print("CONSTRUCTIONGAMETEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
