extends Control
## Ladebildschirm: zeigt Titelart, Wortmarke, Fortschritt und Tipps, während
## die Hauptszene in einem Thread geladen wird. Wechselt danach mit Fade.

const TEX_BG = preload("res://assets/ui/title_bg.png")
const TEX_LOGO = preload("res://assets/ui/logo_title.png")
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
var packed: PackedScene

func _ready() -> void:
	_build()
	ResourceLoader.load_threaded_request(MAIN_PATH, "PackedScene")
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.7)

func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 13)
	center.add_child(box)

	var logo := TextureRect.new()
	logo.texture = TEX_LOGO
	logo.custom_minimum_size = Vector2(0, 330)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(logo)

	status = _label("Die Reiche Europas werden geschmiedet …", 20, Color(0.96, 0.90, 0.77))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var wrap := CenterContainer.new()
	box.add_child(wrap)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(560, 16)
	bar.max_value = 100.0
	bar.value = 0.0
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

	percent = _label("0 %", 13, Color(0.82, 0.69, 0.46))
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(percent)

	tip = _label("TIPP · " + TIPS[0], 13, Color(0.74, 0.64, 0.48))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(640, 38)
	box.add_child(tip)

	var version := _label("v1.2 · Kronen und Kriege", 12, Color(0.64, 0.54, 0.38))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 24
	version.offset_top = -30
	version.offset_right = 360
	version.offset_bottom = -10
	add_child(version)
	var hint := _label("Bronzezeit · Grand Strategy", 12, Color(0.64, 0.54, 0.38))
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
	tip_timer += delta
	if tip_timer > 3.4:
		tip_timer = 0.0
		tip_index = (tip_index + 1) % TIPS.size()
		tip.text = "TIPP · " + TIPS[tip_index]

	var progress: Array = []
	var state: int = ResourceLoader.load_threaded_get_status(MAIN_PATH, progress)
	var real: float = 0.0
	if progress.size() > 0:
		real = float(progress[0]) * 100.0
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(MAIN_PATH) as PackedScene
		real = 100.0

	var fake: float = 88.0 * clampf(elapsed / 1.9, 0.0, 1.0)
	var target: float = maxf(real, fake)
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		target = 100.0
	shown = lerpf(shown, target, 1.0 - pow(0.002, delta))
	if target - shown < 0.6:
		shown = target
	bar.value = shown
	percent.text = "%d %%" % int(round(shown))

	if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		status.text = "Laden fehlgeschlagen. Bitte das Spiel neu starten."
		return
	if state == ResourceLoader.THREAD_LOAD_LOADED and elapsed >= 2.4 and shown >= 96.0:
		_finish()

func _finish() -> void:
	if done:
		return
	done = true
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		if packed != null:
			get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(MAIN_PATH)
	)
