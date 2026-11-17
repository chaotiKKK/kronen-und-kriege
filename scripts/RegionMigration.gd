extends RefCounted
## Pure conversion. File backup and installation happen only after validation.
const Legacy = preload("res://scripts/Data.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const KEYS := ["market", "barracks", "walls"]

static func _failure(source: Dictionary, message: String) -> Dictionary:
	return {"ok":false, "data":source.duplicate(true), "errors":[message]}

static func owner_for(region: Dictionary, parents: Dictionary, capitals: Dictionary) -> int:
	var ids: Array = region.legacy_region_shares.keys()
	var contained: Array = []
	for id in ids:
		if str(capitals.get(id, "")) == str(region.id):
			contained.append(id)
	if contained.size() == 1:
		return int(parents[contained[0]].owner)
	ids.sort_custom(func(a, b):
		var left := float(region.legacy_region_shares[a])
		var right := float(region.legacy_region_shares[b])
		return left > right if left != right else str(a) < str(b))
	return int(parents[ids[0]].owner)

static func _contains(region: Dictionary, point: Vector2) -> bool:
	for part in region.parts:
		if Geometry2D.is_point_in_polygon(point, part):
			return true
	return false

static func _successor(id: String, regions: Array, old_geometry: Dictionary, coastal := false) -> String:
	var candidates: Array = []
	for region in regions:
		if region.legacy_parent_shares.has(id) and (not coastal or bool(region.coastal)):
			candidates.append(region)
	if candidates.is_empty() and coastal:
		for region in regions:
			if bool(region.coastal):
				candidates.append(region)
	if candidates.is_empty():
		return ""
	var anchor: Vector2 = old_geometry[id].label_pos
	candidates.sort_custom(func(a, b):
		var inside_a := _contains(a, anchor)
		var inside_b := _contains(b, anchor)
		if inside_a != inside_b:
			return inside_a
		var left := float(a.legacy_parent_shares.get(id, 0.0))
		var right := float(b.legacy_parent_shares.get(id, 0.0))
		if left != right:
			return left > right
		var da: float = a.capital_anchor.distance_squared_to(anchor)
		var db: float = b.capital_anchor.distance_squared_to(anchor)
		return da < db if da != db else str(a.id) < str(b.id))
	return str(candidates[0].id)

static func _allocate(total: int, shares: Dictionary) -> Dictionary:
	var result := {}
	var remaining := total
	var ids: Array = shares.keys()
	for id in ids:
		var amount := floori(total * float(shares[id]))
		result[id] = amount
		remaining -= amount
	ids.sort_custom(func(a,b):
		var left := total * float(shares[a]) - int(result[a])
		var right := total * float(shares[b]) - int(result[b])
		return left > right if left != right else str(a) < str(b))
	for index in remaining:
		result[ids[index % ids.size()]] += 1
	return result

static func validate_current(state: Dictionary) -> Array:
	var errors: Array = []
	if str(state.get("region_catalog_hash", "")) != Regions.catalog_hash():
		errors.append("Der Spielstand gehört zu einem anderen Regionskatalog.")
	var known := {}
	for region in Regions.provinces():
		known[str(region.id)] = region
	var seen := {}
	for p in state.get("provinces", []):
		var id := str(p.get("id", ""))
		if not known.has(id) or seen.has(id):
			errors.append("Unbekannte oder doppelte Spielregion: " + id)
		seen[id] = true
		for key in ["base_income", "initial_dev", "economic_share", "building_effects", "initial_buildings"]:
			if not p.has(key):
				errors.append("Regionskapazität fehlt: " + key)
		if int(p.get("owner", -1)) < 0 or int(p.get("owner", -1)) >= state.get("houses", []).size():
			errors.append("Eine Spielregion hat keinen gültigen Besitzer.")
		for key in ["base_income", "levy", "economic_share"]:
			var value := float(p.get(key, -1))
			if not is_finite(value) or value < 0:
				errors.append("Ungültiger Regionswert: " + key)
		if known.has(id) and absf(float(p.get("economic_share", 0)) - float(known[id].economic_share)) > 0.000001:
			errors.append("Die Regionskapazität passt nicht zum Katalog.")
		for key in KEYS:
			var value := float(p.get("building_effects", {}).get(key, -1))
			if not is_finite(value) or value < 0:
				errors.append("Ungültige Gebäudewirkung: " + key)
	if seen.size() != known.size():
		errors.append("Der Spielstand enthält nicht alle 108 Regionen.")
	for h in state.get("houses", []):
		if not known.has(str(h.get("capital", ""))):
			errors.append("Eine Hauptstadt ist unbekannt.")
		for group in ["armies", "fleets", "claims"]:
			for entry in h.get(group, []):
				if not known.has(str(entry.get("province", ""))):
					errors.append("Eine Einheit oder ein Anspruch verweist auf eine unbekannte Region.")
				if entry.has("station") and not known.has(str(entry.station)):
					errors.append("Ein Flottenstandort ist unbekannt.")
		for id in h.get("faith", {}).get("holy_sites", []):
			if not known.has(str(id)):
				errors.append("Eine heilige Stätte ist unbekannt.")
	return errors

static func migrate_state(source: Dictionary) -> Dictionary:
	if str(source.get("world_layout", "")) == "regions108":
		var errors := validate_current(source)
		return {"ok":errors.is_empty(), "data":source.duplicate(true), "errors":errors}
	var geometry := {}
	for old in Legacy.provinces():
		geometry[str(old.id)] = old
	var parents := {}
	for old in source.get("provinces", []):
		var id := str(old.get("id", ""))
		if not geometry.has(id) or parents.has(id):
			return _failure(source, "Unbekannte oder doppelte Altprovinz: " + id)
		if int(old.get("owner", -1)) < 0 or int(old.owner) >= source.get("houses", []).size() or int(old.get("levy", -1)) < 0:
			return _failure(source, "Ungültige Besitzer-/Truppenzuordnung.")
		parents[id] = old
	if parents.size() != geometry.size():
		return _failure(source, "Für die Migration werden alle 49 Altprovinzen benötigt.")
	var regions: Array = Regions.provinces()
	var successors := {}
	var ports := {}
	for id in parents:
		successors[id] = _successor(id, regions, geometry)
		ports[id] = _successor(id, regions, geometry, true)
	var capitals := {}
	for h in source.get("houses", []):
		var id := str(h.get("capital", ""))
		if not successors.has(id):
			return _failure(source, "Eine alte Hauptstadt ist unbekannt.")
		# Only a geometrically contained capital receives ownership priority.
		for region in regions:
			if _contains(region, geometry[id].label_pos):
				capitals[id] = str(region.id)
				break
	var report := {"mixed_regions":[], "compensation_claims":[], "reset_sieges":[], "roads":[], "rounded_buildings":[]}
	var by_id := {}
	for region in regions:
		region.owner = owner_for(region, parents, capitals)
		region.economic_focus = "balanced"
		region.focus_changed_month = -1
		region.levy = 0
		region.base_income = 0
		region.defense = 0
		region.siege = 0
		region.siege_owner = -1
		region.blockade = 0
		region.blockade_owner = -1
		region.buildings = {}
		region.initial_buildings = {}
		region.building_effects = {"market":0.0,"barracks":0.0,"walls":0.0}
		var development := 0.0
		var defense := 0.0
		var owner_set := {}
		for id in region.legacy_region_shares:
			var share := float(region.legacy_region_shares[id])
			development += int(parents[id].dev) * share
			defense += int(parents[id].get("defense", 0)) * share
			owner_set[int(parents[id].owner)] = true
		for key in KEYS:
			var level := 0.0
			for id in region.legacy_region_shares:
				level += int(parents[id].get("buildings", {}).get(key, 0)) * float(region.legacy_region_shares[id])
			region.buildings[key] = roundi(level)
			region.initial_buildings[key] = roundi(level)
			if not is_equal_approx(level, round(level)):
				report.rounded_buildings.append({"id":region.id,"building":key,"before":level,"display":roundi(level)})
		region.dev = roundi(development)
		region.initial_dev = region.dev
		region.defense = roundi(defense)
		if owner_set.size() > 1:
			report.mixed_regions.append(region.id)
		by_id[str(region.id)] = region
	for id in parents:
		var old: Dictionary = parents[id]
		var shares := {}
		for region in regions:
			if region.legacy_parent_shares.has(id):
				shares[str(region.id)] = float(region.legacy_parent_shares[id])
		for budget in [["levy", int(old.levy)], ["base_income", int(old.dev) * 4]]:
			var allocation := _allocate(int(budget[1]), shares)
			for rid in allocation:
				by_id[rid][budget[0]] += int(allocation[rid])
		for rid in shares:
			for key in KEYS:
				by_id[rid].building_effects[key] += int(old.get("buildings", {}).get(key, 0)) * float(shares[rid])
		if int(old.get("siege", 0)) > 0 or int(old.get("blockade", 0)) > 0:
			report.reset_sieges.append(id)
	var out: Dictionary = source.duplicate(true)
	out.provinces = []
	for region in regions:
		var saved: Dictionary = region.duplicate(true)
		for key in ["points", "parts", "capital_anchor", "label_pos", "bounds", "terrain_color"]:
			saved.erase(key)
		out.provinces.append(saved)
	for h in out.houses:
		h.capital = successors[str(h.capital)]
		for group in ["armies", "fleets"]:
			for unit in h.get(group, []):
				var id := str(unit.get("province", ""))
				if not successors.has(id):
					return _failure(source, "Eine alte Einheit hat einen unbekannten Standort.")
				unit.province = ports[id] if group == "fleets" else successors[id]
				if unit.has("station"):
					var station := str(unit.station)
					if not ports.has(station):
						return _failure(source, "Ein alter Flottenstandort ist unbekannt.")
					unit.station = ports[station]
		var claims: Dictionary = {}
		for claim in h.get("claims", []):
			var id := str(claim.get("province", ""))
			if not successors.has(id):
				return _failure(source, "Ein alter Anspruch ist unbekannt.")
			var destinations: Array = []
			for region in regions:
				if float(region.legacy_region_shares.get(id, 0)) >= 0.2:
					destinations.append(str(region.id))
			if destinations.is_empty():
				destinations.append(successors[id])
			for rid in destinations:
				var copy: Dictionary = claim.duplicate(true)
				copy.province = rid
				if not claims.has(rid) or int(copy.get("strength",1)) > int(claims[rid].get("strength",1)):
					claims[rid] = copy
		h.claims = claims.values()
		var sites: Array = []
		for id in h.get("faith", {}).get("holy_sites", []):
			if not successors.has(str(id)):
				return _failure(source, "Eine alte heilige Stätte ist unbekannt.")
			if not sites.has(successors[id]):
				sites.append(successors[id])
		if h.has("faith"):
			h.faith.holy_sites = sites
	var month := int(source.get("month_index", 0)) + 1
	for region in regions:
		for id in region.legacy_region_shares:
			var previous_owner := int(parents[id].owner)
			if previous_owner != int(region.owner) and float(region.legacy_region_shares[id]) >= .2:
				out.houses[previous_owner].claims.append({"province":region.id,"strength":1,"expires":month+120})
				report.compensation_claims.append({"region":region.id,"house":previous_owner})
	for index in out.get("roads", []).size():
		var road: Dictionary = out.roads[index]
		var a := str(road.get("from", ""))
		var b := str(road.get("to", ""))
		if not successors.has(a) or not successors.has(b):
			return _failure(source, "Eine alte Straße hat unbekannte Endpunkte.")
		road.from = successors[a]
		road.to = successors[b]
		road["legacy_connection"] = true
		road["migration_origin"] = index
		report.roads.append({"from":a,"to":b,"new_from":road.from,"new_to":road.to})
	out["schema_version"] = 14
	out["world_layout"] = "regions108"
	out["region_catalog_hash"] = Regions.catalog_hash()
	out["migration_report"] = report
	out["migration_legacy"] = {"provinces":source.provinces.duplicate(true),"roads":source.get("roads", []).duplicate(true)}
	var errors := validate_current(out)
	return {"ok":errors.is_empty(),"data":out,"errors":errors,"report":report}
