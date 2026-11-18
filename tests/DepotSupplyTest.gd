extends Node
## Pure depot extension over real SupplyNetwork balances; no Main or renderer.
const Supply = preload("res://scripts/SupplyNetwork.gd")
var checks := 0
var failures := 0
var depot

func _ready() -> void:
	if FileAccess.file_exists("res://scripts/DepotSupply.gd"):
		depot = load("res://scripts/DepotSupply.gd")
	test_frontier_import()
	if depot != null:
		test_no_depot_or_surplus()
		test_source_and_depot_limits()
		test_road_and_control_barriers()
		test_blocker_value_types()
		test_land_adjacency_and_no_relay()
		test_multiple_depots_and_armies()
		test_weighted_capacity()
		test_determinism_and_immutability()
		test_conservation()
	finish()

func province(id: String, owner: int = 0, site: int = 0, share: float = 1.0) -> Dictionary:
	return {"id":id,"owner":owner,"economic_share":share,"logistics_sites":{"depot":site},"siege":0,"siege_owner":-1}

func army(id: int, location: String, strength: int) -> Dictionary:
	return {"id":id,"province":location,"strength":strength,"morale":100}

func road(a: String, b: String, state: String = "complete") -> Dictionary:
	return {"from":a,"to":b,"state":state}

func fixture() -> Dictionary:
	var provinces := [province("source"),province("home"),province("depot",0,1),province("front",1),province("far",1)]
	var roads := [road("source","home"),road("home","depot")]
	var armies := [army(1,"home",200),army(2,"front",500)]
	var report := Supply.calculate(provinces,roads,armies,0,{"source":1000,"home":100,"front":100},{"source":500})
	return {"provinces":provinces,"roads":roads,"armies":armies,"adjacency":{"depot":["front"],"front":["depot","far"],"far":["front"]},"report":report}

func apply_fixture(f: Dictionary, blocked: Dictionary = {}) -> Dictionary:
	return f.report.duplicate(true) if depot == null else depot.apply(f.report,f.provinces,f.adjacency,f.armies,0,blocked)

func balance(report: Dictionary, id: String) -> Dictionary:
	return report.get("regions",{}).get(id,{})

func recompute(f: Dictionary, bonus: int = 500) -> void:
	f.report = Supply.calculate(f.provinces,f.roads,f.armies,0,{"source":1000,"home":100,"front":100,"far":0},{"source":bonus})

func test_frontier_import() -> void:
	var f := fixture()
	check(balance(f.report,"source").get("export") == 100 and balance(f.report,"front").get("shortfall") == 400,"Existing own allocation leaves 400 actual source surplus and a 400-man frontier deficit")
	var result := apply_fixture(f)
	check(balance(result,"front").get("import") == 300 and balance(result,"front").get("shortfall") == 100,"Completed adjacent depot supplies 300 actual men to the existing frontier deficit")
	if depot == null: return
	check(balance(result,"source").get("export") == 400,"Frontier delivery charges the actual source after its 100-man internal export")
	check(result.frontier_deliveries == [{"from":"source","depot":"depot","to":"front","amount":300}],"Delivery names the real source, depot, foreign recipient and amount")
	var network: Dictionary = result.networks[0]
	check(network.members == ["depot","home","source"] and network.demand == 200 and network["import"] == 100 and network.shortfall == 0,"Foreign receiver never joins own network or changes its internal demand/import accounting")
	check(network["export"] == 400 and network.frontier_export == 300,"Network export includes exact frontier source charges, with a separate frontier subset")
	check(result.roads == f.report.roads,"Depot extension preserves existing road statuses")

