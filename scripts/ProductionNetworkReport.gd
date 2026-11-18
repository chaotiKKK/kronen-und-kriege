extends RefCounted
## Pure bounded DTO boundary. No Game/Save/Protocol dependency or simulation.
const Production = preload("res://scripts/RegionalProduction.gd")
const RULES := {"version":1,"max_regions":256,"max_edges":1402,"max_flows":4096,
	"max_path":256,"max_report_bytes":524288,"max_quantity":1000000000000,
	"empty_month":-1,"exact_fields":true,"integer_quanta":true,
	"conservation":true,"current_stock_match":true,"shared_edge_usage":true,
	"legacy_self_edge":"matching-world-legacy-inactive-zero-only",
	"no_simulation":true,"transient_only":true}
const QUANTITIES := ["before_u","produced_u","used_u","wasted_u","work_u","production_work_u","legacy_work_u","import_u","export_u","after_u"]
const LEDGER_FIELDS := ["owner","before_u","produced_u","used_u","wasted_u","work_u","production_work_u","legacy_work_u","import_u","export_u","after_u"]
const EDGE_REASONS := ["","Identical road endpoints.","Unknown road endpoint.","Road is not complete.","Road endpoints are not under the same own control.","Hostile occupation blocks the road."]

static func pack(report: Dictionary, state: Dictionary) -> Dictionary:
	var dto: Dictionary=report.duplicate(true) if not report.is_empty() else {"month_index":-1,"regions":{},"flows":[],"edges":[]}
	dto["version"]=int(RULES.version)
	var checked:=normalize(dto,state)
	if not bool(checked.ok): return {}
	var result: Dictionary=checked.data.duplicate(true) if not checked.data.is_empty() else {"month_index":-1,"regions":{},"flows":[],"edges":[]}
	result["version"]=int(RULES.version)
	return result

