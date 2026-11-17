extends RefCounted
## Reine Definitionen und Save-Prüfung; Zustandsänderungen bleiben in Game.
const INNOVATIONS := {
	"surveying": {"name":"Vermessung", "branch":"Verwaltung", "months":6, "gold":20, "requires":"", "description":"Land, Entfernungen und Besitz werden verlässlich erfasst.", "effect_text":"Eröffnet Straßenbau und weitere Wissenszweige.", "effects":{}},
	"road_building": {"name":"Straßenbau", "branch":"Logistik", "months":12, "gold":40, "requires":"surveying", "description":"Feste Verbindungen erschließen benachbarte eigene Gebiete.", "effect_text":"Schaltet örtliche Straßen frei: +2 Gold/Jahr je fertiger eigener Verbindung.", "effects":{}},
	"crop_rotation": {"name":"Fruchtwechsel", "branch":"Wirtschaft", "months":8, "gold":32, "requires":"surveying", "description":"Wechselnde Feldfrüchte schonen fruchtbare Böden.", "effect_text":"+10 % regionaler Grundertrag in Ebenen und Ackerland.", "terrains":["plains","farmland"], "effects":{"income_percent":10}},
	"irrigation": {"name":"Bewässerung", "branch":"Wirtschaft", "months":10, "gold":45, "requires":"crop_rotation", "description":"Gezielte Wasserverteilung verbessert Anbauflächen.", "effect_text":"+8 % regionaler Grundertrag in Ebenen, Ackerland und Steppe.", "terrains":["plains","farmland","steppe"], "effects":{"income_percent":8}},
	"accounting": {"name":"Buchführung", "branch":"Verwaltung", "months":8, "gold":35, "requires":"surveying", "description":"Einheitliche Listen machen Abgaben nachvollziehbar.", "effect_text":"+5 % Grundertrag in allen eigenen Regionen.", "effects":{"income_percent":5}},
	"masonry": {"name":"Steinbau", "branch":"Militär", "months":9, "gold":45, "requires":"surveying", "description":"Werkzeuge und Baupläne verringern den Materialverlust.", "effect_text":"−10 % Kosten für Markt, Kaserne und Mauern.", "effects":{"build_discount":10}},
	"fortification": {"name":"Befestigungskunst", "branch":"Militär", "months":12, "gold":60, "requires":"masonry", "description":"Gestaffelte Befestigungen schützen eigene Gebiete.", "effect_text":"+8 Prozentpunkte Verteidigung bei Feldschlachten.", "effects":{"defense":8}},
	"drill": {"name":"Gemeinsamer Drill", "branch":"Militär", "months":9, "gold":50, "requires":"surveying", "description":"Einheitliche Ausbildung erleichtert das Anwerben von Aufgeboten.", "effect_text":"−10 % Kosten der regionalen Truppenwerbung.", "effects":{"recruit_discount":10}},
	"logistics": {"name":"Versorgungswesen", "branch":"Logistik", "months":10, "gold":55, "requires":"road_building", "description":"Geplante Depots versorgen größere Heere.", "effect_text":"+20 % örtliche Versorgungskapazität für deine Armeen.", "effects":{"supply_percent":20}},
	"field_medicine": {"name":"Heilkunde", "branch":"Medizin", "months":10, "gold":55, "requires":"surveying", "description":"Gesammelte Behandlungserfahrung hilft dem Herrscher.", "effect_text":"+2 Herrschergesundheit beim Jahreswechsel.", "effects":{"health":2}},
	"sanitation": {"name":"Wasserhygiene", "branch":"Medizin", "months":12, "gold":65, "requires":"field_medicine", "description":"Sauberes Wasser und getrennte Abfälle mindern Krankheiten.", "effect_text":"Weitere +2 Herrschergesundheit beim Jahreswechsel.", "effects":{"health":2}},
	"trade_charters": {"name":"Handelsrechte", "branch":"Wirtschaft", "months":12, "gold":70, "requires":"accounting", "description":"Verlässliche Regeln stärken bestehende Marktorte.", "effect_text":"+8 % Einnahmen aus tatsächlich errichteten Märkten.", "effects":{"market_percent":8}},
	"engineering": {"name":"Ingenieurwesen", "branch":"Logistik", "months":14, "gold":80, "requires":"masonry", "description":"Hebewerkzeuge und standardisierte Pläne erleichtern große Vorhaben.", "effect_text":"−10 % regionale Ausbaukosten; +1 Belagerungsfortschritt je Aktion.", "effects":{"develop_discount":10,"siege":1}},
	"military_staff": {"name":"Heeresplanung", "branch":"Militär", "months":15, "gold":90, "requires":"drill", "description":"Abgestimmte Befehle verbessern den Einsatz deiner Aufgebote.", "effect_text":"+5 % Angriffskraft bei Feldschlachten.", "effects":{"attack_percent":5}},
	"granaries": {"name":"Vorratslager", "branch":"Logistik", "months":12, "gold":65, "requires":"crop_rotation", "description":"Lagerhäuser verteilen Nahrung über schlechte Jahreszeiten.", "effect_text":"Weitere +10 % örtliche Versorgungskapazität für deine Armeen.", "effects":{"supply_percent":10}},
	"administration": {"name":"Landesverwaltung", "branch":"Verwaltung", "months":12, "gold":75, "requires":"accounting", "description":"Regionale Verwalter stimmen Abgaben und Besitzlisten aufeinander ab.", "effect_text":"Weitere +5 % regionaler Grundertrag.", "effects":{"income_percent":5}},
}
const DataScript = preload("res://scripts/Data.gd")

