extends RefCounted
## Eingebettete Referenzgeografie. Verändert weder Provinzen noch Spielregeln.
const DATA_PATH := "res://data/atlas.json"
const MAP_SIZE := Vector2(1200, 760)
const CELL_SIZE := 32.0
const KIND_ZOOM := {"country": 1.0, "region": 2.0, "district": 6.0, "municipality": 24.0, "local_admin": 24.0}
const KIND_DETAIL := {"country": 0, "region": 1, "district": 2, "municipality": 3, "local_admin": 3}
const CITY_POPULATION_TIERS := [1000000, 350000, 80000, 20000]
static var _shared: Dictionary = {}

var features: Array = []
var cities: Array = []
var rivers: Array = []
var sources: Array = []
var error_message := ""
var _geometry := PackedByteArray()
var _paths: Dictionary = {}
var _feature_grids: Dictionary = {}
var _city_grid: Dictionary = {}
var _city_tier_grids: Dictionary = {}
var _lookup: Dictionary = {}
var _search_index: Array = []
var _administrative_coverage: Dictionary = {}

func load_data() -> bool:
	if not _shared.is_empty():
		_restore_shared()
		return true
	if not FileAccess.file_exists(DATA_PATH):
		error_message = "Die eingebetteten Atlasdaten fehlen."
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary) or int(parsed.get("schema", 0)) != 1:
		error_message = "Die Atlasdaten haben ein unbekanntes Format."
		return false
	var geometry_path := str(parsed.get("geometry", ""))
	if geometry_path.is_empty() or not FileAccess.file_exists(geometry_path):
		error_message = "Die eingebetteten Grenzgeometrien fehlen."
		return false
	_geometry = FileAccess.get_file_as_bytes(geometry_path)
	if _geometry.is_empty() or _geometry.size() % 8 != 0:
		error_message = "Die Grenzgeometrien sind unvollständig."
		return false
	features = []
	cities = []
	rivers = []
	_feature_grids = {}
	_city_grid = {}
	_city_tier_grids = {}
	for minimum_population in CITY_POPULATION_TIERS:
		_city_tier_grids[minimum_population] = {}
	_lookup = {}
	_search_index = []
	_paths = {}
	for raw in parsed.get("features", []):
		if not (raw is Dictionary):
			continue
		var feature: Dictionary = raw.duplicate()
		feature["bounds"] = _rect(raw.get("bounds", []))
		feature["center"] = _point(raw.get("center", []))
		feature["point"] = feature.center
		feature["paths"] = raw.get("paths", [])
		feature["kind"] = str(raw.get("kind", "region"))
		var index := features.size()
		features.append(feature)
		var kind: String = feature.kind
		if not _feature_grids.has(kind):
			_feature_grids[kind] = {}
		_index_rect(_feature_grids[kind], feature.bounds, index)
		_add_lookup(feature, 0)
	for raw in parsed.get("cities", []):
		if not (raw is Dictionary):
			continue
		var city: Dictionary = raw.duplicate()
		city["point"] = _point(raw.get("point", []))
		city["kind"] = "city"
		city["population"] = int(raw.get("population", 0))
		var index := cities.size()
		cities.append(city)
		var city_rect := Rect2(city.point, Vector2(0.001, 0.001))
		# Der Vollindex bleibt für die räumliche Auswahl aller Orte erhalten.
		_index_rect(_city_grid, city_rect, index)
		for minimum_population in CITY_POPULATION_TIERS:
			if int(city.population) >= int(minimum_population):
				_index_rect(_city_tier_grids[minimum_population], city_rect, index)
		_add_lookup(city, int(city.population) + 1000000)
	for raw in parsed.get("rivers", []):
		if not (raw is Dictionary):
			continue
		var river: Dictionary = raw.duplicate()
		river["bounds"] = _rect(raw.get("bounds", []))
		river["paths"] = raw.get("paths", [])
		rivers.append(river)
	sources = parsed.get("sources", [])
	_administrative_coverage = parsed.get("administrative_coverage", {})
	if features.is_empty() or cities.is_empty():
		error_message = "Der Atlas enthält keine vollständigen Orte und Gebiete."
		return false
	_shared = {"features": features, "cities": cities, "rivers": rivers, "sources": sources,
		"geometry": _geometry, "paths": _paths, "feature_grids": _feature_grids,
		"city_grid": _city_grid, "city_tier_grids": _city_tier_grids,
		"lookup": _lookup, "search_index": _search_index, "administrative_coverage": _administrative_coverage}
	return true

func _restore_shared() -> void:
	features = _shared.features
	cities = _shared.cities
	rivers = _shared.rivers
	sources = _shared.sources
	_geometry = _shared.geometry
	_paths = _shared.paths
	_feature_grids = _shared.feature_grids
	_city_grid = _shared.city_grid
	_city_tier_grids = _shared.city_tier_grids
	_lookup = _shared.lookup
	_search_index = _shared.search_index
	_administrative_coverage = _shared.administrative_coverage

func coverage_for_country(country: String) -> Dictionary:
	return _administrative_coverage.get(country, {})

func project(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 12.0) / 64.0 * 1200.0, (72.0 - lat) / 39.0 * 760.0)

