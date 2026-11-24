extends RefCounted
## Pure bounded food-ledger boundary; no simulation or world mutation.
const Production = preload("res://scripts/RegionalProduction.gd")
const Civic = preload("res://scripts/CivicProvision.gd")
const RULES := {"version":1,"max_regions":256,"max_report_bytes":262144,"max_quantity":1000000000000,
	"empty_month":-1,"exact_fields":true,"integer_quanta":true,"conservation":true,
	"current_stock_and_satisfaction_match":true,"historical_owner_and_rations":true,
	"maximum_food_per_work":6,"maximum_farm_percent":75,"maximum_ration_percent":125,
	"shared_industry_budget":true,"satisfaction_labor_bound":true,"consume_before_overflow":true,"no_imports_or_exports":true,"no_simulation":true}
const QUANTITIES := ["before_u","produced_u","consumed_u","requested_u","shortfall_u","wasted_u","after_u","farm_work_u","industry_labor_u","total_labor_u"]
const LEDGER_FIELDS := ["owner","before_u","produced_u","consumed_u","requested_u","shortfall_u","wasted_u","after_u","farm_work_u","industry_labor_u","total_labor_u","satisfaction_before","satisfaction_after","rations"]
const RATIONS := {"scarce":75,"normal":100,"generous":125}

static func empty() -> Dictionary:
	return {"month_index":-1,"regions":{}}

static func validate(raw: Variant, state: Dictionary) -> Dictionary:
	if not _fields(raw,["month_index","regions"]): return _bad("Berichtsfelder")
	if not _integer(raw.month_index,-1,1000000000) or not raw.regions is Dictionary: return _bad("Berichtsmonat oder Regionstyp")
	if raw.regions.size()>int(RULES.max_regions): return _bad("Berichtsgrenze")
	if int(raw.month_index)==-1:
		return {"ok":true,"data":empty(),"reason":""} if raw.regions.is_empty() else _bad("Leerer Berichtsmonat")
	if not _integer(state.get("month_index"),0,1000000000) or int(raw.month_index)!=int(state.month_index): return _bad("Veralteter Berichtsmonat")
	if not state.get("provinces") is Array or not state.get("houses") is Array: return _bad("Weltkatalog")
	var catalog: Dictionary={}
	for p in state.provinces:
		if not p is Dictionary or not p.get("id") is String or p.id.is_empty() or p.id.length()>80 or catalog.has(p.id): return _bad("Regionskatalog")
		catalog[p.id]=p
	if catalog.is_empty() or catalog.size()>int(RULES.max_regions) or raw.regions.size()!=catalog.size(): return _bad("Unvollständige Regionsbilanz")
	var production = state.get("production_report",{})
	var compare_production := false
	if not production is Dictionary: return _bad("Produktionsberichtstyp")
	if not production.is_empty():
		if not _integer(production.get("month_index"),-1,1000000000): return _bad("Produktionsmonat")
		compare_production=int(production.month_index)==int(raw.month_index)
		if compare_production and not production.get("regions") is Dictionary: return _bad("Produktionsregionen")
	var regions: Dictionary={}
	var ids: Array=catalog.keys(); ids.sort()
	for id in ids:
		if not raw.regions.has(id) or not _fields(raw.regions[id],LEDGER_FIELDS): return _bad("Regionsbilanzfelder")
		var source: Dictionary=raw.regions[id]
		if not _integer(source.owner,0,state.houses.size()-1): return _bad("Historischer Bilanzbesitzer")
		if not source.rations is String or not RATIONS.has(source.rations): return _bad("Historische Ration")
		var row: Dictionary={"owner":int(source.owner),"rations":str(source.rations)}
		for key in QUANTITIES:
			if not _integer(source[key],0,int(RULES.max_quantity)): return _bad("Bilanzmenge: "+key)
			row[key]=int(source[key])
		for key in ["satisfaction_before","satisfaction_after"]:
			if not _integer(source[key],0,100): return _bad("Bilanzzufriedenheit")
			row[key]=int(source[key])
		var provision = catalog[id].get("provisioning")
		if not provision is Dictionary or not _integer(provision.get("food_u"),0,int(RULES.max_quantity)) or not _integer(provision.get("satisfaction"),0,100): return _bad("Aktueller Versorgungstand")
		if row.after_u!=int(provision.food_u) or row.satisfaction_after!=int(provision.satisfaction): return _bad("Örtlicher Endbestand oder Zufriedenheit")
		if row.before_u+row.produced_u-row.consumed_u-row.wasted_u!=row.after_u: return _bad("Nahrungserhaltung")
		if row.consumed_u!=mini(int(row.requested_u),int(row.before_u)+int(row.produced_u)) or row.shortfall_u!=row.requested_u-row.consumed_u: return _bad("Rationsfehlbedarf")
		var labor:=Production.labor_capacity_u(catalog[id])
		@warning_ignore("integer_division")
		var actual_labor: int=labor*mini(Civic.work_percent(int(row.satisfaction_before)),Civic.work_percent(int(row.satisfaction_after)))/100
		if row.total_labor_u>actual_labor or row.farm_work_u+row.industry_labor_u!=row.total_labor_u: return _bad("Gemeinsame Arbeit")
		@warning_ignore("integer_division")
		var before_labor: int=labor*Civic.work_percent(int(row.satisfaction_before))/100
		@warning_ignore("integer_division")
		var farm_limit: int=before_labor*int(RULES.maximum_farm_percent)/100
		if row.farm_work_u>farm_limit or row.produced_u>int(row.farm_work_u)*int(RULES.maximum_food_per_work): return _bad("Gewichtete Nahrungsproduktion")
		var numerator:=Production.weight_u(catalog[id])*int(RATIONS[row.rations])
		@warning_ignore("integer_division")
		var minimum_requested: int=numerator/100
		@warning_ignore("integer_division")
		var maximum_requested: int=(numerator+99)/100
		if row.requested_u<minimum_requested or row.requested_u>maximum_requested: return _bad("Gewichtete Rationsmenge")
		if compare_production:
			var actual = production.regions.get(id)
			if not actual is Dictionary: return _bad("Fehlende gleichmonatige Produktion")
			var used:=0
			for key in ["work_u","production_work_u","legacy_work_u"]:
				if not _integer(actual.get(key),0,int(RULES.max_quantity)): return _bad("Rohe Produktionsarbeit")
				used+=int(actual[key])
			if used>int(row.industry_labor_u): return _bad("Produktion überschreitet übrige Industriearbeit")
		regions[id]=row
	var result: Dictionary={"month_index":int(raw.month_index),"regions":regions}
	if JSON.stringify(result).to_utf8_buffer().size()>int(RULES.max_report_bytes): return _bad("Berichtsgröße")
	return {"ok":true,"data":result,"reason":""}

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size()!=fields.size(): return false
	for key in value:
		if not key is String or not fields.has(key): return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=minimum and float(value)<=maximum

static func _bad(reason: String) -> Dictionary:
	return {"ok":false,"data":{},"reason":reason}
