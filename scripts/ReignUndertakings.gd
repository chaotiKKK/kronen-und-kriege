extends RefCounted
## One optional active regional mandate for each house. All progress is derived
## from existing game state, and only Game may pay a completed mandate.
const Food = preload("res://scripts/CivicProvision.gd")
const Calendar = preload("res://scripts/CampaignCalendar.gd")
const MAX_SERIAL := 1000000000
const ORDER := ["roads","granary","watch"]
const CATALOG := {
	"roads":{"name":"Straßenbund","goal":"Verbinde zwei eigene Provinzen mit einer neuen Straße.","gold":28,"renown":4,"map":"economy"},
	"granary":{"name":"Kornkammer","goal":"Spezialisiere eine Provinz auf Landwirtschaft, erforsche Fruchtwechsel und fülle vier Monatsrationen.","gold":24,"renown":4,"map":"economy"},
	"watch":{"name":"Grenzwacht","goal":"Verstärke die Mauern am Grenzort um eine Stufe und stationiere dort ein eigenes Feldheer.","gold":35,"renown":5,"map":"war"},
}
const RULES := {"version":1,"catalog":CATALOG,"order":ORDER,"granary_months":4,
	"one_active_per_house":true,"each_once_per_campaign":true,"cancel_has_no_award":true,
	"watch_positive_strength_and_morale":true,"maximum_ticket":MAX_SERIAL}

static func empty() -> Dictionary:
	return {"serial":0,"active":{},"completed":{}}

static func offer(game, house: int, kind: String, id: String) -> Dictionary:
	if not CATALOG.has(kind): return {"ok":false,"reason":"Unbekanntes Reichsvorhaben."}
	var plan := {"id":kind,"province":id,"partner":"","wall_level":0}
	var p: Dictionary=game.province(id)
	if p.is_empty() or int(p.owner)!=house:
		return {"ok":false,"reason":"Wähle einen Ort im eigenen Land."}
	match kind:
		"roads":
			var neighbors: Array=game.neighbours(id).duplicate()
			neighbors.sort()
			for other in neighbors:
				if int(game.province(str(other)).get("owner",-1))==house and not _road_exists(game.roads,id,str(other)):
					plan.partner=str(other)
					break
			if plan.partner.is_empty(): return {"ok":false,"reason":"Keine freie Verbindung zu einer eigenen Nachbarprovinz."}
		"granary":
			if progress(game,house,plan).ready:
				return {"ok":false,"reason":"Dieser Ort erfüllt die Kornkammer bereits."}
		"watch":
			if not game.is_border_province(house,id) or int(p.buildings.walls)>=3:
				return {"ok":false,"reason":"Kein Grenzort mit ausbaubaren Mauern."}
			plan.wall_level=int(p.buildings.walls)+1
	return {"ok":true,"plan":plan}

static func progress(game, house: int, plan: Dictionary) -> Dictionary:
	var p: Dictionary=game.province(str(plan.province))
	var steps: Array=[]
	var reason := ""
	if p.is_empty() or int(p.owner)!=house:
		reason="Der Zielort gehört deinem Haus derzeit nicht."
	match str(plan.id):
		"roads":
			var q: Dictionary=game.province(str(plan.partner))
			if q.is_empty() or int(q.owner)!=house:
				reason="Mindestens einer der beiden Orte gehört deinem Haus derzeit nicht."
			steps.append({"done":_road_exists(game.roads,str(plan.province),str(plan.partner),true),
				"text":"Neue Straße fertigstellen"})
		"granary":
			var required:int=Food.need_u(p)*int(RULES.granary_months)
			var stored:int=int(p.get("provisioning",{}).get("food_u",0))
			var months:=float(stored)/maxi(1,Food.need_u(p))
			steps.append({"done":str(p.get("economic_focus",""))=="agriculture","text":"Provinzschwerpunkt Landwirtschaft"})
			steps.append({"done":game.houses[house].research.known.has("crop_rotation"),"text":"Fruchtwechsel erforschen"})
			steps.append({"done":stored>=required,"text":"Vorrat %s / %d Monatsrationen" % [("%.1f" % months).replace(".",","),int(RULES.granary_months)]})
		"watch":
			var walls:=int(p.get("buildings",{}).get("walls",0))
			steps.append({"done":walls>=int(plan.wall_level),
				"text":"Mauern %d / %d" % [walls,int(plan.wall_level)]})
			var stationed:bool=game.houses[house].armies.any(func(army):
				return str(army.province)==str(plan.province) and int(army.strength)>0 and int(army.morale)>0)
			steps.append({"done":stationed,"text":"Kampffähiges eigenes Feldheer vor Ort"})
	return {"ready":reason.is_empty() and not steps.is_empty() and steps.all(func(step): return bool(step.done)),
		"reason":reason,"steps":steps}

