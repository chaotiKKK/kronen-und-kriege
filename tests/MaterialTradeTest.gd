extends Node
## Real pure plans: atomic lots, shared original budgets, dates and hostile input.
const UNIT := 1000000
var trade
var checks := 0
var failures := 0

func _ready() -> void:
	if not check(FileAccess.file_exists("res://scripts/MaterialTrade.gd"),"Real trade planner must atomically move an existing full lot and its agreed payment"):
		finish(); return
	trade=load("res://scripts/MaterialTrade.gd")
	if not check(trade!=null,"Pure trade module loads without parse errors"):
		finish(); return
	test_atomic_delivery()
	test_no_partial_or_invented_budget()
	test_quote()
	test_dates_and_completion()
	test_shared_budgets_and_rotation()
	test_no_same_plan_recycling()
	test_ownership_and_hostility()
	test_contract_specific_pause()
	test_shared_npc_need_budget()
	test_validation()
	test_global_capacity_and_ordering()
	test_defensive_planning_and_purity()
	finish()

func region(id: String, stock: int=0, owner: int=0, share: float=1.0) -> Dictionary:
	return {"id":id,"owner":owner,"economic_share":share,"siege":0,"siege_owner":-1,"production":{"materials_u":stock,"rate_carry":0}}

func agreement(id: int=1, source: String="a", target: String="b", seller: int=0, buyer: int=1) -> Dictionary:
	return {"id":id,"seller":seller,"buyer":buyer,"from":source,"to":target,"proposer":seller,
		"lot_u":UNIT,"lot_gold":2,"created_month":0,"expires_month":6,"accepted_month":0,
		"last_delivery_month":-1,"delivered_lots":0,"status":"active"}

func graph() -> Dictionary:
	return {"a":["b","c"],"b":["a","c"],"c":["a","b"]}

func sample_world() -> Array:
	return [region("a",3*UNIT),region("b",0,1),region("c",0,2)]

func sd(result: Dictionary, id: String) -> int:
	return int(result.get("stock_deltas",{}).get(id,0))

func gd(result: Dictionary, id: String) -> int:
	return int(result.get("gold_deltas",{}).get(id,0))

func plan(p: Array, contracts: Array, offers: Dictionary={"a":UNIT}, funds: Dictionary={"0":0,"1":4,"2":4}, month: int=1, blocked: Dictionary={}, hostile: Dictionary={}, adjacency: Dictionary={}) -> Dictionary:
	return trade.plan(p,contracts,offers,funds,month,blocked,hostile,graph() if adjacency.is_empty() else adjacency)

func test_atomic_delivery() -> void:
	var result: Dictionary=plan(sample_world(),[agreement()])
	check(sd(result,"a")==-UNIT and sd(result,"b")==UNIT and gd(result,"0")==2 and gd(result,"1")==-2,"One original full lot and exactly two gold move atomically after acceptance")
	check(result.deliveries==[{"trade_id":1,"seller":0,"buyer":1,"from":"a","to":"b","amount_u":UNIT,"gold":2}],"Delivery receipt identifies the actual contract, endpoints, full quantity and payment")
	if check(result.contracts.size()==1,"A first delivery retains its unfinished contract"):
		check(result.contracts[0].delivered_lots==1 and result.contracts[0].last_delivery_month==1,"Contract records exactly one delivery in the actual month")
	check(not str(result.statuses.get("1","")).is_empty(),"Each actual outcome has a German status reason keyed by string contract ID")

func test_no_partial_or_invented_budget() -> void:
	for mode in ["offer","stock","gold","room","reserved"]:
		var p:=sample_world()
		var offers: Dictionary={"a":UNIT}
		var funds: Dictionary={"0":0,"1":4,"2":4}
		match mode:
			"offer": offers.a=UNIT-1
			"stock": p[0].production.materials_u=UNIT-1; offers.a=10*UNIT
			"gold": funds["1"]=1
			"room": p[1].production.materials_u=11*UNIT+1
			"reserved": offers.a=0
		var result: Dictionary=plan(p,[agreement()],offers,funds)
		check(result.deliveries.is_empty() and result.stock_deltas.is_empty() and result.gold_deltas.is_empty(),"No partial or unpaid booking when blocked by "+mode)
		check(result.contracts==[agreement()],"A temporarily unaffordable full lot remains unchanged: "+mode)
	var oversized: Dictionary=plan(sample_world(),[agreement()],{"a":100*UNIT})
	check(sd(oversized,"a")==-UNIT,"An oversized offer never creates more than an existing complete lot")