static func initial_research() -> Dictionary:
	return {"known": [], "active": "", "months": 0}

static func edge_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	var event_ids := {}
	for event in DataScript.events():
		event_ids[str(event.id)] = true
	var houses: Array = data.get("houses", [])
	for i in houses.size():
		if not str(houses[i].get("doctrine", "balanced")) in ["balanced", "infantry", "cavalry", "siege"]:
			errors.append("Unbekannte Armeedoktrin.")
		var history = houses[i].get("event_history", [])
		if not history is Array or history.size() > 6:
			errors.append("Ungültige Ereignishistorie.")
		else:
			for id in history:
				if not id is String or not event_ids.has(id):
					errors.append("Unbekanntes Ereignis in der Historie.")
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
		for innovation in known:
			if INNOVATIONS.has(str(innovation)):
				var prerequisite := str(INNOVATIONS[str(innovation)].requires)
				if prerequisite != "" and not known.has(prerequisite):
					errors.append("Forschung ohne Voraussetzung: " + str(INNOVATIONS[str(innovation)].name))
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
	var regional := str(data.get("world_layout", "")) == "regions108"
	var adjacency: Dictionary = load("res://scripts/GameRegionData.gd").adjacency() if regional else DataScript.adjacency()
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
		var inherited := false
		if regional and bool(road.get("legacy_connection", false)):
			var originals: Array = data.get("migration_legacy", {}).get("roads", [])
			var origin := int(road.get("migration_origin", -1))
			if origin >= 0 and origin < originals.size():
				var old: Dictionary = originals[origin]
				inherited = (DataScript.adjacency().get(str(old.get("from", "")), []) as Array).has(str(old.get("to", "")))
		if (a == b and not inherited) or not provinces.has(a) or not provinces.has(b) or owner < 0 or owner >= houses.size() or (edges.has(key) and not inherited):
			errors.append("Ungültige oder doppelte Straßenverbindung.")
		if not inherited and not (adjacency.get(a, []) as Array).has(b):
			errors.append("Straßenendpunkte sind nicht benachbart.")
		if not ((state == "building" and months >= 1 and months <= 3) or (state == "complete" and months == 0)):
			errors.append("Ungültiger Straßenbauzustand.")
		edges[key] = true
	return errors
