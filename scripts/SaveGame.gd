extends RefCounted
## Versioniertes Speicherformat für Banger Queens.
##
## Schema 11 ergänzt:
## - Schema-2-Felder: schema_version, provinces[].buildings, victory
## - Schema-3-Feld: houses[].legitimacy
## - Welle-2/3-Felder: factions, secrets, claims, armies, truces,
##   provinces[].defense/siege/siege_owner
## - Seekrieg: houses[].fleets, provinces[].blockade/blockade_owner
## - Dynastie: houses[].renown, houses[].legacies
## - Vasallen/Rat: houses[].vassals, houses[].council (vier Sitze),
##   houses[].council_effects
## - Hof: houses[].court.relics/hall/grandeur/amenities
## - Glaube: houses[].faith.confession/piety/holy_sites/church_power
## - Ketzerei/Reform/Krieg: houses[].faith.heresy/reform/holy_war
##
## Schema 1 (Altstand) hat keinen schema_version-Schlüssel. Die Migration
## erhält alle vorhandenen Felder und ergänzt nur neue Pflichtfelder mit
## deterministischen Defaults. Sie überschreibt keine unbekannten Felder.
## Schema18 ergänzt rohe geprüfte Handelsverträge und deren globale Seriennummer.
## Vor18 entstehen ausschließlich leere Handelsfelder; bestehende Güter bleiben erhalten.

const CURRENT_VERSION := 19
const Production = preload("res://scripts/RegionalProduction.gd")
const MaterialTrade = preload("res://scripts/MaterialTrade.gd")
const Civic = preload("res://scripts/CivicProvision.gd")
const ProvisionReport = preload("res://scripts/CivicProvisionReport.gd")
const TRADE_INTEGER_FIELDS := ["id","seller","buyer","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots"]
const MAX_PRODUCTION_UNITS := Production.MAX_UNITS
const MAX_PROJECT_SERIAL := Production.MAX_SERIAL
const REGIONAL_PROJECT_FIELDS := ["id","builder","kind","target_level","paid_gold","material_total_u","material_spent_u","work_total_u","work_done_u","priority","started_month"]
const ROAD_CONSTRUCTION_FIELDS := ["id","paid_gold","priority","started_month","legs"]
const CONSTRUCTION_LEG_FIELDS := ["province","material_total_u","material_spent_u","work_total_u","work_done_u"]
const CampaignLimits = preload("res://scripts/CampaignLimits.gd")
const MAX_ARMY_STRENGTH := CampaignLimits.MAX_ARMY_STRENGTH
const MAX_ARMY_UPKEEP := CampaignLimits.MAX_ARMY_UPKEEP
const RegionMigrationScript = preload("res://scripts/RegionMigration.gd")
const CalendarScript = preload("res://scripts/CampaignCalendar.gd")
const InfrastructureScript = preload("res://scripts/Infrastructure.gd")
const ProvinceEconomyScript = preload("res://scripts/ProvinceEconomy.gd")
const RELIC_IDS := ["crown", "blade", "seal"]
const COURT_MAX_HALL := 3
const COURT_BASE_GRANDEUR := 20
const COURT_GRANDEUR_RELIC := 15
const COURT_GRANDEUR_HALL := 15
const COURT_AMENITY_IDS := ["table", "chambers", "retinue"]
const COURT_AMENITY_MAX := 3
const COURT_AMENITY_GRANDEUR := 5
const FAITH_ORDER := ["sun", "moon", "earth"]
const FAITH_START_PIETY := 20
const FAITH_MAX_PIETY := 100
const FAITH_MAX_SITES := 3
const FAITH_CHURCH_BASE := 5
const FAITH_CHURCH_SITE := 10
const FAITH_CHURCH_RELIC := 5
const FAITH_CHURCH_PIETY_DIV := 4
const FAITH_CHURCH_BONUS := {"sun": 6, "moon": 3, "earth": 0}
const FAITH_MAX_HERESY := 100
const FAITH_MAX_REFORM := 3
const FAITH_REFORM_POWER := 4
const FAITH_HOLY_WAR_MONTHS := 24
const LEGACY_TRACKS := ["war", "crown", "guile"]
const COUNCIL_ROLES := ["marshal", "chancellor", "steward", "spymaster"]
const VASSAL_COUNT := 3
const VASSAL_MAX_LEVEL := 2
const BUILDING_KEYS := ["market", "barracks", "walls"]

const REQUIRED_TOP_LEVEL := [
	"schema_version", "year", "month", "player", "speed", "event_timer",
	"game_over", "log", "pending", "houses", "provinces", "opinion",
	"cooldowns", "captive", "scandal", "custom", "victory",
	"calendar_version", "month_index", "campaign_sandbox",
	"roads", "project_serial", "material_trades", "trade_serial", "provisioning_report",
]
const REQUIRED_PROVINCE := ["id", "name", "owner", "dev", "levy", "buildings", "defense", "siege", "siege_owner", "blockade", "blockade_owner", "economic_focus", "focus_changed_month", "production", "regional_project", "logistics_sites", "provisioning"]
const REQUIRED_HOUSE := [
	"name", "color", "gold", "prestige", "legitimacy", "capital", "realm", "ruler",
	"spouse", "children", "heir", "heir_age", "pregnant", "lover_house",
	"crest", "factions", "secrets", "claims", "armies", "fleets", "truces",
	"renown", "legacies", "council", "council_effects", "vassals", "court", "faith",
]