func test_quote() -> void:
	check(trade.quote(region("a"),region("b",0,1))=={"lot_u":UNIT,"lot_gold":2},"Equal unit regions quote one million material quanta for two gold")
	check(trade.quote(region("a",0,0,0.25),region("b",0,1,0.75))=={"lot_u":375000,"lot_gold":1},"Unequal regions use their harmonic edge weight and round price upward")
	check(trade.quote(region("a",0,0,0.0),region("b",0,1,0.0))=={"lot_u":1,"lot_gold":1},"Smallest admitted weight still quotes one quantum and one gold")
	check(trade.quote(region("a",0,0,15625.0),region("b",0,1,15625.0))=={"lot_u":15625000000,"lot_gold":31250},"Maximum admitted weights quote without overflow")
	for invalid in [true,NAN,INF,-1.0,"1",15625.1]:
		var p:=region("a"); p.economic_share=invalid
		check(trade.quote(p,region("b",0,1)).is_empty(),"Malformed or out-of-range weight has no invented quotation: "+str(invalid))

func test_dates_and_completion() -> void:
	var offered:=agreement(); offered.status="offered"; offered.accepted_month=-1
	var result: Dictionary=plan(sample_world(),[offered])
	check(result.deliveries.is_empty() and result.contracts==[offered],"An unaccepted offer never delivers")
	result=plan(sample_world(),[agreement()],{"a":UNIT},{"0":0,"1":4},0)
	check(result.deliveries.is_empty() and result.contracts==[agreement()],"The acceptance month cannot deliver")
	var current:=agreement(); current.delivered_lots=1; current.last_delivery_month=1
	result=plan(sample_world(),[current])
	check(result.deliveries.is_empty() and result.contracts==[current],"Repeated planning in one month cannot deliver twice")
	current.delivered_lots=2; current.last_delivery_month=2
	result=plan(sample_world(),[current],{"a":UNIT},{"0":0,"1":4},6)
	check(result.deliveries.size()==1 and result.contracts.is_empty(),"Third full delivery removes the contract, including its expiry month")
	result=plan(sample_world(),[agreement()],{"a":UNIT},{"0":0,"1":4},7)
	check(result.deliveries.is_empty() and result.contracts.is_empty() and not str(result.statuses.get("1","")).is_empty(),"After inclusive expiry the contract closes without booking")

func test_shared_budgets_and_rotation() -> void:
	var contracts: Array=[agreement(1,"a","b",0,1),agreement(2,"a","c",0,2)]
	var first: Dictionary=plan(sample_world(),contracts,{"a":UNIT},{"0":0,"1":4,"2":4},2)
	var second: Dictionary=plan(sample_world(),contracts,{"a":UNIT},{"0":0,"1":4,"2":4},3)
	check(sd(first,"b")==UNIT and sd(first,"c")==0 and sd(second,"b")==0 and sd(second,"c")==UNIT,"Scarce original stock rotates by month and sorted contract ID")
	var p: Array=[region("a",UNIT),region("b",11*UNIT,1),region("c",UNIT,2)]
	contracts=[agreement(1,"a","b",0,1),agreement(2,"c","b",2,1)]
	var result: Dictionary=plan(p,contracts,{"a":UNIT,"c":UNIT},{"0":0,"1":20,"2":0},2)
	check(sd(result,"b")==UNIT and result.deliveries.size()==1,"Two sellers share only the buyer's original free warehouse room")
	p[1].production.materials_u=0
	result=plan(p,contracts,{"a":UNIT,"c":UNIT},{"0":0,"1":3,"2":0},2)
	check(gd(result,"1")==-2 and result.deliveries.size()==1,"Two sellers share one original buyer budget instead of overdrawing it")

