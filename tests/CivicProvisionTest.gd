extends Node
## Real finite-food, rounding, recovery and shared-work contracts; no Game/RNG fixtures.
var food
var checks := 0
var failures := 0

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/CivicProvision.gd"):
		check(false,"Finite civilian food must consume a real ration and reserve shared farm work")
		finish()
		return
	food=load("res://scripts/CivicProvision.gd")
	if food==null:
		check(false,"Civilian provision API loads cleanly")
		finish()
		return
	test_neutral_and_policy_costs()
	test_raw_state_and_plan_rejection()
	test_remainders_and_weights()
	test_blockade_reserves_and_recovery()
	test_taxes_and_satisfaction_limits()
	test_storage_and_research()
	test_budget_integration()
	test_extreme_purity()
	finish()

func region(weight: float=1.0, focus: String="balanced", rations: String="normal", satisfaction: int=50) -> Dictionary:
	var p := {"id":"home","owner":0,"economic_share":weight,"economic_focus":focus,"terrain":"forest","dev":4,"production":{"materials_u":0,"rate_carry":0}}
	p.provisioning=food.initial_state(p)
	p.provisioning.rations=rations
	p.provisioning.satisfaction=satisfaction
	return p

func balanced(result: Dictionary, label: String) -> void:
	check(result.get("ok",false),label+": plan is valid")
	if not result.get("ok",false): return
	var row: Dictionary=result.ledger
	check(row.size()==14 and row.before_u+row.produced_u-row.consumed_u-row.wasted_u==row.after_u,label+": exact fourteen-field food ledger conserves quantity")
	check(row.consumed_u<=row.requested_u and row.shortfall_u==row.requested_u-row.consumed_u and row.after_u>=0,label+": only actual available food is consumed")
	check(row.farm_work_u+row.industry_labor_u<=row.total_labor_u,label+": agriculture and industry share one effective budget")
	check(int(result.state.food_u)==int(row.after_u) and int(result.state.satisfaction)==int(row.satisfaction_after),label+": returned state matches ledger")

func test_neutral_and_policy_costs() -> void:
	var p:=region()
	check(p.provisioning=={"food_u":3000000,"harvest_carry":0,"ration_carry":0,"satisfaction":50,"rations":"normal","changed_month":-1},"Explicit initial resource is exactly three normal rations, neutral and unmodified")
	var normal: Dictionary=food.plan(p,1,1)
	balanced(normal,"Normal one-weight region")
	if not normal.get("ok",false): return
	check(normal.ledger.before_u==3000000 and normal.ledger.produced_u==1000000 and normal.ledger.consumed_u==1000000 and normal.ledger.after_u==3000000,"Neutral ration preserves the real three-month reserve")
	check(normal.ledger.farm_work_u==500000 and normal.ledger.industry_labor_u==1500000 and normal.ledger.total_labor_u==2000000,"Normal harvest uses actual500000 farm work, leaving1500000 for industry")
	p.provisioning.rations="generous"
	var generous: Dictionary=food.plan(p,1,1)
	balanced(generous,"Generous ration")
	check(generous.ledger.requested_u==1250000 and generous.ledger.farm_work_u==625000 and generous.ledger.industry_labor_u==1375000 and generous.state.satisfaction==52,"Generous rations cost25percent more food and real farm work before improving satisfaction")
	p.provisioning.rations="scarce"
	var scarce: Dictionary=food.plan(p,1,1)
	balanced(scarce,"Scarce ration")
	check(scarce.ledger.requested_u==750000 and scarce.ledger.farm_work_u==375000 and scarce.ledger.total_labor_u==1980000 and scarce.ledger.industry_labor_u==1605000 and scarce.state.satisfaction==49,"Scarce ration trades lower demand against immediate morale and work capacity")
	for item in [["balanced",500000,1000000,3000000],["trade",625000,1000000,3000000],["workshops",666667,1000000,3000000],["agriculture",1333334,4000002,6000000]]:
		var result: Dictionary=food.plan(region(1.0,str(item[0])),1,1)
		check(result.ok and result.ledger.farm_work_u==item[1] and result.ledger.produced_u==item[2] and result.ledger.after_u==item[3],"Literal harvest cost/reserve for focus "+str(item[0]))

