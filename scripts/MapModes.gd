extends RefCounted
## Aussage einer Karte: Farben und Grenzprioritäten ändern keine Spielregeln.
const IDS := ["political", "terrain", "titles", "economy", "war"]
const TITLES := {"political":"Politik", "terrain":"Gelände", "titles":"Rechtstitel", "economy":"Wirtschaft", "war":"Krieg"}
const HINTS := {
	"political":"Tatsächlicher Hausbesitz und veränderliche Herrschaftsgrenzen",
	"terrain":"Topografie, Flüsse und feste angestammte Königreichs-/Reichsgrenzen",
	"titles":"Angestammte Herzogtümer, Königreiche oder Reiche unabhängig vom Besitzer",
	"economy":"Landsertrag, Provinzschwerpunkte und kontrollierte Straßenversorgung",
	"war":"Eigenes Aufgebot, erreichbare Angriffsziele, Armeen und Belagerungen",
}
const MINIATURES := {
	"political": preload("res://assets/map/living/political.png"),
	"terrain": preload("res://assets/map/living/terrain.png"),
	"titles": preload("res://assets/map/living/titles.png"),
	"economy": preload("res://assets/map/living/economy.png"),
	"war": preload("res://assets/map/living/war.png"),
}
const ACCENTS := {"political":Color("f6d39b"), "terrain":Color("afc9a2"),
	"titles":Color("e2bddb"), "economy":Color("94d6b3"), "war":Color("f5a487")}
const TIER_NAMES := {"duchy":"Herzogtümer","kingdom":"Königreiche","empire":"Reiche"}

const PALETTE := [Color("b85e52"),Color("557ea6"),Color("698d62"),Color("bb9a50"),Color("8e6da3"),Color("4f9994"),Color("a87859"),Color("7d8b52")]

static func canonical(id: String) -> String:
	var aliases := {"duchy":"titles", "kingdom":"titles", "development":"economy"}
	var result: String = aliases.get(id, id)
	return result if IDS.has(result) else "political"

static func fill(game, province: Dictionary, mode: String, tier: String, selected: String) -> Color:
	var color: Color
	match canonical(mode):
		"terrain":
			color = province.get("terrain_color", Color("6c8458"))
			color.a = 0.025
		"titles":
			color = PALETTE[posmod(str(province.get(tier, "")).hash(), PALETTE.size())]
			color.a = 0.78
		"economy":
			var development := clampf((float(province.get("dev", 1)) - 1) / 9.0, 0, 1)
			var yield_ratio := clampf(log(1.0 + float(game.region_income(province))) / log(41.0),0,1)
			development = yield_ratio * .8 + development * .2
			color = Color("715142").lerp(Color("c4a057"), minf(1, development * 2)) if development < .5 else Color("c4a057").lerp(Color("2c9077"), (development - .5) * 2)
			color.a = .80
		"war":
			if int(province.owner) == game.player:
				color = Color("347368")
				color.a = .78
			elif game.can_attack(str(province.id)):
				color = Color("d66743")
				color.a = .86
			else:
				color = Color("333745")
				color.a = .62
		_:
			color = game.houses[int(province.owner)].color
			color.a = .58
	if str(province.id) == selected:
		var alpha := color.a
		color = color.lightened(.16)
		color.a = alpha
	return color

static func border_key(p: Dictionary, q: Dictionary, mode: String, tier: String, player: int = -1) -> String:
	if q.is_empty():
		return "coast"
	match canonical(mode):
		"terrain":
			if str(p.empire) != str(q.empire): return "empire"
			if str(p.kingdom) != str(q.kingdom): return "kingdom"
		"titles":
			if str(p.get(tier, "")) != str(q.get(tier, "")): return tier
		"war":
			if int(p.owner) != int(q.owner):
				if player in [int(p.owner), int(q.owner)]: return "front"
				return "owner"
		_:
			if int(p.owner) != int(q.owner): return "owner"
	return "province"

static func border_styles(mode: String) -> Dictionary:
	var styles := {
		"province":[Color(0.10,0.15,0.14,.24),.45],
		"duchy":[Color("f1d8a0"),0.0], "kingdom":[Color("f1d8a0"),0.0],
		"empire":[Color("f6dfad"),0.0], "owner":[Color("f7e2b6"),1.75],
		"coast":[Color.TRANSPARENT,0.0],
		"front":[Color("ffc089"),2.7],
	}
	match canonical(mode):
		"terrain":
			styles.province = [Color(0.12,0.20,0.15,.08),.30]
			styles.kingdom = [Color("ac8b59"),1.45]
			styles.empire = [Color("ffe7ab"),2.7]
			styles.owner[1] = 0.0
		"titles":
			styles.duchy = [Color("eed5ec"),1.65]
			styles.kingdom = [Color("f1d9ef"),2.15]
			styles.empire = [Color("ffe5f5"),2.7]
			styles.owner[1] = 0.0
		"economy":
			styles.province = [Color(0.13,0.20,0.15,.55),.75]
			styles.owner = [Color("cee3ad"),1.35]
		"war":
			styles.owner = [Color("d0ad98"),1.30]
	return styles

static func context_line(game, province: Dictionary, mode: String, tier: String) -> String:
	if province.is_empty():
		return str(HINTS[mode])
	var region := str(province.name)
	match mode:
		"terrain":
			return "%s · %s · %s" % [region, province.get("terrain_name", ""), province.get("kingdom_name", "")]
		"titles":
			return "%s · %s" % [region, province.get(tier + "_name", TIER_NAMES[tier])]
		"economy":
			var focus: Dictionary = preload("res://scripts/ProvinceEconomy.gd").FOCI.get(str(province.get("economic_focus","balanced")), {})
			return "%s · %d Gold/Jahr · %s" % [region, game.region_income(province), focus.get("name", "Ausgewogen")]
		"war":
			if int(province.get("siege", 0)) > 0:
				return "%s · Belagerung %d %%" % [region, province.siege]
			if int(province.owner) == game.player:
				return "%s · Eigenes Aufgebot %d" % [region, province.get("levy", 0)]
			return "%s · %s" % [region, "Angriff möglich" if game.can_attack(str(province.id)) else "Angriff derzeit gesperrt"]
		_:
			return "%s · %s" % [region, game.houses[int(province.owner)].name]
