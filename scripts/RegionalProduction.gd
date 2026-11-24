extends RefCounted
## Pure fixed-point labor/material planning. Game alone books its result.
const UNIT := 1000000
const MAX_UNITS := 1000000000000
const MAX_SERIAL := 1000000000
const MAX_WEIGHT_U := 15625000000
const RULES := {
	"algorithm_version":2,"unit":UNIT,"max_units":MAX_UNITS,"max_serial":MAX_SERIAL,
	"max_weight_u":MAX_WEIGHT_U,"max_tasks":256,"labor_per_weight":2,
	"stock_per_weight":12,"yield_denominator":32,"normal_yield":8,
	"normal_resource_terrain_yield":10,"workshops_yield":32,
	"workshops_resource_terrain_yield":40,"resource_terrains":["forest","hills"],
	"road_material_per_weight":6,"road_work_per_weight":6,
	"road_capacity_per_weight":4,"equal_priority_rotates_by_month":true,
	"cumulative_material_ceiling":true,"overflow_carry_is_discarded":true,
	"project_requirements":{
		"market":{"material_base":2,"material_per_level":4,"work_base":2,"work_per_level":2},
		"barracks":{"material_base":4,"material_per_level":4,"work_base":3,"work_per_level":2},
		"walls":{"material_base":6,"material_per_level":4,"work_base":4,"work_per_level":2}},
	"develop_base":6,"develop_per_band":2,"develop_band":3,
	"depot_material":8,"depot_work":6,
	"quantity_helper_saturates_at_max_units":true,
	"optional_available_labor_u":true,"full_labor_sentinel":-1,
}

static func weight_u(province: Dictionary) -> int:
	var value = province.get("economic_share",1.0)
	if not (value is int or value is float) or not is_finite(float(value)):
		return UNIT
	return clampi(roundi(clampf(float(value),0.0,float(MAX_WEIGHT_U)/UNIT)*UNIT),1,MAX_WEIGHT_U)

static func stock_capacity_u(province: Dictionary) -> int:
	return weight_u(province)*int(RULES.stock_per_weight)

static func labor_capacity_u(province: Dictionary) -> int:
	return weight_u(province)*int(RULES.labor_per_weight)

static func yield_numerator(province: Dictionary) -> int:
	var resource_terrain: bool = RULES.resource_terrains.has(str(province.get("terrain","plains")))
	if str(province.get("economic_focus","balanced"))=="workshops":
		return int(RULES.workshops_resource_terrain_yield if resource_terrain else RULES.workshops_yield)
	return int(RULES.normal_resource_terrain_yield if resource_terrain else RULES.normal_yield)

static func requirements(province: Dictionary, kind: String, target_level: int) -> Dictionary:
	var weight := weight_u(province)
	if RULES.project_requirements.has(kind):
		if target_level<1 or target_level>3: return {}
		var definition: Dictionary = RULES.project_requirements[kind]
		return {"material_total_u":(int(definition.material_base)+int(definition.material_per_level)*target_level)*weight,
			"work_total_u":(int(definition.work_base)+int(definition.work_per_level)*target_level)*weight}
	if kind=="depot" and target_level==1:
		return {"material_total_u":int(RULES.depot_material)*weight,"work_total_u":int(RULES.depot_work)*weight}
	if kind=="develop":
		var development := clampi(int(province.get("dev",1)),0,10)
		if target_level!=development+1 or target_level>10: return {}
		var amount := (int(RULES.develop_base)+int(RULES.develop_per_band)*floori(float(development-1)/int(RULES.develop_band)))*weight
		return {"material_total_u":amount,"work_total_u":amount}
	return {}

static func edge_weight_u(a: Dictionary, b: Dictionary) -> int:
	var left := weight_u(a)
	var right := weight_u(b)
	return int(_mul_div(2*left,right,left+right).quotient)

## Public shared quantity arithmetic for Game and strict Save validation.
static func material_at_work(material_total_u: int, work_total_u: int, work_done_u: int) -> int:
	if material_total_u<=0 or work_total_u<=0 or work_done_u<=0: return 0
	var material := mini(material_total_u,MAX_UNITS)
	var total := mini(work_total_u,MAX_UNITS)
	var done := mini(work_done_u,total)
	return mini(MAX_UNITS,_ceil_ratio(material,done,total))

