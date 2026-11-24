extends Control
## One miniature viewport for the active map tool. Idle mode renders one frame.
const Modes = preload("res://scripts/MapModes.gd")
const SIZE := Vector2i(136, 136)
var _viewport: SubViewport
var _pivot: Node3D
var _image: TextureRect
var _model: Node3D
var _tween: Tween
var current_mode := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(49, 46)
	_image = TextureRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_image)
	if DisplayServer.get_name() != "headless":
		_setup_viewport()
	show_mode("political", false)

func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Miniaturenbuehne"
	_viewport.size = SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cedce8")
	environment.environment.ambient_light_energy = 0.62
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_color = Color("ffe3b3")
	light.light_energy = 1.1
	_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.62
	_viewport.add_child(camera)
	camera.position = Vector3(3.2, 3.7, 4.8)
	camera.look_at(Vector3(0, .79, 0))
	camera.make_current()
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	visibility_changed.connect(_sync_render)

func show_mode(mode: String, animated: bool) -> void:
	if _image == null or mode == current_mode:
		return
	current_mode = Modes.canonical(mode)
	if _tween != null:
		_tween.kill()
		_tween = null
	if _viewport == null:
		_image.texture = Modes.MINIATURES[current_mode]
		return
	if _model != null:
		_model.hide()
		_model.queue_free()
	var scene := load("res://assets/map/living/%s.glb" % current_mode) as PackedScene
	if scene == null:
		_image.texture = Modes.MINIATURES[current_mode]
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_model = scene.instantiate() as Node3D
	_pivot.add_child(_model)
	_image.texture = _viewport.get_texture()
	_pivot.rotation.y = -0.67 if animated else 0.0
	if animated and is_visible_in_tree():
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_pivot, "rotation:y", 0.0, 0.34)
		_tween.finished.connect(stop_motion)
	_sync_render()

func stop_motion() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _pivot != null:
		_pivot.rotation.y = 0.0
	_sync_render()

func _sync_render() -> void:
	if _viewport == null:
		return
	if not is_visible_in_tree() or _model == null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif _tween != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
