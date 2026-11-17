extends RefCounted
## Eingefrorene Spielregionen. Der Detailatlas wird getrennt geladen.
const DATA_PATH := "res://data/game_regions.json"
const CELL_SIZE := 32.0

var error_message := ""
var _regions: Array = []
var _lookup: Dictionary = {}
var _grid: Dictionary = {}
var _catalog_hash := ""

func load_data() -> bool:
	if not FileAccess.file_exists(DATA_PATH):
		return _fail("Die eingebetteten Spielregionen fehlen.")
	var raw := FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return _fail("Die Spielregionen sind nicht lesbar.")
	var path := str(parsed.get("geometry", ""))
	if path != "res://data/game_region_geometry.bin" or not FileAccess.file_exists(path):
		return _fail("Die eingebettete Regionsgeometrie fehlt.")
	return load_bytes(raw, FileAccess.get_file_as_bytes(path))

func load_bytes(raw: String, geometry: PackedByteArray) -> bool:
	_clear()
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary or int(parsed.get("schema", 0)) != 1:
		return _fail("Die Spielregionen haben ein unbekanntes Format.")
	if geometry.is_empty() or geometry.size() % 8 != 0:
		return _fail("Die Regionsgeometrie ist unvollständig.")
	var geometry_context := HashingContext.new()
	geometry_context.start(HashingContext.HASH_SHA256)
	geometry_context.update(geometry)
	if geometry_context.finish().hex_encode() != str(parsed.get("geometry_sha256", "")):
		return _fail("Die Prüfsumme der Regionsgeometrie stimmt nicht.")
	# Hash the exact canonical writer bytes, preserving its float representation.
	var expression := RegEx.new()
	expression.compile('"catalog_hash":"([a-f0-9]{64})",')
	var matches := expression.search_all(raw)
	if matches.size() != 1:
		return _fail("Der eindeutige Katalogfingerabdruck fehlt.")
	var match_data: RegExMatch = matches[0]
	var content := raw.erase(match_data.get_start(), match_data.get_end() - match_data.get_start()).trim_suffix("\n")
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(content.to_utf8_buffer())
	hash_context.update(geometry)
	var digest := hash_context.finish().hex_encode()
	if digest != str(parsed.get("catalog_hash", "")):
		return _fail("Die Prüfsumme des Regionskatalogs stimmt nicht.")
	var raw_regions = parsed.get("regions", [])
	if not raw_regions is Array or raw_regions.size() < 100 or raw_regions.size() > 115 or int(parsed.get("region_count", 0)) != raw_regions.size():
		return _fail("Die Anzahl der Spielregionen ist ungültig.")
	for source in raw_regions:
		if not source is Dictionary:
			return _fail("Eine Spielregion ist beschädigt.")
		var region: Dictionary = source.duplicate(true)
		var id := str(region.get("id", ""))
		if id.is_empty() or _lookup.has(id) or str(region.get("kind", "")) != "game_region":
			return _fail("Eine Regionskennung ist ungültig oder doppelt.")
		var anchor = region.get("capital_anchor", [])
		if not anchor is Array or anchor.size() != 2:
			return _fail("Der Regionsanker fehlt.")
		region.capital_anchor = Vector2(float(anchor[0]), float(anchor[1]))
		var bounds = region.get("bounds", [])
		if not bounds is Array or bounds.size() != 4:
			return _fail("Die Regionsgrenzen fehlen.")
		region.bounds = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]) - float(bounds[0]), float(bounds[3]) - float(bounds[1]))
		region.parts = []
		for reference in region.get("geometry_refs", []):
			if not reference is Array or reference.size() != 2:
				return _fail("Ein Geometrieverweis ist beschädigt.")
			var offset := int(reference[0])
			var count := int(reference[1])
			if offset < 0 or count < 3 or count > geometry.size() / 8 - offset:
				return _fail("Ein Geometrieverweis überschreitet die eingebetteten Daten.")
			var points := PackedVector2Array()
			for index in count:
				var byte_offset := (offset + index) * 8
				var point := Vector2(geometry.decode_float(byte_offset), geometry.decode_float(byte_offset + 4))
				if not point.is_finite():
					return _fail("Die Regionsgeometrie enthält ungültige Koordinaten.")
				points.append(point)
			region.parts.append(points)
		if region.parts.is_empty() or not _contains(region, region.capital_anchor):
			return _fail("Eine Spielregion besitzt keinen gültigen Innenanker.")
		var shares = region.get("legacy_region_shares", {})
		if not shares is Dictionary or shares.is_empty():
			return _fail("Die Migrationsanteile fehlen.")
		var total := 0.0
		for share in shares.values():
			var value := float(share)
			if not is_finite(value) or value <= 0.0:
				return _fail("Ein Migrationsanteil ist ungültig.")
			total += value
		if absf(total - 1.0) > 0.000001:
			return _fail("Die Migrationsanteile sind unvollständig.")
		_lookup[id] = region
		_regions.append(region)
		_index(region)
	for region in _regions:
		var neighbours = region.get("neighbours", [])
		if not neighbours is Array:
			return _fail("Die Regionsnachbarschaften sind beschädigt.")
		for neighbour in neighbours:
			if str(neighbour) == str(region.id) or not _lookup.has(str(neighbour)) or not _lookup[str(neighbour)].get("neighbours", []).has(region.id):
				return _fail("Die Regionsnachbarschaften sind unvollständig.")
	_catalog_hash = digest
	return true

func regions() -> Array:
	return _regions.duplicate(true)

func catalog_hash() -> String:
	return _catalog_hash

func get_region(id: String) -> Dictionary:
	return _lookup.get(id, {}).duplicate(true)

func region_at(point: Vector2) -> Dictionary:
	var key := Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
	for id in _grid.get(key, []):
		var region: Dictionary = _lookup[id]
		if _contains(region, point):
			return region.duplicate(true)
	return {}

func query(rect: Rect2) -> Array:
	var ids := {}
	for x in range(floori(rect.position.x / CELL_SIZE), floori(rect.end.x / CELL_SIZE) + 1):
		for y in range(floori(rect.position.y / CELL_SIZE), floori(rect.end.y / CELL_SIZE) + 1):
			for id in _grid.get(Vector2i(x, y), []):
				ids[id] = true
	var keys := ids.keys()
	keys.sort()
	var result: Array = []
	for id in keys:
		if (_lookup[id].bounds as Rect2).intersects(rect):
			result.append(_lookup[id].duplicate(true))
	return result

func _contains(region: Dictionary, point: Vector2) -> bool:
	for part in region.parts:
		if Geometry2D.is_point_in_polygon(point, part):
			return true
	return false

func _index(region: Dictionary) -> void:
	var rect: Rect2 = region.bounds
	for x in range(floori(rect.position.x / CELL_SIZE), floori(rect.end.x / CELL_SIZE) + 1):
		for y in range(floori(rect.position.y / CELL_SIZE), floori(rect.end.y / CELL_SIZE) + 1):
			var key := Vector2i(x, y)
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(str(region.id))

func _clear() -> void:
	error_message = ""
	_regions.clear()
	_lookup.clear()
	_grid.clear()
	_catalog_hash = ""

func _fail(message: String) -> bool:
	_clear()
	error_message = message
	return false