## Exact floor for admitted nonnegative quantities; oversized results saturate.
static func mul_div_floor(a: int, b: int, denominator: int) -> int:
	if a<=0 or b<=0 or denominator<=0: return 0
	return int(_mul_div(mini(a,MAX_UNITS),mini(b,MAX_UNITS),mini(denominator,MAX_UNITS)).quotient)

static func road_requirements(a: Dictionary, b: Dictionary) -> Dictionary:
	var edge := edge_weight_u(a,b)
	var material := int(RULES.road_material_per_weight)*edge
	var work := int(RULES.road_work_per_weight)*edge
	var ids: Array = [str(a.get("id","")),str(b.get("id",""))]
	ids.sort()
	var legs: Array=[]
	for index in 2:
		@warning_ignore("integer_division")
		var leg_material: int = material/2 + (material%2 if index==0 else 0)
		@warning_ignore("integer_division")
		var leg_work: int = work/2 + (work%2 if index==0 else 0)
		legs.append({"province":ids[index],"material_total_u":leg_material,"material_spent_u":0,"work_total_u":leg_work,"work_done_u":0})
	return {"edge_weight_u":edge,"material_total_u":material,"work_total_u":work,"legs":legs}

static func plan_local(province: Dictionary, tasks: Array, month_index: int, blocked: bool = false, available_labor_u: int = -1) -> Dictionary:
	var capacity := stock_capacity_u(province)
	var production: Dictionary = province.get("production",{}) if province.get("production",{}) is Dictionary else {}
	var state := {"materials_u":clampi(int(production.get("materials_u",0)),0,capacity),
		"rate_carry":clampi(int(production.get("rate_carry",0)),0,31),
		"produced_u":0,"used_u":0,"work_u":0,"production_work_u":0,"wasted_u":0,
		"task_updates":[]}
	var working := _tasks(tasks)
	if not blocked:
		var remaining := labor_capacity_u(province)
		if available_labor_u!=-1: remaining=clampi(available_labor_u,0,remaining)
		for priority in [1,0]:
			var group: Array=[]
			for item in working:
				if int(item.priority)==priority and int(item.work_done_u)<int(item.work_total_u): group.append(item)
			while remaining>0 and not group.is_empty():
				@warning_ignore("integer_division")
				var share: int = remaining/group.size()
				var remainder: int = remaining%group.size()
				var start := posmod(month_index,group.size())
				var spent := 0
				for index in group.size():
					var allowance := share+(1 if posmod(index-start,group.size())<remainder else 0)
					spent+=_advance(group[index],allowance,state,yield_numerator(province),capacity)
				remaining-=spent
				var unfinished: Array=[]
				for item in group:
					if int(item.work_done_u)<int(item.work_total_u): unfinished.append(item)
				group=unfinished
				if spent==0: break
		_produce(remaining,state,yield_numerator(province),capacity)
	for item in working:
		state.task_updates.append({"token":item.token,"work_done_u":item.work_done_u,"material_spent_u":item.material_spent_u,
			"work_u":int(item.work_done_u)-int(item.initial_work_u),"used_u":int(item.material_spent_u)-int(item.initial_material_u),
			"complete":int(item.work_done_u)==int(item.work_total_u)})
	return state

static func _tasks(tasks: Array) -> Array:
	var result: Array=[]
	var counts := {}
	for candidate in tasks:
		if candidate is Dictionary and candidate.has("token"):
			var key := str(candidate.token)
			counts[key]=int(counts.get(key,0))+1
	for candidate in tasks.slice(0,int(RULES.max_tasks)):
		if not candidate is Dictionary or not candidate.has("token") or int(counts.get(str(candidate.token),0))!=1: continue
		var valid := true
		for key in ["material_total_u","material_spent_u","work_total_u","work_done_u"]:
			var value = candidate.get(key,null)
			if not (value is int) or int(value)<0 or int(value)>MAX_UNITS: valid=false
		if not valid: continue
		var total_work := int(candidate.work_total_u)
		if total_work<1 or int(candidate.work_done_u)>total_work or int(candidate.material_spent_u)>int(candidate.material_total_u): continue
		if int(candidate.material_spent_u)!=_ceil_ratio(int(candidate.material_total_u),int(candidate.work_done_u),total_work): continue
		var item: Dictionary=candidate.duplicate(true)
		item.priority=clampi(int(candidate.get("priority",0)),0,1)
		item.initial_work_u=int(item.work_done_u)
		item.initial_material_u=int(item.material_spent_u)
		result.append(item)
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return str(a.token)<str(b.token))
	return result