func test_no_depot_or_surplus() -> void:
	var f := fixture()
	f.provinces[2].logistics_sites.depot = 0
	var result := apply_fixture(f)
	check(balance(result,"front").shortfall == 400 and result.frontier_deliveries.is_empty(),"No completed depot means no frontier import")
	f = fixture()
	recompute(f,100)
	result = apply_fixture(f)
	check(balance(result,"home").shortfall == 0 and balance(result,"front").shortfall == 400,"Own network demand consumes surplus first; depot creates no food")
	f = fixture()
	f.armies = [army(1,"home",200)]
	recompute(f)
	result = apply_fixture(f)
	check(not result.regions.has("front") and result.frontier_deliveries.is_empty(),"Foreign land without an actual own army cannot receive depot supply")

func test_source_and_depot_limits() -> void:
	var f := fixture()
	recompute(f,220)
	var result := apply_fixture(f)
	check(balance(result,"front")["import"] == 120 and balance(result,"source")["export"] == 220,"Frontier import is capped by actual surplus remaining after own allocation")
	f = fixture()
	f.armies[1].strength = 210
	recompute(f)
	result = apply_fixture(f)
	check(balance(result,"front")["import"] == 110 and balance(result,"front").shortfall == 0,"Depot never supplies more than the existing foreign deficit")
	f = fixture()
	f.report.regions.source["export"] = 500
	result = apply_fixture(f)
	check(balance(result,"front").shortfall == 400 and result.frontier_deliveries.is_empty(),"A fully allocated source remainder cannot be reused")

func test_road_and_control_barriers() -> void:
	for barrier in ["unfinished","severed","foreign_middle","siege_source","siege_depot","siege_middle","blocked_source","blocked_depot","blocked_middle","blocked_reason_middle","blocked_front","hostile_front_siege"]:
		var f := fixture()
		var blocked := {}
		match barrier:
			"unfinished": f.roads[1].state = "building"
			"severed": f.roads.pop_back()
			"foreign_middle": f.provinces[1].owner = 1
			"siege_source": f.provinces[0].siege = 10; f.provinces[0].siege_owner = 1
			"siege_depot": f.provinces[2].siege = 10; f.provinces[2].siege_owner = 1
			"siege_middle": f.provinces[1].siege = 10; f.provinces[1].siege_owner = 1
			"blocked_source": blocked.source = true
			"blocked_depot": blocked.depot = true
			"blocked_middle": blocked.home = true
			"blocked_reason_middle": blocked.home = "Fremdes Feldheer vor Ort: Versorgung unterbrochen."
			"blocked_front": blocked.front = true
			"hostile_front_siege": f.provinces[3].siege = 10; f.provinces[3].siege_owner = 2
		recompute(f)
		var result := apply_fixture(f,blocked)
		check(balance(result,"front").shortfall == 400 and result.frontier_deliveries.is_empty(),"Actual barrier blocks the depot supply path: "+barrier)
	var f := fixture()
	f.provinces[3].siege = 10
	f.provinces[3].siege_owner = 0
	check(balance(apply_fixture(f),"front")["import"] == 300,"Own siege at the foreign receiver does not falsely block its own supplying army")
	f = fixture()
	f.provinces[2].owner = 1
	recompute(f)
	check(balance(apply_fixture(f),"front")["import"] == 0,"A captured foreign depot does not supply the previous owner")

func test_land_adjacency_and_no_relay() -> void:
	var f := fixture()
	f.adjacency = {}
	check(balance(apply_fixture(f),"front")["import"] == 0,"No actual land adjacency means no frontier delivery")
	f.adjacency = {"depot":[],"front":[],"sea_routes":{"depot":["front"]}}
	check(balance(apply_fixture(f),"front")["import"] == 0,"A sea-only relation never becomes a land connection")
	f = fixture()
	f.armies.append(army(3,"far",100))
	recompute(f)
	var result := apply_fixture(f)
	check(balance(result,"front")["import"] == 300 and balance(result,"far")["import"] == 0,"Foreign recipient cannot relay supply to its own foreign neighbor")
	f = fixture()
	f.provinces[3].owner = 0
	recompute(f)
	check(balance(apply_fixture(f),"front")["import"] == 0,"Depot frontier stage cannot bypass missing own roads to an own recipient")

