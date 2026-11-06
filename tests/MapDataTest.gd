extends Node
## Prüft die erzeugte Europakarte: 49 Grafschaften, gültige Flächen,
## 25 Herzogtümer, 9 Königreiche, 3 Reiche und Nachbarschaften.

func _ready() -> void:
	var ps: Array = load("res://scripts/Data.gd").provinces()
	var kingdoms := {}
	var duchies := {}
	var empires := {}
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
	print("PROVINCES=%d KINGDOMS=%d DUCHIES=%d EMPIRES=%d BAD=%d" % [ps.size(), kingdoms.size(), duchies.size(), empires.size(), bad])
	var adj: Dictionary = load("res://scripts/Data.gd").adjacency()
	var empty: Array = []
	for p in ps:
		if (adj[p["id"]] as Array).is_empty():
			empty.append(p["id"])
	print("ADJ=%d EMPTY=%s" % [adj.size(), ", ".join(empty)])
	if bad > 0 or ps.size() != 49 or kingdoms.size() != 9 or duchies.size() < 20 or empires.size() != 3 or not empty.is_empty():
		print("MAPDATATEST FAIL")
		get_tree().quit(1)
		return
	print("MAPDATATEST OK")
	get_tree().quit(0)
