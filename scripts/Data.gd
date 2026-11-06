extends RefCounted
## Bronzezeit-Europa: 49 Grafschaften in 25 Herzogtümern, neun Königreichen
## und drei Reichen. Die Flächen werden aus den Königreichsumrissen erzeugt;
## alle Namen, Grenzen und Daten sind eigene Inhalte, keine CK3-Assets.

const START_YEAR := -2000
const EMPIRE_NAMES := {
	"west": "Westliches Reich",
	"mitte": "Mittleres Reich",
	"ost": "Östliches Reich",
}

static var _province_cache: Array = []
static var _adjacency_cache: Dictionary = {}
static var _geometry_cache: Dictionary = {}

static func empires() -> Array:
	return [
		{"id": "west", "name": EMPIRE_NAMES["west"], "color": Color(0.62, 0.40, 0.26)},
		{"id": "mitte", "name": EMPIRE_NAMES["mitte"], "color": Color(0.48, 0.46, 0.28)},
		{"id": "ost", "name": EMPIRE_NAMES["ost"], "color": Color(0.34, 0.42, 0.48)},
	]

static func _kingdoms() -> Array:
	return [
		{"id": "iberien", "name": "Iberien", "empire": "west", "owner": 3,
			"points": [Vector2(95, 520), Vector2(150, 495), Vector2(225, 505), Vector2(285, 545),
				Vector2(275, 605), Vector2(235, 655), Vector2(170, 675), Vector2(120, 645), Vector2(90, 590)],
			"counties": [
				{"id": "gades", "name": "Gades", "duchy": "baetica", "duchy_name": "Herzogtum Baetica", "dev": 5, "levy": 650, "capital": true},
				{"id": "corduba", "name": "Corduba", "duchy": "baetica", "duchy_name": "Herzogtum Baetica", "dev": 4, "levy": 560},
				{"id": "olisipo", "name": "Olisipo", "duchy": "lusitania", "duchy_name": "Herzogtum Lusitania", "dev": 4, "levy": 520},
				{"id": "tarraco", "name": "Tarraco", "duchy": "tarraconensis", "duchy_name": "Herzogtum Tarraconensis", "dev": 4, "levy": 540},
				{"id": "numantia", "name": "Numantia", "duchy": "tarraconensis", "duchy_name": "Herzogtum Tarraconensis", "dev": 3, "levy": 440},
			]},
		{"id": "gallien", "name": "Gallien", "empire": "west", "owner": 1,
			"points": [Vector2(250, 420), Vector2(315, 395), Vector2(380, 400), Vector2(430, 440),
				Vector2(440, 500), Vector2(405, 545), Vector2(345, 555), Vector2(300, 525),
				Vector2(270, 480), Vector2(245, 455)],
			"counties": [
				{"id": "lugdunum", "name": "Lugdunum", "duchy": "lugdunensis", "duchy_name": "Herzogtum Lugdunensis", "dev": 5, "levy": 620, "capital": true},
				{"id": "aedui", "name": "Aedui", "duchy": "lugdunensis", "duchy_name": "Herzogtum Lugdunensis", "dev": 4, "levy": 540},
				{"id": "aquitania", "name": "Aquitania", "duchy": "aquitanien", "duchy_name": "Herzogtum Aquitanien", "dev": 4, "levy": 500},
				{"id": "narbonensis", "name": "Narbonensis", "duchy": "aquitanien", "duchy_name": "Herzogtum Aquitanien", "dev": 4, "levy": 480},
				{"id": "belgica", "name": "Belgica", "duchy": "belgica", "duchy_name": "Herzogtum Belgica", "dev": 4, "levy": 520},
				{"id": "armorica", "name": "Armorica", "duchy": "belgica", "duchy_name": "Herzogtum Belgica", "dev": 3, "levy": 430},
			]},
		{"id": "britannien", "name": "Britannien", "empire": "west", "owner": 2,
			"points": [Vector2(300, 230), Vector2(335, 215), Vector2(360, 245), Vector2(355, 285),
				Vector2(380, 320), Vector2(390, 370), Vector2(365, 410), Vector2(325, 420),
				Vector2(300, 385), Vector2(285, 340), Vector2(295, 300), Vector2(285, 265)],
			"counties": [
				{"id": "cantium", "name": "Cantium", "duchy": "kent", "duchy_name": "Herzogtum Kent", "dev": 4, "levy": 520, "capital": true},
				{"id": "iceni", "name": "Iceni", "duchy": "ostanglien", "duchy_name": "Herzogtum Ostanglien", "dev": 4, "levy": 500},
				{"id": "brigantes", "name": "Brigantes", "duchy": "brigantien", "duchy_name": "Herzogtum Brigantien", "dev": 4, "levy": 520},
				{"id": "cambria", "name": "Cambria", "duchy": "brigantien", "duchy_name": "Herzogtum Brigantien", "dev": 3, "levy": 430},
				{"id": "caledonia", "name": "Caledonia", "duchy": "alba", "duchy_name": "Herzogtum Alba", "dev": 3, "levy": 420},
			]},
		{"id": "italia", "name": "Italia", "empire": "west", "owner": 8,
			"points": [Vector2(495, 510), Vector2(545, 500), Vector2(565, 535), Vector2(555, 570),
				Vector2(575, 600), Vector2(605, 640), Vector2(595, 675), Vector2(565, 665),
				Vector2(550, 620), Vector2(525, 585), Vector2(500, 560)],
			"counties": [
				{"id": "latium", "name": "Latium", "duchy": "latium", "duchy_name": "Herzogtum Latium", "dev": 5, "levy": 580, "capital": true},
				{"id": "campania", "name": "Campania", "duchy": "latium", "duchy_name": "Herzogtum Latium", "dev": 4, "levy": 500},
				{"id": "etruria", "name": "Etruria", "duchy": "etrurien", "duchy_name": "Herzogtum Etrurien", "dev": 4, "levy": 480},
				{"id": "venetia", "name": "Venetia", "duchy": "venetien", "duchy_name": "Herzogtum Venetien", "dev": 4, "levy": 500},
				{"id": "apulia", "name": "Apulia", "duchy": "venetien", "duchy_name": "Herzogtum Venetien", "dev": 3, "levy": 430},
			]},
		{"id": "germanien", "name": "Germanien", "empire": "mitte", "owner": 0,
			"points": [Vector2(430, 405), Vector2(485, 380), Vector2(555, 375), Vector2(620, 395),
				Vector2(650, 440), Vector2(640, 490), Vector2(600, 520), Vector2(540, 535),
				Vector2(480, 520), Vector2(445, 480), Vector2(425, 440)],
			"counties": [
				{"id": "boiohaemum", "name": "Boiohaemum", "duchy": "boiohaemum", "duchy_name": "Herzogtum Boiohaemum", "dev": 5, "levy": 640, "capital": true},
				{"id": "suebia", "name": "Suebia", "duchy": "boiohaemum", "duchy_name": "Herzogtum Boiohaemum", "dev": 4, "levy": 540},
				{"id": "chattia", "name": "Chattia", "duchy": "chattia", "duchy_name": "Herzogtum Chattia", "dev": 4, "levy": 520},
				{"id": "frisia", "name": "Frisia", "duchy": "chattia", "duchy_name": "Herzogtum Chattia", "dev": 3, "levy": 440},
				{"id": "saxonia", "name": "Saxonia", "duchy": "saxonia", "duchy_name": "Herzogtum Saxonia", "dev": 4, "levy": 500},
				{"id": "vandalia", "name": "Vandalia", "duchy": "saxonia", "duchy_name": "Herzogtum Saxonia", "dev": 3, "levy": 450},
			]},
		{"id": "skandia", "name": "Skandia", "empire": "mitte", "owner": 4,
			"points": [Vector2(440, 120), Vector2(465, 85), Vector2(500, 90), Vector2(530, 120),
				Vector2(545, 180), Vector2(550, 240), Vector2(535, 295), Vector2(545, 330),
				Vector2(520, 355), Vector2(495, 345), Vector2(485, 310), Vector2(465, 300),
				Vector2(450, 250), Vector2(435, 190)],
			"counties": [
				{"id": "vestland", "name": "Vestland", "duchy": "vestland", "duchy_name": "Herzogtum Vestland", "dev": 4, "levy": 520, "capital": true},
				{"id": "norrland", "name": "Norrland", "duchy": "vestland", "duchy_name": "Herzogtum Vestland", "dev": 3, "levy": 420},
				{"id": "svealand", "name": "Svealand", "duchy": "svealand", "duchy_name": "Herzogtum Svealand", "dev": 4, "levy": 500},
				{"id": "gotaland", "name": "Gotaland", "duchy": "svealand", "duchy_name": "Herzogtum Svealand", "dev": 4, "levy": 480},
				{"id": "skane", "name": "Skane", "duchy": "jutland", "duchy_name": "Herzogtum Jutland", "dev": 3, "levy": 440},
				{"id": "jutland", "name": "Jutland", "duchy": "jutland", "duchy_name": "Herzogtum Jutland", "dev": 3, "levy": 420},
			]},
		{"id": "hellas", "name": "Hellas", "empire": "ost", "owner": 5,
			"points": [Vector2(625, 470), Vector2(680, 455), Vector2(735, 470), Vector2(775, 505),
				Vector2(790, 550), Vector2(770, 585), Vector2(785, 620), Vector2(760, 660),
				Vector2(720, 685), Vector2(680, 675), Vector2(665, 640), Vector2(635, 620),
				Vector2(625, 570), Vector2(610, 520)],
			"counties": [
				{"id": "dalmatia", "name": "Dalmatia", "duchy": "dalmatien", "duchy_name": "Herzogtum Dalmatien", "dev": 3, "levy": 440},
				{"id": "makedonia", "name": "Makedonia", "duchy": "makedonien", "duchy_name": "Herzogtum Makedonien", "dev": 4, "levy": 500, "capital": true},
				{"id": "thessalia", "name": "Thessalia", "duchy": "makedonien", "duchy_name": "Herzogtum Makedonien", "dev": 3, "levy": 440},
				{"id": "attika", "name": "Attika", "duchy": "attika", "duchy_name": "Herzogtum Attika", "dev": 5, "levy": 560},
				{"id": "boeotia", "name": "Boeotia", "duchy": "attika", "duchy_name": "Herzogtum Attika", "dev": 4, "levy": 480},
				{"id": "peloponnesos", "name": "Peloponnesos", "duchy": "peloponnes", "duchy_name": "Herzogtum Peloponnes", "dev": 4, "levy": 500},
			]},
		{"id": "anatolien", "name": "Anatolien", "empire": "ost", "owner": 6,
			"points": [Vector2(800, 560), Vector2(860, 535), Vector2(940, 530), Vector2(1010, 550),
				Vector2(1035, 585), Vector2(1010, 625), Vector2(950, 650), Vector2(870, 645),
				Vector2(815, 620), Vector2(790, 590)],
			"counties": [
				{"id": "troas", "name": "Troas", "duchy": "troas", "duchy_name": "Herzogtum Troas", "dev": 4, "levy": 500},
				{"id": "hatti", "name": "Hatti", "duchy": "troas", "duchy_name": "Herzogtum Troas", "dev": 5, "levy": 620, "capital": true},
				{"id": "phrygia", "name": "Phrygia", "duchy": "phrygien", "duchy_name": "Herzogtum Phrygien", "dev": 4, "levy": 500},
				{"id": "lycia", "name": "Lycia", "duchy": "lykien", "duchy_name": "Herzogtum Lykien", "dev": 3, "levy": 440},
				{"id": "cilicia", "name": "Cilicia", "duchy": "lykien", "duchy_name": "Herzogtum Lykien", "dev": 3, "levy": 420},
			]},
		{"id": "skythien", "name": "Skythien", "empire": "ost", "owner": 7,
			"points": [Vector2(650, 350), Vector2(720, 320), Vector2(820, 315), Vector2(920, 330),
				Vector2(980, 370), Vector2(1000, 430), Vector2(970, 480), Vector2(900, 505),
				Vector2(820, 505), Vector2(760, 480), Vector2(700, 440), Vector2(665, 395)],
			"counties": [
				{"id": "borysthenes", "name": "Borysthenes", "duchy": "borysthenes", "duchy_name": "Herzogtum Borysthenes", "dev": 4, "levy": 520, "capital": true},
				{"id": "venedia", "name": "Venedia", "duchy": "borysthenes", "duchy_name": "Herzogtum Borysthenes", "dev": 3, "levy": 440},
				{"id": "tauris", "name": "Tauris", "duchy": "tauris", "duchy_name": "Herzogtum Tauris", "dev": 3, "levy": 430},
				{"id": "sarmatia", "name": "Sarmatia", "duchy": "tauris", "duchy_name": "Herzogtum Tauris", "dev": 4, "levy": 480},
				{"id": "rha", "name": "Rha", "duchy": "rha", "duchy_name": "Herzogtum Rha", "dev": 3, "levy": 420},
			]},
	]

