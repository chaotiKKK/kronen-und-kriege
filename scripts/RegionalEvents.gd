extends RefCounted
## Ort und Entscheidung kommen aus dem Zustand und einem festen Katalog.
const Civic = preload("res://scripts/CivicProvision.gd")
const Infrastructure = preload("res://scripts/Infrastructure.gd")
const DRAW_SHARE := 0.42
const MAX_RECENT := 6
const LOW_RESERVE := 2.0
const STORAGE_PRESSURE := 5.0
const LOW_SATISFACTION := 45
const SCENES := {
	"rat_vorrat":{"site":"vorrat","title":"Wie lange reichen die Speicher?","text":"Bei der Einberufung reichte der Vorrat für weniger als zwei normale Monatsrationen. Mit knapperen Rationen hält er länger, doch ein Teil der Bevölkerung wird unzufrieden.","art":"event_harvest","action":"ration","value":"scarce","label":"Rationen kürzen","hold":"Rationen beibehalten"},
	"rat_versorgung":{"site":"zufriedenheit","title":"Stimmen vor dem Speicher","text":"Die Leute klagen über die Versorgung. Der Rat hat genügend eingelagerten Vorrat für großzügigere Rationen gemeldet. Für die höhere Erzeugung kann künftig Arbeitskraft im Ausbau fehlen.","art":"event_court_reception","action":"ration","value":"generous","label":"Rationen erhöhen","hold":"Rationen beibehalten"},
	"rat_abgaben":{"site":"abgaben","title":"Die Abgaben stehen zur Debatte","text":"Abgeordnete aus der Provinz bitten um Entlastung. Niedrigere Abgaben lassen dem Haus künftig weniger Steuerertrag, entlasten aber die Zufriedenheit.","art":"event_tithe","action":"tax","value":"1","label":"Abgaben normalisieren","hold":"Hohe Abgaben beibehalten"},
	"rat_grenzmauer":{"site":"grenze","title":"Ein Heer jenseits der Grenze","text":"Die Grenzwache meldete ein fremdes Heer in der Nachbarschaft. Die Wache bittet darum, die Befestigung rechtzeitig auszubauen. Der Auftrag braucht Gold, Baustoffe und örtliche Arbeit.","art":"event_battle","action":"build","value":"walls","label":"Mauerbau beauftragen","hold":"Kasse für den Feldzug schonen"},
	"rat_markt":{"site":"strasse","title":"Ein Marktplatz an der neuen Straße","text":"Die fertige Straße bindet die Provinz an das eigene Wegenetz. Reisende Händler schlagen einen festen Marktplatz vor. Ein Bauauftrag würde den örtlichen Jahresertrag nach seiner Fertigstellung erhöhen.","art":"event_merchant","action":"build","value":"market","label":"Marktbau beauftragen","hold":"Beim bisherigen Handel bleiben"},
	"rat_lager":{"site":"lager","title":"Ein Lager für schlechte Monate","text":"Die gefüllten Speicher haben dem Rat gezeigt, wie viel von der Lagerung abhängt. Forschung zu Vorratslagern kann die zivile Lagerkapazität verdoppeln.","art":"event_monastery","action":"research","value":"granaries","label":"Vorratslager erforschen","hold":"Forschungskapazität freihalten"},
}
const RULES := {"revision":1,"draw_share":DRAW_SHARE,"recent":MAX_RECENT,"min_reserve_months":LOW_RESERVE,"storage_pressure_months":STORAGE_PRESSURE,"low_satisfaction":LOW_SATISFACTION,"one_ordinary_event_between":true,"scenes":SCENES,"pending_separator":"@"}

static func for_region(id: String, region: String) -> Dictionary:
	if not SCENES.has(id):
		return {}
	var scene: Dictionary = SCENES[id]
	return {"id":id,"region":region,"title":scene.title,"text":scene.text,"art":scene.art,"options":[
		{"label":scene.label,"effects":{}},{"label":scene.hold,"effects":{}}]}

