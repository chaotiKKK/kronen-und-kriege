extends RefCounted
## Explizit zugelassene Wasserwege, getrennt von Landnachbarn und Texturfarben.
## Die konservative Wasserprüfung erfolgt vor Aufnahme in die Produktdaten.
## Dieser Reader prüft Format, Quellenbindung und Regionsrandanker erneut.
const DATA_PATH := "res://data/naval_routes.json"
const Catalog = preload("res://scripts/GameRegionCatalog.gd")
const MAP_SIZE := Vector2(1200,760)
# Vector2/Regionskonturen verwenden Float32; der Offlinebeleg behält Float64.
const ANCHOR_TOLERANCE := 0.001
var error_message := ""
var _routes: Dictionary = {}
var _fingerprint := ""

func load_data() -> bool:
	if not FileAccess.file_exists(DATA_PATH):
		return _fail("Die eingebetteten Seewege fehlen.")
	return load_bytes(FileAccess.get_file_as_string(DATA_PATH))

func load_bytes(raw: String) -> bool:
	_clear()
	var decoder := JSON.new()
	if decoder.parse(raw)!=OK:
		return _fail("Die Seewege sind nicht als JSON lesbar.")
	var document = decoder.data
	if not document is Dictionary or not _integer(document.get("schema"),1,1):
		return _fail("Die Seewege haben ein unbekanntes Format.")
	var projection = document.get("projection")
	if not projection is Dictionary or not _same_numbers(projection.get("size"),[1200,760]) or not _same_numbers(projection.get("lon"),[-12,52]) or not _same_numbers(projection.get("lat"),[33,72]):
		return _fail("Die Kartenprojektion der Seewege stimmt nicht.")
	var sources = document.get("sources")
	if not sources is Dictionary or sources.size()!=5:
		return _fail("Die Quellenbindung der Seewege ist unvollständig.")
	var manifest_decoder := JSON.new()
	if manifest_decoder.parse(FileAccess.get_file_as_string(Catalog.DATA_PATH))!=OK:
		return _fail("Der Regionskatalog der Seewege ist nicht lesbar.")
	var manifest = manifest_decoder.data
	if not manifest is Dictionary or not _digest(document.get("catalog_hash")) or document.catalog_hash!=manifest.get("catalog_hash"):
		return _fail("Die Seewege gehören zu einem anderen Regionskatalog.")
	for path in ["data/game_regions.json","data/game_region_geometry.bin"]:
		if not _digest(sources.get(path)) or sources[path]!=FileAccess.get_sha256("res://"+path):
			return _fail("Die Regionsquelle der Seewege wurde verändert.")
	for path in ["data/atlas.json","data/atlas_geometry.bin","data/europe_geometry.json"]:
		if not _digest(sources.get(path)) or sources[path]!=manifest.get("input_hashes",{}).get(path):
			return _fail("Die Küstenquellen der Seewege passen nicht zum Regionskatalog.")
	var verification = document.get("verification")
	if not verification is Dictionary or verification.get("method")!="open-water-land-union-v1" or not _digest(verification.get("proof_sha256")) or not _digest(verification.get("verifier_sha256")) or not _number(verification.get("max_length_map_units")) or float(verification.max_length_map_units)<=0.0 or float(verification.max_length_map_units)>150.0:
		return _fail("Der geometrische Aufnahmebeleg der Seewege fehlt.")
	var definitions = document.get("routes")
	if not definitions is Array or definitions.is_empty():
		return _fail("Die Tabelle enthält keine verifizierten Seewege.")
	var catalog = Catalog.new()
	if not catalog.load_data():
		return _fail("Der Regionskatalog der Seewege ist ungültig: "+catalog.error_message)
	var ids := {}
	for definition in definitions:
		if not definition is Dictionary:
			return _fail("Ein Seeweg ist beschädigt.")
		var id = definition.get("id")
		var origin = definition.get("from")
		var destination = definition.get("to")
		if not id is String or id.is_empty() or ids.has(id) or not origin is String or not destination is String or origin==destination:
			return _fail("Eine Seewegkennung ist ungültig oder doppelt.")
		var start_region: Dictionary = catalog.get_region(origin)
		var end_region: Dictionary = catalog.get_region(destination)
		if start_region.is_empty() or end_region.is_empty() or _routes.get(origin,{}).has(destination):
			return _fail("Ein Seewegziel ist unbekannt oder doppelt verbunden.")
		var raw_points = definition.get("points")
		if not raw_points is Array or raw_points.size()<2:
			return _fail("Die Wasserlinie eines Seewegs ist unvollständig.")
		var points := PackedVector2Array()
		for coordinates in raw_points:
			if not coordinates is Array or coordinates.size()!=2 or not _number(coordinates[0]) or not _number(coordinates[1]):
				return _fail("Eine Seewegkoordinate ist ungültig.")
			var point := Vector2(float(coordinates[0]),float(coordinates[1]))
			if point.x<0.0 or point.y<0.0 or point.x>MAP_SIZE.x or point.y>MAP_SIZE.y:
				return _fail("Ein Seeweg verlässt die Spielkarte.")
			points.append(point)
		if not _on_boundary(start_region,points[0]) or not _on_boundary(end_region,points[points.size()-1]):
			return _fail("Ein Seeweg besitzt keinen passenden Regionsrandanker.")
		var measured_length := 0.0
		for index in range(1,raw_points.size()):
			var dx: float = float(raw_points[index][0])-float(raw_points[index-1][0])
			var dy: float = float(raw_points[index][1])-float(raw_points[index-1][1])
			var segment_length := sqrt(dx*dx+dy*dy)
			if segment_length<=0.0:
				return _fail("Ein Seeweg enthält eine leere Etappe.")
			measured_length += segment_length
		if not _number(definition.get("length_map_units")) or absf(float(definition.length_map_units)-measured_length)>0.000001 or measured_length>float(verification.max_length_map_units):
			return _fail("Die Länge eines Seewegs stimmt nicht mit der geprüften Wasserlinie überein.")
		var proof = definition.get("proof")
		if not _accepted_proof(proof):
			return _fail("Hin- und Rückweg besitzen keinen vollständigen Wasserbeleg.")
		var forward: Dictionary = definition.duplicate(true)
		forward.points = points
		forward.coasts_verified = true
		var reverse: Dictionary = forward.duplicate(true)
		reverse.from = destination
		reverse.to = origin
		var reverse_points := points.duplicate()
		reverse_points.reverse()
		reverse.points = reverse_points
		if not _routes.has(origin): _routes[origin] = {}
		if not _routes.has(destination): _routes[destination] = {}
		_routes[origin][destination] = forward
		_routes[destination][origin] = reverse
		ids[id] = true
	# Der logische Fingerabdruck ist unabhängig von Einrückung und Schlüssel-
	# beziehungsweise Eintragsreihenfolge. Die Rohbeleg-Hashes bleiben enthalten.
	var normalized: Dictionary = document.duplicate(true)
	normalized.routes.sort_custom(func(a,b): return str(a.id)<str(b.id))
	_fingerprint = JSON.stringify(_canonical(normalized),"",true,true).sha256_text()
	return true

