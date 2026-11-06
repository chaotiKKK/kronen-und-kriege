extends RefCounted
## Versioniertes Speicherformat für Banger Queens.
##
## Schema 4 ergänzt:
## - Schema-2-Felder: schema_version, provinces[].buildings, victory
## - Schema-3-Feld: houses[].legitimacy
## - Welle-2/3-Felder: factions, secrets, claims, armies, truces,
##   provinces[].defense/siege/siege_owner
##
## Schema 1 (Altstand) hat keinen schema_version-Schlüssel. Die Migration
## erhält alle vorhandenen Felder und ergänzt nur neue Pflichtfelder mit
## deterministischen Defaults. Sie überschreibt keine unbekannten Felder.

const CURRENT_VERSION := 4
const BUILDING_KEYS := ["market", "barracks", "walls"]

const REQUIRED_TOP_LEVEL := [
	"schema_version", "year", "month", "player", "speed", "event_timer",
	"game_over", "log", "pending", "houses", "provinces", "opinion",
	"cooldowns", "captive", "scandal", "custom", "victory",
]
const REQUIRED_PROVINCE := ["id", "name", "owner", "dev", "levy", "buildings", "defense", "siege", "siege_owner"]
const REQUIRED_HOUSE := [
	"name", "color", "gold", "prestige", "legitimacy", "capital", "realm", "ruler",
	"spouse", "children", "heir", "heir_age", "pregnant", "lover_house",
	"crest", "factions", "secrets", "claims", "armies", "truces",
]

## Migriert einen beliebigen Save-Stand auf das aktuelle Schema.
## Rückgabe: { ok, data, from_version, to_version, errors }.
static func migrate(data: Dictionary) -> Dictionary:
	var errors: Array = []
	var out: Dictionary = data.duplicate(true)
	var from_version: int = int(out.get("schema_version", 1))
	if from_version < 1:
		errors.append("Ungültige Schema-Version %d." % from_version)
	if from_version > CURRENT_VERSION:
		errors.append("Schema-Version %d ist neuer als unterstützt (%d)." % [from_version, CURRENT_VERSION])
		return {
			"ok": false, "data": out, "from_version": from_version,
			"to_version": CURRENT_VERSION, "errors": errors,
		}

	out["schema_version"] = CURRENT_VERSION
	out["year"] = int(out.get("year", -2000))
	out["month"] = int(out.get("month", 1))
	out["player"] = int(out.get("player", 0))
	out["speed"] = int(out.get("speed", 0))
	out["event_timer"] = int(out.get("event_timer", 9))
	out["game_over"] = bool(out.get("game_over", false))
	out["log"] = _string_array(out.get("log", []))
	out["pending"] = str(out.get("pending", ""))
	out["opinion"] = _int_array(out.get("opinion", []))
	out["cooldowns"] = _int_dict(out.get("cooldowns", {}))
	out["captive"] = _dictionary(out.get("captive", {}))
	out["scandal"] = int(out.get("scandal", 0))
	out["custom"] = bool(out.get("custom", false))
	out["victory"] = bool(out.get("victory", false))
	out["houses"] = _migrate_houses(out.get("houses", []), errors)
	out["provinces"] = _migrate_provinces(out.get("provinces", []), errors)

	return {
		"ok": errors.is_empty(), "data": out, "from_version": from_version,
		"to_version": CURRENT_VERSION, "errors": errors,
	}

## Erzeugt aus einem vollständigen Snapshot das aktuelle Schema.
static func make_current(data: Dictionary) -> Dictionary:
	var result: Dictionary = migrate(data)
	if not bool(result.get("ok", false)):
		push_error("SaveGame.make_current: " + "; ".join(result.get("errors", [])))
	return result["data"]