static func choose(game, roll: float) -> Dictionary:
	if roll >= DRAW_SHARE:
		return {}
	var recent: Array = game.house().event_history
	if not recent.is_empty() and SCENES.has(str(recent[-1])):
		return {}
	var own: Array = game.owned()
	if own.is_empty():
		return {}
	var blocked: Dictionary = game._production_blocked()
	var roads := {}
	for road in game.roads:
		var a: Dictionary = game.province(str(road.from))
		var b: Dictionary = game.province(str(road.to))
		if str(road.state)=="complete" and a.get("owner")==game.player and b.get("owner")==game.player and not blocked.has(road.from) and not blocked.has(road.to):
			roads[road.from] = true
			roads[road.to] = true
	var hostile := {}
	for other in game.houses.size():
		if other==game.player or game.truce_until(other)>game._now():
			continue
		for army in game.houses[other].armies:
			if int(army.strength)>0 and int(army.morale)>0:
				hostile[army.province] = true
	var suitable: Array[Dictionary] = []
	for id in SCENES:
		if recent.has(id):
			continue
		var best:Dictionary = {}
		var priority := -INF
		for region in own:
			var region_id := str(region.id)
			var score := _site_score(str(SCENES[id].site),region,roads,hostile,game)
			if score == -INF or score<priority or (score==priority and region_id>=str(best.region)):
				continue
			var instance := for_region(id,region_id)
			if not str(option(game,instance,0).reason).is_empty():
				continue
			priority = score
			best = instance
		if not best.is_empty():
			suitable.append(best)
	if suitable.is_empty():
		return {}
	return suitable[mini(suitable.size()-1,int(roll/DRAW_SHARE*suitable.size()))]

static func _site_score(site: String, p: Dictionary, roads: Dictionary, hostile: Dictionary, game) -> float:
	var food_months := float(p.provisioning.food_u)/Civic.need_u(p)
	var satisfaction := int(p.provisioning.satisfaction)
	match site:
		"vorrat": return LOW_RESERVE-food_months if food_months<LOW_RESERVE else -INF
		"zufriedenheit": return float(100-satisfaction) if satisfaction<=LOW_SATISFACTION and food_months>=LOW_RESERVE else -INF
		"abgaben": return float(100-satisfaction) if satisfaction<=LOW_SATISFACTION and int(game.house().laws.tax)==2 else -INF
		"grenze":
			if int(p.buildings.walls)<2:
				for neighbor in game.neighbours(str(p.id)):
					if hostile.has(neighbor): return float(Civic.need_u(p))
		"strasse":
			if roads.has(p.id) and int(p.buildings.market)==0: return float(p.dev)
		"lager":
			if food_months>=STORAGE_PRESSURE: return food_months
	return -INF

static func option(game, event: Dictionary, index: int, execute: bool = false) -> Dictionary:
	if index==1:
		return _quote(0,"Bisherigen Kurs beibehalten.")
	var scene: Dictionary = SCENES.get(str(event.id),{})
	var id := str(event.region)
	var p: Dictionary = game.province(id)
	if scene.is_empty() or index!=0:
		return _quote(0,"","Unbekannte Ratsentscheidung.")
	if p.is_empty() or int(p.owner)!=game.player:
		return _quote(0,"","Diese Provinz gehört deinem Haus inzwischen nicht mehr.")
	if game.game_over:
		return _quote(0,"","Die Partie ist beendet.")
	var value := str(scene.value)
	match str(scene.action):
		"ration":
			var detail := "%d %% der normalen Ration · ab dem nächsten Monat" % Civic.ration_rate(value)
			if str(p.provisioning.rations)==value:
				return _quote(0,detail,"Diese Ration gilt bereits.")
			return game.set_province_rations(id,value) if execute else _quote(0,detail)
		"tax":
			var detail := "Normale Abgaben im ganzen Haus"
			if int(game.house().laws.tax)!=2:
				return _quote(0,detail,"Die Abgaben sind bereits gesenkt.")
			return game.set_law("tax",value) if execute else _quote(0,detail)
		"build":
			if execute: return game.build(id,value)
			var preview: Dictionary = game.regional_project_preview(id,value)
			return _quote(int(preview.gold),"Bauauftrag · örtliche Arbeit und Baustoffe",str(preview.reason))
		"research":
			var info: Dictionary = Infrastructure.INNOVATIONS[value]
			if execute: return game.start_research(value)
			return _quote(int(info.gold),"Forschung · %d Monate" % int(info.months),game._research_blocker(value,game.player))
	return _quote(0,"","Unbekannte Ratsentscheidung.")

static func _quote(cost: int, detail: String, reason: String = "") -> Dictionary:
	return {"cost":cost,"detail":detail,"reason":reason,"ok":reason.is_empty()}
