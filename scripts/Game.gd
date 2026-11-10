extends RefCounted
## Spiellogik der Bronzezeit: Zeit, Wirtschaft, Krieg, Familie, Intrigen, Speicherstand.
## Reine Datenlogik ohne UI – Main.gd liest und schreibt nur über diese API.

const START_YEAR := -2000
const GOAL_PROVINCES := 15
const BUILDING_KEYS := ["market", "barracks", "walls"]
const FLEET_COST := 60
const BLOCKADE_MONTHS := 6
const LEGACY_MAX_LEVEL := 3
const LEGACY_ORDER := ["war", "crown", "guile"]
const LEGACY_START_RENOWN := 80
const LEGACY_TRACKS := {
	"war": {"name": "Kriegsvermächtnis", "costs": [80, 160, 240],
		"effect": "+10 % Armeestärke und Angriffskraft je Stufe"},
	"crown": {"name": "Kronvermächtnis", "costs": [80, 160, 240],
		"effect": "+2 Gold jährlich je Stufe; Freischaltung schenkt 2 Legitimität"},
	"guile": {"name": "Ränkevermächtnis", "costs": [80, 160, 240],
		"effect": "+3 Prozentpunkte Intrigenchance je Stufe"},
}
const COUNCIL_ROLES := ["marshal", "chancellor", "steward", "spymaster"]
const COUNCIL_OFFICES := {
	"marshal": {"name": "Marschall", "stat": "martial", "effect": "Marschallstraining: +Truppen im Hauptbesitz pro Jahr"},
	"chancellor": {"name": "Kanzler", "stat": "diplomacy", "effect": "Kanzler: baut jedes Jahr Meinung bei allen Vasallen auf"},
	"steward": {"name": "Kämmerer", "stat": "stewardship", "effect": "Kämmerer: erzeugt jedes Jahr zusätzliche Steuern"},
	"spymaster": {"name": "Spionmeister", "stat": "intrigue", "effect": "Spionmeister: erhöht die Chance von Intrigen"},
}
const COUNCIL_RESOLUTIONS := {
	"war_levy": {"name": "Kriegsaufgebot", "role": "marshal", "cost_gold": 40, "cost_prestige": 5,
		"effect": "+80 Aufgebot in der Hauptstadt, +2 Legitimität, −3 Meinung je Vasall"},
	"land_frieden": {"name": "Landfrieden", "role": "chancellor", "cost_gold": 60, "cost_prestige": 0,
		"effect": "+6 Meinung je Vasall, +2 Legitimität"},
	"crown_tax": {"name": "Kronsteuer", "role": "steward", "cost_gold": 0, "cost_prestige": 10,
		"effect": "+80 Gold, −4 Meinung je Vasall"},
	"shadow_network": {"name": "Schattennetz", "role": "spymaster", "cost_gold": 50, "cost_prestige": 0,
		"effect": "+2 Prozentpunkte Intrigenchance (max. +10), −1 Meinung je Vasall"},
}
const VASSAL_COUNT := 3
const VASSAL_MAX_LEVEL := 2
const VASSAL_CONTRACTS := [
	{"id": "0", "name": "Schutzvertrag", "tax": 2, "levy": 0},
	{"id": "1", "name": "Lehnsvertrag", "tax": 5, "levy": 30},
	{"id": "2", "name": "Kriegsvertrag", "tax": 8, "levy": 60},
]
const RELIC_ORDER := ["crown", "blade", "seal"]
const RELIC_DEFS := {
	"crown": {"name": "Krone der Ahnen", "cost_gold": 100, "cost_prestige": 10,
		"effect": "+10 Legitimität und +15 Hofpracht"},
	"blade": {"name": "Klinge des ersten Königs", "cost_gold": 120, "cost_prestige": 8,
		"effect": "+80 Aufgebot in der Hauptstadt und +15 Hofpracht"},
	"seal": {"name": "Siegel des Schattenrats", "cost_gold": 90, "cost_prestige": 12,
		"effect": "+2 Prozentpunkte Intrigenchance und +15 Hofpracht"},
}
const RELIC_EDGES := {"crown": "R1", "blade": "R2", "seal": "R3"}
const COURT_MAX_HALL := 3
const COURT_HALL_COSTS := [80, 140, 220]
const COURT_HALL_PRESTIGE := [5, 10, 15]
const COURT_BASE_GRANDEUR := 20
const COURT_GRANDEUR_RELIC := 15
const COURT_GRANDEUR_HALL := 15
const COURT_AMENITY_ORDER := ["table", "chambers", "retinue"]
const COURT_AMENITY_MAX := 3
const COURT_AMENITY_GRANDEUR := 5
const COURT_AMENITY_COSTS := [50, 90, 140]
const COURT_AMENITY_UPKEEP := 8
const COURT_EXPECTATION_BASE := 5
const COURT_EXPECTATION_PROVINCE := 2
const COURT_EXPECTATION_LEGITIMACY_DIV := 5
const COURT_AMENITY_DEFS := {
	"table": {"name": "Tafel", "effect": "Jede Stufe: +2 Vasallenmeinung"},
	"chambers": {"name": "Gemächer", "effect": "Jede Stufe: +1 Diplomatie"},
	"retinue": {"name": "Gefolge", "effect": "Jede Stufe: +40 Aufgebot in der Hauptstadt"},
}
const FAITH_ORDER := ["sun", "moon", "earth"]
const FAITH_TOKEN_ORDER := [
	"heresy_low", "heresy_mid", "heresy_high",
	"reform_0", "reform_1", "reform_2", "reform_3",
	"holy_war_0", "holy_war_1", "holy_war_2", "holy_war_3", "holy_war_4",
	"holy_war_5", "holy_war_6", "holy_war_7", "holy_war_8", "holy_war_9",
]
const FAITH_DEFS := {
	"sun": {"name": "Sonnenbund", "doctrine": "Herrschaft", "church_bonus": 6,
		"effect": "Jährlich +1 Legitimität. Die Sonne stärkt den Thron."},
	"moon": {"name": "Mondorakel", "doctrine": "Intrige", "church_bonus": 3,
		"effect": "Jährlich +1 Intrigenpunkt (max. 10). Der Mond öffnet Schattenwege."},
	"earth": {"name": "Erdbund", "doctrine": "Herrschaft", "church_bonus": 0,
		"effect": "Jährlich +1 Prestige. Der Bund der Erde nährt den Ruhm."},
}
const FAITH_START_PIETY := 20
const FAITH_MAX_PIETY := 100
const FAITH_MAX_SITES := 3
const FAITH_SITE_COST_GOLD := 60
const FAITH_SITE_COST_PIETY := 15
const FAITH_SITE_PRESTIGE := 6
const FAITH_PILGRIMAGE_COST := 30
const FAITH_PILGRIMAGE_PIETY := 12
const FAITH_CONVERT_COST_GOLD := 80
const FAITH_CONVERT_COST_PRESTIGE := 15
const FAITH_CONVERT_OPINION := -6
const FAITH_CHURCH_BASE := 5
const FAITH_CHURCH_SITE := 10
const FAITH_CHURCH_RELIC := 5
const FAITH_CHURCH_PIETY_DIV := 4
const FAITH_MAX_HERESY := 100
const FAITH_MAX_REFORM := 3
const FAITH_HERESY_LOW_POWER := 40
const FAITH_HERESY_HIGH_POWER := 70
const FAITH_HERESY_GROWTH := 4
const FAITH_HERESY_DECAY := 3
const FAITH_HERESY_LEGITIMACY_LOW := 35
const FAITH_HERESY_LEGITIMACY_GROWTH := 2
const FAITH_HERESY_OPINION_DIV := 30
const FAITH_HERESY_WAR_THRESHOLD := 50
const FAITH_REFORM_COST_GOLD := [100, 150, 200]
const FAITH_REFORM_COST_PIETY := [25, 30, 35]
const FAITH_REFORM_COST_PRESTIGE := [10, 15, 20]
const FAITH_REFORM_OPINION := -4
const FAITH_REFORM_HERESY := -10
const FAITH_REFORM_POWER := 4
const FAITH_REFORM_HERESY_DRIFT := 2
const FAITH_SUPPRESS_COST_GOLD := 50
const FAITH_SUPPRESS_COST_PRESTIGE := 10
const FAITH_SUPPRESS_HERESY := -25
const FAITH_HOLY_WAR_COST_GOLD := 60
const FAITH_HOLY_WAR_COST_PIETY := 20
const FAITH_HOLY_WAR_COST_PRESTIGE := 10
const FAITH_HOLY_WAR_OPINION := -3
const FAITH_HOLY_WAR_MONTHS := 24
const FAITH_HOLY_WAR_PRESTIGE := 10
const FAITH_HOLY_WAR_LEGITIMACY := 5
const MONTHS := ["Hartung", "Hornung", "Lenzmond", "Ostermond", "Wonnemond", "Brachmond",
	"Heumond", "Erntemond", "Scheiding", "Weinmond", "Nebelmond", "Julmond"]
const SaveGameScript = preload("res://scripts/SaveGame.gd")
const CalendarScript = preload("res://scripts/CampaignCalendar.gd")
const InfrastructureScript = preload("res://scripts/Infrastructure.gd")
const ResolverScript = preload("res://scripts/SystemicResolver.gd")

var data
var provinces: Array = []
var houses: Array = []
var adjacency: Dictionary = {}
var player: int = 0
var year: int = START_YEAR
var campaign_sandbox := false
var roads: Array = []
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

## Im Einzelspielermodus bleiben die bisherigen persönlichen Felder unverändert.
## Eine LAN-Partie hält zusätzlich einen Kontext je Haus; player wählt nur die
## aktuelle synchrone Perspektive. Nur der Host darf die gemeinsame Welt takten.
var human_houses: Array = []
var _player_contexts: Dictionary = {}
var _event_instance: int = 0
var _lan_projection := false
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

func configure_human_houses(ids: Array) -> bool:
	if not _valid_human_ids(ids, houses.size()):
		return false
	_store_player_context()
	human_houses = []
	for index in ids:
		human_houses.append(int(index))
	_lan_projection = false
	for i in houses.size():
		_ensure_player_context(i)
	if not human_houses.has(player):
		return select_player_context(int(human_houses[0]))
	return true

func is_human_house(index: int) -> bool:
	return index == player if human_houses.is_empty() else human_houses.has(index)

func select_player_context(index: int) -> bool:
	if index < 0 or index >= houses.size():
		return false
	if index == player:
		return true
	_store_player_context()
	_ensure_player_context(index)
	player = index
	_load_player_context(_player_contexts[str(index)])
	return true

func opinion_value(house_index: int, index: int) -> int:
	if index < 0 or index >= houses.size() or house_index < 0 or house_index >= houses.size():
		return 0
	if human_houses.is_empty() or house_index == player:
		return int(opinion[index]) if index < opinion.size() else 0
	_ensure_player_context(house_index)
	return int(_player_contexts[str(house_index)]["opinion"][index])

func set_opinion_value(house_index: int, index: int, value: int) -> void:
	if index < 0 or index >= houses.size() or house_index < 0 or house_index >= houses.size():
		return
	if human_houses.is_empty() or house_index == player:
		opinion[index] = value
		return
	_ensure_player_context(house_index)
	_player_contexts[str(house_index)]["opinion"][index] = value

func scandal_value(house_index: int) -> int:
	if house_index < 0 or house_index >= houses.size():
		return 0
	if human_houses.is_empty() or house_index == player:
		return scandal
	_ensure_player_context(house_index)
	return int(_player_contexts[str(house_index)]["scandal"])

func set_scandal_value(house_index: int, value: int) -> void:
	if house_index < 0 or house_index >= houses.size():
		return
	if human_houses.is_empty() or house_index == player:
		scandal = value
		return
	_ensure_player_context(house_index)
	_player_contexts[str(house_index)]["scandal"] = value

func pending_event_instance() -> int:
	return _event_instance

func has_pending_human_events() -> bool:
	if human_houses.is_empty():
		return pending_event != null
	_store_player_context()
	for index in human_houses:
		var context: Dictionary = _player_contexts[str(index)]
		if not bool(context["game_over"]) and str(context["pending"]) != "":
			return true
	return false

func all_human_houses_over() -> bool:
	if human_houses.is_empty():
		return game_over
	_store_player_context()
	for index in human_houses:
		if not bool(_player_contexts[str(index)]["game_over"]):
			return false
	return true

func _personal_state() -> Dictionary:
	return {
		"opinion": opinion.duplicate(), "cooldowns": cooldowns.duplicate(true),
		"captive": captive.duplicate(true), "scandal": scandal,
		"pending": str(pending_event["id"]) if pending_event != null else "",
		"event_timer": event_timer, "event_instance": _event_instance,
		"game_over": game_over, "victory": victory,
		"history": history.duplicate(true), "log": log_lines.duplicate(),
	}

func _store_player_context() -> void:
	_player_contexts[str(player)] = _personal_state()

func _ensure_player_context(index: int) -> void:
	if _player_contexts.has(str(index)):
		return
	var initial_opinion: Array = []
	initial_opinion.resize(houses.size())
	initial_opinion.fill(0)
	_player_contexts[str(index)] = {
		"opinion": initial_opinion, "cooldowns": {}, "captive": {}, "scandal": 0,
		"pending": "", "event_timer": 9, "event_instance": 0,
		"game_over": false, "victory": false, "log": [],
		"history": house_history[index].duplicate(true) if index < house_history.size() else [_house_point(index, _now())],
	}

func _load_player_context(context: Dictionary) -> void:
	opinion = context["opinion"].duplicate()
	cooldowns = context["cooldowns"].duplicate(true)
	captive = context["captive"].duplicate(true)
	scandal = int(context["scandal"])
	event_timer = int(context["event_timer"])
	_event_instance = int(context["event_instance"])
	game_over = bool(context["game_over"])
	victory = bool(context["victory"])
	history = context["history"].duplicate(true)
	log_lines = context["log"].duplicate()
	pending_event = null
	for event in data.events():
		if str(event["id"]) == str(context["pending"]):
			pending_event = event
			break

func _valid_human_ids(ids: Array, house_count: int) -> bool:
	if ids.size() < 2 or ids.size() > 4:
		return false
	var seen: Array = []
	for index in ids:
		if not _whole_number(index) or int(index) < 0 or int(index) >= house_count or seen.has(int(index)):
			return false
		seen.append(int(index))
	return true

func _whole_number(value) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

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

## Persönliche Tickmeldungen erreichen auch inaktive Menschenperspektiven.
## Der gemeinsame Welt-/Spielerkontext wird dafür nicht umgeschaltet.
func _note_for_house(house_index: int, msg: String) -> void:
	if house_index < 0 or house_index >= houses.size() or not is_human_house(house_index):
		return
	if house_index == player:
		note(msg)
		return
	_ensure_player_context(house_index)
	var lines: Array = _player_contexts[str(house_index)]["log"]
	lines.append(msg)
	while lines.size() > 10:
		lines.pop_front()

