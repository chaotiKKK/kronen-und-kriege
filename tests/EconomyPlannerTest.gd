extends Node
## Normal-budget decisions are separate from explicitly controlled logistics fixtures.
const Game = preload("res://scripts/Game.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const Naval = preload("res://scripts/NavalCampaign.gd")
var planner
var checks:=0
var failures:=0

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/EconomyPlanner.gd"):
		check(false,"Real NPC economy must propose a paid useful action while preserving its actual military reserve")
		finish()
		return
	planner=load("res://scripts/EconomyPlanner.gd")
	if planner==null:
		check(false,"Pure NPC economy planner loads")
		finish()
		return
	test_normal_start_and_purity()
	test_humans_defeat_and_budget()
	test_normal_wessex_saves_for_sea()
	test_controlled_material_chain()
	test_controlled_frontier_chain()
	test_controlled_project_budget()
	test_controlled_threat()
	test_legacy_research_month_guard()
	finish()

func test_legacy_research_month_guard() -> void:
	var game=fresh()
	# Controlled valid migrated research: four of the original six months remain.
	var owned: Array=game.provinces.filter(func(p): return int(p.owner)==1)
	game.houses[1].research={"known":[],"active":"surveying","months":4,"legacy_duration":6}
	check(not planner._already_bought(game,1,owned),"Four remaining legacy months are not mistaken for a newly started four-month innovation")
	game.houses[1].research.months=6
	check(planner._already_bought(game,1,owned),"Actual original six-month start still blocks a second paid NPC intent in that month")
	game.houses[1].research={"known":[],"active":"surveying","months":4}
	check(planner._already_bought(game,1,owned),"A genuinely new four-month start still blocks a second paid NPC intent")

func fresh():
	seed(20261118)
	return Game.new(Regions,0)

func state_hash(game) -> String:
	return JSON.stringify([game.provinces,game.houses,game.roads,game.project_serial,game.year,game.month,game.player,game.human_houses,game._player_contexts,game.log_lines,game.pending_event,game.history,game.house_history,game.effect_log,game.disabled_edges,game.game_over]).sha256_text()

func plan_unchanged(game,hi: int) -> Dictionary:
	var before:=state_hash(game)
	var order: Dictionary=planner.next_order(game,hi)
	check(state_hash(game)==before,"Read-only NPC planning preserves exact world/perspective hash for house"+str(hi))
	return order

func cost(game,order: Dictionary,hi: int) -> int:
	match str(order.get("id","")):
		"build": return int(game.regional_project_preview(str(order.province),str(order.key),hi).gold)
		"develop": return int(game.regional_project_preview(str(order.province),"develop",hi).gold)
		"road": return int(game.road_preview(str(order.province),str(order.to),hi).gold)
		"province_focus":
			for choice in game.province_focus_choices(str(order.province),hi):
				if str(choice.id)==str(order.focus): return int(choice.cost)
		"research":
			for choice in game.research_choices(hi):
				if str(choice.id)==str(order.innovation): return int(choice.gold)
	return 0

func execute(game,order: Dictionary,hi: int) -> Dictionary:
	match str(order.get("id","")):
		"build": return game.build(str(order.province),str(order.key),hi)
		"develop": return game.develop(str(order.province),hi)
		"road": return game.build_road(str(order.province),str(order.to),hi)
		"province_focus": return game.set_province_focus(str(order.province),str(order.focus),hi)
		"research": return game.start_research(str(order.innovation),hi)
	return {"ok":false}

func test_normal_start_and_purity() -> void:
	var game=fresh()
	check(int(game.houses[1].gold)==130 and game.provinces.size()==108,"Ordinary Sequana start uses actual130gold and all108regions")
	var before: Dictionary=game.snapshot()
	var order:=plan_unchanged(game,1)
	check(not order.is_empty() and ["build","develop"].has(str(order.get("id",""))),"Ordinary NPC begins an actual useful regional investment without injected stocks or research")
	check(game.snapshot()==before,"Normal current-format snapshot is byte-equivalent after planning")
	var price:=cost(game,order,1)
	check(price>0 and price<=50,"Ordinary first choice leaves the real80gold reserve intact")
	check(execute(game,order,1).ok and int(game.houses[1].gold)==130-price,"The proposed order executes through the actual paid Game API")
	check(plan_unchanged(game,1).is_empty(),"Already accepted economic purchase prevents a second paid intent in the same month")

func test_humans_defeat_and_budget() -> void:
	var game=fresh()
	check(plan_unchanged(game,0).is_empty(),"Human house receives no autonomous spending")
	game.configure_human_houses([0,1])
	check(plan_unchanged(game,1).is_empty(),"A human LAN seat also receives no autonomous economy order")
	game=fresh()
	game.houses[1].gold=80 # Controlled reserve boundary, not a regular campaign.
	check(plan_unchanged(game,1).is_empty(),"NPC cannot spend the protected military reserve")
	for p in game.provinces:
		if int(p.owner)==1: p.owner=8 # Controlled defeated-house ownership fixture.
	game.houses[1].gold=1000
	check(plan_unchanged(game,1).is_empty(),"A defeated house with no actual territory cannot buy economy effects")
	check(plan_unchanged(game,-1).is_empty() and plan_unchanged(game,99).is_empty(),"Invalid house perspective cannot produce an order")

func test_normal_wessex_saves_for_sea() -> void:
	var game=fresh()
	var preparation: Dictionary=Naval.preparation(game,2)
	check(int(game.houses[2].gold)==120 and not preparation.is_empty() and int(preparation.required_gold)>120,"Ordinary Wessex really lacks the combined naval expedition money")
	check(plan_unchanged(game,2).is_empty() and int(game.houses[2].gold)==120,"Wessex saves its actual initial120gold rather than buying a civilian project before sea preparation")

func controlled_material_game():
	var game=fresh()
	game.houses[1].gold=1000 # Explicit controlled financing; ordinary budget tested above.
	check(game.set_province_focus("gallien__03","workshops",1).ok,"Controlled source is a real paid forest workshop focus")
	check(game.build("gallien__04","market",1).ok,"Controlled destination is a real paid material-demanding market")
	game.month=2 # Both fixture purchases happened in the previous month.
	return game

func test_controlled_material_chain() -> void:
	var game=controlled_material_game()
	var order:=plan_unchanged(game,1)
	check(order.get("id")=="research" and order.get("innovation")=="surveying","Actual unfed destination and chosen source justify the first4month research")
	game.houses[1].research.known=["surveying"] # Controlled completed prerequisite.
	order=plan_unchanged(game,1)
	check(order.get("id")=="research" and order.get("innovation")=="road_building","Existing surveying advances toward the useful six-month road unlock")
	game.houses[1].research.known=["surveying","road_building"]
	order=plan_unchanged(game,1)
	check(order.get("id")=="road" and [str(order.get("province","")),str(order.get("to",""))].has("gallien__03") and [str(order.get("province","")),str(order.get("to",""))].has("gallien__04"),"Unlocked road connects the actual workshop source directly to its real construction demand")
	check(cost(game,order,1)>0 and execute(game,order,1).ok,"Road intent is actually paid and accepted by the real model")
	game=controlled_material_game()
	game.province("gallien__03").economic_focus="balanced" # Controlled missing source choice.
	order=plan_unchanged(game,1)
	check(order.get("id")=="province_focus" and order.get("focus")=="workshops","A real material shortfall selects one productive source before unrelated new projects")
	if not order.is_empty():
		check(str(game.province(str(order.province)).terrain) in ["forest","hills"],"Workshop source uses an actual suitable resource terrain")
	game=controlled_material_game()
	game.houses[1].research.known=["surveying","road_building"]
	order=plan_unchanged(game,1)
	check(not (order.get("id")=="province_focus" and order.get("focus")=="workshops"),"Existing source is connected instead of turning the whole realm into workshops")

func controlled_front_game():
	var game=fresh()
	game.houses[1].gold=1000 # Controlled front/army setup, not claimed as normal-budget success.
	game.houses[1].research.known=["surveying","road_building"]
	check(game.set_province_focus("gallien__03","agriculture",1).ok,"Controlled agricultural source still pays the ordinary focus cost")
	game.roads.append({"from":"gallien__03","to":"gallien__04","builder":1,"months":0,"state":"complete","construction":{}}) # Explicit completed network fixture.
	game.houses[1].armies=[{"id":1,"province":"germanien__02","strength":900,"upkeep":3,"morale":100}]
	game.month=2
	return game

func test_controlled_frontier_chain() -> void:
	var game=controlled_front_game()
	check(int(game.supply_report(1).regions["germanien__02"].shortfall)>0,"Controlled foreign army has a measured actual supply shortfall")
	var order:=plan_unchanged(game,1)
	if order.get("innovation","")!="logistics": print("ECONOMYPLANNERTEST front research actual: "+JSON.stringify(order))
	check(order.get("id")=="research" and order.get("innovation")=="logistics","Connected real agricultural source and adjacent deficient front justify logistics research")
	game.houses[1].research.known.append("logistics")
	order=plan_unchanged(game,1)
	if order.get("key","")!="depot": print("ECONOMYPLANNERTEST front depot actual: "+JSON.stringify(order))
	check(order.get("id")=="build" and order.get("key")=="depot" and order.get("province")=="gallien__04","Depot intent chooses the actual connected own border, not the foreign army province")
	check(cost(game,order,1)>0 and execute(game,order,1).ok,"Useful depot is a paid actual Game project")
	game=controlled_front_game()
	game.houses[1].armies=[]
	order=plan_unchanged(game,1)
	check(order.get("innovation","")!="logistics" and order.get("key","")!="depot","Without real front demand NPC does not habitually buy logistics or depots")

func test_controlled_project_budget() -> void:
	var game=fresh()
	game.houses[1].gold=1000 # Explicit concurrent-work boundary fixture.
	for id in ["gallien__01","gallien__02","gallien__04"]: check(game.build(id,"market",1).ok,"Controlled concurrent project is accepted and paid")
	game.month=2
	var order:=plan_unchanged(game,1)
	check(not ["build","develop"].has(str(order.get("id",""))),"Three running regional projects prevent a fourth regional commitment")

func test_controlled_threat() -> void:
	var game=fresh()
	game.houses[1].gold=1000 # Controlled imminent land-border threat.
	game.houses[0].armies=[{"id":1,"province":"germanien__02","strength":900,"upkeep":3,"morale":100}]
	var order:=plan_unchanged(game,1)
	check(order.get("id")=="build" and order.get("key")=="walls" and ["gallien__04","gallien__05"].has(str(order.get("province",""))),"Actual enemy field army at a land border makes useful frontier walls outrank peaceful investment")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("ECONOMYPLANNERTEST FAIL: "+message)

func finish() -> void:
	print("ECONOMYPLANNERTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