func test_raw_state_and_plan_rejection() -> void:
	var p:=region()
	var state: Dictionary=p.provisioning.duplicate(true)
	check(food.state_errors(state,1).is_empty(),"Valid exact six-field raw state is accepted")
	for field in ["food_u","harvest_carry","ration_carry","satisfaction","changed_month"]:
		for bad in [true,false,0.5,NAN,INF,"1",null,[],{}]:
			var changed: Dictionary=state.duplicate(true); changed[field]=bad
			var before:=var_to_bytes(changed)
			check(not food.state_errors(changed,1).is_empty(),"Reject raw malformed numeric "+field+"/"+str(bad))
			check(before==var_to_bytes(changed),"Raw validation preserves malformed input "+field)
		var missing: Dictionary=state.duplicate(true); missing.erase(field)
		check(not food.state_errors(missing,1).is_empty(),"Missing raw numeric is not silently initialized: "+field)
	for pair in [["food_u",-1],["food_u",1000000000001],["harvest_carry",10000],["ration_carry",100],["satisfaction",101],["changed_month",-2],["changed_month",2],["rations","feast"],["rations",1],["unknown",0]]:
		var changed: Dictionary=state.duplicate(true); changed[pair[0]]=pair[1]
		check(not food.state_errors(changed,1).is_empty(),"Reject invalid raw bound/key/policy "+str(pair))
	for raw in [null,[],true,1,"state"]:
		check(not food.state_errors(raw,1).is_empty(),"Reject non-dictionary state "+str(raw))
	var json_state: Dictionary=JSON.parse_string(JSON.stringify(state))
	check(food.state_errors(json_state,1).is_empty(),"Finite whole JSON numbers are valid before canonicalization")
	p.provisioning=json_state
	var json_plan: Dictionary=food.plan(p,1,1)
	check(json_plan.ok and typeof(json_plan.state.food_u)==TYPE_INT and typeof(json_plan.state.changed_month)==TYPE_INT,"Returned valid JSON state is canonically integer without editing its source")
	p.erase("provisioning")
	check(not food.plan(p,1,1).ok,"Missing state never receives an implicit reserve")
	p=region(); p.provisioning.food_u=true
	check(not food.plan(p,1,1).ok,"Plan rejects malformed state before any quantity coercion")
	p=region()
	for bad_bonus in [{"harvest_percent":true},{"harvest_percent":0.5},{"storage_percent":101},{"harvest_percent":-1},{"unknown":1}]:
		check(not food.plan(p,1,1,bad_bonus).ok,"Reject untrusted bonus "+str(bad_bonus))
	check(not food.plan(p,-1,1).ok and not food.plan(p,1,3).ok and not food.plan(p,1,-1).ok,"Invalid simulation month and tax cannot enter a food phase")
	p.economic_focus="unknown"
	check(not food.plan(p,1,1).ok,"Unknown focus cannot invent an implicit food yield")
	p=region(); p.owner=-1
	check(not food.plan(p,1,1).ok,"A ledger cannot fabricate a valid historical owner")

