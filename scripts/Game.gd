extends RefCounted
## Spiellogik der Bronzezeit: Zeit, Wirtschaft, Krieg, Familie, Intrigen, Speicherstand.
## Reine Datenlogik ohne UI – Main.gd liest und schreibt nur über diese API.

const START_YEAR := -2000
const GOAL_PROVINCES := 15
const BUILDING_KEYS := ["market", "barracks", "walls"]
const MONTHS := ["Hartung", "Hornung", "Lenzmond", "Ostermond", "Wonnemond", "Brachmond",
	"Heumond", "Erntemond", "Scheiding", "Weinmond", "Nebelmond", "Julmond"]
const SaveGameScript = preload("res://scripts/SaveGame.gd")
const ResolverScript = preload("res://scripts/SystemicResolver.gd")

var data
var provinces: Array = []
var houses: Array = []
var adjacency: Dictionary = {}
var player: int = 0
var year: int = START_YEAR
var month: int = 1
var speed: int = 0
var log_lines: Array = []
var pending_event = null
var event_timer: int = 9
var game_over: bool = false
var opinion: Array = []
var cooldowns: Dictionary = {}
var captive: Dictionary = {}
var scandal: int = 0
var victory: bool = false
var custom_start: bool = false
var extra_state: Dictionary = {}
var resolver = ResolverScript.new()
var disabled_edges: Dictionary = {}
var effect_log: Array = []
## Monatliche Momentaufnahmen für die Chronik-Graphen (max. 240 Punkte).
var history: Array = []
## Verlauf je Haus (Index = Haus) für den Vergleich in der Chronik.
var house_history: Array = []
## Testhook: >= 0 erzwingt den Schlachtwurf; im normalen Spiel bleibt der Wert -1.
var attack_roll_override: float = -1.0

func _init(data_script, player_index: int = 0, custom: Dictionary = {}) -> void:
	data = data_script
	houses = data.houses().duplicate(true)
	provinces = data.provinces().duplicate(true)
	adjacency = data.adjacency()
	year = START_YEAR
	month = 1
	opinion.resize(houses.size())
	opinion.fill(0)
	for p in provinces:
		_normalize_province(p)
	for i in houses.size():
		_normalize_house(i)
	if custom.is_empty():
		player = clampi(player_index, 0, houses.size() - 1)
		note("%d v. Chr.: %s übernimmt die Herrschaft über %s." % [
			-year, house()["ruler"]["name"], house()["name"]
		])
	else:
		_custom_start(custom)
	_record_history()

# --- Zugriff -------------------------------------------------------------

func province(id: String) -> Dictionary:
	for p in provinces:
		if p["id"] == id:
			return p
	return {}

func house() -> Dictionary:
	return houses[player]

func owned() -> Array:
	var out: Array = []
	for p in provinces:
		if int(p["owner"]) == player:
			out.append(p)
	return out

func neighbours(id: String) -> Array:
	return adjacency.get(id, [])

func month_name(m: int) -> String:
	return MONTHS[clampi(m - 1, 0, 11)]

func date_text() -> String:
	var m: String = month_name(month)
	if year < 0:
		return "%s %d v. Chr." % [m, -year]
	return "%s %d n. Chr." % [m, year]

func note(msg: String) -> void:
	log_lines.append(msg)
	while log_lines.size() > 10:
		log_lines.pop_front()

# --- Aufbau --------------------------------------------------------------

func _normalize_province(p: Dictionary) -> void:
	if not p.has("buildings") or not (p["buildings"] is Dictionary):
		p["buildings"] = {}
	for key in BUILDING_KEYS:
		p["buildings"][key] = clampi(int(p["buildings"].get(key, 0)), 0, 3)
	p["defense"] = clampi(int(p.get("defense", 0)), 0, 100)
	p["siege"] = clampi(int(p.get("siege", 0)), 0, 100)
	p["siege_owner"] = int(p.get("siege_owner", -1))
	var terrain_key: String = str(p.get("terrain", data.terrain_for(str(p["id"]))))
	var terrain: Dictionary = data.terrain_info(terrain_key)
	p["terrain"] = terrain_key
	p["terrain_name"] = str(terrain["name"])
	p["terrain_color"] = terrain["color"]
	p["terrain_defense"] = int(terrain["defense"])
	p["terrain_supply"] = int(terrain["supply"])

func _make_courtier(i: int, n: int) -> Dictionary:
	var g: String = "f" if (i + n) % 2 == 0 else "m"
	var traits := ["Loyal", "Ehrgeizig", "Gelehrsam", "Kriegserprobt", "Fromm", "Gerissen"]
	return {
		"name": _random_name(), "age": randi_range(24, 58), "gender": g,
		"martial": randi_range(5, 18), "diplomacy": randi_range(5, 18),
		"stewardship": randi_range(5, 18), "intrigue": randi_range(4, 18),
		"loyalty": randi_range(42, 92), "portrait": _random_portrait(g),
		"trait": traits[(i + n) % traits.size()],
	}

func _make_courtiers(i: int) -> Array:
	var out: Array = []
	for n in 6:
		out.append(_make_courtier(i, n))
	return out

func _normalize_house(i: int) -> void:
	var h: Dictionary = houses[i]
	h["gold"] = int(h.get("gold", 100))
	if not h.has("courtiers") or not (h["courtiers"] is Array) or (h["courtiers"] as Array).is_empty():
		h["courtiers"] = _make_courtiers(i)
	else:
		for c in h["courtiers"]:
			c["age"] = int(c.get("age", 35))
			c["martial"] = int(c.get("martial", 8))
			c["diplomacy"] = int(c.get("diplomacy", 8))
			c["stewardship"] = int(c.get("stewardship", 8))
			c["intrigue"] = int(c.get("intrigue", 8))
			c["loyalty"] = clampi(int(c.get("loyalty", 60)), 0, 100)
			c["portrait"] = int(c.get("portrait", i % 12))
	if not h.has("council") or not (h["council"] is Dictionary):
		h["council"] = {"marshal": 0, "chancellor": 1, "steward": 2}
	for office in ["marshal", "chancellor", "steward"]:
		h["council"][office] = clampi(int(h["council"].get(office, 0)), 0, h["courtiers"].size() - 1)
	if not h.has("laws") or not (h["laws"] is Dictionary):
		h["laws"] = {"tax": 1, "levy": 1, "succession": "eldest"}
	h["laws"]["tax"] = clampi(int(h["laws"].get("tax", 1)), 0, 2)
	h["laws"]["levy"] = clampi(int(h["laws"].get("levy", 1)), 0, 2)
	if str(h["laws"].get("succession", "eldest")) not in ["eldest", "youngest"]:
		h["laws"]["succession"] = "eldest"
	h["prestige"] = int(h.get("prestige", 0))
	h["legitimacy"] = clampi(int(h.get("legitimacy", 50)), 0, 100)
	if not h.has("factions") or not (h["factions"] is Array) or (h["factions"] as Array).is_empty():
		h["factions"] = [
			{"name": "Adel", "power": 20, "loyalty": 65},
			{"name": "Krieger", "power": 20, "loyalty": 60},
		]
	else:
		for faction in h["factions"]:
			faction["name"] = str(faction.get("name", "Faktion"))
			faction["power"] = clampi(int(faction.get("power", 20)), 0, 100)
			faction["loyalty"] = clampi(int(faction.get("loyalty", 60)), 0, 100)
	if not h.has("secrets") or not (h["secrets"] is Array):
		h["secrets"] = []
	if not h.has("claims") or not (h["claims"] is Array):
		h["claims"] = []
	if not h.has("armies") or not (h["armies"] is Array):
		h["armies"] = []
	if not h.has("truces") or not (h["truces"] is Dictionary):
		h["truces"] = {}
	else:
		for key in h["truces"].keys():
			h["truces"][str(key)] = int(h["truces"][key])
	var crest_index := int(h.get("crest", i))
	if not h.has("crest_file") or str(h.get("crest_file", "")) == "":
		crest_index = posmod(crest_index, 9)
	h["crest"] = crest_index
	if not h.has("spouse") or not (h["spouse"] is Dictionary):
		h["spouse"] = {}
	if not h.has("children") or not (h["children"] is Array):
		h["children"] = []
	h["pregnant"] = int(h.get("pregnant", 0))
	h["lover_house"] = int(h.get("lover_house", -1))
	var r: Dictionary = h["ruler"]
	r["gender"] = str(r.get("gender", "m"))
	r["martial"] = int(r.get("martial", 8))
	r["diplomacy"] = int(r.get("diplomacy", 8))
	r["stewardship"] = int(r.get("stewardship", 8))
	r["intrigue"] = int(r.get("intrigue", 8))
	r["health"] = int(r.get("health", 80))
	r["age"] = int(r.get("age", 30))
	r["portrait"] = int(r.get("portrait", i % 12))
	if not r.has("traits") or not (r["traits"] is Array) or (r["traits"] as Array).is_empty():
		if int(r["martial"]) >= 12:
			r["traits"] = ["Kriegserprobt"]
		elif int(r["stewardship"]) >= 12:
			r["traits"] = ["Gelehrsam"]
		else:
			r["traits"] = ["Loyal"]
	else:
		var clean_traits: Array = []
		for trait_value in r["traits"]:
			var trait_text: String = str(trait_value)
			if trait_text != "" and not clean_traits.has(trait_text):
				clean_traits.append(trait_text)
		r["traits"] = clean_traits
	if not h["spouse"].is_empty():
		var s: Dictionary = h["spouse"]
		s["gender"] = str(s.get("gender", "f"))
		s["age"] = int(s.get("age", 25))
		s["martial"] = int(s.get("martial", 8))
		s["diplomacy"] = int(s.get("diplomacy", 8))
		s["stewardship"] = int(s.get("stewardship", 8))
		s["intrigue"] = int(s.get("intrigue", 8))
		s["health"] = int(s.get("health", 85))
		s["portrait"] = int(s.get("portrait", 9))
	if not h["children"].is_empty():
		for c in h["children"]:
			if not c.has("portrait"):
				var cg: String = str(c.get("gender", "m"))
				var hv: int = absi(str(c.get("name", "?")).hash())
				c["portrait"] = (8 + hv % 40) if cg == "f" else (hv % 8)
			var education: String = str(c.get("education", ""))
			if education not in ["martial", "diplomacy", "stewardship", "intrigue"]:
				c["education"] = ["martial", "diplomacy", "stewardship", "intrigue"][absi(int(c.get("age", 0))) % 4]
		_recompute_heir(h)
	else:
		h["heir"] = ""
		h["heir_age"] = 0
	if not h.has("capital") or str(h["capital"]) == "":
		for p in provinces:
			if int(p["owner"]) == i:
				h["capital"] = str(p["id"])
				break
	if not h.has("realm") or str(h["realm"]) == "":
		h["realm"] = "Hausbesitz"

