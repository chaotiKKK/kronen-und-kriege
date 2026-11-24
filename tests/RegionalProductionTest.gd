extends Node
## Catches free whole-region output, labor duplication, material deadlock and rounding drift.
var checks := 0
var failures := 0
var production

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/RegionalProduction.gd"):
		check(false,"Real regional production module must produce the specified finite output")
		finish()
		return
	production = load("res://scripts/RegionalProduction.gd")
	if production == null:
		check(false,"Regional production module loads")
		finish()
		return
	test_weight_and_requirements()
	test_production_and_carry()
	test_local_material_progress()
	test_labor_priority_and_fairness()
	test_overflow_and_blocked()
	test_reordering_and_conservation()
	test_completion_alternatives()
	test_large_exact_ratio()
	test_public_exact_helpers()
	test_available_labor_budget()
	finish()

func region(weight: float=1.0, stock: int=0, focus: String="balanced", terrain: String="plains") -> Dictionary:
	return {"id":"home","economic_share":weight,"economic_focus":focus,"terrain":terrain,"dev":4,"production":{"materials_u":stock,"rate_carry":0}}

func task(token: String="market", material: int=6000000, work: int=4000000, priority: int=0) -> Dictionary:
	return {"token":token,"priority":priority,"started_month":0,"material_total_u":material,"material_spent_u":0,"work_total_u":work,"work_done_u":0}

func update(report: Dictionary, token: String) -> Dictionary:
	for item in report.get("task_updates",[]):
		if str(item.token)==token: return item
	return {}

func test_weight_and_requirements() -> void:
	check(production.weight_u({})==1000000,"Missing legacy weight means one normal capacity unit")
	check(production.weight_u(region(0.000630275878694353))==630,"Smallest catalog region gets 630 micro-weight, not a whole material")
	check(production.stock_capacity_u(region(0.000630275878694353))==7560,"Tiny stock capacity scales to actual territory")
	check(production.labor_capacity_u(region(0.000630275878694353))==1260,"Tiny labor has no whole-region minimum")
	check(production.yield_numerator(region())==8 and production.yield_numerator(region(1.0,0,"balanced","forest"))==10,"Base material yield uses 8/32 and forest10/32")
	check(production.yield_numerator(region(1.0,0,"workshops","hills"))==40,"Hill workshops use the real 40/32 yield")
	var cases := [["market",1,6000000,4000000],["market",3,14000000,8000000],["barracks",2,12000000,7000000],["walls",3,18000000,10000000],["develop",5,8000000,8000000],["depot",1,8000000,6000000]]
	for item in cases:
		var req: Dictionary = production.requirements(region(),str(item[0]),int(item[1]))
		check(req.get("material_total_u")==item[2] and req.get("work_total_u")==item[3],"Frozen requirements: "+str(item[0])+str(item[1]))
	check(production.requirements(region(),"unknown",1).is_empty(),"Unknown project cannot acquire free requirements")
	var a := region(); a.id="a"
	var b := region(3.0); b.id="b"
	check(production.edge_weight_u(a,b)==1500000,"Road uses harmonic capacity rather than region count")
	var road: Dictionary = production.road_requirements(a,b)
	check(road.get("material_total_u")==9000000 and road.get("work_total_u")==9000000,"Road has finite total material and labor")
	check(road.legs.size()==2 and road.legs[0].province=="a" and road.legs[0].material_total_u==4500000 and road.legs[1].work_total_u==4500000,"Each actual road endpoint receives its construction leg")
	check(production.road_requirements(b,a)==road,"Road endpoint order cannot change requirements or remainder assignment")

func test_production_and_carry() -> void:
	var p := region()
	var result: Dictionary = production.plan_local(p,[],0)
	check(result.materials_u==500000 and result.produced_u==500000 and result.production_work_u==2000000 and result.rate_carry==0,"Empty normal region produces exactly500000 micro-units from2000000 labor")
	p=region(0.000001,0,"balanced")
	var work := task("one",1,8)
	work.material_spent_u=1
	work.work_done_u=1
	for month in 4:
		# High-priority construction consumes exactly one of two micro-work quanta.
		var single := task("one",1,2)
		single.material_spent_u=1
		single.work_done_u=1
		p.production.materials_u=1
		result=production.plan_local(p,[single],month)
		p.production.rate_carry=result.rate_carry
	check(result.rate_carry==0 and result.produced_u==1,"Four quarter-producing leftover work quanta conserve the carried material quantum")