func _note_for_houses(recipients: Array, msg: String) -> void:
	var delivered: Array = []
	for recipient in recipients:
		var house_index := int(recipient)
		if not delivered.has(house_index):
			delivered.append(house_index)
			_note_for_house(house_index, msg)

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
	p["blockade"] = clampi(int(p.get("blockade", 0)), 0, 24)
	p["blockade_owner"] = int(p.get("blockade_owner", -1))
	if int(p["blockade"]) <= 0:
		p["blockade_owner"] = -1

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
	if not h.has("research"):
		h["research"] = InfrastructureScript.initial_research()
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
		h["council"] = {}
	for office in COUNCIL_ROLES:
		if not h["council"].has(office):
			h["council"][office] = COUNCIL_ROLES.find(office)
		h["council"][office] = clampi(int(h["council"].get(office, 0)), 0, h["courtiers"].size() - 1)
	if not h.has("council_effects") or not (h["council_effects"] is Dictionary):
		h["council_effects"] = {"intrigue": 0, "history": []}
	h["council_effects"]["intrigue"] = clampi(int(h["council_effects"].get("intrigue", 0)), 0, 10)
	if not (h["council_effects"].get("history", []) is Array):
		h["council_effects"]["history"] = []
	_normalize_vassals(h, i)
	_normalize_court(h)
	_normalize_faith(h, i)
	if not h.has("laws") or not (h["laws"] is Dictionary):
		h["laws"] = {"tax": 1, "levy": 1, "succession": "eldest"}
	h["laws"]["tax"] = clampi(int(h["laws"].get("tax", 1)), 0, 2)
	h["laws"]["levy"] = clampi(int(h["laws"].get("levy", 1)), 0, 2)
	if str(h["laws"].get("succession", "eldest")) not in ["eldest", "youngest"]:
		h["laws"]["succession"] = "eldest"
	h["prestige"] = int(h.get("prestige", 0))
	h["legitimacy"] = clampi(int(h.get("legitimacy", 50)), 0, 100)
	h["renown"] = maxi(0, int(h.get("renown", LEGACY_START_RENOWN)))
	var raw_legacies = h.get("legacies", {})
	var legacies: Dictionary = {}
	for track in LEGACY_ORDER:
		var level: int = int(raw_legacies.get(track, 0)) if raw_legacies is Dictionary else 0
		legacies[track] = clampi(level, 0, LEGACY_MAX_LEVEL)
	h["legacies"] = legacies
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
	_normalize_fleets(h)
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

func _normalize_vassals(h: Dictionary, house_index: int) -> void:
	var courtiers: Array = h.get("courtiers", [])
	var raw = h.get("vassals", [])
	var out: Array = []
	if raw is Array:
		for n in mini(VASSAL_COUNT, raw.size()):
			if not (raw[n] is Dictionary):
				continue
			var item: Dictionary = raw[n]
			var ci: int = clampi(int(item.get("courtier", n)), 0, maxi(0, courtiers.size() - 1))
			var fallback_name: String = str(courtiers[ci].get("name", "Vasall %d" % (n + 1))) if ci < courtiers.size() else "Vasall %d" % (n + 1)
			out.append({
				"name": str(item.get("name", fallback_name)),
				"courtier": ci,
				"level": clampi(int(item.get("level", 1)), 0, VASSAL_MAX_LEVEL),
				"opinion": clampi(int(item.get("opinion", 50)), 0, 100),
			})
	while out.size() < VASSAL_COUNT:
		var n: int = out.size()
		var ci2: int = n % maxi(1, courtiers.size())
		var fallback: String = str(courtiers[ci2].get("name", "Vasall %d" % (n + 1))) if ci2 < courtiers.size() else "Vasall %d" % (n + 1)
		out.append({"name": fallback, "courtier": ci2, "level": 1, "opinion": 50})
	h["vassals"] = out

func _normalize_court(h: Dictionary) -> void:
	if not h.has("court") or not (h["court"] is Dictionary):
		h["court"] = {}
	var c: Dictionary = h["court"]
	var raw = c.get("relics", [])
	var relics: Array = []
	if raw is Array:
		for relic_id in RELIC_ORDER:
			if raw.has(relic_id) and not relics.has(relic_id):
				relics.append(relic_id)
	c["relics"] = relics
	c["hall"] = clampi(int(c.get("hall", 0)), 0, COURT_MAX_HALL)
	var raw_amenities = c.get("amenities", {})
	var amenities: Dictionary = {}
	for key in COURT_AMENITY_ORDER:
		var level: int = 0
		if raw_amenities is Dictionary:
			level = int((raw_amenities as Dictionary).get(key, 0))
		amenities[key] = clampi(level, 0, COURT_AMENITY_MAX)
	c["amenities"] = amenities
	c["grandeur"] = _court_grandeur_from_parts(c)
	h["court"] = c

func _court_grandeur_from_parts(c: Dictionary) -> int:
	var raw_relics = c.get("relics", [])
	var relic_count: int = raw_relics.size() if raw_relics is Array else 0
	var hall: int = clampi(int(c.get("hall", 0)), 0, COURT_MAX_HALL)
	var raw_amenities = c.get("amenities", {})
	var amenity_total: int = 0
	if raw_amenities is Dictionary:
		for key in COURT_AMENITY_ORDER:
			amenity_total += clampi(int((raw_amenities as Dictionary).get(key, 0)), 0, COURT_AMENITY_MAX)
	return clampi(COURT_BASE_GRANDEUR + relic_count * COURT_GRANDEUR_RELIC + hall * COURT_GRANDEUR_HALL + amenity_total * COURT_AMENITY_GRANDEUR, 0, 100)

func _normalize_faith(h: Dictionary, house_index: int) -> void:
	var raw = h.get("faith", {})
	var f: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var confession: String = str(f.get("confession", FAITH_ORDER[posmod(house_index, FAITH_ORDER.size())]))
	if not FAITH_DEFS.has(confession):
		confession = str(FAITH_ORDER[posmod(house_index, FAITH_ORDER.size())])
	f["confession"] = confession
	f["piety"] = clampi(int(f.get("piety", FAITH_START_PIETY)), 0, FAITH_MAX_PIETY)
	var raw_sites = f.get("holy_sites", [])
	var sites: Array = []
	if raw_sites is Array:
		for value in raw_sites:
			var site_id: String = str(value)
			if site_id != "" and not sites.has(site_id) and not province(site_id).is_empty() and sites.size() < FAITH_MAX_SITES:
				sites.append(site_id)
	f["holy_sites"] = sites
	f["church_power"] = _faith_church_power_from_parts(f, h)
	h["faith"] = f

func _faith_church_power_from_parts(f: Dictionary, h: Dictionary) -> int:
	var confession: String = str(f.get("confession", "sun"))
	var def: Dictionary = FAITH_DEFS.get(confession, FAITH_DEFS["sun"])
	var raw_sites = f.get("holy_sites", [])
	var site_count: int = raw_sites.size() if raw_sites is Array else 0
	var raw_relics = (h.get("court", {}) as Dictionary).get("relics", [])
	var relic_count: int = raw_relics.size() if raw_relics is Array else 0
	var piety: int = clampi(int(f.get("piety", FAITH_START_PIETY)), 0, FAITH_MAX_PIETY)
	var reform: int = clampi(int(f.get("reform", 0)), 0, FAITH_MAX_REFORM)
	return clampi(FAITH_CHURCH_BASE + int(piety / FAITH_CHURCH_PIETY_DIV) + site_count * FAITH_CHURCH_SITE + relic_count * FAITH_CHURCH_RELIC + reform * FAITH_REFORM_POWER + int(def.get("church_bonus", 0)), 0, 100)

func _normalize_fleets(h: Dictionary) -> void:
	var clean: Array = []
	var raw = h.get("fleets", [])
	if raw is Array:
		for item in raw:
			if not (item is Dictionary):
				continue
			var port_id: String = str(item.get("province", ""))
			if port_id == "" or province(port_id).is_empty():
				continue
			var station_id: String = str(item.get("station", port_id))
			if station_id == "" or province(station_id).is_empty():
				station_id = port_id
			var ships: int = clampi(int(item.get("ships", 0)), 0, 40)
			if ships <= 0:
				continue
			clean.append({
				"id": int(item.get("id", clean.size() + 1)),
				"province": port_id,
				"station": station_id,
				"ships": ships,
				"upkeep": clampi(int(item.get("upkeep", maxi(1, int(ceil(float(ships) / 10.0))))), 0, 10),
				"morale": clampi(int(item.get("morale", 100)), 0, 100),
			})
	h["fleets"] = clean

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
		"renown": LEGACY_START_RENOWN,
		"legacies": {"war": 0, "crown": 0, "guile": 0},
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
	if (game_over if human_houses.is_empty() else all_human_houses_over()):
		return
	if not campaign_sandbox and calendar_index() >= CalendarScript.LAST_MONTH:
		speed = 0
		return
	var original_player := player
	# Ältere Hausmethoden lesen game_over der aktuellen Perspektive. Der
	# gemeinsame Weltschritt verwendet deshalb ein noch lebendes Menschenhaus.
	if not human_houses.is_empty() and game_over:
		for index in human_houses:
			select_player_context(int(index))
			if not game_over:
				break
	month += 1
	if month > 12:
		month = 1
		year = 1 if year == -1 else year + 1
		_yearly()
	_tick_family()
	_tick_naval()
	_tick_dynasty()
	_tick_infrastructure()
	if human_houses.is_empty():
		_tick_personal_event()
	else:
		var previous_player := player
		for index in human_houses:
			select_player_context(int(index))
			if not game_over:
				_tick_captive()
				_tick_personal_event()
		select_player_context(previous_player)
	_record_history()
	if not human_houses.is_empty():
		select_player_context(original_player)
	if not campaign_sandbox and calendar_index() >= CalendarScript.LAST_MONTH:
		speed = 0

func _tick_personal_event() -> void:
	if pending_event == null:
		event_timer -= 1
		if event_timer <= 0:
			_trigger_event()

func calendar_index() -> int:
	return CalendarScript.to_index(year, month)

func continue_sandbox() -> Dictionary:
	if calendar_index() < CalendarScript.LAST_MONTH:
		return _res(false, "Die reguläre Kampagne läuft noch.")
	campaign_sandbox = true
	return _res(true, "Das Vermächtnis wird als Sandbox fortgesetzt.")

func research_choices(house_index: int = -1) -> Array:
	var hi := player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return []
	var choices: Array = []
	for innovation in InfrastructureScript.INNOVATIONS:
		var info: Dictionary = InfrastructureScript.INNOVATIONS[innovation].duplicate()
		info["id"] = innovation
		info["reason"] = _research_blocker(str(innovation), hi)
		choices.append(info)
	return choices

func _research_blocker(innovation: String, hi: int) -> String:
	if game_over:
		return "Die Partie ist beendet."
	if hi < 0 or hi >= houses.size() or not InfrastructureScript.INNOVATIONS.has(innovation):
		return "Unbekannte Forschung oder ungültiges Haus."
	var research: Dictionary = houses[hi].research
	if research.known.has(innovation):
		return "Bereits erforscht."
	if str(research.active) != "":
		return "Zuerst laufende Forschung abschließen."
	var info: Dictionary = InfrastructureScript.INNOVATIONS[innovation]
	if str(info.requires) != "" and not research.known.has(info.requires):
		return "Voraussetzung: Vermessung."
	if int(houses[hi].gold) < int(info.gold):
		return "Nicht genug Gold."
	return ""

func start_research(innovation: String, house_index: int = -1) -> Dictionary:
	var hi := player if house_index < 0 else house_index
	var reason := _research_blocker(innovation, hi)
	if reason != "":
		return _res(false, reason)
	var info: Dictionary = InfrastructureScript.INNOVATIONS[innovation]
	_resolve([{"edge": "", "source": "Forschung", "target": "Herrschaft", "state": "gold", "kind": "gold", "house": hi, "amount": -int(info.gold), "reason": "Forschung: " + str(info.name)}])
	houses[hi].research.active = innovation
	houses[hi].research.months = int(info.months)
	return _res(true, "%s wird erforscht: %d Monate." % [info.name, info.months])

func road_blocker(from_id: String, to_id: String, house_index: int = -1) -> String:
	var hi := player if house_index < 0 else house_index
	if game_over or hi < 0 or hi >= houses.size():
		return "Kein gültiges Haus aktiv."
	var a := province(from_id)
	var b := province(to_id)
	if a.is_empty() or b.is_empty() or from_id == to_id or not neighbours(from_id).has(to_id):
		return "Zwei benachbarte Provinzen auswählen."
	if int(a.owner) != hi or int(b.owner) != hi:
		return "Beide Provinzen müssen dir gehören."
	if not houses[hi].research.known.has("road_building"):
		return "Zuerst Straßenbau erforschen."
	var key := InfrastructureScript.edge_key(from_id, to_id)
	for road in roads:
		if InfrastructureScript.edge_key(str(road.from), str(road.to)) == key:
			return "Diese Verbindung existiert bereits."
	if int(houses[hi].gold) < 30:
		return "30 Gold für den Straßenbau erforderlich."
	return ""

func build_road(from_id: String, to_id: String, house_index: int = -1) -> Dictionary:
	var hi := player if house_index < 0 else house_index
	var reason := road_blocker(from_id, to_id, hi)
	if reason != "":
		return _res(false, reason)
	_resolve([{"edge": "", "source": "Infrastruktur", "target": "Herrschaft", "state": "gold", "kind": "gold", "house": hi, "amount": -30, "reason": "Straßenbau"}])
	var ends := [from_id, to_id]
	ends.sort()
	roads.append({"from": ends[0], "to": ends[1], "builder": hi, "months": 3, "state": "building"})
	return _res(true, "Straßenbau begonnen: 3 Monate, danach +2 Gold im Jahr.")

func _tick_infrastructure() -> void:
	for hi in houses.size():
		var research: Dictionary = houses[hi].research
		if str(research.active) != "":
			research.months = int(research.months) - 1
			if int(research.months) == 0:
				var innovation := str(research.active)
				research.known.append(innovation)
				research.active = ""
				_note_for_house(hi, "Forschung abgeschlossen: " + str(InfrastructureScript.INNOVATIONS[innovation].name))
	for road in roads:
		if road.state != "building":
			continue
		if int(province(str(road.from)).get("owner", -1)) != int(road.builder) or int(province(str(road.to)).get("owner", -1)) != int(road.builder):
			continue
		road.months = int(road.months) - 1
		if int(road.months) == 0:
			road.state = "complete"
			_note_for_house(int(road.builder), "Eine Straßenverbindung ist fertiggestellt.")

func road_segments() -> Array:
	return roads.duplicate(true)

func road_income(house_index: int = -1) -> int:
	var hi := player if house_index < 0 else house_index
	var income := 0
	for road in roads:
		if road.state == "complete" and int(province(str(road.from)).get("owner", -1)) == hi and int(province(str(road.to)).get("owner", -1)) == hi:
			income += 2
	return income

func _apply_road_income(hi: int) -> void:
	_resolve([{"edge": "I1", "source": "Infrastruktur", "target": "Herrschaft", "state": "gold", "kind": "gold", "house": hi, "amount": road_income(hi), "reason": "Straßenhandel"}])

func _record_history() -> void:
	var t: int = _now()
	history.append(_house_point(player, t))
	while history.size() > 240:
		history.pop_front()
	while house_history.size() < houses.size():
		house_history.append([])
	for i in houses.size():
		house_history[i].append(_house_point(i, t))
		while house_history[i].size() > 240:
			house_history[i].pop_front()
	if not human_houses.is_empty():
		_store_player_context()
		for i in houses.size():
			_ensure_player_context(i)
			_player_contexts[str(i)]["history"] = house_history[i].duplicate(true)
		history = house_history[player].duplicate(true)

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
	var t: int = _now()
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
		_apply_road_income(i)
		_apply_army_upkeep(i)
		_apply_army_supply(i)
		_apply_fleet_upkeep(i)
		_apply_court_amenities(i)
		_apply_trait_effects(i)
	for p in provinces:
		p["levy"] = mini(4000, int(p["levy"]) + int(p["levy"] * 0.02) + 5)
	for i in houses.size():
		_apply_council_training(i)
		_apply_chancellor_opinion(i)
		_apply_court_prestige(i)
		_apply_court_opinion(i)
		_apply_court_expectation(i)
		_apply_faith_piety(i)
		_apply_faith_doctrine(i)
		_apply_faith_sites(i)
		_apply_faith_church(i)
		_apply_faith_heresy(i)
		_apply_faith_holy_war(i)
		_apply_legitimacy_effects(i)
		_apply_vassal_politics(i)
		_apply_faction_pressure(i)
	for i in houses.size():
		if is_human_house(i):
			continue
		var h: Dictionary = houses[i]
		if h["spouse"].is_empty() and randf() < 0.25:
			h["spouse"] = _make_spouse_for(i, i)
		if not h["spouse"].is_empty() and int(h["pregnant"]) == 0 and randf() < 0.16:
			h["pregnant"] = 9
	if human_houses.is_empty():
		_tick_scandal()
	else:
		var previous_player := player
		for index in human_houses:
			select_player_context(int(index))
			if not game_over:
				_tick_scandal()
		select_player_context(previous_player)
	_check_deaths()