## Migriert einen beliebigen Save-Stand auf das aktuelle Schema.
## Rückgabe: { ok, data, from_version, to_version, errors }.
static func migrate(data: Dictionary) -> Dictionary:
	var errors: Array = []
	var out: Dictionary = data.duplicate(true)
	if out.has("schema_version") and not _bounded_integer(out.schema_version,1,CURRENT_VERSION):
		return {"ok":false,"data":out,"from_version":0,"to_version":CURRENT_VERSION,"errors":["Ungültige oder nicht unterstützte Schema-Version."]}
	var from_version: int = int(out.get("schema_version", 1))
	errors.append_array(_research_fields(out,from_version))
	errors.append_array(_siege_dates(out))
	errors.append_array(_focus_fields(out,from_version >= 14))
	errors.append_array(_naval_dates(out,from_version >= 15))
	errors.append_array(_army_bounds(out,from_version >= 16))
	errors.append_array(_production_fields(out,from_version >= 17))
	errors.append_array(_trade_fields(out,from_version >= 18))
	errors.append_array(_provision_fields(out,from_version >= 19))
	if not errors.is_empty():
		return {"ok":false,"data":out,"from_version":from_version,"to_version":CURRENT_VERSION,"errors":errors}
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
	var calendar_version := int(out.get("calendar_version", 0))
	if calendar_version == 0:
		# Legacy-Zählung enthielt Jahr null. Dauer und absolute Fristen bewahren.
		if int(out["year"]) >= 0:
			out["year"] = int(out["year"]) + 1
	elif calendar_version != 1:
		errors.append("Unbekanntes Kalenderformat.")
	var month_index := CalendarScript.to_index(int(out["year"]), int(out["month"]))
	if month_index < 0:
		errors.append("Ungültiges Kampagnendatum.")
	if calendar_version == 1 and (not out.has("month_index") or int(out["month_index"]) != month_index):
		errors.append("Datum und Monatsindex widersprechen sich.")
	out["calendar_version"] = 1
	out["month_index"] = month_index
	out["campaign_sandbox"] = bool(out.get("campaign_sandbox", false))
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
	if not out.has("project_serial"):
		out["project_serial"] = 0
	out["project_serial"] = int(out["project_serial"])
	# The pure trade contract has already validated every raw numeric value.
	# Historical worlds acquire empty bookkeeping, never invented deliveries.
	if not out.has("material_trades"): out["material_trades"] = []
	if not out.has("trade_serial"): out["trade_serial"] = 0
	out["trade_serial"] = int(out["trade_serial"])
	for contract in out["material_trades"]:
		for field in TRADE_INTEGER_FIELDS: contract[field] = int(contract[field])
	out["houses"] = _migrate_houses(out.get("houses", []), errors)
	out["provinces"] = _migrate_provinces(out.get("provinces", []), errors)
	if not out.has("provisioning_report"): out["provisioning_report"] = ProvisionReport.empty()
	var provision_report: Dictionary = ProvisionReport.validate(out["provisioning_report"],out)
	if not provision_report.ok: errors.append("Ungültiger ziviler Monatsbericht: "+str(provision_report.reason))
	else: out["provisioning_report"] = provision_report.data
	for h in out["houses"]:
		if not h.has("research"):
			if from_version >= 12:
				errors.append("Forschungsstand fehlt im aktuellen Save.")
			h["research"] = InfrastructureScript.initial_research()
	if not out.has("roads"):
		out["roads"] = []
	for road in out["roads"]:
		if not road.has("construction"):
			road["construction"] = {}
		if from_version < 17 and str(road.get("state","")) == "building" and road.construction.is_empty():
			road["legacy_construction"] = true
		if not road.construction.is_empty():
			for field in ["id","paid_gold","priority","started_month"]:
				road.construction[field] = int(road.construction[field])
			for leg in road.construction.legs:
				for field in ["material_total_u","material_spent_u","work_total_u","work_done_u"]:
					leg[field] = int(leg[field])
	if str(out.get("world_layout", "")) == "regions108":
		errors.append_array(RegionMigrationScript.validate_current(out))
	errors.append_array(InfrastructureScript.validate(out))

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
	errors.append_array(_siege_dates(data))
	errors.append_array(_naval_dates(data,true))
	errors.append_array(_army_bounds(data,true))
	errors.append_array(_production_fields(data,true))
	errors.append_array(_trade_fields(data,true))
	errors.append_array(_provision_fields(data,true))
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
				if h.get("court", null) is Dictionary:
					var raw_court: Dictionary = h["court"]
					var raw_hall := int(raw_court.get("hall", 0))
					if raw_hall < 0 or raw_hall > COURT_MAX_HALL:
						errors.append("houses[%d].court.hall liegt außerhalb 0..%d." % [i, COURT_MAX_HALL])
					if raw_court.get("amenities", null) is Dictionary:
						for amenity_id in COURT_AMENITY_IDS:
							var raw_level := int((raw_court["amenities"] as Dictionary).get(amenity_id, 0))
							if raw_level < 0 or raw_level > COURT_AMENITY_MAX:
								errors.append("houses[%d].court.amenities.%s liegt außerhalb 0..%d." % [i, amenity_id, COURT_AMENITY_MAX])
					if raw_court.has("grandeur") and int(raw_court["grandeur"]) != _court_grandeur(raw_court):
						errors.append("houses[%d].court.grandeur ist nicht aus Reliquien, Halle und Ausstattung abgeleitet." % i)
				if h.get("faith", null) is Dictionary:
					var raw_faith: Dictionary = h["faith"]
					if raw_faith.has("church_power"):
						var raw_relic_count := _raw_relic_count(h.get("court", {}))
						if int(raw_faith["church_power"]) != _faith_church_power(raw_faith, raw_relic_count):
							errors.append("houses[%d].faith.church_power ist nicht aus Frömmigkeit, Stätten und Reliquien abgeleitet." % i)
					if raw_faith.has("heresy") and (int(raw_faith["heresy"]) < 0 or int(raw_faith["heresy"]) > FAITH_MAX_HERESY):
						errors.append("houses[%d].faith.heresy liegt außerhalb 0..%d." % [i, FAITH_MAX_HERESY])
					if raw_faith.has("reform") and (int(raw_faith["reform"]) < 0 or int(raw_faith["reform"]) > FAITH_MAX_REFORM):
						errors.append("houses[%d].faith.reform liegt außerhalb 0..%d." % [i, FAITH_MAX_REFORM])
					if raw_faith.has("holy_war"):
						var raw_war = raw_faith["holy_war"]
						if not (raw_war is Dictionary):
							errors.append("houses[%d].faith.holy_war ist kein Dictionary." % i)
						else:
							var raw_target := int((raw_war as Dictionary).get("target", -1))
							var raw_months := int((raw_war as Dictionary).get("months", 0))
							if raw_target < -1 or raw_target >= (raw_houses as Array).size() or raw_target == i or raw_months < 0 or raw_months > FAITH_HOLY_WAR_MONTHS:
								errors.append("houses[%d].faith.holy_war liegt außerhalb der Grenzen." % i)
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
		var known_provinces := {}
		for p in d.get("provinces", []):
			if p is Dictionary:
				known_provinces[str(p.get("id", ""))] = true
		for i in (d["houses"] as Array).size():
			var h = d["houses"][i]
			if not (h is Dictionary):
				errors.append("houses[%d] ist kein Dictionary." % i)
				continue
			for key in REQUIRED_HOUSE:
				if not h.has(key):
					errors.append("houses[%d].%s fehlt." % [i, key])
			if h.get("legacies", {}) is Dictionary:
				for track in LEGACY_TRACKS:
					if not (h["legacies"] as Dictionary).has(track):
						errors.append("houses[%d].legacies.%s fehlt." % [i, track])
			if h.get("council", {}) is Dictionary:
				for role in COUNCIL_ROLES:
					if not (h["council"] as Dictionary).has(role):
						errors.append("houses[%d].council.%s fehlt." % [i, role])
			else:
				errors.append("houses[%d].council ist kein Dictionary." % i)
			if h.get("vassals", []) is Array:
				if (h["vassals"] as Array).size() < VASSAL_COUNT:
					errors.append("houses[%d].vassals hat weniger als %d Einträge." % [i, VASSAL_COUNT])
				for vi in (h["vassals"] as Array).size():
					var v = h["vassals"][vi]
					if not (v is Dictionary):
						errors.append("houses[%d].vassals[%d] ist kein Dictionary." % [i, vi])
						continue
					if not v.has("name") or not v.has("level") or not v.has("opinion"):
						errors.append("houses[%d].vassals[%d] ist unvollständig." % [i, vi])
			else:
				errors.append("houses[%d].vassals ist kein Array." % i)
			if h.get("council_effects", {}) is Dictionary:
				if not (h["council_effects"] as Dictionary).has("intrigue"):
					errors.append("houses[%d].council_effects.intrigue fehlt." % i)
			else:
				errors.append("houses[%d].council_effects ist kein Dictionary." % i)
			if h.get("court", {}) is Dictionary:
				var court: Dictionary = h["court"]
				if not (court.get("relics", null) is Array):
					errors.append("houses[%d].court.relics ist kein Array." % i)
				else:
					for relic_id in (court["relics"] as Array):
						if not RELIC_IDS.has(str(relic_id)):
							errors.append("houses[%d].court.relics enthält unbekannte Reliquie %s." % [i, str(relic_id)])
				if not court.has("hall"):
					errors.append("houses[%d].court.hall fehlt." % i)
				if not court.has("grandeur"):
					errors.append("houses[%d].court.grandeur fehlt." % i)
				if court.has("grandeur") and int(court["grandeur"]) != _court_grandeur(court):
					errors.append("houses[%d].court.grandeur ist nicht aus Reliquien, Halle und Ausstattung abgeleitet." % i)
				var amenities = court.get("amenities", null)
				if not (amenities is Dictionary):
					errors.append("houses[%d].court.amenities fehlt oder ist kein Dictionary." % i)
				else:
					for amenity_id in COURT_AMENITY_IDS:
						if not (amenities as Dictionary).has(amenity_id):
							errors.append("houses[%d].court.amenities.%s fehlt." % [i, amenity_id])
						elif int((amenities as Dictionary)[amenity_id]) < 0 or int((amenities as Dictionary)[amenity_id]) > COURT_AMENITY_MAX:
							errors.append("houses[%d].court.amenities.%s liegt außerhalb 0..%d." % [i, amenity_id, COURT_AMENITY_MAX])
			else:
				errors.append("houses[%d].court ist kein Dictionary." % i)
			if h.get("faith", {}) is Dictionary:
				var faith: Dictionary = h["faith"]
				var confession: String = str(faith.get("confession", ""))
				if not FAITH_ORDER.has(confession):
					errors.append("houses[%d].faith.confession ist unbekannt." % i)
				if not faith.has("piety") or int(faith["piety"]) < 0 or int(faith["piety"]) > FAITH_MAX_PIETY:
					errors.append("houses[%d].faith.piety fehlt oder liegt außerhalb 0..%d." % [i, FAITH_MAX_PIETY])
				var sites = faith.get("holy_sites", null)
				if not (sites is Array):
					errors.append("houses[%d].faith.holy_sites ist kein Array." % i)
				else:
					if (sites as Array).size() > FAITH_MAX_SITES:
						errors.append("houses[%d].faith.holy_sites hat mehr als %d Einträge." % [i, FAITH_MAX_SITES])
					var seen_sites := {}
					for site_id in sites:
						var sid := str(site_id)
						if sid == "" or not known_provinces.has(sid):
							errors.append("houses[%d].faith.holy_sites enthält unbekannte Provinz %s." % [i, sid])
						elif seen_sites.has(sid):
							errors.append("houses[%d].faith.holy_sites enthält %s doppelt." % [i, sid])
						else:
							seen_sites[sid] = true
				if not faith.has("church_power"):
					errors.append("houses[%d].faith.church_power fehlt." % i)
				elif int(faith["church_power"]) != _faith_church_power(faith, _raw_relic_count(h.get("court", {}))):
					errors.append("houses[%d].faith.church_power ist nicht aus Frömmigkeit, Stätten und Reliquien abgeleitet." % i)
				if not faith.has("heresy"):
					errors.append("houses[%d].faith.heresy fehlt." % i)
				elif int(faith["heresy"]) < 0 or int(faith["heresy"]) > FAITH_MAX_HERESY:
					errors.append("houses[%d].faith.heresy liegt außerhalb 0..%d." % [i, FAITH_MAX_HERESY])
				if not faith.has("reform"):
					errors.append("houses[%d].faith.reform fehlt." % i)
				elif int(faith["reform"]) < 0 or int(faith["reform"]) > FAITH_MAX_REFORM:
					errors.append("houses[%d].faith.reform liegt außerhalb 0..%d." % [i, FAITH_MAX_REFORM])
				var war = faith.get("holy_war", null)
				if not (war is Dictionary):
					errors.append("houses[%d].faith.holy_war fehlt oder ist kein Dictionary." % i)
				else:
					var war_target := int((war as Dictionary).get("target", -1))
					var war_months := int((war as Dictionary).get("months", 0))
					if war_target < -1 or war_target >= (d["houses"] as Array).size():
						errors.append("houses[%d].faith.holy_war.target ist unbekannt." % i)
					elif war_target == i:
						errors.append("houses[%d].faith.holy_war.target ist das eigene Haus." % i)
					if war_months < 0 or war_months > FAITH_HOLY_WAR_MONTHS:
						errors.append("houses[%d].faith.holy_war.months liegt außerhalb 0..%d." % [i, FAITH_HOLY_WAR_MONTHS])
					elif war_target == -1 and war_months != 0:
						errors.append("houses[%d].faith.holy_war ohne Ziel hat Monate." % i)
					elif war_target >= 0 and war_months == 0:
						errors.append("houses[%d].faith.holy_war mit Ziel hat keine Monate." % i)
			else:
				errors.append("houses[%d].faith ist kein Dictionary." % i)

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

