extends TextureRect
## Eigene, einmal erzeugte Maserung. Keine heruntergeladenen Materialdateien.
## Der interne Hintergrund liegt vor dem Panelstil und hinter seinen Inhalten.
const GRAIN_SHADER = preload("res://shaders/wood_grain.gdshader")
static var shared_texture: ImageTexture

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_TILE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if shared_texture == null:
		shared_texture = _make_grain()
	texture = shared_texture
	var grain_material := ShaderMaterial.new()
	grain_material.shader = GRAIN_SHADER
	material = grain_material
	resized.connect(_update_bounds)

static func _make_grain() -> ImageTexture:
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	# Periodische Wellen schließen ohne sichtbare Nähte aneinander an.
	for y in 128:
		for x in 256:
			var u := float(x) / 256.0 * TAU
			var v := float(y) / 128.0 * TAU
			var flow := v * 14.0 + sin(u + sin(v) * 0.5) * 1.8 + sin(u * 3.0) * 0.24
			var grain := sin(flow) * 0.55 + sin(flow * 3.0 + sin(u * 2.0)) * 0.25
			grain += sin(flow * 11.0 + sin(u * 7.0)) * 0.12
			var ink := Color.WHITE if grain > 0 else Color.BLACK
			ink.a = absf(grain) * 0.23
			image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)

func configure(style: StyleBox) -> void:
	if style is StyleBoxFlat:
		modulate.a = style.bg_color.a
		material.set_shader_parameter("corner_radius", float(style.corner_radius_top_left))
	_update_bounds()

func _update_bounds() -> void:
	material.set_shader_parameter("panel_size", size.max(Vector2.ONE))
