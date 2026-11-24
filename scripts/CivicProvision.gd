extends RefCounted
## Pure civilian food plan. Game alone commits state, once per shared world month.
const Production = preload("res://scripts/RegionalProduction.gd")
const UNIT := Production.UNIT
const MAX_UNITS := Production.MAX_UNITS
const MAX_MONTH := Production.MAX_SERIAL
const STATE_FIELDS := ["food_u","harvest_carry","ration_carry","satisfaction","rations","changed_month"]
const RATIONS := {"scarce":75,"normal":100,"generous":125}
const HARVEST := {"balanced":200,"agriculture":300,"trade":160,"workshops":150}
const RULES := {
	"algorithm_version":2,"unit":UNIT,"max_units":MAX_UNITS,"max_month":MAX_MONTH,
	"state_fields":STATE_FIELDS,"normal_need_per_weight":1,"initial_rations":3,
	"base_storage_rations":6,"normal_reserve_rations":3,"agriculture_reserve_rations":6,
	"rations":RATIONS,"harvest_focus_numerator":HARVEST,"harvest_denominator":10000,
	"ration_denominator":100,"max_bonus_percent":100,"max_farm_labor_percent":75,
	"min_work_percent":80,"work_neutral_satisfaction":50,"work_slope_numerator":2,"work_slope_denominator":5,
	"income_min_percent":80,"income_max_percent":110,"income_neutral_satisfaction":50,
	"scarce_satisfaction_delta":-1,"normal_recovery_step":1,"generous_satisfaction_delta":2,"generous_recovery_cap":75,
	"tax_deltas":[1,0,-2],"maximum_shortfall_penalty":8,"max_owner":255,
	"freight_precedes_farm_and_rations":true,"blocked_consumes_existing_stock":true,
	"industry_uses_min_pre_post_labor":true,"raw_overcapacity_is_valid":true,
}

static func initial_state(region: Dictionary) -> Dictionary:
	return {"food_u":3*need_u(region),"harvest_carry":0,"ration_carry":0,
		"satisfaction":50,"rations":"normal","changed_month":-1}

## Validate raw JSON before integer conversion; neither canonicalize nor mutate here.
static func state_errors(raw: Variant, month_index: int) -> Array:
	var errors: Array=[]
	if month_index<0 or month_index>MAX_MONTH:
		errors.append("Der Versorgungsmonat ist ungültig.")
	if not raw is Dictionary:
		errors.append("Der zivile Vorratszustand fehlt oder ist kein Objekt.")
		return errors
	if raw.size()!=STATE_FIELDS.size():
		errors.append("Der zivile Vorratszustand muss genau sechs Felder enthalten.")
	for key in raw:
		if not key is String or not STATE_FIELDS.has(key):
			errors.append("Der zivile Vorratszustand enthält ein unbekanntes Feld.")
	for entry in [["food_u",0,MAX_UNITS],["harvest_carry",0,9999],["ration_carry",0,99],
		["satisfaction",0,100],["changed_month",-1,month_index]]:
		if not _integer(raw.get(entry[0]),int(entry[1]),int(entry[2])):
			errors.append("Ungültiger ganzzahliger Vorratswert: "+str(entry[0])+".")
	if not raw.get("rations") is String or not RATIONS.has(raw.get("rations")):
		errors.append("Die gewählte Ration ist unbekannt.")
	return errors

static func need_u(region: Dictionary) -> int:
	return Production.weight_u(region)

static func capacity_u(region: Dictionary, bonuses: Dictionary={}) -> int:
	if not _bonus_errors(bonuses).is_empty(): return 0
	@warning_ignore("integer_division")
	var capacity: int = 6*need_u(region)*(100+int(bonuses.get("storage_percent",0)))/100
	return capacity

static func work_percent(satisfaction: int) -> int:
	@warning_ignore("integer_division")
	var bonus: int = mini(clampi(satisfaction,0,100),50)*2/5
	return 80+bonus

static func income_percent(satisfaction: int) -> int:
	var numerator := (clampi(satisfaction,0,100)-50)*2
	@warning_ignore("integer_division")
	var delta: int = numerator/5
	# Integer division truncates toward zero; negative fractional effects must floor.
	if numerator<0 and numerator%5!=0: delta-=1
	return clampi(100+delta,80,110)

static func ration_rate(id: String) -> int:
	return int(RATIONS.get(id,0))

static func requested_u(region: Dictionary) -> int:
	var raw:Dictionary=region.provisioning
	@warning_ignore("integer_division")
	return (need_u(region)*ration_rate(str(raw.rations))+int(raw.ration_carry))/100