static func normalize(dto: Variant, state: Dictionary) -> Dictionary:
	if not _fields(dto,["version","month_index","regions","flows","edges"]): return _bad("Berichtsfelder")
	if not _integer(dto.version,1,1) or not dto.regions is Dictionary or not dto.flows is Array or not dto.edges is Array: return _bad("Berichtstyp")
	if dto.regions.size()>int(RULES.max_regions) or dto.edges.size()>int(RULES.max_edges) or dto.flows.size()>int(RULES.max_flows): return _bad("Berichtsgrenze")
	if not _integer(dto.month_index,-1,1000000000): return _bad("Berichtsmonat")
	if int(dto.month_index)==-1:
		return {"ok":true,"data":{},"reason":""} if dto.regions.is_empty() and dto.edges.is_empty() and dto.flows.is_empty() else _bad("Leerer Berichtsmonat")
	if not _integer(state.get("month_index"),0,1000000000) or int(dto.month_index)!=int(state.month_index): return _bad("Veralteter Berichtsmonat")
	if not state.get("provinces") is Array or not state.get("houses") is Array: return _bad("Weltkatalog")
	var catalog: Dictionary={}
	for p in state.provinces:
		if not p is Dictionary or not p.get("id") is String or p.id.is_empty() or p.id.length()>80 or catalog.has(p.id): return _bad("Regionskatalog")
		catalog[p.id]=p
	if catalog.is_empty() or dto.regions.size()!=catalog.size(): return _bad("Unvollständige Regionsbilanz")
	var regions: Dictionary={}
	var imports: Dictionary={}
	var exports: Dictionary={}
	var ids: Array=catalog.keys(); ids.sort()
	for id in ids:
		if not dto.regions.has(id) or not _fields(dto.regions[id],LEDGER_FIELDS): return _bad("Regionsbilanzfelder")
		var raw: Dictionary=dto.regions[id]
		if not _integer(raw.owner,0,state.houses.size()-1): return _bad("Bilanzbesitzer")
		var row: Dictionary={"owner":int(raw.owner)}
		for key in QUANTITIES:
			if not _integer(raw[key],0,int(RULES.max_quantity)): return _bad("Bilanzmenge")
			row[key]=int(raw[key])
		var capacity:=Production.stock_capacity_u(catalog[id])
		var labor:=Production.labor_capacity_u(catalog[id])
		if row.before_u>capacity or row.after_u>capacity or not catalog[id].get("production") is Dictionary or row.after_u!=catalog[id].production.get("materials_u"): return _bad("Örtlicher Endbestand")
		if row.work_u+row.production_work_u+row.legacy_work_u>labor: return _bad("Gemeinsame Arbeit")
		@warning_ignore("integer_division")
		var maximum_produced: int=(int(row.production_work_u)*40+31)/32
		if row.produced_u>maximum_produced or row.wasted_u>row.produced_u: return _bad("Produktionsgrenze")
		if row.used_u+row.wasted_u+row.export_u>row.before_u+row.produced_u: return _bad("Weiterexport eingetroffener Mengen")
		if row.before_u+row.produced_u+row.import_u-row.used_u-row.export_u-row.wasted_u!=row.after_u: return _bad("Materialerhaltung")
		regions[id]=row; imports[id]=0; exports[id]=0
	var edges: Array=[]
	var edge_index: Dictionary={}
	var usage: Dictionary={}
	var completed_roads: Dictionary={}
	var legacy_self_roads: Dictionary={}
	for road in state.get("roads",[]):
		if road is Dictionary and str(road.get("state",""))=="complete": completed_roads[_edge(str(road.get("from","")),str(road.get("to","")))]=true
		if road is Dictionary and road.get("legacy_connection") is bool and road.legacy_connection and str(road.get("from",""))==str(road.get("to","")):
			legacy_self_roads[str(road.get("from",""))]=true
	for raw in dto.edges:
		if not _fields(raw,["from","to","capacity_u","used_u","active","reason"]): return _bad("Kantenfelder")
		if not _known(raw.from,catalog) or not _known(raw.to,catalog) or str(raw.from)>str(raw.to) or not raw.active is bool or not raw.reason is String or not EDGE_REASONS.has(raw.reason): return _bad("Kantenbezeichner")
		if not _integer(raw.capacity_u,0,int(RULES.max_quantity)) or not _integer(raw.used_u,0,int(RULES.max_quantity)): return _bad("Kantenmenge")
		if raw.from==raw.to and (not legacy_self_roads.has(raw.from) or raw.active or int(raw.capacity_u)!=0 or int(raw.used_u)!=0 or raw.reason!="Identical road endpoints."): return _bad("Ungültige historische Selbstkante")
		var key:=_edge(str(raw.from),str(raw.to))
		if edge_index.has(key): return _bad("Doppelte Kante")
		var capacity: int=4*Production.edge_weight_u(catalog[raw.from],catalog[raw.to]) if raw.active else 0
		if int(raw.capacity_u)!=capacity or int(raw.used_u)>capacity or bool(raw.active)!=str(raw.reason).is_empty(): return _bad("Gemeinsame Kantenkapazität")
		if raw.active and not completed_roads.has(key): return _bad("Nicht vorhandene Transportkante")
		if raw.active and int(regions[raw.from].owner)!=int(regions[raw.to].owner): return _bad("Kantenbesitzer")
		edge_index[key]=edges.size(); usage[key]=0
		edges.append({"from":str(raw.from),"to":str(raw.to),"capacity_u":int(raw.capacity_u),"used_u":int(raw.used_u),"active":bool(raw.active),"reason":str(raw.reason)})
	var flows: Array=[]
	for raw in dto.flows:
		if not _fields(raw,["from","to","amount_u","path"]): return _bad("Lieferfelder")
		if not _known(raw.from,catalog) or not _known(raw.to,catalog) or raw.from==raw.to or not _integer(raw.amount_u,1,int(RULES.max_quantity)) or not raw.path is Array: return _bad("Liefermenge oder Ziel")
		if raw.path.size()<2 or raw.path.size()>mini(catalog.size(),int(RULES.max_path)) or raw.path[0]!=raw.from or raw.path[-1]!=raw.to: return _bad("Lieferpfad")
		var seen: Dictionary={}
		for id in raw.path:
			if not _known(id,catalog) or seen.has(id) or int(regions[id].owner)!=int(regions[raw.from].owner): return _bad("Zyklischer oder fremder Lieferpfad")
			seen[id]=true
		for index in raw.path.size()-1:
			var key:=_edge(str(raw.path[index]),str(raw.path[index+1]))
			if not edge_index.has(key) or not bool(edges[edge_index[key]].active): return _bad("Fehlende Lieferkante")
			usage[key]=int(usage[key])+int(raw.amount_u)
			if int(usage[key])>int(edges[edge_index[key]].capacity_u): return _bad("Überbuchte Lieferkante")
		exports[raw.from]=int(exports[raw.from])+int(raw.amount_u)
		imports[raw.to]=int(imports[raw.to])+int(raw.amount_u)
		flows.append({"from":str(raw.from),"to":str(raw.to),"amount_u":int(raw.amount_u),"path":raw.path.duplicate()})
	for id in ids:
		if int(imports[id])!=int(regions[id].import_u) or int(exports[id])!=int(regions[id].export_u): return _bad("Lieferung und Bilanz widersprechen sich")
	for key in edge_index:
		if int(usage[key])!=int(edges[edge_index[key]].used_u): return _bad("Lieferung und Kantenbelegung widersprechen sich")
	var result: Dictionary={"month_index":int(dto.month_index),"regions":regions,"flows":flows,"edges":edges}
	if JSON.stringify(result).to_utf8_buffer().size()>int(RULES.max_report_bytes): return _bad("Berichtsgröße")
	return {"ok":true,"data":result,"reason":""}

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size()!=fields.size(): return false
	for key in value:
		if not key is String or not fields.has(key): return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=minimum and float(value)<=maximum

static func _known(id: Variant, catalog: Dictionary) -> bool:
	return id is String and catalog.has(id)

static func _edge(a: String,b: String) -> String:
	return JSON.stringify([a,b] if a<b else [b,a])

static func _bad(reason: String) -> Dictionary:
	return {"ok":false,"data":{},"reason":reason}
