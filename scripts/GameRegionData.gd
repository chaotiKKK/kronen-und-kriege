extends RefCounted
## Adapter zwischen eingefrorenem Regionskatalog und bestehender Spiellogik.
const Legacy = preload("res://scripts/Data.gd")
const Catalog = preload("res://scripts/GameRegionCatalog.gd")
static var _provinces: Array = []
static var _houses: Array = []
static var _adjacency: Dictionary = {}

static func provinces() -> Array:
	_ensure()
	return _provinces.duplicate(true)

static func houses() -> Array:
	_ensure()
	return _houses.duplicate(true)

static func adjacency() -> Dictionary:
	_ensure()
	return _adjacency.duplicate(true)

static func _ensure() -> void:
	if not _provinces.is_empty():
		return
	var catalog := Catalog.new()
	if not catalog.load_data():
		push_error(catalog.error_message)
		return
	var old_by_id := {}
	for old in Legacy.provinces():
		old_by_id[str(old.id)] = old
	var by_id := {}
	for region in catalog.regions():
		var parent_ids: Array = region.legacy_region_shares.keys()
		parent_ids.sort_custom(func(a, b):
			var left := float(region.legacy_region_shares[a])
			var right := float(region.legacy_region_shares[b])
			return left > right if left != right else str(a) < str(b))
		var parent: Dictionary = old_by_id[str(parent_ids[0])]
		var p: Dictionary = parent.duplicate(true)
		p.merge(region, true)
		p.points = region.parts[0]
		p.label_pos = region.capital_anchor
		p.capital = false
		p.base_income = 0
		p.levy = 0
		p.economic_share = 0.0
		var development := 0.0
		for id in region.legacy_region_shares:
			development += float(old_by_id[id].dev) * float(region.legacy_region_shares[id])
		for share in region.legacy_parent_shares.values():
			p.economic_share += float(share)
		p.dev = roundi(development)
		p.initial_dev = p.dev
		p.coastal = _coastal(p.parts)
		by_id[str(p.id)] = p
		_provinces.append(p)
		_adjacency[str(p.id)] = region.neighbours.duplicate()
	for old_id in old_by_id:
		var shares := {}
		for p in _provinces:
			if p.legacy_parent_shares.has(old_id):
				shares[str(p.id)] = float(p.legacy_parent_shares[old_id])
		var old: Dictionary = old_by_id[old_id]
		for budget in [["base_income", int(old.dev) * 4], ["levy", int(old.levy)]]:
			var allocation := _allocate(int(budget[1]), shares)
			for id in allocation:
				by_id[id][budget[0]] += int(allocation[id])
	_houses = Legacy.houses()
	for house in _houses:
		var old_id := str(house.capital)
		var old: Dictionary = old_by_id[old_id]
		var candidates: Array = []
		for p in _provinces:
			if p.legacy_parent_shares.has(old_id):
				candidates.append(p)
		candidates.sort_custom(func(a, b):
			var in_a := _contains(a.parts, old.label_pos)
			var in_b := _contains(b.parts, old.label_pos)
			if in_a != in_b:
				return in_a
			var left := float(a.legacy_parent_shares[old_id])
			var right := float(b.legacy_parent_shares[old_id])
			return left > right if left != right else str(a.id) < str(b.id))
		if not candidates.is_empty():
			house.capital = str(candidates[0].id)
			candidates[0].capital = true

static func _allocate(total: int, shares: Dictionary) -> Dictionary:
	var result := {}
	var remainder := total
	var ids: Array = shares.keys()
	for id in ids:
		var value := floori(total * float(shares[id]))
		result[id] = value
		remainder -= value
	ids.sort_custom(func(a, b):
		var left := total * float(shares[a]) - int(result[a])
		var right := total * float(shares[b]) - int(result[b])
		return left > right if left != right else str(a) < str(b))
	for index in remainder:
		result[ids[index % ids.size()]] += 1
	return result

static func _contains(parts: Array, point: Vector2) -> bool:
	for part in parts:
		if Geometry2D.is_point_in_polygon(point, part):
			return true
	return false

static func _coastal(parts: Array) -> bool:
	for part in parts:
		for index in part.size():
			var a: Vector2 = part[index]
			var b: Vector2 = part[(index + 1) % part.size()]
			var midpoint := (a + b) * 0.5
			var normal := (b - a).orthogonal().normalized()
			if Legacy._is_sea_at(midpoint + normal * 2.0) or Legacy._is_sea_at(midpoint - normal * 2.0):
				return true
	return false

static func is_coastal(id: String) -> bool:
	_ensure()
	for p in _provinces:
		if p.id == id:
			return bool(p.coastal)
	return false

static func terrain_for(id: String) -> String:
	_ensure()
	for p in _provinces:
		if p.id == id:
			return str(p.terrain)
	return "plains"

static func terrain_info(key: String) -> Dictionary:
	return Legacy.terrain_info(key)

static func events() -> Array:
	return Legacy.events()

static func name_pool() -> Array:
	return Legacy.name_pool()

static func kingdom_neighbours() -> Dictionary:
	return Legacy.kingdom_neighbours()