func route(from_id: String, to_id: String) -> Dictionary:
	return (_routes.get(from_id,{}).get(to_id,{}) as Dictionary).duplicate(true)

func destinations(id: String) -> Array:
	var result: Array = _routes.get(id,{}).keys()
	result.sort()
	return result

func is_port(id: String) -> bool:
	return _routes.has(id)

func fingerprint() -> String:
	return _fingerprint

func _accepted_proof(proof) -> bool:
	if not proof is Dictionary: return false
	for key in ["accepted","reverse_accepted","strict_ocean_covers","reverse_strict_ocean_covers","only_endpoint_land_contacts","reverse_only_endpoint_land_contacts"]:
		if not proof.get(key) is bool or not proof[key]: return false
	for key in ["land_contact_length","reverse_land_contact_length"]:
		if not _number(proof.get(key)) or float(proof[key])!=0.0: return false
	return true

func _on_boundary(region: Dictionary, point: Vector2) -> bool:
	for part in region.parts:
		for index in part.size():
			var a: Vector2 = part[index]
			var edge: Vector2 = part[(index+1)%part.size()]-a
			var squared := edge.length_squared()
			var closest := a if squared==0.0 else a+edge*clampf((point-a).dot(edge)/squared,0.0,1.0)
			if point.distance_to(closest)<=ANCHOR_TOLERANCE: return true
	return false

func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _same_numbers(value, expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size(): return false
	for index in expected.size():
		if not _number(value[index]) or float(value[index])!=float(expected[index]): return false
	return true

func _integer(value, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value)==floorf(float(value)) and float(value)>=minimum and float(value)<=maximum

func _digest(value) -> bool:
	return value is String and value.length()==64 and value==value.to_lower() and value.is_valid_hex_number(false)

func _canonical(value):
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys: result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_canonical(item))
		return result
	return value

func _clear() -> void:
	error_message = ""
	_routes.clear()
	_fingerprint = ""

func _fail(message: String) -> bool:
	_clear()
	error_message = message
	return false