static func _migrate_legacies(raw) -> Dictionary:
	var out: Dictionary = {}
	for track in LEGACY_TRACKS:
		var level: int = 0
		if raw is Dictionary:
			level = int(raw.get(track, 0))
		out[track] = clampi(level, 0, 3)
	return out

static func _migrate_council(raw, courtiers) -> Dictionary:
	var out: Dictionary = {}
	var max_index: int = maxi(0, (courtiers as Array).size() - 1) if courtiers is Array else 0
	for role_index in COUNCIL_ROLES.size():
		var role: String = str(COUNCIL_ROLES[role_index])
		var value: int = role_index
		if raw is Dictionary and raw.has(role):
			value = int(raw[role])
		out[role] = clampi(value, 0, max_index)
	return out

static func _migrate_vassals(raw, h: Dictionary, house_index: int) -> Array:
	var courtiers: Array = h.get("courtiers", []) if h.get("courtiers", []) is Array else []
	var out: Array = []
	for n in VASSAL_COUNT:
		var item: Dictionary = {}
		if raw is Array and n < (raw as Array).size() and raw[n] is Dictionary:
			item = raw[n]
		var ci: int = clampi(int(item.get("courtier", n)), 0, maxi(0, courtiers.size() - 1))
		var fallback_name: String = "Vasall %d" % (n + 1)
		if ci < courtiers.size():
			fallback_name = str(courtiers[ci].get("name", fallback_name))
		out.append({
			"name": str(item.get("name", fallback_name)), "courtier": ci,
			"level": clampi(int(item.get("level", 1)), 0, VASSAL_MAX_LEVEL),
			"opinion": clampi(int(item.get("opinion", 50)), 0, 100),
		})
	return out