func _tick_scandal() -> void:
	if scandal > 0 and randf() < 0.35:
		scandal = 0
		house()["prestige"] = maxi(0, int(house()["prestige"]) - 18)
		for i in opinion.size():
			opinion[i] = int(opinion[i]) - 10
		note("Ein Skandal erschüttert dein Haus (−18 Prestige).")

func _tick_family() -> void:
	for i in houses.size():
		var h: Dictionary = houses[i]
		if int(h["pregnant"]) > 0:
			h["pregnant"] = int(h["pregnant"]) - 1
			if int(h["pregnant"]) == 0:
				_birth(i)
	if human_houses.is_empty():
		_tick_captive()

func _tick_captive() -> void:
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
	_resolve([{
		"source": "Dynastie", "target": "Dynastie",
		"state": "houses[%d].renown" % i, "kind": "renown", "house": i,
		"amount": 6, "reason": "Geburt in der Dynastie",
	}])
	h["pregnant"] = 0
	_recompute_heir(h)
	_note_for_house(i, "Ein Kind wird geboren: %s." % child["name"])

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
		if game_over and human_houses.is_empty():
			return
		if not human_houses.is_empty() and is_human_house(i):
			_store_player_context()
			if bool(_player_contexts[str(i)]["game_over"]):
				continue
		var r: Dictionary = houses[i]["ruler"]
		var chance: float = clampf((int(r["age"]) - 45) / 55.0 + (100 - int(r["health"])) / 350.0, 0.0, 0.85)
		if randf() < chance:
			_succession(i)

func _succession(i: int) -> void:
	if not human_houses.is_empty() and is_human_house(i) and i != player:
		var previous_player := player
		select_player_context(i)
		_succession(i)
		select_player_context(previous_player)
		return
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
	_event_instance += 1

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
	var attack_power: int = int(base_power * (1.0 + int(house()["ruler"]["martial"]) / 20.0) * legacy_war_multiplier(player))
	var naval_bonus := 1.0
	if int(target.get("blockade_owner", -1)) == player and int(target.get("blockade", 0)) > 0:
		naval_bonus = 1.25
		note("Die eigene Blockade unterstützt den Angriff auf %s." % target["name"])
	var defender: Dictionary = houses[int(target["owner"])]
	var terrain_defense: int = int(target.get("terrain_defense", 0))
	var defense: int = int(target["levy"] * (1.0 + int(target["dev"]) / 12.0) * (1.0 + int(defender["ruler"]["martial"]) / 25.0) * (1.0 + (int(target.get("defense", 0)) + terrain_defense) / 100.0))
	var attack_roll: float = randf_range(0.85, 1.15)
	if attack_roll_override >= 0.0:
		attack_roll = attack_roll_override
	if attack_power * attack_roll * naval_bonus > defense:
		var old_owner: int = int(target["owner"])
		if int(target.get("blockade", 0)) > 0:
			_release_blockade(target)
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

# --- Hofpracht und Reliquien ---------------------------------------------

