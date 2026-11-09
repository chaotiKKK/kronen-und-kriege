extends Node
## Prüft die erzeugte Europakarte: 49 Grafschaften, gültige Flächen,
## Gelände, 29 Herzogtümer, 9 Königreiche, 3 Reiche und Nachbarschaften.

var _checks: int = 0

func _ready() -> void:
	var data = load("res://scripts/Data.gd")
	var ps: Array = data.provinces()
	var kingdoms := {}
	var duchies := {}
	var empires := {}
	var terrains := {}
	var bad := 0
	for p in ps:
		var pts: PackedVector2Array = p["points"]
		kingdoms[p["kingdom"]] = true
		duchies[p["duchy"]] = true
		empires[p["empire"]] = true
		if pts.size() < 3:
			print("BAD %s: zu wenig Punkte" % p["id"])
			bad += 1
			continue
		var area := 0.0
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			area += a.x * b.y - b.x * a.y
		area = absf(area) * 0.5
		var minx := 1e9
		var maxx := -1e9
		var miny := 1e9
		var maxy := -1e9
		for q in pts:
			minx = minf(minx, q.x); maxx = maxf(maxx, q.x)
			miny = minf(miny, q.y); maxy = maxf(maxy, q.y)
		if area < 200.0 or minx < 0.0 or miny < 0.0 or maxx > 1200.0 or maxy > 760.0:
			print("BAD %s: area=%.0f bounds=(%.0f,%.0f)-(%.0f,%.0f)" % [p["id"], area, minx, miny, maxx, maxy])
			bad += 1
		var terrain_key := str(p.get("terrain", ""))
		if not data.COUNTY_TERRAIN.has(str(p["id"])) or not data.TERRAIN_TYPES.has(terrain_key) or not p.has("terrain_name") or not p.has("terrain_color") or not p.has("terrain_defense") or not p.has("terrain_supply"):
			print("BAD %s: Geländefelder unvollständig" % p["id"])
			bad += 1
		else:
			terrains[terrain_key] = true
	print("PROVINCES=%d KINGDOMS=%d DUCHIES=%d EMPIRES=%d TERRAIN=%d BAD=%d" % [ps.size(), kingdoms.size(), duchies.size(), empires.size(), terrains.size(), bad])
	var adj: Dictionary = load("res://scripts/Data.gd").adjacency()
	var empty: Array = []
	for p in ps:
		if (adj[p["id"]] as Array).is_empty():
			empty.append(p["id"])
	print("ADJ=%d EMPTY=%s" % [adj.size(), ", ".join(empty)])
	if not _check(bad == 0, "Mindestens eine Provinz ist geometrisch oder im Gelände ungültig."):
		return
	if not _check(ps.size() == 49, "Die Karte hat %d statt 49 Provinzen." % ps.size()):
		return
	if not _check(kingdoms.size() == 9, "Die Karte hat %d statt 9 Königreiche." % kingdoms.size()):
		return
	if not _check(duchies.size() >= 20, "Die Karte hat nur %d Herzogtümer." % duchies.size()):
		return
	if not _check(empires.size() == 3, "Die Karte hat %d statt 3 Reiche." % empires.size()):
		return
	if not _check(terrains.size() == 9, "Es fehlen Geländetypen: %d von 9." % terrains.size()):
		return
	if not _check(data.COUNTY_TERRAIN.size() == 49, "COUNTY_TERRAIN enthält %d statt 49 Einträge." % data.COUNTY_TERRAIN.size()):
		return
	if not _check(adj.size() == 49, "Die Adjazenz hat %d statt 49 Einträge." % adj.size()):
		return
	if not _check(empty.is_empty(), "Provinzen ohne Nachbarn: %s" % ", ".join(empty)):
		return
	print("MAPDATATEST OK: %d Provinzen, %d Königreiche, %d Herzogtümer, %d Reiche, %d Gelände; %d Prüfungen." % [
		ps.size(), kingdoms.size(), duchies.size(), empires.size(), terrains.size(), _checks
	])
	get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	print("MAPDATATEST FAIL: " + message)
	get_tree().quit(1)
	return false