static func _migrate_council_effects(raw) -> Dictionary:
	var out: Dictionary = {"intrigue": 0, "history": []}
	if raw is Dictionary:
		out["intrigue"] = clampi(int(raw.get("intrigue", 0)), 0, 10)
		var history = raw.get("history", [])
		if history is Array:
			for item in history:
				if item is Dictionary:
					out["history"].append({
						"id": str(item.get("id", "")), "name": str(item.get("name", "")),
						"year": int(item.get("year", 0)), "month": int(item.get("month", 1)),
					})
			while out["history"].size() > 8:
				out["history"].pop_front()
	return out

static func _migrate_faith(raw, house_index: int, relic_count: int, house_count: int) -> Dictionary:
	var f: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var confession: String = str(f.get("confession", FAITH_ORDER[posmod(house_index, FAITH_ORDER.size())]))
	if not FAITH_ORDER.has(confession):
		confession = str(FAITH_ORDER[posmod(house_index, FAITH_ORDER.size())])
	f["confession"] = confession
	f["piety"] = clampi(int(f.get("piety", FAITH_START_PIETY)), 0, FAITH_MAX_PIETY)
	f["heresy"] = clampi(int(f.get("heresy", 0)), 0, FAITH_MAX_HERESY)
	f["reform"] = clampi(int(f.get("reform", 0)), 0, FAITH_MAX_REFORM)
	var raw_sites = f.get("holy_sites", [])
	var sites: Array = []
	if raw_sites is Array:
		for value in raw_sites:
			var site_id: String = str(value)
			if site_id != "" and not sites.has(site_id) and sites.size() < FAITH_MAX_SITES:
				sites.append(site_id)
	f["holy_sites"] = sites
	var raw_war = f.get("holy_war", {})
	var war: Dictionary = raw_war.duplicate(true) if raw_war is Dictionary else {}
	var war_target := int(war.get("target", -1))
	var war_months := clampi(int(war.get("months", 0)), 0, FAITH_HOLY_WAR_MONTHS)
	if war_target < 0 or war_target >= house_count or war_target == house_index or war_months <= 0:
		war_target = -1
		war_months = 0
	f["holy_war"] = {"target": war_target, "months": war_months}
	f["church_power"] = _faith_church_power(f, relic_count)
	return f

static func _faith_church_power(faith: Dictionary, relic_count: int) -> int:
	var confession: String = str(faith.get("confession", "sun"))
	var piety: int = clampi(int(faith.get("piety", FAITH_START_PIETY)), 0, FAITH_MAX_PIETY)
	var raw_sites = faith.get("holy_sites", [])
	var site_count: int = (raw_sites as Array).size() if raw_sites is Array else 0
	var bonus: int = int(FAITH_CHURCH_BONUS.get(confession, 0))
	var reform: int = clampi(int(faith.get("reform", 0)), 0, FAITH_MAX_REFORM)
	return clampi(FAITH_CHURCH_BASE + int(piety / FAITH_CHURCH_PIETY_DIV) + site_count * FAITH_CHURCH_SITE + relic_count * FAITH_CHURCH_RELIC + reform * FAITH_REFORM_POWER + bonus, 0, 100)

static func _raw_relic_count(court) -> int:
	if not (court is Dictionary):
		return 0
	var relics = (court as Dictionary).get("relics", [])
	return (relics as Array).size() if relics is Array else 0