static func houses() -> Array:
	return [
		{"name": "Haus Unetice", "color": Color(0.68, 0.30, 0.20), "gold": 140, "prestige": 8,
			"capital": "boiohaemum", "realm": "Königreich Germanien",
			"ruler": {"name": "Kral", "age": 42, "gender": "m", "martial": 13, "diplomacy": 9, "stewardship": 14, "intrigue": 8, "health": 82, "portrait": 0},
			"spouse": {"name": "Nina", "age": 38, "gender": "f", "martial": 6, "diplomacy": 11, "stewardship": 12, "intrigue": 9, "health": 84, "portrait": 9, "house": -1},
			"children": [{"name": "Boleslav", "age": 7, "gender": "m", "portrait": 1}],
			"heir": "Boleslav", "heir_age": 7, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Sequana", "color": Color(0.22, 0.38, 0.62), "gold": 130, "prestige": 6,
			"capital": "lugdunum", "realm": "Königreich Gallien",
			"ruler": {"name": "Brennus", "age": 38, "gender": "m", "martial": 11, "diplomacy": 14, "stewardship": 10, "intrigue": 11, "health": 86, "portrait": 1},
			"spouse": {}, "children": [{"name": "Epona", "age": 3, "gender": "f", "portrait": 9}],
			"heir": "Epona", "heir_age": 3, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Wessex", "color": Color(0.24, 0.50, 0.30), "gold": 120, "prestige": 5,
			"capital": "cantium", "realm": "Königreich Britannien",
			"ruler": {"name": "Belenos", "age": 35, "gender": "m", "martial": 14, "diplomacy": 8, "stewardship": 9, "intrigue": 7, "health": 84, "portrait": 2},
			"spouse": {"name": "Boudica", "age": 33, "gender": "f", "martial": 12, "diplomacy": 10, "stewardship": 9, "intrigue": 8, "health": 88, "portrait": 10, "house": 2},
			"children": [{"name": "Cunorix", "age": 9, "gender": "m", "portrait": 2}],
			"heir": "Cunorix", "heir_age": 9, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Tartessos", "color": Color(0.76, 0.56, 0.20), "gold": 110, "prestige": 7,
			"capital": "gades", "realm": "Königreich Iberien",
			"ruler": {"name": "Argantonios", "age": 47, "gender": "m", "martial": 12, "diplomacy": 10, "stewardship": 8, "intrigue": 10, "health": 74, "portrait": 3},
			"spouse": {"name": "Elissa", "age": 42, "gender": "f", "martial": 5, "diplomacy": 13, "stewardship": 14, "intrigue": 9, "health": 80, "portrait": 11, "house": 3},
			"children": [{"name": "Gadir", "age": 15, "gender": "m", "portrait": 3}],
			"heir": "Gadir", "heir_age": 15, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Skandia", "color": Color(0.18, 0.50, 0.52), "gold": 115, "prestige": 4,
			"capital": "vestland", "realm": "Königreich Skandia",
			"ruler": {"name": "Sigrun", "age": 33, "gender": "f", "martial": 16, "diplomacy": 7, "stewardship": 8, "intrigue": 9, "health": 88, "portrait": 4},
			"spouse": {"name": "Bragi", "age": 35, "gender": "m", "martial": 13, "diplomacy": 8, "stewardship": 7, "intrigue": 6, "health": 87, "portrait": 1, "house": 4},
			"children": [{"name": "Ulf", "age": 4, "gender": "m", "portrait": 5}],
			"heir": "Ulf", "heir_age": 4, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Mykene", "color": Color(0.44, 0.28, 0.58), "gold": 120, "prestige": 9,
			"capital": "makedonia", "realm": "Königreich Hellas",
			"ruler": {"name": "Atreus", "age": 44, "gender": "m", "martial": 10, "diplomacy": 12, "stewardship": 9, "intrigue": 13, "health": 78, "portrait": 5},
			"spouse": {}, "children": [{"name": "Agamemnon", "age": 12, "gender": "m", "portrait": 6}],
			"heir": "Agamemnon", "heir_age": 12, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Hatti", "color": Color(0.72, 0.60, 0.20), "gold": 160, "prestige": 10,
			"capital": "hatti", "realm": "Königreich Anatolien",
			"ruler": {"name": "Pithana", "age": 51, "gender": "m", "martial": 9, "diplomacy": 15, "stewardship": 13, "intrigue": 12, "health": 70, "portrait": 6},
			"spouse": {"name": "Kubaba", "age": 40, "gender": "f", "martial": 7, "diplomacy": 12, "stewardship": 11, "intrigue": 10, "health": 82, "portrait": 10, "house": 6},
			"children": [{"name": "Anitta", "age": 18, "gender": "m", "portrait": 7}],
			"heir": "Anitta", "heir_age": 18, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Srubna", "color": Color(0.34, 0.40, 0.48), "gold": 105, "prestige": 3,
			"capital": "borysthenes", "realm": "Königreich Skythien",
			"ruler": {"name": "Targitai", "age": 40, "gender": "m", "martial": 12, "diplomacy": 9, "stewardship": 11, "intrigue": 8, "health": 80, "portrait": 7},
			"spouse": {}, "children": [{"name": "Ari", "age": 6, "gender": "m", "portrait": 0}],
			"heir": "Ari", "heir_age": 6, "pregnant": 0, "lover_house": -1},
		{"name": "Haus Latium", "color": Color(0.46, 0.52, 0.26), "gold": 150, "prestige": 7,
			"capital": "latium", "realm": "Königreich Italia",
			"ruler": {"name": "Lavinia", "age": 37, "gender": "f", "martial": 8, "diplomacy": 13, "stewardship": 16, "intrigue": 11, "health": 85, "portrait": 8},
			"spouse": {"name": "Titus", "age": 39, "gender": "m", "martial": 11, "diplomacy": 10, "stewardship": 8, "intrigue": 7, "health": 83, "portrait": 3, "house": 8},
			"children": [{"name": "Latinus", "age": 10, "gender": "m", "portrait": 4}],
			"heir": "Latinus", "heir_age": 10, "pregnant": 0, "lover_house": -1},
	]

