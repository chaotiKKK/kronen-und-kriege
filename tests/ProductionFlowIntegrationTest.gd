extends Node
## Echte Game-Pfade; fertige Infrastruktur ist in diesen Randfällen ausdrücklich
## eine kontrollierte Ausgangslage. Normale Finanzierung wird separat geprüft.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Production = preload("res://scripts/RegionalProduction.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	seed(20261118)
	shared_horizon()
	current_production_export()
	frontier_receiver()
	npc_execution()
	print("PRODUCTIONFLOWINTEGRATIONTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func shared_horizon() -> void:
	var game = Game.new(Data,0)
	if not check(game.has_method("_material_horizon"),"Lieferbedarf besitzt eine gemeinsame örtliche Arbeitshorizontrechnung"): return
	var p: Dictionary=game.province("germanien__03")
	var w: int=Production.weight_u(p)
	var tasks: Array=[{"token":"region:1","id":1,"priority":0,"started_month":0,"material_total_u":6*w,"material_spent_u":0,"work_total_u":4*w,"work_done_u":0},
		{"token":"road:2:a","id":2,"priority":0,"started_month":0,"material_total_u":3*w,"material_spent_u":0,"work_total_u":3*w,"work_done_u":0}]
	var before: Dictionary=game.snapshot()
	var need: int=game._material_horizon(p,tasks,2)
	check(need<=6*w and need>=4*w,"Zwei Monate gemeinsamer Arbeit fordern nicht neun vollständige Materialeinheiten je Gewicht an")
	check(game.snapshot()==before and int(tasks[0].work_done_u)==0,"Theoretischer Horizont verändert weder Welt noch tatsächliche Aufgaben")
	var reverse: Array=tasks.duplicate(true)
	reverse.reverse()
	check(game._material_horizon(p,reverse,2)==need,"Gemeinsame Nachfrage bleibt unabhängig von der Eingabereihenfolge")

func current_production_export() -> void:
	var game = Game.new(Data,0)
	var source := "germanien__03"
	var target := "germanien__05"
	game.house().research.known=["surveying","road_building"]
	game.roads=[{"from":source,"to":target,"builder":0,"months":0,"state":"complete","construction":{}}]
	check(game.set_province_focus(source,"workshops").ok and game.build(target,"walls").ok,"Echte Startkasse bezahlt Werkstätten und tatsächliche Zielbaustelle")
	check(int(game.province(source).production.materials_u)==0,"Quelle beginnt ohne geliehenen oder vorbereiteten Vorrat")
	game.advance_month()
	var report: Dictionary=game.regional_production_report()
	var sent := 0
	for flow in report.flows:
		if str(flow.from)==source and str(flow.to)==target: sent+=int(flow.amount_u)
	check(sent>0,"Tatsächlich im Monat produzierte freie Baustoffe werden nach Reserve schon über den fertigen Weg geliefert")
	check(int(report.ledger[source].export_u)==sent and int(report.ledger[target].import_u)==sent,"Gleiche wirkliche Menge verlässt die Quelle und erreicht die Baustelle")
	for id in [source,target]:
		var row: Dictionary=report.ledger[id]
		check(int(row.before_u)+int(row.produced_u)+int(row.import_u)-int(row.used_u)-int(row.export_u)-int(row.wasted_u)==int(row.after_u),"Monatsledger bleibt mit frischer Produktion und Lieferung exakt konserviert: "+id)

func frontier_receiver() -> void:
	var game = Game.new(Data,0)
	var source := "germanien__03"
	var depot := "germanien__02"
	var target := "gallien__05"
	game.house().research.known=["surveying","road_building","logistics"]
	game.roads=[{"from":source,"to":depot,"builder":0,"months":0,"state":"complete","construction":{}}]
	check(game.set_province_focus(source,"agriculture").ok,"Kornkammer wird aus tatsächlichem Startgold bezahlt")
	check(game.raise_army(depot).ok and game.fabricate_claim(target).ok,"Echte Feldarmee und echter Anspruch sind regulär bezahlt")
	check(game.march_army(target).ok,"Die wirkliche Armee marschiert auf benachbartes beanspruchtes Fremdland")
	game.advance_month()
	var without: Dictionary=game.supply_report()
	var deficit: int=without.regions[target].shortfall
	var without_step: Dictionary=game.siege_preview(target)
	check(deficit>0,"Tatsächliches Feldheer hat im Fremdgebiet einen messbaren Fehlbedarf")
	game.province(depot).logistics_sites.depot=1 # Kontrollierter fertiger Standort; kein regulärer Baubeleg.
	var supplied: Dictionary=game.supply_report()
	check(int(supplied.regions[target]["import"])>0 and int(supplied.regions[target].shortfall)<deficit,"Eigene Belagerungsarmee wird als legitimer Depotempfänger versorgt, obwohl dort die fremde Zivilproduktion ruht")
	var with_step: Dictionary=game.siege_preview(target)
	check(int(with_step.get("progress",0))>int(without_step.get("progress",0)),"Tatsächlicher vorhandener Belagerungsschritt nutzt den verbesserten Nachschub")
	var source_export: int=supplied.regions[source]["export"]
	check(source_export>0 and source_export<=int(supplied.regions[source].export_available),"Frontversorgung verbraucht nur tatsächlichen übrigen Landwirtschaftsüberschuss")
	var before: Dictionary=game.snapshot()
	game.supply_report(); game.siege_preview(target)
	check(game.snapshot()==before,"Wiederholtes Lesen erzeugt keine Nahrung, Arbeit oder dauerhaften Zustandsänderungen")

func npc_execution() -> void:
	var game = Game.new(Data,0)
	if not check(game.has_method("_run_ai_economy"),"Reiner Wirtschaftsplaner ist an den tatsächlichen Monatslauf angeschlossen"): return
	var before: Dictionary=game.snapshot()
	game.advance_month()
	var orders = game.get("_last_economy_orders")
	check(orders is Dictionary and not orders.is_empty(),"Reguläre NPC-Häuser führen nach echtem Monatswechsel bezahlte Wirtschaftsabsichten aus")
	if not orders is Dictionary: return
	for hi in orders:
		var order: Dictionary=orders[hi]
		check(int(hi)!=game.player and int(order.gold_after)<int(order.gold_before),"NPC-Vorhaben nutzt fremdes echtes Budget ohne Menschenhaus zu steuern")
	var once: Dictionary=game.snapshot()
	game._run_ai_economy()
	check(game.snapshot()==once,"Ein zweiter Ausführungsaufruf im selben Monat kauft keinen zweiten NPC-Auftrag")
	check(int(before.project_serial)<int(once.project_serial),"Tatsächliche NPC-Projekte erhalten normale globale Projektkennungen")

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PRODUCTIONFLOWINTEGRATIONTEST FAIL: "+message)
	return ok
