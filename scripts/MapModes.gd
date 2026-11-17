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
			color.a = 0.06
		"titles":
			color = PALETTE[posmod(str(province.get(tier, "")).hash(), PALETTE.size())]
			color.a = 0.76
		"economy":
			var development := clampf((float(province.get("dev", 1)) - 1) / 9.0, 0, 1)
			var yield_ratio := clampf(log(1.0 + float(game.region_income(province))) / log(41.0),0,1)
			development = yield_ratio * .8 + development * .2
			color = Color("b15a42").lerp(Color("e9ce76"), minf(1, development * 2)) if development < .5 else Color("e9ce76").lerp(Color("3e9872"), (development - .5) * 2)
			color.a = .80
		"war":
			if int(province.owner) == game.player:
				color = Color("4f9b7d")
				color.a = .78
			elif game.can_attack(str(province.id)):
				color = Color("cf624a")
				color.a = .86
			else:
				color = Color("393f49")
				color.a = .62
		_:
			color = game.houses[int(province.owner)].color
			color.a = .68
	if str(province.id) == selected:
		var alpha := color.a
		color = color.lightened(.16)
		color.a = alpha
	return color

static func border_key(p: Dictionary, q: Dictionary, mode: String, tier: String) -> String:
	if q.is_empty():
		return "coast"
	match canonical(mode):
		"terrain":
			if str(p.empire) != str(q.empire): return "empire"
			if str(p.kingdom) != str(q.kingdom): return "kingdom"
		"titles":
			if str(p.get(tier, "")) != str(q.get(tier, "")): return tier
		_:
			if int(p.owner) != int(q.owner): return "owner"
	return "province"

static func border_styles(mode: String) -> Dictionary:
	var styles := {
		"province":[Color(0.10,0.15,0.14,.24),.45],
		"duchy":[Color("f1d8a0"),0.0], "kingdom":[Color("f1d8a0"),0.0],
		"empire":[Color("f6dfad"),0.0], "owner":[Color("f7e2b6"),1.75],
		"coast":[Color(0.10,0.17,0.18,.70),.80],
	}
	match canonical(mode):
		"terrain":
			styles.province = [Color(0.12,0.20,0.15,.08),.30]
			styles.kingdom = [Color("806342"),1.25]
			styles.empire = [Color("ead5a3"),2.7]
			styles.owner[1] = 0.0
		"titles":
			styles.duchy[1] = 1.8
			styles.kingdom[1] = 2.2
			styles.empire[1] = 2.8
			styles.owner[1] = 0.0
		"economy":
			styles.province = [Color(0.13,0.20,0.15,.55),.75]
			styles.owner = [Color(0.17,0.21,0.18,.65),1.2]
		"war":
			styles.owner = [Color("f0b985"),2.3]
	return styles
