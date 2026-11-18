extends Node
## Catches invented stock, unlimited shared roads, relay imports and recipient starvation.
var checks:=0
var failures:=0
var transport

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/MaterialTransport.gd"):
		check(false,"Real material planner must deliver conserved stocks over controlled roads")
		finish()
		return
	transport=load("res://scripts/MaterialTransport.gd")
	if transport==null:
		check(false,"Material transport module loads")
		finish()
		return
	test_actual_multiedge_delivery()
	test_blocked_routes()
	test_typed_block_reasons()
	test_capacity_and_no_relay()
	test_offers_reserve_and_stock_bounds()
	test_priority_and_rotation()
	test_reordering_and_free_capacity()
	finish()

func region(id: String, stock: int=0, owner: int=0, weight: float=1.0) -> Dictionary:
	return {"id":id,"owner":owner,"economic_share":weight,"siege":0,"siege_owner":-1,"production":{"materials_u":stock,"rate_carry":0}}

func road(a: String,b: String,state: String="complete") -> Dictionary:
	return {"from":a,"to":b,"state":state}

func demand(id: String, amount: int, priority: int=0, project_id: int=1, house: int=0) -> Dictionary:
	return {"province":id,"house":house,"amount_u":amount,"priority":priority,"project_id":project_id}

func delta(result: Dictionary,id: String) -> int:
	return int(result.get("deltas",{}).get(id,0))

func test_actual_multiedge_delivery() -> void:
	var p: Array=[region("a",3000000),region("b"),region("c")]
	var r: Array=[road("a","b"),road("b","c")]
	var result: Dictionary=transport.plan(p,r,[demand("c",3000000)],{"a":3000000},0)
	check(delta(result,"a")==-3000000 and delta(result,"b")==0 and delta(result,"c")==3000000,"Actual source stock crosses two controlled completed roads exactly once")
	check(result.flows.size()==1 and result.flows[0].path==["a","b","c"] and result.flows[0].amount_u==3000000,"Delivery reports the actual finite full route")
	check(result.edges.size()==2 and result.edges[0].used_u==3000000 and result.edges[1].used_u==3000000,"Every route edge consumes the actual delivered capacity")

func test_blocked_routes() -> void:
	var p: Array=[region("a",4000000),region("b"),region("c")]
	var r: Array=[road("a","b"),road("b","c")]
	for mode in ["foreign","siege","blocked","building","missing"]:
		var provinces:=p.duplicate(true)
		var roads:=r.duplicate(true)
		var blocked: Dictionary={}
		match mode:
			"foreign": provinces[1].owner=1
			"siege": provinces[1].siege=1; provinces[1].siege_owner=1
			"blocked": blocked["b"]=true
			"building": roads[1].state="building"
			"missing": roads.remove_at(1)
		var result: Dictionary=transport.plan(provinces,roads,[demand("c",4000000)],{"a":4000000},0,blocked)
		check(result.flows.is_empty() and delta(result,"a")==0 and delta(result,"c")==0,"No stock teleports through "+mode+" intermediate route")
	check(transport.plan(p,r,[demand("c",4000000,0,1,1)],{"a":4000000},0).flows.is_empty(),"Demanding house must own every route and receiver")

func test_capacity_and_no_relay() -> void:
	var p: Array=[region("a",3000000),region("b",3000000)]
	var result: Dictionary=transport.plan(p,[road("a","b"),road("b","a"),road("a","b","building")],[demand("a",3000000,0,1),demand("b",3000000,0,2)],{"a":3000000,"b":3000000},0)
	var total:=0
	for flow in result.flows: total+=int(flow.amount_u)
	check(result.edges.size()==1 and total==4000000 and result.edges[0].capacity_u==4000000 and result.edges[0].used_u==4000000,"Opposite directions and duplicate edges share one finite capacity")
	p=[region("a",4000000),region("b"),region("c")]
	result=transport.plan(p,[road("a","b"),road("b","c")],[demand("b",4000000,1,1),demand("c",4000000,0,2)],{"a":4000000,"b":4000000},0)
	check(delta(result,"b")==4000000 and delta(result,"c")==0,"Imported materials cannot become a new offer during the same month")

