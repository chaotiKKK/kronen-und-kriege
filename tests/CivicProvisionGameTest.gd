extends Node
const Game=preload("res://scripts/Game.gd")
const Data=preload("res://scripts/GameRegionData.gd")
const Save=preload("res://scripts/SaveGame.gd")
var checks:int=0
var failures:int=0

func _ready() -> void:
	seed(20261119)
	var game=Game.new(Data,0)
	var available:bool=true
	for method in ["provision_preview","set_province_rations","provision_report","_tick_provisioning","_run_ai_provisioning","_industry_budget"]:
		available=available and game.has_method(method)
	check(available,"Game besitzt die echten zivilen Mengen-/Politik-/Vorschau-APIs")
	var initialized:bool=game.provinces.all(func(p):return p.get("provisioning") is Dictionary)
	check(initialized,"Alle echten Regionen besitzen explizit initialisierte Vorräte")
	if not available or not initialized:
		finish()
		return
	test_neutral_start(game)
	test_authority(game)
	test_real_month(game)
	test_roundtrip(game)
	test_blockade()
	test_npc_and_human_boundaries()
	test_campaign_comparison()
	finish()

func test_neutral_start(game) -> void:
	check(game.provinces.size()==108 and int(game.house().gold)==140,"Vollständige normale Startwelt und echte Startkasse bleiben vorhanden")
	for p in game.provinces:
		var weight:int=roundi(float(p.economic_share)*1000000.0)
		check(int(p.provisioning.food_u)==3*weight and int(p.provisioning.satisfaction)==50 and p.provisioning.rations=="normal","Neuer örtlicher Vorrat wird ausschließlich proportional zum kanonischen Gewicht initialisiert: "+str(p.id))
	var report:Dictionary=game.snapshot().get("provisioning_report",{})
	check(report.get("month_index",0)==-1 and report.get("regions",{}).is_empty(),"Neue Partie behauptet noch keine bereits verbrauchte Monatsration")

func test_authority(game) -> void:
	var id:String=str(game.house().capital)
	var foreign:String=""
	for p in game.provinces:
		if int(p.owner)!=0: foreign=str(p.id);break
	var before:Dictionary=game.snapshot()
	check(not bool(game.set_province_rations(foreign,"generous").ok),"Fremdes Land erlaubt keine eigene Rationsentscheidung")
	check(game.provision_preview(foreign).is_empty(),"Fremde Vorratsverwaltung wird nicht als eigene Vorschau ausgegeben")
	check(not bool(game.set_province_rations(id,"madeup").ok),"Unbekannte Rationen sind gesperrt")
	check(not bool(game.set_province_rations(id,"normal").ok),"Wiederholung gleicher Politik ist ein unveränderter Noop")
	check(Save.diff(before,game.snapshot()).is_empty(),"Abgewiesene Politik ändert weder Welt noch Log")
	var preview:Dictionary=game.provision_preview(id,"generous")
	check(preview.get("ok",false) and preview.has("next") and preview.ration_rate==125,"Reine gültige großzügige Vorschau enthält die tatsächliche Ration")
	check(Save.diff(before,game.snapshot()).is_empty(),"Vorschau produziert, verbraucht und belohnt nichts")
	var old_food:int=game.province(id).provisioning.food_u
	var old_mood:int=game.province(id).provisioning.satisfaction
	var old_gold:int=game.house().gold
	check(game.set_province_rations(id,"generous").ok,"Eigene kostenlose Politikabsicht wird über das Modell angenommen")
	check(int(game.province(id).provisioning.food_u)==old_food and int(game.province(id).provisioning.satisfaction)==old_mood and int(game.house().gold)==old_gold,"Politik allein verändert weder Nahrung, Zufriedenheit noch Gold")

func test_real_month(game) -> void:
	var id:String=str(game.house().capital)
	var preview:Dictionary=game.provision_preview(id,"generous")
	var expected:Dictionary=preview.next.duplicate(true)
	game.advance_month()
	var report:Dictionary=game.provision_report(0)
	check(int(report.month_index)==game.calendar_index() and report.regions.has(id),"Ein gemeinsamer Monatslauf bucht die zivile Ration")
	var row:Dictionary=report.regions.get(id,{})
	for key in ["before_u","produced_u","consumed_u","requested_u","shortfall_u","wasted_u","after_u","farm_work_u","industry_labor_u","satisfaction_after"]:
		check(row.get(key,-1)==expected.get(key,-2),"Echter unveränderter erster Monat stimmt mit reiner Vorschau überein: "+key)
	check(row.consumed_u>0 and row.satisfaction_after>row.satisfaction_before,"Großzügige Rationen verbrauchen echte Nahrung und verbessern Zufriedenheit")
	var production:Dictionary=game.regional_production_report(0)
	for key in report.regions:
		var food:Dictionary=report.regions[key]
		check(production.ledger.has(key),"Tatsächlicher Produktionsbeleg ist vorhanden: "+str(key))
		var industry:Dictionary=production.ledger.get(key,{})
		var actual_work:int=int(industry.get("work_u",0))+int(industry.get("production_work_u",0))+int(industry.get("legacy_work_u",0))
		check(actual_work<=int(food.industry_labor_u) and actual_work+int(food.farm_work_u)<=int(food.total_labor_u),"Landwirtschaft, Bau und Produktion teilen tatsächlich dieselbe Arbeit: "+str(key))
	var before:Dictionary=game.snapshot()
	game._tick_provisioning()
	check(Save.diff(before,game.snapshot()).is_empty(),"Gleiche Monatsphase kann nicht doppelt Nahrung erzeugen oder verbrauchen")
	var focus:Dictionary=game.province_economy_preview(id,"workshops")
	check(focus.has("projected_material_potential_u") and focus.has("projected_industry_labor_u"),"Schwerpunktvorschau zeigt auch den positiven Baustoff-/Arbeitsgrund")