func test_blocker_value_types() -> void:
	for row in [[false,300],["",300],[true,0],["Enemy field army",0],[&"Enemy field army",0]]:
		var f:=fixture()
		check(balance(apply_fixture(f,{"home":row[0]}),"front")["import"]==int(row[1]),"Explicit blocker value keeps false/empty free and actual reasons blocked: %s" % str(row[0]))

func test_multiple_depots_and_armies() -> void:
	var f := fixture()
	f.provinces.append(province("depot2",0,1))
	f.roads.append(road("home","depot2"))
	f.adjacency.depot2 = ["front","far"]
	f.armies = [army(1,"home",200),army(2,"front",200),army(3,"front",200),army(4,"far",300)]
	recompute(f)
	var result := apply_fixture(f)
	check(balance(result,"front")["import"] == 300 and balance(result,"front").shortfall == 0,"Multiple co-located armies share one recipient deficit")
	check(balance(result,"far")["import"] == 100 and balance(result,"far").shortfall == 200,"Two depots share the one remaining source budget without multiplying it")
	check(balance(result,"source")["export"] == 500 and result.networks[0].frontier_export == 400,"Combined depot exports conserve the finite source across recipients")
	f = fixture()
	f.armies = [army(1,"home",200),army(2,"front",500),army(3,"far",500)]
	f.adjacency.depot = ["far","front"]
	recompute(f)
	result = apply_fixture(f)
	check(balance(result,"far")["import"] == 300 and balance(result,"front")["import"] == 0,"One depot shares its 300-man cap across targets in stable region-ID order")

func test_weighted_capacity() -> void:
	for row in [[0.5,150],[0.333333,99],[0.0006303,0],[0.0,0],[2.0,400]]:
		var f := fixture()
		f.provinces[2].economic_share = float(row[0])
		var result := apply_fixture(f)
		check(balance(result,"front")["import"] == int(row[1]),"Depot throughput floors its weighted 300-man cap for share %s" % str(row[0]))
	var f := fixture()
	f.provinces[2].erase("economic_share")
	check(balance(apply_fixture(f),"front")["import"] == 300,"Legacy missing weight retains weight one")

func test_determinism_and_immutability() -> void:
	var f := fixture()
	var before: Dictionary = f.duplicate(true)
	var blocked := {"unused":true}
	var blocked_before := blocked.duplicate(true)
	var first := apply_fixture(f,blocked)
	check(f == before and blocked == blocked_before,"Report, provinces, adjacency, armies and blocker inputs remain untouched")
	first.regions.front["import"] = -1
	first.networks[0].members.append("mutated")
	first.roads[0].active = false
	check(f == before,"Returned nested report data is a deep copy")
	var expected := apply_fixture(f)
	f.provinces.reverse()
	f.armies.reverse()
	f.roads.reverse()
	f.adjacency.front.reverse()
	recompute(f)
	check(apply_fixture(f) == expected,"Input array order does not change delivery ordering or quantities")
	var empty: Dictionary = depot.apply(Supply.calculate([],[],[],0,{},{}),[],{},[],0)
	check(empty == {"regions":{},"roads":[],"networks":[],"frontier_deliveries":[]},"Empty world supplies no phantom food or receivers")

func test_conservation() -> void:
	for available in [0,99,100,101,249,400,500,999]:
		var f := fixture()
		recompute(f,available)
		var result := apply_fixture(f)
		var exports := 0
		var imports := 0
		var valid := true
		for item in result.regions.values():
			exports += int(item["export"])
			imports += int(item["import"])
			valid = valid and int(item["export"]) <= int(item.export_available) and int(item["export"]) >= 0 and int(item.shortfall) >= 0
			valid = valid and int(item["import"]) + int(item.shortfall) == maxi(0,int(item.demand)-int(item.local_capacity))
		check(valid and exports == imports and exports <= available,"Every real source unit is consumed at most once with surplus %d" % available)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("DEPOTSUPPLYTEST FAIL: "+message)

func finish() -> void:
	print("DEPOTSUPPLYTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
