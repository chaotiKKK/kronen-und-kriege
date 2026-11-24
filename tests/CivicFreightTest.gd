extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Transport = preload("res://scripts/MaterialTransport.gd")
const ProductionReport = preload("res://scripts/ProductionNetworkReport.gd")
const CivicReport = preload("res://scripts/CivicProvisionReport.gd")
const Food = preload("res://scripts/CivicProvision.gd")
const Origin := "germanien__03"
const Target := "germanien__05"
var checks := 0
var failures := 0

func _ready() -> void:
	var control = fixture(false)
	var connected = fixture(true)
	seed(14159)
	control.advance_month()
	seed(14159)
	connected.advance_month()
	var month: Dictionary = connected.provision_report(0)
	var row: Dictionary = month.regions[Target]
	if not check(int(row.get("import_u",0))>0,"A completed own road delivers real food to the workshop district this month"):
		finish()
		return
	var source: Dictionary=month.regions[Origin]
	var delivered := int(row.import_u)
	check(source.export_u==delivered and int(source.before_u)-delivered-int(source.requested_u)>=4*Food.need_u(connected.province(Origin)),"Freight spends only existing supply above four months and the donor's own ration")
	check(month.flows.size()==1 and month.flows[0].path==[Origin,Target] and month.flows[0].amount_u==delivered,"Monthly report shows the route and actual dispatched weight")
	var baseline: Dictionary=control.provision_report(0).regions[Target]
	check(row.farm_work_u<baseline.farm_work_u and row.industry_labor_u>baseline.industry_labor_u and row.consumed_u==baseline.consumed_u,"Real food is used before local planning and frees industry without ration loss")
	var rail: Dictionary=connected._last_production.edges[0]
	check(int(rail.used_u)+delivered<=int(rail.capacity_u),"Both cargoes fit in the same road space")
	var state: Dictionary=connected.snapshot()
	check(not state.is_empty() and Save.validate(state).is_empty(),"Entire end-of-month world remains a valid save")
	var copy = Game.new(Data,0)
	check(copy.restore(JSON.parse_string(JSON.stringify(state))) and Save.state_equal(copy.snapshot(),state),"Historical food shipments persist exactly across save/load")
	var report_state:=state.duplicate()
	report_state["production_report"]=connected._last_production
	check(CivicReport.validate(state.provisioning_report,report_state).ok and not ProductionReport.pack(connected._last_production,state).is_empty(),"Both actual reports agree at the network boundary")
	var forged: Dictionary=state.provisioning_report.duplicate(true)
	forged.flows[0].path=[Origin,Target,Target]
	check(not CivicReport.validate(forged,state).ok,"Unknown or cyclic freight path cannot be loaded")
	var overbooked: Dictionary=connected._last_production.duplicate(true)
	overbooked.edges[0].used_u=overbooked.edges[0].capacity_u
	report_state["production_report"]=overbooked
	check(not CivicReport.validate(state.provisioning_report,report_state).ok,"Material usage and food usage are checked together, even when individually under capacity")
	var taken=Game.new(Data,0)
	check(taken.restore(state),"Original freight month can be loaded before a territory change")
	taken._capture_province(Target,1)
	var conquered: Dictionary=taken.snapshot()
	check(not conquered.is_empty() and Save.validate(conquered).is_empty(),"Later conquest preserves the true historical ledger and ownership for past freight")
	check(taken.provision_report(0).get("flows",[]).is_empty(),"Previous owner no longer sees a cargo route to this lost province on the active map")
	var blocked=fixture(true)
	blocked.province(Target).siege=4
	blocked.province(Target).siege_owner=1
	blocked.advance_month()
	check(blocked.provision_report(0).get("flows",[]).is_empty(),"A closed front does not receive freight")
	var work=fixture(true)
	work.roads[0].state="building"
	work.roads[0].months=2
	work.advance_month()
	check(work.provision_report(0).get("flows",[]).is_empty(),"An unfinished road does not advance a shipment")
	test_shared_capacity()
	test_regular_campaign()
	finish()

func test_shared_capacity() -> void:
	var provinces := [
		{"id":"a","owner":0,"economic_share":1.0,"production":{"materials_u":6000000}},
		{"id":"b","owner":0,"economic_share":1.0,"production":{"materials_u":0}},
	]
	var roads := [{"from":"a","to":"b","state":"complete"}]
	var requests := [{"province":"b","house":0,"amount_u":4500000,"priority":1,"project_id":1}]
	var offers := {"a":5500000}
	var reserved := {Transport.edge_key("b","a"):3000000}
	var report := Transport.plan(provinces,roads,requests,offers,11,{}, {}, reserved)
	check(report.edges[0].capacity_u==4000000 and report.edges[0].used_u==1000000 and report.flows[0].amount_u==1000000,"Three charged units in the opposite direction leave exactly one unit for materials")
	check(report.deltas=={"a":-1000000,"b":1000000},"The allocator does not charge surplus goods or capacity twice")
	provinces[1].owner=1
	check(Transport.plan(provinces,roads,requests,offers,11,{}, {}, reserved).flows.is_empty(),"Different provincial owners prevent even residual own freight")

func test_regular_campaign() -> void:
	seed(20261124)
	var game=Game.new(Data,0)
	check(game.set_province_focus(Origin,"agriculture").ok and game.set_province_focus(Target,"workshops").ok,"Ordinary start pays both specializations out of normal treasury")
	check(game.start_research("surveying").ok,"Paid surveying from the ordinary start")
	var paid_road:=false
	for turn in 84:
		var research: Dictionary=game.house().research
		if not research.known.has("road_building") and research.known.has("surveying") and str(research.active).is_empty():
			game.start_research("road_building")
		if research.known.has("road_building") and not paid_road:
			paid_road=game.build_road(Origin,Target).ok
		game.advance_month()
		if game.pending_event!=null:
			for i in range(game.pending_event.options.size()-1,-1,-1):
				if game.apply_event(i).ok: break
			if game.pending_event!=null: game.decline_event()
		var report: Dictionary=game.provision_report()
		for flow in report.get("flows",[]):
			if flow.from!=Origin or flow.to!=Target: continue
			check(paid_road and int(flow.amount_u)>0 and int(report.regions[Target].farm_work_u)==0,"Real planned and financed road carries life-maintaining food into the workshop district")
			var path:=OS.get_environment("BQ_FREIGHT_CAMPAIGN_PROOF")
			if not path.is_empty():
				var save:=FileAccess.open(path,FileAccess.WRITE)
				save.store_string(JSON.stringify(game.snapshot()))
				save.close()
			print("FOOD_CHAIN month=",game.calendar_index()," shipment=",JSON.stringify(flow)," receiver=",JSON.stringify(report.regions[Target]))
			return
	check(false,"Ordinary campaign completes actual built road and delivers earned food within 84 months")

func fixture(road: bool):
	var world = Game.new(Data,0)
	var source: Dictionary=world.province(Origin)
	source.economic_focus="agriculture"
	source.provisioning.food_u=6*Food.need_u(source)
	var into: Dictionary=world.province(Target)
	into.economic_focus="workshops"
	into.provisioning.food_u=3*Food.need_u(into)
	if road:
		world.roads.append({"from":Origin,"to":Target,"state":"complete","months":0,"builder":0,"construction":{}})
	return world

func check(ok:bool,message:String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("CIVICFREIGHTTEST FAIL: "+message)
	return ok

func finish() -> void:
	print("CIVICFREIGHTTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