func test_no_same_plan_recycling() -> void:
	var contracts: Array=[agreement(1,"a","b",0,1),agreement(2,"b","c",1,2),agreement(3,"c","a",2,0)]
	var p: Array=[region("a",UNIT),region("b",0,1),region("c",UNIT,2)]
	var result: Dictionary=plan(p,contracts,{"a":UNIT,"b":UNIT,"c":UNIT},{"0":0,"1":2,"2":2},3)
	check(result.deliveries.size()==1 and sd(result,"a")==-UNIT and sd(result,"b")==UNIT and sd(result,"c")==0,"A valid three-house ring neither re-exports incoming stock nor spends new sale proceeds")
	p=[region("a",12*UNIT),region("b",UNIT,1),region("c",0,2)]
	result=plan(p,[agreement(1,"a","c",0,2),agreement(2,"b","a",1,0)],{"a":UNIT,"b":UNIT},{"0":2,"1":0,"2":2},2)
	check(result.deliveries.size()==1 and sd(result,"a")==-UNIT and sd(result,"c")==UNIT,"Outgoing stock does not create new import room within the same plan")

func test_ownership_and_hostility() -> void:
	for mode in ["owner","source_siege","target_siege","block","hostile","disconnected"]:
		var p:=sample_world(); var blocked: Dictionary={}; var hostile: Dictionary={}; var adjacency:=graph()
		match mode:
			"owner": p[0].owner=2
			"source_siege": p[0].siege=1; p[0].siege_owner=2
			"target_siege": p[1].siege=1; p[1].siege_owner=0
			"block": blocked.a="Feindliches Feldheer."
			"hostile": hostile["0|1"]=true
			"disconnected": adjacency={"a":[],"b":[],"c":[]}
		var result: Dictionary=plan(p,[agreement()],{"a":UNIT},{"0":0,"1":4,"2":4},1,blocked,hostile,adjacency)
		check(result.deliveries.is_empty() and result.stock_deltas.is_empty() and result.gold_deltas.is_empty(),"No transfer through "+mode)
		check(not str(result.statuses.get("1","")).is_empty(),"Blocked outcome explains its reason: "+mode)
		if mode=="owner": check(result.contracts.is_empty(),"Ownership change closes the original agreement instead of redirecting goods")
		elif mode!="disconnected": check(result.contracts==[agreement()],"Military interference pauses the existing contract without rewriting its parties")
	for clear in [false,""]:
		check(plan(sample_world(),[agreement()],{"a":UNIT},{"0":0,"1":4},1,{"a":clear},{"0|1":clear}).deliveries.size()==1,"False/empty hostility is not an actual war or blockade")