func _custom_start(cfg: Dictionary) -> void:
	var palette: Array = [
		Color(0.62, 0.30, 0.22), Color(0.26, 0.42, 0.60), Color(0.30, 0.52, 0.32),
		Color(0.74, 0.58, 0.24), Color(0.24, 0.50, 0.50), Color(0.46, 0.30, 0.56),
		Color(0.66, 0.54, 0.22), Color(0.36, 0.44, 0.50), Color(0.48, 0.54, 0.28),
	]
	var gender: String = str(cfg.get("gender", "m"))
	var h := {
		"name": str(cfg.get("house", "Haus Neu")),
		"color": palette[int(cfg.get("color", 0)) % palette.size()],
		"crest": posmod(int(cfg.get("crest", houses.size())), 9),
		"gold": 150,
		"prestige": 12,
		"legitimacy": 50,
		"ruler": {
			"name": str(cfg.get("ruler", "Ari")),
			"age": int(cfg.get("age", 25)),
			"gender": gender,
			"martial": clampi(int(cfg.get("martial", 8)), 3, 20),
			"diplomacy": clampi(int(cfg.get("diplomacy", 8)), 3, 20),
			"stewardship": clampi(int(cfg.get("stewardship", 8)), 3, 20),
			"intrigue": clampi(int(cfg.get("intrigue", 8)), 3, 20),
			"health": 92,
			"portrait": 0 if gender == "m" else 8,
		},
		"spouse": {},
		"children": [],
		"heir": "",
		"heir_age": 0,
		"pregnant": 0,
		"lover_house": -1,
	}
	houses.append(h)
	player = houses.size() - 1
	opinion.append(0)
	for i in player:
		opinion[i] = 0
	var cap: Dictionary = province(str(cfg.get("province", provinces[0]["id"])))
	if not cap.is_empty():
		cap["owner"] = player
		cap["dev"] = maxi(int(cap["dev"]), 4)
		cap["levy"] = maxi(int(cap["levy"]), 600)
		if str(cfg.get("land", "")) != "":
			cap["name"] = str(cfg.get("land", ""))
		h["capital"] = str(cap["id"])
		h["realm"] = "Grafschaft %s" % str(cap["name"])
	_normalize_house(player)
	custom_start = true
	note("%d v. Chr.: %s gründet %s in %s." % [
		-year, h["ruler"]["name"], h["name"], cap.get("name", "?")
	])

# --- Zeit ----------------------------------------------------------------

func advance_month() -> void:
	if game_over:
		return
	month += 1
	if month > 12:
		month = 1
		year += 1
		_yearly()
	_tick_family()
	if pending_event == null:
		event_timer -= 1
		if event_timer <= 0:
			_trigger_event()
	_record_history()

func _record_history() -> void:
	var t: int = (year - START_YEAR) * 12 + month
	history.append(_house_point(player, t))
	while history.size() > 240:
		history.pop_front()
	while house_history.size() < houses.size():
		house_history.append([])
	for i in houses.size():
		house_history[i].append(_house_point(i, t))
		while house_history[i].size() > 240:
			house_history[i].pop_front()

func _house_point(index: int, t: int) -> Dictionary:
	var h: Dictionary = houses[index]
	var troops := 0
	for a in h.get("armies", []):
		troops += int(a.get("strength", 0))
	var own := 0
	var dev := 0
	for p in provinces:
		if int(p["owner"]) == index:
			own += 1
			dev += int(p["dev"])
	return {
		"t": t,
		"gold": int(h["gold"]),
		"prestige": int(h["prestige"]),
		"legitimacy": int(h["legitimacy"]),
		"army": troops,
		"dev": int(round(float(dev) / maxi(1, own))),
	}

