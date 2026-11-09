extends SceneTree
## Exportiert die fertig aufbereiteten Provinzdaten aus Data.gd als JSON für
## tools/gen_map_assets.py. Der Export nutzt dieselbe Geometrie wie das Spiel,
## damit Relief, Normalmap und Marker exakt auf der 1200×760-Karte sitzen.

const DataScript = preload("res://scripts/Data.gd")


func _init() -> void:
	var target := OS.get_environment("MAP_ASSET_GEOMETRY")
	if target.is_empty():
		printerr("MAP_GEOMETRY FAIL: MAP_ASSET_GEOMETRY fehlt")
		quit(2)
		return
	if not target.is_absolute_path():
		target = ProjectSettings.globalize_path("res://").path_join(target)
	var parent := target.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(parent)
	var provinces: Array = DataScript.provinces()
	var payload := {
		"projection": {"size": [1200.0, 760.0]},
		"provinces": [],
	}
	for p in provinces:
		var parts: Array = []
		for part in p.get("parts", []):
			var points: Array = []
			for point in part:
				points.append([snappedf(float(point.x), 0.001), snappedf(float(point.y), 0.001)])
			if points.size() >= 3:
				parts.append(points)
		if parts.is_empty():
			continue
		var label: Vector2 = p.get("label_pos", Vector2.ZERO)
		payload["provinces"].append({
			"id": str(p["id"]),
			"name": str(p["name"]),
			"terrain": str(p.get("terrain", "plains")),
			"capital": bool(p.get("capital", false)),
			"kingdom": str(p["kingdom"]),
			"kingdom_name": str(p["kingdom_name"]),
			"empire": str(p["empire"]),
			"empire_name": str(p["empire_name"]),
			"dev": int(p.get("dev", 1)),
			"label": [snappedf(label.x, 0.001), snappedf(label.y, 0.001)],
			"parts": parts,
		})
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		printerr("MAP_GEOMETRY FAIL: Schreibfehler %s" % target)
		quit(3)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	print("MAP_GEOMETRY OK provinces=%d target=%s" % [payload["provinces"].size(), target])
	quit(0)