static func _migrate_court(raw) -> Dictionary:
	var relics: Array = []
	if raw is Dictionary:
		var raw_relics = raw.get("relics", [])
		if raw_relics is Array:
			for value in raw_relics:
				var relic_id: String = str(value)
				if RELIC_IDS.has(relic_id) and not relics.has(relic_id):
					relics.append(relic_id)
	var hall: int = clampi(int(raw.get("hall", 0)), 0, COURT_MAX_HALL) if raw is Dictionary else 0
	var raw_amenities = raw.get("amenities", {}) if raw is Dictionary else {}
	var amenities: Dictionary = {}
	for amenity_id in COURT_AMENITY_IDS:
		amenities[amenity_id] = clampi(int((raw_amenities as Dictionary).get(amenity_id, 0)) if raw_amenities is Dictionary else 0, 0, COURT_AMENITY_MAX)
	var court := {"relics": relics, "hall": hall, "amenities": amenities}
	court["grandeur"] = _court_grandeur(court)
	return court

static func _court_grandeur(court: Dictionary) -> int:
	var relics = court.get("relics", [])
	var relic_count: int = relics.size() if relics is Array else 0
	var hall: int = clampi(int(court.get("hall", 0)), 0, COURT_MAX_HALL)
	var amenities = court.get("amenities", {})
	var amenity_total: int = 0
	if amenities is Dictionary:
		for amenity_id in COURT_AMENITY_IDS:
			amenity_total += clampi(int((amenities as Dictionary).get(amenity_id, 0)), 0, COURT_AMENITY_MAX)
	return clampi(COURT_BASE_GRANDEUR + relic_count * COURT_GRANDEUR_RELIC + hall * COURT_GRANDEUR_HALL + amenity_total * COURT_AMENITY_GRANDEUR, 0, 100)

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
				if not item.has("expires"):
					out[-1].erase("expires")
	return out

static func _focus_fields(data: Dictionary, required: bool) -> Array:
	var errors: Array = []
	var raw = data.get("provinces",[])
	if not raw is Array:
		return errors
	var year := int(data.get("year",-2000))
	if int(data.get("calendar_version",0)) == 0 and year >= 0:
		year += 1
	var now := CalendarScript.to_index(year,int(data.get("month",1)))
	for p in raw:
		if not p is Dictionary:
			continue
		if required or p.has("economic_focus"):
			var focus = p.get("economic_focus")
			if not focus is String or not ProvinceEconomyScript.FOCI.has(focus):
				errors.append("Ungültiger oder fehlender Provinzschwerpunkt.")
		if required or p.has("focus_changed_month"):
			var changed = p.get("focus_changed_month")
			if not (changed is int or changed is float) or not is_finite(float(changed)) or floor(changed) != changed or changed < -1 or changed > now:
				errors.append("Ungültiger oder fehlender Schwerpunktzeitpunkt.")
	return errors