func test_validation() -> void:
	var p:=sample_world(); var houses: Array=[{},{},{}]
	check(trade.validate([agreement()],1,p,houses,graph(),1).is_empty(),"A complete historical contract is valid")
	var raw: Dictionary=JSON.parse_string(JSON.stringify(agreement()))
	for key in ["id","seller","buyer","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots"]: raw[key]=float(raw[key])
	check(trade.validate([raw],1.0,p,houses,graph(),1).is_empty(),"Finite whole JSON floats are admitted before canonical integer conversion")
	p[0].owner=2
	check(trade.validate([agreement()],1,p,houses,graph(),7).is_empty(),"Pure historical validation accepts expired and now differently owned endpoints; planning closes them")
	p=sample_world()
	for invalid in [true,1.25,NAN,INF,-1,1000000001]:
		check(not trade.validate([],invalid,p,houses,graph(),1).is_empty(),"Malformed serial is rejected before numeric coercion: "+str(invalid))
	for invalid in [null,{},true,"contracts"]:
		check(not trade.validate(invalid,1,p,houses,graph(),1).is_empty(),"Contract container must really be an array")
	var changes: Array=[
		["id",0],["id",2],["id",true],["id",1.5],["id",NAN],
		["seller",1],["seller",3],["buyer",-1],["proposer",2],
		["from","b"],["to","missing"],["lot_u",UNIT+1],["lot_gold",1],
		["created_month",2],["created_month",-1],["expires_month",5],
		["accepted_month",2],["last_delivery_month",0],["delivered_lots",3],
		["status","finished"],["unexpected",0]]
	for change in changes:
		var candidate:=agreement(); candidate[change[0]]=change[1]
		check(not trade.validate([candidate],1,p,houses,graph(),1).is_empty(),"Raw contract rejects forged field %s=%s" % [change[0],str(change[1])])
	var missing:=agreement(); missing.erase("proposer")
	check(not trade.validate([missing],1,p,houses,graph(),1).is_empty(),"Missing required contract field is not defaulted silently")
	check(not trade.validate([agreement(),agreement()],1,p,houses,graph(),1).is_empty(),"Duplicate IDs are rejected")
	var duplicate:=agreement(2)
	check(not trade.validate([agreement(),duplicate],2,p,houses,graph(),1).is_empty(),"One directed region relationship cannot have two contracts")
	var offered:=agreement(); offered.status="offered"; offered.accepted_month=-1
	var offered2:=agreement(2,"a","c",0,2); offered2.status="offered"; offered2.accepted_month=-1
	check(not trade.validate([offered,offered2],2,p,houses,graph(),1).is_empty(),"One proposer cannot have two open offers")
	var active_three: Array=[agreement(),agreement(2,"a","c",0,2),agreement(3,"c","a",2,0)]
	check(not trade.validate(active_three,3,p,houses,graph(),1).is_empty(),"A house cannot hold three active contracts")
	check(trade.validate([agreement(),agreement(2,"b","c",1,2),agreement(3,"c","a",2,0)],3,p,houses,graph(),1).is_empty(),"Three competing contracts are valid as a ring with only two per house")
	var impossible:=agreement(); impossible.delivered_lots=2; impossible.last_delivery_month=1
	check(not trade.validate([impossible],1,p,houses,graph(),2).is_empty(),"Two lots cannot fit into only one month after acceptance")
	var offered_lots:=offered.duplicate(true); offered_lots.delivered_lots=1; offered_lots.last_delivery_month=1
	check(not trade.validate([offered_lots],1,p,houses,graph(),1).is_empty(),"A pending offer cannot claim a historical delivery")
	var many: Array=[]
	for index in 65: many.append(agreement(index+1))
	check(not trade.validate(many,65,p,houses,graph(),1).is_empty(),"Global contract bound is checked before processing oversized lists")
	check(not trade.validate([agreement()],1,p,houses,{"a":[],"b":[]},1).is_empty(),"Stored contract must connect actual land neighbours")
	var overflow:=agreement()
	overflow.created_month=9223372036854775800
	overflow.expires_month=9223372036854775806
	overflow.accepted_month=9223372036854775806
	overflow.last_delivery_month=9223372036854775806
	overflow.delivered_lots=2
	check(not trade.validate([overflow],1,p,houses,graph(),9223372036854775807).is_empty(),"Extreme dates cannot overflow chronology and invent two deliveries in the acceptance month")
	for field in ["id","seller","buyer","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots"]:
		for invalid in [true,NAN,INF,0.5]:
			var candidate:=agreement(); candidate[field]=invalid
			check(not trade.validate([candidate],1,p,houses,graph(),1).is_empty(),"Every numeric field rejects raw bool/nonfinite/fraction before normalization: "+field)

func test_contract_specific_pause() -> void:
	var contracts: Array=[agreement(1,"a","b",0,1),agreement(2,"a","c",0,2)]
	var result: Dictionary=plan(sample_world(),contracts,{"a":2*UNIT},{"0":0,"1":4,"2":4},2,{"trade:1":"Die NPC-Baustelle benötigt keine volle Charge mehr."})
	check(result.deliveries.size()==1 and sd(result,"b")==0 and sd(result,"c")==UNIT,"A contract-specific lack of NPC demand pauses only that agreement, not another sale of the same house")
	check(result.contracts.size()==2 and str(result.statuses.get("1",""))=="Die NPC-Baustelle benötigt keine volle Charge mehr.","A temporary per-contract restriction preserves its agreement and exact readable reason")