func test_local_material_progress() -> void:
	var p := region()
	var result: Dictionary = production.plan_local(p,[task()],0)
	var item := update(result,"market")
	check(int(item.get("work_done_u",0))>0 and result.production_work_u>0,"Empty local project makes material and real progress without a supply deadlock")
	check(result.work_u+result.production_work_u<=2000000,"Construction and material production share the same local labor")
	check(result.materials_u>=0 and result.materials_u==result.produced_u-result.used_u,"Local progress spends only produced real material")
	check(item.material_spent_u==int(ceil(float(6000000*int(item.work_done_u))/4000000.0)),"Partial project spends its exact cumulative ceiling material ratio")
	var tiny: Dictionary = production.plan_local(region(0.000630275878694353),[task("tiny",3780,2520)],0)
	check(tiny.work_u>0 and tiny.work_u+tiny.production_work_u<=1260,"Smallest actual catalog weight also has finite progressing work")
	check(tiny.materials_u==tiny.produced_u-tiny.used_u,"Tiny local production conserves every micro-unit")

func test_labor_priority_and_fairness() -> void:
	var p:=region(0.000001,12)
	var first:=task("a",1,10)
	var second:=task("b",1,10)
	var third:=task("c",1,10)
	var zero: Dictionary=production.plan_local(p,[third,first,second],0)
	var one: Dictionary=production.plan_local(p,[third,first,second],1)
	check(update(zero,"a").work_done_u==1 and update(zero,"b").work_done_u==1 and update(zero,"c").work_done_u==0,"Equal tasks split labor and stable month0 remainder")
	check(update(one,"b").work_done_u==1 and update(one,"c").work_done_u==1 and update(one,"a").work_done_u==0,"Whole work remainder rotates instead of starving the last task")
	first.priority=1
	var urgent: Dictionary=production.plan_local(p,[second,first],0)
	check(update(urgent,"a").work_done_u==2 and update(urgent,"b").work_done_u==0,"Priority reallocates existing labor without creating more")
	var split: Dictionary=production.plan_local(region(1.0,12000000),[task("local",6000000,4000000),task("road",6000000,6000000)],0)
	check(update(split,"local").work_done_u==1000000 and update(split,"road").work_done_u==1000000,"Regional project and road leg share one actual labor pool")

func test_overflow_and_blocked() -> void:
	var p:=region(1.0,11999999)
	var result: Dictionary=production.plan_local(p,[],0)
	check(result.materials_u==12000000 and result.produced_u==500000 and result.wasted_u==499999,"Full warehouse caps real material and reports overflow honestly")
	p.production.rate_carry=31
	result=production.plan_local(p,[task()],0,true)
	check(result.materials_u==11999999 and result.rate_carry==31 and result.produced_u==0 and result.work_u==0 and result.production_work_u==0,"Hostile occupation preserves stock/carry and stops both production and construction")

func test_reordering_and_conservation() -> void:
	var p:=region(0.4,900000,"workshops","forest")
	var tasks: Array=[task("road-b",1200000,1000000),task("local",2000000,1000000),task("road-a",1000000,1000000)]
	var before:=JSON.stringify([p,tasks])
	var result: Dictionary=production.plan_local(p,tasks,7)
	check(JSON.stringify([p,tasks])==before,"Pure local planner cannot mutate caller province or tasks")
	tasks.reverse()
	check(JSON.stringify(production.plan_local(p,tasks,7))==JSON.stringify(result),"Input order cannot change local work, output or report ordering")
	check(900000+result.produced_u-result.used_u-result.wasted_u==result.materials_u,"Local material ledger balances exactly")
	check(result.work_u+result.production_work_u<=800000,"Multiple jobs still share only actual weighted labor")
	var sum_used:=0
	var sum_work:=0
	for item in result.task_updates:
		sum_used+=int(item.material_spent_u)
		sum_work+=int(item.work_done_u)
	check(sum_used==result.used_u and sum_work==result.work_u,"Task deltas agree with the single regional ledger")

func complete_months(focus: String, stock: int) -> int:
	var p:=region(1.0,stock,focus)
	var current:=task()
	for month in 40:
		var result: Dictionary=production.plan_local(p,[current],month)
		p.production.materials_u=result.materials_u
		p.production.rate_carry=result.rate_carry
		var item:=update(result,"market")
		current.work_done_u=item.work_done_u
		current.material_spent_u=item.material_spent_u
		if current.work_done_u==4000000: return month+1
	return 999