static func _road_exists(roads: Array, a: String, b: String, complete: bool=false) -> bool:
	for road in roads:
		if (road.from==a and road.to==b) or (road.from==b and road.to==a):
			if not complete or road.state=="complete": return true
	return false

static func save_errors(state: Dictionary) -> Array:
	var houses = state.get("houses",[])
	if not houses is Array: return []
	var errors: Array=[]
	var places := {}
	var provinces=state.get("provinces",[])
	for p in provinces if provinces is Array else []:
		if p is Dictionary and p.get("id") is String: places[p.id]=true
	var now:=Calendar.to_index(int(state.get("year",-2000)),int(state.get("month",1)))
	var adjacency: Dictionary={}
	for house in houses:
		if not house is Dictionary or not house.has("undertaking"): continue
		var raw = house.undertaking
		if not _fields(raw,["serial","active","completed"]) or not raw.completed is Dictionary or not raw.active is Dictionary or not _integer(raw.serial,1,MAX_SERIAL):
			errors.append("Ungültiger Zustand der Reichsvorhaben.")
			continue
		if raw.serial<raw.completed.size() or raw.completed.size()>ORDER.size():
			errors.append("Ungültige Reichsvorhabenskennung.")
		for kind in raw.completed:
			if not kind is String or not CATALOG.has(kind) or not _integer(raw.completed[kind],0,now):
				errors.append("Ungültiger Abschluss eines Reichsvorhabens.")
		var active: Dictionary=raw.active
		if active.is_empty(): continue
		if not _fields(active,["id","province","partner","wall_level","serial","started"]):
			errors.append("Ungültige Angaben zum laufenden Reichsvorhaben.")
			continue
		if not active.id is String or not CATALOG.has(active.id) or raw.completed.has(active.id) or not active.province is String or not places.has(active.province) or not active.partner is String or not _integer(active.serial,int(raw.serial),int(raw.serial)) or not _integer(active.started,0,now):
			errors.append("Unbekanntes Ziel oder falsche Kennung des Reichsvorhabens.")
			continue
		var watch: bool=active.id=="watch"
		if not _integer(active.wall_level,1 if watch else 0,3 if watch else 0):
			errors.append("Ungültige Mauerstufe im Reichsvorhaben.")
		if active.id=="roads":
			if adjacency.is_empty():
				var catalog=load("res://scripts/GameRegionData.gd") if state.get("world_layout","")=="regions108" else load("res://scripts/Data.gd")
				adjacency=catalog.adjacency()
			if not places.has(active.partner) or not adjacency.get(active.province,[]).has(active.partner):
				errors.append("Das Straßenziel muss landbenachbart sein.")
		elif not active.partner.is_empty():
			errors.append("Unerwarteter zweiter Zielort.")
	return errors

static func normalize(raw: Dictionary) -> void:
	raw.serial=int(raw.serial)
	for kind in raw.completed: raw.completed[kind]=int(raw.completed[kind])
	if not raw.active.is_empty():
		for field in ["serial","started","wall_level"]: raw.active[field]=int(raw.active[field])

static func _fields(value: Variant, fields: Array) -> bool:
	return value is Dictionary and value.size()==fields.size() and fields.all(func(field): return value.has(field))

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=minimum and value<=maximum