func need_plan(p: Array, contracts: Array, needs: Dictionary, month: int=2) -> Dictionary:
	return trade.plan(p,contracts,{"a":133676,"c":169684},{"0":0,"1":10,"2":0},month,{},{},graph(),needs)

func test_shared_npc_need_budget() -> void:
	var p: Array=[region("a",300000,0,0.110275),region("b",0,1,0.169684),region("c",300000,2,0.169684)]
	var first:=agreement(1,"a","b",0,1); first.lot_u=133676; first.lot_gold=1
	var second:=agreement(2,"c","b",2,1); second.lot_u=169684; second.lot_gold=1
	var contracts: Array=[first,second]
	var needs: Dictionary={"b":169685}
	check(trade.quote(p[0],p[1])=={"lot_u":133676,"lot_gold":1} and trade.quote(p[2],p[1])=={"lot_u":169684,"lot_gold":1},"NPC overbuy regression uses independently frozen genuine border quotes")
	check(trade.validate(contracts,2,p,[{},{},{}],graph(),2).is_empty(),"Both competing supplier contracts are valid within the buyer's two-active limit")
	var before:=JSON.stringify([p,contracts,needs])
	var result:=need_plan(p,contracts,needs)
	check(result.deliveries.size()==1 and sd(result,"b")==133676 and sd(result,"b")<=169685,"Two suppliers share the one original NPC project need instead of both spending its full demand")
	check(result.contracts.size()==2 and str(result.statuses.get("2","")).to_lower().contains("bedarf"),"A second whole lot that no longer fits demand pauses without partial goods or cancellation")
	check(JSON.stringify([p,contracts,needs])==before,"Planning never decrements the caller's NPC need or other economic inputs")
	var rotated:=need_plan(p,contracts,needs,3)
	check(rotated.deliveries.size()==1 and sd(rotated,"b")==169684 and sd(rotated,"b")<=169685,"The shared need rotates fair access rather than permanently preferring the smaller lot")
	p.reverse(); contracts.reverse()
	check(JSON.stringify(result)==JSON.stringify(need_plan(p,contracts,needs)),"NPC need allocation is independent of supplier and province input ordering")
	check(need_plan(p,contracts,{}).deliveries.size()==2 and sd(need_plan(p,contracts,{}),"b")==303360,"Unlisted human destinations retain deliberate unrestricted purchases with an empty optional need map")
	check(need_plan(p,contracts,{"unrelated":0}).deliveries.size()==2,"A need on another target cannot restrict the current destination")
	var legacy: Dictionary=trade.plan(p,contracts,{"a":133676,"c":169684},{"0":0,"1":10,"2":0},2,{},{},graph())
	check(legacy.deliveries.size()==2 and sd(legacy,"b")==303360,"Existing eight-argument callers keep their unrestricted human-purchase behavior")
	check(need_plan(p,contracts,{"b":0}).deliveries.is_empty(),"A present valid zero NPC need is binding instead of being treated as an absent restriction")
	for invalid in [true,-1,1.5,169685.0,NAN,INF,"169685",1000000000001]:
		var rejected:=need_plan(p,contracts,{"b":invalid})
		check(rejected.deliveries.is_empty() and rejected.stock_deltas.is_empty() and rejected.gold_deltas.is_empty(),"Present but invalid NPC demand fails closed without a partial charge: "+str(invalid))

