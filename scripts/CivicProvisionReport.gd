extends RefCounted
## Pure bounded food-ledger boundary; no simulation or world mutation.
const Production = preload("res://scripts/RegionalProduction.gd")
const Civic = preload("res://scripts/CivicProvision.gd")
const Freight = preload("res://scripts/CivicFreight.gd")
const Transport = preload("res://scripts/MaterialTransport.gd")
const RULES := {"version":2,"max_regions":256,"max_flows":4096,"max_report_bytes":524288,"max_quantity":1000000000000,
	"empty_month":-1,"exact_fields":true,"integer_quanta":true,"conservation":true,
	"current_stock_and_satisfaction_match":true,"historical_owner_and_rations":true,
	"maximum_food_per_work":6,"maximum_farm_percent":75,"maximum_ration_percent":125,
	"shared_industry_budget":true,"satisfaction_labor_bound":true,"consume_before_overflow":true,"own_edge_freight_and_shared_usage":true,"no_simulation":true}
const QUANTITIES := ["before_u","produced_u","consumed_u","requested_u","shortfall_u","wasted_u","after_u","farm_work_u","industry_labor_u","total_labor_u"]
const LEDGER_FIELDS := ["owner","before_u","produced_u","consumed_u","requested_u","shortfall_u","wasted_u","after_u","farm_work_u","industry_labor_u","total_labor_u","satisfaction_before","satisfaction_after","rations"]
const RATIONS := {"scarce":75,"normal":100,"generous":125}

static func empty() -> Dictionary:
	return {"month_index":-1,"regions":{}}

static func validate(raw: Variant, state: Dictionary) -> Dictionary:
	var has_flows:bool=raw is Dictionary and raw.has("flows")
	var keys:Array=["month_index","regions","flows"] if has_flows else ["month_index","regions"]
	if not _fields(raw,keys): return _bad("Berichtsfelder")
	if has_flows and (not raw.flows is Array or raw.flows.is_empty()): return _bad("Nahrungsfrachtfelder")
	if not _integer(raw.month_index,-1,1000000000) or not raw.regions is Dictionary: return _bad("Berichtsmonat oder Regionstyp")
	if raw.regions.size()>int(RULES.max_regions): return _bad("Berichtsgrenze")
	if int(raw.month_index)==-1:
		return {"ok":true,"data":empty(),"reason":""} if raw.regions.is_empty() and not has_flows else _bad("Leerer Berichtsmonat")
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
	var freight:=_freight(raw.get("flows",[]),raw.regions,catalog,state.get("roads",[]))
	if not bool(freight.ok): return freight
	if compare_production and not freight.usage.is_empty() and not _shared_usage(freight.usage,production.get("edges")):
		return _bad("Nahrung und Baustoffe überbuchen gemeinsame Straße")
	var regions: Dictionary={}
	var ids: Array=catalog.keys(); ids.sort()
	for id in ids:
		var incoming:=int(freight.incoming.get(id,0))
		var outgoing:=int(freight.outgoing.get(id,0))
		var moved:=incoming>0 or outgoing>0
		var region_fields:Array=LEDGER_FIELDS+["import_u","export_u"] if moved else LEDGER_FIELDS
		if not raw.regions.has(id) or not _fields(raw.regions[id],region_fields): return _bad("Regionsbilanzfelder")
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
		if moved:
			if not _integer(source.import_u,incoming,incoming) or not _integer(source.export_u,outgoing,outgoing): return _bad("Fracht und Nahrungsbilanz widersprechen sich")
			if incoming>int(row.requested_u) or (incoming>0 and outgoing>0): return _bad("Unzulässige Frachtrationsmenge")
			if outgoing>0 and int(row.before_u)-outgoing-int(row.requested_u)<Freight.EXPORT_RESERVE*Civic.need_u(catalog[id]): return _bad("Örtliche Exportreserve unterschritten")
			row["import_u"]=incoming
			row["export_u"]=outgoing
		var available:int=int(row.before_u)+int(row.produced_u)+incoming-outgoing
		if available-row.consumed_u-row.wasted_u!=row.after_u: return _bad("Nahrungserhaltung")
		if row.consumed_u!=mini(int(row.requested_u),available) or row.shortfall_u!=row.requested_u-row.consumed_u: return _bad("Rationsfehlbedarf")
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
	if has_flows: result["flows"]=freight.flows
	if JSON.stringify(result).to_utf8_buffer().size()>int(RULES.max_report_bytes): return _bad("Berichtsgröße")
	return {"ok":true,"data":result,"reason":""}

