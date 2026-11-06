extends RefCounted
## Spiellogik der Bronzezeit: Zeit, Wirtschaft, Krieg, Familie, Intrigen, Speicherstand.
## Reine Datenlogik ohne UI – Main.gd liest und schreibt nur über diese API.

const START_YEAR := -2000
const GOAL_PROVINCES := 15
const BUILDING_KEYS := ["market", "barracks", "walls"]
const MONTHS := ["Hartung", "Hornung", "Lenzmond", "Ostermond", "Wonnemond", "Brachmond",
	"Heumond", "Erntemond", "Scheiding", "Weinmond", "Nebelmond", "Julmond"]
const SaveGameScript = preload("res://scripts/SaveGame.gd")

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

func _yearly() -> void:
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
		var income: int = 0
		for p in provinces:
			if int(p["owner"]) == i:
				income += int(p["dev"]) * 4
		h["gold"] = int(h["gold"]) + income + int(r["stewardship"]) / 4
	for p in provinces:
		p["levy"] = mini(4000, int(p["levy"]) + int(p["levy"] * 0.02) + 5)
	for i in houses.size():
		if i == player:
			continue
		var h: Dictionary = houses[i]
		if h["spouse"].is_empty() and randf() < 0.25:
			h["spouse"] = _make_spouse(i)
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

func _recompute_heir(h: Dictionary) -> void:
	var best: Dictionary = {}
	for c in h["children"]:
		if best.is_empty() or int(c["age"]) > int(best["age"]):
			best = c
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
	if not h["children"].is_empty():
		var best: Dictionary = h["children"][0]
		for c in h["children"]:
			if int(c["age"]) > int(best["age"]):
				best = c
		h["children"].erase(best)
		var g: String = str(best.get("gender", "m"))
		var bp: int = int(best["portrait"]) if best.has("portrait") else _random_portrait(g)
		new_ruler = _ruler_from(str(best["name"]), maxi(16, int(best["age"])), g, bp)
	elif str(h.get("heir", "")) != "":
		var g2: String = str(h["ruler"].get("gender", "m"))
		new_ruler = _ruler_from(str(h["heir"]), maxi(16, int(h.get("heir_age", 16))), g2, _random_portrait(g2))
	elif i == player:
		game_over = true
		note("%s stirbt ohne Erben. Das Haus ist erloschen." % old)
		return
	else:
		var g3: String = "f" if randf() < 0.5 else "m"
		new_ruler = _ruler_from(_random_name(), randi_range(18, 30), g3, _random_portrait(g3))
	h["ruler"] = new_ruler
	h["heir"] = ""
	h["heir_age"] = 0
	h["prestige"] = int(h["prestige"]) + 10
	if not h["children"].is_empty():
		_recompute_heir(h)
	note("%s folgt %s nach." % [new_ruler["name"], old])

func succession_order(i: int) -> Array:
	var kids: Array = houses[i].get("children", []).duplicate()
	kids.sort_custom(func(a, b): return int(a["age"]) > int(b["age"]))
	return kids

func _ruler_from(n: String, age: int, gender: String, portrait: int) -> Dictionary:
	return {
		"name": n, "age": age, "gender": gender,
		"martial": randi_range(5, 17), "diplomacy": randi_range(5, 17),
		"stewardship": randi_range(5, 17), "intrigue": randi_range(5, 17),
		"health": randi_range(65, 95), "portrait": portrait,
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
	var defense: int = int(target["levy"] * (1.0 + int(target["dev"]) / 12.0) * (1.0 + int(defender["ruler"]["martial"]) / 25.0))
	if attack_power * randf_range(0.85, 1.15) > defense:
		target["owner"] = player
		target["levy"] = int(int(target["levy"]) * 0.6)
		target["dev"] = maxi(1, int(target["dev"]) - 1)
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
	var g: String = "f" if str(house()["ruler"]["gender"]) == "m" else "m"
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
		house()["spouse"] = _make_spouse(target)
		house()["prestige"] = int(house()["prestige"]) + 10
		opinion[target] = int(opinion[target]) + 20
		var s: Dictionary = house()["spouse"]
		note("%s vermählt sich mit %s aus %s." % [house()["ruler"]["name"], s["name"], houses[target]["name"]])
		return _res(true, "Die Hochzeit wird gefeiert.")
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
		})
	var data_state: Dictionary = extra_state.duplicate(true)
	data_state["year"] = year
	data_state["month"] = month
	data_state["player"] = player
	data_state["speed"] = speed
	data_state["event_timer"] = event_timer
	data_state["game_over"] = game_over
	data_state["log"] = log_lines.duplicate()
	data_state["pending"] = pending_event["id"] if pending_event != null else ""
	data_state["houses"] = hs
	data_state["provinces"] = ps
	data_state["opinion"] = opinion.duplicate()
	data_state["cooldowns"] = cooldowns.duplicate()
	data_state["captive"] = captive.duplicate(true)
	data_state["scandal"] = scandal
	data_state["custom"] = custom_start
	data_state["victory"] = victory
	return SaveGameScript.make_v2(data_state)

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
	return true
