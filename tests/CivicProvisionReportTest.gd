extends Node
## Strict actual food ledger boundary, no simulation or scene dependency.
var Report
var checks := 0
var failures := 0
const NUMERIC := ["owner","before_u","produced_u","consumed_u","requested_u","shortfall_u","wasted_u","after_u","farm_work_u","industry_labor_u","total_labor_u","satisfaction_before","satisfaction_after"]

func _ready() -> void:
	if not FileAccess.file_exists("res://scripts/CivicProvisionReport.gd"):
		check(false,"Required actual provisioning ledger module is implemented")
		finish(); return
	Report=load("res://scripts/CivicProvisionReport.gd")
	if Report==null or not Report.has_method("validate"):
		check(false,"Provisioning ledger exposes real validation")
		finish(); return
	test_valid_and_lifecycle()
	test_rejections()
	test_settlement_bounds()
	finish()

func world() -> Dictionary:
	return {"month_index":1,"houses":[{},{}],"provinces":[{"id":"a","owner":0,"economic_share":1.0,"provisioning":{"food_u":3000000,"harvest_carry":0,"ration_carry":0,"satisfaction":50,"rations":"normal","changed_month":-1}}]}

func row() -> Dictionary:
	return {"owner":0,"before_u":3000000,"produced_u":1000000,"consumed_u":1000000,"requested_u":1000000,"shortfall_u":0,"wasted_u":0,"after_u":3000000,"farm_work_u":500000,"industry_labor_u":1500000,"total_labor_u":2000000,"satisfaction_before":50,"satisfaction_after":50,"rations":"normal"}

func report() -> Dictionary:
	return {"month_index":1,"regions":{"a":row()}}

func test_valid_and_lifecycle() -> void:
	check(Report.empty()=={"month_index":-1,"regions":{}},"Empty report explicitly claims no historical food phase")
	var state := world(); var raw := report(); var before := var_to_bytes(raw); var world_before := var_to_bytes(state)
	var result: Dictionary=Report.validate(raw,state)
	check(result.ok and result.data==raw,"Complete conserved real one-region ledger is accepted")
	check(var_to_bytes(raw)==before and var_to_bytes(state)==world_before,"Validator is pure for report and world")
	var roundtrip: Dictionary=Report.validate(JSON.parse_string(JSON.stringify(raw)),state)
	check(roundtrip.ok and roundtrip.data.month_index is int,"JSON whole-number report is canonicalized after validation")
	if roundtrip.ok:
		for field in NUMERIC: check(roundtrip.data.regions.a[field] is int,"Canonical report quantity "+field)
	state.provinces[0].owner=1; state.provinces[0].provisioning.rations="generous"; state.provinces[0].provisioning.changed_month=1
	check(Report.validate(raw,state).ok,"Historical owner and last ration remain valid after same-month conquest/policy")
	state=world(); state["production_report"]={"month_index":1,"regions":{"a":{"work_u":1000000,"production_work_u":400000,"legacy_work_u":100000}}}
	check(Report.validate(raw,state).ok,"Equal monthly real production budget is legal")
	state.production_report.regions.a.work_u+=1
	check(not Report.validate(raw,state).ok,"Actual work above remaining industry budget is rejected")
	state.production_report.month_index=0
	check(Report.validate(raw,state).ok,"Older production ledger is not compared as this-month work")
	check(Report.validate(Report.empty(),state).ok,"Fresh migration can have old production ledger and no invented food phase")
	var blocked := report(); blocked.regions.a=row(); blocked.regions.a.produced_u=0; blocked.regions.a.farm_work_u=0; blocked.regions.a.industry_labor_u=0; blocked.regions.a.total_labor_u=0; blocked.regions.a.after_u=2000000
	state=world(); state.provinces[0].provisioning.food_u=2000000
	check(Report.validate(blocked,state).ok,"Blocked month consumes real reserve while work/production are zero")
	var overcap:=report(); overcap.regions.a.before_u=9000000; overcap.regions.a.produced_u=0; overcap.regions.a.after_u=6000000; overcap.regions.a.wasted_u=2000000; overcap.regions.a.farm_work_u=0; overcap.regions.a.industry_labor_u=2000000
	state=world(); state.provinces[0].provisioning.food_u=6000000
	check(Report.validate(overcap,state).ok,"Real old overcapacity stock may be explicitly consumed and wasted")