func test_remainders_and_weights() -> void:
	check(food.need_u(region(0.000630275878694353))==630 and food.need_u(region(3.7647918625942487))==3764792,"Smallest/largest catalog weights determine need, not region count")
	for weight in [0.000001,0.000630275878694353,0.0050137620969656896,0.1370968205859261,1.0,3.7647918625942487]:
		for focus in ["balanced","agriculture","trade","workshops"]:
			var p:=region(float(weight),focus,"normal",0)
			p.provisioning.food_u=0
			for month in 5:
				var result: Dictionary=food.plan(p,month,1)
				balanced(result,"Subsistence "+focus+"/"+str(weight)+"/"+str(month))
				if float(weight)==0.000001:
					# Technical w=1 stress input is below the real catalog minimum630.
					# floor(2*80/100)=1 and floor(1*75/100)=0: no free work/food.
					check(result.ledger.shortfall_u==1 and result.ledger.produced_u==0 and result.ledger.farm_work_u==0 and result.ledger.total_labor_u==1,"Artificial single-quantum starvation keeps exact finite work and never fabricates subsistence")
				else:
					check(result.ledger.shortfall_u==0,"Every supported zero-satisfaction unstocked region covers normal subsistence "+focus+"/"+str(weight))
				p.provisioning=result.state
	for weight in [0.000630275878694353,3.7647918625942487]:
		for focus in ["balanced","agriculture","trade","workshops"]:
			for policy in ["scarce","normal","generous"]:
				var p:=region(float(weight),focus,policy,0)
				p.provisioning.food_u=0
				var result: Dictionary=food.plan(p,1,1)
				balanced(result,"Supported extreme focus/ration "+focus+"/"+policy+"/"+str(weight))
				check(result.ledger.shortfall_u==0,"Supported smallest/largest regions cover each ration through actual farm work at minimum satisfaction")
	for policy in ["scarce","generous"]:
		var p:=region(0.000001,"workshops",policy)
		var requested:=0; var produced:=0; var work:=0
		for month in 100:
			var result: Dictionary=food.plan(p,month,1)
			requested+=int(result.ledger.requested_u); produced+=int(result.ledger.produced_u); work+=int(result.ledger.farm_work_u)
			p.provisioning=result.state
		check(requested==(75 if policy=="scarce" else 125) and p.provisioning.ration_carry==0,"One-hundred tiny rations preserve every quarter-quantum: "+policy)
		check(produced*10000+int(p.provisioning.harvest_carry)==work*15000,"Tiny work keeps the exact harvest numerator remainder: "+policy)

func test_blockade_reserves_and_recovery() -> void:
	var p:=region()
	for month in 3:
		var result: Dictionary=food.plan(p,month,1,{},true)
		balanced(result,"Blocked reserve month"+str(month))
		check(result.ledger.produced_u==0 and result.ledger.farm_work_u==0 and result.ledger.industry_labor_u==0 and result.ledger.total_labor_u==0 and result.ledger.shortfall_u==0,"Blockade stops all work and consumes exactly the stored reserve")
		check(result.state.food_u==2000000-month*1000000,"Three initial rations are finite during blockade")
		p.provisioning=result.state
	var starved: Dictionary=food.plan(p,3,1,{},true)
	check(starved.ledger.consumed_u==0 and starved.ledger.shortfall_u==1000000 and starved.state.food_u==0 and starved.state.satisfaction==42,"Fourth full blockade month has real unmet need and8satisfaction loss")
	p.provisioning=starved.state
	var recovery: Dictionary=food.plan(p,4,1)
	balanced(recovery,"Real local recovery after relief")
	check(recovery.ledger.shortfall_u==0 and recovery.ledger.produced_u>recovery.ledger.consumed_u and recovery.state.satisfaction==43 and recovery.ledger.industry_labor_u>0,"Relieved town recovers from its own finite work without gifted stock")
	p=region(); p.provisioning.food_u=500000
	var partial: Dictionary=food.plan(p,1,1,{},true)
	check(partial.ledger.shortfall_u==500000 and partial.state.satisfaction==46,"Half an unmet ration causes the independently derived4point penalty")
	p=region(); p.provisioning.food_u=999999; p.provisioning.satisfaction=40
	var tiny: Dictionary=food.plan(p,1,1,{},true)
	check(tiny.state.satisfaction==39,"Even a one-quantum deficit removes positive normal recovery and costs at least1")

func test_taxes_and_satisfaction_limits() -> void:
	for item in [["normal",50,0,51],["normal",50,1,50],["normal",50,2,48],["normal",40,1,41],["normal",60,1,59],["scarce",50,2,47],["generous",50,2,50],["generous",74,1,75],["generous",80,1,80],["generous",100,0,100]]:
		var result: Dictionary=food.plan(region(1.0,"balanced",str(item[0]),int(item[1])),1,int(item[2]))
		check(result.state.satisfaction==item[3],"Actual tax/ration satisfaction consequence "+str(item))
	for item in [[0,80,80],[1,80,80],[49,99,99],[50,100,100],[51,100,100],[74,100,109],[75,100,110],[100,100,110]]:
		check(food.work_percent(int(item[0]))==item[1] and food.income_percent(int(item[0]))==item[2],"Exact positive/negative floor and cap for satisfaction "+str(item[0]))
	check(food.ration_rate("scarce")==75 and food.ration_rate("normal")==100 and food.ration_rate("generous")==125 and food.ration_rate("unknown")==0,"Only known ration policies yield a request rate")