func test_global_capacity_and_ordering() -> void:
	# All individual parties/pairs are valid: only the 65th agreement exceeds
	# the world limit, rather than accidentally testing duplicate/house limits.
	var p: Array=[]; var houses: Array=[]; var contracts: Array=[]
	var offers: Dictionary={}; var funds: Dictionary={}; var adjacency: Dictionary={}
	for index in 65:
		var source: String="source%d" % index
		var target: String="target%d" % index
		var seller: int=index*2
		var buyer: int=seller+1
		p.append(region(source,UNIT,seller)); p.append(region(target,0,buyer))
		houses.append({}); houses.append({})
		contracts.append(agreement(index+1,source,target,seller,buyer))
		offers[source]=UNIT; funds[str(seller)]=0; funds[str(buyer)]=2
		adjacency[source]=[target]; adjacency[target]=[source]
	var maximum: Array=contracts.slice(0,64)
	check(trade.validate(maximum,64,p,houses,adjacency,1).is_empty(),"Exactly64 distinct individually valid contracts fit the worldwide bound")
	var result: Dictionary=trade.plan(p,maximum,offers,funds,1,{},{},adjacency)
	check(result.deliveries.size()==64 and result.contracts.size()==64,"A full valid64-contract world can deliver every independent original full lot")
	check(not trade.validate(contracts,65,p,houses,adjacency,1).is_empty(),"A65th otherwise independent valid agreement exceeds only the world bound")
	check(trade.plan(p,contracts,offers,funds,1,{},{},adjacency).deliveries.is_empty(),"An oversized65-contract plan fails closed before any booking")
	maximum.reverse(); p.reverse()
	check(JSON.stringify(result)==JSON.stringify(trade.plan(p,maximum,offers,funds,1,{},{},adjacency)),"Complete64-contract outcomes are independent of province and contract input ordering")

func test_defensive_planning_and_purity() -> void:
	var p:=sample_world(); var contracts: Array=[agreement()]; var offers: Dictionary={"a":UNIT}; var funds: Dictionary={"0":0,"1":4,"2":4}
	var before:=JSON.stringify([p,contracts,offers,funds,graph()])
	var result: Dictionary=plan(p,contracts,offers,funds)
	check(JSON.stringify([p,contracts,offers,funds,graph()])==before,"Quote, validation and planning never mutate caller state or contract data")
	var stock_sum:=0; var gold_sum:=0
	for amount in result.stock_deltas.values(): stock_sum+=int(amount)
	for amount in result.gold_deltas.values(): gold_sum+=int(amount)
	check(stock_sum==0 and gold_sum==0,"All planned material and gold are exactly conserved")
	if not result.contracts.is_empty(): result.contracts[0].seller=999
	check(contracts[0].seller==0,"Remaining contracts are independent deep copies")
	for invalid in [true,-1,1.5,NAN,INF,"1000000",1000000000001]:
		check(plan(p,contracts,{"a":invalid},funds).deliveries.is_empty(),"Invalid original offer does not create goods: "+str(invalid))
		check(plan(p,contracts,offers,{"0":0,"1":invalid}).deliveries.is_empty(),"Invalid original money budget does not create payment: "+str(invalid))
	for invalid in [true,NAN,INF,-1,1.5,9223372036854775807]:
		var broken: Array=p.duplicate(true); broken[0].production.materials_u=invalid
		check(plan(broken,contracts,offers,funds).deliveries.is_empty(),"Malformed original source stock never becomes available through clamping: "+str(invalid))
	check(plan(p,contracts,offers,{0:0,1:4}).deliveries.is_empty(),"Integer dictionary keys cannot silently replace required string house budgets")
	var bad:=agreement(); bad.lot_u=9223372036854775807
	check(plan(p,[bad],offers,funds).deliveries.is_empty(),"Extreme forged quantity is rejected before multiplication or booking")
	check(plan(p,[agreement(),agreement()],offers,funds).deliveries.is_empty(),"Duplicate contracts never execute twice")
	check(plan(p,[agreement(),bad],offers,funds).deliveries.is_empty(),"A malformed duplicate ID cannot be filtered out to make its otherwise valid twin executable")
	p.reverse(); contracts.reverse()
	check(plan(p,contracts,offers,funds).deliveries==[{"trade_id":1,"seller":0,"buyer":1,"from":"a","to":"b","amount_u":UNIT,"gold":2}],"Province and contract ordering cannot alter a deterministic valid delivery")
	check(trade.plan([],[],{},{},0,{},{},{}).deliveries.is_empty(),"An empty world never creates a trade")

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADETEST FAIL: "+message)
	return ok

func finish() -> void:
	print("MATERIALTRADETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
