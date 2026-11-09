extends Node
## Prüft die reproduzierbare Blender-Kartenpipeline: Dateien, PNG-Formate,
## Alpha-/Kontrastinhalt, GLB-Magic, Manifest sowie die Laufzeitbindung der
## Relieftextur und der neun Halte-/Königreichsmarker.

const OUT := "res://assets/map/generated/"
const MAP_SIZE := Vector2i(2400, 1520)

var _checks: int = 0
var _main


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _fail(message: String) -> void:
	print("MAPASSETTEST FAIL: " + message)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false


func _image(name: String) -> Image:
	var path := ProjectSettings.globalize_path(OUT + name)
	if not FileAccess.file_exists(path):
		_fail("Datei fehlt: " + path)
		return null
	var image := Image.load_from_file(path)
	if image == null:
		_fail("Bild nicht lesbar: " + path)
	return image


func _sheet_stats(image: Image, step: int = 8) -> Dictionary:
	var covered := 0
	var total := 0
	var colors := {}
	var lo := 1.0
	var hi := 0.0
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var color := image.get_pixel(x, y)
			total += 1
			if color.a > 0.2:
				covered += 1
			colors[color.to_rgba32()] = true
			var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			lo = minf(lo, luma)
			hi = maxf(hi, luma)
	return {"coverage": float(covered) / maxf(1.0, float(total)), "colors": colors.size(), "spread": hi - lo}


func _run() -> void:
	var height := _image("heightmap.png")
	var normal := _image("normal_map.png")
	var relief := _image("relief_shaded.png")
	var castle := _image("marker_castle.png")
	var banner := _image("marker_banner.png")
	if height == null or normal == null or relief == null or castle == null or banner == null:
		return
	if not _check(height.get_size() == MAP_SIZE and normal.get_size() == MAP_SIZE and relief.get_size() == MAP_SIZE,
			"Heightmap, Normalmap und Relief müssen 2400x1520 sein."):
		return
	if not _check(castle.get_size() == Vector2i(256, 256) and banner.get_size() == Vector2i(256, 256),
			"Marker-Sprites müssen 256x256 sein."):
		return
	if not _check(height.get_format() == Image.FORMAT_L8, "Heightmap ist nicht 8-bit-Graustufen."):
		return
	if not _check(normal.get_format() == Image.FORMAT_RGB8, "Normalmap ist nicht RGB8."):
		return
	if not _check(relief.get_format() == Image.FORMAT_RGB8, "Relief ist nicht RGB8."):
		return

	var hstats := _sheet_stats(height, 12)
	if not _check(float(hstats["spread"]) > 0.18, "Heightmap hat zu wenig Höhenspanne."):
		return
	var rstats := _sheet_stats(relief, 10)
	if not _check(int(rstats["colors"]) > 64 and float(rstats["spread"]) > 0.12,
			"Relief ist leer oder ohne Schattierung."):
		return
	var nstats := _sheet_stats(normal, 12)
	if not _check(int(nstats["colors"]) > 32 and float(nstats["spread"]) > 0.20,
			"Normalmap hat zu wenig Gradienten."):
		return
	for entry in [["marker_castle.png", castle], ["marker_banner.png", banner]]:
		var stats := _sheet_stats(entry[1], 4)
		if not _check(float(stats["coverage"]) > 0.06 and float(stats["coverage"]) < 0.80,
				"%s hat keine brauchbare Alpha-Deckung." % entry[0]):
			return
		if not _check(int(stats["colors"]) > 32 and float(stats["spread"]) > 0.10,
				"%s ist leer oder flach." % entry[0]):
			return

	for glb_name in ["marker_castle.glb", "marker_banner.glb"]:
		var glb_path := ProjectSettings.globalize_path(OUT + glb_name)
		if not _check(FileAccess.file_exists(glb_path), "GLB fehlt: " + glb_name):
			return
		var glb := FileAccess.open(glb_path, FileAccess.READ)
		if glb == null:
			_fail("GLB nicht lesbar: " + glb_name)
			return
		var magic := glb.get_buffer(4).get_string_from_ascii()
		var size := glb.get_length()
		glb.close()
		if not _check(magic == "glTF" and size > 4096, "GLB-Magic oder Größe falsch: " + glb_name):
			return

	var manifest_path := ProjectSettings.globalize_path(OUT + "manifest.json")
	if not _check(FileAccess.file_exists(manifest_path), "Manifest fehlt."):
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not _check(manifest is Dictionary, "Manifest ist kein JSON-Objekt."):
		return
	var entries: Array = manifest.get("assets", [])
	if not _check(entries.size() == 7, "Manifest listet %d statt 7 Assets." % entries.size()):
		return
	for entry in entries:
		var rel := str(entry.get("path", ""))
		if not _check(rel != "" and FileAccess.file_exists("res://" + rel), "Manifest-Asset fehlt: " + rel):
			return
	var provenance := FileAccess.get_file_as_string(ProjectSettings.globalize_path(OUT + "PROVENANCE.md"))
	if not _check(provenance.contains("keine CK3-Dateien"), "Herkunftsnachweis fehlt."):
		return

	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main._start(2)
	await get_tree().process_frame
	var view = _main.map_view
	if not _check(view != null, "Weltkarte wurde nicht erzeugt."):
		return
	var relief_tex: Texture2D = view._base.relief_texture()
	if not _check(relief_tex != null and relief_tex.resource_path == OUT + "relief_shaded.png",
			"MapBase verwendet nicht das generierte Relief."):
		return
	if not _check(view._base.relief_overlay() != null and view._base.relief_overlay().material is ShaderMaterial,
			"Das multiplikative Relief-Overlay fehlt."):
		return
	if not _check(view.marker_textures_loaded(), "3D-Markertexturen sind nicht geladen."):
		return
	var specs: Array = view.marker_specs()
	if not _check(specs.size() == 9, "Es sind %d statt 9 Halte-/Königreichssitze markiert." % specs.size()):
		return
	var imperial := 0
	for spec in specs:
		if bool(spec.get("imperial", false)):
			imperial += 1
	if not _check(imperial == 3, "Es sind %d statt 3 Reichssitze markiert." % imperial):
		return
	if not _check(view.marker_scale_for(0.8) < view.marker_scale_for(3.0),
			"Marker skalieren nicht mit dem Kartenzoom."):
		return
	if not _check(view.marker_scale_for(4.0) <= 1.2801, "Marker wachsen über die Zoomdeckelung hinaus."):
		return

	print("MAPASSETTEST OK: 7 Assets, 9 Halte-/Königreichsmarker, 3 Reichssitze, Relief im MapBase; %d Prüfungen." % _checks)
	get_tree().quit(0)