func test_roundtrip(game) -> void:
	var before:Dictionary=game.snapshot()
	var copy=Game.new(Data,0)
	check(copy.restore(JSON.parse_string(JSON.stringify(before))),"Echter19-Zustand bleibt über JSON ladbar")
	check(Save.diff(before,copy.snapshot()).is_empty(),"Vorräte, Restüberträge, Politik und echter Ledger bleiben erhalten")
	var held:Dictionary=copy.snapshot()
	copy._tick_provisioning()
	check(Save.diff(held,copy.snapshot()).is_empty(),"Restore bucht den geladenen Monat nicht erneut")

func test_blockade() -> void:
	var game=Game.new(Data,0)
	var id:String=str(game.house().capital)
	var p:Dictionary=game.province(id)
	p.siege=1;p.siege_owner=1 # Ausschließlich kontrollierte Blockadelage.
	var initial:int=p.provisioning.food_u
	for i in 3:
		game.advance_month()
		var row:Dictionary=game.provision_report(0).regions[id]
		check(row.produced_u==0 and row.farm_work_u==0 and row.industry_labor_u==0,"Feindliche Belagerung erzeugt keine zusätzliche Nahrung oder Arbeit")
	check(int(p.provisioning.food_u)==0 and initial>0,"Drei echte normale Rationen verbrauchen den endlichen Anfangsvorrat")
	game.advance_month()
	check(game.provision_report(0).regions[id].shortfall_u>0 and int(p.provisioning.satisfaction)<50,"Tatsächlicher Mangel hat eine begrenzte zivile Folge")
	p.siege=0;p.siege_owner=-1
	game.advance_month()
	var recovered:Dictionary=game.provision_report(0).regions[id]
	check(recovered.produced_u>0 and recovered.consumed_u>0 and recovered.after_u>0,"Nach Entlastung entsteht Erholung ausschließlich durch echte örtliche Arbeit")

func test_npc_and_human_boundaries() -> void:
	var game=Game.new(Data,0)
	check(game.configure_human_houses([0,1]),"Zwei menschliche Rollen sind konfigurierbar")
	var second:String=str(game.houses[1].capital)
	check(game.set_province_rations(second,"scarce",1).ok,"Zweite Menschenrolle entscheidet ausdrücklich selbst")
	game.houses[0].laws.tax=2
	game.houses[2].laws.tax=2 # Kontrollierter Politikvergleich, keine zusätzlichen Ressourcen.
	game._run_ai_provisioning()
	check(game.province(str(game.houses[0].capital)).provisioning.rations=="normal" and game.province(second).provisioning.rations=="scarce","KI verändert keine der beiden Menschenpolitiken")
	check(game.province(str(game.houses[2].capital)).provisioning.rations=="generous","Nichtmenschliche hohe Steuern werden mit tatsächlich aufwendigerer Versorgung ausgeglichen")
	var quantities:Array=[]
	for p in game.provinces:quantities.append(p.provisioning.duplicate(true))
	game.select_player_context(1);game.select_player_context(0)
	for i in game.provinces.size():check(game.provinces[i].provisioning==quantities[i],"Perspektivwechsel bucht keine Nahrung: "+str(i))

func test_campaign_comparison() -> void:
	for entry in [[0,2042],[1,3127]]:
		var house_index:int=entry[0]
		seed(int(entry[1]))
		var normal=Game.new(Data,house_index)
		seed(int(entry[1]))
		var generous=Game.new(Data,house_index)
		var id:String=str(normal.house().capital)
		check(generous.set_province_rations(id,"generous").ok,"Regular starting house can prioritize generous rations: "+id)
		var extra_food:=0
		var extra_farm_work:=0
		for month in 6:
			seed(int(entry[1])+month)
			normal.advance_month()
			seed(int(entry[1])+month)
			generous.advance_month()
			var baseline:Dictionary=normal.provision_report().regions[id]
			var improved:Dictionary=generous.provision_report().regions[id]
			extra_food+=int(improved.consumed_u)-int(baseline.consumed_u)
			extra_farm_work+=int(improved.farm_work_u)-int(baseline.farm_work_u)
		var regular:Dictionary=normal.province(id)
		var supported:Dictionary=generous.province(id)
		check(extra_food>0 and extra_farm_work>0,"Six regular months pay for the larger ration with food and labor: "+id)
		check(int(supported.provisioning.satisfaction)>int(regular.provisioning.satisfaction),"The paid ration improves actual satisfaction: "+id)
		var baseline_income:Dictionary=normal.province_economy_preview(id)
		var supported_income:Dictionary=generous.province_economy_preview(id)
		check(float(supported_income.current_income)>float(baseline_income.current_income),"Satisfaction improves the modeled gold contribution over the comparison world: "+id)
		check(Save.validate(normal.snapshot()).is_empty() and Save.validate(generous.snapshot()).is_empty(),"Both regular campaigns still yield valid saves: "+id)

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;print("CIVICPROVISIONGAMETEST FAIL: "+message)
func finish() -> void:
	print("CIVICPROVISIONGAMETEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