## Validiert die Pflichtstruktur eines aktuellen Schemas.
static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	# Pflichtfelder am Rohstand prüfen, bevor migrate() Defaults ergänzt.
	# Sonst würde validate() einen Feldverlust nie bemerken.
	if int(data.get("schema_version", 0)) != CURRENT_VERSION:
		errors.append("schema_version ist nicht %d." % CURRENT_VERSION)
	for key in REQUIRED_TOP_LEVEL:
		if not data.has(key):
			errors.append("Top-Level-Feld fehlt: %s" % key)
	var raw_houses = data.get("houses", [])
	if raw_houses is Array:
		for i in (raw_houses as Array).size():
			var h = raw_houses[i]
			if h is Dictionary:
				for key in REQUIRED_HOUSE:
					if not h.has(key):
						errors.append("houses[%d].%s fehlt." % [i, key])
	var raw_provinces = data.get("provinces", [])
	if raw_provinces is Array:
		for i in (raw_provinces as Array).size():
			var p = raw_provinces[i]
			if p is Dictionary:
				for key in REQUIRED_PROVINCE:
					if not p.has(key):
						errors.append("provinces[%d].%s fehlt." % [i, key])
	var result: Dictionary = migrate(data)
	if not bool(result.get("ok", false)):
		errors.append_array(result.get("errors", []))
	var d: Dictionary = result["data"]

	for key in REQUIRED_TOP_LEVEL:
		if not d.has(key):
			errors.append("Top-Level-Feld fehlt: %s" % key)

	if int(d.get("schema_version", 0)) != CURRENT_VERSION:
		errors.append("schema_version ist nicht %d." % CURRENT_VERSION)

	if not (d.get("houses", []) is Array) or (d.get("houses", []) as Array).is_empty():
		errors.append("houses ist leer oder kein Array.")
	else:
		for i in (d["houses"] as Array).size():
			var h = d["houses"][i]
			if not (h is Dictionary):
				errors.append("houses[%d] ist kein Dictionary." % i)
				continue
			for key in REQUIRED_HOUSE:
				if not h.has(key):
					errors.append("houses[%d].%s fehlt." % [i, key])

	if not (d.get("provinces", []) is Array) or (d.get("provinces", []) as Array).is_empty():
		errors.append("provinces ist leer oder kein Array.")
	else:
		for i in (d["provinces"] as Array).size():
			var p = d["provinces"][i]
			if not (p is Dictionary):
				errors.append("provinces[%d] ist kein Dictionary." % i)
				continue
			for key in REQUIRED_PROVINCE:
				if not p.has(key):
					errors.append("provinces[%d].%s fehlt." % [i, key])
			if p.get("buildings", {}) is Dictionary:
				for key in BUILDING_KEYS:
					if not (p["buildings"] as Dictionary).has(key):
						errors.append("provinces[%d].buildings.%s fehlt." % [i, key])
			else:
				errors.append("provinces[%d].buildings ist kein Dictionary." % i)

	if not (d.get("opinion", []) is Array):
		errors.append("opinion ist kein Array.")
	elif (d["opinion"] as Array).size() < (d.get("houses", []) as Array).size():
		errors.append("opinion ist kürzer als houses.")

	if not (d.get("cooldowns", {}) is Dictionary):
		errors.append("cooldowns ist kein Dictionary.")
	if not (d.get("captive", {}) is Dictionary):
		errors.append("captive ist kein Dictionary.")

	var player: int = int(d.get("player", -1))
	if player < 0 or player >= (d.get("houses", []) as Array).size():
		errors.append("player liegt außerhalb von houses.")
	return errors