static func _bounded_integer(value, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=minimum and value<=maximum

static func _research_fields(data: Dictionary, source_version: int) -> Array:
	var errors: Array=[]
	var houses = data.get("houses",[])
	if not houses is Array: return errors
	for house in houses:
		if not house is Dictionary: continue
		if not house.has("research"):
			if source_version>=12: errors.append("Forschungsstand fehlt im aktuellen Save.")
			continue
		var research = house.research
		if research is Dictionary and source_version<17:
			var active = research.get("active")
			if active is String and InfrastructureScript.LEGACY_RESEARCH_DURATIONS.has(active) and not research.has("legacy_duration"):
				research["legacy_duration"]=int(InfrastructureScript.LEGACY_RESEARCH_DURATIONS[active])
		var problems: Array=InfrastructureScript.research_errors(research)
		errors.append_array(problems)
		if problems.is_empty():
			research.months=int(research.months)
			if research.has("legacy_duration"): research.legacy_duration=int(research.legacy_duration)
	return errors

static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size()!=fields.size(): return false
	for field in fields:
		if not value.has(field): return false
	return true

static func _builder_knows(houses, builder, innovation: String) -> bool:
	if not houses is Array or not _bounded_integer(builder,0,houses.size()-1): return false
	var house = houses[int(builder)]
	if not house is Dictionary: return false
	var research = house.get("research")
	return research is Dictionary and research.get("known") is Array and research.known.has(innovation)

static func _construction_progress(value: Dictionary, allow_complete: bool) -> Array:
	var errors: Array = []
	for field in ["material_total_u","work_total_u"]:
		if not _bounded_integer(value.get(field),1,MAX_PRODUCTION_UNITS):
			errors.append("Ungültiger oder fehlender Baugesamtwert: "+field)
	for field in ["material_spent_u","work_done_u"]:
		if not _bounded_integer(value.get(field),0,MAX_PRODUCTION_UNITS):
			errors.append("Ungültiger oder fehlender Baufortschritt: "+field)
	if not errors.is_empty(): return errors
	var material: int = int(value.material_total_u)
	var work: int = int(value.work_total_u)
	var done: int = int(value.work_done_u)
	if done>work or (done==work and not allow_complete):
		errors.append("Abgeschlossener oder überhöhter Regionalbaufortschritt.")
		return errors
	# Shared exact quotient/remainder arithmetic never forms material*done,
	# which can overflow int64 even when all three bounded values are valid.
	var expected: int = Production.material_at_work(material,work,done)
	if int(value.material_spent_u)!=expected:
		errors.append("Materialverbrauch und kumulativer Arbeitsfortschritt widersprechen sich.")
	return errors

static func _trade_fields(data: Dictionary, required: bool) -> Array:
	var errors: Array = []
	if required:
		for field in ["material_trades","trade_serial"]:
			if not data.has(field): errors.append("Aktuelles Handelsfeld fehlt: "+field)
	var contracts = data.get("material_trades",[])
	var serial = data.get("trade_serial",0)
	if not contracts is Array:
		errors.append("Handelsverträge müssen als Liste gespeichert sein.")
	if not _bounded_integer(serial,0,MAX_PROJECT_SERIAL):
		errors.append("Ungültige globale Handelsnummer.")
	if not errors.is_empty(): return errors
	if int(data.get("schema_version",1))<18 and (not contracts.is_empty() or int(serial)!=0):
		return ["Historische Spielstände vor Schema18 können keine vergebenen Handelsnummern oder Verträge enthalten."]
	var provinces = data.get("provinces",[])
	var houses = data.get("houses",[])
	if not provinces is Array or not houses is Array:
		return ["Handelsregionen und Häuser müssen als Listen gespeichert sein."]
	var year := int(data.get("year",-2000))
	if int(data.get("calendar_version",0))==0 and year>=0: year+=1
	var now := CalendarScript.to_index(year,int(data.get("month",1)))
	var adjacency: Dictionary = {}
	if not contracts.is_empty():
		# Adjacency belongs to the immutable world catalog, never to saved input.
		adjacency = RegionMigrationScript.Regions.adjacency() if str(data.get("world_layout",""))=="regions108" else RegionMigrationScript.Legacy.adjacency()
	errors.append_array(MaterialTrade.validate(contracts,serial,provinces,houses,adjacency,now))
	return errors

static func _provision_fields(data: Dictionary, required: bool) -> Array:
	var errors: Array=[]
	var provinces = data.get("provinces",[])
	if not provinces is Array: return ["Zivile Versorgungsregionen müssen als Liste gespeichert sein."]
	var year := int(data.get("year",-2000))
	if int(data.get("calendar_version",0))==0 and year>=0: year+=1
	var now := CalendarScript.to_index(year,int(data.get("month",1)))
	for p in provinces:
		if not p is Dictionary: continue
		if not p.has("provisioning"):
			if required: errors.append("Aktueller ziviler Vorratszustand fehlt.")
			continue
		var problems: Array=Civic.state_errors(p.provisioning,now)
		errors.append_array(problems)
		if problems.is_empty() and not required and not state_equal(p.provisioning,Civic.initial_state(p)):
			errors.append("Historische Spielstände vor Schema19 können keine fortgeschrittenen zivilen Vorräte enthalten.")
	if not data.has("provisioning_report"):
		if required: errors.append("Aktueller ziviler Monatsbericht fehlt.")
		return errors
	var report_state: Dictionary=data.duplicate()
	report_state["month_index"]=now
	var report: Dictionary=ProvisionReport.validate(data.provisioning_report,report_state)
	if not report.ok:
		errors.append("Ungültiger roher ziviler Monatsbericht: "+str(report.reason))
	elif not required and not state_equal(report.data,ProvisionReport.empty()):
		errors.append("Historische Spielstände vor Schema19 können keine zivile Monatsabrechnung enthalten.")
	return errors

static func _production_fields(data: Dictionary, required: bool) -> Array:
	var errors: Array = []
	var serial = data.get("project_serial",0)
	if (required and not data.has("project_serial")) or not _bounded_integer(serial,0,MAX_PROJECT_SERIAL):
		errors.append("Ungültige oder fehlende globale Bauauftragsnummer.")
		serial = 0
	var now := CalendarScript.to_index(int(data.get("year",-2000)),int(data.get("month",1)))
	if int(data.get("calendar_version",0))==0 and int(data.get("year",-2000))>=0:
		now = CalendarScript.to_index(int(data.get("year",0))+1,int(data.get("month",1)))
	var houses = data.get("houses",[])
	var house_count: int = houses.size() if houses is Array else 0
	var provinces = data.get("provinces",[])
	if not provinces is Array: return ["Produktionsregionen müssen als Liste gespeichert sein."]
	var by_id: Dictionary = {}
	var ids: Dictionary = {}
	for p in provinces:
		if p is Dictionary: by_id[str(p.get("id",""))] = p
	for p in provinces:
		if not p is Dictionary: continue
		if required and p.get("buildings") is Dictionary and p.buildings.has("depot"):
			errors.append("Das Depot muss getrennt von den historischen Gebäudelinien gespeichert sein.")
		for field in ["production","regional_project","logistics_sites"]:
			if (required or p.has(field)) and not p.get(field) is Dictionary:
				errors.append("Ungültiges oder fehlendes Provinzfeld: "+field)
		var production = p.get("production")
		if production is Dictionary:
			if not _exact_fields(production,["materials_u","rate_carry"]) or not _bounded_integer(production.get("materials_u"),0,MAX_PRODUCTION_UNITS) or not _bounded_integer(production.get("rate_carry"),0,31):
				errors.append("Ungültiger Baustoffbestand oder Produktionsrest.")
			elif int(production.materials_u)>Production.stock_capacity_u(p):
				errors.append("Der Baustoffbestand überschreitet das örtliche Lager.")
		var sites = p.get("logistics_sites")
		if sites is Dictionary:
			if not _exact_fields(sites,["depot"]) or not _bounded_integer(sites.get("depot"),0,1):
				errors.append("Ungültiges örtliches Depot.")
		var project = p.get("regional_project")
		if not project is Dictionary or project.is_empty(): continue
		if not _exact_fields(project,REGIONAL_PROJECT_FIELDS):
			errors.append("Unvollständiger oder unbekannt erweiterter Regionalauftrag.")
			continue
		var project_id = project.get("id")
		if not _bounded_integer(project_id,1,MAX_PROJECT_SERIAL) or ids.has(int(project_id)) or project_id>serial:
			errors.append("Ungültige, doppelte oder nicht vergebene Bauauftragsnummer.")
		else: ids[int(project_id)] = true
		if not _bounded_integer(project.get("builder"),0,house_count-1) or project.builder!=p.get("owner"):
			errors.append("Der Regionalauftrag gehört nicht dem Provinzbesitzer.")
		if project.get("kind")=="depot" and not _builder_knows(houses,project.get("builder"),"logistics"):
			errors.append("Dem Depotbauherrn fehlt das erforschte Versorgungswesen.")
		if not _bounded_integer(project.get("paid_gold"),1,MAX_PRODUCTION_UNITS) or not _bounded_integer(project.get("priority"),0,1) or not _bounded_integer(project.get("started_month"),0,now):
			errors.append("Ungültige Zahlung, Priorität oder Startzeit des Regionalauftrags.")
		var kind = project.get("kind")
		var expected_target := -1
		var levels = p.get("buildings",{})
		if not levels is Dictionary:
			errors.append("Ungültige Gebäudestufen eines Bauauftrags.")
			continue
		if kind is String:
			if BUILDING_KEYS.has(kind): expected_target = int(levels.get(kind,0))+1
			elif kind=="develop" and _bounded_integer(project.get("target_level"),1,10):
				# Development events may change the live level while work is paid.
				# Its bounded start reference pins the recipe, not the current dev.
				expected_target = int(project.target_level)
			elif kind=="depot" and sites is Dictionary: expected_target = int(sites.get("depot",0))+1
		if expected_target<1 or not _bounded_integer(project.get("target_level"),expected_target,expected_target) or (BUILDING_KEYS.has(kind) and expected_target>3) or (kind=="depot" and expected_target>1) or (kind=="develop" and expected_target>10):
			errors.append("Ungültiges oder nicht mehr passendes Bauziel.")
		else:
			var requirement_province: Dictionary = p.duplicate(true)
			if kind=="develop": requirement_province.dev = expected_target-1
			var expected: Dictionary = Production.requirements(requirement_province,str(kind),expected_target)
			if expected.is_empty() or project.get("material_total_u")!=expected.get("material_total_u") or project.get("work_total_u")!=expected.get("work_total_u"):
				errors.append("Die gespeicherten Bauanforderungen passen nicht zum eingefrorenen Ziel.")
		errors.append_array(_construction_progress(project,false))
	var roads = data.get("roads",[])
	if required and not data.has("roads"): errors.append("Aktuelles Straßennetz fehlt.")
	if not roads is Array: return errors+["Straßenbaustellen müssen als Liste gespeichert sein."]
	# The region graph has226 undirected edges; legacy provenance may retain
	# up to the old49-region complete graph in addition. No unbounded queue.
	if roads.size()>1402: errors.append("Zu viele gespeicherte Straßen.")
	for road in roads:
		if not road is Dictionary:
			errors.append("Ungültige Straßenbaustelle.")
			continue
		var construction = road.get("construction")
		if not road.has("construction") and not required: continue
		if required and (not _bounded_integer(road.get("months"),0,3) or not road.get("state") is String or not _bounded_integer(road.get("builder"),0,house_count-1)):
			errors.append("Ungültige aktuelle Straßendauer oder Zustand.")
		if not construction is Dictionary:
			errors.append("Ungültige oder fehlende Straßenbaurechnung.")
			continue
		if road.has("legacy_construction") and (not road.legacy_construction is bool or road.legacy_construction!=true):
			errors.append("Ungültige Kennzeichnung einer alten Straßenbaustelle.")
		if str(road.get("state",""))=="complete":
			if not construction.is_empty(): errors.append("Fertige Straße besitzt noch einen Bauauftrag.")
			continue
		if construction.is_empty():
			if required and road.get("legacy_construction")!=true: errors.append("Historischer Straßenbau ist nicht gekennzeichnet.")
			continue
		if road.has("legacy_construction") or not _exact_fields(construction,ROAD_CONSTRUCTION_FIELDS):
			errors.append("Ungültige Felder einer neuen Straßenbaurechnung.")
			continue
		var project_id = construction.get("id")
		if not _bounded_integer(project_id,1,MAX_PROJECT_SERIAL) or ids.has(int(project_id)) or project_id>serial:
			errors.append("Ungültige, doppelte oder nicht vergebene Straßenauftragsnummer.")
		else: ids[int(project_id)] = true
		if not _bounded_integer(construction.get("paid_gold"),1,MAX_PRODUCTION_UNITS) or not _bounded_integer(construction.get("priority"),0,1) or not _bounded_integer(construction.get("started_month"),0,now):
			errors.append("Ungültige Zahlung, Priorität oder Startzeit einer Straße.")
		var a := str(road.get("from",""))
		var b := str(road.get("to",""))
		if a>=b or not by_id.has(a) or not by_id.has(b) or not _bounded_integer(road.get("builder"),0,house_count-1):
			errors.append("Ungültige neue Straßenendpunkte oder Bauherr.")
			continue
		if by_id[a].get("owner")!=road.builder or by_id[b].get("owner")!=road.builder:
			errors.append("Neue Straßenbaustelle besitzt einen fremden Endpunkt.")
		if not _builder_knows(houses,road.get("builder"),"road_building"):
			errors.append("Dem neuen Straßenbauherrn fehlt die Straßenbauforschung.")
		var legs = construction.get("legs")
		if not legs is Array or legs.size()!=2:
			errors.append("Eine Straßenbaustelle benötigt genau zwei Beine.")
			continue
		var both_complete := true
		var expected_road: Dictionary = Production.road_requirements(by_id[a],by_id[b])
		for i in 2:
			var leg = legs[i]
			if not leg is Dictionary or not _exact_fields(leg,CONSTRUCTION_LEG_FIELDS):
				errors.append("Ungültige Straßenbeinfelder.")
				continue
			if leg.get("province")!=([a,b][i]): errors.append("Straßenbeine und Endpunkte widersprechen sich.")
			if leg.get("material_total_u")!=expected_road.legs[i].material_total_u or leg.get("work_total_u")!=expected_road.legs[i].work_total_u:
				errors.append("Die Straßenanforderungen passen nicht zu den Endpunkten.")
			errors.append_array(_construction_progress(leg,true))
			both_complete = both_complete and leg.get("work_done_u") == leg.get("work_total_u")
		if both_complete: errors.append("Abgeschlossene Straßenbeine besitzen noch eine Baustelle.")
	return errors

static func _siege_dates(data: Dictionary) -> Array:
	var errors := []
	var year := int(data.get("year", -2000))
	# Dieselbe Legacy-Zeitachse wie migrate(): vorchristliche Daten bleiben
	# gleich, Jahr null entspricht 1 n. Chr. Absolute Monatsfristen bleiben.
	if int(data.get("calendar_version", 0)) == 0 and year >= 0:
		year += 1
	var now := CalendarScript.to_index(year, int(data.get("month", 1))) + 1
	var raw_houses = data.get("houses", [])
	if not raw_houses is Array:
		return ["Häuser müssen als Liste gespeichert sein."]
	for h in raw_houses:
		if not h is Dictionary:
			continue
		var raw_armies = h.get("armies", [])
		if not raw_armies is Array:
			errors.append("Armeen müssen als Liste gespeichert sein.")
			continue
		for army in raw_armies:
			if not army is Dictionary:
				continue
			if army.has("last_siege_month"):
				var v = army.last_siege_month
				if not (v is int or v is float) or not floor(v)==v or v<0 or v>now:
					errors.append("Ungültiger Belagerungszeitpunkt.")
	return errors

static func _naval_dates(data: Dictionary, required: bool) -> Array:
	var errors: Array = []
	var year := int(data.get("year",-2000))
	if int(data.get("calendar_version",0)) == 0 and year >= 0:
		year += 1
	var now := CalendarScript.to_index(year,int(data.get("month",1))) + 1
	var raw_houses = data.get("houses",[])
	if not raw_houses is Array: return errors
	for house in raw_houses:
		if not house is Dictionary: continue
		var fleets = house.get("fleets",[])
		if not fleets is Array:
			errors.append("Flotten müssen als Liste gespeichert sein.")
			continue
		for fleet in fleets:
			if not fleet is Dictionary:
				errors.append("Ungültiger Flotteneintrag.")
				continue
			if required or fleet.has("last_naval_month"):
				var used = fleet.get("last_naval_month")
				if not (used is int or used is float) or not is_finite(float(used)) or floor(used) != used or used < -1 or used == 0 or used > now:
					errors.append("Ungültiger oder fehlender Flottenaktionsmonat.")
	return errors

static func _army_bounds(data: Dictionary, required: bool) -> Array:
	var errors: Array = []
	# Historical formats retain their previous default/coercion semantics, with
	# widened bounds. Current raw values must never be silently clipped or filled.
	if not required: return errors
	var houses = data.get("houses",[])
	if not houses is Array: return errors
	for house in houses:
		if not house is Dictionary: continue
		var armies = house.get("armies",[])
		if not armies is Array:
			errors.append("Armeen müssen als Liste gespeichert sein.")
			continue
		for army in armies:
			if not army is Dictionary:
				errors.append("Ungültiger Armeeeintrag.")
				continue
			for field in ["strength","upkeep"]:
				var value = army.get(field)
				var maximum: int = MAX_ARMY_STRENGTH if field=="strength" else MAX_ARMY_UPKEEP
				if not (value is int or value is float) or not is_finite(float(value)) or floor(value)!=value or value<0 or value>maximum:
					errors.append("Ungültiger oder fehlender Armeewert: "+field)
	return errors

static func _migrate_armies(raw) -> Array:
	var out: Array = []
	var used_ids: Dictionary = {}
	var reserved_ids: Dictionary = {}
	if raw is Array:
		# Fehlende Alt-IDs dürfen eine später vorhandene stabile ID nicht belegen.
		for item in raw:
			if item is Dictionary and int(item.get("id", 0)) > 0:
				reserved_ids[int(item.id)] = true
		for item in raw:
			if item is Dictionary:
				if int(item.get("strength", 0)) <= 0:
					continue
				var army_id := int(item.get("id", 0))
				if army_id <= 0 or used_ids.has(army_id):
					army_id = 1
					while used_ids.has(army_id) or reserved_ids.has(army_id):
						army_id += 1
				used_ids[army_id] = true
				var army := {
					"id": army_id,
					"province": str(item.get("province", "")),
					"strength": clampi(int(item.get("strength", 0)), 0, MAX_ARMY_STRENGTH),
					"upkeep": clampi(int(item.get("upkeep", 2)), 0, MAX_ARMY_UPKEEP),
					"morale": clampi(int(item.get("morale", 100)), 0, 100),
				}
				if item.has("last_siege_month"):
					army["last_siege_month"] = item.last_siege_month
				out.append(army)
	return out

static func _migrate_fleets(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				var port_id: String = str(item.get("province", ""))
				if port_id == "":
					continue
				var ships: int = clampi(int(item.get("ships", 0)), 0, 40)
				if ships <= 0:
					continue
				var station: String = str(item.get("station", port_id))
				out.append({
					"id": int(item.get("id", out.size() + 1)),
					"province": port_id,
					"station": station if station != "" else port_id,
					"ships": ships,
					"upkeep": clampi(int(item.get("upkeep", maxi(1, int(ceil(float(ships) / 10.0))))), 0, 10),
					"morale": clampi(int(item.get("morale", 100)), 0, 100),
					"last_naval_month": int(item.get("last_naval_month",-1)),
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
		h["renown"] = maxi(0, int(h.get("renown", 80)))
		h["legacies"] = _migrate_legacies(h.get("legacies", {}))
		h["factions"] = _migrate_factions(h.get("factions", []))
		h["council"] = _migrate_council(h.get("council", {}), h.get("courtiers", []))
		h["council_effects"] = _migrate_council_effects(h.get("council_effects", {}))
		h["vassals"] = _migrate_vassals(h.get("vassals", []), h, i)
		h["court"] = _migrate_court(h.get("court", {}))
		h["faith"] = _migrate_faith(h.get("faith", {}), i, _raw_relic_count(h["court"]), (raw as Array).size())
		h["secrets"] = _migrate_secrets(h.get("secrets", []))
		h["claims"] = _migrate_claims(h.get("claims", []))
		h["armies"] = _migrate_armies(h.get("armies", []))
		h["fleets"] = _migrate_fleets(h.get("fleets", []))
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
		p["blockade"] = clampi(int(p.get("blockade", 0)), 0, 24)
		p["blockade_owner"] = int(p.get("blockade_owner", -1))
		if not p.has("economic_focus"):
			p["economic_focus"] = "balanced"
		if not p.has("focus_changed_month"):
			p["focus_changed_month"] = -1
		if int(p["blockade"]) <= 0:
			p["blockade_owner"] = -1
		var raw_buildings = p.get("buildings", {})
		var buildings: Dictionary = {}
		for key in BUILDING_KEYS:
			var value: int = 0
			if raw_buildings is Dictionary:
				value = int(raw_buildings.get(key, 0))
			buildings[key] = clampi(value, 0, 3)
		p["buildings"] = buildings
		if not p.has("production"):
			p["production"] = {"materials_u":0,"rate_carry":0}
		if not p.has("regional_project"):
			p["regional_project"] = {}
		if not p.has("logistics_sites"):
			p["logistics_sites"] = {"depot":0}
		for field in ["materials_u","rate_carry"]:
			p.production[field] = int(p.production[field])
		p.logistics_sites.depot = int(p.logistics_sites.depot)
		if not p.has("provisioning"): p["provisioning"] = Civic.initial_state(p)
		for field in Civic.STATE_FIELDS:
			if field!="rations": p.provisioning[field] = int(p.provisioning[field])
		if not p.regional_project.is_empty():
			for field in REGIONAL_PROJECT_FIELDS:
				if field!="kind": p.regional_project[field] = int(p.regional_project[field])
		out.append(p)
	return out