func test_completion_alternatives() -> void:
	var unassisted:=complete_months("balanced",0)
	var workshops:=complete_months("workshops",0)
	var stocked:=complete_months("balanced",6000000)
	check(unassisted==14 and workshops==5 and stocked==2,"Actual material and productivity change completion:14/5/2months, not one universal timer")

func test_large_exact_ratio() -> void:
	# Values deliberately exceed safe64-bit multiplication, while quotients remain bounded.
	var p:=region(1000.0,10000000000)
	var current:=task("large",999999999999,999999999998)
	current.work_done_u=499999999999
	current.material_spent_u=500000000000
	var result: Dictionary=production.plan_local(p,[current],0)
	check(result.work_u==2000000000 and update(result,"large").material_spent_u==502000000000,"Large cumulative ceiling ratio remains exact without integer-product overflow")
	check(result.used_u==2000000000 and result.materials_u==8000000000,"Large partial consumption preserves the material ledger")

func test_public_exact_helpers() -> void:
	if not production.has_method("material_at_work") or not production.has_method("mul_div_floor"):
		check(false,"Shared Game/Save material and multiplication helpers must exist without duplicated overflow-prone arithmetic")
		return
	check(production.call("material_at_work",999999999999,999999999998,501999999999)==502000000000,"Public material helper computes the exact large cumulative ceiling")
	check(production.call("material_at_work",9,4,1)==3 and production.call("material_at_work",9,4,4)==9,"Public material helper rounds partial consumption up and ends on exact total")
	check(production.call("mul_div_floor",999999999999,999999999998,999999999997)==1000000000000,"Public floor helper remains exact at the admitted quantity ceiling")
	check(production.call("mul_div_floor",200000000000,200000000000,400000000000)==100000000000,"Public floor helper computes harmonic road products beyond int64 safely")
	check(production.call("mul_div_floor",1000000000000,1000000000000,1)==1000000000000,"Public quantity helper saturates oversized results at admitted MAX_UNITS")

func test_available_labor_budget() -> void:
	var supported:=false
	for method in production.get_script_method_list():
		if method.name=="plan_local": supported=method.args.size()==5
	if not supported:
		check(false,"An explicit industrial remainder must constrain existing production instead of duplicating civilian labor")
		return
	var p:=region()
	var before:=JSON.stringify(p)
	var low: Dictionary=production.plan_local(p,[],0,false,500000)
	check(low.production_work_u==500000 and low.produced_u==125000,"Explicit500000 work produces only125000 material, not the full region output")
	var zero: Dictionary=production.plan_local(p,[task()],0,false,0)
	check(zero.work_u==0 and zero.production_work_u==0 and zero.produced_u==0,"No remaining work means neither construction nor material fabrication")
	var shared: Dictionary=production.plan_local(region(1.0,12000000),[task()],0,false,900000)
	check(shared.work_u==900000 and shared.production_work_u==0,"Stocked construction is limited to its exact explicit budget")
	var mixed: Dictionary=production.plan_local(p,[task()],0,false,900000)
	check(mixed.work_u>0 and mixed.work_u+mixed.production_work_u<=900000,"Construction and its prerequisite production share the smaller budget")
	check(production.plan_local(p,[],0)==production.plan_local(p,[],0,false,-1),"Omitted or sentinel budget preserves the original pure module behavior")
	check(production.plan_local(p,[],0)==production.plan_local(p,[],0,false,999999999999),"A caller cannot invent labor beyond actual regional capacity")
	var invalid: Dictionary=production.plan_local(p,[],0,false,-2)
	check(invalid.production_work_u==0 and invalid.produced_u==0,"Only the documented minus-one sentinel means full capacity; other negative budgets fail closed")
	var blocked: Dictionary=production.plan_local(p,[],0,true,900000)
	check(blocked.work_u==0 and blocked.production_work_u==0,"An explicit work budget cannot bypass hostile occupation")
	check(JSON.stringify(p)==before,"Explicit budget planning preserves the original province")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("REGIONALPRODUCTIONTEST FAIL: "+message)

func finish() -> void:
	print("REGIONALPRODUCTIONTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
