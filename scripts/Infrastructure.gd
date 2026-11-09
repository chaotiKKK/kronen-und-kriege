extends RefCounted
## Reine Definitionen und Save-Prüfung; Zustandsänderungen bleiben in Game.
const INNOVATIONS := {
	"surveying": {"name": "Vermessung", "months": 6, "gold": 20, "requires": ""},
	"road_building": {"name": "Straßenbau", "months": 12, "gold": 40, "requires": "surveying"},
}
const DataScript = preload("res://scripts/Data.gd")

static func initial_research() -> Dictionary:
	return {"known": [], "active": "", "months": 0}

static func edge_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	var houses: Array = data.get("houses", [])
	for i in houses.size():
		var research = houses[i].get("research", null)
		if not (research is Dictionary) or not (research.get("known", null) is Array):
			errors.append("Forschungsstand von Haus %d fehlt oder ist ungültig." % i)
			continue
		var active := str(research.get("active", ""))
		var months := int(research.get("months", -1))
		var known: Array = research.known
		var seen := {}
		for innovation in known:
			if not INNOVATIONS.has(str(innovation)) or seen.has(str(innovation)):
				errors.append("Unbekannte oder doppelte Innovation.")
			seen[str(innovation)] = true
		if known.has("road_building") and not known.has("surveying"):
			errors.append("Straßenbau ohne Vermessung.")
		if active == "":
			if months != 0:
				errors.append("Forschungsdauer ohne Projekt.")
		elif not INNOVATIONS.has(active):
			errors.append("Unbekanntes Forschungsprojekt.")
		else:
			var info: Dictionary = INNOVATIONS[active]
			if months < 1 or months > int(info.months) or known.has(active) or (str(info.requires) != "" and not known.has(info.requires)):
				errors.append("Inkonsistentes Forschungsprojekt.")
	var provinces := {}
	for p in data.get("provinces", []):
		provinces[str(p.id)] = true
	var roads = data.get("roads", null)
	if not (roads is Array):
		errors.append("Straßennetz fehlt oder ist ungültig.")
		return errors
	var edges := {}
	var adjacency: Dictionary = DataScript.adjacency()
	for road in roads:
		if not (road is Dictionary):
			errors.append("Ungültiger Straßeneintrag.")
			continue
		var a := str(road.get("from", ""))
		var b := str(road.get("to", ""))
		var key := edge_key(a, b)
		var owner := int(road.get("builder", -1))
		var months := int(road.get("months", -1))
		var state := str(road.get("state", ""))
		if a == b or not provinces.has(a) or not provinces.has(b) or owner < 0 or owner >= houses.size() or edges.has(key):
			errors.append("Ungültige oder doppelte Straßenverbindung.")
		if not (adjacency.get(a, []) as Array).has(b):
			errors.append("Straßenendpunkte sind nicht benachbart.")
		if not ((state == "building" and months >= 1 and months <= 3) or (state == "complete" and months == 0)):
			errors.append("Ungültiger Straßenbauzustand.")
		edges[key] = true
	return errors