func _clean_series(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for e in raw:
		if not (e is Dictionary) or not e.has("t"):
			continue
		out.append({
			"t": int(e.get("t", 0)),
			"gold": int(e.get("gold", 0)),
			"prestige": int(e.get("prestige", 0)),
			"legitimacy": int(e.get("legitimacy", 0)),
			"army": int(e.get("army", 0)),
			"dev": int(e.get("dev", 0)),
		})
	return out

## Stellt sicher, dass der Verlauf nach Init oder Laden gefüllt ist und zu
## den vorhandenen Häusern passt. Alte Spielstände bekommen einen Startpunkt.
func _ensure_history() -> void:
	var t: int = (year - START_YEAR) * 12 + month
	history = _clean_series(history)
	if history.is_empty():
		history = [_house_point(player, t)]
	var cleaned: Array = []
	for i in houses.size():
		var series: Array = _clean_series(house_history[i]) if i < house_history.size() else []
		if series.is_empty():
			series = [_house_point(i, t)]
		cleaned.append(series)
	house_history = cleaned

## Teilt eine Armeestärke auf die vier Truppengattungen auf. Die Belagerung
## bekommt ein Gerät je angefangener 100 Mann, der Rest verteilt sich 55/25/15.
func army_composition(strength: int) -> Dictionary:
	var total: int = maxi(0, strength)
	var siege: int = maxi(1, int(ceil(float(total) / 100.0))) if total > 0 else 0
	var field: int = maxi(0, total - siege)
	var levy: int = int(round(float(field) * 0.55))
	var archer: int = int(round(float(field) * 0.25))
	var knight: int = maxi(0, field - levy - archer)
	return {"levy": levy, "archer": archer, "knight": knight, "siege": siege}

func _yearly() -> void:
	run_ai_turn()
	for i in houses.size():
		var h: Dictionary = houses[i]
		var r: Dictionary = h["ruler"]
		r["age"] = int(r["age"]) + 1
		r["health"] = clampi(int(r["health"]) + randi_range(-3, 1), 15, 100)
		if not h["spouse"].is_empty():
			h["spouse"]["age"] = int(h["spouse"]["age"]) + 1
		if not h["children"].is_empty():
			for c in h["children"]:
				c["age"] = int(c["age"]) + 1
			_recompute_heir(h)
		_apply_house_economy(i)
		_apply_army_upkeep(i)
		_apply_army_supply(i)
		_apply_trait_effects(i)
	for p in provinces:
		p["levy"] = mini(4000, int(p["levy"]) + int(p["levy"] * 0.02) + 5)
	for i in houses.size():
		_apply_council_training(i)
		_apply_legitimacy_effects(i)
		_apply_faction_pressure(i)
	for i in houses.size():
		if i == player:
			continue
		var h: Dictionary = houses[i]
		if h["spouse"].is_empty() and randf() < 0.25:
			h["spouse"] = _make_spouse_for(i, i)
		if not h["spouse"].is_empty() and int(h["pregnant"]) == 0 and randf() < 0.16:
			h["pregnant"] = 9
	if scandal > 0 and randf() < 0.35:
		scandal = 0
		house()["prestige"] = maxi(0, int(house()["prestige"]) - 18)
		for i in opinion.size():
			opinion[i] = int(opinion[i]) - 10
		note("Ein Skandal erschüttert dein Haus (−18 Prestige).")
	_check_deaths()

func _tick_family() -> void:
	for i in houses.size():
		var h: Dictionary = houses[i]
		if int(h["pregnant"]) > 0:
			h["pregnant"] = int(h["pregnant"]) - 1
			if int(h["pregnant"]) == 0:
				_birth(i)
	if not captive.is_empty():
		captive["months"] = int(captive["months"]) - 1
		if int(captive["months"]) <= 0:
			var ci: int = int(captive.get("house", 0))
			if ci >= 0 and ci < opinion.size():
				opinion[ci] = int(opinion[ci]) - 5
			note("%s entkommt aus der Gefangenschaft." % str(captive.get("name", "Der Gefangene")))
			captive = {}

func _birth(i: int) -> void:
	var h: Dictionary = houses[i]
	var g: String = "f" if randf() < 0.5 else "m"
	var child := {
		"name": _random_name(),
		"age": 0,
		"gender": g,
		"portrait": _random_portrait(g),
	}
	h["children"].append(child)
	h["prestige"] = int(h["prestige"]) + 5
	h["pregnant"] = 0
	_recompute_heir(h)
	if i == player:
		note("Ein Kind wird geboren: %s." % child["name"])

func _heir_candidate(h: Dictionary) -> Dictionary:
	var children: Array = h.get("children", [])
	if children.is_empty():
		return {}
	var law: String = str((h.get("laws", {}) as Dictionary).get("succession", "eldest"))
	var best: Dictionary = children[0]
	for c in children:
		if law == "youngest":
			if int(c.get("age", 0)) < int(best.get("age", 0)):
				best = c
		elif int(c.get("age", 0)) > int(best.get("age", 0)):
			best = c
	return best

func _recompute_heir(h: Dictionary) -> void:
	var best := _heir_candidate(h)
	if best.is_empty():
		h["heir"] = ""
		h["heir_age"] = 0
	else:
		h["heir"] = str(best["name"])
		h["heir_age"] = int(best["age"])

func _check_deaths() -> void:
	for i in houses.size():
		if game_over:
			return
		var r: Dictionary = houses[i]["ruler"]
		var chance: float = clampf((int(r["age"]) - 45) / 55.0 + (100 - int(r["health"])) / 350.0, 0.0, 0.85)
		if randf() < chance:
			_succession(i)

func _succession(i: int) -> void:
	var h: Dictionary = houses[i]
	var old: String = str(h["ruler"]["name"])
	var new_ruler: Dictionary = {}
	var education: String = "martial"
	var candidate := _heir_candidate(h)
	if not candidate.is_empty():
		var best: Dictionary = candidate
		education = str(best.get("education", "martial"))
		h["children"].erase(best)
		var g: String = str(best.get("gender", "m"))
		var bp: int = int(best["portrait"]) if best.has("portrait") else _random_portrait(g)
		new_ruler = _ruler_from(str(best["name"]), maxi(16, int(best["age"])), g, bp, education)
	elif str(h.get("heir", "")) != "":
		var g2: String = str(h["ruler"].get("gender", "m"))
		new_ruler = _ruler_from(str(h["heir"]), maxi(16, int(h.get("heir_age", 16))), g2, _random_portrait(g2), education)
	elif i == player:
		game_over = true
		note("%s stirbt ohne Erben. Das Haus ist erloschen." % old)
		return
	else:
		var g3: String = "f" if randf() < 0.5 else "m"
		new_ruler = _ruler_from(_random_name(), randi_range(18, 30), g3, _random_portrait(g3), education)
	h["ruler"] = new_ruler
	h["heir"] = ""
	h["heir_age"] = 0
	h["prestige"] = int(h["prestige"]) + 10
	_apply_education_succession(i, education)
	if not h["children"].is_empty():
		_recompute_heir(h)
	note("%s folgt %s nach." % [new_ruler["name"], old])

func succession_order(i: int) -> Array:
	var kids: Array = houses[i].get("children", []).duplicate()
	var law: String = str((houses[i].get("laws", {}) as Dictionary).get("succession", "eldest"))
	kids.sort_custom(func(a, b):
		if law == "youngest":
			return int(a["age"]) < int(b["age"])
		return int(a["age"]) > int(b["age"])
	)
	return kids

func _ruler_from(n: String, age: int, gender: String, portrait: int, education: String = "martial") -> Dictionary:
	return {
		"name": n, "age": age, "gender": gender,
		"martial": randi_range(5, 12), "diplomacy": randi_range(5, 12),
		"stewardship": randi_range(5, 12), "intrigue": randi_range(5, 12),
		"health": randi_range(65, 95), "portrait": portrait,
		"education": education, "traits": ["Loyal"],
	}

func _random_portrait(gender: String) -> int:
	if gender == "f":
		return randi_range(8, 47)
	return randi_range(0, 7)

func _random_name() -> String:
	var pool: Array = data.name_pool()
	return pool[randi_range(0, pool.size() - 1)]

func _trigger_event() -> void:
	var pool: Array = data.events()
	pending_event = pool[randi_range(0, pool.size() - 1)]

# --- Aktionen ------------------------------------------------------------

func can_develop(id: String) -> bool:
	var p := province(id)
	return not p.is_empty() and int(p["owner"]) == player and int(p["dev"]) < 10 and int(house()["gold"]) >= 50

func develop(id: String) -> Dictionary:
	if not can_develop(id):
		return _res(false, "Ausbau nicht möglich (eigenes Land, Entwicklung < 10, 50 Gold).")
	var p := province(id)
	house()["gold"] = int(house()["gold"]) - 50
	p["dev"] = int(p["dev"]) + 1
	p["levy"] = mini(4000, int(p["levy"]) + 120)
	note("%s ausgebaut: Entwicklung %d." % [p["name"], int(p["dev"])])
	return _res(true, "%s blüht auf." % p["name"])

func can_recruit(id: String) -> bool:
	var p := province(id)
	return not p.is_empty() and int(p["owner"]) == player and int(house()["gold"]) >= 30

func recruit(id: String) -> Dictionary:
	if not can_recruit(id):
		return _res(false, "Werben nicht möglich (eigenes Land, 30 Gold).")
	var p := province(id)
	house()["gold"] = int(house()["gold"]) - 30
	p["levy"] = mini(4000, int(p["levy"]) + 160)
	note("In %s werden 160 Mann angeworben." % p["name"])
	return _res(true, "Truppen verstärkt.")

func can_attack(id: String) -> bool:
	if id == "":
		return false
	var p := province(id)
	if p.is_empty() or int(p["owner"]) == player:
		return false
	if int(house()["gold"]) < 25:
		return false
	if not bool(disabled_edges.get("K2", false)) and not has_claim(id):
		return false
	var target_house: int = int(p["owner"])
	if not bool(disabled_edges.get("D6", false)) and opinion[target_house] >= 60:
		return false
	if not bool(disabled_edges.get("K7", false)) and truce_until(target_house) > _now():
		return false
	var target_kingdom: String = str(p["kingdom"])
	for q in owned():
		if neighbours(str(q["id"])).has(id):
			return true
		if (data.kingdom_neighbours().get(str(q["kingdom"]), []) as Array).has(target_kingdom):
			return true
	return false

func attack(id: String) -> Dictionary:
	if not can_attack(id):
		return _res(false, "Angriff nicht möglich (Nachbarprovinz, 25 Gold).")
	var target := province(id)
	house()["gold"] = int(house()["gold"]) - 25
	var target_kingdom: String = str(target["kingdom"])
	var border_power: int = 0
	var total_power: int = 0
	for q in owned():
		total_power += int(q["levy"])
		if neighbours(str(q["id"])).has(id) or (data.kingdom_neighbours().get(str(q["kingdom"]), []) as Array).has(target_kingdom):
			border_power += int(q["levy"])
	var base_power: int = border_power if border_power > 0 else int(total_power * 0.5)
	var attack_power: int = int(base_power * (1.0 + int(house()["ruler"]["martial"]) / 20.0))
	var defender: Dictionary = houses[int(target["owner"])]
	var terrain_defense: int = int(target.get("terrain_defense", 0))
	var defense: int = int(target["levy"] * (1.0 + int(target["dev"]) / 12.0) * (1.0 + int(defender["ruler"]["martial"]) / 25.0) * (1.0 + (int(target.get("defense", 0)) + terrain_defense) / 100.0))
	var attack_roll: float = randf_range(0.85, 1.15)
	if attack_roll_override >= 0.0:
		attack_roll = attack_roll_override
	if attack_power * attack_roll > defense:
		var old_owner: int = int(target["owner"])
		target["owner"] = player
		target["levy"] = int(int(target["levy"]) * 0.6)
		target["dev"] = maxi(1, int(target["dev"]) - 1)
		target["siege"] = 0
		target["siege_owner"] = -1
		_remove_claim(id, player)
		house()["prestige"] = int(house()["prestige"]) + 15
		note("Sieg! %s gehört nun zu %s." % [target["name"], house()["name"]])
		return _res(true, "Sieg bei %s." % target["name"])
	target["levy"] = int(int(target["levy"]) * 0.85)
	for n in neighbours(id):
		var q := province(n)
		if not q.is_empty() and int(q["owner"]) == player:
			q["levy"] = int(int(q["levy"]) * 0.8)
	house()["prestige"] = maxi(0, int(house()["prestige"]) - 5)
	note("Niederlage bei %s." % target["name"])
	return _res(false, "Die Schlacht ist verloren.")

func can_court() -> bool:
	return int(house()["gold"]) >= 40

func court() -> Dictionary:
	if not can_court():
		return _res(false, "Hof halten kostet 40 Gold.")
	house()["gold"] = int(house()["gold"]) - 40
	house()["prestige"] = int(house()["prestige"]) + 12
	note("Der Hof gibt sich prächtig (+12 Prestige).")
	return _res(true, "Prestige gewonnen.")

# --- Systemische Welle 1 -------------------------------------------------

func _resolve(effects: Array) -> Array:
	return resolver.apply(self, effects)

func record_effect(entry: Dictionary) -> void:
	effect_log.append(entry)
	while effect_log.size() > 200:
		effect_log.pop_front()

func set_edge_enabled(edge: String, enabled: bool) -> void:
	disabled_edges[edge] = not enabled

func council_member(house_index: int, office: String) -> Dictionary:
	if house_index < 0 or house_index >= houses.size():
		return {}
	var h: Dictionary = houses[house_index]
	var council: Dictionary = h.get("council", {})
	var idx: int = int(council.get(office, 0))
	var courtiers: Array = h.get("courtiers", [])
	if idx < 0 or idx >= courtiers.size():
		return {}
	return courtiers[idx]

func council_training_amount(house_index: int) -> int:
	if house_index < 0 or house_index >= houses.size():
		return 0
	var marshal := council_member(house_index, "marshal")
	if marshal.is_empty():
		return 0
	var h: Dictionary = houses[house_index]
	return 4 + int(int(marshal.get("martial", 0)) / 3) + int(int(h.get("legitimacy", 50)) / 20)

func _apply_council_training(i: int) -> void:
	var h: Dictionary = houses[i]
	var marshal := council_member(i, "marshal")
	if marshal.is_empty():
		return
	var capital := province(str(h.get("capital", "")))
	if capital.is_empty():
		for p in provinces:
			if int(p["owner"]) == i:
				capital = p
				break
	if capital.is_empty():
		return
	var amount: int = council_training_amount(i)
	if amount <= 0:
		return
	var edge: String = "H1" if i == player else "AI1"
	var applied := _resolve([{
		"edge": edge, "source": "Rat", "target": "Krieg",
		"state": "provinces[%s].levy" % str(capital["id"]),
		"kind": "levy", "province": str(capital["id"]), "house": i,
		"amount": amount, "reason": "Marschallstraining",
	}])
	if i == player and not applied.is_empty():
		note("%s trainiert %s (+%d Truppen)." % [marshal["name"], capital["name"], amount])

func assign_council(office: String, courtier_index: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return _res(false, "Ungültiges Haus.")
	if not ["marshal", "chancellor", "steward"].has(office):
		return _res(false, "Unbekanntes Ratsamt.")
	var h: Dictionary = houses[hi]
	var courtiers: Array = h.get("courtiers", [])
	if courtier_index < 0 or courtier_index >= courtiers.size():
		return _res(false, "Ungültiger Höfling.")
	h["council"][office] = courtier_index
	return _res(true, "%s übernimmt das Amt des %s." % [courtiers[courtier_index]["name"], office])

func _assign_best_ai(office: String, stat: String, house_index: int) -> void:
	var h: Dictionary = houses[house_index]
	var best: int = -1
	var best_value: int = -999
	for idx in h["courtiers"].size():
		var value: int = int(h["courtiers"][idx].get(stat, 0))
		if value > best_value:
			best_value = value
			best = idx
	if best >= 0:
		assign_council(office, best, house_index)

func run_ai_turn() -> void:
	for i in houses.size():
		if i == player:
			continue
		var h: Dictionary = houses[i]
		if h.get("courtiers", []).is_empty():
			continue
		_assign_best_ai("marshal", "martial", i)
		_assign_best_ai("chancellor", "diplomacy", i)
		_assign_best_ai("steward", "stewardship", i)
		if int(h.get("gold", 0)) >= 220:
			var capital := province(str(h.get("capital", "")))
			if not capital.is_empty() and int((capital.get("buildings", {}) as Dictionary).get("barracks", 0)) < 2:
				build(str(capital["id"]), "barracks", i)
		var desired_tax: int = 2 if int(h.get("gold", 0)) < 120 else 1
		if int(h["laws"].get("tax", 1)) != desired_tax:
			_resolve([{
				"edge": "AI2", "source": "KI", "target": "Herrschaft",
				"state": "houses[%d].laws.tax" % i, "kind": "law", "house": i,
				"law_key": "tax", "law_value": desired_tax, "reason": "KI-Steuerpolitik",
			}])
		if h["spouse"].is_empty() and int(h.get("gold", 0)) >= 30:
			for target in houses.size():
				if target == i:
					continue
				if bool(disabled_edges.get("AI3", false)):
					break
				if _settle_marriage_for(i, target, "AI3")["ok"]:
					h["gold"] = int(h["gold"]) - 30
					break
		if h["claims"].is_empty() and int(h.get("gold", 0)) >= 40:
			var claim_target: String = _ai_claim_target(i)
			if claim_target != "":
				fabricate_claim(claim_target, i)
		var capital2 := province(str(h.get("capital", "")))
		if h["armies"].is_empty() and not capital2.is_empty() and int(h.get("gold", 0)) >= 50:
			raise_army(str(capital2["id"]), i)
		if not h["claims"].is_empty() and not h["armies"].is_empty():
			var siege_target: String = str(h["claims"][0].get("province", ""))
			if siege_target != "":
				advance_siege(siege_target, i)
		if not h["secrets"].is_empty():
			var secret_target: int = int(h["secrets"][0].get("target", -1))
			if secret_target >= 0:
				expose_secret(secret_target, i)
		elif int(h.get("gold", 0)) >= 120:
			for target in houses.size():
				if target != i:
					discover_secret(target, i)
					break

func building_cost(key: String) -> int:
	if key == "barracks":
		return 70
	if key == "walls":
		return 80
	if key == "market":
		return 60
	return 0

func can_build(id: String, key: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return false
	if not ["barracks", "walls", "market"].has(key):
		return false
	var p := province(id)
	if p.is_empty() or int(p["owner"]) != hi:
		return false
	if int((p.get("buildings", {}) as Dictionary).get(key, 0)) >= 3:
		return false
	return int(houses[hi]["gold"]) >= building_cost(key)

func build(id: String, key: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not can_build(id, key, hi):
		return _res(false, "Bau nicht möglich (eigenes Land, freie Stufe, genug Gold).")
	var h: Dictionary = houses[hi]
	var p := province(id)
	var cost: int = building_cost(key)
	var level: int = int((p.get("buildings", {}) as Dictionary).get(key, 0))
	var effects: Array = [
		{"source": "Herrschaft", "target": "Herrschaft", "state": "houses[%d].gold" % hi,
			"kind": "gold", "house": hi, "amount": -cost, "reason": "Baukosten"},
		{"source": "Herrschaft", "target": "Herrschaft", "state": "provinces[%s].buildings.%s" % [id, key],
			"kind": "building", "house": hi, "province": id, "building": key, "amount": 1,
			"reason": "Gebäudestufe"},
	]
	if key == "barracks":
		effects.append({"edge": "H5", "source": "Herrschaft", "target": "Krieg",
			"state": "provinces[%s].levy" % id, "kind": "levy", "house": hi,
			"province": id, "amount": 60 + level * 35, "reason": "Kaserne"})
	elif key == "walls":
		effects.append({"edge": "H5", "source": "Herrschaft", "target": "Krieg",
			"state": "provinces[%s].defense" % id, "kind": "defense", "house": hi,
			"province": id, "amount": 10 + level * 5, "reason": "Mauern"})
	var applied := _resolve(effects)
	if hi == player:
		var new_level: int = int((p.get("buildings", {}) as Dictionary).get(key, 0))
		var gain: int = 0
		for entry in applied:
			if str(entry.get("edge", "")) == "H5":
				gain = int(entry.get("delta", 0))
		var label: String = "Kaserne" if key == "barracks" else ("Mauern" if key == "walls" else "Markt")
		note("%s in %s auf Stufe %d (+%d)." % [label, p["name"], new_level, gain])
	return _res(true, "%s ausgebaut." % p["name"])

func set_law(key: String, value: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return _res(false, "Ungültiges Haus.")
	var h: Dictionary = houses[hi]
	if key == "tax":
		var tax_value: int = clampi(int(value), 0, 2)
		if int(h["laws"]["tax"]) == tax_value:
			return _res(false, "Steuersatz unverändert.")
		h["laws"]["tax"] = tax_value
		if hi == player:
			note("Steuersatz: %d." % tax_value)
		return _res(true, "Steuersatz geändert.")
	if key != "succession":
		return _res(false, "Unbekanntes Gesetz.")
	if not ["eldest", "youngest"].has(value):
		return _res(false, "Unbekannte Erbfolge.")
	h["laws"]["succession"] = value
	_resolve([{
		"edge": "H2", "source": "Herrschaft", "target": "Dynastie",
		"state": "houses[%d].heir" % hi, "kind": "heir", "house": hi,
		"reason": "Erbfolgegesetz",
	}])
	if hi == player:
		note("Erbfolgegesetz: %s." % ("Ältester" if value == "eldest" else "Jüngster"))
	return _res(true, "Erbfolge geändert.")

func settle_marriage(target: int) -> Dictionary:
	return _settle_marriage_for(player, target, "D5")

func _settle_marriage_for(hi: int, target: int, edge: String) -> Dictionary:
	if hi < 0 or hi >= houses.size() or target < 0 or target >= houses.size() or target == hi:
		return _res(false, "Ungültiges Heiratsziel.")
	var h: Dictionary = houses[hi]
	if not h["spouse"].is_empty():
		return _res(false, "Bereits vermählt.")
	h["spouse"] = _make_spouse_for(hi, target)
	_resolve([
		{"edge": edge, "source": "Dynastie", "target": "Herrschaft",
			"state": "houses[%d].legitimacy" % hi, "kind": "legitimacy",
			"house": hi, "amount": 5, "reason": "Eheverbindung"},
		{"edge": edge, "source": "Dynastie", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige",
			"house": hi, "amount": 10, "reason": "Eheverbindung"},
		{"edge": edge, "source": "Dynastie", "target": "Herrschaft",
			"state": "opinion[%d]" % target, "kind": "opinion",
			"house": hi, "index": target, "amount": 20, "reason": "Eheverbindung"},
	])
	if hi == player:
		var s: Dictionary = h["spouse"]
		note("%s vermählt sich mit %s aus %s. Legitimität +5." % [h["ruler"]["name"], s["name"], houses[target]["name"]])
	return _res(true, "Die Hochzeit wird gefeiert.")

# --- Systemische Wellen 2/3 ---------------------------------------------

func faction_power(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var power: int = 0
	for faction in houses[hi].get("factions", []):
		power = maxi(power, int(faction.get("power", 0)))
	return power

func _apply_house_economy(i: int) -> void:
	var h: Dictionary = houses[i]
	var r: Dictionary = h["ruler"]
	var base: int = int(int(r["stewardship"]) / 4)
	for p in provinces:
		if int(p["owner"]) == i:
			base += int(p["dev"]) * 4
	h["gold"] = int(h["gold"]) + base
	_apply_tax_income(i, base)
	_apply_market_income(i)

func _apply_tax_income(i: int, base: int) -> void:
	var tax: int = int(houses[i]["laws"].get("tax", 1))
	var delta: int = int(round(base * (float(tax) - 1.0) * 0.15))
	if delta == 0:
		return
	var edge: String = "H3" if i == player else "AI2"
	_resolve([{
		"edge": edge, "source": "Herrschaft", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": delta, "reason": "Steuersatz %d" % tax,
	}])

func _apply_market_income(i: int) -> void:
	var amount: int = 0
	for p in provinces:
		if int(p["owner"]) != i:
			continue
		amount += int((p.get("buildings", {}) as Dictionary).get("market", 0)) * 4
	if amount <= 0:
		return
	_resolve([{
		"edge": "H4", "source": "Herrschaft", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": amount, "reason": "Marktsteuer",
	}])

func _apply_army_upkeep(i: int) -> void:
	var total: int = 0
	for army in houses[i].get("armies", []):
		total += int(army.get("upkeep", 0))
	if total <= 0:
		return
	_resolve([{
		"edge": "K3", "source": "Krieg", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": -total, "reason": "Armeeunterhalt",
	}])

func _apply_army_supply(i: int) -> void:
	var h: Dictionary = houses[i]
	for army in h.get("armies", []):
		var p: Dictionary = province(str(army.get("province", "")))
		if p.is_empty():
			continue
		var capacity: int = int(p.get("terrain_supply", 6)) * 100
		var strength: int = int(army.get("strength", 0))
		if strength <= capacity:
			continue
		var loss: int = maxi(1, int(round(float(strength - capacity) * 0.02)))
		loss = mini(loss, maxi(1, int(strength / 20)))
		army["strength"] = maxi(1, strength - loss)
		if i == player:
			note("%s: Versorgung im %s reicht nicht; %d Mann gehen verloren." % [str(p["name"]), str(p.get("terrain_name", "Gelände")), loss])

func _apply_trait_effects(i: int) -> void:
	var h: Dictionary = houses[i]
	var traits: Array = h["ruler"].get("traits", [])
	if traits.has("Gelehrsam"):
		_resolve([{
			"edge": "D1", "source": "Dynastie", "target": "Herrschaft",
			"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
			"amount": 2, "reason": "Trait Gelehrsam",
		}])
	if traits.has("Kriegserprobt"):
		var capital: Dictionary = province(str(h.get("capital", "")))
		if not capital.is_empty():
			_resolve([{
				"edge": "D2", "source": "Dynastie", "target": "Krieg",
				"state": "provinces[%s].levy" % str(capital["id"]), "kind": "levy",
				"province": str(capital["id"]), "house": i, "amount": 5,
				"reason": "Trait Kriegserprobt",
			}])

func _apply_legitimacy_effects(i: int) -> void:
	if i != player or int(houses[i]["legitimacy"]) >= 40:
		return
	for j in opinion.size():
		if j == i:
			continue
		_resolve([{
			"edge": "H6", "source": "Herrschaft", "target": "Herrschaft",
			"state": "opinion[%d]" % j, "kind": "opinion", "house": i,
			"index": j, "amount": -2, "reason": "niedrige Legitimität",
		}])
	_resolve([{
		"edge": "H6", "source": "Herrschaft", "target": "Herrschaft",
		"state": "houses[%d].factions[0].loyalty" % i, "kind": "faction_loyalty",
		"house": i, "index": 0, "amount": -5, "reason": "niedrige Legitimität",
	}])

func _apply_faction_pressure(i: int) -> void:
	if faction_power(i) < 60:
		return
	var h: Dictionary = houses[i]
	if int(h["laws"].get("tax", 1)) != 2:
		_resolve([{
			"edge": "H7", "source": "Herrschaft", "target": "Herrschaft",
			"state": "houses[%d].laws.tax" % i, "kind": "law", "house": i,
			"law_key": "tax", "law_value": 2, "reason": "Faktionsdruck",
		}])
	var capital: Dictionary = province(str(h.get("capital", "")))
	if not capital.is_empty():
		_resolve([{
			"edge": "H8", "source": "Herrschaft", "target": "Krieg",
			"state": "provinces[%s].levy" % str(capital["id"]), "kind": "levy",
			"house": i, "province": str(capital["id"]), "amount": -10,
			"reason": "Faktionsunruhe",
		}])

func _apply_education_succession(i: int, education: String) -> void:
	if education not in ["martial", "diplomacy", "stewardship", "intrigue"]:
		return
	_resolve([{
		"edge": "D3", "source": "Dynastie", "target": "Herrschaft",
		"state": "houses[%d].ruler.%s" % [i, education], "kind": "ruler_stat",
		"house": i, "stat": education, "amount": 4, "reason": "Erziehung",
	}])
	if education != "martial":
		return
	var capital: Dictionary = province(str(houses[i].get("capital", "")))
	if not capital.is_empty():
		_resolve([{
			"edge": "D4", "source": "Dynastie", "target": "Krieg",
			"state": "provinces[%s].levy" % str(capital["id"]), "kind": "levy",
			"house": i, "province": str(capital["id"]), "amount": 12,
			"reason": "militärische Erziehung",
		}])

func has_claim(province_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return false
	for claim in houses[hi].get("claims", []):
		if str(claim.get("province", "")) == province_id:
			return true
	return false

func _add_claim(house_index: int, province_id: String, strength: int = 1) -> bool:
	if province(province_id).is_empty() or has_claim(province_id, house_index):
		return false
	var before: int = houses[house_index].get("claims", []).size()
	houses[house_index]["claims"].append({
		"province": province_id, "strength": clampi(strength, 1, 5),
		"expires": _now() + 240,
	})
	if house_index == player:
		record_effect({"edge": "K2", "source": "Krieg", "target": "Herrschaft",
			"state": "houses[%d].claims" % house_index, "kind": "claim",
			"house": house_index, "before": before, "after": before + 1,
			"delta": 1, "reason": "Anspruch"})
	return true

func _remove_claim(province_id: String, house_index: int = -1) -> void:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return
	var kept: Array = []
	for claim in houses[hi].get("claims", []):
		if str(claim.get("province", "")) != province_id:
			kept.append(claim)
	houses[hi]["claims"] = kept

func fabricate_claim(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return _res(false, "Ungültiges Haus.")
	var p := province(province_id)
	if p.is_empty() or int(p["owner"]) == hi:
		return _res(false, "Anspruch nur auf fremdes Land.")
	if int(houses[hi]["gold"]) < 40:
		return _res(false, "Anspruch schmieden kostet 40 Gold.")
	if not _is_border_province(hi, province_id):
		return _res(false, "Nur an der eigenen Grenze.")
	houses[hi]["gold"] = int(houses[hi]["gold"]) - 40
	_add_claim(hi, province_id)
	if hi == player:
		note("Ein Anspruch auf %s wird geschmiedet." % p["name"])
	return _res(true, "Anspruch auf %s." % p["name"])

func press_claim(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not has_claim(province_id, hi):
		return _res(false, "Kein Anspruch vorhanden.")
	_resolve([
		{"edge": "K1", "source": "Krieg", "target": "Herrschaft",
			"state": "houses[%d].legitimacy" % hi, "kind": "legitimacy",
			"house": hi, "amount": 3, "reason": "Anspruch erhoben"},
		{"edge": "K1", "source": "Krieg", "target": "Herrschaft",
			"state": "houses[%d].factions[0].power" % hi, "kind": "faction_power",
			"house": hi, "index": 0, "amount": 5, "reason": "Anspruch erhoben"},
	])
	return _res(true, "Der Anspruch wird öffentlich erhoben.")

func raise_army(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var p := province(province_id)
	if p.is_empty() or int(p["owner"]) != hi:
		return _res(false, "Armee nur im eigenen Land.")
	if int(houses[hi]["gold"]) < 50:
		return _res(false, "Armeeaufstellung kostet 50 Gold.")
	var strength: int = maxi(100, int(int(p["levy"]) / 2))
	houses[hi]["gold"] = int(houses[hi]["gold"]) - 50
	houses[hi]["armies"].append({
		"id": houses[hi]["armies"].size() + 1, "province": province_id,
		"strength": strength, "upkeep": maxi(1, int(strength / 250)), "morale": 100,
	})
	if hi == player:
		note("In %s wird eine Armee von %d Mann aufgestellt." % [p["name"], strength])
	return _res(true, "Armee aufgestellt.")

func army_for(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or houses[hi]["armies"].is_empty():
		return {}
	return houses[hi]["armies"][0]

func advance_siege(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var p := province(province_id)
	if p.is_empty() or int(p["owner"]) == hi:
		return _res(false, "Kein fremdes Belagerungsziel.")
	if not has_claim(province_id, hi):
		return _res(false, "Belagerung braucht einen Anspruch.")
	var army := army_for(hi)
	if army.is_empty():
		return _res(false, "Keine Armee verfügbar.")
	if str(army.get("province", "")) != province_id:
		army["province"] = province_id
	var edge: String = "K4" if hi == player else "AI4"
	var amount: int = 20 + int(int(army["strength"]) / 60) + int(int(houses[hi]["ruler"]["martial"]) / 4)
	_resolve([{
		"edge": edge, "source": "Krieg", "target": "Krieg",
		"state": "provinces[%s].siege" % province_id, "kind": "siege",
		"house": hi, "province": province_id, "amount": amount,
		"reason": "Armeestärke %d" % int(army["strength"]),
	}])
	if int(p.get("siege", 0)) >= 100:
		_capture_province(province_id, hi)
		return _res(true, "%s fällt." % p["name"])
	return _res(true, "Belagerung von %s: %d%%." % [p["name"], int(p.get("siege", 0))])

func _capture_province(province_id: String, new_owner: int) -> void:
	var p := province(province_id)
	if p.is_empty():
		return
	p["owner"] = new_owner
	p["levy"] = int(int(p["levy"]) * 0.6)
	p["siege"] = 0
	p["siege_owner"] = -1
	_remove_claim(province_id, new_owner)
	_resolve([{
		"edge": "K5", "source": "Krieg", "target": "Welt",
		"state": "provinces[%s].dev" % province_id, "kind": "dev",
		"house": new_owner, "province": province_id, "amount": -1,
		"reason": "Belagerungsschaden",
	}])
	for key in BUILDING_KEYS:
		if int((p.get("buildings", {}) as Dictionary).get(key, 0)) > 0:
			_resolve([{
				"edge": "K5", "source": "Krieg", "target": "Welt",
				"state": "provinces[%s].buildings.%s" % [province_id, key], "kind": "building",
				"house": new_owner, "province": province_id, "building": key, "amount": -1,
				"reason": "Belagerungsschaden",
			}])
			break
	if new_owner == player:
		note("Die Belagerung nimmt %s ein." % p["name"])

func make_peace(target_house: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if target_house < 0 or target_house >= houses.size() or target_house == hi:
		return _res(false, "Ungültiger Friedenspartner.")
	var h: Dictionary = houses[hi]
	_resolve([
		{"edge": "K6", "source": "Krieg", "target": "Diplomatie",
			"state": "houses[%d].truces[%d]" % [hi, target_house], "kind": "truce",
			"house": hi, "target_house": target_house, "amount": 24, "reason": "Frieden"},
		{"edge": "K6", "source": "Krieg", "target": "Herrschaft",
			"state": "opinion[%d]" % target_house, "kind": "opinion", "house": hi,
			"index": target_house, "amount": 10, "reason": "Frieden"},
	])
	if h["spouse"].is_empty() and randf() < 0.5:
		h["spouse"] = _make_spouse_for(hi, target_house)
	if hi == player:
		note("Frieden mit %s; die Grenzen beruhigen sich." % houses[target_house]["name"])
	return _res(true, "Frieden geschlossen.")

func truce_until(target_house: int, house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	return int(houses[hi].get("truces", {}).get(str(target_house), 0))

func discover_secret(target_house: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if target_house < 0 or target_house >= houses.size() or target_house == hi:
		return _res(false, "Ungültiges Ziel für ein Geheimnis.")
	for secret in houses[hi]["secrets"]:
		if int(secret.get("target", -1)) == target_house:
			return _res(false, "Geheimnis bereits bekannt.")
	houses[hi]["secrets"].append({
		"id": "secret_%d_%d" % [hi, target_house], "target": target_house,
		"kind": "scandal", "known": true,
	})
	return _res(true, "Ein Geheimnis wird aufgedeckt.")

func expose_secret(target_house: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var found: Dictionary = {}
	for secret in houses[hi]["secrets"]:
		if int(secret.get("target", -1)) == target_house:
			found = secret
			break
	if found.is_empty():
		return _res(false, "Kein Geheimnis vorhanden.")
	houses[hi]["secrets"].erase(found)
	var edge: String = "D7" if hi == player else "AI5"
	_resolve([
		{"edge": edge, "source": "Dynastie", "target": "Herrschaft",
			"state": "scandal", "kind": "scandal", "house": hi,
			"amount": 1, "reason": "Geheimnis veröffentlicht"},
		{"edge": edge, "source": "Dynastie", "target": "Herrschaft",
			"state": "opinion[%d]" % target_house, "kind": "opinion",
			"house": hi, "index": target_house, "amount": -15,
			"reason": "Geheimnis veröffentlicht"},
	])
	if not bool(disabled_edges.get("D8", false)):
		var target_capital: String = str(houses[target_house].get("capital", ""))
		if target_capital != "" and _add_claim(hi, target_capital):
			record_effect({"edge": "D8", "source": "Dynastie", "target": "Krieg",
				"state": "houses[%d].claims" % hi, "kind": "claim", "house": hi,
				"before": 0, "after": 1, "delta": 1, "reason": "Geheimnis als Anspruch"})
	return _res(true, "Das Geheimnis wird ausgenutzt.")

func is_border_province(house_index: int, province_id: String) -> bool:
	return _is_border_province(house_index, province_id)

func _is_border_province(house_index: int, province_id: String) -> bool:
	for p in provinces:
		if int(p["owner"]) == house_index and neighbours(str(p["id"])).has(province_id):
			return true
	return false

func _ai_claim_target(house_index: int) -> String:
	for p in provinces:
		if int(p["owner"]) != house_index or not _is_border_province(house_index, str(p["id"])):
			continue
		for n in neighbours(str(p["id"])):
			var q := province(str(n))
			if not q.is_empty() and int(q["owner"]) != house_index and not has_claim(str(n), house_index):
				return str(n)
	return ""

# --- Familie -------------------------------------------------------------

func _now() -> int:
	return (year - START_YEAR) * 12 + month

func _cooldown_left(key: String) -> int:
	return int(cooldowns.get(key, 0)) - _now()

func _set_cooldown(key: String, months: int) -> void:
	cooldowns[key] = _now() + months

func _chance(kind: String, target: int) -> float:
	var r: Dictionary = house()["ruler"]
	match kind:
		"marry":
			return clampf(0.45 + int(r["diplomacy"]) * 0.02 + int(house()["prestige"]) * 0.0015 + int(opinion[target]) * 0.004, 0.10, 0.95)
		"seduce":
			var t: Dictionary = houses[target]["ruler"]
			return clampf(0.25 + int(r["diplomacy"]) * 0.02 + int(r["intrigue"]) * 0.025 - int(t["intrigue"]) * 0.015 + int(opinion[target]) * 0.002, 0.05, 0.90)
		"murder":
			var m: Dictionary = houses[target]["ruler"]
			return clampf(0.12 + int(r["intrigue"]) * 0.035 - int(m["intrigue"]) * 0.02 + (100 - int(m["health"])) * 0.002, 0.05, 0.85)
		"kidnap":
			var k: Dictionary = houses[target]["ruler"]
			return clampf(0.20 + int(r["martial"]) * 0.02 + int(r["intrigue"]) * 0.02 - int(k["martial"]) * 0.01, 0.05, 0.85)
	return 0.0

func action_chance(kind: String, target: int) -> float:
	return _chance(kind, target)

func action_cost(kind: String) -> int:
	match kind:
		"marry":
			return 30
		"seduce":
			return 20
		"murder":
			return 60
		"kidnap":
			return 45
	return 0

func can_action(kind: String, target: int) -> bool:
	match kind:
		"marry":
			return can_marry(target)
		"seduce":
			return can_seduce(target)
		"murder":
			return can_murder(target)
		"kidnap":
			return can_kidnap(target)
	return false

func do_action(kind: String, target: int) -> Dictionary:
	match kind:
		"marry":
			return marry(target)
		"seduce":
			return seduce(target)
		"murder":
			return murder(target)
		"kidnap":
			return kidnap(target)
	return _res(false, "Unbekannte Aktion.")

func _make_spouse(target: int) -> Dictionary:
	return _make_spouse_for(player, target)

func _make_spouse_for(house_index: int, target: int) -> Dictionary:
	var g: String = "f" if str(houses[house_index]["ruler"].get("gender", "m")) == "m" else "m"
	return {
		"name": _random_name(), "age": randi_range(18, 30), "gender": g,
		"martial": randi_range(4, 14), "diplomacy": randi_range(4, 14),
		"stewardship": randi_range(4, 14), "intrigue": randi_range(4, 14),
		"health": randi_range(70, 95), "portrait": _random_portrait(g), "house": target,
	}

func can_marry(target: int) -> bool:
	if game_over or target < 0 or target >= houses.size() or target == player:
		return false
	if not house()["spouse"].is_empty():
		return false
	if int(house()["gold"]) < 30:
		return false
	return _cooldown_left("marry") <= 0

func marry(target: int) -> Dictionary:
	if not can_marry(target):
		return _res(false, "Heirat nicht möglich (unverheiratet, 30 Gold, kein laufender Antrag).")
	house()["gold"] = int(house()["gold"]) - 30
	_set_cooldown("marry", 12)
	if randf() < _chance("marry", target):
		return settle_marriage(target)
	opinion[target] = int(opinion[target]) - 5
	house()["prestige"] = maxi(0, int(house()["prestige"]) - 5)
	note("%s lehnt die Verbindung ab." % houses[target]["name"])
	return _res(false, "Der Antrag wurde abgelehnt.")

func can_bed() -> bool:
	return not game_over and not house()["spouse"].is_empty() and int(house()["pregnant"]) == 0 and _cooldown_left("bed") <= 0

func bed() -> Dictionary:
	if not can_bed():
		return _res(false, "Beilager nicht möglich (Gemahl/in nötig, keine bestehende Schwangerschaft).")
	_set_cooldown("bed", 6)
	var s: Dictionary = house()["spouse"]
	var chance: float = clampf(0.35 + (30 - absi(int(s["age"]) - 26)) * 0.02 + int(house()["ruler"]["health"]) * 0.001, 0.15, 0.85)
	note("%s teilt das Lager mit %s." % [house()["ruler"]["name"], s["name"]])
	if randf() < chance:
		house()["pregnant"] = 9
		note("%s ist schwanger." % s["name"])
		return _res(true, "Das Haus erwartet Nachwuchs.")
	return _res(true, "Diesmal bleibt der Segen aus.")

func can_seduce(target: int) -> bool:
	if game_over or target < 0 or target >= houses.size() or target == player:
		return false
	if int(house()["gold"]) < 20:
		return false
	return _cooldown_left("seduce_%d" % target) <= 0

func seduce(target: int) -> Dictionary:
	if not can_seduce(target):
		return _res(false, "Verführen nicht möglich (20 Gold, Abklingzeit).")
	house()["gold"] = int(house()["gold"]) - 20
	_set_cooldown("seduce_%d" % target, 12)
	var t: Dictionary = houses[target]
	if randf() < _chance("seduce", target):
		house()["lover_house"] = target
		house()["prestige"] = int(house()["prestige"]) + 8
		opinion[target] = int(opinion[target]) + 12
		note("%s gewinnt das Vertrauen von %s." % [house()["ruler"]["name"], t["ruler"]["name"]])
		var g1: String = str(house()["ruler"]["gender"])
		var g2: String = str(t["ruler"]["gender"])
		if g1 != g2 and int(house()["ruler"]["age"]) < 45 and int(t["ruler"]["age"]) < 45 and randf() < 0.35:
			house()["pregnant"] = 9
			scandal += 1
			note("Eine heimliche Schwangerschaft entsteht.")
		return _res(true, "Die Verführung gelingt.")
	if randf() < 0.5:
		opinion[target] = int(opinion[target]) - 15
		house()["prestige"] = maxi(0, int(house()["prestige"]) - 8)
		note("Der Annäherungsversuch wird öffentlich.")
	return _res(false, "Die Verführung scheitert.")

func can_murder(target: int) -> bool:
	if game_over or target < 0 or target >= houses.size() or target == player:
		return false
	if int(house()["gold"]) < 60:
		return false
	return _cooldown_left("murder_%d" % target) <= 0

func murder(target: int) -> Dictionary:
	if not can_murder(target):
		return _res(false, "Mord nicht möglich (60 Gold, Abklingzeit).")
	house()["gold"] = int(house()["gold"]) - 60
	_set_cooldown("murder_%d" % target, 18)
	var victim: String = str(houses[target]["ruler"]["name"])
	if randf() < _chance("murder", target):
		note("Ein Dolch im Dunkeln beendet das Leben von %s." % victim)
		_succession(target)
		house()["prestige"] = int(house()["prestige"]) + 5
		if randf() < 0.4:
			for i in opinion.size():
				opinion[i] = int(opinion[i]) - 15
			house()["prestige"] = maxi(0, int(house()["prestige"]) - 15)
			note("Der Mord wird aufgedeckt. Dein Ruf leidet.")
		return _res(true, "%s ist tot." % victim)
	if randf() < 0.5:
		opinion[target] = int(opinion[target]) - 30
		house()["prestige"] = maxi(0, int(house()["prestige"]) - 10)
		note("Der Anschlag auf %s schlägt fehl und wird bekannt." % victim)
	return _res(false, "Der Anschlag scheitert.")

func can_kidnap(target: int) -> bool:
	if game_over or target < 0 or target >= houses.size() or target == player:
		return false
	if int(house()["gold"]) < 45:
		return false
	return _cooldown_left("kidnap_%d" % target) <= 0

func kidnap(target: int) -> Dictionary:
	if not can_kidnap(target):
		return _res(false, "Entführung nicht möglich (45 Gold, Abklingzeit).")
	house()["gold"] = int(house()["gold"]) - 45
	_set_cooldown("kidnap_%d" % target, 18)
	if randf() < _chance("kidnap", target):
		var g: String = "f" if randf() < 0.5 else "m"
		captive = {"house": target, "name": _random_name(), "gender": g, "months": 12}
		opinion[target] = int(opinion[target]) - 20
		house()["prestige"] = int(house()["prestige"]) + 5
		note("%s fällt in die Hände deiner Späher." % captive["name"])
		return _res(true, "Die Entführung gelingt.")
	opinion[target] = int(opinion[target]) - 20
	house()["prestige"] = maxi(0, int(house()["prestige"]) - 10)
	note("Die Entführung scheitert und erzürnt %s." % houses[target]["name"])
	return _res(false, "Die Entführung scheitert.")

func can_ransom() -> bool:
	return not game_over and not captive.is_empty()

func ransom_captive() -> Dictionary:
	if not can_ransom():
		return _res(false, "Kein Gefangener.")
	var ci: int = int(captive["house"])
	var n: String = str(captive["name"])
	house()["gold"] = int(house()["gold"]) + 80
	house()["prestige"] = int(house()["prestige"]) + 5
	opinion[ci] = int(opinion[ci]) - 10
	captive = {}
	note("Lösegeld für %s füllt die Kasse (+80 Gold)." % n)
	return _res(true, "Der Gefangene wird freigelassen.")

func can_force_marry() -> bool:
	if game_over or captive.is_empty() or not house()["spouse"].is_empty():
		return false
	return str(captive.get("gender", "f")) != str(house()["ruler"]["gender"])

func force_marry_captive() -> Dictionary:
	if not can_force_marry():
		return _res(false, "Zwangsheirat nicht möglich.")
	var ci: int = int(captive["house"])
	var s := {
		"name": captive["name"], "age": 22, "gender": captive["gender"],
		"martial": randi_range(4, 14), "diplomacy": randi_range(4, 14),
		"stewardship": randi_range(4, 14), "intrigue": randi_range(4, 14),
		"health": 85, "portrait": _random_portrait(str(captive["gender"])), "house": ci,
	}
	house()["spouse"] = s
	opinion[ci] = int(opinion[ci]) - 30
	house()["prestige"] = maxi(0, int(house()["prestige"]) - 10)
	captive = {}
	note("%s wird gegen den Willen der Ihren vermählt." % s["name"])
	return _res(true, "Die erzwungene Hochzeit findet statt.")

# --- Ereignisse ----------------------------------------------------------

func apply_event(option_index: int) -> void:
	if pending_event == null:
		return
	var options: Array = pending_event["options"]
	if option_index < 0 or option_index >= options.size():
		return
	var opt: Dictionary = options[option_index]
	_apply_effects(opt["effects"])
	note("%s: %s" % [pending_event["title"], opt["label"]])
	pending_event = null
	event_timer = randi_range(7, 14)

func _apply_effects(e: Dictionary) -> void:
	var h := house()
	if e.has("gold"):
		h["gold"] = maxi(0, int(h["gold"]) + int(e["gold"]))
	if e.has("prestige"):
		h["prestige"] = maxi(0, int(h["prestige"]) + int(e["prestige"]))
	if e.has("health"):
		h["ruler"]["health"] = clampi(int(h["ruler"]["health"]) + int(e["health"]), 10, 100)
	if e.has("levy"):
		for p in provinces:
			if int(p["owner"]) == player:
				p["levy"] = mini(4000, int(p["levy"]) + int(e["levy"]))
				break
	if e.has("dev"):
		for p in provinces:
			if int(p["owner"]) == player:
				p["dev"] = mini(10, int(p["dev"]) + int(e["dev"]))
				break
	if e.has("heir") and h["heir"] == "":
		h["children"].append({"name": _random_name(), "age": 0, "gender": "f" if randf() < 0.5 else "m"})
		_recompute_heir(h)

func _res(ok: bool, msg: String) -> Dictionary:
	return {"ok": ok, "msg": msg}

# --- Speicherstand -------------------------------------------------------

func snapshot() -> Dictionary:
	var hs: Array = []
	for h in houses:
		var copy: Dictionary = h.duplicate(true)
		var c: Color = h["color"]
		copy["color"] = [c.r, c.g, c.b]
		hs.append(copy)
	var ps: Array = []
	for p in provinces:
		var buildings: Dictionary = {}
		if p.has("buildings") and p["buildings"] is Dictionary:
			buildings = (p["buildings"] as Dictionary).duplicate(true)
		ps.append({
			"id": str(p["id"]), "name": str(p["name"]),
			"owner": int(p["owner"]), "dev": int(p["dev"]),
			"levy": int(p["levy"]), "buildings": buildings,
			"defense": int(p.get("defense", 0)),
			"siege": int(p.get("siege", 0)),
			"siege_owner": int(p.get("siege_owner", -1)),
		})
	var data_state: Dictionary = extra_state.duplicate(true)
	data_state["year"] = year
	data_state["month"] = month
	data_state["player"] = player
	data_state["speed"] = speed
	data_state["event_timer"] = event_timer
	data_state["game_over"] = game_over
	_ensure_history()
	data_state["log"] = log_lines.duplicate()
	data_state["history"] = history.duplicate(true)
	data_state["house_history"] = house_history.duplicate(true)
	data_state["pending"] = pending_event["id"] if pending_event != null else ""
	data_state["houses"] = hs
	data_state["provinces"] = ps
	data_state["opinion"] = opinion.duplicate()
	data_state["cooldowns"] = cooldowns.duplicate()
	data_state["captive"] = captive.duplicate(true)
	data_state["scandal"] = scandal
	data_state["custom"] = custom_start
	data_state["victory"] = victory
	return SaveGameScript.make_current(data_state)

func restore(d: Dictionary) -> bool:
	var migration: Dictionary = SaveGameScript.migrate(d)
	if not bool(migration.get("ok", false)):
		note("Spielstand nicht ladbar: " + "; ".join(migration.get("errors", [])))
		return false
	var state: Dictionary = migration["data"]
	var saved_houses: Array = state.get("houses", [])
	if saved_houses.is_empty():
		note("Spielstand enthält kein Haus.")
		return false
	if int(state.get("player", -1)) < 0 or int(state.get("player", -1)) >= saved_houses.size():
		note("Spielstand enthält keinen gültigen Spieler.")
		return false

	extra_state = {}
	for key in state.keys():
		if SaveGameScript.REQUIRED_TOP_LEVEL.has(str(key)):
			continue
		var extra = state[key]
		if extra is Dictionary or extra is Array:
			extra_state[str(key)] = extra.duplicate(true)
		else:
			extra_state[str(key)] = extra

	year = int(state.get("year", START_YEAR))
	month = int(state.get("month", 1))
	player = int(state.get("player", 0))
	speed = int(state.get("speed", 0))
	event_timer = int(state.get("event_timer", 9))
	game_over = bool(state.get("game_over", false))
	custom_start = bool(state.get("custom", false))
	scandal = int(state.get("scandal", 0))
	victory = bool(state.get("victory", false))
	log_lines = []
	for line in state.get("log", []):
		log_lines.append(str(line))
	houses = []
	var saved_heirs: Array = []
	for hd in saved_houses:
		var h: Dictionary = hd.duplicate(true)
		if h.has("color") and h["color"] is Array and (h["color"] as Array).size() >= 3:
			var c: Array = h["color"]
			h["color"] = Color(float(c[0]), float(c[1]), float(c[2]))
		saved_heirs.append({
			"heir": str(h.get("heir", "")),
			"heir_age": int(h.get("heir_age", 0)),
		})
		houses.append(h)
	opinion = []
	for v in state.get("opinion", []):
		opinion.append(int(v))
	while opinion.size() < houses.size():
		opinion.append(0)
	cooldowns = {}
	var cd = state.get("cooldowns", {})
	if cd is Dictionary:
		for k in cd.keys():
			cooldowns[str(k)] = int(cd[k])
	captive = {}
	var cap = state.get("captive", {})
	if cap is Dictionary:
		captive = cap.duplicate(true)
	var base: Array = data.provinces()
	var saved: Array = state.get("provinces", [])
	provinces = []
	for p in base:
		var restored: Dictionary = p.duplicate(true)
		for s in saved:
			if str(s.get("id", "")) != str(p["id"]):
				continue
			for key in s.keys():
				if key == "id":
					continue
				var value = s[key]
				if value is Dictionary or value is Array:
					restored[key] = value.duplicate(true)
				else:
					restored[key] = value
			break
		_normalize_province(restored)
		provinces.append(restored)
	for i in houses.size():
		_normalize_house(i)
		if i < saved_heirs.size() and str(saved_heirs[i]["heir"]) != "":
			houses[i]["heir"] = saved_heirs[i]["heir"]
			houses[i]["heir_age"] = saved_heirs[i]["heir_age"]
	pending_event = null
	var pid: String = str(state.get("pending", ""))
	if pid != "":
		for ev in data.events():
			if ev["id"] == pid:
				pending_event = ev
				break
	history = _clean_series(state.get("history", []))
	var raw_house_history = state.get("house_history", [])
	house_history = []
	if raw_house_history is Array:
		for series in raw_house_history:
			house_history.append(_clean_series(series))
	_ensure_history()
	return true