func test_typed_block_reasons() -> void:
	var p: Array=[region("a",1000000),region("b"),region("c")]
	var r: Array=[road("a","b"),road("b","c")]
	for value in ["Feindliche Belagerung: Produktion und Bau ruhen.",true,"",false]:
		var expected_blocked: bool=(value is String and not str(value).is_empty()) or (value is bool and value)
		var result: Dictionary=transport.plan(p,r,[demand("c",1000000)],{"a":1000000},0,{"b":value})
		check(delta(result,"c")==0 if expected_blocked else delta(result,"c")==1000000,"Actual Game reason/bool blocked map handles "+JSON.stringify(value)+" without a String-to-bool constructor")

func test_offers_reserve_and_stock_bounds() -> void:
	var p: Array=[region("a",8000000),region("b")]
	var r: Array=[road("a","b")]
	var result: Dictionary=transport.plan(p,r,[demand("b",4000000)],{"a":1000000},0)
	check(delta(result,"a")==-1000000 and delta(result,"b")==1000000,"Provided eligible offer preserves the source reserve calculated by Game")
	result=transport.plan(p,r,[demand("b",4000000)],{"a":0},0)
	check(result.flows.is_empty(),"Reserved real stock is not automatically exported")
	p[0].production.materials_u=900000
	result=transport.plan(p,r,[demand("b",4000000)],{"a":9000000},0)
	check(delta(result,"a")==-900000 and delta(result,"b")==900000,"Oversized offer is bounded by actual finite source stock")

func test_priority_and_rotation() -> void:
	var p: Array=[region("a",1),region("b"),region("c")]
	var r: Array=[road("a","b"),road("a","c")]
	var demands: Array=[demand("b",1,0,1),demand("c",1,0,2)]
	var zero: Dictionary=transport.plan(p,r,demands,{"a":1},0)
	var one: Dictionary=transport.plan(p,r,demands,{"a":1},1)
	check(delta(zero,"b")==1 and delta(zero,"c")==0 and delta(one,"b")==0 and delta(one,"c")==1,"Same-priority scarcity rotates recipients over successive months")
	demands[1].priority=1
	check(delta(transport.plan(p,r,demands,{"a":1},0),"c")==1,"Urgent actual project receives stock before a normal one")

func test_reordering_and_free_capacity() -> void:
	var p: Array=[region("a",5000000),region("b",11999999),region("c")]
	var r: Array=[road("b","c"),road("a","c"),road("a","b")]
	var demands: Array=[demand("b",4000000),demand("c",4000000,0,2)]
	var offers: Dictionary={"a":5000000}
	var before:=JSON.stringify([p,r,demands,offers])
	var result: Dictionary=transport.plan(p,r,demands,offers,7)
	check(JSON.stringify([p,r,demands,offers])==before,"Transport planner does not mutate real caller stocks, roads, offers or demands")
	check(delta(result,"b")<=1,"Receiver cannot import beyond its actual free warehouse space")
	var sum:=0
	for value in result.deltas.values(): sum+=int(value)
	check(sum==0,"Every reported import is balanced by a real source export")
	p.reverse(); r.reverse(); demands.reverse()
	check(JSON.stringify(result)==JSON.stringify(transport.plan(p,r,demands,offers,7)),"Province, road and demand ordering cannot change routes or material results")
	for edge in result.edges: check(edge.used_u<=edge.capacity_u,"No edge usage exceeds actual finite capacity")
	var empty: Dictionary=transport.plan([],[],[],{},0)
	check(empty.deltas.is_empty() and empty.flows.is_empty() and empty.edges.is_empty(),"Empty world cannot create stock or graph entries")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRANSPORTTEST FAIL: "+message)

func finish() -> void:
	print("MATERIALTRANSPORTTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