func path(reference: Array) -> PackedVector2Array:
	if reference.size() != 2:
		return PackedVector2Array()
	var offset := int(reference[0])
	var count := int(reference[1])
	if offset < 0 or count < 2 or offset > _geometry.size() / 8 or count > _geometry.size() / 8 - offset:
		return PackedVector2Array()
	var key := Vector2i(offset, count)
	if _paths.has(key):
		return _paths[key]
	var points := PackedVector2Array()
	points.resize(count)
	for i in count:
		var byte_offset := (offset + i) * 8
		points[i] = Vector2(_geometry.decode_float(byte_offset), _geometry.decode_float(byte_offset + 4))
	_paths[key] = points
	return points

func visible_features(rect: Rect2, zoom: float) -> Array:
	var result: Array = []
	# Nicht sichtbare Ebenen werden vor der räumlichen Abfrage ausgelassen.
	# So werden etwa Gemeinde-IDs bei einer Länderansicht gar nicht dedupliziert.
	for kind in _feature_grids:
		if zoom < float(KIND_ZOOM.get(str(kind), 10.0)):
			continue
		for index in _query(_feature_grids[kind], rect):
			var feature: Dictionary = features[int(index)]
			if feature.bounds.intersects(rect):
				result.append(feature)
	return result

func visible_cities(rect: Rect2, zoom: float) -> Array:
	var minimum_population := 0
	if zoom < 1.8:
		minimum_population = 1000000
	elif zoom < 3.0:
		minimum_population = 350000
	elif zoom < 5.0:
		minimum_population = 80000
	elif zoom < 8.0:
		minimum_population = 20000
	var result: Array = []
	var grid: Dictionary = _city_grid if minimum_population == 0 else _city_tier_grids[minimum_population]
	for index in _query(grid, rect):
		var city: Dictionary = cities[int(index)]
		if int(city.population) >= minimum_population and rect.has_point(city.point):
			result.append(city)
	return result

func search(query: String, limit: int = 20) -> Array:
	var term := _fold(query)
	if term.is_empty() or limit <= 0:
		return []
	var matches: Array = []
	for entry in _search_index:
		var name: String = entry.text
		var position := name.find(term)
		if position < 0:
			continue
		var category := 0 if name == term else (1 if position == 0 else 2)
		matches.append({"record": entry.record, "category": category, "rank": entry.rank, "name": name})
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.category) != int(b.category):
			return int(a.category) < int(b.category)
		if int(a.rank) != int(b.rank):
			return int(a.rank) > int(b.rank)
		return str(a.name) < str(b.name))
	var result: Array = []
	for i in mini(limit, matches.size()):
		result.append(matches[i].record)
	return result

func lookup(id: String) -> Dictionary:
	return _lookup.get(id, {})

func nearest_city(point: Vector2, radius: float = 8.0) -> Dictionary:
	var result: Dictionary = {}
	var best := radius * radius
	for index in _query(_city_grid, Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		var city: Dictionary = cities[int(index)]
		var distance: float = city.point.distance_squared_to(point)
		if distance < best:
			best = distance
			result = city
	return result

func feature_at(point: Vector2, zoom: float = 16.0) -> Dictionary:
	var result: Dictionary = {}
	var smallest := INF
	var deepest := -1
	for feature in visible_features(Rect2(point - Vector2(0.001, 0.001), Vector2(0.002, 0.002)), zoom):
		var detail := int(KIND_DETAIL.get(str(feature.kind), -1))
		var area: float = feature.bounds.get_area()
		if detail < deepest or (detail == deepest and area >= smallest):
			continue
		var contained := false
		for reference in feature.paths:
			var ring := path(reference)
			if ring.size() >= 3 and Geometry2D.is_point_in_polygon(point, ring):
				contained = not contained
		if contained:
			result = feature
			smallest = area
			deepest = detail
	return result

func _add_lookup(record: Dictionary, rank: int) -> void:
	_lookup[str(record.get("id", ""))] = record
	if not bool(record.get("name_known", true)):
		return
	_search_index.append({"text": _fold(str(record.get("name", ""))), "record": record, "rank": rank})

func _index_rect(grid: Dictionary, rect: Rect2, index: int) -> void:
	var first := Vector2i(floori(rect.position.x / CELL_SIZE), floori(rect.position.y / CELL_SIZE))
	var last := Vector2i(floori(rect.end.x / CELL_SIZE), floori(rect.end.y / CELL_SIZE))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, y)
			if not grid.has(key):
				grid[key] = []
			grid[key].append(index)

func _query(grid: Dictionary, rect: Rect2) -> Array:
	var clipped := rect.intersection(Rect2(Vector2.ZERO, MAP_SIZE))
	if not clipped.has_area():
		return []
	var first := Vector2i(floori(clipped.position.x / CELL_SIZE), floori(clipped.position.y / CELL_SIZE))
	var last := Vector2i(floori(clipped.end.x / CELL_SIZE), floori(clipped.end.y / CELL_SIZE))
	var found: Dictionary = {}
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for index in grid.get(Vector2i(x, y), []):
				found[index] = true
	return found.keys()

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value.size() == 2 else Vector2.ZERO

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3])) if value.size() == 4 else Rect2()

static func _fold(text: String) -> String:
	var folded := text.strip_edges().to_lower()
	for pair in [["ä", "a"], ["ö", "o"], ["ü", "u"], ["ß", "ss"], ["é", "e"], ["è", "e"], ["ê", "e"], ["á", "a"], ["à", "a"], ["â", "a"], ["í", "i"], ["ó", "o"], ["ô", "o"], ["ú", "u"], ["ñ", "n"], ["ç", "c"]]:
		folded = folded.replace(pair[0], pair[1])
	return folded