static func plan(region: Dictionary, month_index: int, tax_level: int, bonuses: Dictionary={}, blocked: bool=false, cargo_delta_u: int=0) -> Dictionary:
	var errors := state_errors(region.get("provisioning"),month_index)
	errors.append_array(_bonus_errors(bonuses))
	if tax_level<0 or tax_level>2: errors.append("Die Steuerstufe ist ungültig.")
	var focus = region.get("economic_focus","balanced")
	if not focus is String or not HARVEST.has(focus): errors.append("Der wirtschaftliche Schwerpunkt ist unbekannt.")
	if not _integer(region.get("owner"),0,int(RULES.max_owner)): errors.append("Der Besitzer der versorgten Region ist ungültig.")
	if not errors.is_empty(): return {"ok":false,"reason":" ".join(errors)}
	var raw: Dictionary=region.provisioning
	var original_stock := int(raw.food_u)
	var before := original_stock+cargo_delta_u
	if before<0 or before>MAX_UNITS or (blocked and cargo_delta_u!=0):
		return {"ok":false,"reason":"Ungültige gebuchte Nahrungsfracht."}
	var satisfaction_before := int(raw.satisfaction)
	var rations := str(raw.rations)
	var need := need_u(region)
	var ration_numerator := need*ration_rate(rations)+int(raw.ration_carry)
	@warning_ignore("integer_division")
	var requested: int = ration_numerator/100
	var capacity := capacity_u(region,bonuses)
	var reserve := mini(capacity,need*(6 if focus=="agriculture" else 3))
	var desired := maxi(0,reserve+requested-before)
	var original_labor := _labor(region,satisfaction_before)
	var farm_work := 0
	var produced := 0
	var harvest_carry := int(raw.harvest_carry)
	if not blocked:
		@warning_ignore("integer_division")
		var farm_limit: int = original_labor*75/100
		var numerator := int(HARVEST[focus])*(100+int(bonuses.get("harvest_percent",0)))
		var needed_numerator := maxi(0,desired*10000-harvest_carry)
		@warning_ignore("integer_division")
		var needed_work: int = (needed_numerator+numerator-1)/numerator
		farm_work=mini(farm_limit,needed_work)
		var harvest_numerator := farm_work*numerator+harvest_carry
		@warning_ignore("integer_division")
		produced=harvest_numerator/10000
		harvest_carry=harvest_numerator%10000
	var consumed := mini(requested,before+produced)
	var shortfall := requested-consumed
	var wasted := maxi(0,before+produced-consumed-capacity)
	var after := before+produced-consumed-wasted
	var satisfaction_after := _satisfaction(satisfaction_before,rations,tax_level,requested,shortfall)
	var total_labor := 0 if blocked else mini(original_labor,_labor(region,satisfaction_after))
	var industry_labor := maxi(0,total_labor-farm_work)
	var state := {"food_u":after,"harvest_carry":harvest_carry,"ration_carry":ration_numerator%100,
		"satisfaction":satisfaction_after,"rations":rations,"changed_month":int(raw.changed_month)}
	var ledger := {"owner":int(region.owner),"before_u":original_stock,"produced_u":produced,"consumed_u":consumed,
		"requested_u":requested,"shortfall_u":shortfall,"wasted_u":wasted,"after_u":after,
		"farm_work_u":farm_work,"industry_labor_u":industry_labor,"total_labor_u":total_labor,
		"satisfaction_before":satisfaction_before,"satisfaction_after":satisfaction_after,"rations":rations}
	if cargo_delta_u!=0:
		ledger["import_u"]=maxi(0,cargo_delta_u)
		ledger["export_u"]=maxi(0,-cargo_delta_u)
	return {"ok":true,"reason":"","state":state,"ledger":ledger}

static func _labor(region: Dictionary, satisfaction: int) -> int:
	@warning_ignore("integer_division")
	var result: int = Production.labor_capacity_u(region)*work_percent(satisfaction)/100
	return result

static func _satisfaction(before: int, rations: String, tax: int, requested: int, shortfall: int) -> int:
	var ration_delta := -1 if rations=="scarce" else (signi(50-before) if rations=="normal" else mini(2,maxi(0,75-before)))
	var penalty := 0
	if shortfall>0:
		ration_delta=mini(0,ration_delta)
		@warning_ignore("integer_division")
		penalty=clampi((8*shortfall+requested-1)/requested,1,8)
	return clampi(before+ration_delta+int(RULES.tax_deltas[tax])-penalty,0,100)

static func _bonus_errors(bonuses: Dictionary) -> Array:
	var errors: Array=[]
	for key in bonuses:
		if not key is String or not ["harvest_percent","storage_percent"].has(key):
			errors.append("Der Versorgungsbonus enthält ein unbekanntes Feld.")
		elif not _integer(bonuses[key],0,100):
			errors.append("Ein Versorgungsbonus liegt nicht als ganze Zahl zwischen null und hundert vor.")
	return errors

static func _integer(value: Variant, low: int, high: int) -> bool:
	if value is int: return int(value)>=low and int(value)<=high
	return value is float and is_finite(value) and value==floor(value) and value>=low and value<=high