static func provinces() -> Array:
	if _province_cache.is_empty():
		_province_cache = _build_provinces()
	return _province_cache.duplicate(true)

static func geometry_loaded() -> bool:
	return not _geometry().is_empty()

static func _geometry() -> Dictionary:
	if not _geometry_cache.is_empty():
		return _geometry_cache
	var f := FileAccess.open("res://data/europe_geometry.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_geometry_cache = parsed
	return _geometry_cache

static func _pack_points(raw) -> PackedVector2Array:
	var out := PackedVector2Array()
	if raw is Array:
		for p in raw:
			if p is Array and p.size() >= 2:
				out.append(Vector2(float(p[0]), float(p[1])))
	return out

static func _build_provinces() -> Array:
	var out: Array = []
	var geo: Dictionary = _geometry()
	var realms: Dictionary = geo.get("realms", {})
	for k in _kingdoms():
		var pieces: Array = _split_region(PackedVector2Array(k["points"]), k["counties"].size())
		var realm_geo: Dictionary = realms.get(str(k["id"]), {})
		var realm_provinces: Dictionary = realm_geo.get("provinces", {})
		for i in k["counties"].size():
			var c: Dictionary = k["counties"][i]
			var parts: Array = []
			var label_pos := Vector2.ZERO
			var gp: Dictionary = realm_provinces.get(str(c["id"]), {})
			if not gp.is_empty():
				for raw_part in gp.get("parts", []):
					var part := _pack_points(raw_part)
					if part.size() >= 3:
						parts.append(part)
				var raw_label = gp.get("label", [])
				if raw_label is Array and raw_label.size() >= 2:
					label_pos = Vector2(float(raw_label[0]), float(raw_label[1]))
			if parts.is_empty():
				var fallback: PackedVector2Array = pieces[i] if i < pieces.size() else PackedVector2Array()
				if fallback.size() >= 3:
					parts.append(fallback)
			if parts.is_empty():
				continue
			var pts: PackedVector2Array = parts[0]
			var best_area: float = absf(_poly_area(pts))
			for j in range(1, parts.size()):
				var pa: float = absf(_poly_area(parts[j]))
				if pa > best_area:
					best_area = pa
					pts = parts[j]
			if label_pos == Vector2.ZERO:
				label_pos = _centroid(pts)
			out.append({
				"id": c["id"], "name": c["name"], "owner": int(k["owner"]),
				"dev": int(c["dev"]), "levy": int(c["levy"]), "points": pts,
				"parts": parts, "label_pos": label_pos,
				"kingdom": k["id"], "kingdom_name": "Königreich " + str(k["name"]),
				"duchy": c["duchy"], "duchy_name": c["duchy_name"],
				"empire": k["empire"], "empire_name": EMPIRE_NAMES[str(k["empire"])],
				"capital": bool(c.get("capital", false)),
			})
	return out

static func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / maxf(1.0, float(poly.size()))

static func _split_region(poly: PackedVector2Array, n: int) -> Array:
	var center := Vector2.ZERO
	for p in poly:
		center += p
	center /= float(poly.size())
	var out: Array = []
	for i in n:
		var a0: float = -PI / 2.0 + TAU * float(i) / float(n)
		var a1: float = -PI / 2.0 + TAU * float(i + 1) / float(n)
		var wedge := PackedVector2Array([
			center,
			center + Vector2(cos(a0), sin(a0)) * 3000.0,
			center + Vector2(cos(a1), sin(a1)) * 3000.0,
		])
		var pieces: Array = Geometry2D.intersect_polygons(poly, wedge)
		var best := PackedVector2Array()
		var best_area := 0.0
		for piece in pieces:
			var pp := PackedVector2Array(piece)
			if pp.size() < 3:
				continue
			var ar: float = absf(_poly_area(pp))
			if ar > best_area:
				best_area = ar
				best = pp
		if best.size() < 3:
			best = wedge
		out.append(best)
	return out

static func _poly_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5

static func adjacency() -> Dictionary:
	if not _adjacency_cache.is_empty():
		return _adjacency_cache.duplicate(true)
	var ps: Array = provinces()
	var out: Dictionary = {}
	var geo_adj = _geometry().get("adjacency", {})
	if geo_adj is Dictionary and not (geo_adj as Dictionary).is_empty():
		var valid := {}
		for p in ps:
			valid[str(p["id"])] = true
		for p in ps:
			var ns: Array = []
			for nid in (geo_adj as Dictionary).get(str(p["id"]), []):
				if valid.has(str(nid)) and not ns.has(str(nid)):
					ns.append(str(nid))
			out[p["id"]] = ns
		for p in ps:
			for nid in out[p["id"]]:
				if not (out[nid] as Array).has(p["id"]):
					out[nid].append(p["id"])
	else:
		for p in ps:
			var ns: Array = []
			for q in ps:
				if p["id"] == q["id"]:
					continue
				if _shared_vertices(p["points"], q["points"]) >= 2:
					ns.append(q["id"])
			out[p["id"]] = ns
	for p in ps:
		if not (out[p["id"]] as Array).is_empty():
			continue
		var best_id := ""
		var best_d := 1e9
		for q in ps:
			if q["id"] == p["id"]:
				continue
			var d: float = _min_distance(p["points"], q["points"])
			if d < best_d:
				best_d = d
				best_id = q["id"]
		if best_d < 45.0:
			out[p["id"]].append(best_id)
	for p in ps:
		for nid in out[p["id"]]:
			if not (out[nid] as Array).has(p["id"]):
				out[nid].append(p["id"])
	_adjacency_cache = out
	return out.duplicate(true)

static func _shared_vertices(a: PackedVector2Array, b: PackedVector2Array) -> int:
	var hits := 0
	for p in a:
		for q in b:
			if p.distance_squared_to(q) < 1.0:
				hits += 1
				break
	return hits

static func _min_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var best := 1e9
	for p in a:
		for q in b:
			best = minf(best, p.distance_to(q))
	return best

static func kingdom_neighbours() -> Dictionary:
	return {
		"iberien": ["gallien"],
		"gallien": ["iberien", "britannien", "germanien", "italien"],
		"britannien": ["gallien", "skandia"],
		"italia": ["gallien", "germanien", "hellas"],
		"germanien": ["gallien", "italien", "skandia", "skythien"],
		"skandia": ["britannien", "germanien", "skythien"],
		"hellas": ["italien", "skythien", "anatolien"],
		"anatolien": ["hellas", "skythien"],
		"skythien": ["germanien", "skandia", "hellas", "anatolien"],
	}

static func events() -> Array:
	return [
		{"id": "zehnt", "title": "Die Gabe an die Götter",
			"text": "Ein Priester verlangt eine Gabe für den Tempel. Zahlst du, segnet man dein Haus; verweigerst du, zürnen die Götter.",
			"options": [
				{"label": "Opfern  (−40 Gold, +10 Prestige)", "effects": {"gold": -40, "prestige": 10}},
				{"label": "Verweigern  (+35 Gold, −12 Prestige)", "effects": {"gold": 35, "prestige": -12}},
			]},
		{"id": "ernte", "title": "Gute Ernte",
			"text": "Die Speicher sind voll. Du kannst verkaufen oder Vorräte für den Krieg anlegen.",
			"options": [
				{"label": "Verkaufen  (+45 Gold)", "effects": {"gold": 45}},
				{"label": "Einlagern  (+180 Truppen)", "effects": {"levy": 180}},
			]},
		{"id": "hoftag", "title": "Hoftag",
			"text": "Deine Gefolgsleute erwarten ein Fest. Pracht kostet Gold, schafft aber Ansehen.",
			"options": [
				{"label": "Groß feiern  (−35 Gold, +25 Prestige)", "effects": {"gold": -35, "prestige": 25}},
				{"label": "Schlicht bleiben  (+5 Prestige)", "effects": {"prestige": 5}},
			]},
		{"id": "grenzstreit", "title": "Grenzstreit",
			"text": "Hirten an der Grenze streiten über Weideland. Der Nachbar schickt Bewaffnete.",
			"options": [
				{"label": "Söldner werben  (−30 Gold, +260 Truppen)", "effects": {"gold": -30, "levy": 260}},
				{"label": "Nachgeben  (−8 Prestige)", "effects": {"prestige": -8}},
			]},
		{"id": "hochzeit", "title": "Hochzeit",
			"text": "Eine passende Partie wird angeboten. Eine Verbindung sichert die Zukunft deines Hauses.",
			"options": [
				{"label": "Vermählen  (−25 Gold, +18 Prestige)", "effects": {"gold": -25, "prestige": 18, "heir": 1}},
				{"label": "Ablehnen", "effects": {}},
			]},
		{"id": "krankheit", "title": "Fieber",
			"text": "Dein Herrscher liegt mit Fieber danieder. Ein Heiler aus dem Osten wäre teuer.",
			"options": [
				{"label": "Heiler bezahlen  (−40 Gold, +10 Gesundheit)", "effects": {"gold": -40, "health": 10}},
				{"label": "Ausharren  (−14 Gesundheit)", "effects": {"health": -14}},
			]},
		{"id": "kloster", "title": "Tempelgründung",
			"text": "Priester bitten um Land für einen Tempel. Sie versprechen Segen und Bildung.",
			"options": [
				{"label": "Stiften  (−30 Gold, +14 Prestige, +1 Entwicklung)", "effects": {"gold": -30, "prestige": 14, "dev": 1}},
				{"label": "Abschlagen", "effects": {"prestige": -4}},
			]},
		{"id": "haendler", "title": "Fahrende Händler",
			"text": "Ein Karawanenzug bietet Zinn und Bernstein. Der Zoll könnte deine Kasse füllen.",
			"options": [
				{"label": "Zoll erheben  (+30 Gold, −6 Prestige)", "effects": {"gold": 30, "prestige": -6}},
				{"label": "Frei passieren  (+8 Prestige)", "effects": {"prestige": 8}},
			]},
	]

static func name_pool() -> Array:
	return [
		"Belenos", "Brennus", "Bragi", "Cunorix", "Dagda", "Epona", "Hektor",
		"Kassandra", "Kubaba", "Latinus", "Midas", "Nina", "Pithana", "Rhea",
		"Sargon", "Sigrun", "Targitai", "Titus", "Ariadne", "Atreus", "Elissa",
		"Gadir", "Hattusa", "Anitta", "Debora", "Jael", "Naram", "Enheduanna",
	]