func test_storage_and_research() -> void:
	var p:=region()
	check(food.capacity_u(p)==6000000 and food.capacity_u(p,{"storage_percent":100})==12000000,"Granary bonus doubles finite storage rather than creating food")
	var boosted: Dictionary=food.plan(p,1,1,{"harvest_percent":10})
	check(boosted.ledger.farm_work_u==454546 and boosted.ledger.produced_u==1000001 and boosted.state.harvest_carry==2000,"Research changes exact required harvest work and preserves fraction")
	p=region(1.0,"agriculture"); p.provisioning.food_u=0
	var capped: Dictionary=food.plan(p,1,1)
	check(capped.ledger.farm_work_u==1500000 and capped.ledger.produced_u==4500000 and capped.ledger.after_u==3500000,"Agriculture uses at most75percent of actual labor while rebuilding the6ration target")
	p=region(); p.provisioning.food_u=1000000000000
	check(food.state_errors(p.provisioning,1).is_empty(),"A real captured stock above current capacity remains raw-loadable")
	var over: Dictionary=food.plan(p,1,1)
	balanced(over,"Explicit over-capacity release")
	check(over.ledger.farm_work_u==0 and over.ledger.produced_u==0 and over.ledger.wasted_u==999993000000 and over.state.food_u==6000000,"Over-capacity stock is consumed first and overflow booked only in the next real plan")
	p=region(); p.provisioning.harvest_carry=9999; p.provisioning.ration_carry=99
	var paused: Dictionary=food.plan(p,1,1,{},true)
	check(paused.state.harvest_carry==9999 and paused.state.ration_carry==99,"Blockade preserves harvest carry and applies the ration carry exactly once")

func test_budget_integration() -> void:
	var production=load("res://scripts/RegionalProduction.gd")
	var supports_budget:=false
	for method in production.get_script_method_list():
		if method.name=="plan_local": supports_budget=method.args.size()==5
	if not supports_budget:
		check(false,"Industrial planner must accept the remaining civilian work instead of duplicating full labor")
		return
	var p:=region()
	var result: Dictionary=food.plan(p,1,1)
	var industry: Dictionary=production.plan_local(p,[],1,false,int(result.ledger.industry_labor_u))
	check(industry.production_work_u==1500000 and industry.produced_u==468750,"Actual forest material output uses only the remaining1500000 work")
	check(result.ledger.farm_work_u+industry.work_u+industry.production_work_u<=result.ledger.total_labor_u,"Actual separate planners conserve one common workforce")

func test_extreme_purity() -> void:
	var p:=region(15625.0,"agriculture","generous",0)
	p.provisioning.food_u=0
	var bonuses: Dictionary={"harvest_percent":100,"storage_percent":100}
	var before:=var_to_bytes([p,bonuses])
	var result: Dictionary=food.plan(p,1000000000,2,bonuses)
	balanced(result,"Largest canonical economic weight")
	check(result.ledger.shortfall_u==0 and result.ledger.total_labor_u<=31250000000 and result.ledger.produced_u<=1000000000000,"Admitted large quantities remain finite without product overflow")
	check(before==var_to_bytes([p,bonuses]),"Planning cannot mutate caller state, nested stocks or research bonuses")
	check(var_to_bytes(food.plan(p,1000000000,2,bonuses))==var_to_bytes(result),"Repeated pure preview cannot consume or generate a second different result")
	check(food.state_errors(result.state,1000000000).is_empty(),"Largest valid pure output remains admissible raw save data")
	seed(20261118)
	var next_random:=randi()
	seed(20261118)
	food.plan(p,1000000000,2,bonuses)
	check(randi()==next_random,"Pure simulation preview does not advance or reseed the world RNG")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("CIVICPROVISIONTEST FAIL: "+message)

func finish() -> void:
	print("CIVICPROVISIONTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