## Kanonische, JSON-stabile Darstellung: sortierte Dict-Schlüssel und
## ganzzahlige Floats werden zu int. Damit ist ein JSON-Roundtrip vergleichbar.
static func canonical(value):
	if value is Dictionary:
		var out: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			out[str(key)] = canonical(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(canonical(item))
		return out
	if value is Color:
		return [value.r, value.g, value.b]
	if value is float:
		if is_equal_approx(value, round(value)):
			return int(round(value))
		return value
	if value == null or value is bool or value is int or value is String:
		return value
	return str(value)

## Liefert alle Unterschiede zwischen expected und actual. Leer = identisch.
static func diff(expected, actual, path: String = "") -> Array:
	var errors: Array = []
	var e = canonical(expected)
	var a = canonical(actual)
	if e is Dictionary and a is Dictionary:
		for key in e.keys():
			var child_path: String = str(key) if path == "" else "%s.%s" % [path, key]
			if not a.has(key):
				errors.append("%s fehlt." % child_path)
			else:
				errors.append_array(diff(e[key], a[key], child_path))
		for key in a.keys():
			if not e.has(key):
				var extra_path: String = str(key) if path == "" else "%s.%s" % [path, key]
				errors.append("%s ist unerwartet." % extra_path)
		return errors
	if e is Array and a is Array:
		if e.size() != a.size():
			errors.append("%s: Länge %d statt %d." % [path, a.size(), e.size()])
			return errors
		for i in e.size():
			errors.append_array(diff(e[i], a[i], "%s[%d]" % [path, i]))
		return errors
	if e is float and a is float:
		# JSON-Roundtrips verlieren wenige Float-Bits; das ist kein Zustandsverlust.
		if not is_equal_approx(e, a):
			errors.append("%s: %s statt %s." % [path, str(e), str(a)])
		return errors
	if e != a:
		errors.append("%s: %s statt %s." % [path, str(e), str(a)])
	return errors

static func state_equal(expected: Dictionary, actual: Dictionary) -> bool:
	return diff(expected, actual).is_empty()

static func _migrate_factions(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append({
					"name": str(item.get("name", "Faktion")),
					"power": clampi(int(item.get("power", 20)), 0, 100),
					"loyalty": clampi(int(item.get("loyalty", 60)), 0, 100),
				})
	if out.is_empty():
		out = [
			{"name": "Adel", "power": 20, "loyalty": 65},
			{"name": "Krieger", "power": 20, "loyalty": 60},
		]
	return out

static func _migrate_secrets(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append({
					"id": str(item.get("id", "")),
					"target": int(item.get("target", -1)),
					"kind": str(item.get("kind", "scandal")),
					"known": bool(item.get("known", false)),
				})
	return out

static func _migrate_claims(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append({
					"province": str(item.get("province", "")),
					"strength": clampi(int(item.get("strength", 1)), 1, 5),
					"expires": int(item.get("expires", 0)),
				})
	return out

static func _migrate_armies(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append({
					"id": int(item.get("id", out.size())),
					"province": str(item.get("province", "")),
					"strength": clampi(int(item.get("strength", 0)), 0, 5000),
					"upkeep": clampi(int(item.get("upkeep", 2)), 0, 50),
					"morale": clampi(int(item.get("morale", 100)), 0, 100),
				})
	return out

static func _migrate_truces(raw) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for key in raw.keys():
			out[str(key)] = int(raw[key])
	return out

static func _migrate_traits(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for value in raw:
			var trait_name: String = str(value)
			if trait_name != "" and not out.has(trait_name):
				out.append(trait_name)
	if out.is_empty():
		out = ["Loyal"]
	return out

static func _string_array(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for value in raw:
			out.append(str(value))
	return out

static func _int_array(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for value in raw:
			out.append(int(value))
	return out

static func _int_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for key in raw.keys():
			out[str(key)] = int(raw[key])
	return out

static func _dictionary(raw) -> Dictionary:
	if raw is Dictionary:
		return raw.duplicate(true)
	return {}

static func _migrate_houses(raw, errors: Array) -> Array:
	var out: Array = []
	if not (raw is Array):
		errors.append("houses ist kein Array.")
		return out
	for i in (raw as Array).size():
		var source = raw[i]
		if not (source is Dictionary):
			errors.append("houses[%d] ist kein Dictionary." % i)
			continue
		var h: Dictionary = source.duplicate(true)
		if h.get("color") is Color:
			var c: Color = h["color"]
			h["color"] = [c.r, c.g, c.b]
		h["legitimacy"] = clampi(int(h.get("legitimacy", 50)), 0, 100)
		h["factions"] = _migrate_factions(h.get("factions", []))
		h["secrets"] = _migrate_secrets(h.get("secrets", []))
		h["claims"] = _migrate_claims(h.get("claims", []))
		h["armies"] = _migrate_armies(h.get("armies", []))
		h["truces"] = _migrate_truces(h.get("truces", {}))
		var ruler = h.get("ruler", {})
		if ruler is Dictionary:
			ruler["traits"] = _migrate_traits(ruler.get("traits", []))
		else:
			h["ruler"] = {}
		var children = h.get("children", [])
		if children is Array:
			for child in children:
				if child is Dictionary:
					var education: String = str(child.get("education", "martial"))
					if education not in ["martial", "diplomacy", "stewardship", "intrigue"]:
						education = "martial"
					child["education"] = education
		out.append(h)
	return out

static func _migrate_provinces(raw, errors: Array) -> Array:
	var out: Array = []
	if not (raw is Array):
		errors.append("provinces ist kein Array.")
		return out
	for i in (raw as Array).size():
		var source = raw[i]
		if not (source is Dictionary):
			errors.append("provinces[%d] ist kein Dictionary." % i)
			continue
		var p: Dictionary = source.duplicate(true)
		p["id"] = str(p.get("id", ""))
		p["name"] = str(p.get("name", ""))
		p["owner"] = int(p.get("owner", 0))
		p["dev"] = int(p.get("dev", 1))
		p["levy"] = int(p.get("levy", 0))
		p["defense"] = clampi(int(p.get("defense", 0)), 0, 100)
		p["siege"] = clampi(int(p.get("siege", 0)), 0, 100)
		p["siege_owner"] = int(p.get("siege_owner", -1))
		var raw_buildings = p.get("buildings", {})
		var buildings: Dictionary = {}
		for key in BUILDING_KEYS:
			var value: int = 0
			if raw_buildings is Dictionary:
				value = int(raw_buildings.get(key, 0))
			buildings[key] = clampi(value, 0, 3)
		p["buildings"] = buildings
		out.append(p)
	return out
