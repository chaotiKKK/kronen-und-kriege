extends Node2D
## Grenzpfade bleiben bei kleinen Schwenks im lokalen Kartenraum erhalten.
const MAP_RECT := Rect2(Vector2.ZERO, Vector2(1200, 760))
const MIN_PATH_SCREEN_EXTENT := 0.75
const PATH_BOUNDS_PADDING := 0.001
var _atlas
var _cache_rect := Rect2()
var _zoom := -1.0
var _line_scale := -1.0
var _lines: Array = []

func update_view(atlas, visible_rect: Rect2, zoom: float, map_scale: float, offset: Vector2) -> void:
	position = offset
	scale = Vector2.ONE * map_scale
	if atlas == _atlas and is_equal_approx(zoom, _zoom) and is_equal_approx(map_scale, _line_scale) and _cache_rect.encloses(visible_rect):
		return
	_atlas = atlas
	_zoom = zoom
	_line_scale = map_scale
	# Ein kleiner Vorlauf verhindert neue Draw-Kommandos bei jedem Pan-Pixel.
	var margin := maxf(visible_rect.size.x, visible_rect.size.y) * 0.20
	_cache_rect = visible_rect.grow(margin).intersection(MAP_RECT)
	_build_lines(atlas.visible_features(_cache_rect, zoom))
	queue_redraw()

func clip_line_to_rect(points: PackedVector2Array, rect: Rect2) -> Array:
	if points.size() < 2 or not rect.has_area():
		return []
	var polygon := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	return Geometry2D.intersect_polyline_with_polygon(points, polygon)

func _build_lines(features: Array) -> void:
	_lines.clear()
	for feature in features:
		var kind := str(feature.kind)
		if kind in ["municipality", "local_admin"] and float(feature.bounds.get_area()) * _line_scale * _line_scale < 256.0:
			continue
		for path_index in feature.paths.size():
			var reference: Array = feature.paths[path_index]
			var metadata_bounds: Variant = _path_metadata_bounds(feature, path_index)
			# Inseln bleiben binär erhalten; kleine/entfernte Komponenten werden
			# bei vorhandener Einzel-BBox bereits vor Float32-Decoding ausgelassen.
			if metadata_bounds is Rect2 and not _path_relevant(metadata_bounds):
				continue
			var points: PackedVector2Array = _atlas.path(reference)
			if points.size() < 2:
				continue
			var bounds: Rect2 = metadata_bounds if metadata_bounds is Rect2 else _decoded_bounds(points)
			if not _path_relevant(bounds):
				continue
			if _cache_rect.encloses(bounds.grow(PATH_BOUNDS_PADDING)):
				_lines.append({"kind": kind, "points": points})
			else:
				# Nur Linien schneiden; niemals künstliche Flächenkanten zeichnen.
				for part in clip_line_to_rect(points, _cache_rect):
					if part.size() >= 2:
						_lines.append({"kind": kind, "points": part})

func _path_metadata_bounds(feature: Dictionary, index: int) -> Variant:
	var values: Variant = feature.get("path_bounds")
	if not (values is Array) or index >= values.size():
		return null
	var raw: Variant = values[index]
	if not (raw is Array) or raw.size() != 4:
		return null
	for value in raw:
		if not (value is int or value is float) or not is_finite(float(value)):
			return null
	if float(raw[2]) < 0.0 or float(raw[3]) < 0.0:
		return null
	return Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))

func _decoded_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

func _path_relevant(bounds: Rect2) -> bool:
	return maxf(bounds.size.x, bounds.size.y) * _line_scale >= MIN_PATH_SCREEN_EXTENT and bounds.grow(PATH_BOUNDS_PADDING).intersects(_cache_rect, true)

func _draw() -> void:
	if _atlas == null or _line_scale <= 0.0:
		return
	for line in _lines:
		var kind := str(line.kind)
		var width := 0.85
		var color := Color(0.17, 0.20, 0.15, 0.45)
		if kind == "country":
			width = 1.2
			color = Color(0.14, 0.17, 0.13, 0.55)
		elif kind == "district":
			width = 0.8
			color = Color(0.14, 0.17, 0.13, 0.50)
		elif kind in ["municipality", "local_admin"]:
			width = 0.6
			color = Color(0.20, 0.23, 0.18, 0.25)
		draw_polyline(line.points, color, width / _line_scale, true)
