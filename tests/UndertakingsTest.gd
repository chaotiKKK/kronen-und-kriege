extends Node

const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var game = Game.new(Data,0)
	if check(game.has_method("undertaking_board"),"Das Startspiel bietet verschiedene nachprüfbare Reichsvorhaben"):
		crop_campaign(game)
		roads_campaign()
		watch_campaign()
		border_and_network()
	print("UNDERTAKINGS %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func crop_campaign(game) -> void:
	seed(20261126)
	var board: Dictionary = game.undertaking_board()
	check(board.offers.size()==3 and board.offers.all(func(row): return row.ok),"Alle drei Eröffnungsrichtungen haben am regulären Start ein Ziel")
	var offer: Dictionary=choose(board,"granary")
	var router = Kernel.new()
	router.bind_game(game)
	var starting_gold: int=game.house().gold
	if not check(router.dispatch({"id":"undertake_start","kind":"granary","province":offer.province}).ok,"Kornkammer per normalem Befehl annehmen"): return
	var active: Dictionary=game.undertaking_board().active
	var token:int=active.serial
	var before: Dictionary=game.snapshot()
	check(not before.is_empty() and int(game.house().gold)==starting_gold,"Annahme ist noch keine Auszahlung")
	check(not router.dispatch({"id":"undertake_finish","token":token}).ok and game.snapshot()==before,"Vorzeitige Auszahlung bleibt ohne Folgen")
	check(not game.start_undertaking("roads",offer.province).ok,"Gleichzeitig bleibt nur der angenommene Auftrag offen")
	var resumed = Game.new(Data,0)
	check(resumed.restore(JSON.parse_string(JSON.stringify(before))) and resumed.undertaking_board().active.serial==token,"Laufende Aufgabe bleibt mit genau derselben Identität ladbar")
	var forged:=before.duplicate(true)
	forged.houses[0].undertaking.active.province="unbekannt"
	check(not Save.validate(forged).is_empty(),"Rohspielstand darf keinen erfundenen Zielort annehmen")
	var captured = Game.new(Data,0)
	captured.restore(before)
	captured._capture_province(str(offer.province),1)
	check(not captured.undertaking_board().ready and captured.undertaking_board().reason.contains("gehört"),"Eroberung blockiert die Vergütung")
	check(captured.cancel_undertaking(token).ok and not captured.finish_undertaking(token).ok,"Abbruch hinterlässt keinen Anspruch")
	var id:=str(offer.province)
	check(game.set_province_focus(id,"agriculture").ok,"Landwirtschaft aus normalen Mitteln wählen")
	check(game.start_research("surveying").ok,"Vermessung bezahlen")
	for month in 4: advance(game)
	check(game.start_research("crop_rotation").ok,"Fruchtwechsel bezahlen")
	for month in 8: advance(game)
	for month in 16:
		if game.undertaking_board().ready: break
		advance(game)
	if not check(game.undertaking_board().ready,"Bezahlter Fruchtwechsel und vier Monatsrationen erfüllen die Kornkammer"): return
	var gold: int=game.house().gold
	var renown: int=game.house().renown
	var reward: Dictionary=game.undertaking_board().reward
	write_proof("BQ_UNDERTAKING_READY_PROOF",game.snapshot())
	check(router.dispatch({"id":"undertake_finish","token":token}).ok and game.house().gold==gold+int(reward.gold) and game.house().renown==renown+int(reward.renown),"Vergütung für spielbare Leistung genau einmal buchen")
	check(not router.dispatch({"id":"undertake_finish","token":token}).ok,"Wiederholte Anfrage zahlt nicht erneut")
	resumed=Game.new(Data,0)
	check(resumed.restore(game.snapshot()) and not choose(resumed.undertaking_board(),"granary").ok,"Abgeschlossene Richtung bleibt nach Laden abgeschlossen")
	write_proof("BQ_UNDERTAKING_DONE_PROOF",game.snapshot())
	print("UNDERTAKING_GRANARY province=",game.province(id).name," month=",game.calendar_index()," reward=",reward)

func roads_campaign() -> void:
	seed(20261124)
	var game=Game.new(Data,0)
	var offer:=choose(game.undertaking_board("germanien__03"),"roads")
	if not check(offer.ok and game.start_undertaking("roads",str(offer.province)).ok,"Straßenbund bietet eine konkrete noch fehlende Verbindung"): return
	var job: Dictionary=game.undertaking_board().active
	var origin:=str(job.province)
	var target:=str(job.partner)
	check(game.neighbours(origin).has(target) and not game.undertaking_board().ready,"Verlegen bloßer Ziele erfüllt keinen Straßenbau")
	if not check(game.start_research("surveying").ok,"Zivilroute finanziert die erste Forschung"): return
	for month in 4: advance(game)
	if not check(game.start_research("road_building").ok,"Zivilroute bezahlt die Straßenbauforschung"): return
	for month in 6: advance(game)
	if not check(game.build_road(origin,target).ok,"Die versprochene Straße wird regulär bezahlt"): return
	check(not game.undertaking_board().ready,"Eine Baustelle allein erfüllt das Ziel nicht")
	for month in 72:
		if game.undertaking_board().ready: break
		advance(game)
	if not check(game.undertaking_board().ready and game.finish_undertaking(int(job.serial)).ok,"Echte fertiggestellte Straße ermöglicht den Straßenbund"): return
	print("UNDERTAKING_ROAD from=",game.province(origin).name," to=",game.province(target).name," month=",game.calendar_index())

func watch_campaign() -> void:
	seed(20261124)
	var game=Game.new(Data,0)
	var fronts: Array=[]
	for p in game.owned():
		if game.is_border_province(0,str(p.id)) and int(p.buildings.walls)<3:
			fronts.append({"id":p.id,"gold":game.building_cost("walls",str(p.id))})
	fronts.sort_custom(func(a,b):return int(a.gold)<int(b.gold))
	if not check(not fronts.is_empty(),"Normales Startgebiet hat einen ausbaubaren Grenzort"): return
	var target := str(fronts[0].id)
	check(game.start_undertaking("watch",target).ok,"Grenzwacht wird in der regulären Partie am gewählten Ort angenommen")
	if not check(game.build(target,"walls").ok,"Normale Kasse finanziert echte neue Mauern"): return
	for month in 72:
		if not game.province(target).regional_project.is_empty():
			advance(game)
			continue
		if int(game.house().gold)>=50: break
		advance(game)
	if not check(game.raise_army(target).ok,"Ein Feldheer wird mit regulären 50 Gold aufgestellt"): return
	var goal: Dictionary=game.undertaking_board()
	check(goal.ready and game.finish_undertaking(int(goal.active.serial)).ok,"Mauerbau und Feldheer schließen die Grenzwacht regulär ab")
	print("UNDERTAKING_WATCH province=",game.province(target).name," month=",game.calendar_index())

func border_and_network() -> void:
	var game=Game.new(Data,0)
	game.configure_human_houses([0,1])
	var choice:=choose(game.undertaking_board("",1),"watch")
	if not check(choice.ok,"Gast hat einen ausbaubaren Grenzort"): return
	var authority=Authority.new(game,{1:0,2:1})
	var target:=str(choice.province)
	check(not authority.execute(2,1,{"id":"undertake_start","kind":"watch","province":str(game.house().capital)}).ok,"Gast kann kein fremdes Reichsvorhaben starten")
	check(authority.execute(2,2,{"id":"undertake_start","kind":"watch","province":target}).ok and game.undertaking_board("",0).active.is_empty(),"Host bindet Vertrag ausschließlich an das Haus des Gastes")
	var current: Dictionary=game.undertaking_board("",1).active
	var token:=int(current.serial)
	check(authority.execute(2,3,{"id":"undertake_cancel","token":token}).ok,"Gast darf eigenen offenen Vertrag abbrechen")
	check(authority.execute(2,4,{"id":"undertake_start","kind":"watch","province":target}).ok and not authority.execute(2,5,{"id":"undertake_cancel","token":token}).ok,"Verspätete Abbruchkennung greift nicht auf neu angenommenen Auftrag zu")
	current=game.undertaking_board("",1).active
	# Controlled verification of the settlement criteria after normal border placement.
	game.province(target).buildings.walls=int(current.wall_level)
	check(not game.undertaking_board("",1).ready,"Mauer ohne Feldheer reicht nicht")
	game.houses[1].armies=[{"id":1,"province":target,"strength":100,"upkeep":1,"morale":90}]
	check(game.undertaking_board("",1).ready,"Eigene neue Mauer und ein kampffähiges Feldheer erfüllen Grenzwacht")
	check(authority.execute(2,6,{"id":"undertake_finish","token":int(current.serial)}).ok and str(game.player)=="0","Gast kann bezahlbare eigene Grenzwacht abschließen")

func choose(board: Dictionary, kind: String) -> Dictionary:
	for offer in board.offers:
		if offer.id==kind: return offer
	return {}

func advance(game) -> void:
	game.advance_month()
	if game.pending_event==null: return
	for i in range(game.pending_event.options.size()-1,-1,-1):
		if game.apply_event(i).ok: return
	game.decline_event()

func write_proof(variable: String,state: Dictionary) -> void:
	var path := OS.get_environment(variable)
	if path.is_empty(): return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(state))

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("UNDERTAKINGSTEST FAIL: "+label)
	return ok