static func _freight(raw: Array, balances: Dictionary, catalog: Dictionary, roads: Variant) -> Dictionary:
	var result := {"ok":true,"flows":[],"incoming":{},"outgoing":{},"usage":{}}
	if raw.is_empty(): return result
	if raw.size()>int(RULES.max_flows) or not roads is Array: return _bad("Frachtgrenze oder Straßenliste")
	var completed := {}
	for road in roads:
		if road is Dictionary and road.get("state")=="complete":
			completed[Transport.edge_key(str(road.from),str(road.to))]=true
	for shipment in raw:
		if not _fields(shipment,["from","to","path","amount_u"]): return _bad("Nahrungsfrachtfelder")
		if not shipment.from is String or not shipment.to is String or shipment.from==shipment.to or not _integer(shipment.amount_u,1,int(RULES.max_quantity)): return _bad("Nahrungsfrachtmenge oder Route")
		var path=shipment.path
		if not path is Array or path.size()<2 or path.size()>catalog.size() or path[0]!=shipment.from or path[-1]!=shipment.to: return _bad("Nahrungsfrachtweg")
		var seen := {}
		var owner = null
		for id in path:
			if not id is String or not catalog.has(id) or seen.has(id) or not balances.get(id) is Dictionary: return _bad("Unbekannter oder zyklischer Nahrungsfrachtweg")
			seen[id]=true
			if owner==null: owner=balances[id].get("owner")
			elif balances[id].get("owner")!=owner: return _bad("Nahrungsfracht über fremdes Gebiet")
		var amount:=int(shipment.amount_u)
		for i in path.size()-1:
			var key:=Transport.edge_key(str(path[i]),str(path[i+1]))
			if not completed.has(key): return _bad("Keine fertige Nahrungsfrachtkante")
			result.usage[key]=int(result.usage.get(key,0))+amount
			var capacity:int=int(Transport.RULES.capacity_per_edge_weight)*Production.edge_weight_u(catalog[path[i]],catalog[path[i+1]])
			if int(result.usage[key])>capacity: return _bad("Überbuchte Nahrungsfrachtkante")
		result.outgoing[shipment.from]=int(result.outgoing.get(shipment.from,0))+amount
		result.incoming[shipment.to]=int(result.incoming.get(shipment.to,0))+amount
		result.flows.append({"from":str(shipment.from),"to":str(shipment.to),"path":path.duplicate(),"amount_u":amount})
	return result

static func _shared_usage(food_usage: Dictionary, edges: Variant) -> bool:
	if not edges is Array: return false
	var found := 0
	for edge in edges:
		if not edge is Dictionary: return false
		var key := Transport.edge_key(str(edge.get("from","")),str(edge.get("to","")))
		if not food_usage.has(key): continue
		if edge.get("active",false)!=true or not _integer(edge.get("used_u"),0,int(RULES.max_quantity)) or not _integer(edge.get("capacity_u"),0,int(RULES.max_quantity)): return false
		if int(edge.used_u)+int(food_usage[key])>int(edge.capacity_u): return false
		found+=1
	return found==food_usage.size()

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size()!=fields.size(): return false
	for key in value:
		if not key is String or not fields.has(key): return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=minimum and float(value)<=maximum

static func _bad(reason: String) -> Dictionary:
	return {"ok":false,"data":{},"reason":reason}
