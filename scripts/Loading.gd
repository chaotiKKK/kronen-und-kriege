extends Control
## Ladebildschirm: zeigt das Banger-Queens-Titelbild, Fortschritt und Tipps,
## während die Hauptszene geladen wird. Wechselt danach mit Fade.

const TEX_TITLE = preload("res://assets/ui/bq_beta_title.jpg")
const TEX_INTRO = preload("res://assets/ui/chaotiKKK_logo.png")
const INTRO_SECONDS := 3.0
const MAIN_PATH := "res://scenes/Main.tscn"
const TIPS := [
	"Ein Erbe sichert das Fortbestehen deines Hauses.",
	"Prestige öffnet Türen an fremden Höfen.",
	"Gold baut Land aus — Truppen erobern es.",
	"Tippe auf eine Grafschaft, um ihre Nachbarn zu prüfen.",
	"Heirat verbindet zwei Häuser und ihre Ansprüche.",
]

var bar: ProgressBar
var status: Label
var tip: Label
var percent: Label
var elapsed: float = 0.0
var shown: float = 0.0
var tip_timer: float = 0.0
var tip_index: int = 0
var done: bool = false
var load_failed: bool = false
var loaded_ok: bool = false
var main_scene: PackedScene
var intro_layer: ColorRect
var intro_image: TextureRect
var intro_elapsed := 0.0
var load_started := false
var awaiting_loading_frame := false
var loading_frame_presented := false

func _ready() -> void:
	_build()
	_build_intro()
	# Main is deliberately not read here: the first screen gets three seconds
	# before even a synchronous resource load can block rendering.
	modulate.a = 1.0

func _build_intro() -> void:
	intro_layer = ColorRect.new()
	intro_layer.name = "chaotiKKKIntro"
	intro_layer.color = Color.BLACK
	intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_layer)
	intro_image = TextureRect.new()
	intro_image.texture = TEX_INTRO
	intro_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	intro_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(intro_image)

func _on_loading_frame_presented() -> void:
	if not awaiting_loading_frame or intro_layer.visible:
		return
	awaiting_loading_frame = false
	loading_frame_presented = true
	# frame_post_draw has completed the first normal loading/title frame.
	# Defer the synchronous reader so it cannot prolong the logo's last frame.
	call_deferred("_load_main")

func _load_main() -> void:
	if load_started or not loading_frame_presented or intro_layer.visible:
		return
	load_started = true
	main_scene = _read_main_scene()
	loaded_ok = main_scene != null
	if not loaded_ok:
		load_failed = true
		status.text = "Laden fehlgeschlagen. Bitte das Spiel neu starten."

func _read_main_scene() -> PackedScene:
	return load(MAIN_PATH) as PackedScene

func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_TITLE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.34)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Das Titelbild enthält die Wortmarke bereits. Der Ladebereich sitzt deshalb
	# ohne zweites Logo unten und lässt Bild und Wortmarke sichtbar.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_left = 24
	center.offset_top = -224
	center.offset_right = -24
	center.offset_bottom = -28
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 13)
	center.add_child(box)

	status = _label("Die Reiche Europas werden geschmiedet …", 20, Color(0.96, 0.90, 0.77))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var wrap := CenterContainer.new()
	box.add_child(wrap)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(560, 16)
	bar.max_value = 100.0
	bar.value = 0.0
	bar.visible = false
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.035, 0.02, 0.94)
	track.border_width_left = 1
	track.border_width_top = 1
	track.border_width_right = 1
	track.border_width_bottom = 1
	track.border_color = Color(0.50, 0.38, 0.18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.64, 0.30)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	wrap.add_child(bar)

	percent = _label("Hauptszene wird geladen · 0 s", 13, Color(0.82, 0.69, 0.46))
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(percent)

	tip = _label("TIPP · " + TIPS[0], 13, Color(0.74, 0.64, 0.48))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(640, 38)
	box.add_child(tip)

	var version := _label("Banger Queens · 2000 v. Chr. – 2200 n. Chr.", 12, Color(0.64, 0.54, 0.38))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 24
	version.offset_top = -30
	version.offset_right = 360
	version.offset_bottom = -10
	add_child(version)
	var hint := _label("Eine Geschichte. Dein Vermächtnis.", 12, Color(0.64, 0.54, 0.38))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -300
	hint.offset_top = -30
	hint.offset_right = -24
	hint.offset_bottom = -10
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)

func _process(delta: float) -> void:
	if done:
		return
	elapsed += delta
	if intro_layer.visible:
		intro_elapsed += delta
		if intro_elapsed >= INTRO_SECONDS:
			intro_layer.hide()
			percent.text = "Hauptszene wird geladen · %d s" % int(elapsed)
			awaiting_loading_frame = true
			RenderingServer.frame_post_draw.connect(_on_loading_frame_presented, CONNECT_ONE_SHOT)
		return
	tip_timer += delta
	if tip_timer > 3.4:
		tip_timer = 0.0
		tip_index = (tip_index + 1) % TIPS.size()
		tip.text = "TIPP · " + TIPS[tip_index]

	if load_failed:
		return

	# Der synchrone Loader liefert keine Zwischenwerte. Nur Status und Laufzeit.
	bar.visible = loaded_ok
	bar.value = 100.0 if loaded_ok else 0.0
	percent.text = "%s · %d s" % ["Hauptszene geladen" if loaded_ok else "Hauptszene wird geladen", int(elapsed)]

	if loaded_ok and elapsed >= 2.4:
		_finish()

func _finish() -> void:
	if done or not loaded_ok or main_scene == null:
		return
	done = true
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		get_tree().change_scene_to_packed(main_scene)
	)