func court_grandeur(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	return clampi(int((houses[hi].get("court", {}) as Dictionary).get("grandeur", 0)), 0, 100)

func court_relics(house_index: int = -1) -> Array:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return []
	var c: Dictionary = houses[hi].get("court", {})
	var raw = c.get("relics", [])
	return raw.duplicate() if raw is Array else []

func has_relic(relic_id: String, house_index: int = -1) -> bool:
	return court_relics(house_index).has(relic_id)

func court_hall_level(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	return clampi(int((houses[hi].get("court", {}) as Dictionary).get("hall", 0)), 0, COURT_MAX_HALL)

func court_hall_cost(house_index: int = -1) -> int:
	var level := court_hall_level(house_index)
	if level >= COURT_MAX_HALL:
		return 0
	return int(COURT_HALL_COSTS[level])

func court_hall_prestige_cost(house_index: int = -1) -> int:
	var level := court_hall_level(house_index)
	if level >= COURT_MAX_HALL:
		return 0
	return int(COURT_HALL_PRESTIGE[level])

func court_amenities(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return {}
	var c: Dictionary = houses[hi].get("court", {})
	var raw = c.get("amenities", {})
	var out: Dictionary = {}
	for key in COURT_AMENITY_ORDER:
		out[key] = clampi(int((raw as Dictionary).get(key, 0)) if raw is Dictionary else 0, 0, COURT_AMENITY_MAX)
	return out

func court_amenity_level(amenity_id: String, house_index: int = -1) -> int:
	return int(court_amenities(house_index).get(amenity_id, 0))

func court_amenity_total(house_index: int = -1) -> int:
	var total := 0
	for key in COURT_AMENITY_ORDER:
		total += court_amenity_level(str(key), house_index)
	return total

func court_amenity_upkeep(house_index: int = -1) -> int:
	return court_amenity_total(house_index) * COURT_AMENITY_UPKEEP

func court_amenity_cost(amenity_id: String, house_index: int = -1) -> int:
	if not COURT_AMENITY_ORDER.has(amenity_id):
		return 0
	var level := court_amenity_level(amenity_id, house_index)
	if level >= COURT_AMENITY_MAX:
		return 0
	return int(COURT_AMENITY_COSTS[level])

func court_expected_grandeur(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var owned_count := 0
	for p in provinces:
		if int(p.get("owner", -1)) == hi:
			owned_count += 1
	var legitimacy: int = clampi(int(houses[hi].get("legitimacy", 50)), 0, 100)
	return clampi(COURT_EXPECTATION_BASE + owned_count * COURT_EXPECTATION_PROVINCE + int(legitimacy / COURT_EXPECTATION_LEGITIMACY_DIV), 0, 100)

func court_expectation_delta(house_index: int = -1) -> int:
	return court_grandeur(house_index) - court_expected_grandeur(house_index)

func court_expectation_effect(house_index: int = -1) -> Dictionary:
	var delta := court_expectation_delta(house_index)
	var magnitude := mini(5, 1 + int(absi(delta) / 15))
	return {
		"delta": delta,
		"prestige": magnitude if delta >= 0 else -magnitude,
		"opinion": 1 if delta >= 0 else -1,
	}

func court_amenity_info(amenity_id: String, house_index: int = -1) -> Dictionary:
	if not COURT_AMENITY_DEFS.has(amenity_id):
		return {}
	var def: Dictionary = COURT_AMENITY_DEFS[amenity_id]
	var level := court_amenity_level(amenity_id, house_index)
	var cost := court_amenity_cost(amenity_id, house_index)
	var maxed := level >= COURT_AMENITY_MAX
	return {
		"id": amenity_id, "name": str(def["name"]), "effect": str(def["effect"]),
		"level": level, "max": COURT_AMENITY_MAX, "cost": cost,
		"upkeep": COURT_AMENITY_UPKEEP, "maxed": maxed,
		"button_text": "Maximal" if maxed else "Ausbauen · %d G" % cost,
		"can_upgrade": not maxed and can_upgrade_court_amenity(amenity_id, house_index),
	}

func court_prestige_gain(house_index: int = -1) -> int:
	return int(court_grandeur(house_index) / 25)

func court_opinion_gain(house_index: int = -1) -> int:
	var g := court_grandeur(house_index)
	if g >= 80:
		return 2
	if g >= 60:
		return 1
	return 0

func relic_info(relic_id: String, house_index: int = -1) -> Dictionary:
	if not RELIC_DEFS.has(relic_id):
		return {}
	var d: Dictionary = RELIC_DEFS[relic_id]
	return {
		"id": relic_id, "name": str(d["name"]), "effect": str(d["effect"]),
		"icon": "relic_%s" % relic_id,
		"cost_gold": int(d["cost_gold"]), "cost_prestige": int(d["cost_prestige"]),
		"owned": has_relic(relic_id, house_index),
		"can_forge": can_forge_relic(relic_id, house_index),
	}

func _relic_reason(relic_id: String, hi: int) -> String:
	if hi < 0 or hi >= houses.size():
		return "Ungültiges Haus."
	if not RELIC_DEFS.has(relic_id):
		return "Unbekannte Reliquie."
	var h: Dictionary = houses[hi]
	if has_relic(relic_id, hi):
		return "Diese Reliquie ist bereits im Besitz."
	var d: Dictionary = RELIC_DEFS[relic_id]
	if int(h.get("gold", 0)) < int(d["cost_gold"]):
		return "Zu wenig Gold (%d benötigt)." % int(d["cost_gold"])
	if int(h.get("prestige", 0)) < int(d["cost_prestige"]):
		return "Zu wenig Prestige (%d benötigt)." % int(d["cost_prestige"])
	var edge: String = str(RELIC_EDGES.get(relic_id, ""))
	if edge != "" and bool(disabled_edges.get(edge, false)):
		return "Die Reliquienkante %s ist deaktiviert." % edge
	if relic_id == "crown" and int(h.get("legitimacy", 0)) >= 100:
		return "Die Legitimität ist bereits am Maximum."
	if relic_id == "seal" and int((h.get("council_effects", {}) as Dictionary).get("intrigue", 0)) >= 10:
		return "Der Intrigenbonus ist bereits am Maximum."
	if relic_id == "blade":
		var capital := province(str(h.get("capital", "")))
		if capital.is_empty():
			return "Keine Hauptstadt für das Aufgebot."
		if int(capital.get("levy", 0)) >= 4000:
			return "Das Aufgebot der Hauptstadt ist bereits am Maximum."
	return ""

func can_forge_relic(relic_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _relic_reason(relic_id, hi) == ""

func forge_relic(relic_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _relic_reason(relic_id, hi)
	if reason != "":
		return _res(false, "Reliquie nicht schmiedbar: " + reason)
	var h: Dictionary = houses[hi]
	var d: Dictionary = RELIC_DEFS[relic_id]
	var edge: String = str(RELIC_EDGES[relic_id])
	var effects: Array = [
		{"edge": "", "source": "Hof", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -int(d["cost_gold"]), "reason": "Reliquie %s" % str(d["name"])},
		{"edge": "", "source": "Hof", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -int(d["cost_prestige"]), "reason": "Reliquie %s" % str(d["name"])},
	]
	match relic_id:
		"crown":
			effects.append({"edge": edge, "source": "Hof", "target": "Herrschaft",
				"state": "houses[%d].legitimacy" % hi, "kind": "legitimacy", "house": hi,
				"amount": 10, "reason": "Krone der Ahnen"})
		"blade":
			var capital := province(str(h.get("capital", "")))
			effects.append({"edge": edge, "source": "Hof", "target": "Krieg",
				"state": "provinces[%s].levy" % str(capital["id"]), "kind": "levy",
				"province": str(capital["id"]), "house": hi, "amount": 80,
				"reason": "Klinge des ersten Königs"})
		"seal":
			effects.append({"edge": edge, "source": "Hof", "target": "Intrige",
				"state": "houses[%d].council_effects.intrigue" % hi, "kind": "council_intrigue",
				"house": hi, "amount": 2, "reason": "Siegel des Schattenrats"})
	effects.append({"edge": edge, "source": "Hof", "target": "Hof",
		"state": "houses[%d].court.grandeur" % hi, "kind": "court_grandeur", "house": hi,
		"amount": COURT_GRANDEUR_RELIC, "reason": "Reliquie %s" % str(d["name"])})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Reliquie konnte nicht gebucht werden.")
	var c: Dictionary = h["court"]
	var relics: Array = c.get("relics", [])
	relics.append(relic_id)
	c["relics"] = relics
	_normalize_court(h)
	_refresh_faith_power(hi)
	if hi == player:
		note("%s wird in die Hofhalle überführt (+%d Hofpracht)." % [str(d["name"]), COURT_GRANDEUR_RELIC])
	return _res(true, "%s erworben." % str(d["name"]))

func _hall_reason(hi: int) -> String:
	if hi < 0 or hi >= houses.size():
		return "Ungültiges Haus."
	var level := court_hall_level(hi)
	if level >= COURT_MAX_HALL:
		return "Die Hofhalle ist bereits vollendet."
	var h: Dictionary = houses[hi]
	var cost: int = int(COURT_HALL_COSTS[level])
	var prestige_cost: int = int(COURT_HALL_PRESTIGE[level])
	if int(h.get("gold", 0)) < cost:
		return "Zu wenig Gold (%d benötigt)." % cost
	if int(h.get("prestige", 0)) < prestige_cost:
		return "Zu wenig Prestige (%d benötigt)." % prestige_cost
	if bool(disabled_edges.get("R4", false)):
		return "Die Hofkante R4 ist deaktiviert."
	return ""

func can_upgrade_court_hall(house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _hall_reason(hi) == ""

func upgrade_court_hall(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _hall_reason(hi)
	if reason != "":
		return _res(false, "Hofhalle nicht ausbaubar: " + reason)
	var h: Dictionary = houses[hi]
	var level := court_hall_level(hi)
	var cost: int = int(COURT_HALL_COSTS[level])
	var prestige_cost: int = int(COURT_HALL_PRESTIGE[level])
	var applied := _resolve([
		{"edge": "", "source": "Hof", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -cost, "reason": "Hofhalle Stufe %d" % (level + 1)},
		{"edge": "", "source": "Hof", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -prestige_cost, "reason": "Hofhalle Stufe %d" % (level + 1)},
		{"edge": "R4", "source": "Hof", "target": "Hof",
			"state": "houses[%d].court.grandeur" % hi, "kind": "court_grandeur", "house": hi,
			"amount": COURT_GRANDEUR_HALL, "reason": "Hofhalle Stufe %d" % (level + 1)},
	])
	if applied.is_empty():
		return _res(false, "Hofhalle konnte nicht gebucht werden.")
	var c: Dictionary = h["court"]
	c["hall"] = level + 1
	_normalize_court(h)
	if hi == player:
		note("Die Hofhalle erreicht Stufe %d (+%d Hofpracht)." % [level + 1, COURT_GRANDEUR_HALL])
	return _res(true, "Hofhalle ausgebaut.")

func _apply_court_prestige(i: int) -> void:
	var amount := court_prestige_gain(i)
	if amount <= 0:
		return
	_resolve([{"edge": "R5", "source": "Hof", "target": "Herrschaft",
		"state": "houses[%d].prestige" % i, "kind": "prestige", "house": i,
		"amount": amount, "reason": "Hofpracht"}])

func _apply_court_opinion(i: int) -> void:
	var amount := court_opinion_gain(i)
	if amount <= 0:
		return
	for vi in houses[i].get("vassals", []).size():
		_resolve([{"edge": "R6", "source": "Hof", "target": "Vasall",
			"state": "houses[%d].vassals[%d].opinion" % [i, vi], "kind": "vassal_opinion",
			"house": i, "index": vi, "amount": amount, "reason": "Hofpracht"}])

func _apply_court_amenities(i: int) -> void:
	var upkeep := court_amenity_upkeep(i)
	if upkeep <= 0:
		return
	_resolve([{"edge": "R7", "source": "Hof", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": -upkeep, "reason": "Hofausstattung Unterhalt"}])

func _apply_court_expectation(i: int) -> void:
	var effect: Dictionary = court_expectation_effect(i)
	var effects: Array = []
	var prestige_amount := int(effect.get("prestige", 0))
	if prestige_amount != 0:
		effects.append({"edge": "R8", "source": "Hof", "target": "Herrschaft",
			"state": "houses[%d].prestige" % i, "kind": "prestige", "house": i,
			"amount": prestige_amount, "reason": "Hofpracht-Erwartung"})
	var opinion_amount := int(effect.get("opinion", 0))
	if opinion_amount != 0:
		for vi in houses[i].get("vassals", []).size():
			effects.append({"edge": "R8", "source": "Hof", "target": "Vasall",
				"state": "houses[%d].vassals[%d].opinion" % [i, vi], "kind": "vassal_opinion",
				"house": i, "index": vi, "amount": opinion_amount,
				"reason": "Hofpracht-Erwartung"})
	if not effects.is_empty():
		_resolve(effects)

func _amenity_reason(amenity_id: String, house_index: int) -> String:
	if house_index < 0 or house_index >= houses.size():
		return "Ungültiges Haus."
	if not COURT_AMENITY_ORDER.has(amenity_id):
		return "Unbekannte Hofausstattung."
	var level := court_amenity_level(amenity_id, house_index)
	if level >= COURT_AMENITY_MAX:
		return "Diese Ausstattung ist bereits vollendet."
	var cost := court_amenity_cost(amenity_id, house_index)
	if int(houses[house_index].get("gold", 0)) < cost:
		return "Zu wenig Gold (%d benötigt)." % cost
	if bool(disabled_edges.get("R7", false)):
		return "Die Hofkante R7 ist deaktiviert."
	if amenity_id == "retinue" and str(houses[house_index].get("capital", "")) == "":
		return "Keine Hauptstadt für das Gefolge."
	return ""

func can_upgrade_court_amenity(amenity_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _amenity_reason(amenity_id, hi) == ""

func upgrade_court_amenity(amenity_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _amenity_reason(amenity_id, hi)
	if reason != "":
		return _res(false, "Hofausstattung nicht ausbaubar: " + reason)
	var h: Dictionary = houses[hi]
	var level := court_amenity_level(amenity_id, hi)
	var cost := court_amenity_cost(amenity_id, hi)
	var def: Dictionary = COURT_AMENITY_DEFS[amenity_id]
	var effects: Array = [
		{"edge": "R7", "source": "Hof", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -cost, "reason": "Hofausstattung %s" % str(def["name"])},
		{"edge": "R7", "source": "Hof", "target": "Hof",
			"state": "houses[%d].court.grandeur" % hi, "kind": "court_grandeur", "house": hi,
			"amount": COURT_AMENITY_GRANDEUR, "reason": "Hofausstattung %s" % str(def["name"])},
	]
	match amenity_id:
		"table":
			for vi in h.get("vassals", []).size():
				effects.append({"edge": "R7", "source": "Hof", "target": "Vasall",
					"state": "houses[%d].vassals[%d].opinion" % [hi, vi], "kind": "vassal_opinion",
					"house": hi, "index": vi, "amount": 2,
					"reason": "Tafel"})
		"chambers":
			effects.append({"edge": "R7", "source": "Hof", "target": "Herrschaft",
				"state": "houses[%d].ruler.diplomacy" % hi, "kind": "ruler_stat", "house": hi,
				"stat": "diplomacy", "amount": 1, "reason": "Gemächer"})
		"retinue":
			var capital := province(str(h.get("capital", "")))
			effects.append({"edge": "R7", "source": "Hof", "target": "Krieg",
				"state": "provinces[%s].levy" % str(capital["id"]), "kind": "levy",
				"province": str(capital["id"]), "house": hi, "amount": 40,
				"reason": "Gefolge"})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Hofausstattung konnte nicht gebucht werden.")
	var c: Dictionary = h["court"]
	var amenities: Dictionary = c.get("amenities", {}).duplicate(true)
	amenities[amenity_id] = level + 1
	c["amenities"] = amenities
	_normalize_court(h)
	if hi == player:
		note("%s erreicht Stufe %d (+%d Hofpracht)." % [str(def["name"]), level + 1, COURT_AMENITY_GRANDEUR])
	return _res(true, "%s ausgebaut." % str(def["name"]))

func _ai_court(house_index: int) -> void:
	var h: Dictionary = houses[house_index]
	if int(h.get("gold", 0)) < 100 or int(h.get("prestige", 0)) < 8:
		return
	if court_grandeur(house_index) < court_expected_grandeur(house_index) and _ai_upgrade_amenity(house_index):
		return
	var preferred: Array = ["crown", "blade", "seal"]
	if int(h["ruler"].get("martial", 0)) > int(h["ruler"].get("diplomacy", 0)):
		preferred = ["blade", "crown", "seal"]
	elif int(h["ruler"].get("intrigue", 0)) > int(h["ruler"].get("stewardship", 0)):
		preferred = ["seal", "crown", "blade"]
	for relic_id in preferred:
		var info: Dictionary = RELIC_DEFS[relic_id]
		if can_forge_relic(str(relic_id), house_index) and int(h["gold"]) > int(info["cost_gold"]) + 80:
			forge_relic(str(relic_id), house_index)
			return
	if can_upgrade_court_hall(house_index) and int(h["gold"]) > court_hall_cost(house_index) + 80 and int(h["prestige"]) > court_hall_prestige_cost(house_index) + 4:
		upgrade_court_hall(house_index)
		return
	_ai_upgrade_amenity(house_index)

func _ai_upgrade_amenity(house_index: int) -> bool:
	var h: Dictionary = houses[house_index]
	if court_amenity_upkeep(house_index) + COURT_AMENITY_UPKEEP > 6 * COURT_AMENITY_UPKEEP:
		return false
	if int(h.get("gold", 0)) < 220:
		return false
	var best_id := ""
	var best_cost := 9999
	for key in COURT_AMENITY_ORDER:
		var level := court_amenity_level(str(key), house_index)
		if level >= COURT_AMENITY_MAX:
			continue
		var cost := court_amenity_cost(str(key), house_index)
		if cost <= 0 or int(h["gold"]) < cost + 120:
			continue
		if cost < best_cost:
			best_cost = cost
			best_id = str(key)
	if best_id == "":
		return false
	return bool(upgrade_court_amenity(best_id, house_index).get("ok", false))

# --- Glaube und Kirche ---------------------------------------------------

func faith(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return {}
	var f = houses[hi].get("faith", {})
	return f.duplicate(true) if f is Dictionary else {}

func faith_confession(house_index: int = -1) -> String:
	return str(faith(house_index).get("confession", "sun"))

func faith_piety(house_index: int = -1) -> int:
	return clampi(int(faith(house_index).get("piety", 0)), 0, FAITH_MAX_PIETY)

func faith_church_power(house_index: int = -1) -> int:
	return clampi(int(faith(house_index).get("church_power", 0)), 0, 100)

func faith_holy_sites(house_index: int = -1) -> Array:
	var raw = faith(house_index).get("holy_sites", [])
	return raw.duplicate() if raw is Array else []

func faith_site_count(house_index: int = -1) -> int:
	return faith_holy_sites(house_index).size()

func faith_heresy(house_index: int = -1) -> int:
	return clampi(int(faith(house_index).get("heresy", 0)), 0, FAITH_MAX_HERESY)

func faith_reform(house_index: int = -1) -> int:
	return clampi(int(faith(house_index).get("reform", 0)), 0, FAITH_MAX_REFORM)

func faith_holy_war(house_index: int = -1) -> Dictionary:
	var raw = faith(house_index).get("holy_war", {})
	return raw.duplicate(true) if raw is Dictionary else {}

func faith_holy_war_target(house_index: int = -1) -> int:
	var war := faith_holy_war(house_index)
	var target := int(war.get("target", -1))
	if int(war.get("months", 0)) <= 0 or target < 0 or target >= houses.size():
		return -1
	var capital_id := str(houses[target].get("capital", ""))
	if capital_id == "" or not claim_active(capital_id, house_index):
		return -1
	return target

func faith_holy_war_claim_months(house_index: int = -1) -> int:
	var target := faith_holy_war_target(house_index)
	if target < 0:
		return 0
	var capital_id := str(houses[target].get("capital", ""))
	var expiry := claim_expiry(capital_id, house_index)
	return maxi(0, expiry - _now()) if expiry >= 0 else 0

func claim_expiry(province_id: String, house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return -1
	for claim in houses[hi].get("claims", []):
		if str(claim.get("province", "")) == province_id:
			return int(claim.get("expires", -1))
	return -1

func claim_active(province_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return false
	for claim in houses[hi].get("claims", []):
		if str(claim.get("province", "")) != province_id:
			continue
		if not claim.has("expires") or int(claim["expires"]) >= _now():
			return true
	return false

func faith_is_heretic(house_index: int = -1) -> bool:
	return faith_heresy(house_index) >= FAITH_HERESY_WAR_THRESHOLD

func faith_heresy_growth(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var growth := 0
	var power := faith_church_power(hi)
	if power < FAITH_HERESY_LOW_POWER:
		growth += FAITH_HERESY_GROWTH
	elif power >= FAITH_HERESY_HIGH_POWER:
		growth -= FAITH_HERESY_DECAY
	if int(houses[hi].get("legitimacy", 50)) < FAITH_HERESY_LEGITIMACY_LOW:
		growth += FAITH_HERESY_LEGITIMACY_GROWTH
	if not bool(disabled_edges.get("F11", false)):
		growth -= faith_reform(hi) * FAITH_REFORM_HERESY_DRIFT
	return growth

func faith_heresy_legitimacy_penalty(house_index: int = -1) -> int:
	var heresy := faith_heresy(house_index)
	if heresy >= 70:
		return 2
	if heresy >= 40:
		return 1
	return 0

func faith_heresy_opinion_penalty(house_index: int = -1) -> int:
	var heresy := faith_heresy(house_index)
	if heresy < 30:
		return 0
	return clampi(int(heresy / FAITH_HERESY_OPINION_DIV), 1, 3)

func reform_cost(house_index: int = -1) -> Dictionary:
	var level := clampi(faith_reform(house_index), 0, FAITH_MAX_REFORM - 1)
	return {
		"level": faith_reform(house_index),
		"gold": int(FAITH_REFORM_COST_GOLD[level]),
		"piety": int(FAITH_REFORM_COST_PIETY[level]),
		"prestige": int(FAITH_REFORM_COST_PRESTIGE[level]),
	}

func _reform_reason(house_index: int) -> String:
	if house_index < 0 or house_index >= houses.size():
		return "Ungültiges Haus."
	if game_over:
		return "Das Spiel ist beendet."
	if faith_reform(house_index) >= FAITH_MAX_REFORM:
		return "Die Reformbewegung ist bereits abgeschlossen."
	if faith_heresy(house_index) > 60:
		return "Zu viel Ketzerei für eine Reform (höchstens 60)."
	var cost := reform_cost(house_index)
	if int(houses[house_index].get("gold", 0)) < int(cost["gold"]):
		return "Zu wenig Gold (%d benötigt)." % int(cost["gold"])
	if faith_piety(house_index) < int(cost["piety"]):
		return "Zu wenig Frömmigkeit (%d benötigt)." % int(cost["piety"])
	if int(houses[house_index].get("prestige", 0)) < int(cost["prestige"]):
		return "Zu wenig Prestige (%d benötigt)." % int(cost["prestige"])
	return ""

func can_reform_faith(house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _reform_reason(hi) == ""

func reform_faith(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _reform_reason(hi)
	if reason != "":
		return _res(false, "Reform nicht möglich: " + reason)
	var cost := reform_cost(hi)
	var effects: Array = [
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -int(cost["gold"]), "reason": "Reform"},
		{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.piety" % hi, "kind": "faith_piety", "house": hi,
			"amount": -int(cost["piety"]), "reason": "Reform"},
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -int(cost["prestige"]), "reason": "Reform"},
		{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.reform" % hi, "kind": "faith_reform", "house": hi,
			"amount": 1, "reason": "Reform"},
	]
	for vi in houses[hi].get("vassals", []).size():
		effects.append({"edge": "", "source": "Glaube", "target": "Vasall",
			"state": "houses[%d].vassals[%d].opinion" % [hi, vi],
			"kind": "vassal_opinion", "house": hi, "index": vi,
			"amount": FAITH_REFORM_OPINION, "reason": "Reform"})
	if not bool(disabled_edges.get("F11", false)):
		effects.append({"edge": "F11", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.heresy" % hi, "kind": "faith_heresy", "house": hi,
			"amount": FAITH_REFORM_HERESY, "reason": "Reform"})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Reform konnte nicht gebucht werden.")
	_refresh_faith_power(hi)
	if hi == player:
		note("Die Reformbewegung steigt auf Stufe %d. Die Kirche ist geeint, die Traditionalisten murren." % faith_reform(hi))
	return _res(true, "Reform beschlossen.")

func can_suppress_heresy(house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or game_over:
		return false
	if faith_heresy(hi) <= 0:
		return false
	return int(houses[hi].get("gold", 0)) >= FAITH_SUPPRESS_COST_GOLD and int(houses[hi].get("prestige", 0)) >= FAITH_SUPPRESS_COST_PRESTIGE

func suppress_heresy(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not can_suppress_heresy(hi):
		return _res(false, "Ketzergericht nicht möglich (Ketzerei, 50 Gold, 10 Prestige).")
	var applied := _resolve([
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -FAITH_SUPPRESS_COST_GOLD, "reason": "Ketzergericht"},
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -FAITH_SUPPRESS_COST_PRESTIGE, "reason": "Ketzergericht"},
		{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.heresy" % hi, "kind": "faith_heresy", "house": hi,
			"amount": FAITH_SUPPRESS_HERESY, "reason": "Ketzergericht"},
	])
	if applied.is_empty():
		return _res(false, "Ketzergericht konnte nicht gebucht werden.")
	if hi == player:
		note("Das Ketzergericht reinigt die Kirche (%d Ketzerei)." % FAITH_SUPPRESS_HERESY)
	return _res(true, "Ketzerei zurückgedrängt.")

func _apply_faith_heresy(house_index: int) -> void:
	var growth := faith_heresy_growth(house_index)
	if growth != 0:
		_resolve([{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.heresy" % house_index, "kind": "faith_heresy",
			"house": house_index, "amount": growth, "reason": "Ketzerez"}])
	var legitimacy_penalty := faith_heresy_legitimacy_penalty(house_index)
	if legitimacy_penalty > 0 and not bool(disabled_edges.get("F8", false)):
		_resolve([{"edge": "F8", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].legitimacy" % house_index, "kind": "legitimacy",
			"house": house_index, "amount": -legitimacy_penalty, "reason": "Ketzerei"}])
	var opinion_penalty := faith_heresy_opinion_penalty(house_index)
	if opinion_penalty > 0 and not bool(disabled_edges.get("F9", false)):
		for vi in houses[house_index].get("vassals", []).size():
			_resolve([{"edge": "F9", "source": "Glaube", "target": "Vasall",
				"state": "houses[%d].vassals[%d].opinion" % [house_index, vi],
				"kind": "vassal_opinion", "house": house_index, "index": vi,
				"amount": -opinion_penalty, "reason": "Ketzerei"}])

func _holy_war_reason(target_house: int, house_index: int) -> String:
	if house_index < 0 or house_index >= houses.size():
		return "Ungültiges Haus."
	if target_house < 0 or target_house >= houses.size() or target_house == house_index:
		return "Ungültiges Ziel für einen heiligen Krieg."
	if game_over:
		return "Das Spiel ist beendet."
	if faith_holy_war_target(house_index) >= 0:
		return "Es läuft bereits ein heiliger Krieg."
	var target: Dictionary = houses[target_house]
	var capital_id := str(target.get("capital", ""))
	var capital := province(capital_id)
	if capital.is_empty() or int(capital.get("owner", -1)) != target_house:
		return "Das Ziel hält seine Hauptstadt nicht."
	if faith_confession(target_house) == faith_confession(house_index) and not faith_is_heretic(target_house):
		return "Das Ziel ist weder andersgläubig noch ketzerisch."
	if truce_until(target_house, house_index) > _now():
		return "Es gilt ein Waffenstillstand."
	if int(houses[house_index].get("gold", 0)) < FAITH_HOLY_WAR_COST_GOLD:
		return "Zu wenig Gold (%d benötigt)." % FAITH_HOLY_WAR_COST_GOLD
	if faith_piety(house_index) < FAITH_HOLY_WAR_COST_PIETY:
		return "Zu wenig Frömmigkeit (%d benötigt)." % FAITH_HOLY_WAR_COST_PIETY
	if int(houses[house_index].get("prestige", 0)) < FAITH_HOLY_WAR_COST_PRESTIGE:
		return "Zu wenig Prestige (%d benötigt)." % FAITH_HOLY_WAR_COST_PRESTIGE
	return ""

func can_declare_holy_war(target_house: int, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _holy_war_reason(target_house, hi) == ""

func declare_holy_war(target_house: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _holy_war_reason(target_house, hi)
	if reason != "":
		return _res(false, "Heiliger Krieg nicht möglich: " + reason)
	var target_capital := str(houses[target_house].get("capital", ""))
	var effects: Array = [
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -FAITH_HOLY_WAR_COST_GOLD, "reason": "Heiliger Krieg"},
		{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.piety" % hi, "kind": "faith_piety", "house": hi,
			"amount": -FAITH_HOLY_WAR_COST_PIETY, "reason": "Heiliger Krieg"},
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -FAITH_HOLY_WAR_COST_PRESTIGE, "reason": "Heiliger Krieg"},
	]
	for vi in houses[hi].get("vassals", []).size():
		effects.append({"edge": "", "source": "Glaube", "target": "Vasall",
			"state": "houses[%d].vassals[%d].opinion" % [hi, vi],
			"kind": "vassal_opinion", "house": hi, "index": vi,
			"amount": FAITH_HOLY_WAR_OPINION, "reason": "Heiliger Krieg"})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Heiliger Krieg konnte nicht gebucht werden.")
	_add_claim(hi, target_capital, 3)
	var f: Dictionary = houses[hi]["faith"]
	f["holy_war"] = {"target": target_house, "months": FAITH_HOLY_WAR_MONTHS}
	houses[hi]["faith"] = f
	_refresh_faith_power(hi)
	if hi == player:
		note("Ein heiliger Krieg gegen %s beginnt. Der Anspruch auf die Hauptstadt ist erhoben." % str(houses[target_house]["name"]))
	return _res(true, "Heiliger Krieg erklärt.")

func _apply_faith_holy_war(house_index: int) -> void:
	var f: Dictionary = houses[house_index].get("faith", {})
	var war: Dictionary = f.get("holy_war", {}) if f.get("holy_war", {}) is Dictionary else {}
	var target := int(war.get("target", -1))
	var months := int(war.get("months", 0))
	if target < 0 or months <= 0:
		return
	if target >= houses.size():
		f["holy_war"] = {"target": -1, "months": 0}
		houses[house_index]["faith"] = f
		return
	var capital_id := str(houses[target].get("capital", ""))
	var capital := province(capital_id)
	if not claim_active(capital_id, house_index):
		f["holy_war"] = {"target": -1, "months": 0}
		houses[house_index]["faith"] = f
		_note_for_house(house_index, "Der Anspruch im heiligen Krieg ist erloschen; der Krieg endet.")
		return
	if not capital.is_empty() and int(capital.get("owner", -1)) == house_index:
		_resolve([
			{"edge": "F12", "source": "Glaube", "target": "Herrschaft",
				"state": "houses[%d].prestige" % house_index, "kind": "prestige",
				"house": house_index, "amount": FAITH_HOLY_WAR_PRESTIGE, "reason": "Heiliger Krieg gewonnen"},
			{"edge": "F12", "source": "Glaube", "target": "Herrschaft",
				"state": "houses[%d].legitimacy" % house_index, "kind": "legitimacy",
				"house": house_index, "amount": FAITH_HOLY_WAR_LEGITIMACY, "reason": "Heiliger Krieg gewonnen"},
		])
		f["holy_war"] = {"target": -1, "months": 0}
		houses[house_index]["faith"] = f
		_note_for_house(house_index, "Der heilige Krieg ist gewonnen: +%d Prestige, +%d Legitimität." % [FAITH_HOLY_WAR_PRESTIGE, FAITH_HOLY_WAR_LEGITIMACY])
		return
	months -= 1
	if months <= 0:
		f["holy_war"] = {"target": -1, "months": 0}
		_note_for_house(house_index, "Der heilige Krieg gegen %s ist versandet." % str(houses[target]["name"]))
	else:
		f["holy_war"] = {"target": target, "months": months}
	houses[house_index]["faith"] = f

func faith_piety_gain(house_index: int = -1) -> int:
	var gain: int = 1 + int(court_grandeur(house_index) / 50)
	if faith_site_count(house_index) > 0:
		gain += 1
	return gain

func faith_church_opinion_gain(house_index: int = -1) -> int:
	var power := faith_church_power(house_index)
	if power >= 80:
		return 2
	if power >= 60:
		return 1
	return 0

func faith_confession_info(confession: String) -> Dictionary:
	if not FAITH_DEFS.has(confession):
		return {}
	var d: Dictionary = FAITH_DEFS[confession]
	return {
		"id": confession, "name": str(d["name"]), "doctrine": str(d["doctrine"]),
		"effect": str(d["effect"]), "church_bonus": int(d["church_bonus"]),
		"icon": "faith_%s" % confession,
	}

func pilgrimage_cost(house_index: int = -1) -> int:
	return FAITH_PILGRIMAGE_COST

func pilgrimage_piety(house_index: int = -1) -> int:
	return FAITH_PILGRIMAGE_PIETY

func can_pilgrimage(house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or game_over:
		return false
	return int(houses[hi].get("gold", 0)) >= FAITH_PILGRIMAGE_COST and faith_piety(hi) < FAITH_MAX_PIETY

func pilgrimage(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not can_pilgrimage(hi):
		return _res(false, "Wallfahrt nicht möglich (30 Gold, Frömmigkeit nicht am Maximum).")
	var f: Dictionary = houses[hi]["faith"]
	var applied := _resolve([
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -FAITH_PILGRIMAGE_COST, "reason": "Wallfahrt"},
		{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.piety" % hi, "kind": "faith_piety", "house": hi,
			"amount": FAITH_PILGRIMAGE_PIETY, "reason": "Wallfahrt"},
	])
	if applied.is_empty():
		return _res(false, "Wallfahrt konnte nicht gebucht werden.")
	_refresh_faith_power(hi)
	if hi == player:
		note("Die Wallfahrt mehrt die Frömmigkeit (+%d)." % FAITH_PILGRIMAGE_PIETY)
	return _res(true, "Die Wallfahrt ist vollendet.")

func _site_reason(province_id: String, hi: int) -> String:
	if hi < 0 or hi >= houses.size():
		return "Ungültiges Haus."
	var p: Dictionary = province(province_id)
	if p.is_empty():
		return "Unbekannte Provinz."
	if int(p.get("owner", -1)) != hi:
		return "Die heilige Stätte muss dem Haus gehören."
	if faith_holy_sites(hi).has(province_id):
		return "Diese Stätte ist bereits geweiht."
	if faith_site_count(hi) >= FAITH_MAX_SITES:
		return "Es sind bereits %d heilige Stätten geweiht." % FAITH_MAX_SITES
	if int(houses[hi].get("gold", 0)) < FAITH_SITE_COST_GOLD:
		return "Zu wenig Gold (%d benötigt)." % FAITH_SITE_COST_GOLD
	if faith_piety(hi) < FAITH_SITE_COST_PIETY:
		return "Zu wenig Frömmigkeit (%d benötigt)." % FAITH_SITE_COST_PIETY
	if bool(disabled_edges.get("F4", false)):
		return "Die Glaubenskante F4 ist deaktiviert."
	return ""

func can_consecrate_site(province_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _site_reason(province_id, hi) == ""

func consecrate_site(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _site_reason(province_id, hi)
	if reason != "":
		return _res(false, "Stätte nicht weihbar: " + reason)
	var h: Dictionary = houses[hi]
	var applied := _resolve([
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -FAITH_SITE_COST_GOLD, "reason": "Heilige Stätte"},
		{"edge": "", "source": "Glaube", "target": "Glaube",
			"state": "houses[%d].faith.piety" % hi, "kind": "faith_piety", "house": hi,
			"amount": -FAITH_SITE_COST_PIETY, "reason": "Heilige Stätte"},
		{"edge": "F4", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": FAITH_SITE_PRESTIGE, "reason": "Heilige Stätte"},
	])
	if applied.is_empty():
		return _res(false, "Heilige Stätte konnte nicht gebucht werden.")
	var f: Dictionary = h["faith"]
	var sites: Array = f.get("holy_sites", [])
	sites.append(province_id)
	f["holy_sites"] = sites
	_refresh_faith_power(hi)
	if hi == player:
		note("%s wird zur heiligen Stätte geweiht (+%d Prestige)." % [str(province(province_id)["name"]), FAITH_SITE_PRESTIGE])
	return _res(true, "Heilige Stätte geweiht.")

func _convert_reason(confession: String, hi: int) -> String:
	if hi < 0 or hi >= houses.size():
		return "Ungültiges Haus."
	if not FAITH_DEFS.has(confession):
		return "Unbekannte Konfession."
	if faith_confession(hi) == confession:
		return "Diese Konfession ist bereits aktiv."
	if int(houses[hi].get("gold", 0)) < FAITH_CONVERT_COST_GOLD:
		return "Zu wenig Gold (%d benötigt)." % FAITH_CONVERT_COST_GOLD
	if int(houses[hi].get("prestige", 0)) < FAITH_CONVERT_COST_PRESTIGE:
		return "Zu wenig Prestige (%d benötigt)." % FAITH_CONVERT_COST_PRESTIGE
	return ""

func can_convert_faith(confession: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	return _convert_reason(confession, hi) == ""

func convert_faith(confession: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _convert_reason(confession, hi)
	if reason != "":
		return _res(false, "Bekehrung nicht möglich: " + reason)
	var h: Dictionary = houses[hi]
	var effects: Array = [
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -FAITH_CONVERT_COST_GOLD, "reason": "Bekehrung"},
		{"edge": "", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -FAITH_CONVERT_COST_PRESTIGE, "reason": "Bekehrung"},
	]
	for vi in h.get("vassals", []).size():
		effects.append({"edge": "", "source": "Glaube", "target": "Vasall",
			"state": "houses[%d].vassals[%d].opinion" % [hi, vi],
			"kind": "vassal_opinion", "house": hi, "index": vi,
			"amount": FAITH_CONVERT_OPINION, "reason": "Bekehrung"})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Bekehrung konnte nicht gebucht werden.")
	var f: Dictionary = h["faith"]
	f["confession"] = confession
	_refresh_faith_power(hi)
	if hi == player:
		note("Das Haus bekennt sich zu %s. Die Vasallen sind beunruhigt (%d Meinung)." % [str(FAITH_DEFS[confession]["name"]), FAITH_CONVERT_OPINION])
	return _res(true, "Konfession gewechselt.")

func _refresh_faith_power(house_index: int) -> void:
	if house_index < 0 or house_index >= houses.size():
		return
	var h: Dictionary = houses[house_index]
	var f: Dictionary = h.get("faith", {})
	f["church_power"] = _faith_church_power_from_parts(f, h)
	h["faith"] = f

func _apply_faith_piety(i: int) -> void:
	var amount := faith_piety_gain(i)
	if amount <= 0:
		return
	_resolve([{"edge": "", "source": "Glaube", "target": "Glaube",
		"state": "houses[%d].faith.piety" % i, "kind": "faith_piety", "house": i,
		"amount": amount, "reason": "Jährliche Andacht"}])
	_refresh_faith_power(i)

func _apply_faith_doctrine(i: int) -> void:
	match faith_confession(i):
		"sun":
			_resolve([{"edge": "F1", "source": "Glaube", "target": "Herrschaft",
				"state": "houses[%d].legitimacy" % i, "kind": "legitimacy", "house": i,
				"amount": 1, "reason": "Sonnenbund"}])
		"moon":
			_resolve([{"edge": "F2", "source": "Glaube", "target": "Intrige",
				"state": "houses[%d].council_effects.intrigue" % i, "kind": "council_intrigue", "house": i,
				"amount": 1, "reason": "Mondorakel"}])
		"earth":
			_resolve([{"edge": "F3", "source": "Glaube", "target": "Herrschaft",
				"state": "houses[%d].prestige" % i, "kind": "prestige", "house": i,
				"amount": 1, "reason": "Erdbund"}])

func _apply_faith_sites(i: int) -> void:
	for site_id in faith_holy_sites(i):
		_resolve([{"edge": "F4", "source": "Glaube", "target": "Herrschaft",
			"state": "houses[%d].prestige" % i, "kind": "prestige", "house": i,
			"amount": 1, "reason": "Heilige Stätte %s" % site_id}])

func _apply_faith_church(i: int) -> void:
	var amount := faith_church_opinion_gain(i)
	if amount <= 0:
		return
	for vi in houses[i].get("vassals", []).size():
		_resolve([{"edge": "F5", "source": "Glaube", "target": "Vasall",
			"state": "houses[%d].vassals[%d].opinion" % [i, vi], "kind": "vassal_opinion",
			"house": i, "index": vi, "amount": amount, "reason": "Kirchenmacht"}])

func _ai_faith(house_index: int) -> void:
	# Eine Glaubenshandlung pro Jahr: Ketzerei bekämpfen, Reform, heiliger Krieg,
	# dann Bekehrung, Weihe und Wallfahrt.
	var h: Dictionary = houses[house_index]
	if faith_heresy(house_index) >= 50 and can_suppress_heresy(house_index):
		suppress_heresy(house_index)
		return
	if int(h.get("gold", 0)) > 500 and can_reform_faith(house_index):
		reform_faith(house_index)
		return
	if int(h.get("gold", 0)) > 400 and faith_piety(house_index) >= 60 and int(h.get("prestige", 0)) >= 40 and faith_holy_war_target(house_index) < 0:
		for target in houses.size():
			if target != house_index and can_declare_holy_war(target, house_index):
				declare_holy_war(target, house_index)
				return
	if int(h.get("gold", 0)) > 500 and faith_piety(house_index) >= 80:
		var target := "sun" if int(h["ruler"].get("diplomacy", 0)) >= int(h["ruler"].get("intrigue", 0)) else "moon"
		if target != faith_confession(house_index) and can_convert_faith(target, house_index):
			convert_faith(target, house_index)
			return
	if int(h.get("gold", 0)) > 260 and faith_piety(house_index) >= 30:
		var site_id := ""
		for p in provinces:
			if int(p.get("owner", -1)) == house_index and not faith_holy_sites(house_index).has(str(p["id"])):
				site_id = str(p["id"])
				break
		if site_id != "" and can_consecrate_site(site_id, house_index):
			consecrate_site(site_id, house_index)
			return
	if int(h.get("gold", 0)) > 160 and faith_piety(house_index) < 50 and can_pilgrimage(house_index):
		pilgrimage(house_index)

# --- Systemische Welle 1 -------------------------------------------------

func _resolve(effects: Array) -> Array:
	return resolver.apply(self, effects)

func record_effect(entry: Dictionary) -> void:
	effect_log.append(entry)
	while effect_log.size() > 200:
		effect_log.pop_front()

func set_edge_enabled(edge: String, enabled: bool) -> void:
	disabled_edges[edge] = not enabled

# --- Vasallenverträge ----------------------------------------------------

func vassal_contract_level(vassal_index: int, house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var vassals: Array = houses[hi].get("vassals", [])
	if vassal_index < 0 or vassal_index >= vassals.size():
		return 0
	return clampi(int(vassals[vassal_index].get("level", 1)), 0, VASSAL_MAX_LEVEL)

func vassal_contract_info(vassal_index: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return {}
	var vassals: Array = houses[hi].get("vassals", [])
	if vassal_index < 0 or vassal_index >= vassals.size():
		return {}
	var v: Dictionary = vassals[vassal_index]
	var level: int = clampi(int(v.get("level", 1)), 0, VASSAL_MAX_LEVEL)
	var contract: Dictionary = VASSAL_CONTRACTS[level]
	var next_level: int = mini(VASSAL_MAX_LEVEL, level + 1)
	var lower_level: int = maxi(0, level - 1)
	return {
		"index": vassal_index, "name": str(v.get("name", "Vasall")), "level": level,
		"max": VASSAL_MAX_LEVEL, "contract": str(contract["name"]),
		"tax": int(contract["tax"]), "levy": int(contract["levy"]),
		"opinion": clampi(int(v.get("opinion", 50)), 0, 100),
		"next_level": next_level, "raise_cost": vassal_contract_cost(vassal_index, next_level, hi),
		"raise_legitimacy": 40 + 10 * next_level, "raise_prestige": 8 * next_level,
		"can_raise": can_change_vassal_contract(vassal_index, next_level, hi),
		"lower_level": lower_level, "lower_cost": 0,
		"can_lower": can_change_vassal_contract(vassal_index, lower_level, hi),
		"icon": "contract_%d" % level,
	}

func vassal_contract_cost(vassal_index: int, target_level: int, house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	var current: int = vassal_contract_level(vassal_index, hi)
	var target: int = clampi(target_level, 0, VASSAL_MAX_LEVEL)
	if target <= current:
		return 0
	return 40 + 20 * target

func _vassal_contract_reason(vassal_index: int, target_level: int, hi: int) -> String:
	if hi < 0 or hi >= houses.size():
		return "Ungültiges Haus."
	var vassals: Array = houses[hi].get("vassals", [])
	if vassal_index < 0 or vassal_index >= vassals.size():
		return "Ungültiger Vasall."
	var target: int = clampi(target_level, 0, VASSAL_MAX_LEVEL)
	var current: int = vassal_contract_level(vassal_index, hi)
	if target == current:
		return "Vertragsstufe unverändert."
	if target > current:
		var cost: int = vassal_contract_cost(vassal_index, target, hi)
		if int(houses[hi].get("gold", 0)) < cost:
			return "Zu wenig Gold (%d benötigt)." % cost
		if int(houses[hi].get("legitimacy", 0)) < 40 + 10 * target:
			return "Legitimität zu niedrig (%d benötigt)." % (40 + 10 * target)
		if int(houses[hi].get("prestige", 0)) < 8 * target:
			return "Prestige zu niedrig (%d benötigt)." % (8 * target)
	return ""

func can_change_vassal_contract(vassal_index: int, target_level: int, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or vassal_index < 0:
		return false
	return _vassal_contract_reason(vassal_index, target_level, hi) == ""

func change_vassal_contract(vassal_index: int, target_level: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var reason := _vassal_contract_reason(vassal_index, target_level, hi)
	if reason != "":
		return _res(false, "Vertrag nicht änderbar: " + reason)
	if bool(disabled_edges.get("V3", false)):
		return _res(false, "Vertragskante V3 ist deaktiviert.")
	var h: Dictionary = houses[hi]
	var v: Dictionary = h["vassals"][vassal_index]
	var old_level: int = vassal_contract_level(vassal_index, hi)
	var target: int = clampi(target_level, 0, VASSAL_MAX_LEVEL)
	var cost: int = vassal_contract_cost(vassal_index, target, hi)
	var opinion_delta: int = -10 if target > old_level else 10
	var effects: Array = []
	if cost > 0:
		effects.append({"edge": "V3", "source": "Vasall", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -cost, "reason": "Vertragsausgleich %s" % str(v["name"])})
	effects.append({"edge": "V3", "source": "Vasall", "target": "Herrschaft",
		"state": "houses[%d].vassals[%d].opinion" % [hi, vassal_index],
		"kind": "vassal_opinion", "house": hi, "index": vassal_index,
		"amount": opinion_delta, "reason": "Vertragsänderung %s" % str(v["name"])})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Vertragsänderung konnte nicht gebucht werden.")
	v["level"] = target
	if hi == player:
		note("%s wechselt auf %s (Stufe %d): Meinung %+d." % [str(v["name"]), str(VASSAL_CONTRACTS[target]["name"]), target, opinion_delta])
	return _res(true, "Vertrag von %s geändert." % str(v["name"]))

func vassal_tax_income(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var total: int = 0
	for vi in houses[hi].get("vassals", []).size():
		total += int(VASSAL_CONTRACTS[vassal_contract_level(vi, hi)]["tax"])
	return total

func vassal_levy_bonus(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var total: int = 0
	for vi in houses[hi].get("vassals", []).size():
		total += int(VASSAL_CONTRACTS[vassal_contract_level(vi, hi)]["levy"])
	return total

func vassal_opinion_avg(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var vassals: Array = houses[hi].get("vassals", [])
	if vassals.is_empty():
		return 0
	var total: int = 0
	for v in vassals:
		total += int(v.get("opinion", 50))
	return int(round(float(total) / float(vassals.size())))

func _apply_vassal_tax(i: int) -> void:
	var amount := vassal_tax_income(i)
	if amount <= 0:
		return
	_resolve([{"edge": "V1", "source": "Vasall", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": amount, "reason": "Vasallensteuern"}])

func _apply_vassal_politics(i: int) -> void:
	var av: int = vassal_opinion_avg(i)
	if av < 35:
		_resolve([{"edge": "V3", "source": "Vasall", "target": "Herrschaft",
			"state": "houses[%d].legitimacy" % i, "kind": "legitimacy", "house": i,
			"amount": -2, "reason": "Vasallenunmut"}])
	elif av > 65:
		_resolve([{"edge": "V3", "source": "Vasall", "target": "Herrschaft",
			"state": "houses[%d].legitimacy" % i, "kind": "legitimacy", "house": i,
			"amount": 2, "reason": "Vasallenloyalität"}])

# --- Rat -----------------------------------------------------------------

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

func council_role_name(office: String) -> String:
	return str(COUNCIL_OFFICES.get(office, {}).get("name", office))

func council_seat_vote(office: String, resolution_id: String, house_index: int = -1, opinion_avg: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var info = COUNCIL_RESOLUTIONS.get(resolution_id, {})
	var role: Dictionary = COUNCIL_OFFICES.get(office, {})
	var member := council_member(hi, office)
	if not (info is Dictionary) or info.is_empty() or role.is_empty() or member.is_empty():
		return {"office": office, "name": council_role_name(office), "member": "unbesetzt", "vote": false, "score": 0, "key": false}
	var stat: int = int(member.get(str(role["stat"]), 0))
	var avg: int = vassal_opinion_avg(hi) if opinion_avg < 0 else opinion_avg
	var score: int = int(member.get("loyalty", 50)) + stat * 2 + int(int(houses[hi].get("legitimacy", 50)) / 5) + int(avg / 10)
	return {
		"office": office, "name": council_role_name(office), "member": str(member.get("name", "?")),
		"vote": score >= 90, "score": score, "key": office == str(info["role"]),
	}

func council_vote_preview(resolution_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var info = COUNCIL_RESOLUTIONS.get(resolution_id, {})
	if not (info is Dictionary) or info.is_empty():
		return {"votes": [], "yes": 0, "required": 3, "passed": false}
	var votes: Array = []
	var yes: int = 0
	var key_yes: bool = false
	var avg: int = vassal_opinion_avg(hi)
	for office in COUNCIL_ROLES:
		var vote := council_seat_vote(str(office), resolution_id, hi, avg)
		votes.append(vote)
		if bool(vote["vote"]):
			yes += 1
		if bool(vote["key"]):
			key_yes = bool(vote["vote"])
	var required: int = 3
	return {"votes": votes, "yes": yes, "required": required,
		"passed": yes >= required and key_yes, "key_yes": key_yes}

func can_enact_council_resolution(resolution_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	var info = COUNCIL_RESOLUTIONS.get(resolution_id, {})
	if not (info is Dictionary) or info.is_empty() or hi < 0 or hi >= houses.size():
		return false
	if int(houses[hi].get("gold", 0)) < int(info["cost_gold"]):
		return false
	if int(houses[hi].get("prestige", 0)) < int(info["cost_prestige"]):
		return false
	return bool(council_vote_preview(resolution_id, hi).get("passed", false))

func enact_council_resolution(resolution_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var info = COUNCIL_RESOLUTIONS.get(resolution_id, {})
	if not (info is Dictionary) or info.is_empty():
		return _res(false, "Unbekannter Ratsbeschluss.")
	if not can_enact_council_resolution(resolution_id, hi):
		return _res(false, "Ratsbeschluss nicht möglich: Kosten oder Mehrheit fehlen.")
	var h: Dictionary = houses[hi]
	var effects: Array = []
	if int(info["cost_gold"]) > 0:
		effects.append({"edge": "C5", "source": "Rat", "target": "Herrschaft",
			"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
			"amount": -int(info["cost_gold"]), "reason": "Ratsbeschluss %s" % str(info["name"])})
	if int(info["cost_prestige"]) > 0:
		effects.append({"edge": "C5", "source": "Rat", "target": "Herrschaft",
			"state": "houses[%d].prestige" % hi, "kind": "prestige", "house": hi,
			"amount": -int(info["cost_prestige"]), "reason": "Ratsbeschluss %s" % str(info["name"])})
	match resolution_id:
		"war_levy":
			var capital := province(str(h.get("capital", "")))
			if capital.is_empty():
				return _res(false, "Keine Hauptstadt für das Aufgebot.")
			effects.append({"edge": "C1", "source": "Rat", "target": "Krieg",
				"state": "provinces[%s].levy" % str(capital["id"]), "kind": "levy",
				"house": hi, "province": str(capital["id"]), "amount": 80, "reason": "Kriegsaufgebot"})
			effects.append({"edge": "C1", "source": "Rat", "target": "Herrschaft",
				"state": "houses[%d].legitimacy" % hi, "kind": "legitimacy", "house": hi,
				"amount": 2, "reason": "Kriegsaufgebot"})
			for vi in h["vassals"].size():
				effects.append({"edge": "C1", "source": "Rat", "target": "Vasall",
					"state": "houses[%d].vassals[%d].opinion" % [hi, vi],
					"kind": "vassal_opinion", "house": hi, "index": vi,
					"amount": -3, "reason": "Kriegsaufgebot"})
		"land_frieden":
			for vi in h["vassals"].size():
				effects.append({"edge": "C2", "source": "Rat", "target": "Vasall",
					"state": "houses[%d].vassals[%d].opinion" % [hi, vi], "kind": "vassal_opinion",
					"house": hi, "index": vi, "amount": 6, "reason": "Landfrieden"})
			effects.append({"edge": "C2", "source": "Rat", "target": "Herrschaft",
				"state": "houses[%d].legitimacy" % hi, "kind": "legitimacy", "house": hi,
				"amount": 2, "reason": "Landfrieden"})
		"crown_tax":
			effects.append({"edge": "C3", "source": "Rat", "target": "Herrschaft",
				"state": "houses[%d].gold" % hi, "kind": "gold", "house": hi,
				"amount": 80, "reason": "Kronsteuer"})
			for vi in h["vassals"].size():
				effects.append({"edge": "C3", "source": "Rat", "target": "Vasall",
					"state": "houses[%d].vassals[%d].opinion" % [hi, vi], "kind": "vassal_opinion",
					"house": hi, "index": vi, "amount": -4, "reason": "Kronsteuer"})
		"shadow_network":
			effects.append({"edge": "C4", "source": "Rat", "target": "Intrige",
				"state": "houses[%d].council_effects.intrigue" % hi, "kind": "council_intrigue",
				"house": hi, "amount": 2, "reason": "Schattennetz"})
			for vi in h["vassals"].size():
				effects.append({"edge": "C4", "source": "Rat", "target": "Vasall",
					"state": "houses[%d].vassals[%d].opinion" % [hi, vi], "kind": "vassal_opinion",
					"house": hi, "index": vi, "amount": -1, "reason": "Schattennetz"})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Ratsbeschluss konnte nicht gebucht werden.")
	h["council_effects"]["history"].append({"id": resolution_id, "name": str(info["name"]), "year": year, "month": month})
	while h["council_effects"]["history"].size() > 8:
		h["council_effects"]["history"].pop_front()
	if hi == player:
		note("Der Rat beschließt %s." % str(info["name"]))
	return _res(true, "Ratsbeschluss %s umgesetzt." % str(info["name"]))

func council_steward_income(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	var member := council_member(hi, "steward")
	if member.is_empty():
		return 0
	return 1 + int(int(member.get("stewardship", 0)) / 8)

func _apply_steward_income(i: int) -> void:
	var amount := council_steward_income(i)
	if amount <= 0:
		return
	_resolve([{"edge": "C3", "source": "Rat", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": amount, "reason": "Kämmerersteuer"}])

func chancellor_opinion_gain(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	var member := council_member(hi, "chancellor")
	if member.is_empty():
		return 0
	return 1 + int(int(member.get("diplomacy", 0)) / 8)

func _apply_chancellor_opinion(i: int) -> void:
	var amount := chancellor_opinion_gain(i)
	if amount <= 0:
		return
	for vi in houses[i].get("vassals", []).size():
		_resolve([{"edge": "C2", "source": "Rat", "target": "Vasall",
			"state": "houses[%d].vassals[%d].opinion" % [i, vi], "kind": "vassal_opinion",
			"house": i, "index": vi, "amount": amount, "reason": "Kanzler"}])

func spymaster_intrigue_bonus(house_index: int = -1) -> float:
	var hi: int = player if house_index < 0 else house_index
	var member := council_member(hi, "spymaster")
	var passive: float = 0.0
	if not member.is_empty():
		passive = 0.01 * (1.0 + float(int(member.get("intrigue", 0))) / 6.0)
	var active: float = 0.01 * float(int(houses[hi].get("council_effects", {}).get("intrigue", 0)))
	return clampf(passive + active, 0.0, 0.15)

func council_intrigue_percent(house_index: int = -1) -> int:
	return int(round(spymaster_intrigue_bonus(house_index) * 100.0))

func council_resolution_info(resolution_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	var info = COUNCIL_RESOLUTIONS.get(resolution_id, {})
	if not (info is Dictionary) or info.is_empty():
		return {}
	var preview := council_vote_preview(resolution_id, hi)
	return {
		"id": resolution_id, "name": str(info["name"]), "role": str(info["role"]),
		"role_name": council_role_name(str(info["role"])), "effect": str(info["effect"]),
		"cost_gold": int(info["cost_gold"]), "cost_prestige": int(info["cost_prestige"]),
		"votes": preview.get("votes", []), "yes": int(preview.get("yes", 0)),
		"required": int(preview.get("required", 3)), "passed": bool(preview.get("passed", false)),
		"can_enact": can_enact_council_resolution(resolution_id, hi),
	}

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
	if not applied.is_empty():
		_note_for_house(i, "%s trainiert %s (+%d Truppen)." % [marshal["name"], capital["name"], amount])

func assign_council(office: String, courtier_index: int, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return _res(false, "Ungültiges Haus.")
	if not COUNCIL_ROLES.has(office):
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
	if best >= 0 and int(h.get("council", {}).get(office, -1)) != best:
		assign_council(office, best, house_index)

func run_ai_turn() -> void:
	for i in houses.size():
		if is_human_house(i):
			continue
		var h: Dictionary = houses[i]
		if h.get("courtiers", []).is_empty():
			continue
		_assign_best_council(i)
		_ai_court(i)
		_ai_faith(i)
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
		if h["fleets"].is_empty() and int(h.get("gold", 0)) >= FLEET_COST:
			var port_id := _ai_port(i)
			if port_id != "":
				raise_fleet(port_id, i)
		if not h["fleets"].is_empty() and not _ai_has_blockade(i):
			var naval_target := _ai_naval_target(i)
			if naval_target != "":
				blockade(naval_target, i)
		if not h["secrets"].is_empty():
			var secret_target: int = int(h["secrets"][0].get("target", -1))
			if secret_target >= 0:
				expose_secret(secret_target, i)
		elif int(h.get("gold", 0)) >= 120:
			for target in houses.size():
				if target != i:
					discover_secret(target, i)
					break
		var legacy_track := _ai_legacy_choice(i)
		if legacy_track != "":
			unlock_legacy(legacy_track, i)
		var ai_resolution := _ai_council_choice(i)
		if ai_resolution != "":
			enact_council_resolution(ai_resolution, i)
		var ai_contract := _ai_vassal_contract(i)
		if ai_contract >= 0:
			change_vassal_contract(ai_contract, vassal_contract_level(ai_contract, i) + 1, i)

func _assign_best_council(house_index: int) -> void:
	var h: Dictionary = houses[house_index]
	var roles: Array = ["marshal", "chancellor", "steward", "spymaster"]
	var stats: Array = ["martial", "diplomacy", "stewardship", "intrigue"]
	var best: Array = [-1, -1, -1, -1]
	var best_values: Array = [-999, -999, -999, -999]
	for idx in h["courtiers"].size():
		var courtier: Dictionary = h["courtiers"][idx]
		for role_index in 4:
			var value: int = int(courtier.get(stats[role_index], 0))
			if value > int(best_values[role_index]):
				best_values[role_index] = value
				best[role_index] = idx
	var council: Dictionary = h.get("council", {})
	for role_index in 4:
		var candidate: int = int(best[role_index])
		if candidate >= 0 and int(council.get(roles[role_index], -1)) != candidate:
			assign_council(str(roles[role_index]), candidate, house_index)

func _ai_council_choice(house_index: int) -> String:
	var h: Dictionary = houses[house_index]
	if int(h.get("gold", 0)) < 220:
		return ""
	var preferred: Array = ["land_frieden", "crown_tax", "war_levy", "shadow_network"]
	if int(h["ruler"].get("martial", 0)) > int(h["ruler"].get("diplomacy", 0)):
		preferred = ["war_levy", "crown_tax", "land_frieden", "shadow_network"]
	elif int(h["ruler"].get("intrigue", 0)) > int(h["ruler"].get("stewardship", 0)):
		preferred = ["shadow_network", "land_frieden", "crown_tax", "war_levy"]
	for resolution_id in preferred:
		if can_enact_council_resolution(str(resolution_id), house_index):
			return str(resolution_id)
	return ""

func _ai_vassal_contract(house_index: int) -> int:
	var h: Dictionary = houses[house_index]
	if int(h.get("gold", 0)) < 260:
		return -1
	var best: int = -1
	var best_level: int = 99
	for vi in h["vassals"].size():
		var level := vassal_contract_level(vi, house_index)
		if level < VASSAL_MAX_LEVEL and can_change_vassal_contract(vi, level + 1, house_index):
			if level < best_level and int(h["gold"]) > vassal_contract_cost(vi, level + 1, house_index) + 40:
				best = vi
				best_level = level
	return best

func _ai_legacy_choice(house_index: int) -> String:
	var h: Dictionary = houses[house_index]
	var preferred: Array = ["crown", "war", "guile"]
	if int(h["ruler"].get("martial", 0)) > int(h["ruler"].get("stewardship", 0)):
		preferred = ["war", "crown", "guile"]
	elif int(h["ruler"].get("intrigue", 0)) > int(h["ruler"].get("diplomacy", 0)):
		preferred = ["guile", "crown", "war"]
	for track in preferred:
		if can_unlock_legacy(track, house_index):
			return str(track)
	return ""
func _ai_port(house_index: int) -> String:
	var capital := province(str(houses[house_index].get("capital", "")))
	if not capital.is_empty() and is_coastal(str(capital["id"])):
		return str(capital["id"])
	for p in provinces:
		if int(p["owner"]) == house_index and is_coastal(str(p["id"])):
			return str(p["id"])
	return ""

func _ai_has_blockade(house_index: int) -> bool:
	for p in provinces:
		if int(p.get("blockade_owner", -1)) == house_index and int(p.get("blockade", 0)) > 0:
			return true
	return false

func _ai_naval_target(house_index: int) -> String:
	for claim in houses[house_index].get("claims", []):
		var claimed: String = str(claim.get("province", ""))
		if claimed != "" and can_blockade(claimed, house_index):
			return claimed
	# Eine Blockade der eigenen Küste wird mit einer Gegenblockade beantwortet.
	var player_is_blockading := false
	for p in provinces:
		if int(p["owner"]) == house_index and int(p.get("blockade_owner", -1)) == player and int(p.get("blockade", 0)) > 0:
			player_is_blockading = true
			break
	if not player_is_blockading:
		return ""
	for p in provinces:
		if int(p["owner"]) == player and can_blockade(str(p["id"]), house_index):
			return str(p["id"])
	return ""

func legacy_level(track: String, house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or not LEGACY_TRACKS.has(track):
		return 0
	var legacies = houses[hi].get("legacies", {})
	if not (legacies is Dictionary):
		return 0
	return clampi(int(legacies.get(track, 0)), 0, LEGACY_MAX_LEVEL)

func legacy_cost(track: String, house_index: int = -1) -> int:
	if not LEGACY_TRACKS.has(track):
		return -1
	var level := legacy_level(track, house_index)
	if level >= LEGACY_MAX_LEVEL:
		return -1
	return int((LEGACY_TRACKS[track]["costs"] as Array)[level])

func can_unlock_legacy(track: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or not LEGACY_TRACKS.has(track):
		return false
	var cost := legacy_cost(track, hi)
	return cost >= 0 and int(houses[hi].get("renown", 0)) >= cost

func unlock_legacy(track: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not can_unlock_legacy(track, hi):
		return _res(false, "Vermächtnis nicht verfügbar (Ruhm oder Maximalstufe).")
	var cost := legacy_cost(track, hi)
	var edge: String = {"war": "L1", "crown": "L2", "guile": "L3"}[track]
	var effects: Array = [
		{"edge": edge, "source": "Dynastie", "target": "Dynastie",
			"state": "houses[%d].renown" % hi, "kind": "renown", "house": hi,
			"amount": -cost, "reason": "Vermächtnis %s" % str(LEGACY_TRACKS[track]["name"])},
		{"edge": edge, "source": "Dynastie", "target": "Dynastie",
			"state": "houses[%d].legacies.%s" % [hi, track], "kind": "legacy",
			"house": hi, "legacy": track, "amount": 1,
			"reason": "Vermächtnis %s" % str(LEGACY_TRACKS[track]["name"])},
	]
	if track == "crown":
		effects.append({"edge": "L2", "source": "Dynastie", "target": "Herrschaft",
			"state": "houses[%d].legitimacy" % hi, "kind": "legitimacy", "house": hi,
			"amount": 2, "reason": "Kronvermächtnis"})
	var applied := _resolve(effects)
	if applied.is_empty():
		return _res(false, "Vermächtnis konnte nicht freigeschaltet werden.")
	if hi == player:
		note("%s freigeschaltet: Stufe %d." % [str(LEGACY_TRACKS[track]["name"]), legacy_level(track, hi)])
	return _res(true, "%s freigeschaltet." % str(LEGACY_TRACKS[track]["name"]))

func legacy_war_multiplier(house_index: int = -1) -> float:
	return 1.0 + 0.10 * float(legacy_level("war", house_index))

func renown_gain(house_index: int = -1) -> int:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return 0
	var h: Dictionary = houses[hi]
	var owned_count: int = 0
	for p in provinces:
		if int(p["owner"]) == hi:
			owned_count += 1
	var gain: int = 2 + int(int(h["prestige"]) / 80) + int(owned_count / 6) + int(int(h["ruler"]["diplomacy"]) / 12)
	return clampi(gain, 1, 12)

func _tick_dynasty() -> void:
	for i in houses.size():
		var gain := renown_gain(i)
		_resolve([{
			"source": "Dynastie", "target": "Dynastie",
			"state": "houses[%d].renown" % i, "kind": "renown", "house": i,
			"amount": gain, "reason": "Dynastischer Ruhm",
		}])

func legacy_track_info(track: String) -> Dictionary:
	return LEGACY_TRACKS.get(track, {})

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
		{"source": "Dynastie", "target": "Dynastie",
			"state": "houses[%d].renown" % hi, "kind": "renown", "house": hi,
			"amount": 12, "reason": "Eheverbindung"},
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
	_apply_legacy_income(i)
	_apply_vassal_tax(i)
	_apply_steward_income(i)

func _apply_legacy_income(i: int) -> void:
	var crown_level := legacy_level("crown", i)
	if crown_level <= 0:
		return
	_resolve([{
		"edge": "L2", "source": "Dynastie", "target": "Herrschaft",
		"state": "houses[%d].gold" % i, "kind": "gold", "house": i,
		"amount": crown_level * 2, "reason": "Kronvermächtnis %d" % crown_level,
	}])

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
		_note_for_house(i, "%s: Versorgung im %s reicht nicht; %d Mann gehen verloren." % [str(p["name"]), str(p.get("terrain_name", "Gelände")), loss])

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
	if not is_human_house(i) or int(houses[i]["legitimacy"]) >= 40:
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
	var base_strength: int = maxi(100, int(round(float(int(p["levy"]) / 2) * legacy_war_multiplier(hi))))
	var vassal_levy := vassal_levy_bonus(hi)
	var strength: int = base_strength + vassal_levy
	houses[hi]["gold"] = int(houses[hi]["gold"]) - 50
	houses[hi]["armies"].append({
		"id": houses[hi]["armies"].size() + 1, "province": province_id,
		"strength": strength, "upkeep": maxi(1, int(strength / 250)), "morale": 100,
	})
	if vassal_levy > 0:
		record_effect({"edge": "V2", "source": "Vasall", "target": "Krieg",
			"state": "houses[%d].armies[%d].strength" % [hi, houses[hi]["armies"].size() - 1],
			"kind": "army_strength", "house": hi, "before": base_strength, "after": strength,
			"delta": vassal_levy, "reason": "Vasallenaufgebot"})
	if hi == player:
		note("In %s wird eine Armee von %d Mann aufgestellt." % [p["name"], strength])
	return _res(true, "Armee aufgestellt.")

func army_for(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or houses[hi]["armies"].is_empty():
		return {}
	return houses[hi]["armies"][0]

# --- Seekrieg ------------------------------------------------------------

func is_coastal(province_id: String) -> bool:
	return data.is_coastal(province_id)

func fleet_for(house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size() or houses[hi].get("fleets", []).is_empty():
		return {}
	return houses[hi]["fleets"][0]

func can_raise_fleet(province_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return false
	var p := province(province_id)
	if p.is_empty() or int(p["owner"]) != hi:
		return false
	if not is_coastal(province_id):
		return false
	if not fleet_for(hi).is_empty():
		return false
	return int(houses[hi]["gold"]) >= FLEET_COST

func raise_fleet(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not can_raise_fleet(province_id, hi):
		return _res(false, "Flotte nur in einer eigenen Küstenprovinz ohne bestehende Flotte (60 Gold).")
	var p := province(province_id)
	var h: Dictionary = houses[hi]
	var ships: int = clampi(8 + int(p["dev"]) + int(int(p["levy"]) / 180) + int(int(h["ruler"]["martial"]) / 3), 8, 24)
	h["gold"] = int(h["gold"]) - FLEET_COST
	h["fleets"].append({
		"id": h["fleets"].size() + 1, "province": province_id, "station": province_id,
		"ships": ships, "upkeep": maxi(1, int(ceil(float(ships) / 10.0))), "morale": 100,
	})
	if hi == player:
		note("In %s wird eine Flotte von %d Schiffen aufgestellt." % [p["name"], ships])
	return _res(true, "Flotte aufgestellt.")

## Eine Flotte kann nur in benachbarten Küstengewässern operieren. Die
## Königreichsnachbarschaft bildet dabei die Seekarte ab, ohne einen zweiten
## Seazonen-Graphen zu pflegen.
func _maritime_reachable(origin_id: String, target_id: String) -> bool:
	var origin := province(origin_id)
	var target := province(target_id)
	if origin.is_empty() or target.is_empty():
		return false
	if str(origin["kingdom"]) == str(target["kingdom"]):
		return true
	var neighbours: Array = data.kingdom_neighbours().get(str(origin["kingdom"]), [])
	return neighbours.has(str(target["kingdom"]))

func can_blockade(province_id: String, house_index: int = -1) -> bool:
	var hi: int = player if house_index < 0 else house_index
	if hi < 0 or hi >= houses.size():
		return false
	var target := province(province_id)
	if target.is_empty() or int(target["owner"]) == hi:
		return false
	if not is_coastal(province_id):
		return false
	var fleet := fleet_for(hi)
	if fleet.is_empty() or int(fleet.get("ships", 0)) <= 0 or int(fleet.get("morale", 0)) < 20:
		return false
	if not _maritime_reachable(str(fleet.get("province", "")), province_id):
		return false
	if truce_until(int(target["owner"]), hi) > _now():
		return false
	if int(target.get("blockade", 0)) > 0 and int(target.get("blockade_owner", -1)) != hi:
		return false
	return true

func blockade(province_id: String, house_index: int = -1) -> Dictionary:
	var hi: int = player if house_index < 0 else house_index
	if not can_blockade(province_id, hi):
		return _res(false, "Blockade nicht möglich (eigene Flotte, Küstenziel, Seeweg, kein Waffenstillstand).")
	var h: Dictionary = houses[hi]
	var target := province(province_id)
	var fleet := fleet_for(hi)
	var defender: int = int(target["owner"])
	var defending_fleet := _defending_fleet(province_id, defender)
	var battle_text := ""
	if not defending_fleet.is_empty():
		var battle := _naval_battle(fleet, hi, defending_fleet, defender)
		battle_text = str(battle.get("msg", ""))
		if not bool(battle.get("won", false)):
			_note_for_houses([hi, defender], "Seeschlacht vor %s: %s" % [target["name"], battle_text])
			return _res(false, battle_text)
	target["blockade"] = BLOCKADE_MONTHS
	target["blockade_owner"] = hi
	target["levy"] = maxi(40, int(int(target["levy"]) * 0.9))
	fleet["station"] = province_id
	fleet["morale"] = mini(100, int(fleet.get("morale", 100)) + 3)
	var loot: int = mini(8 + int(target["dev"]) * 3, int(houses[defender]["gold"]))
	if loot > 0:
		houses[defender]["gold"] = int(houses[defender]["gold"]) - loot
		h["gold"] = int(h["gold"]) + loot
	h["prestige"] = int(h["prestige"]) + 3
	var prefix := ""
	if battle_text != "":
		prefix = battle_text + " "
	_note_for_houses([hi, defender], "%sDie Küste von %s wird blockiert (%d Monate, %d Gold Beute)." % [prefix, target["name"], BLOCKADE_MONTHS, loot])
	return _res(true, "Küste von %s blockiert." % target["name"])

func _defending_fleet(province_id: String, house_index: int) -> Dictionary:
	if house_index < 0 or house_index >= houses.size():
		return {}
	for fleet in houses[house_index].get("fleets", []):
		if int(fleet.get("ships", 0)) <= 0:
			continue
		if str(fleet.get("station", "")) == province_id or str(fleet.get("province", "")) == province_id:
			return fleet
	return {}

func _naval_battle(attacker: Dictionary, attacker_house: int, defender: Dictionary, defender_house: int) -> Dictionary:
	var attack_roll: float = randf_range(0.85, 1.15)
	if attack_roll_override >= 0.0:
		attack_roll = attack_roll_override
	var attack_power: float = float(attacker.get("ships", 0)) * (0.8 + float(attacker.get("morale", 100)) / 200.0 + float(houses[attacker_house]["ruler"].get("martial", 8)) / 40.0) * attack_roll
	var defense_power: float = float(defender.get("ships", 0)) * (0.8 + float(defender.get("morale", 100)) / 200.0 + float(houses[defender_house]["ruler"].get("martial", 8)) / 40.0) * randf_range(0.85, 1.15)
	if attack_power >= defense_power:
		var defender_before: int = int(defender.get("ships", 0))
		var defender_loss: int = maxi(2, int(round(float(defender_before) * 0.55)))
		var attacker_loss: int = maxi(1, int(round(float(defender_before) * 0.25)))
		defender["ships"] = maxi(0, defender_before - defender_loss)
		attacker["ships"] = maxi(0, int(attacker.get("ships", 0)) - attacker_loss)
		defender["morale"] = maxi(0, int(defender.get("morale", 100)) - 25)
		attacker["morale"] = mini(100, int(attacker.get("morale", 100)) + 5)
		var msg := "Seesieg: %d Schiffe verloren, %d feindliche versenkt." % [attacker_loss, defender_loss]
		if int(defender["ships"]) <= 0:
			_sink_fleet(defender_house, defender)
		if int(attacker["ships"]) <= 0:
			_sink_fleet(attacker_house, attacker)
		return {"won": int(attacker["ships"]) > 0, "msg": msg}
	var attacker_before: int = int(attacker.get("ships", 0))
	var attacker_loss: int = maxi(2, int(round(float(attacker_before) * 0.5)))
	var defender_loss: int = maxi(1, int(round(float(attacker_before) * 0.15)))
	attacker["ships"] = maxi(0, attacker_before - attacker_loss)
	defender["ships"] = maxi(1, int(defender.get("ships", 0)) - defender_loss)
	attacker["morale"] = maxi(0, int(attacker.get("morale", 100)) - 25)
	defender["morale"] = mini(100, int(defender.get("morale", 100)) + 3)
	var lost_msg := "Seeniederlage: %d Schiffe verloren." % attacker_loss
	if int(attacker["ships"]) <= 0:
		_sink_fleet(attacker_house, attacker)
	return {"won": false, "msg": lost_msg}

func _sink_fleet(house_index: int, fleet: Dictionary) -> void:
	if house_index < 0 or house_index >= houses.size():
		return
	var kept: Array = []
	for item in houses[house_index].get("fleets", []):
		if int(item.get("id", -1)) != int(fleet.get("id", -2)):
			kept.append(item)
	houses[house_index]["fleets"] = kept
	_clear_blockades(house_index)
	_note_for_house(house_index, "Die eigene Flotte ist versenkt worden.")

func _clear_blockades(house_index: int) -> void:
	for p in provinces:
		if int(p.get("blockade_owner", -1)) == house_index and int(p.get("blockade", 0)) > 0:
			_release_blockade(p)

func _release_blockade(p: Dictionary) -> void:
	var province_id: String = str(p.get("id", ""))
	var blockader: int = int(p.get("blockade_owner", -1))
	p["blockade"] = 0
	p["blockade_owner"] = -1
	if blockader < 0 or blockader >= houses.size():
		return
	for fleet in houses[blockader].get("fleets", []):
		if str(fleet.get("station", "")) == province_id:
			fleet["station"] = str(fleet.get("province", province_id))

func _tick_naval() -> void:
	for p in provinces:
		var months: int = int(p.get("blockade", 0))
		if months <= 0:
			continue
		var blockader: int = int(p.get("blockade_owner", -1))
		var target_owner: int = int(p["owner"])
		if blockader < 0 or blockader >= houses.size() or blockader == target_owner:
			_release_blockade(p)
			continue
		months -= 1
		p["blockade"] = months
		if months <= 0:
			_release_blockade(p)
			_note_for_houses([blockader, target_owner], "Die Blockade von %s endet." % str(p["name"]))
			continue
		var loot: int = mini(3 + int(p.get("dev", 1)), int(houses[target_owner]["gold"]))
		if loot > 0:
			houses[target_owner]["gold"] = int(houses[target_owner]["gold"]) - loot
			houses[blockader]["gold"] = int(houses[blockader]["gold"]) + loot
		p["levy"] = maxi(40, int(p["levy"]) - maxi(5, int(int(p["levy"]) * 0.02)))

func _apply_fleet_upkeep(i: int) -> void:
	var h: Dictionary = houses[i]
	var kept: Array = []
	for fleet in h.get("fleets", []):
		var cost: int = int(fleet.get("upkeep", 1))
		if int(h["gold"]) >= cost:
			h["gold"] = int(h["gold"]) - cost
			fleet["morale"] = mini(100, int(fleet.get("morale", 100)) + 5)
			kept.append(fleet)
		else:
			fleet["morale"] = maxi(0, int(fleet.get("morale", 100)) - 20)
			fleet["ships"] = maxi(0, int(fleet.get("ships", 0)) - 1)
			_note_for_house(i, "Der Flottenunterhalt ist nicht bezahlt; Schiffe desertieren.")
			if int(fleet["ships"]) > 0:
				kept.append(fleet)
	h["fleets"] = kept
	if kept.is_empty():
		_clear_blockades(i)

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
	if int(p.get("blockade", 0)) > 0:
		_release_blockade(p)
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
	_note_for_house(new_owner, "Die Belagerung nimmt %s ein." % p["name"])

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
	for p in provinces:
		var blockader: int = int(p.get("blockade_owner", -1))
		if int(p.get("blockade", 0)) <= 0:
			continue
		if (blockader == hi and int(p["owner"]) == target_house) or (blockader == target_house and int(p["owner"]) == hi):
			_release_blockade(p)
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
	# Einsbasierte Altfristen und Chronikwerte behalten ihre Bedeutung.
	return calendar_index() + 1

func _cooldown_left(key: String) -> int:
	return int(cooldowns.get(key, 0)) - _now()

func _set_cooldown(key: String, months: int) -> void:
	cooldowns[key] = _now() + months

func _chance(kind: String, target: int) -> float:
	var r: Dictionary = house()["ruler"]
	var guile_bonus: float = 0.03 * float(legacy_level("guile", player)) + spymaster_intrigue_bonus(player)
	match kind:
		"marry":
			return clampf(0.45 + int(r["diplomacy"]) * 0.02 + int(house()["prestige"]) * 0.0015 + int(opinion[target]) * 0.004, 0.10, 0.95)
		"seduce":
			var t: Dictionary = houses[target]["ruler"]
			return clampf(0.25 + int(r["diplomacy"]) * 0.02 + int(r["intrigue"]) * 0.025 - int(t["intrigue"]) * 0.015 + int(opinion[target]) * 0.002 + guile_bonus, 0.05, 0.90)
		"murder":
			var m: Dictionary = houses[target]["ruler"]
			return clampf(0.12 + int(r["intrigue"]) * 0.035 - int(m["intrigue"]) * 0.02 + (100 - int(m["health"])) * 0.002 + guile_bonus, 0.05, 0.85)
		"kidnap":
			var k: Dictionary = houses[target]["ruler"]
			return clampf(0.20 + int(r["martial"]) * 0.02 + int(r["intrigue"]) * 0.02 - int(k["martial"]) * 0.01 + guile_bonus, 0.05, 0.85)
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
			"blockade": int(p.get("blockade", 0)),
			"blockade_owner": int(p.get("blockade_owner", -1)),
		})
	var data_state: Dictionary = extra_state.duplicate(true)
	data_state["year"] = year
	data_state["month"] = month
	data_state["calendar_version"] = 1
	data_state["month_index"] = calendar_index()
	data_state["campaign_sandbox"] = campaign_sandbox
	data_state["roads"] = roads.duplicate(true)
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
	data_state["event_instance"] = _event_instance
	if not human_houses.is_empty():
		_store_player_context()
		data_state["lan_human_houses"] = human_houses.duplicate()
		if _lan_projection:
			data_state["lan_projection"] = true
			data_state.erase("lan_contexts")
		else:
			data_state["lan_contexts"] = _player_contexts.duplicate(true)
			data_state.erase("lan_projection")
	return SaveGameScript.make_current(data_state)

func snapshot_for_player(index: int) -> Dictionary:
	if index < 0 or index >= houses.size() or (not human_houses.is_empty() and not human_houses.has(index)):
		return {}
	var previous_player := player
	select_player_context(index)
	var out := snapshot()
	select_player_context(previous_player)
	out.erase("lan_contexts")
	if not human_houses.is_empty():
		out["lan_projection"] = true
	return out

func _valid_personal_context(context, house_count: int) -> bool:
	if not context is Dictionary:
		return false
	for key in ["event_timer", "event_instance", "scandal"]:
		if not _whole_number(context.get(key)) or int(context[key]) < 0 or int(context[key]) > 1000000000:
			return false
	if not context.get("game_over") is bool or not context.get("victory") is bool:
		return false
	var opinions = context.get("opinion")
	if not opinions is Array or opinions.size() != house_count:
		return false
	for value in opinions:
		if not _whole_number(value) or absi(int(value)) > 1000000000:
			return false
	var pending = context.get("pending")
	if not pending is String:
		return false
	if pending != "":
		var known := false
		for event in data.events():
			if str(event["id"]) == pending:
				known = true
				break
		if not known or int(context["event_instance"]) < 1:
			return false
	var saved_cooldowns = context.get("cooldowns")
	if not saved_cooldowns is Dictionary or saved_cooldowns.size() > 256:
		return false
	for key in saved_cooldowns:
		if not key is String or key.length() > 128 or not _whole_number(saved_cooldowns[key]) or int(saved_cooldowns[key]) < 0 or int(saved_cooldowns[key]) > 1000000000:
			return false
	var saved_captive = context.get("captive")
	if not saved_captive is Dictionary:
		return false
	if not saved_captive.is_empty():
		if not _whole_number(saved_captive.get("house")) or int(saved_captive["house"]) < 0 or int(saved_captive["house"]) >= house_count:
			return false
		if not saved_captive.get("name") is String or str(saved_captive["name"]).length() > 256 or not ["m", "f"].has(saved_captive.get("gender")):
			return false
		if not _whole_number(saved_captive.get("months")) or int(saved_captive["months"]) < 0 or int(saved_captive["months"]) > 24:
			return false
	var lines = context.get("log")
	if not lines is Array or lines.size() > 10:
		return false
	for line in lines:
		if not line is String or line.length() > 2048:
			return false
	var points = context.get("history")
	if not points is Array or points.size() > 240:
		return false
	for point in points:
		if not point is Dictionary:
			return false
		for key in ["t", "gold", "prestige", "legitimacy", "army", "dev"]:
			if not _whole_number(point.get(key)):
				return false
	return true

func _valid_lan_state(state: Dictionary) -> bool:
	if state.has("event_instance") and (not _whole_number(state["event_instance"]) or int(state["event_instance"]) < 0):
		return false
	if not state.has("lan_human_houses"):
		return not state.has("lan_contexts") and not state.has("lan_projection")
	var ids = state["lan_human_houses"]
	var house_count: int = state["houses"].size()
	if not _whole_number(state.get("player")) or int(state["player"]) < 0 or int(state["player"]) >= house_count:
		return false
	if not ids is Array or not _valid_human_ids(ids, house_count):
		return false
	var active: Dictionary = {}
	for key in ["opinion", "cooldowns", "captive", "scandal", "pending", "event_timer", "event_instance", "game_over", "victory", "history", "log"]:
		active[key] = state.get(key)
	if not _valid_personal_context(active, house_count):
		return false
	if state.has("lan_projection"):
		var active_is_human := false
		for index in ids:
			if int(index) == int(state["player"]):
				active_is_human = true
		return state["lan_projection"] is bool and state["lan_projection"] == true and not state.has("lan_contexts") and active_is_human
	var contexts = state.get("lan_contexts")
	if not contexts is Dictionary or contexts.size() != house_count:
		return false
	for i in house_count:
		if not _valid_personal_context(contexts.get(str(i)), house_count):
			return false
	return SaveGameScript.state_equal(active, contexts[str(int(state["player"]))])

func restore(d: Dictionary) -> bool:
	var migration: Dictionary = SaveGameScript.migrate(d)
	if not bool(migration.get("ok", false)):
		note("Spielstand nicht ladbar: " + "; ".join(migration.get("errors", [])))
		return false
	var state: Dictionary = migration["data"]
	if not _valid_lan_state(state):
		return false
	var saved_houses: Array = state.get("houses", [])
	if saved_houses.is_empty():
		note("Spielstand enthält kein Haus.")
		return false
	if int(state.get("player", -1)) < 0 or int(state.get("player", -1)) >= saved_houses.size():
		note("Spielstand enthält keinen gültigen Spieler.")
		return false

	extra_state = {}
	for key in state.keys():
		if SaveGameScript.REQUIRED_TOP_LEVEL.has(str(key)) or ["lan_human_houses", "lan_contexts", "lan_projection", "event_instance"].has(str(key)):
			continue
		var extra = state[key]
		if extra is Dictionary or extra is Array:
			extra_state[str(key)] = extra.duplicate(true)
		else:
			extra_state[str(key)] = extra

	year = int(state.get("year", START_YEAR))
	month = int(state.get("month", 1))
	campaign_sandbox = bool(state.get("campaign_sandbox", false))
	roads = (state.get("roads", []) as Array).duplicate(true)
	player = int(state.get("player", 0))
	speed = int(state.get("speed", 0))
	event_timer = int(state.get("event_timer", 9))
	game_over = bool(state.get("game_over", false))
	custom_start = bool(state.get("custom", false))
	scandal = int(state.get("scandal", 0))
	victory = bool(state.get("victory", false))
	_event_instance = int(state.get("event_instance", 0))
	human_houses = []
	_player_contexts = {}
	_lan_projection = bool(state.get("lan_projection", false))
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
				# Alte Einzelspielstände besitzen noch keine Ereignisinstanz.
				_event_instance = maxi(1, _event_instance)
				break
	history = _clean_series(state.get("history", []))
	var raw_house_history = state.get("house_history", [])
	house_history = []
	if raw_house_history is Array:
		for series in raw_house_history:
			house_history.append(_clean_series(series))
	_ensure_history()
	if state.has("lan_human_houses"):
		for index in state["lan_human_houses"]:
			human_houses.append(int(index))
		if not _lan_projection:
			_player_contexts = (state["lan_contexts"] as Dictionary).duplicate(true)
			_load_player_context(_player_contexts[str(player)])
		else:
			_store_player_context()
			for index in houses.size():
				_ensure_player_context(index)
	return true