func test_rejections() -> void:
	for field in NUMERIC:
		for bad in [true,false,0.25,NAN,INF,-1,1000000000001]:
			var raw:=report(); raw.regions.a[field]=bad
			rejected(raw,world(),"Raw row "+field+" rejects "+str(bad))
	for field in row():
		var raw:=report(); raw.regions.a.erase(field)
		rejected(raw,world(),"Exact row requires "+field)
	for changed in [["owner",2],["satisfaction_before",101],["satisfaction_after",101],["rations","free"],["rations",true],["after_u",3000001],["shortfall_u",1],["consumed_u",1000001],["produced_u",3000001],["farm_work_u",2000001],["industry_labor_u",1500001],["total_labor_u",2000001]]:
		var raw:=report(); raw.regions.a[changed[0]]=changed[1]
		rejected(raw,world(),"Reject inconsistent "+str(changed))
	for raw in [null,{}, {"month_index":-1,"regions":{"a":{}}},{"month_index":0,"regions":{}},{"month_index":true,"regions":{}},{"month_index":1,"regions":{},"extra":0}]:
		rejected(raw,world(),"Malformed report or empty mismatch")
	var raw:=report(); raw.regions.a["import_u"]=1
	rejected(raw,world(),"No invented imports or extra row fields")
	raw=report(); raw.regions["unknown"]=raw.regions.a; raw.regions.erase("a")
	rejected(raw,world(),"All and only current regions are required")
	var state:=world(); state.provinces.append(state.provinces[0].duplicate(true))
	rejected(report(),state,"Duplicate world region cannot pass")
	state=world(); state.provinces[0].provisioning.satisfaction=49
	rejected(report(),state,"Current satisfaction must match settled report")

func rejected(raw: Variant,state: Dictionary,message: String) -> void:
	var before:=var_to_bytes(raw); var world_before:=var_to_bytes(state)
	var result: Dictionary=Report.validate(raw,state)
	check(not result.ok and result.data.is_empty() and not str(result.reason).is_empty(),message)
	check(var_to_bytes(raw)==before and var_to_bytes(state)==world_before,"Bad report/world remain unchanged")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("CIVICPROVISIONREPORT FAIL: "+message)

func finish() -> void:
	print("CIVICPROVISIONREPORTTEST %s: %d Prüfungen"%["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func test_settlement_bounds() -> void:
	var state:=world(); var raw:=report()
	raw.regions.a.satisfaction_before=0; raw.regions.a.satisfaction_after=0; state.provinces[0].provisioning.satisfaction=0
	rejected(raw,state,"Low-satisfaction world cannot report full healthy labor")
	state=world(); raw=report()
	raw.regions.a.satisfaction_before=0; raw.regions.a.satisfaction_after=0; state.provinces[0].provisioning.satisfaction=0
	raw.regions.a.total_labor_u=1600000; raw.regions.a.farm_work_u=1300000; raw.regions.a.industry_labor_u=300000
	rejected(raw,state,"Farm share cannot exceed75percent of actual pre-settlement labor")
	state=world(); raw=report()
	raw.regions.a.before_u=0; raw.regions.a.produced_u=1000000; raw.regions.a.consumed_u=0; raw.regions.a.shortfall_u=1000000; raw.regions.a.wasted_u=1000000; raw.regions.a.after_u=0; state.provinces[0].provisioning.food_u=0
	rejected(raw,state,"Available food must be consumed before recording shortage and waste")
	state=world(); raw=report(); raw.regions.a.requested_u=999999; raw.regions.a.consumed_u=999999; raw.regions.a.after_u=3000001; state.provinces[0].provisioning.food_u=3000001
	rejected(raw,state,"A whole-weight normal ration cannot be under-requested")
	for bad in [true,false,0.5,NAN,INF,-1,1000000000001]:
		for key in ["work_u","production_work_u","legacy_work_u"]:
			state=world(); state["production_report"]={"month_index":1,"regions":{"a":{"work_u":0,"production_work_u":0,"legacy_work_u":0}}};state.production_report.regions.a[key]=bad
			rejected(report(),state,"Production crosscheck validates raw "+key)
	state=world(); state.provinces[0].economic_share=0.000001; state.provinces[0].provisioning.food_u=3
	raw=report();raw.regions.a={"owner":0,"before_u":3,"produced_u":1,"consumed_u":1,"requested_u":1,"shortfall_u":0,"wasted_u":0,"after_u":3,"farm_work_u":1,"industry_labor_u":1,"total_labor_u":2,"satisfaction_before":50,"satisfaction_after":50,"rations":"normal"}
	check(Report.validate(raw,state).ok,"Smallest one-quantum region keeps exact bounded food and labor")
	state=world();state.provinces=[];raw=report();raw.regions={}
	for index in 256:
		var p:Dictionary=world().provinces[0].duplicate(true);p.id="r%d"%index;state.provinces.append(p);raw.regions[p.id]=row()
	check(Report.validate(raw,state).ok,"Maximum256-region report is accepted")
	var extra:Dictionary=state.provinces[0].duplicate(true);extra.id="overflow";state.provinces.append(extra);raw.regions.overflow=row()
	rejected(raw,state,"257-region report is rejected at bounded DTO boundary")