static func _advance(task: Dictionary, allowance: int, state: Dictionary, numerator: int, capacity: int) -> int:
	if allowance<=0: return 0
	var low := 0
	var high := mini(allowance,int(task.work_total_u)-int(task.work_done_u))
	while low<high:
		@warning_ignore("integer_division")
		var middle: int = low+(high-low+1)/2
		var material := _ceil_ratio(int(task.material_total_u),int(task.work_done_u)+middle,int(task.work_total_u))-int(task.material_spent_u)
		@warning_ignore("integer_division")
		var possible: int = ((allowance-middle)*numerator+int(state.rate_carry))/32
		if material<=mini(capacity,int(state.materials_u)+possible): low=middle
		else: high=middle-1
	if low==0:
		_produce(allowance,state,numerator,capacity)
		return allowance
	var cumulative := _ceil_ratio(int(task.material_total_u),int(task.work_done_u)+low,int(task.work_total_u))
	var consumed := cumulative-int(task.material_spent_u)
	var missing := maxi(0,consumed-int(state.materials_u))
	var production_work := 0
	if missing>0:
		@warning_ignore("integer_division")
		var needed_work: int = (missing*32-int(state.rate_carry)+numerator-1)/numerator
		production_work=needed_work
	_produce(production_work,state,numerator,capacity)
	state.materials_u=int(state.materials_u)-consumed
	state.used_u=int(state.used_u)+consumed
	state.work_u=int(state.work_u)+low
	task.work_done_u=int(task.work_done_u)+low
	task.material_spent_u=cumulative
	return low+production_work

static func _produce(work: int, state: Dictionary, numerator: int, capacity: int) -> void:
	if work<=0: return
	var scaled := work*numerator+int(state.rate_carry)
	@warning_ignore("integer_division")
	var produced: int = scaled/32
	var before := int(state.materials_u)
	state.materials_u=mini(capacity,before+produced)
	state.rate_carry=scaled%32 if int(state.materials_u)<capacity else 0
	state.produced_u=int(state.produced_u)+produced
	state.wasted_u=int(state.wasted_u)+maxi(0,before+produced-capacity)
	state.production_work_u=int(state.production_work_u)+work

static func _ceil_ratio(a: int, b: int, denominator: int) -> int:
	var value := _mul_div(a,b,denominator)
	return int(value.quotient)+(1 if int(value.remainder)>0 else 0)

## Exact quotient and remainder without overflowing a*b for the admitted bounds.
static func _mul_div(a: int, b: int, denominator: int) -> Dictionary:
	if a==0 or b==0: return {"quotient":0,"remainder":0}
	@warning_ignore("integer_division")
	var safe_limit: int = 9223372036854775807/b
	if a<=safe_limit:
		var product := a*b
		@warning_ignore("integer_division")
		var quotient: int = product/denominator
		return {"quotient":mini(MAX_UNITS,quotient),"remainder":product%denominator}
	@warning_ignore("integer_division")
	var term: int = a/denominator
	var remainder := a%denominator
	var count := b
	var result := 0
	var result_remainder := 0
	while count>0:
		if count&1:
			result=mini(MAX_UNITS,result+term)
			result_remainder+=remainder
			if result_remainder>=denominator:
				result=mini(MAX_UNITS,result+1)
				result_remainder-=denominator
		count=count>>1
		if count>0:
			term=mini(MAX_UNITS,term*2)
			remainder*=2
			if remainder>=denominator:
				term=mini(MAX_UNITS,term+1)
				remainder-=denominator
	return {"quotient":result,"remainder":result_remainder}
