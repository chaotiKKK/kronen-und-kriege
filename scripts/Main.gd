extends Control
## Baut die Bronzezeit-Oberfläche: Startmenü, Herrscher-/Land-Erstellung, Karte,
## Hofpanel mit Familie und Intrigen, Ereignisse, Spielende.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const MapViewScript = preload("res://scripts/MapView.gd")
const WorldMiniMapScript = preload("res://scripts/WorldMiniMap.gd")
const FamilyTreeScript = preload("res://scripts/FamilyTree.gd")
const BannerGeneratorScript = preload("res://scripts/BannerGenerator.gd")
const UiKernelScript = preload("res://scripts/UiKernel.gd")
const ViewModelBuilder = preload("res://scripts/ViewModelBuilder.gd")
const AcceptanceDriverScript = preload("res://scripts/AcceptanceDriver.gd")
const ModernInterfaceScript = preload("res://scripts/ModernInterface.gd")

const TEX_CARD = preload("res://assets/ui/card.png")
const TEX_BUTTON = preload("res://assets/ui/button.png")
const TEX_TITLE = preload("res://assets/ui/bq_beta_title.jpg")
const TEX_COURT = preload("res://assets/ui/court/court_hall.png")
const TEX_FAITH = preload("res://assets/ui/faith/faith_temple.png")

const SETTINGS_PATH := "user://einstellungen.cfg"
const RESOLUTIONS := [[1280, 720], [1600, 900], [1920, 1080]]
const EventArtFallbackScript := preload("res://scripts/EventArtFallback.gd")
const EVENT_ART_KEYS := {
	"hoftag": "event_court_reception",
	"hochzeit": "event_wedding",
	"kloster": "event_monastery",
	"zehnt": "event_tithe",
	"ernte": "event_harvest",
	"haendler": "event_merchant",
	"grenzstreit": "event_battle",
	"krankheit": "event_fever",
}

const INK := Color("edf3f5")
const INK_SOFT := Color("afbfca")
const CREAM := Color("edf3f5")

var game
var kernel
var map_view
var map_mode_buttons: Dictionary = {}
var top_crest: TextureRect
var top_realm_label: Label
var top_world_label: Label
var map_header_title: Label
var map_header_meta: Label
var side_panel: PanelContainer
var side_toggle_btn: Button
var legend_button: Button
var minimap
var _side_hidden := false
var date_label: Label
var gold_label: Label
var prestige_label: Label
var renown_label: Label
var crest_rect: TextureRect
var portrait_rect: TextureRect
var title_label: Label
var info_label: Label
var family_label: Label
var hint_label: Label
var log_label: Label
var develop_btn: Button
var recruit_btn: Button
var attack_btn: Button
var court_btn: Button
var marry_btn: Button
var bed_btn: Button
var seduce_btn: Button
var murder_btn: Button
var kidnap_btn: Button
var ransom_btn: Button
var force_btn: Button
var speed_buttons: Array = []
var event_layer: Control
var event_art: TextureRect
var event_art_fallback: Control
var event_title: Label
var event_text: Label
var event_buttons: VBoxContainer
var over_layer: Control
var start_layer: Control
var newgame_layer: Control
var title_status: Label
var start_box: VBoxContainer
var create_layer: Control
var edit_ruler: LineEdit
var edit_house: LineEdit
var edit_land: LineEdit
var create_sex: OptionButton
var create_home: OptionButton
var points_label: Label
var pick_layer: Control
var pick_title: Label
var pick_box: VBoxContainer
var pick_kind: String = ""
var tree_layer: Control
var tree_view
var tree_title: Label
var tree_list: VBoxContainer
var rule_layer: Control
var rule_title: Label
var rule_body: VBoxContainer
var research_label: Label
var infrastructure_layer: Control
var infrastructure_body: VBoxContainer
var research_buttons: Dictionary = {}
var road_buttons: VBoxContainer
var sandbox_button: Button
var court_layer: Control
var court_title: Label
var court_body: VBoxContainer
var court_hall_preview: TextureRect
var court_hall_stage_label: Label
var court_hall_stats_label: Label
var court_hall_pips: HBoxContainer
var court_expectation_label: Label
var court_expectation_track: Control
var court_amenity_pips: Array = []
var court_amenity_buttons: Dictionary = {}
var faith_layer: Control
var faith_title: Label
var faith_body: VBoxContainer
var faith_heresy_icon: TextureRect
var faith_reform_icon: TextureRect
var faith_war_marker: PanelContainer
var faith_war_marker_icon: TextureRect
var faith_war_marker_label: Label
var custom_layer: Control
var custom_name: LineEdit
var custom_house: LineEdit
var custom_gender: OptionButton
var custom_age: SpinBox
var custom_portrait_preview: TextureRect
var custom_crest_preview: TextureRect
var custom_color_swatch: ColorRect
var custom_status: Label
var custom_stat_labels: Dictionary = {}
var custom_portrait_buttons: Array = []
var custom_crest_buttons: Array = []
var custom_portrait_group: ButtonGroup
var custom_crest_group: ButtonGroup
var custom_snapshot: Dictionary = {}
var custom_prev_speed: int = 0
var banner_generator
var banner_prev_speed: int = 0
var ambient_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var open_player: AudioStreamPlayer
var sound_btn: Button
var sound_on := true
var selected: String = ""
var settings := {
	"window_mode": 0,
	"resolution": 1,
	"vsync": 1,
	"ui_scale": 1.0,
	"ui_theme": ModernInterfaceScript.DEFAULT_APPEARANCE,
	"text_scale": 1.0,
	"music": 55,
	"sfx": 75,
	"muted": false,
	"autosave": true,
	"pause_events": true,
	"start_speed": 0,
}
var TOKENS: Dictionary = {}
var EVENT_ARTS: Dictionary = {}
var options_layer: Control
var options_tab_buttons: Dictionary = {}
var options_sections: Dictionary = {}
var options_status: Label
var opt_window_mode: OptionButton
var opt_resolution: OptionButton
var opt_vsync: OptionButton
var opt_ui_scale: HSlider
var opt_ui_scale_label: Label
var opt_theme: OptionButton
var opt_text_scale: OptionButton
var opt_music: HSlider
var opt_music_label: Label
var opt_sfx: HSlider
var opt_sfx_label: Label
var opt_muted: CheckButton
var opt_autosave: CheckButton
var opt_pause_events: CheckButton
var opt_start_speed: OptionButton
var opt_save_btn: Button
var opt_save_quit_btn: Button
var province_layer: Control
var province_title: Label
var province_art: TextureRect
var province_crest: TextureRect
var province_portrait: TextureRect
var province_info: VBoxContainer
var province_owner_name: Label
var province_buildings: HBoxContainer
var province_troops: HBoxContainer
var province_neighbors: Label
var province_action_buttons: Dictionary = {}
var province_side_panel: VBoxContainer
var province_side_icon: TextureRect
var province_side_crest: TextureRect
var province_side_title: Label
var province_side_meta: Label
var quit_layer: Control
var quit_status: Label
var _cli_resolution_locked := false
var accum: float = 0.0
var stat_values := {"martial": 6, "diplomacy": 6, "stewardship": 6, "intrigue": 6}
var stat_labels := {}
var stat_points: int = 20
var CRESTS: Array = []
var PORTRAITS: Array = []
var ICONS: Dictionary = {}

func _ready() -> void:
	kernel = UiKernelScript.new()
	kernel.save_handler = Callable(self, "_save")
	kernel.load_handler = Callable(self, "_load")
	_load_assets()
	_setup_audio_buses()
	_load_settings()
	ModernInterfaceScript.appearance = int(settings["ui_theme"])
	ModernInterfaceScript.text_scale = float(settings["text_scale"])
	_apply_display_settings(false)
	# Headless-Tests brauchen keinen Audio-Stream; die Wiedergabe kann beim
	# harten Test-Quit eine Ressource offen halten.
	if DisplayServer.get_name() != "headless":
		_load_audio()
	_build()
	var modern = ModernInterfaceScript.new()
	modern.install(self)
	_show_start()
	_apply_audio_settings()
	var args := OS.get_cmdline_user_args()
	if args.has("--acceptance"):
		var driver = AcceptanceDriverScript.new()
		add_child(driver)
		driver.begin(self, args)
	print("MAIN_READY version=%s" % ProjectSettings.get_setting("application/config/version"))

func _stop_audio() -> void:
	# Die laufende Ambient-Wiedergabe kann beim Engine-Shutdown eine Ressource
	# offen halten; vor dem Quit sauber stoppen und loesen.
	if ambient_player != null:
		ambient_player.stop()
		ambient_player.stream = null
	if click_player != null:
		click_player.stop()
		click_player.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Der Fenster-Schließen-Knopf ist der harte Windows-Ausgang: laufende
		# Partie automatisch sichern, damit ein versehentliches Schließen nicht
		# den Fortschritt verliert. Die Menüs bieten zusätzlich die bewusste Wahl.
		if game != null:
			_write_save()
		_save_settings()
		_stop_audio()
		get_tree().quit()

func _exit_tree() -> void:
	_stop_audio()

func _load_audio() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Musik"
	ambient_player.volume_db = -10.0
	var amb = load("res://assets/audio/ambient.wav")
	if amb != null:
		ambient_player.stream = amb
		if amb is AudioStreamWAV:
			amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
			amb.loop_begin = 0
			amb.loop_end = int(amb.get_length() * float(amb.mix_rate))
		add_child(ambient_player)
		ambient_player.play()
	click_player = AudioStreamPlayer.new()
	click_player.bus = "Effekte"
	click_player.volume_db = -3.0
	var clk = load("res://assets/audio/click.wav")
	if clk != null:
		click_player.stream = clk
		add_child(click_player)
	open_player = AudioStreamPlayer.new()
	open_player.bus = "Effekte"
	open_player.volume_db = -5.0
	var opn = load("res://assets/audio/open.wav")
	if opn != null:
		open_player.stream = opn
		add_child(open_player)

func _setup_audio_buses() -> void:
	for bus_name in ["Musik", "Effekte"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func _apply_audio_settings() -> void:
	sound_on = not bool(settings.get("muted", false))
	if ambient_player != null:
		ambient_player.stream_paused = not sound_on
	var music_idx: int = AudioServer.get_bus_index("Musik")
	var sfx_idx: int = AudioServer.get_bus_index("Effekte")
	var music_linear: float = clampf(float(settings.get("music", 55)) / 100.0, 0.0, 1.0)
	var sfx_linear: float = clampf(float(settings.get("sfx", 75)) / 100.0, 0.0, 1.0)
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(music_linear, 0.001)))
		AudioServer.set_bus_mute(music_idx, not sound_on or music_linear <= 0.001)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_linear, 0.001)))
		AudioServer.set_bus_mute(sfx_idx, not sound_on or sfx_linear <= 0.001)
	AudioServer.set_bus_mute(0, not sound_on)
	if sound_btn != null:
		sound_btn.text = "Ton an" if sound_on else "Ton aus"
	if opt_music_label != null:
		opt_music_label.text = "%d %%" % int(settings["music"])
	if opt_sfx_label != null:
		opt_sfx_label.text = "%d %%" % int(settings["sfx"])

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	settings["window_mode"] = clampi(int(cf.get_value("bild", "fenstermodus", 0)), 0, 1)
	settings["resolution"] = clampi(int(cf.get_value("bild", "aufloesung", 1)), 0, RESOLUTIONS.size() - 1)
	settings["vsync"] = clampi(int(cf.get_value("bild", "vsync", 1)), 0, 2)
	settings["ui_scale"] = clampf(float(cf.get_value("bild", "ui_scale", 1.0)), 0.8, 1.2)
	settings["ui_theme"] = clampi(int(cf.get_value("bild", "ui_theme", ModernInterfaceScript.DEFAULT_APPEARANCE)), 0, ModernInterfaceScript.THEME_NAMES.size() - 1)
	settings["text_scale"] = clampf(float(cf.get_value("bild", "text_scale", 1.0)), 1.0, 2.0)
	settings["music"] = clampi(int(cf.get_value("ton", "musik", 55)), 0, 100)
	settings["sfx"] = clampi(int(cf.get_value("ton", "effekte", 75)), 0, 100)
	settings["muted"] = bool(cf.get_value("ton", "stumm", false))
	settings["autosave"] = bool(cf.get_value("spiel", "autosave", true))
	settings["pause_events"] = bool(cf.get_value("spiel", "ereignisse_pausieren", true))
	settings["start_speed"] = clampi(int(cf.get_value("spiel", "starttempo", 0)), 0, 3)

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("bild", "fenstermodus", int(settings["window_mode"]))
	cf.set_value("bild", "aufloesung", int(settings["resolution"]))
	cf.set_value("bild", "vsync", int(settings["vsync"]))
	cf.set_value("bild", "ui_scale", float(settings["ui_scale"]))
	cf.set_value("bild", "ui_theme", int(settings["ui_theme"]))
	cf.set_value("bild", "text_scale", float(settings["text_scale"]))
	cf.set_value("ton", "musik", int(settings["music"]))
	cf.set_value("ton", "effekte", int(settings["sfx"]))
	cf.set_value("ton", "stumm", bool(settings["muted"]))
	cf.set_value("spiel", "autosave", bool(settings["autosave"]))
	cf.set_value("spiel", "ereignisse_pausieren", bool(settings["pause_events"]))
	cf.set_value("spiel", "starttempo", int(settings["start_speed"]))
	cf.save(SETTINGS_PATH)

func _apply_display_settings(force: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Ein per CLI vorgegebenes Testfenster nicht durch gespeicherte Werte
	# überschreiben; eine bewusste Änderung im Optionsmenü (force) gewinnt.
	if not force and OS.get_cmdline_args().has("--resolution"):
		_cli_resolution_locked = true
	if not force and _cli_resolution_locked:
		return
	var win := get_window()
	if int(settings["window_mode"]) == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Array = RESOLUTIONS[clampi(int(settings["resolution"]), 0, RESOLUTIONS.size() - 1)]
		DisplayServer.window_set_size(Vector2i(int(res[0]), int(res[1])))
	match int(settings["vsync"]):
		0:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		2:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	win.content_scale_factor = clampf(float(settings["ui_scale"]), 0.8, 1.2)

func _play_click() -> void:
	if click_player != null:
		click_player.play()

func _play_open() -> void:
	if open_player != null:
		open_player.play()

func _toggle_sound() -> void:
	settings["muted"] = not bool(settings.get("muted", false))
	_apply_audio_settings()
	_save_settings()
	if opt_muted != null:
		opt_muted.set_pressed_no_signal(not bool(settings["muted"]))

func _load_assets() -> void:
	for i in 9:
		var t = load("res://assets/crests/crest_%d.png" % i)
		if t != null:
			CRESTS.append(t)
	PORTRAITS.clear()
	for i in 48:
		var t2 = load("res://assets/portraits_hd/portrait_%02d.png" % (i + 1))
		if t2 == null:
			t2 = load("res://assets/portraits/portrait_%d.png" % i)
		PORTRAITS.append(t2)
	for n in ["gold", "prestige", "sword", "heart", "ring", "mask", "dagger", "chain", "crown", "scroll"]:
		var t3 = load("res://assets/icons/icon_%s.png" % n)
		if t3 != null:
			ICONS[n] = t3
	TOKENS.clear()
	for n in ["terrain_plains", "terrain_farmland", "terrain_forest", "terrain_hills", "terrain_mountains", "terrain_marsh", "terrain_coast", "terrain_steppe", "terrain_heath", "building_barracks", "building_walls", "building_market", "unit_levy", "unit_archer", "unit_knight", "unit_siege", "unit_fleet", "legacy_war", "legacy_crown", "legacy_guile", "council_marshal", "council_chancellor", "council_steward", "council_spymaster", "contract_0", "contract_1", "contract_2", "relic_crown", "relic_blade", "relic_seal", "faith_sun", "faith_moon", "faith_earth"]:
		var tex = load("res://assets/ui/tokens/%s.png" % n)
		if tex != null:
			TOKENS[n] = tex
	for key in GameScript.FAITH_TOKEN_ORDER:
		var token_name := "faith_%s" % str(key)
		var token_tex = load("res://assets/ui/tokens/%s.png" % token_name)
		if token_tex != null:
			TOKENS[token_name] = token_tex
	EVENT_ARTS.clear()
	for n in EVENT_ART_KEYS.values():
		var tex = load("res://assets/ui/events/%s.png" % n)
		if tex != null:
			EVENT_ARTS[n] = tex

# --- Stile ---------------------------------------------------------------

func _card_style(cm: int = 18) -> StyleBoxFlat:
	return ModernInterfaceScript.surface(ModernInterfaceScript.PANEL, cm)

func _btn_style(bright: float) -> StyleBoxFlat:
	return ModernInterfaceScript.surface(Color(0.11, 0.21, 0.27).lightened(maxf(0, bright - 1.0) * 0.4), 12)

func _flat(bg: Color, line := Color(0, 0, 0, 0), width: int = 0, preserve_color: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if not preserve_color and bg.r > bg.b * 1.3 and bg.g < 0.3:
		bg = Color(0.075, 0.14, 0.19, bg.a)
	sb.set_meta("atlas_bg", bg)
	sb.set_meta("atlas_fixed_color", preserve_color)
	sb.bg_color = bg if preserve_color else ModernInterfaceScript._surface_color(bg)
	if width > 0:
		sb.border_width_left = width
		sb.border_width_right = width
		sb.border_width_top = width
		sb.border_width_bottom = width
		sb.border_color = line
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _field_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_meta("atlas_bg", Color("101e2b"))
	sb.bg_color = ModernInterfaceScript._surface_color(Color("101e2b"))
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.32, 0.17)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _label(text: String, px: int, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.set_meta("atlas_color", col)
	l.set_meta("atlas_font_size", px)
	l.add_theme_font_size_override("font_size", int(round(px * ModernInterfaceScript.text_scale)))
	l.add_theme_color_override("font_color", ModernInterfaceScript.readable(col))
	return l

func _button(text: String, cb: Callable, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", ModernInterfaceScript.readable(CREAM))
	b.add_theme_color_override("font_hover_color", ModernInterfaceScript.readable(Color.WHITE))
	b.add_theme_color_override("font_pressed_color", ModernInterfaceScript.readable(CREAM))
	b.add_theme_color_override("font_disabled_color", ModernInterfaceScript.disabled_text())
	b.add_theme_stylebox_override("normal", _btn_style(1.0))
	b.add_theme_stylebox_override("hover", _btn_style(1.18))
	b.add_theme_stylebox_override("pressed", _btn_style(0.82))
	b.add_theme_stylebox_override("disabled", _btn_style(0.55))
	b.add_theme_stylebox_override("focus", ModernInterfaceScript.focus_surface())
	if icon_name != "" and ICONS.has(icon_name):
		b.icon = ICONS[icon_name]
		b.add_theme_constant_override("icon_max_width", 22)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	return b

func _title_button(text: String, cb: Callable, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.97, 0.91, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.84, 0.77, 0.62))
	b.add_theme_stylebox_override("normal", _flat(Color(0.07, 0.05, 0.03, 0.82), Color(0.56, 0.42, 0.20), 1))
	b.add_theme_stylebox_override("hover", _flat(Color(0.18, 0.12, 0.06, 0.94), Color(0.90, 0.70, 0.34), 2))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.04, 0.03, 0.02, 0.96), Color(0.90, 0.70, 0.34), 2))
	b.add_theme_stylebox_override("focus", _flat(Color(0.10, 0.07, 0.04, 0.90), Color(0.72, 0.56, 0.28), 1))
	if icon_name != "" and ICONS.has(icon_name):
		b.icon = ICONS[icon_name]
		b.add_theme_constant_override("icon_max_width", 24)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	return b

func _map_tool(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(48, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.07, 0.05, 0.88), Color(0.66, 0.50, 0.25), 1))
	b.add_theme_stylebox_override("hover", _flat(Color(0.20, 0.14, 0.08, 0.95), Color(0.86, 0.68, 0.34), 1))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.06, 0.04, 0.03, 0.95), Color(0.86, 0.68, 0.34), 1))
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	return b

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

# --- Aufbau --------------------------------------------------------------

func _build() -> void:
	var back := ColorRect.new()
	back.set_meta("atlas_background", true)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.07, 0.06, 0.05)
	add_child(back)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Kopfzeile: Haus, Zeit, Ressourcen und Zeitsteuerung wie eine Weltkarten-Leiste.
	var top := PanelContainer.new()
	top.custom_minimum_size = Vector2(0, 64)
	top.add_theme_stylebox_override("panel", _flat(Color(0.075, 0.055, 0.035), Color(0.62, 0.46, 0.22), 2))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 9)
	top.add_child(top_row)
	var realm_block := HBoxContainer.new()
	realm_block.add_theme_constant_override("separation", 8)
	top_row.add_child(realm_block)
	top_crest = TextureRect.new()
	top_crest.custom_minimum_size = Vector2(38, 46)
	top_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	realm_block.add_child(top_crest)
	var realm_text := VBoxContainer.new()
	realm_text.add_theme_constant_override("separation", 0)
	realm_block.add_child(realm_text)
	top_world_label = _label("WELTKARTE · 2000 V. CHR.", 9, Color(0.92, 0.72, 0.35))
	realm_text.add_child(top_world_label)
	top_realm_label = _label("Haus Wessex", 17, CREAM)
	realm_text.add_child(top_realm_label)
	var date_box := PanelContainer.new()
	date_box.add_theme_stylebox_override("panel", _flat(Color(0.11, 0.08, 0.05, 0.92), Color(0.42, 0.31, 0.16), 1))
	top_row.add_child(date_box)
	date_label = _label("Hartung 2000 v. Chr.", 16, Color(0.98, 0.86, 0.56))
	date_box.add_child(date_label)
	top_row.add_child(_spacer())
	var res_box := HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 13)
	top_row.add_child(res_box)
	gold_label = _label("Gold: 0", 15, Color(0.98, 0.82, 0.38))
	res_box.add_child(gold_label)
	prestige_label = _label("Prestige: 0", 15, Color(0.78, 0.88, 1.0))
	res_box.add_child(prestige_label)
	renown_label = _label("Ruhm: 0", 15, Color(0.95, 0.74, 0.44))
	res_box.add_child(renown_label)
	top_row.add_child(_spacer())
	sound_btn = Button.new()
	sound_btn.text = "Ton an"
	sound_btn.custom_minimum_size = Vector2(60, 34)
	sound_btn.add_theme_font_size_override("font_size", 11)
	sound_btn.add_theme_color_override("font_color", CREAM)
	sound_btn.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.07, 0.05, 0.8), Color(0.50, 0.38, 0.18), 1))
	sound_btn.add_theme_stylebox_override("hover", _flat(Color(0.20, 0.14, 0.08, 0.95), Color(0.86, 0.68, 0.34), 1))
	sound_btn.pressed.connect(_toggle_sound)
	top_row.add_child(sound_btn)
	var options_btn := Button.new()
	options_btn.text = "Optionen"
	options_btn.custom_minimum_size = Vector2(72, 34)
	options_btn.add_theme_font_size_override("font_size", 11)
	options_btn.add_theme_color_override("font_color", CREAM)
	options_btn.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.07, 0.05, 0.8), Color(0.50, 0.38, 0.18), 1))
	options_btn.add_theme_stylebox_override("hover", _flat(Color(0.20, 0.14, 0.08, 0.95), Color(0.86, 0.68, 0.34), 1))
	options_btn.pressed.connect(_show_options)
	options_btn.pressed.connect(_play_click)
	top_row.add_child(options_btn)
	for i in 4:
		var names := ["Pause", "x1", "x2", "x3"]
		var b := Button.new()
		b.text = names[i]
		b.custom_minimum_size = Vector2(44, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", CREAM)
		b.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.07, 0.05, 0.8), Color(0.46, 0.35, 0.18), 1))
		b.add_theme_stylebox_override("hover", _flat(Color(0.20, 0.14, 0.08, 0.95), Color(0.86, 0.68, 0.34), 1))
		b.add_theme_stylebox_override("pressed", _flat(Color(0.28, 0.20, 0.10, 0.98), Color(0.96, 0.78, 0.38), 2))
		b.pressed.connect(_set_speed.bind(i))
		speed_buttons.append(b)
		top_row.add_child(b)

	# Inhalt: Die Karte ist die Hauptfläche; der Hof liegt als Seitenpanel daneben.
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var map_wrap := Control.new()
	map_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_wrap.custom_minimum_size = Vector2(420, 320)
	left.add_child(map_wrap)
	map_view = MapViewScript.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.province_selected.connect(_on_province_selected)
	map_view.province_activated.connect(_on_province_activated)
	map_view.map_mode_changed.connect(_on_map_mode_changed)
	map_view.atlas_location_selected.connect(_on_atlas_location_selected)
	map_wrap.add_child(map_view)

	# HUD-Plaketten und Werkzeuge schweben über der Karte; die Karte bleibt
	# bis zum Rand bedienbar und muss nicht mehr in feste Leisten eingepasst werden.
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_wrap.add_child(hud)
	var map_header := PanelContainer.new()
	map_header.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_header.offset_left = 12
	map_header.offset_top = 12
	map_header.offset_right = 296
	map_header.offset_bottom = 78
	map_header.add_theme_stylebox_override("panel", _flat(Color(0.045, 0.035, 0.022, 0.88), Color(0.68, 0.51, 0.24, 0.86), 1))
	hud.add_child(map_header)
	var mh_box := VBoxContainer.new()
	mh_box.add_theme_constant_override("separation", 1)
	map_header.add_child(mh_box)
	map_header_title = _label("WELTKARTE · POLITIK", 15, CREAM)
	map_header_title.clip_text = true
	mh_box.add_child(map_header_title)
	map_header_meta = _label("49 Grafschaften · 9 Königreiche · 3 Reiche", 10, Color(0.88, 0.80, 0.64))
	map_header_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mh_box.add_child(map_header_meta)

	var ticker := PanelContainer.new()
	ticker.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ticker.offset_left = -140
	ticker.offset_top = 12
	ticker.offset_right = 140
	ticker.offset_bottom = 42
	ticker.add_theme_stylebox_override("panel", _flat(Color(0.06, 0.045, 0.028, 0.84), Color(0.42, 0.32, 0.17, 0.72), 1))
	hud.add_child(ticker)
	log_label = _label("", 10, Color(0.92, 0.86, 0.72))
	log_label.clip_text = true
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ticker.add_child(log_label)

	var map_tools := HBoxContainer.new()
	map_tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_tools.offset_left = -282
	map_tools.offset_top = 12
	map_tools.offset_right = -12
	map_tools.offset_bottom = 46
	map_tools.add_theme_constant_override("separation", 4)
	hud.add_child(map_tools)
	var zoom_out := _map_tool("−", func(): map_view.zoom_by(0.8))
	zoom_out.custom_minimum_size = Vector2(44, 34)
	zoom_out.tooltip_text = "Herauszoomen (−)"
	map_tools.add_child(zoom_out)
	var zoom_in := _map_tool("+", func(): map_view.zoom_by(1.25))
	zoom_in.custom_minimum_size = Vector2(44, 34)
	zoom_in.tooltip_text = "Hineinzoomen (+)"
	map_tools.add_child(zoom_in)
	var reset_btn := _map_tool("⌂", func(): map_view.reset_view())
	reset_btn.custom_minimum_size = Vector2(44, 34)
	reset_btn.tooltip_text = "Kartenausschnitt zurücksetzen (0)"
	map_tools.add_child(reset_btn)
	legend_button = _map_tool("Legende", _toggle_map_legend)
	legend_button.custom_minimum_size = Vector2(64, 34)
	legend_button.toggle_mode = true
	legend_button.add_theme_font_size_override("font_size", 10)
	legend_button.tooltip_text = "Kartenlegende ein-/ausblenden (L)"
	legend_button.add_theme_stylebox_override("pressed", _flat(Color(0.30, 0.22, 0.10, 0.98), Color(0.96, 0.78, 0.38), 2))
	map_tools.add_child(legend_button)
	side_toggle_btn = _map_tool("Hof", _toggle_side_panel)
	side_toggle_btn.custom_minimum_size = Vector2(44, 34)
	side_toggle_btn.toggle_mode = true
	side_toggle_btn.button_pressed = true
	side_toggle_btn.tooltip_text = "Hofpanel ein-/ausblenden (H)"
	side_toggle_btn.add_theme_stylebox_override("pressed", _flat(Color(0.30, 0.22, 0.10, 0.98), Color(0.96, 0.78, 0.38), 2))
	map_tools.add_child(side_toggle_btn)

	var mode_bar := PanelContainer.new()
	mode_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mode_bar.offset_left = -592
	mode_bar.offset_top = -180
	mode_bar.offset_right = -12
	mode_bar.offset_bottom = -140
	mode_bar.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.038, 0.024, 0.90), Color(0.58, 0.44, 0.22, 0.84), 1))
	hud.add_child(mode_bar)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)
	mode_bar.add_child(mode_row)
	mode_row.add_child(_label("KARTE", 9, Color(0.92, 0.72, 0.35)))
	var mode_index := 0
	for mode in MapViewScript.MAP_MODES:
		mode_index += 1
		var mb := _map_tool(_map_mode_title(str(mode)), Callable(self, "_set_map_mode").bind(str(mode)))
		mb.custom_minimum_size = Vector2(66, 30)
		mb.toggle_mode = true
		mb.add_theme_font_size_override("font_size", 10)
		mb.tooltip_text = "%d · %s — %s" % [mode_index, _map_mode_title(str(mode)), str(MapViewScript.MODE_HINTS.get(str(mode), ""))]
		mb.add_theme_stylebox_override("pressed", _flat(Color(0.30, 0.22, 0.10, 0.98), Color(0.96, 0.78, 0.38), 2))
		map_mode_buttons[str(mode)] = mb
		mode_row.add_child(mb)
	var chronicle_btn := _map_tool("Chronik", Callable(self, "_show_chronicle"))
	chronicle_btn.custom_minimum_size = Vector2(64, 30)
	chronicle_btn.add_theme_font_size_override("font_size", 10)
	mode_row.add_child(chronicle_btn)
	mode_row.add_child(_map_tool("Forschung", Callable(self, "_show_infrastructure")))

	minimap = WorldMiniMapScript.new()
	minimap.host = map_view
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -212
	minimap.offset_top = -138
	minimap.offset_right = -12
	minimap.offset_bottom = -12
	map_wrap.add_child(minimap)
	_sync_map_mode_buttons()

	# Hofpanel
	side_panel = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(380, 0)
	side_panel.add_theme_stylebox_override("panel", _card_style(12))
	row.add_child(side_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	var side_box := VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 7)
	scroll.add_child(side_box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	side_box.add_child(head)
	crest_rect = TextureRect.new()
	crest_rect.custom_minimum_size = Vector2(54, 64)
	crest_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(crest_rect)
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(88, 108)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_rect.tooltip_text = "Porträt antippen: Herrscher und Wappen gestalten"
	portrait_rect.gui_input.connect(_on_identity_gui_input)
	head.add_child(portrait_rect)
	crest_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	crest_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	crest_rect.tooltip_text = "Wappen antippen: Herrscher und Wappen gestalten"
	crest_rect.gui_input.connect(_on_identity_gui_input)
	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_text.add_theme_constant_override("separation", 2)
	head.add_child(head_text)
	title_label = _label("Dein Hof", 21, INK)
	head_text.add_child(title_label)
	info_label = _label("", 14, INK_SOFT)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_text.add_child(info_label)
	var profile_hint := _label("Porträt oder Wappen antippen, um Herrscher, Werte und Haus zu gestalten.", 11, Color(0.43, 0.31, 0.18))
	profile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(profile_hint)

	family_label = _label("", 13, INK_SOFT)
	family_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(family_label)
	side_box.add_child(_button("Stammbaum", _show_tree, "crown"))
	hint_label = _label("Tippe auf eine Provinz.", 12, Color(0.38, 0.30, 0.20))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(hint_label)

	_build_infrastructure_layer()
	research_label = _label("", 12, INK_SOFT)
	research_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	infrastructure_body.add_child(research_label)
	for innovation in ["surveying", "road_building"]:
		var research_button := _button("", func(): _dispatch({"id": "research", "innovation": innovation}), "scroll")
		research_button.custom_minimum_size.y = 48
		research_buttons[innovation] = research_button
		infrastructure_body.add_child(research_button)
	road_buttons = VBoxContainer.new()
	road_buttons.add_theme_constant_override("separation", 6)
	infrastructure_body.add_child(road_buttons)
	sandbox_button = _button("Als Sandbox fortsetzen", func(): _dispatch({"id": "continue_sandbox"}), "crown")
	sandbox_button.visible = false
	infrastructure_body.add_child(sandbox_button)
	side_box.add_child(_button("Forschung & Verkehrswege", _show_infrastructure, "scroll"))

	# Provinz-Kurzansicht mit Gelände-Token und Besitzerwappen.
	province_side_panel = VBoxContainer.new()
	province_side_panel.add_theme_constant_override("separation", 4)
	province_side_panel.visible = false
	side_box.add_child(province_side_panel)
	var province_side_row := HBoxContainer.new()
	province_side_row.add_theme_constant_override("separation", 8)
	province_side_panel.add_child(province_side_row)
	province_side_icon = TextureRect.new()
	province_side_icon.custom_minimum_size = Vector2(46, 46)
	province_side_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	province_side_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	province_side_row.add_child(province_side_icon)
	province_side_crest = TextureRect.new()
	province_side_crest.custom_minimum_size = Vector2(36, 44)
	province_side_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	province_side_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	province_side_row.add_child(province_side_crest)
	var province_side_text := VBoxContainer.new()
	province_side_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	province_side_text.add_theme_constant_override("separation", 1)
	province_side_row.add_child(province_side_text)
	province_side_title = _label("", 15, INK)
	province_side_text.add_child(province_side_title)
	province_side_meta = _label("", 11, INK_SOFT)
	province_side_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	province_side_text.add_child(province_side_meta)
	var province_open := _button("Provinzseite öffnen", _show_province, "scroll")
	province_open.custom_minimum_size = Vector2(0, 36)
	province_open.add_theme_font_size_override("font_size", 13)
	province_side_panel.add_child(province_open)
	# Die Auswahl steht direkt unter dem Hofkopf und nicht mehr am Ende des
	# langen Rollbereichs. So bleibt sie beim Kartenklick sofort sichtbar.
	side_box.move_child(province_side_panel, 1)

	develop_btn = _button("Ausbauen  (50 Gold)", func(): _dispatch({"id": "develop"}), "gold")
	recruit_btn = _button("Truppen werben  (30 Gold)", func(): _dispatch({"id": "recruit"}), "sword")
	attack_btn = _button("Angreifen  (25 Gold)", func(): _dispatch({"id": "attack"}), "sword")
	side_box.add_child(develop_btn)
	side_box.add_child(recruit_btn)
	side_box.add_child(attack_btn)

	var divider := HSeparator.new()
	side_box.add_child(divider)
	side_box.add_child(_label("Familie & Intrigen", 17, INK))
	marry_btn = _button("Heiraten  (30 Gold)", func(): _open_picker("marry"), "ring")
	bed_btn = _button("Beilager halten", func(): _dispatch({"id": "bed"}), "heart")
	seduce_btn = _button("Verführen  (20 Gold)", func(): _open_picker("seduce"), "mask")
	murder_btn = _button("Ermorden  (60 Gold)", func(): _open_picker("murder"), "dagger")
	kidnap_btn = _button("Entführen  (45 Gold)", func(): _open_picker("kidnap"), "chain")
	ransom_btn = _button("Lösegeld fordern  (+80 Gold)", func(): _dispatch({"id": "ransom"}), "gold")
	force_btn = _button("Gefangene/n heiraten", func(): _dispatch({"id": "force_marry"}), "ring")
	side_box.add_child(marry_btn)
	side_box.add_child(bed_btn)
	side_box.add_child(seduce_btn)
	side_box.add_child(murder_btn)
	side_box.add_child(kidnap_btn)
	side_box.add_child(ransom_btn)
	side_box.add_child(force_btn)
	court_btn = _button("Hof halten  (40 Gold)", func(): _dispatch({"id": "court"}), "crown")
	side_box.add_child(court_btn)
	side_box.add_child(_button("Hof & Reliquien", _show_court, "crown"))
	side_box.add_child(_button("Glaube & Kirche", _show_faith, "crown"))
	side_box.add_child(_button("Herrschaft", _show_rule, "crown"))
	side_box.add_child(_button("Spiel speichern", func(): _dispatch({"id": "save"}), "scroll"))
	side_box.add_child(_button("Spielstand laden", func(): _dispatch({"id": "load"}), "scroll"))
	_build_rule_layer()
	_build_court_layer()
	_build_faith_layer()

	# Ereignis-Overlay
	event_layer = Control.new()
	event_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.visible = false
	event_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.06, 0.16)
	event_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	var event_card_style := ModernInterfaceScript.surface(Color(0.04, 0.09, 0.13, 0.10), 20)
	event_card_style.set_border_width_all(1)
	event_card_style.border_color = Color(0.70, 0.84, 0.90, 0.24)
	event_card_style.shadow_color = Color(0, 0, 0, 0.28)
	event_card_style.shadow_size = 10
	event_card_style.shadow_offset = Vector2(0, 3)
	event_card_style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", event_card_style)
	center.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)
	var event_art_frame := Control.new()
	event_art_frame.custom_minimum_size = Vector2(400, 100)
	event_art_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	event_art_frame.clip_contents = true
	card_box.add_child(event_art_frame)
	event_art_fallback = EventArtFallbackScript.new()
	event_art_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_art_frame.add_child(event_art_fallback)
	event_art = TextureRect.new()
	event_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	event_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rounded_image := ShaderMaterial.new()
	rounded_image.shader = preload("res://shaders/event_portrait.gdshader")
	event_art.material = rounded_image
	event_art.resized.connect(func(): rounded_image.set_shader_parameter("rect_size", event_art.size))
	event_art_frame.add_child(event_art)
	event_title = _label("", 23, INK)
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_title.add_theme_constant_override("outline_size", 7)
	event_title.add_theme_color_override("font_outline_color", Color(0.015, 0.035, 0.05, 0.95))
	card_box.add_child(event_title)
	event_text = _label("", 16, INK_SOFT)
	event_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_text.add_theme_constant_override("outline_size", 5)
	event_text.add_theme_color_override("font_outline_color", Color(0.015, 0.035, 0.05, 0.95))
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_box.add_child(event_text)
	event_buttons = VBoxContainer.new()
	event_buttons.add_theme_constant_override("separation", 8)
	card_box.add_child(event_buttons)

	# Spielende
	over_layer = Control.new()
	over_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.visible = false
	over_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(over_layer)
	var dim2 := ColorRect.new()
	dim2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim2.color = Color(0.05, 0.02, 0.02, 0.86)
	over_layer.add_child(dim2)
	var center2 := CenterContainer.new()
	center2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(center2)
	var card2 := PanelContainer.new()
	card2.custom_minimum_size = Vector2(600, 0)
	card2.add_theme_stylebox_override("panel", _card_style(24))
	center2.add_child(card2)
	var box2 := VBoxContainer.new()
	box2.add_theme_constant_override("separation", 14)
	card2.add_child(box2)
	box2.add_child(_label("Das Haus ist erloschen", 27, Color(0.55, 0.18, 0.12)))
	var t := _label("Ohne Erben endet die Dynastie. Beginne ein neues Spiel.", 17, INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box2.add_child(t)
	box2.add_child(_button("Neu beginnen", func(): get_tree().reload_current_scene(), "crown"))

	# Titelbild
	start_layer = Control.new()
	start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_layer)
	var art := TextureRect.new()
	art.texture = TEX_TITLE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(art)
	var dim3 := ColorRect.new()
	dim3.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim3.color = Color(0.02, 0.015, 0.01, 0.10)
	dim3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(dim3)

	# Das Titelbild enthält die Wortmarke bereits. Die Menüleiste sitzt deshalb
	# ohne zweites Logo im dunklen Bereich unter dem Bogen.
	var title_panel := VBoxContainer.new()
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	title_panel.offset_left = -470
	title_panel.offset_top = -238
	title_panel.offset_right = -40
	title_panel.offset_bottom = -20
	title_panel.alignment = BoxContainer.ALIGNMENT_END
	title_panel.add_theme_constant_override("separation", 6)
	start_layer.add_child(title_panel)
	var title_menu := VBoxContainer.new()
	title_menu.add_theme_constant_override("separation", 7)
	title_panel.add_child(title_menu)
	for entry in [["Neues Spiel", _show_newgame, "crown"], ["Spiel laden", _load_from_title, "scroll"], ["Optionen", _show_options, "scroll"], ["Beenden", _quit_game, ""]]:
		var button := _title_button(str(entry[0]), entry[1], str(entry[2]))
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size", 18)
		title_menu.add_child(button)
	title_status = _label("", 12, Color(0.90, 0.75, 0.48))
	title_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_menu.add_child(title_status)

	var version := _label("Banger Queens · 2000 v. Chr. – 2200 n. Chr.", 12, Color(0.72, 0.60, 0.42))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 24
	version.offset_top = -32
	version.offset_right = 420
	version.offset_bottom = -10
	start_layer.add_child(version)
	var fullscreen_hint := _label("F11 · Vollbild", 12, Color(0.58, 0.50, 0.38))
	fullscreen_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fullscreen_hint.offset_left = 430
	fullscreen_hint.offset_top = -32
	fullscreen_hint.offset_right = 720
	fullscreen_hint.offset_bottom = -10
	fullscreen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	start_layer.add_child(fullscreen_hint)

	# Hausauswahl für ein neues Spiel
	newgame_layer = Control.new()
	newgame_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	newgame_layer.visible = false
	newgame_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(newgame_layer)
	var dim_new := ColorRect.new()
	dim_new.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_new.color = Color(0.02, 0.015, 0.01, 0.78)
	newgame_layer.add_child(dim_new)
	var center_new := CenterContainer.new()
	center_new.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	newgame_layer.add_child(center_new)
	var card_new := PanelContainer.new()
	card_new.custom_minimum_size = Vector2(880, 0)
	card_new.add_theme_stylebox_override("panel", _card_style(22))
	center_new.add_child(card_new)
	var box_new := VBoxContainer.new()
	box_new.add_theme_constant_override("separation", 8)
	card_new.add_child(box_new)
	var head_new := HBoxContainer.new()
	head_new.add_theme_constant_override("separation", 12)
	box_new.add_child(head_new)
	head_new.add_child(_label("Wähle dein Haus", 30, INK))
	head_new.add_child(_spacer())
	head_new.add_child(_button("Zurück", _hide_newgame, ""))
	var sub_new := _label("2000 v. Chr. · 49 Grafschaften · neun Königreiche · drei Reiche", 14, INK_SOFT)
	sub_new.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_new.add_child(sub_new)
	box_new.add_child(_button("Eigenes Haus gründen", _show_create, "crown"))
	var scroll3 := ScrollContainer.new()
	scroll3.custom_minimum_size = Vector2(0, 356)
	scroll3.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_new.add_child(scroll3)
	start_box = VBoxContainer.new()
	start_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_box.add_theme_constant_override("separation", 6)
	scroll3.add_child(start_box)

	# Erstellung
	create_layer = Control.new()
	create_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_layer.visible = false
	create_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(create_layer)
	var dim4 := ColorRect.new()
	dim4.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim4.color = Color(0.04, 0.03, 0.02, 0.78)
	create_layer.add_child(dim4)
	var center4 := CenterContainer.new()
	center4.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_layer.add_child(center4)
	var card4 := PanelContainer.new()
	card4.custom_minimum_size = Vector2(880, 0)
	card4.add_theme_stylebox_override("panel", _card_style(22))
	center4.add_child(card4)
	var box4 := VBoxContainer.new()
	box4.add_theme_constant_override("separation", 8)
	card4.add_child(box4)
	box4.add_child(_label("Gründe dein Haus", 30, INK))
	box4.add_child(_label("2000 v. Chr. — du bestimmst Namen, Land und Gaben.", 14, INK_SOFT))

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 14)
	form.add_theme_constant_override("v_separation", 6)
	box4.add_child(form)
	form.add_child(_label("Herrscher", 15, INK))
	edit_ruler = _field("Ari", "Name des Herrschers")
	form.add_child(edit_ruler)
	form.add_child(_label("Haus", 15, INK))
	edit_house = _field("Haus Neu", "Name deiner Dynastie")
	form.add_child(edit_house)
	form.add_child(_label("Grafschaft", 15, INK))
	edit_land = _field("", "Name deiner Grafschaft (optional)")
	form.add_child(edit_land)
	form.add_child(_label("Geschlecht", 15, INK))
	create_sex = OptionButton.new()
	create_sex.add_item("Mann")
	create_sex.add_item("Frau")
	create_sex.add_theme_stylebox_override("normal", _field_style())
	create_sex.add_theme_color_override("font_color", INK)
	form.add_child(create_sex)
	form.add_child(_label("Heimat", 15, INK))
	create_home = OptionButton.new()
	var provs: Array = DataScript.provinces()
	var houses: Array = DataScript.houses()
	for i in provs.size():
		var p: Dictionary = provs[i]
		create_home.add_item("%s · %s" % [p["name"], str(p["duchy_name"]).replace("Herzogtum ", "")])
		create_home.set_item_metadata(i, p["id"])
	create_home.add_theme_stylebox_override("normal", _field_style())
	create_home.add_theme_color_override("font_color", INK)
	form.add_child(create_home)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	box4.add_child(stats)
	stats.add_child(_label("Gaben (20 Punkte frei)", 15, INK))
	for key in ["martial", "diplomacy", "stewardship", "intrigue"]:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		var name_label := _label(_stat_name(key), 14, INK)
		name_label.custom_minimum_size = Vector2(150, 0)
		row2.add_child(name_label)
		var minus := _button("−", func(): _adjust(key, -1), "")
		minus.custom_minimum_size = Vector2(42, 38)
		row2.add_child(minus)
		var value_label := _label(str(stat_values[key]), 17, INK)
		value_label.custom_minimum_size = Vector2(34, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row2.add_child(value_label)
		stat_labels[key] = value_label
		var plus := _button("+", func(): _adjust(key, 1), "")
		plus.custom_minimum_size = Vector2(42, 38)
		row2.add_child(plus)
		stats.add_child(row2)
	points_label = _label("Punkte übrig: 20", 14, INK_SOFT)
	stats.add_child(points_label)

	var create_actions := HBoxContainer.new()
	create_actions.add_theme_constant_override("separation", 10)
	create_actions.add_child(_button("Herrschaft beginnen", _create_begin, "crown"))
	create_actions.add_child(_button("Zurück", _hide_create, ""))
	box4.add_child(create_actions)

	# Stammbaum
	tree_layer = Control.new()
	tree_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_layer.visible = false
	tree_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tree_layer)
	var dim6 := ColorRect.new()
	dim6.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim6.color = Color(0, 0, 0, 0.72)
	tree_layer.add_child(dim6)
	var center6 := CenterContainer.new()
	center6.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_layer.add_child(center6)
	var card6 := PanelContainer.new()
	card6.custom_minimum_size = Vector2(1140, 0)
	card6.add_theme_stylebox_override("panel", _card_style(20))
	center6.add_child(card6)
	var box6 := VBoxContainer.new()
	box6.add_theme_constant_override("separation", 6)
	card6.add_child(box6)
	var head6 := HBoxContainer.new()
	head6.add_theme_constant_override("separation", 12)
	box6.add_child(head6)
	tree_title = _label("Stammbaum", 23, INK)
	head6.add_child(tree_title)
	head6.add_child(_spacer())
	head6.add_child(_button("Schließen", _hide_tree, ""))
	var content6 := HBoxContainer.new()
	content6.add_theme_constant_override("separation", 10)
	box6.add_child(content6)
	var tree_scroll := ScrollContainer.new()
	tree_scroll.custom_minimum_size = Vector2(730, 470)
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content6.add_child(tree_scroll)
	tree_view = FamilyTreeScript.new()
	tree_view.custom_minimum_size = Vector2(720, 470)
	tree_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.add_child(tree_view)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(330, 470)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content6.add_child(list_scroll)
	tree_list = VBoxContainer.new()
	tree_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(tree_list)

	# Zielauswahl für Intrigen
	pick_layer = Control.new()
	pick_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick_layer.visible = false
	pick_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pick_layer)
	var dim5 := ColorRect.new()
	dim5.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim5.color = Color(0, 0, 0, 0.7)
	pick_layer.add_child(dim5)
	var center5 := CenterContainer.new()
	center5.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick_layer.add_child(center5)
	var card5 := PanelContainer.new()
	card5.custom_minimum_size = Vector2(780, 0)
	card5.add_theme_stylebox_override("panel", _card_style(22))
	center5.add_child(card5)
	var box5 := VBoxContainer.new()
	box5.add_theme_constant_override("separation", 8)
	card5.add_child(box5)
	pick_title = _label("", 24, INK)
	box5.add_child(pick_title)
	var pick_scroll := ScrollContainer.new()
	pick_scroll.custom_minimum_size = Vector2(0, 420)
	pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box5.add_child(pick_scroll)
	pick_box = VBoxContainer.new()
	pick_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_box.add_theme_constant_override("separation", 6)
	pick_scroll.add_child(pick_box)
	box5.add_child(_button("Abbrechen", _hide_picker, ""))

	_build_customizer()
	_build_banner_generator()
	_build_province_layer()
	_build_options_layer()
	_build_quit_layer()

func _build_banner_generator() -> void:
	banner_generator = BannerGeneratorScript.new()
	add_child(banner_generator)
	banner_generator.applied.connect(_on_banner_applied)
	banner_generator.closed.connect(_on_banner_closed)

# --- Herrscher-Werkstatt -------------------------------------------------

func _build_province_layer() -> void:
	province_layer = Control.new()
	province_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	province_layer.visible = false
	province_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(province_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	province_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	province_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 0)
	card.add_theme_stylebox_override("panel", _card_style(18))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	province_title = _label("Provinz", 24, INK)
	province_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(province_title)
	head.add_child(_button("Schließen", _hide_province, ""))

	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	box.add_child(hero)
	province_art = TextureRect.new()
	province_art.custom_minimum_size = Vector2(150, 150)
	province_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	province_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(province_art)
	province_info = VBoxContainer.new()
	province_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	province_info.add_theme_constant_override("separation", 2)
	hero.add_child(province_info)
	var owner_box := VBoxContainer.new()
	owner_box.custom_minimum_size = Vector2(132, 0)
	owner_box.add_theme_constant_override("separation", 2)
	hero.add_child(owner_box)
	province_crest = TextureRect.new()
	province_crest.custom_minimum_size = Vector2(46, 56)
	province_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	province_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_box.add_child(province_crest)
	province_portrait = TextureRect.new()
	province_portrait.custom_minimum_size = Vector2(64, 78)
	province_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	province_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_box.add_child(province_portrait)
	province_owner_name = _label("", 10, INK_SOFT)
	province_owner_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_box.add_child(province_owner_name)

	box.add_child(_label("Gebäude", 16, INK))
	province_buildings = HBoxContainer.new()
	province_buildings.add_theme_constant_override("separation", 16)
	box.add_child(province_buildings)
	box.add_child(_label("Aufgebot", 16, INK))
	province_troops = HBoxContainer.new()
	province_troops.add_theme_constant_override("separation", 10)
	box.add_child(province_troops)
	province_neighbors = _label("", 12, INK_SOFT)
	province_neighbors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(province_neighbors)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	for entry in [["develop", "Ausbauen (50)"], ["recruit", "Truppen werben (30)"], ["attack", "Angreifen (25)"], ["rule", "Herrschaft"]]:
		var key: String = str(entry[0])
		var b := _button(str(entry[1]), Callable(self, "_province_action").bind(key), "")
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 13)
		actions.add_child(b)
		province_action_buttons[key] = b
	box.add_child(actions)

func _refresh_province_side() -> void:
	if province_side_panel == null:
		return
	if game == null or selected == "":
		province_side_panel.visible = false
		return
	var p: Dictionary = game.province(selected)
	if p.is_empty():
		province_side_panel.visible = false
		return
	province_side_panel.visible = true
	province_side_icon.texture = TOKENS.get("terrain_%s" % str(p.get("terrain", "plains")))
	province_side_crest.texture = _crest_for_house(int(p["owner"]))
	province_side_title.text = str(p["name"])
	var side_meta := "%s · %s\nAufgebot %d · Entwicklung %d/10" % [
		str(p.get("terrain_name", "Ebenen")), str(game.houses[int(p["owner"])]["name"]),
		int(p.get("levy", 0)), int(p.get("dev", 1)),
	]
	if int(p.get("blockade", 0)) > 0:
		side_meta += "\nBlockade: %d Monate" % int(p["blockade"])
	province_side_meta.text = side_meta

func _crest_for_house(index: int) -> Texture2D:
	if game == null or index < 0 or index >= game.houses.size():
		return null
	var h: Dictionary = game.houses[index]
	var custom := _house_crest_texture(h)
	if custom != null:
		return custom
	if not CRESTS.is_empty():
		return CRESTS[posmod(int(h.get("crest", index)), CRESTS.size())]
	return null

func _refresh_province_page() -> void:
	if province_layer == null:
		return
	if game == null or selected == "":
		if province_layer.visible:
			_hide_province()
		return
	var p: Dictionary = game.province(selected)
	if p.is_empty():
		if province_layer.visible:
			_hide_province()
		return
	var owner_i: int = int(p["owner"])
	var owner: Dictionary = game.houses[owner_i]
	var terrain_key: String = str(p.get("terrain", "plains"))
	province_title.text = "Provinz %s" % str(p["name"])
	province_art.texture = TOKENS.get("terrain_%s" % terrain_key)
	province_crest.texture = _crest_for_house(owner_i)
	if not PORTRAITS.is_empty():
		province_portrait.texture = PORTRAITS[int(owner["ruler"].get("portrait", 0)) % PORTRAITS.size()]
	else:
		province_portrait.texture = null
	province_owner_name.text = "%s\n%s" % [str(owner["name"]), str(owner["ruler"]["name"])]
	for c in province_info.get_children():
		province_info.remove_child(c)
		c.queue_free()
	province_info.add_child(_label("%s · %s" % [str(p["kingdom_name"]), str(p["empire_name"])], 12, INK_SOFT))
	province_info.add_child(_label("Herzogtum: %s" % str(p["duchy_name"]), 12, INK_SOFT))
	province_info.add_child(_label("Gelände: %s · Verteidigung %+d%% · Versorgung %d" % [
		str(p.get("terrain_name", "Ebenen")), int(p.get("terrain_defense", 0)), int(p.get("terrain_supply", 6)) * 100
	], 12, INK_SOFT))
	province_info.add_child(_label("Entwicklung %d/10 · Aufgebot %d · Hauptstadt: %s" % [
		int(p.get("dev", 1)), int(p.get("levy", 0)), "ja" if bool(p.get("capital", false)) else "nein"
	], 12, INK_SOFT))
	province_info.add_child(_label("Besitzer: %s · Haltung %+d" % [str(owner["name"]), int(game.opinion[owner_i])], 12, INK_SOFT))
	if int(p.get("blockade", 0)) > 0:
		var blockader: int = int(p.get("blockade_owner", -1))
		var blockader_name := "unbekannt"
		if blockader >= 0 and blockader < game.houses.size():
			blockader_name = str(game.houses[blockader]["name"])
		province_info.add_child(_label("Blockade durch %s · noch %d Monate" % [blockader_name, int(p["blockade"])], 12, INK_SOFT))
	if is_coastal_province(selected):
		province_info.add_child(_label("Küstenprovinz · Flotten können hier anlegen und blockieren", 11, INK_SOFT))
	for c in province_buildings.get_children():
		province_buildings.remove_child(c)
		c.queue_free()
	var buildings: Dictionary = p.get("buildings", {})
	for entry in [["market", "Markt"], ["barracks", "Kaserne"], ["walls", "Mauern"]]:
		var key: String = str(entry[0])
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = TOKENS.get("building_%s" % key)
		cell.add_child(icon)
		cell.add_child(_label("%s %d/3" % [str(entry[1]), int(buildings.get(key, 0))], 10, INK_SOFT))
		province_buildings.add_child(cell)
	for c in province_troops.get_children():
		province_troops.remove_child(c)
		c.queue_free()
	province_troops.add_child(_army_tokens(int(p.get("levy", 0))))
	var station_fleet := _fleet_at(selected)
	if not station_fleet.is_empty():
		province_troops.add_child(_fleet_tokens(station_fleet))
	var neighbours: Array = []
	for nid in game.neighbours(selected):
		var q: Dictionary = game.province(str(nid))
		if not q.is_empty():
			neighbours.append("%s (%s)" % [q["name"], game.houses[int(q["owner"])]["name"]])
	province_neighbors.text = "Nachbarn: " + ", ".join(neighbours)
	province_action_buttons["develop"].disabled = not game.can_develop(selected)
	province_action_buttons["recruit"].disabled = not game.can_recruit(selected)
	province_action_buttons["attack"].disabled = not game.can_attack(selected)

func _province_action(key: String) -> void:
	if key == "rule":
		_hide_province()
		_show_rule()
		return
	_dispatch({"id": key})

func _show_province() -> void:
	if game == null or selected == "":
		return
	if province_layer == null:
		_build_province_layer()
	_refresh_province_page()
	province_layer.visible = true
	province_layer.move_to_front()
	kernel.push_modal("provinz")
	_play_open()

func _hide_province() -> void:
	kernel.pop_modal("provinz")
	if province_layer != null:
		province_layer.visible = false

func _option_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(text, 14, INK)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _check_option(text: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", INK)
	c.add_theme_color_override("font_hover_color", INK)
	return c

func _drop_option(items: Array) -> OptionButton:
	var o := OptionButton.new()
	for item in items:
		o.add_item(str(item))
	o.add_theme_stylebox_override("normal", _field_style())
	o.add_theme_stylebox_override("hover", _field_style())
	o.add_theme_stylebox_override("pressed", _field_style())
	o.add_theme_color_override("font_color", INK)
	o.add_theme_font_size_override("font_size", 14)
	return o

func _build_options_layer() -> void:
	options_layer = Control.new()
	options_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_layer.visible = false
	options_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(options_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(860, 0)
	card.add_theme_stylebox_override("panel", _card_style(18))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := _label("Optionen", 25, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Schließen", _hide_options, ""))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for entry in [["bild", "Bild"], ["ton", "Ton"], ["spiel", "Spiel"]]:
		var key: String = str(entry[0])
		var tab := _button(str(entry[1]), Callable(self, "_select_options_tab").bind(key), "")
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(110, 34)
		tab.add_theme_font_size_override("font_size", 14)
		options_tab_buttons[key] = tab
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 4)
	scroll.add_child(pages)
	for key in ["bild", "ton", "spiel"]:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		page.visible = str(key) == "bild"
		options_sections[str(key)] = page
		pages.add_child(page)

	var bild: VBoxContainer = options_sections["bild"]
	opt_window_mode = _drop_option(["Fenster", "Vollbild"])
	bild.add_child(_option_row("Fenstermodus", opt_window_mode))
	opt_resolution = _drop_option(["1280 × 720", "1600 × 900", "1920 × 1080"])
	bild.add_child(_option_row("Fensterauflösung", opt_resolution))
	opt_vsync = _drop_option(["Aus", "An", "Adaptiv"])
	bild.add_child(_option_row("VSync", opt_vsync))
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 10)
	var scale_label := _label("Oberflächengröße", 14, INK)
	scale_label.custom_minimum_size = Vector2(190, 0)
	scale_row.add_child(scale_label)
	opt_ui_scale = HSlider.new()
	opt_ui_scale.min_value = 80
	opt_ui_scale.max_value = 120
	opt_ui_scale.step = 5
	opt_ui_scale.custom_minimum_size = Vector2(320, 24)
	opt_ui_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(opt_ui_scale)
	opt_ui_scale_label = _label("100 %", 12, INK_SOFT)
	opt_ui_scale_label.custom_minimum_size = Vector2(50, 0)
	scale_row.add_child(opt_ui_scale_label)
	bild.add_child(scale_row)
	var bild_hint := _label("Auflösung und Vollbild gelten sofort; die Oberfläche bleibt bei 1280 × 720 lesbar.", 11, INK_SOFT)
	bild_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bild.add_child(bild_hint)
	opt_theme = _drop_option(ModernInterfaceScript.THEME_NAMES)
	opt_theme.select(int(settings["ui_theme"]))
	opt_theme.item_selected.connect(func(index: int):
		if has_meta("modern_interface"):
			get_meta("modern_interface").set_appearance(index)
			_save_settings()
	)
	bild.add_child(_option_row("Lesbarkeitsthema", opt_theme))
	opt_text_scale = _drop_option(["100 %", "125 %", "150 %", "200 %"])
	var text_sizes := [1.0, 1.25, 1.5, 2.0]
	opt_text_scale.select(maxi(0, text_sizes.find(float(settings["text_scale"]))))
	opt_text_scale.item_selected.connect(func(index: int):
		if has_meta("modern_interface"):
			get_meta("modern_interface").set_text_scale(float(text_sizes[index]))
			_save_settings()
	)
	bild.add_child(_option_row("Textgröße", opt_text_scale))

	var ton: VBoxContainer = options_sections["ton"]
	opt_muted = _check_option("Ton aktiv")
	ton.add_child(_option_row("Gesamter Ton", opt_muted))
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 10)
	var music_label := _label("Musik", 14, INK)
	music_label.custom_minimum_size = Vector2(190, 0)
	music_row.add_child(music_label)
	opt_music = HSlider.new()
	opt_music.min_value = 0
	opt_music.max_value = 100
	opt_music.step = 1
	opt_music.custom_minimum_size = Vector2(320, 24)
	opt_music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(opt_music)
	opt_music_label = _label("55 %", 12, INK_SOFT)
	opt_music_label.custom_minimum_size = Vector2(50, 0)
	music_row.add_child(opt_music_label)
	ton.add_child(music_row)
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	var sfx_label := _label("Effekte", 14, INK)
	sfx_label.custom_minimum_size = Vector2(190, 0)
	sfx_row.add_child(sfx_label)
	opt_sfx = HSlider.new()
	opt_sfx.min_value = 0
	opt_sfx.max_value = 100
	opt_sfx.step = 1
	opt_sfx.custom_minimum_size = Vector2(320, 24)
	opt_sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(opt_sfx)
	opt_sfx_label = _label("75 %", 12, INK_SOFT)
	opt_sfx_label.custom_minimum_size = Vector2(50, 0)
	sfx_row.add_child(opt_sfx_label)
	ton.add_child(sfx_row)
	var ton_hint := _label("Musik und Effekte laufen auf getrennten Bussen; „Ton aus“ schaltet beide stumm.", 11, INK_SOFT)
	ton_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ton.add_child(ton_hint)

	var spiel: VBoxContainer = options_sections["spiel"]
	opt_autosave = _check_option("Automatisch jährlich speichern")
	spiel.add_child(_option_row("Speichern", opt_autosave))
	opt_pause_events = _check_option("Zeit bei Ereignissen anhalten")
	spiel.add_child(_option_row("Ereignisse", opt_pause_events))
	opt_start_speed = _drop_option(["Pause", "x1", "x2", "x3"])
	spiel.add_child(_option_row("Starttempo neuer Partien", opt_start_speed))
	var spiel_hint := _label("Speichern legt den Spielstand unter user://spielstand.json ab. Beim Schließen des Fensters wird eine laufende Partie zusätzlich automatisch gesichert.", 11, INK_SOFT)
	spiel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spiel.add_child(spiel_hint)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	box.add_child(footer)
	opt_save_btn = _button("Spiel speichern", _options_save, "scroll")
	opt_save_btn.custom_minimum_size = Vector2(150, 40)
	opt_save_btn.add_theme_font_size_override("font_size", 13)
	footer.add_child(opt_save_btn)
	opt_save_quit_btn = _button("Speichern & Beenden", _save_then_quit, "")
	opt_save_quit_btn.custom_minimum_size = Vector2(160, 40)
	opt_save_quit_btn.add_theme_font_size_override("font_size", 13)
	footer.add_child(opt_save_quit_btn)
	var quit_btn := _button("Beenden", _request_quit, "")
	quit_btn.custom_minimum_size = Vector2(110, 40)
	quit_btn.add_theme_font_size_override("font_size", 13)
	footer.add_child(quit_btn)
	var close_btn := _button("Zurück", _hide_options, "")
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.add_theme_font_size_override("font_size", 13)
	footer.add_child(close_btn)
	options_status = _label("", 11, INK_SOFT)
	options_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(options_status)

	opt_window_mode.item_selected.connect(_options_window_mode)
	opt_resolution.item_selected.connect(_options_resolution)
	opt_vsync.item_selected.connect(_options_vsync)
	opt_ui_scale.value_changed.connect(_options_ui_scale)
	opt_music.value_changed.connect(_options_music)
	opt_sfx.value_changed.connect(_options_sfx)
	opt_muted.toggled.connect(_options_muted)
	opt_autosave.toggled.connect(_options_autosave)
	opt_pause_events.toggled.connect(_options_pause_events)
	opt_start_speed.item_selected.connect(_options_start_speed)
	_select_options_tab("bild")

func _select_options_tab(key: String) -> void:
	for tab_key in options_sections.keys():
		var page: VBoxContainer = options_sections[tab_key]
		page.visible = str(tab_key) == key
		var b: Button = options_tab_buttons.get(tab_key)
		if b != null:
			b.button_pressed = str(tab_key) == key

func _refresh_options() -> void:
	if options_layer == null:
		return
	opt_window_mode.select(clampi(int(settings["window_mode"]), 0, 1))
	opt_resolution.select(clampi(int(settings["resolution"]), 0, RESOLUTIONS.size() - 1))
	opt_vsync.select(clampi(int(settings["vsync"]), 0, 2))
	opt_ui_scale.set_value_no_signal(float(settings["ui_scale"]) * 100.0)
	opt_ui_scale_label.text = "%d %%" % int(round(float(settings["ui_scale"]) * 100.0))
	opt_music.set_value_no_signal(float(settings["music"]))
	opt_music_label.text = "%d %%" % int(settings["music"])
	opt_sfx.set_value_no_signal(float(settings["sfx"]))
	opt_sfx_label.text = "%d %%" % int(settings["sfx"])
	opt_muted.set_pressed_no_signal(not bool(settings["muted"]))
	opt_autosave.set_pressed_no_signal(bool(settings["autosave"]))
	opt_pause_events.set_pressed_no_signal(bool(settings["pause_events"]))
	opt_start_speed.select(clampi(int(settings["start_speed"]), 0, 3))
	opt_save_btn.disabled = game == null
	opt_save_quit_btn.disabled = game == null
	options_status.text = ""

func _show_options() -> void:
	if options_layer == null:
		return
	_refresh_options()
	options_layer.visible = true
	options_layer.move_to_front()
	kernel.push_modal("optionen")
	_play_open()

func _hide_options() -> void:
	kernel.pop_modal("optionen")
	if options_layer != null:
		options_layer.visible = false

func _options_window_mode(index: int) -> void:
	settings["window_mode"] = clampi(index, 0, 1)
	_apply_display_settings(true)
	_save_settings()
	_refresh_options()

func _options_resolution(index: int) -> void:
	settings["resolution"] = clampi(index, 0, RESOLUTIONS.size() - 1)
	_apply_display_settings(true)
	_save_settings()

func _options_vsync(index: int) -> void:
	settings["vsync"] = clampi(index, 0, 2)
	_apply_display_settings(true)
	_save_settings()

func _options_ui_scale(value: float) -> void:
	settings["ui_scale"] = clampf(value / 100.0, 0.8, 1.2)
	if DisplayServer.get_name() != "headless":
		get_window().content_scale_factor = float(settings["ui_scale"])
	opt_ui_scale_label.text = "%d %%" % int(round(value))
	_save_settings()

func _options_music(value: float) -> void:
	settings["music"] = clampi(int(round(value)), 0, 100)
	_apply_audio_settings()
	_save_settings()

func _options_sfx(value: float) -> void:
	settings["sfx"] = clampi(int(round(value)), 0, 100)
	_apply_audio_settings()
	_save_settings()

func _options_muted(on: bool) -> void:
	settings["muted"] = not on
	_apply_audio_settings()
	_save_settings()

func _options_autosave(on: bool) -> void:
	settings["autosave"] = on
	_save_settings()

func _options_pause_events(on: bool) -> void:
	settings["pause_events"] = on
	_save_settings()

func _options_start_speed(index: int) -> void:
	settings["start_speed"] = clampi(index, 0, 3)
	_save_settings()

func _options_save() -> void:
	var results: Dictionary = _save()
	if options_status != null:
		options_status.text = str(results.get("message", ""))

func _build_quit_layer() -> void:
	quit_layer = Control.new()
	quit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_layer.visible = false
	quit_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(quit_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", _card_style(22))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(_label("Spiel beenden?", 24, INK))
	var text := _label("Eine laufende Partie kann gespeichert werden. Beim Schließen des Fensters speichert das Spiel automatisch.", 13, INK_SOFT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	box.add_child(_button("Speichern & Beenden", _save_then_quit, "scroll"))
	box.add_child(_button("Ohne Speichern beenden", _finish_quit, ""))
	box.add_child(_button("Abbrechen", _hide_quit, ""))
	quit_status = _label("", 11, Color(0.55, 0.18, 0.12))
	quit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quit_status)

func _request_quit() -> void:
	if game == null:
		_finish_quit()
		return
	if quit_layer == null:
		_build_quit_layer()
	if quit_status != null:
		quit_status.text = ""
	quit_layer.visible = true
	quit_layer.move_to_front()
	kernel.push_modal("quit_confirm")
	_play_open()

func _hide_quit() -> void:
	kernel.pop_modal("quit_confirm")
	if quit_layer != null:
		quit_layer.visible = false

func _save_then_quit() -> void:
	if game == null:
		_finish_quit()
		return
	var result: Dictionary = _save()
	if bool(result.get("ok", false)):
		_finish_quit()
	elif quit_status != null:
		quit_status.text = str(result.get("message", "Speichern fehlgeschlagen."))

func _finish_quit() -> void:
	_save_settings()
	_stop_audio()
	get_tree().quit()

func _build_customizer() -> void:
	custom_layer = Control.new()
	custom_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_layer.visible = false
	custom_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(custom_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.84)
	custom_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override("panel", _card_style(18))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(_label("Herrscher gestalten", 26, INK))
	head.add_child(_spacer())
	head.add_child(_button("Schließen", _custom_cancel, ""))
	var sub := _label("Porträt, Wappen, Hausfarbe und Charakter deines Herrschers.", 13, INK_SOFT)
	box.add_child(sub)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	box.add_child(content)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 4)
	content.add_child(left)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 10)
	left.add_child(preview_row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(116, 142)
	portrait_frame.add_theme_stylebox_override("panel", _flat(Color(0.16, 0.11, 0.07, 0.92), Color(0.76, 0.58, 0.28), 2))
	preview_row.add_child(portrait_frame)
	custom_portrait_preview = TextureRect.new()
	custom_portrait_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_portrait_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(custom_portrait_preview)
	var badge := VBoxContainer.new()
	badge.add_theme_constant_override("separation", 3)
	preview_row.add_child(badge)
	var crest_frame := PanelContainer.new()
	crest_frame.custom_minimum_size = Vector2(74, 88)
	crest_frame.add_theme_stylebox_override("panel", _flat(Color(0.16, 0.11, 0.07, 0.92), Color(0.76, 0.58, 0.28), 2))
	badge.add_child(crest_frame)
	custom_crest_preview = TextureRect.new()
	custom_crest_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_crest_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest_frame.add_child(custom_crest_preview)
	badge.add_child(_label("Hausfarbe", 10, INK_SOFT))
	custom_color_swatch = ColorRect.new()
	custom_color_swatch.custom_minimum_size = Vector2(74, 18)
	badge.add_child(custom_color_swatch)

	left.add_child(_label("Porträt wählen", 13, INK))
	var portrait_scroll := ScrollContainer.new()
	portrait_scroll.custom_minimum_size = Vector2(0, 176)
	portrait_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(portrait_scroll)
	var portrait_grid := GridContainer.new()
	portrait_grid.columns = 6
	portrait_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_grid.add_theme_constant_override("h_separation", 3)
	portrait_grid.add_theme_constant_override("v_separation", 3)
	portrait_scroll.add_child(portrait_grid)
	custom_portrait_group = ButtonGroup.new()
	for i in PORTRAITS.size():
		var pb := Button.new()
		pb.toggle_mode = true
		pb.button_group = custom_portrait_group
		pb.custom_minimum_size = Vector2(48, 54)
		pb.icon = PORTRAITS[i]
		pb.add_theme_constant_override("icon_max_width", 42)
		pb.add_theme_stylebox_override("normal", _flat(Color(0.90, 0.83, 0.68), Color(0.45, 0.32, 0.17), 1))
		pb.add_theme_stylebox_override("hover", _flat(Color(0.98, 0.91, 0.75), Color(0.72, 0.52, 0.23), 2))
		pb.add_theme_stylebox_override("pressed", _flat(Color(0.82, 0.72, 0.52), Color(0.88, 0.68, 0.32), 2))
		pb.tooltip_text = "Porträt %d" % (i + 1)
		pb.pressed.connect(_custom_set_portrait.bind(i))
		portrait_grid.add_child(pb)
		custom_portrait_buttons.append(pb)

	left.add_child(_label("Wappen wählen", 13, INK))
	var crest_grid := GridContainer.new()
	crest_grid.columns = 5
	crest_grid.add_theme_constant_override("h_separation", 3)
	crest_grid.add_theme_constant_override("v_separation", 3)
	left.add_child(crest_grid)
	custom_crest_group = ButtonGroup.new()
	for i in CRESTS.size():
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_group = custom_crest_group
		cb.custom_minimum_size = Vector2(58, 48)
		cb.icon = CRESTS[i]
		cb.add_theme_constant_override("icon_max_width", 34)
		cb.add_theme_stylebox_override("normal", _flat(Color(0.90, 0.83, 0.68), Color(0.45, 0.32, 0.17), 1))
		cb.add_theme_stylebox_override("hover", _flat(Color(0.98, 0.91, 0.75), Color(0.72, 0.52, 0.23), 2))
		cb.add_theme_stylebox_override("pressed", _flat(Color(0.82, 0.72, 0.52), Color(0.88, 0.68, 0.32), 2))
		cb.tooltip_text = "Wappen %d" % (i + 1)
		cb.pressed.connect(_custom_set_crest.bind(i))
		crest_grid.add_child(cb)
		custom_crest_buttons.append(cb)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	content.add_child(right)
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 5)
	right.add_child(form)
	form.add_child(_label("Name", 13, INK))
	custom_name = _field("", "Name des Herrschers")
	custom_name.custom_minimum_size = Vector2(300, 0)
	form.add_child(custom_name)
	form.add_child(_label("Haus", 13, INK))
	custom_house = _field("", "Name des Hauses")
	custom_house.custom_minimum_size = Vector2(300, 0)
	form.add_child(custom_house)
	form.add_child(_label("Geschlecht", 13, INK))
	custom_gender = OptionButton.new()
	custom_gender.add_item("Mann")
	custom_gender.add_item("Frau")
	custom_gender.add_theme_stylebox_override("normal", _field_style())
	custom_gender.add_theme_color_override("font_color", INK)
	form.add_child(custom_gender)
	form.add_child(_label("Alter", 13, INK))
	custom_age = SpinBox.new()
	custom_age.min_value = 16
	custom_age.max_value = 90
	custom_age.get_line_edit().add_theme_stylebox_override("normal", _field_style())
	custom_age.get_line_edit().add_theme_color_override("font_color", INK)
	form.add_child(custom_age)

	right.add_child(_label("Hausfarbe", 13, INK))
	var palette := HBoxContainer.new()
	palette.add_theme_constant_override("separation", 4)
	right.add_child(palette)
	for col in [
		Color(0.68, 0.30, 0.20), Color(0.22, 0.38, 0.62), Color(0.24, 0.50, 0.30),
		Color(0.76, 0.56, 0.20), Color(0.18, 0.50, 0.52), Color(0.46, 0.28, 0.58),
		Color(0.72, 0.60, 0.20), Color(0.34, 0.40, 0.48), Color(0.48, 0.54, 0.28),
		Color(0.58, 0.22, 0.28),
	]:
		var color_btn := Button.new()
		color_btn.custom_minimum_size = Vector2(30, 30)
		color_btn.tooltip_text = "Hausfarbe wählen"
		color_btn.add_theme_stylebox_override("normal", _flat(col, Color(0.20, 0.14, 0.08), 1, true))
		color_btn.add_theme_stylebox_override("hover", _flat(col.lightened(0.18), Color(0.90, 0.70, 0.34), 2, true))
		color_btn.add_theme_stylebox_override("pressed", _flat(col.darkened(0.18), Color(1.0, 0.82, 0.42), 2, true))
		color_btn.add_theme_stylebox_override("focus", ModernInterfaceScript.focus_surface(0))
		color_btn.pressed.connect(_custom_set_color.bind(col))
		palette.add_child(color_btn)

	right.add_child(_label("Charakterwerte", 15, INK))
	for key in ["martial", "diplomacy", "stewardship", "intrigue"]:
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 7)
		var stat_label := _label(_stat_name(key), 13, INK_SOFT)
		stat_label.custom_minimum_size = Vector2(145, 0)
		stat_row.add_child(stat_label)
		var minus := _button("−", Callable(self, "_custom_adjust").bind(key, -1), "")
		minus.custom_minimum_size = Vector2(36, 32)
		stat_row.add_child(minus)
		var value_label := _label("", 15, INK)
		value_label.custom_minimum_size = Vector2(34, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_row.add_child(value_label)
		custom_stat_labels[key] = value_label
		var plus := _button("+", Callable(self, "_custom_adjust").bind(key, 1), "")
		plus.custom_minimum_size = Vector2(36, 32)
		stat_row.add_child(plus)
		right.add_child(stat_row)

	custom_status = _label("Werte 3–20. Übernehmen speichert alle Änderungen im Spielstand.", 11, Color(0.44, 0.34, 0.22))
	custom_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(custom_status)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	footer.add_child(_button("Banner-Generator", _open_banner_generator, "crown"))
	footer.add_child(_button("Abbrechen", _custom_cancel, ""))
	footer.add_child(_button("Übernehmen", _custom_apply, "crown"))

	custom_name.text_changed.connect(_custom_name_changed)
	custom_house.text_changed.connect(_custom_house_changed)
	custom_gender.item_selected.connect(_custom_gender_changed)
	custom_age.value_changed.connect(_custom_age_changed)

func _on_identity_gui_input(event: InputEvent) -> void:
	if game == null or game.game_over or custom_layer == null or custom_layer.visible:
		return
	var clicked := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		clicked = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if clicked:
		_open_customizer()

func _open_customizer() -> void:
	if game == null or game.game_over:
		return
	kernel.push_modal("customizer")
	custom_snapshot = game.house().duplicate(true)
	custom_prev_speed = int(game.speed)
	game.speed = 0
	var h: Dictionary = game.house()
	var r: Dictionary = h["ruler"]
	custom_name.text = str(r["name"])
	custom_house.text = str(h["name"])
	custom_gender.select(1 if str(r["gender"]) == "f" else 0)
	custom_age.set_value_no_signal(int(r["age"]))
	custom_layer.visible = true
	_refresh_customizer()
	refresh()

func _refresh_customizer() -> void:
	if game == null or custom_portrait_preview == null:
		return
	var h: Dictionary = game.house()
	var r: Dictionary = h["ruler"]
	var pcount: int = custom_portrait_buttons.size()
	var ccount: int = custom_crest_buttons.size()
	var pidx: int = posmod(int(r.get("portrait", 0)), maxi(1, pcount))
	var cidx: int = posmod(int(h.get("crest", game.player)), maxi(1, ccount))
	if not PORTRAITS.is_empty():
		custom_portrait_preview.texture = PORTRAITS[pidx % PORTRAITS.size()]
	var custom_tex := _house_crest_texture(h)
	if custom_tex != null:
		custom_crest_preview.texture = custom_tex
	elif not CRESTS.is_empty():
		custom_crest_preview.texture = CRESTS[cidx % CRESTS.size()]
	custom_color_swatch.color = h.get("color", Color(0.68, 0.30, 0.20))
	for i in pcount:
		custom_portrait_buttons[i].button_pressed = (i == pidx)
	for i in ccount:
		custom_crest_buttons[i].button_pressed = (i == cidx and custom_tex == null)
	for key in custom_stat_labels.keys():
		custom_stat_labels[key].text = str(int(r.get(key, 8)))
	custom_status.text = "%s · %s · %d Jahre · Wappen %d" % [r.get("name", ""), "Frau" if str(r.get("gender", "m")) == "f" else "Mann", int(r.get("age", 25)), cidx + 1]

func _custom_name_changed(value: String) -> void:
	if game == null or value.strip_edges() == "":
		return
	game.house()["ruler"]["name"] = value.strip_edges()
	_refresh_customizer()
	refresh()

func _custom_house_changed(value: String) -> void:
	if game == null or value.strip_edges() == "":
		return
	game.house()["name"] = value.strip_edges()
	refresh()

func _custom_gender_changed(index: int) -> void:
	if game == null:
		return
	game.house()["ruler"]["gender"] = "f" if index == 1 else "m"
	_refresh_customizer()
	refresh()

func _custom_age_changed(value: float) -> void:
	if game == null:
		return
	game.house()["ruler"]["age"] = clampi(int(value), 16, 90)
	_refresh_customizer()
	refresh()

func _custom_adjust(key: String, delta: int) -> void:
	if game == null:
		return
	var r: Dictionary = game.house()["ruler"]
	r[key] = clampi(int(r.get(key, 8)) + delta, 3, 20)
	_refresh_customizer()
	refresh()

func _custom_set_portrait(index: int) -> void:
	if game == null:
		return
	game.house()["ruler"]["portrait"] = index
	_refresh_customizer()
	refresh()

func _custom_set_crest(index: int) -> void:
	if game == null:
		return
	if index < 9:
		game.house().erase("crest_file")
	game.house()["crest"] = index
	_refresh_customizer()
	refresh()

func _custom_set_color(col: Color) -> void:
	if game == null:
		return
	game.house()["color"] = col
	_refresh_customizer()
	refresh()

func _custom_apply() -> void:
	if game == null:
		_close_customizer(false)
		return
	if custom_name.text.strip_edges() == "":
		custom_name.text = "Ari"
		game.house()["ruler"]["name"] = "Ari"
	if custom_house.text.strip_edges() == "":
		custom_house.text = "Haus Neu"
		game.house()["name"] = "Haus Neu"
	game.note("Herrscher, Wappen und Hausfarbe wurden angepasst.")
	_close_customizer(false)

func _custom_cancel() -> void:
	_close_customizer(true)

func _open_banner_generator() -> void:
	if game == null or game.game_over or banner_generator == null:
		return
	if banner_generator.visible:
		return
	banner_prev_speed = int(game.speed)
	game.speed = 0
	banner_generator.open(game.house())

func _on_banner_closed() -> void:
	if game != null and custom_layer != null and not custom_layer.visible:
		game.speed = banner_prev_speed

func _on_banner_applied(design: Dictionary) -> void:
	if game == null:
		return
	var h: Dictionary = game.house()
	h["banner"] = design.duplicate(true)
	h["crest"] = 9
	var img: Image = await banner_generator.render_design(design, Vector2i(256, 320))
	if img != null:
		var path := "user://wappen_custom.png"
		if img.save_png(path) == OK:
			h["crest_file"] = path
			var tex := ImageTexture.create_from_image(img)
			while CRESTS.size() <= 9:
				CRESTS.append(null)
			CRESTS[9] = tex
			if map_view != null:
				map_view.set_crest_texture(9, tex)
	game.note("%s: Ein neues Hauswappen wird angenommen." % h["name"])
	if not custom_layer.visible:
		game.speed = banner_prev_speed
	refresh()
	if custom_layer.visible:
		_refresh_customizer()

func _house_crest_texture(h: Dictionary) -> Texture2D:
	var ci: int = int(h.get("crest", -1))
	var path := str(h.get("crest_file", ""))
	if path == "":
		return null
	_ensure_custom_crest(h)
	if ci >= 0 and ci < CRESTS.size() and CRESTS[ci] != null:
		return CRESTS[ci]
	return null

func _ensure_custom_crest(h: Dictionary) -> void:
	var path := str(h.get("crest_file", ""))
	var ci: int = int(h.get("crest", -1))
	if path == "" or ci < 0:
		return
	if ci < CRESTS.size() and CRESTS[ci] != null:
		return
	if not FileAccess.file_exists(path):
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return
	var tex := ImageTexture.create_from_image(img)
	while CRESTS.size() <= ci:
		CRESTS.append(null)
	CRESTS[ci] = tex
	if map_view != null:
		map_view.set_crest_texture(ci, tex)

func _close_customizer(restore: bool) -> void:
	if custom_layer == null:
		return
	if restore and game != null and not custom_snapshot.is_empty():
		game.houses[game.player] = custom_snapshot.duplicate(true)
	custom_snapshot = {}
	custom_layer.visible = false
	kernel.pop_modal("customizer")
	if game != null:
		game.speed = custom_prev_speed
		refresh()

func _field(placeholder: String, fallback: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = placeholder
	e.placeholder_text = fallback
	e.add_theme_stylebox_override("normal", _field_style())
	e.add_theme_stylebox_override("focus", _field_style())
	e.add_theme_color_override("font_color", ModernInterfaceScript.readable(INK))
	e.add_theme_color_override("caret_color", ModernInterfaceScript.readable(INK))
	e.add_theme_color_override("font_placeholder_color", ModernInterfaceScript.readable(INK_SOFT))
	e.add_theme_font_size_override("font_size", 15)
	return e

func _stat_name(key: String) -> String:
	match key:
		"martial": return "Kriegskunst"
		"diplomacy": return "Diplomatie"
		"stewardship": return "Verwaltung"
		"intrigue": return "Intrige"
	return key

func _show_newgame() -> void:
	if start_layer == null:
		return
	kernel.push_modal("new_game")
	if newgame_layer != null:
		newgame_layer.visible = true
	if title_status != null:
		title_status.text = ""

func _hide_newgame() -> void:
	kernel.pop_modal("new_game")
	if newgame_layer != null:
		newgame_layer.visible = false

func _load_from_title() -> void:
	if not FileAccess.file_exists("user://spielstand.json"):
		if title_status != null:
			title_status.text = "Kein Spielstand gefunden."
		return
	var previous = game
	game = GameScript.new(DataScript, 0)
	kernel.bind_game(game)
	if _load():
		start_layer.visible = false
		if newgame_layer != null:
			newgame_layer.visible = false
	else:
		game = previous
		kernel.bind_game(game)
		if title_status != null:
			title_status.text = "Spielstand konnte nicht geladen werden."

func _quit_game() -> void:
	if game != null:
		_request_quit()
	else:
		_finish_quit()

func _show_start() -> void:
	for c in start_box.get_children():
		c.queue_free()
	var all_houses: Array = DataScript.houses()
	var all_provinces: Array = DataScript.provinces()
	for i in all_houses.size():
		var h: Dictionary = all_houses[i]
		var count := 0
		for p in all_provinces:
			if int(p["owner"]) == i:
				count += 1
		var b := _button("%s  ·  %s  ·  %d Provinzen  ·  %d Gold" % [
			h["name"], h["ruler"]["name"], count, int(h["gold"])
		], Callable(self, "_start").bind(i), "")
		b.custom_minimum_size = Vector2(0, 42)
		if i < CRESTS.size():
			b.icon = CRESTS[i]
			b.add_theme_constant_override("icon_max_width", 26)
		start_box.add_child(b)
	start_layer.visible = true
	if court_layer != null:
		court_layer.visible = false
	if faith_layer != null:
		faith_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	if title_status != null:
		title_status.text = ""
	kernel.set_base_modal("start")

func _show_create() -> void:
	kernel.push_modal("create")
	create_layer.visible = true

func _hide_create() -> void:
	kernel.pop_modal("create")
	create_layer.visible = false

func _adjust(key: String, delta: int) -> void:
	var v: int = int(stat_values[key])
	if delta > 0 and stat_points > 0 and v < 20:
		stat_values[key] = v + 1
		stat_points -= 1
	elif delta < 0 and v > 3:
		stat_values[key] = v - 1
		stat_points += 1
	_update_points()

func _update_points() -> void:
	points_label.text = "Punkte übrig: %d" % stat_points
	for k in stat_labels.keys():
		stat_labels[k].text = str(stat_values[k])

func _create_begin() -> void:
	var ruler: String = edit_ruler.text.strip_edges()
	if ruler == "":
		ruler = "Ari"
	var house_name: String = edit_house.text.strip_edges()
	if house_name == "":
		house_name = "Haus Neu"
	var land: String = edit_land.text.strip_edges()
	var pid: String = str(create_home.get_item_metadata(create_home.selected))
	var cfg := {
		"ruler": ruler, "house": house_name, "land": land,
		"gender": "m" if create_sex.selected == 0 else "f",
		"province": pid, "color": randi_range(0, 8), "crest": randi_range(0, 8),
		"martial": stat_values["martial"], "diplomacy": stat_values["diplomacy"],
		"stewardship": stat_values["stewardship"], "intrigue": stat_values["intrigue"],
	}
	game = GameScript.new(DataScript, 0, cfg)
	game.speed = clampi(int(settings["start_speed"]), 0, 3)
	kernel.bind_game(game)
	kernel.set_base_modal("game")
	selected = ""
	map_view.select("")
	create_layer.visible = false
	start_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	pick_layer.visible = false
	tree_layer.visible = false
	rule_layer.visible = false
	if court_layer != null:
		court_layer.visible = false
	if faith_layer != null:
		faith_layer.visible = false
	if custom_layer != null:
		custom_layer.visible = false
	refresh()

func _start(index: int) -> void:
	game = GameScript.new(DataScript, index)
	game.speed = clampi(int(settings["start_speed"]), 0, 3)
	kernel.bind_game(game)
	kernel.set_base_modal("game")
	selected = ""
	map_view.select("")
	start_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	create_layer.visible = false
	pick_layer.visible = false
	tree_layer.visible = false
	rule_layer.visible = false
	if court_layer != null:
		court_layer.visible = false
	if faith_layer != null:
		faith_layer.visible = false
	if custom_layer != null:
		custom_layer.visible = false
	refresh()

# --- Aktionen ------------------------------------------------------------

func _map_mode_title(mode: String) -> String:
	return {
		"political": "Politik", "terrain": "Gelände", "duchy": "Titel",
		"kingdom": "Reiche", "development": "Entwicklung", "war": "Krieg",
	}.get(mode, "Politik")

func _set_map_mode(mode: String) -> void:
	if map_view == null:
		return
	map_view.set_mode(mode)
	_sync_map_mode_buttons()
	map_view.queue_redraw()

func _on_map_mode_changed(mode: String) -> void:
	_sync_map_mode_buttons()
	if map_view != null and map_view.selected != "":
		refresh()

func _sync_map_mode_buttons() -> void:
	if map_view == null:
		return
	for mode in map_mode_buttons.keys():
		var b: Button = map_mode_buttons[mode]
		b.button_pressed = str(mode) == map_view.map_mode
	_refresh_map_header()

func _on_province_selected(id: String) -> void:
	kernel.select_province(id)
	selected = kernel.selection
	if map_view != null and map_view.selected != selected:
		map_view.select(selected)
	refresh()

func _on_province_activated(id: String) -> void:
	if id != "" and selected == id:
		_show_province()

func _on_atlas_location_selected(_record: Dictionary) -> void:
	_refresh_map_header()

func _toggle_map_legend() -> void:
	if map_view == null:
		return
	map_view.legend_visible = not map_view.legend_visible
	map_view.queue_redraw()
	if legend_button != null:
		legend_button.set_pressed_no_signal(map_view.legend_visible)

func _toggle_side_panel() -> void:
	if side_panel == null:
		return
	_side_hidden = not _side_hidden
	side_panel.visible = not _side_hidden
	if side_toggle_btn != null:
		side_toggle_btn.set_pressed_no_signal(not _side_hidden)

func _refresh_map_header() -> void:
	if map_header_title == null or map_view == null:
		return
	map_header_title.text = "ATLAS · EUROPA · %s" % _map_mode_title(str(map_view.map_mode)).to_upper()
	if game == null:
		return
	if top_world_label != null:
		top_world_label.text = "BANGER QUEENS · %s" % ("%d v. Chr." % -game.year if game.year < 0 else "%d n. Chr." % game.year)
	if selected != "":
		var p: Dictionary = game.province(selected)
		if not p.is_empty():
			if not map_view.atlas_location.is_empty():
				map_header_meta.text = "%s · Referenzort\nHerrschaft: %s · Spielgebiet %s" % [map_view.atlas_location, str(game.houses[int(p["owner"])]["name"]), str(p["name"])]
				return
			map_header_meta.text = "%s · %s\n%s · Entw. %d · Aufgebot %d" % [
				str(p["name"]), str(game.houses[int(p["owner"])]["name"]),
				str(p.get("terrain_name", "Ebenen")), int(p.get("dev", 1)), int(p.get("levy", 0)),
			]
			return
	var h: Dictionary = game.house()
	map_header_meta.text = "%d Grafschaften · %d Königreiche · %d Reiche\nHaus %s · %s" % [
		game.provinces.size(), _count_distinct("kingdom"), _count_distinct("empire"),
		str(h.get("name", "Haus")), str(game.date_text()),
	]

func _count_distinct(key: String) -> int:
	var seen := {}
	if game == null:
		return 0
	for p in game.provinces:
		seen[str(p.get(key, ""))] = true
	return seen.size()

func _set_speed(value: int) -> void:
	_dispatch({"id": "set_speed", "value": value})

func _dispatch(command: Dictionary) -> Dictionary:
	var result: Dictionary = kernel.dispatch(command)
	refresh()
	return result

func _open_picker(kind: String) -> void:
	if game == null or game.game_over:
		return
	pick_kind = kind
	var vm: Dictionary = ViewModelBuilder.picker(game, kind)
	pick_title.text = str(vm["title"])
	for c in pick_box.get_children():
		pick_box.remove_child(c)
		c.queue_free()
	for opt in vm["options"]:
		var i: int = int(opt["index"])
		var b := _button(str(opt["text"]), Callable(self, "_pick").bind(kind, i), "")
		if i < CRESTS.size():
			b.icon = CRESTS[i]
			b.add_theme_constant_override("icon_max_width", 24)
		b.disabled = not bool(opt["enabled"])
		pick_box.add_child(b)
	kernel.push_modal("picker")
	pick_layer.visible = true

func _hide_picker() -> void:
	kernel.pop_modal("picker")
	pick_layer.visible = false

func _pick(kind: String, target: int) -> void:
	if game == null:
		return
	_hide_picker()
	_dispatch({"id": kind, "target": target})

func _show_tree() -> void:
	if game == null:
		return
	kernel.push_modal("family_tree")
	tree_layer.visible = true
	_refresh_tree()

func _hide_tree() -> void:
	kernel.pop_modal("family_tree")
	tree_layer.visible = false

func _refresh_tree() -> void:
	if game == null:
		return
	var vm: Dictionary = ViewModelBuilder.tree(game)
	tree_title.text = str(vm["title"])
	tree_view.set_house(game, game.player)
	for c in tree_list.get_children():
		tree_list.remove_child(c)
		c.queue_free()
	tree_list.add_child(_label("Erbfolge", 18, INK))
	var order: Array = vm["order"]
	if order.is_empty():
		var empty := _label("Keine Nachkommen. Stirbt der Herrscher, erlischt das Haus.", 12, INK_SOFT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tree_list.add_child(empty)
	else:
		for i in order.size():
			var child: Dictionary = order[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			if not PORTRAITS.is_empty():
				var mini := TextureRect.new()
				mini.texture = PORTRAITS[int(child.get("portrait", 0)) % PORTRAITS.size()]
				mini.custom_minimum_size = Vector2(38, 48)
				mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(mini)
			var txt := VBoxContainer.new()
			txt.add_theme_constant_override("separation", 0)
			txt.add_child(_label("%d. %s" % [i + 1, child["name"]], 14, INK))
			txt.add_child(_label("%d Jahre · %s" % [int(child["age"]), "Erbe" if i == 0 else "nachrangig"], 11, INK_SOFT))
			row.add_child(txt)
			tree_list.add_child(row)
	tree_list.add_child(HSeparator.new())
	tree_list.add_child(_label(str(vm["spouse"]), 12, INK_SOFT))
	tree_list.add_child(_label(str(vm["ruler"]), 12, INK_SOFT))
	tree_list.add_child(_label(str(vm["law"]), 11, INK_SOFT))

func _write_save() -> bool:
	if game == null:
		return false
	var f := FileAccess.open("user://spielstand.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(game.snapshot()))
	f.close()
	return true

func _save() -> Dictionary:
	if game == null:
		return {"ok": false, "code": "invalid", "message": "Kein Spiel aktiv.", "delta": {}, "refresh": []}
	if not _write_save():
		game.note("Speichern fehlgeschlagen.")
		refresh()
		return {"ok": false, "code": "blocked", "message": "Speichern fehlgeschlagen.", "delta": {}, "refresh": []}
	game.note("Spielstand gespeichert.")
	refresh()
	return {"ok": true, "code": "ok", "message": "Spielstand gespeichert.", "delta": {}, "refresh": []}

func _load() -> bool:
	if game == null:
		return false
	if not FileAccess.file_exists("user://spielstand.json"):
		game.note("Kein Spielstand gefunden.")
		refresh()
		return false
	var f := FileAccess.open("user://spielstand.json", FileAccess.READ)
	if f == null:
		game.note("Laden fehlgeschlagen.")
		refresh()
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		game.note("Spielstand ist beschädigt.")
		refresh()
		return false
	if not game.restore(parsed):
		refresh()
		return false
	kernel.bind_game(game)
	kernel.set_base_modal("game")
	selected = ""
	map_view.select("")
	event_layer.visible = false
	tree_layer.visible = false
	rule_layer.visible = false
	if court_layer != null:
		court_layer.visible = false
	if faith_layer != null:
		faith_layer.visible = false
	if custom_layer != null:
		custom_layer.visible = false
	start_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	if province_layer != null:
		province_layer.visible = false
	if options_layer != null:
		options_layer.visible = false
	if quit_layer != null:
		quit_layer.visible = false
	game.note("Spielstand geladen.")
	refresh()
	return true

func _choose(index: int) -> void:
	_dispatch({"id": "apply_event", "option": index})
	_hide_event()

func _hide_event() -> void:
	kernel.pop_modal("event")
	event_layer.visible = false

# --- Anzeige -------------------------------------------------------------

func refresh() -> void:
	if game == null:
		return
	var h: Dictionary = game.house()
	_ensure_custom_crest(h)
	map_view.set_game(game)
	map_view.queue_redraw()
	var vm: Dictionary = ViewModelBuilder.refresh(game, selected)
	date_label.text = str(vm["date"])
	gold_label.text = str(vm["gold"])
	prestige_label.text = str(vm["prestige"])
	renown_label.text = str(vm["renown"])
	for i in speed_buttons.size():
		var b: Button = speed_buttons[i]
		b.modulate = Color.WHITE
		b.set_pressed_no_signal(int(vm["speed"]) == i)

	var custom_tex := _house_crest_texture(h)
	if custom_tex != null:
		crest_rect.texture = custom_tex
	elif not CRESTS.is_empty():
		crest_rect.texture = CRESTS[posmod(int(h.get("crest", game.player)), CRESTS.size())]
	if not PORTRAITS.is_empty():
		portrait_rect.texture = PORTRAITS[int(h["ruler"]["portrait"]) % PORTRAITS.size()]

	title_label.text = str(vm["title"])
	info_label.text = str(vm["info"])
	family_label.text = str(vm["family"])
	hint_label.text = str(vm["hint"])
	if top_crest != null:
		top_crest.texture = crest_rect.texture
	if top_realm_label != null:
		top_realm_label.text = str(vm["title"])
	_refresh_map_header()

	var buttons: Dictionary = vm["buttons"]
	develop_btn.disabled = not bool(buttons["develop"])
	recruit_btn.disabled = not bool(buttons["recruit"])
	attack_btn.disabled = not bool(buttons["attack"])
	court_btn.disabled = not bool(buttons["court"])
	marry_btn.disabled = not bool(buttons["marry"])
	seduce_btn.disabled = not bool(buttons["seduce"])
	murder_btn.disabled = not bool(buttons["murder"])
	kidnap_btn.disabled = not bool(buttons["kidnap"])
	bed_btn.disabled = not bool(buttons["bed"])
	ransom_btn.visible = bool(buttons["ransom_visible"])
	force_btn.visible = bool(buttons["force_visible"])
	ransom_btn.disabled = not bool(buttons["ransom"])
	force_btn.disabled = not bool(buttons["force"])

	var log_lines: PackedStringArray = str(vm["log"]).split("\n")
	log_label.text = str(log_lines[log_lines.size() - 1]) if not log_lines.is_empty() else ""
	log_label.tooltip_text = str(vm["log"])
	if bool(vm["has_event"]) and not event_layer.visible:
		_show_event()
	if tree_layer.visible:
		_refresh_tree()
	if rule_layer != null and rule_layer.visible:
		_refresh_rule()
	if court_layer != null and court_layer.visible:
		_refresh_court()
	if faith_layer != null and faith_layer.visible:
		_refresh_faith()
	over_layer.visible = bool(vm["game_over"])
	_refresh_province_side()
	_refresh_province_page()
	_refresh_infrastructure()
	if has_meta("modern_interface"):
		get_meta("modern_interface").refresh_summary()
	if chronicle_layer != null and chronicle_layer.visible:
		_fill_chronicle()

func _build_infrastructure_layer() -> void:
	infrastructure_layer = Control.new()
	infrastructure_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	infrastructure_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	infrastructure_layer.visible = false
	add_child(infrastructure_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	infrastructure_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.55
	panel.anchor_top = 0.03
	panel.anchor_right = 0.99
	panel.anchor_bottom = 0.97
	panel.add_theme_stylebox_override("panel", _card_style(16))
	infrastructure_layer.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := _label("Forschung & Verkehrswege", 21, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	var close := _button("Schließen", _hide_infrastructure, "")
	close.custom_minimum_size.y = 48
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	infrastructure_body = VBoxContainer.new()
	infrastructure_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infrastructure_body.add_theme_constant_override("separation", 12)
	scroll.add_child(infrastructure_body)

func _show_infrastructure() -> void:
	if game == null:
		return
	kernel.push_modal("infrastructure")
	_refresh_infrastructure()
	move_child(infrastructure_layer, get_child_count() - 1)
	infrastructure_layer.visible = true

func _hide_infrastructure() -> void:
	kernel.pop_modal("infrastructure")
	infrastructure_layer.visible = false

func _refresh_infrastructure() -> void:
	var research: Dictionary = game.house().research
	var active := str(research.active)
	if active == "":
		research_label.text = "Wissen entwickeln und Verkehrswege auf der Karte bauen. Straßenhandel: +%d Gold/Jahr." % game.road_income()
	else:
		var info: Dictionary = GameScript.InfrastructureScript.INNOVATIONS[active]
		research_label.text = "%s · noch %d Monate · %d von %d Monaten abgeschlossen" % [info.name, research.months, int(info.months) - int(research.months), info.months]
	if game.calendar_index() >= 50399 and not game.campaign_sandbox:
		research_label.text = "Die Kampagnenzeit bis 2200 ist erreicht. Mit ‚Als Sandbox fortsetzen‘ läuft dein Spielstand weiter."
	for choice in game.research_choices():
		var button: Button = research_buttons[choice.id]
		button.text = "%s · %d Gold · %d Monate" % [choice.name, choice.gold, choice.months]
		if research.known.has(choice.id):
			button.text = str(choice.name) + " · Erforscht"
		button.disabled = str(choice.reason) != ""
		button.tooltip_text = str(choice.reason)
	for child in road_buttons.get_children():
		road_buttons.remove_child(child)
		child.queue_free()
	var province: Dictionary = game.province(selected)
	if province.is_empty():
		var select_hint := _label("Wähle auf der Karte eine eigene Provinz. Hier erscheinen anschließend baubare Verbindungen zu deinen Nachbarn.", 14, INK_SOFT)
		select_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		road_buttons.add_child(select_hint)
	if not province.is_empty() and int(province.owner) == game.player:
		for neighbor_id in game.neighbours(selected):
			var neighbor: Dictionary = game.province(str(neighbor_id))
			if neighbor.is_empty() or int(neighbor.owner) != game.player:
				continue
			var target := str(neighbor_id)
			var reason: String = game.road_blocker(selected, target)
			var button := _button("Straße nach %s · 30 Gold" % neighbor.name, func(): _dispatch({"id": "road", "to": target}), "gold")
			button.custom_minimum_size.y = 48
			button.set_meta("to", target)
			button.disabled = reason != ""
			button.tooltip_text = reason if reason != "" else "Bauzeit: 3 Monate. Danach +2 Gold jährlich bei gemeinsamem Besitz."
			road_buttons.add_child(button)
			if reason != "":
				var explanation := _label(reason, 12, INK_SOFT)
				explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				road_buttons.add_child(explanation)
	for road in game.road_segments():
		if int(road.builder) != game.player:
			continue
		var state: String = "Fertig" if road.state == "complete" else "Bau: noch %d Monate" % road.months
		if road.state == "building" and (int(game.province(str(road.from)).owner) != game.player or int(game.province(str(road.to)).owner) != game.player):
			state = "Bau pausiert · Besitz verloren"
		var label := _label("%s – %s\n%s" % [game.province(str(road.from)).name, game.province(str(road.to)).name, state], 12, INK_SOFT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		road_buttons.add_child(label)
	sandbox_button.visible = game.calendar_index() >= 50399 and not game.campaign_sandbox

func _build_rule_layer() -> void:
	rule_layer = Control.new()
	rule_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rule_layer.visible = false
	rule_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rule_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	rule_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rule_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	card.add_theme_stylebox_override("panel", _card_style(14))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	rule_title = _label("Herrschaft", 24, INK)
	rule_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rule_title)
	var close := _button("Schließen", _hide_rule, "")
	close.custom_minimum_size = Vector2(120, 38)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	rule_body = VBoxContainer.new()
	rule_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_body.add_theme_constant_override("separation", 6)
	scroll.add_child(rule_body)

func _build_court_layer() -> void:
	court_layer = Control.new()
	court_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	court_layer.visible = false
	court_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(court_layer)
	var art := TextureRect.new()
	art.texture = TEX_COURT
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court_layer.add_child(art)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.015, 0.44)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	court_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	court_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 0)
	var card_style: StyleBoxFlat = _card_style(16)
	card_style.content_margin_top = 22
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(850, 0)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	court_title = _label("Hof & Reliquien", 24, INK)
	court_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(court_title)
	var close := _button("Schließen", _hide_court, "")
	close.custom_minimum_size = Vector2(120, 38)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 550)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	court_body = VBoxContainer.new()
	court_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	court_body.add_theme_constant_override("separation", 6)
	scroll.add_child(court_body)

func _show_court() -> void:
	if game == null:
		return
	kernel.push_modal("hof")
	court_layer.visible = true
	_refresh_court()
	_play_open()

func _hide_court() -> void:
	kernel.pop_modal("hof")
	if court_layer != null:
		court_layer.visible = false
	if faith_layer != null:
		faith_layer.visible = false

func _clear_court_body() -> void:
	court_hall_preview = null
	court_hall_stage_label = null
	court_hall_stats_label = null
	court_hall_pips = null
	court_expectation_label = null
	court_expectation_track = null
	court_amenity_pips = []
	court_amenity_buttons = {}
	for child in court_body.get_children():
		court_body.remove_child(child)
		child.queue_free()

func _refresh_court() -> void:
	if game == null or court_body == null:
		return
	_clear_court_body()
	var vm: Dictionary = ViewModelBuilder.court(game)
	court_title.text = str(vm["title"])
	court_body.add_child(_label(str(vm["summary"]), 14, INK_SOFT))
	court_body.add_child(_label(str(vm["benefit"]), 12, INK_SOFT))
	court_body.add_child(HSeparator.new())
	court_body.add_child(_label("Reliquien", 18, INK))
	court_body.add_child(_label("Jede Reliquie ist einzigartig. Schmieden kostet Gold und Prestige; die Wirkung bleibt dauerhaft.", 11, INK_SOFT))
	for relic in vm["relics"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(58, 58)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = TOKENS.get(str(relic["icon"]))
		icon.tooltip_text = "Reliquien-Token aus der Blender-Pipeline"
		row.add_child(icon)
		var text := _label("%s\n%s" % [str(relic["name"]), str(relic["effect"])], 12, INK_SOFT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		var forge := _button(str(relic["button_text"]), Callable(self, "_forge_relic").bind(str(relic["id"])), "")
		forge.custom_minimum_size = Vector2(190, 40)
		forge.disabled = bool(relic["disabled"])
		row.add_child(forge)
		court_body.add_child(row)
	court_body.add_child(HSeparator.new())
	var hall_row := HBoxContainer.new()
	hall_row.name = "HofhallenVorschau"
	hall_row.add_theme_constant_override("separation", 14)
	var frame_style := _flat(Color(0.08, 0.06, 0.04, 0.96), Color(0.55, 0.40, 0.20), 2)
	frame_style.content_margin_left = 4
	frame_style.content_margin_right = 4
	frame_style.content_margin_top = 4
	frame_style.content_margin_bottom = 4
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(390, 240)
	frame.add_theme_stylebox_override("panel", frame_style)
	hall_row.add_child(frame)
	var preview_stack := Control.new()
	preview_stack.custom_minimum_size = Vector2(382, 232)
	preview_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(preview_stack)
	court_hall_preview = TextureRect.new()
	court_hall_preview.texture = TEX_COURT
	court_hall_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	court_hall_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	court_hall_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	court_hall_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stack.add_child(court_hall_preview)
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_left = 6
	overlay.offset_top = -70
	overlay.offset_right = -6
	overlay.offset_bottom = -6
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_style := _flat(Color(0.03, 0.02, 0.012, 0.86), Color(0.62, 0.46, 0.24, 0.9), 1)
	overlay_style.content_margin_left = 6
	overlay_style.content_margin_right = 6
	overlay_style.content_margin_top = 4
	overlay_style.content_margin_bottom = 4
	overlay.add_theme_stylebox_override("panel", overlay_style)
	preview_stack.add_child(overlay)
	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 2)
	overlay.add_child(overlay_box)
	court_expectation_label = _label(str(vm["expectation_text"]), 10, Color(1.0, 0.89, 0.63))
	overlay_box.add_child(court_expectation_label)
	court_expectation_track = Control.new()
	court_expectation_track.custom_minimum_size = Vector2(0, 7)
	court_expectation_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_box.add_child(court_expectation_track)
	var track_bg := ColorRect.new()
	track_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_bg.color = Color(0.16, 0.12, 0.07, 0.95)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court_expectation_track.add_child(track_bg)
	var corridor := ColorRect.new()
	corridor.anchor_left = clampf(float(int(vm["expected"]) - 5) / 100.0, 0.0, 1.0)
	corridor.anchor_right = clampf(float(int(vm["expected"]) + 5) / 100.0, 0.0, 1.0)
	corridor.anchor_bottom = 1.0
	corridor.offset_top = 1
	corridor.offset_bottom = -1
	corridor.color = Color(0.78, 0.58, 0.22, 0.28)
	corridor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court_expectation_track.add_child(corridor)
	var fill := ColorRect.new()
	fill.anchor_right = clampf(float(int(vm["grandeur"])) / 100.0, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	fill.offset_top = 1
	fill.offset_bottom = -1
	fill.color = Color(0.82, 0.61, 0.23, 0.96)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court_expectation_track.add_child(fill)
	var target_marker := ColorRect.new()
	target_marker.anchor_left = clampf(float(int(vm["expected"])) / 100.0, 0.0, 1.0)
	target_marker.anchor_right = target_marker.anchor_left
	target_marker.anchor_bottom = 1.0
	target_marker.offset_left = -1
	target_marker.offset_right = 1
	target_marker.color = Color(1.0, 0.88, 0.52)
	target_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court_expectation_track.add_child(target_marker)
	var amenity_pips_row := HBoxContainer.new()
	amenity_pips_row.add_theme_constant_override("separation", 8)
	overlay_box.add_child(amenity_pips_row)
	for amenity in vm["amenities"]:
		var group := VBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_theme_constant_override("separation", 1)
		amenity_pips_row.add_child(group)
		group.add_child(_label("%s %s" % [str(amenity["name"]), str(amenity["level_text"])], 9, Color(1.0, 0.92, 0.74)))
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		for i in int(amenity["max"]):
			var pip := PanelContainer.new()
			pip.custom_minimum_size = Vector2(22, 4)
			var pip_style := _flat(Color(0.84, 0.64, 0.24, 0.96) if i < int(amenity["level"]) else Color(0.34, 0.25, 0.14, 0.8), Color(0.16, 0.11, 0.06, 0.8), 1)
			pip_style.content_margin_left = 0
			pip_style.content_margin_right = 0
			pip_style.content_margin_top = 0
			pip_style.content_margin_bottom = 0
			pip.add_theme_stylebox_override("panel", pip_style)
			pips.add_child(pip)
		group.add_child(pips)
		court_amenity_pips.append(pips)
	var hall_info := VBoxContainer.new()
	hall_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall_info.add_theme_constant_override("separation", 4)
	hall_row.add_child(hall_info)
	court_hall_stage_label = _label("Hofhalle · Stufe %d/%d" % [int(vm["hall"]), int(vm["hall_max"])], 19, INK)
	hall_info.add_child(court_hall_stage_label)
	court_hall_stats_label = _label("Hofpracht %d/100 · Reliquien %d/%d" % [
		int(vm["grandeur"]), int(vm["relics_owned"]), int(vm["relics_total"])
	], 12, INK_SOFT)
	hall_info.add_child(court_hall_stats_label)
	court_hall_pips = HBoxContainer.new()
	court_hall_pips.add_theme_constant_override("separation", 4)
	for i in int(vm["hall_max"]):
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(54, 8)
		var pip_style := _flat(Color(0.78, 0.58, 0.22, 0.96) if i < int(vm["hall"]) else Color(0.48, 0.36, 0.20, 0.34), Color(0.30, 0.20, 0.10, 0.75), 1)
		pip_style.content_margin_left = 0
		pip_style.content_margin_right = 0
		pip_style.content_margin_top = 0
		pip_style.content_margin_bottom = 0
		pip.add_theme_stylebox_override("panel", pip_style)
		court_hall_pips.add_child(pip)
	hall_info.add_child(court_hall_pips)
	hall_info.add_child(_label("Hofausstattung · %d G/Jahr Unterhalt" % int(vm["amenity_upkeep"]), 10, INK_SOFT))
	for amenity in vm["amenities"]:
		var amenity_row := HBoxContainer.new()
		amenity_row.add_theme_constant_override("separation", 6)
		var amenity_name := _label("%s %s" % [str(amenity["name"]), str(amenity["level_text"])], 11, INK)
		amenity_name.custom_minimum_size = Vector2(92, 0)
		amenity_row.add_child(amenity_name)
		var amenity_effect := _label(str(amenity["effect"]), 9, INK_SOFT)
		amenity_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amenity_effect.tooltip_text = "%s · Unterhalt %d G/Jahr" % [str(amenity["effect"]), int(amenity["upkeep"])]
		amenity_row.add_child(amenity_effect)
		var amenity_button := _button(str(amenity["button_text"]), Callable(self, "_upgrade_court_amenity").bind(str(amenity["id"])), "")
		amenity_button.custom_minimum_size = Vector2(118, 27)
		amenity_button.disabled = not bool(amenity["can_upgrade"])
		amenity_row.add_child(amenity_button)
		court_amenity_buttons[str(amenity["id"])] = amenity_button
		hall_info.add_child(amenity_row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hall_info.add_child(spacer)
	var hall_button := _button(str(vm["hall_button"]), _upgrade_court_hall, "")
	hall_button.custom_minimum_size = Vector2(0, 36)
	hall_button.disabled = bool(vm["hall_maxed"]) or not bool(vm["can_upgrade_hall"])
	hall_info.add_child(hall_button)
	court_body.add_child(hall_row)

func _forge_relic(relic_id: String) -> void:
	_dispatch({"id": "forge_relic", "relic": relic_id})

func _upgrade_court_hall() -> void:
	_dispatch({"id": "upgrade_court_hall"})

func _upgrade_court_amenity(amenity_id: String) -> void:
	_dispatch({"id": "upgrade_court_amenity", "amenity": amenity_id})

func _build_faith_layer() -> void:
	faith_layer = Control.new()
	faith_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faith_layer.visible = false
	faith_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(faith_layer)
	var art := TextureRect.new()
	art.texture = TEX_FAITH
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faith_layer.add_child(art)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.04, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	faith_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faith_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 0)
	card.add_theme_stylebox_override("panel", _card_style(16))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(850, 0)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	faith_title = _label("Glaube & Kirche", 24, INK)
	faith_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(faith_title)
	var close := _button("Schließen", _hide_faith, "")
	close.custom_minimum_size = Vector2(120, 38)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	faith_body = VBoxContainer.new()
	faith_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faith_body.add_theme_constant_override("separation", 6)
	scroll.add_child(faith_body)

func _show_faith() -> void:
	if game == null:
		return
	kernel.push_modal("glaube")
	faith_layer.visible = true
	_refresh_faith()
	_play_open()

func _hide_faith() -> void:
	kernel.pop_modal("glaube")
	if faith_layer != null:
		faith_layer.visible = false

func _clear_faith_body() -> void:
	faith_heresy_icon = null
	faith_reform_icon = null
	faith_war_marker = null
	faith_war_marker_icon = null
	faith_war_marker_label = null
	for child in faith_body.get_children():
		faith_body.remove_child(child)
		child.queue_free()

func _refresh_faith() -> void:
	if game == null or faith_body == null:
		return
	_clear_faith_body()
	var vm: Dictionary = ViewModelBuilder.faith(game)
	faith_title.text = str(vm["title"])
	faith_body.add_child(_label(str(vm["summary"]), 14, INK_SOFT))
	faith_body.add_child(_label(str(vm["benefit"]), 12, INK_SOFT))
	faith_body.add_child(HSeparator.new())
	var current: Dictionary = vm["confession"]
	var current_row := HBoxContainer.new()
	current_row.add_theme_constant_override("separation", 10)
	var current_icon := TextureRect.new()
	current_icon.custom_minimum_size = Vector2(64, 64)
	current_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	current_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	current_icon.texture = TOKENS.get(str(current.get("icon", "")))
	current_row.add_child(current_icon)
	var current_text := _label("%s · %s\n%s" % [str(current.get("name", "—")), str(current.get("doctrine", "")), str(current.get("effect", ""))], 13, INK_SOFT)
	current_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_row.add_child(current_text)
	faith_body.add_child(current_row)
	var pilgrimage := _button("Wallfahrt · %d Gold · +%d Frömmigkeit" % [int(vm["pilgrimage_cost"]), int(vm["pilgrimage_piety"])], _pilgrimage, "")
	pilgrimage.custom_minimum_size = Vector2(0, 42)
	pilgrimage.disabled = not bool(vm["can_pilgrimage"])
	faith_body.add_child(pilgrimage)
	faith_body.add_child(HSeparator.new())
	var heresy_row := HBoxContainer.new()
	heresy_row.add_theme_constant_override("separation", 10)
	faith_heresy_icon = TextureRect.new()
	faith_heresy_icon.custom_minimum_size = Vector2(64, 64)
	faith_heresy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faith_heresy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	faith_heresy_icon.texture = TOKENS.get(str(vm["heresy_icon"]))
	heresy_row.add_child(faith_heresy_icon)
	var heresy_text := _label("Ketzerei · %d/100\nJährliche Veränderung %+d. Ab 40 Ketzerei sinkt die Legitimität, ab 30 die Vasallenmeinung." % [int(vm["heresy"]), int(vm["heresy_growth"])], 12, INK_SOFT)
	heresy_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heresy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heresy_row.add_child(heresy_text)
	faith_body.add_child(heresy_row)
	var suppress := _button(str(vm["suppress_text"]), _suppress_heresy, "")
	suppress.custom_minimum_size = Vector2(0, 38)
	suppress.disabled = not bool(vm["can_suppress"])
	faith_body.add_child(suppress)
	faith_body.add_child(HSeparator.new())
	var reform_row := HBoxContainer.new()
	reform_row.add_theme_constant_override("separation", 10)
	faith_reform_icon = TextureRect.new()
	faith_reform_icon.custom_minimum_size = Vector2(60, 60)
	faith_reform_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faith_reform_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	faith_reform_icon.texture = TOKENS.get(str(vm["reform_icon"]))
	reform_row.add_child(faith_reform_icon)
	var reform_text := _label("Reformbewegung · Stufe %d/%d\nJede Stufe gibt +%d Kirchenmacht und senkt den jährlichen Ketzerei-Zuwachs um %d." % [int(vm["reform"]), int(vm["reform_max"]), game.FAITH_REFORM_POWER, game.FAITH_REFORM_HERESY_DRIFT], 12, INK_SOFT)
	reform_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reform_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reform_row.add_child(reform_text)
	faith_body.add_child(reform_row)
	var reform := _button(str(vm["reform_text"]), _reform_faith, "")
	reform.custom_minimum_size = Vector2(0, 38)
	reform.disabled = not bool(vm["can_reform"])
	faith_body.add_child(reform)
	faith_body.add_child(HSeparator.new())
	faith_body.add_child(_label("Heiliger Krieg", 18, INK))
	if int(vm["holy_war_target"]) >= 0:
		faith_war_marker = PanelContainer.new()
		faith_war_marker.custom_minimum_size = Vector2(0, 68)
		faith_war_marker.add_theme_stylebox_override("panel", _card_style(8))
		var marker_row := HBoxContainer.new()
		marker_row.add_theme_constant_override("separation", 10)
		faith_war_marker_icon = TextureRect.new()
		faith_war_marker_icon.custom_minimum_size = Vector2(60, 60)
		faith_war_marker_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		faith_war_marker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		faith_war_marker_icon.texture = TOKENS.get(str(vm["holy_war_icon"]))
		marker_row.add_child(faith_war_marker_icon)
		faith_war_marker_label = _label("Kriegsziel: %s · %s\nHauptstadt %s · noch %d Monate · Anspruch %d Monate\nSieg: +%d Prestige, +%d Legitimität." % [str(vm["holy_war_target_name"]), str(vm["holy_war_confession"]), str(vm["holy_war_capital"]), int(vm["holy_war_months"]), int(vm["holy_war_claim_months"]), game.FAITH_HOLY_WAR_PRESTIGE, game.FAITH_HOLY_WAR_LEGITIMACY], 12, INK_SOFT)
		faith_war_marker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		faith_war_marker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		marker_row.add_child(faith_war_marker_label)
		faith_war_marker.add_child(marker_row)
		faith_body.add_child(faith_war_marker)
	else:
		faith_body.add_child(_label("Ein heiliger Krieg erhebt Anspruch auf die Hauptstadt eines Andersgläubigen oder Ketzers und nutzt die bestehenden Kriegskanten K1/K2.", 11, INK_SOFT))
	for target in vm["holy_war_targets"]:
		var war_row := HBoxContainer.new()
		war_row.add_theme_constant_override("separation", 8)
		var war_icon := TextureRect.new()
		war_icon.custom_minimum_size = Vector2(42, 42)
		war_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		war_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		war_icon.texture = TOKENS.get(str(target["icon"]))
		war_row.add_child(war_icon)
		var war_text := _label("%s · %s · Hauptstadt %s · Ketzerei %d/100" % [str(target["name"]), str(target["confession"]), str(target["capital"]), int(target["heresy"])], 11, INK_SOFT)
		war_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		war_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		war_row.add_child(war_text)
		var war_button := _button(str(target["button_text"]), Callable(self, "_declare_holy_war").bind(int(target["index"])), "")
		war_button.custom_minimum_size = Vector2(245, 38)
		war_button.disabled = bool(target["disabled"]) or int(vm["holy_war_target"]) >= 0
		war_row.add_child(war_button)
		faith_body.add_child(war_row)
	faith_body.add_child(HSeparator.new())
	faith_body.add_child(_label("Konfessionen", 18, INK))
	faith_body.add_child(_label("Ein Wechsel kostet Gold und Prestige und beunruhigt die Vasallen.", 11, INK_SOFT))
	for confession in vm["confessions"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = TOKENS.get(str(confession["icon"]))
		row.add_child(icon)
		var text := _label("%s · %s\n%s" % [str(confession["name"]), str(confession["doctrine"]), str(confession["effect"])], 12, INK_SOFT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		var change := _button(str(confession["button_text"]), Callable(self, "_convert_faith").bind(str(confession["id"])), "")
		change.custom_minimum_size = Vector2(185, 40)
		change.disabled = bool(confession["disabled"])
		row.add_child(change)
		faith_body.add_child(row)
	faith_body.add_child(HSeparator.new())
	faith_body.add_child(_label("Heilige Stätten · %d/%d" % [int(vm["sites"].size()), int(game.FAITH_MAX_SITES)], 18, INK))
	if vm["sites"].is_empty():
		faith_body.add_child(_label("Noch keine Stätte geweiht. Jede Stätte gibt jährlich Prestige und Kirchenmacht.", 11, INK_SOFT))
	else:
		for site in vm["sites"]:
			faith_body.add_child(_label("◆ %s" % str(site["name"]), 12, INK_SOFT))
	var options_title := _label("Eigene Provinzen weihen · %d Gold · %d Frömmigkeit" % [int(vm["site_cost_gold"]), int(vm["site_cost_piety"])], 12, INK_SOFT)
	faith_body.add_child(options_title)
	for option in vm["site_options"]:
		var option_row := HBoxContainer.new()
		option_row.add_theme_constant_override("separation", 8)
		var name_label := _label(str(option["name"]), 12, INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_row.add_child(name_label)
		var consecrate := _button(str(option["button_text"]), Callable(self, "_consecrate_site").bind(str(option["id"])), "")
		consecrate.custom_minimum_size = Vector2(190, 38)
		consecrate.disabled = bool(option["disabled"])
		option_row.add_child(consecrate)
		faith_body.add_child(option_row)

func _pilgrimage() -> void:
	_dispatch({"id": "pilgrimage"})

func _convert_faith(confession: String) -> void:
	_dispatch({"id": "convert_faith", "confession": confession})

func _consecrate_site(province_id: String) -> void:
	_dispatch({"id": "consecrate_site", "province": province_id})

func _suppress_heresy() -> void:
	_dispatch({"id": "suppress_heresy"})

func _reform_faith() -> void:
	_dispatch({"id": "reform_faith"})

func _declare_holy_war(target: int) -> void:
	_dispatch({"id": "declare_holy_war", "target": target})

func _show_rule() -> void:
	if game == null:
		return
	kernel.push_modal("herrschaft")
	rule_layer.visible = true
	_refresh_rule()

func _hide_rule() -> void:
	kernel.pop_modal("herrschaft")
	if rule_layer != null:
		rule_layer.visible = false

func _clear_rule_body() -> void:
	for child in rule_body.get_children():
		rule_body.remove_child(child)
		child.queue_free()

func _refresh_rule() -> void:
	if game == null or rule_body == null:
		return
	_clear_rule_body()
	var vm: Dictionary = ViewModelBuilder.rule(game, selected)
	rule_title.text = str(vm["title"])
	rule_body.add_child(_label(str(vm["summary"]), 13, INK_SOFT))
	rule_body.add_child(_label(str(vm["faction"]), 12, INK_SOFT))
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Vasallenverträge", 18, INK))
	rule_body.add_child(_label("Steuern %d Gold/Jahr · Aufgebot +%d · durchschnittliche Meinung %d" % [
		int(vm["vassal_tax"]), int(vm["vassal_levy"]), int(vm["vassal_opinion"])], 11, INK_SOFT))
	for vassal in vm["vassals"]:
		var vassal_row := HBoxContainer.new()
		vassal_row.add_theme_constant_override("separation", 8)
		var contract_icon := TextureRect.new()
		contract_icon.custom_minimum_size = Vector2(46, 46)
		contract_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		contract_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contract_icon.texture = TOKENS.get(str(vassal["icon"]))
		contract_icon.tooltip_text = "Vertrags-Token aus der Blender-Pipeline"
		vassal_row.add_child(contract_icon)
		var vassal_text := _label("%s · %s Stufe %d/%d\n%s\n%s" % [
			str(vassal["name"]), str(vassal["contract"]), int(vassal["level"]), int(vassal["max"]),
			str(vassal["effect"]), str(vassal["next_effect"])], 11, INK_SOFT)
		vassal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vassal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vassal_row.add_child(vassal_text)
		var lower_button := _button(str(vassal["lower_text"]), Callable(self, "_change_vassal_contract").bind(int(vassal["index"]), int(vassal["lower_level"])), "")
		lower_button.custom_minimum_size = Vector2(78, 38)
		lower_button.disabled = not bool(vassal["can_lower"])
		vassal_row.add_child(lower_button)
		var raise_button := _button(str(vassal["raise_text"]), Callable(self, "_change_vassal_contract").bind(int(vassal["index"]), int(vassal["next_level"])), "")
		raise_button.custom_minimum_size = Vector2(142, 38)
		raise_button.disabled = not bool(vassal["can_raise"])
		vassal_row.add_child(raise_button)
		rule_body.add_child(vassal_row)
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Rat", 18, INK))
	for office in vm["offices"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var office_icon := TextureRect.new()
		office_icon.custom_minimum_size = Vector2(42, 42)
		office_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		office_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		office_icon.texture = TOKENS.get(str(office["icon"]))
		office_icon.tooltip_text = "Rats-Token aus der Blender-Pipeline"
		row.add_child(office_icon)
		var row_label := _label("%s\n%s · Stimme: %s" % [str(office["text"]), str(office["effect"]), str(office["vote"])], 12, INK_SOFT)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(row_label)
		var change := _button("Wechseln", Callable(self, "_cycle_council").bind(str(office["id"])), "")
		change.custom_minimum_size = Vector2(110, 36)
		row.add_child(change)
		rule_body.add_child(row)
	rule_body.add_child(_label(str(vm["training"]), 11, INK_SOFT))
	rule_body.add_child(_label(str(vm["council_intrigue"]), 11, INK_SOFT))
	rule_body.add_child(_label("Ratssitz-Stimmen · Mehrheit 3/4, Schlüsselamt muss zustimmen", 11, INK_SOFT))
	for resolution in vm["resolutions"]:
		var resolution_row := HBoxContainer.new()
		resolution_row.add_theme_constant_override("separation", 8)
		var resolution_icon := TextureRect.new()
		resolution_icon.custom_minimum_size = Vector2(38, 38)
		resolution_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		resolution_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		resolution_icon.texture = TOKENS.get(str(resolution["icon"]))
		resolution_row.add_child(resolution_icon)
		var resolution_text := _label("%s · %s\n%s\n%s" % [
			str(resolution["name"]), str(resolution["votes_text"]), str(resolution["effect"]), str(resolution["cost_text"])], 11, INK_SOFT)
		resolution_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resolution_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resolution_row.add_child(resolution_text)
		var enact := _button("Beschließen", Callable(self, "_enact_council_resolution").bind(str(resolution["id"])), "")
		enact.custom_minimum_size = Vector2(112, 38)
		enact.disabled = not bool(resolution["can_enact"])
		resolution_row.add_child(enact)
		rule_body.add_child(resolution_row)
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Gesetz", 18, INK))
	var law_button := _button(str(vm["law"]), _toggle_succession, "")
	rule_body.add_child(law_button)
	var tax_button := _button(str(vm["tax"]), _toggle_tax, "")
	rule_body.add_child(tax_button)
	rule_body.add_child(_label(str(vm["heir"]), 12, INK_SOFT))
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Dynastie · Ruhm %d" % int(vm["renown_value"]), 18, INK))
	rule_body.add_child(_label(str(vm["renown_hint"]), 11, INK_SOFT))
	for legacy in vm["legacies"]:
		var legacy_row := HBoxContainer.new()
		legacy_row.add_theme_constant_override("separation", 8)
		var legacy_icon := TextureRect.new()
		legacy_icon.custom_minimum_size = Vector2(46, 46)
		legacy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		legacy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		legacy_icon.texture = TOKENS.get(str(legacy["icon"]))
		legacy_icon.tooltip_text = "Vermächtnis-Token aus der Blender-Pipeline"
		legacy_row.add_child(legacy_icon)
		var legacy_text := _label("%s · Stufe %d/%d\n%s" % [str(legacy["name"]), int(legacy["level"]), int(legacy["max"]), str(legacy["effect"])], 11, INK_SOFT)
		legacy_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		legacy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		legacy_row.add_child(legacy_text)
		var legacy_button := _button(
			"Maximalstufe" if bool(legacy["maxed"]) else "Stufe %d · %d Ruhm" % [int(legacy["level"]) + 1, int(legacy["cost"])],
			Callable(self, "_unlock_legacy").bind(str(legacy["id"])), "")
		legacy_button.custom_minimum_size = Vector2(150, 42)
		legacy_button.disabled = bool(legacy["maxed"]) or bool(legacy["disabled"])
		legacy_row.add_child(legacy_button)
		rule_body.add_child(legacy_row)
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Krieg und Diplomatie", 18, INK))
	rule_body.add_child(_label(str(vm["target"]), 12, INK_SOFT))
	var claim_button := _button("Anspruch schmieden (40 Gold)", _fabricate_claim, "")
	claim_button.disabled = bool(vm["claim_disabled"])
	rule_body.add_child(claim_button)
	var army_button := _button("Armee aufstellen (50 Gold)", _raise_army, "")
	army_button.disabled = bool(vm["army_disabled"])
	rule_body.add_child(army_button)
	var siege_button := _button("Belagerung vorantreiben", _advance_siege, "")
	siege_button.disabled = bool(vm["siege_disabled"])
	rule_body.add_child(siege_button)
	var fleet_row := HBoxContainer.new()
	fleet_row.add_theme_constant_override("separation", 8)
	var fleet_icon := TextureRect.new()
	fleet_icon.custom_minimum_size = Vector2(44, 44)
	fleet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fleet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fleet_icon.texture = TOKENS.get("unit_fleet")
	fleet_icon.tooltip_text = "Flotten-Token aus der Blender-Pipeline"
	fleet_row.add_child(fleet_icon)
	var fleet_label := _label(str(vm["fleet"]), 12, INK_SOFT)
	fleet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fleet_row.add_child(fleet_label)
	rule_body.add_child(fleet_row)
	var fleet_button := _button("Flotte aufstellen (60 Gold)", _raise_fleet, "")
	fleet_button.disabled = bool(vm["fleet_disabled"])
	rule_body.add_child(fleet_button)
	var blockade_button := _button("Küste blockieren (6 Monate)", _blockade_coast, "")
	blockade_button.disabled = bool(vm["blockade_disabled"])
	rule_body.add_child(blockade_button)
	var peace_button := _button("Frieden schließen (24 Monate)", _make_peace, "")
	peace_button.disabled = bool(vm["peace_disabled"])
	rule_body.add_child(peace_button)
	var discover_button := _button("Geheimnis aufdecken", _discover_secret, "")
	discover_button.disabled = bool(vm["discover_disabled"])
	rule_body.add_child(discover_button)
	var expose_button := _button("Geheimnis ausnutzen", _expose_secret, "")
	expose_button.disabled = bool(vm["expose_disabled"])
	rule_body.add_child(expose_button)
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Bauen", 18, INK))
	if str(vm["province_text"]) == "":
		rule_body.add_child(_label(str(vm["province_hint"]), 12, INK_SOFT))
	else:
		rule_body.add_child(_label(str(vm["province_text"]), 12, INK_SOFT))
		var building_icons := HBoxContainer.new()
		building_icons.add_theme_constant_override("separation", 14)
		for building in vm["buildings"]:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(48, 48)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = load("res://assets/ui/tokens/building_%s.png" % str(building["key"]))
			icon.tooltip_text = "Gebäude-Token aus der Blender-Pipeline"
			cell.add_child(icon)
			cell.add_child(_label("%s %d/3" % [str(building["name"]), int(building["level"])], 10, INK_SOFT))
			building_icons.add_child(cell)
		rule_body.add_child(building_icons)
		for building in vm["buildings"]:
			var button := _button(str(building["text"]), Callable(self, "_build_system").bind(str(building["key"])), "")
			button.disabled = bool(building["disabled"])
			rule_body.add_child(button)
		rule_body.add_child(_label(str(vm["defense"]), 12, INK_SOFT))

func _cycle_council(office: String) -> void:
	_dispatch({"id": "council_assign", "office": office})

func _change_vassal_contract(vassal_index: int, target_level: int) -> void:
	_dispatch({"id": "vassal_contract", "vassal": vassal_index, "level": target_level})

func _enact_council_resolution(resolution_id: String) -> void:
	_dispatch({"id": "council_resolution", "resolution": resolution_id})

func _toggle_succession() -> void:
	_dispatch({"id": "law_succession"})

func _build_system(key: String) -> void:
	_dispatch({"id": "build", "key": key})

func _toggle_tax() -> void:
	_dispatch({"id": "set_tax"})

func _unlock_legacy(track: String) -> void:
	_dispatch({"id": "legacy", "track": track})

func _fabricate_claim() -> void:
	_dispatch({"id": "claim"})

func _raise_army() -> void:
	_dispatch({"id": "army"})

func _advance_siege() -> void:
	_dispatch({"id": "siege"})

func _raise_fleet() -> void:
	_dispatch({"id": "fleet"})

func _blockade_coast() -> void:
	_dispatch({"id": "blockade"})

func _make_peace() -> void:
	_dispatch({"id": "peace"})

func _discover_secret() -> void:
	_dispatch({"id": "secret_discover"})

func _expose_secret() -> void:
	_dispatch({"id": "secret_expose"})

var chronicle_layer: Control
var chronicle_body: VBoxContainer
var _chronicle_span: int = 60

func is_coastal_province(province_id: String) -> bool:
	if game == null:
		return false
	return game.is_coastal(province_id)

func _fleet_at(province_id: String) -> Dictionary:
	if game == null:
		return {}
	for h in game.houses:
		for fleet in h.get("fleets", []):
			if str(fleet.get("station", "")) == province_id:
				return fleet
	return {}

func _fleet_tokens(fleet: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = TOKENS.get("unit_fleet")
	icon.tooltip_text = "Flotte"
	row.add_child(icon)
	row.add_child(_label("%d Schiffe" % int(fleet.get("ships", 0)), 10, INK_SOFT))
	return row

func _army_tokens(strength: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var comp: Dictionary = game.army_composition(strength)
	for entry in [["levy", "Fußvolk"], ["archer", "Bogenschützen"], ["knight", "Reiterei"], ["siege", "Belagerung"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load("res://assets/ui/tokens/unit_%s.png" % str(entry[0]))
		icon.tooltip_text = str(entry[1])
		cell.add_child(icon)
		cell.add_child(_label("%s %d" % [str(entry[1]), int(comp[entry[0]])], 10, INK_SOFT))
		row.add_child(cell)
	return row

func _show_chronicle() -> void:
	if chronicle_layer == null:
		_build_chronicle_layer()
	_fill_chronicle()
	chronicle_layer.visible = true
	kernel.push_modal("chronik")

func _hide_chronicle() -> void:
	kernel.pop_modal("chronik")
	chronicle_layer.visible = false

func _build_chronicle_layer() -> void:
	chronicle_layer = Control.new()
	chronicle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chronicle_layer.visible = false
	chronicle_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chronicle_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chronicle_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chronicle_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 680)
	card.add_theme_stylebox_override("panel", _card_style(16))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("Chronik", 24, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Schließen", _hide_chronicle, ""))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(764, 590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	chronicle_body = VBoxContainer.new()
	chronicle_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chronicle_body.add_theme_constant_override("separation", 6)
	scroll.add_child(chronicle_body)

func _chronicle_span_name(span: int) -> String:
	match span:
		12:
			return "12 Monate"
		60:
			return "5 Jahre"
		240:
			return "20 Jahre"
	return "gesamter Verlauf"

func _set_chronicle_span(span: int) -> void:
	_chronicle_span = span
	_fill_chronicle()

func _slice_history(raw: Array, span: int) -> Array:
	if raw == null or raw.is_empty():
		return []
	if span <= 0:
		return raw.duplicate()
	var last_t: int = int(raw[raw.size() - 1].get("t", 0))
	var out: Array = []
	for e in raw:
		if int(e.get("t", 0)) > last_t - span:
			out.append(e)
	return out

func _comparison_points(span: int) -> Dictionary:
	var series: Array = []
	var points: Array = []
	var latest: Array = []
	var hh: Array = game.house_history
	# Der Vergleich übernimmt exakt die Monatspunkte der eigenen Graphen.
	var own: Array = _slice_history(game.history, span)
	for i in game.houses.size():
		series.append([str(i), game.houses[i]["color"], ""])
		latest.append({})
	var last_t: int = 0
	if not own.is_empty():
		last_t = int(own[own.size() - 1].get("t", 0))
	else:
		for i in game.houses.size():
			var series_data: Array = hh[i] if i < hh.size() else []
			if not series_data.is_empty():
				last_t = maxi(last_t, int(series_data[series_data.size() - 1].get("t", 0)))
	# Jede Hausreihe wird am selben Zeitachsenpunkt abgetastet (letzter Wert
	# bis dahin), damit alle Reihen dieselbe Punktzahl und X-Skala besitzen.
	var cursors: Array = []
	cursors.resize(game.houses.size())
	cursors.fill(0)
	for e in own:
		var t: int = int(e.get("t", 0))
		var point: Dictionary = {"t": t}
		for i in game.houses.size():
			var series_data: Array = hh[i] if i < hh.size() else []
			var c: int = int(cursors[i])
			while c + 1 < series_data.size() and int(series_data[c + 1].get("t", 0)) <= t:
				c += 1
			cursors[i] = c
			if c < series_data.size() and int(series_data[c].get("t", 0)) <= t:
				point[str(i)] = int(series_data[c].get("gold", 0))
			else:
				point[str(i)] = 0
		points.append(point)
	for i in game.houses.size():
		var series_data: Array = hh[i] if i < hh.size() else []
		var sample: Dictionary = {}
		for j in range(series_data.size() - 1, -1, -1):
			if int(series_data[j].get("t", 0)) <= last_t:
				sample = series_data[j]
				break
		if sample.is_empty() and not series_data.is_empty():
			sample = series_data[series_data.size() - 1]
		if sample.is_empty():
			var h: Dictionary = game.houses[i]
			var troops := 0
			for a in h.get("armies", []):
				troops += int(a.get("strength", 0))
			latest[i] = {
				"t": last_t,
				"gold": int(h["gold"]),
				"prestige": int(h["prestige"]),
				"army": troops,
			}
		else:
			latest[i] = {
				"t": int(sample.get("t", last_t)),
				"gold": int(sample.get("gold", 0)),
				"prestige": int(sample.get("prestige", 0)),
				"army": int(sample.get("army", 0)),
			}
	return {"series": series, "points": points, "latest": latest}

func _chronicle_ranking(cmp: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "HausRangliste"
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label("Rangliste am Fensterende", 11, INK_SOFT))
	var latest: Array = cmp.get("latest", [])
	var rows: Array = []
	for i in game.houses.size():
		var stat: Dictionary = latest[i] if i < latest.size() else {}
		rows.append([int(stat.get("gold", game.houses[i]["gold"])), i, stat])
	rows.sort_custom(_sort_rank_rows)
	for row in rows:
		var i: int = int(row[1])
		var stat: Dictionary = row[2]
		var hh: Dictionary = game.houses[i]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.color = hh["color"]
		line.add_child(swatch)
		line.add_child(_label("%s: %d Gold · %d Prestige · %d Truppen" % [
			str(hh["name"]), int(stat.get("gold", 0)), int(stat.get("prestige", 0)), int(stat.get("army", 0))
		], 11, INK_SOFT))
		box.add_child(line)
	return box

func _sort_rank_rows(a: Array, b: Array) -> bool:
	if int(a[0]) == int(b[0]):
		return int(a[1]) < int(b[1])
	return int(a[0]) > int(b[0])

func _fill_chronicle() -> void:
	if game == null or chronicle_body == null:
		return
	for c in chronicle_body.get_children():
		chronicle_body.remove_child(c)
		c.queue_free()
	var h: Dictionary = game.house()
	chronicle_body.add_child(_label("Haus %s · %s" % [str(h["name"]), str(ViewModelBuilder.refresh(game, selected)["date"])], 15, INK_SOFT))

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	filters.add_child(_label("Zeitraum", 12, INK_SOFT))
	for entry in [[12, "12 Monate"], [60, "5 Jahre"], [240, "20 Jahre"], [0, "Alles"]]:
		var b := _button(str(entry[1]), Callable(self, "_set_chronicle_span").bind(int(entry[0])), "")
		b.custom_minimum_size = Vector2(88, 32)
		b.add_theme_font_size_override("font_size", 12)
		if int(entry[0]) == _chronicle_span:
			b.modulate = Color(1.0, 0.85, 0.42)
		filters.add_child(b)
	chronicle_body.add_child(filters)

	var span_label := _chronicle_span_name(_chronicle_span)
	var hist: Array = _slice_history(game.history, _chronicle_span)
	if hist.size() < 2:
		chronicle_body.add_child(_label("Noch kein Verlauf — einige Monate vergehen lassen.", 12, INK_SOFT))
	else:
		var chart_script = load("res://scripts/ChronicleChart.gd")
		chronicle_body.add_child(chart_script.new("Gold & Prestige · %s" % span_label, [["gold", Color(0.87, 0.69, 0.26), "Gold"], ["prestige", Color(0.38, 0.62, 0.88), "Prestige"]], hist, 734, 132))
		chronicle_body.add_child(chart_script.new("Macht & Legitimität · %s" % span_label, [["army", Color(0.72, 0.30, 0.24), "Truppen"], ["legitimacy", Color(0.34, 0.60, 0.34), "Legit."]], hist, 734, 132))

	chronicle_body.add_child(_label("Vergleich der Häuser — Gold · %s" % span_label, 17, INK))
	var cmp: Dictionary = _comparison_points(_chronicle_span)
	if (cmp["points"] as Array).size() < 2:
		chronicle_body.add_child(_label("Vergleich braucht mindestens zwei Monatspunkte — Rangliste zeigt den letzten Stand.", 12, INK_SOFT))
	else:
		var chart_script = load("res://scripts/ChronicleChart.gd")
		chronicle_body.add_child(chart_script.new("Gold je Haus · %s" % span_label, cmp["series"], cmp["points"], 734, 150, false))
	chronicle_body.add_child(_chronicle_ranking(cmp))

	chronicle_body.add_child(_label("Geschichte", 17, INK))
	var lines: Array = game.log_lines
	var from: int = maxi(0, lines.size() - 8)
	for i in range(from, lines.size()):
		chronicle_body.add_child(_label(str(lines[i]), 12, INK_SOFT))
	chronicle_body.add_child(HSeparator.new())
	chronicle_body.add_child(_label("Reich & Wirtschaft", 17, INK))
	chronicle_body.add_child(_label("Gold %d · Steuersatz %d/2 · Legitimität %d/100" % [int(h["gold"]), int(h["laws"]["tax"]), int(h["legitimacy"])], 12, INK_SOFT))
	var econ := HBoxContainer.new()
	econ.add_theme_constant_override("separation", 6)
	econ.add_child(_button("Steuersatz", _toggle_tax, ""))
	econ.add_child(_button("Erbfolge", _toggle_succession, ""))
	econ.add_child(_button("Ausbauen (50)", func(): _dispatch({"id": "develop"}), ""))
	chronicle_body.add_child(econ)
	chronicle_body.add_child(HSeparator.new())
	chronicle_body.add_child(_label("Armee & Krieg", 17, INK))
	var armies: Array = h["armies"]
	if armies.is_empty():
		chronicle_body.add_child(_label("Keine stehende Armee.", 12, INK_SOFT))
	else:
		for a in armies:
			var strength: int = int(a.get("strength", 0))
			chronicle_body.add_child(_label("Armee: %d Truppen · Moral %d" % [strength, int(a.get("morale", 0))], 12, INK_SOFT))
			chronicle_body.add_child(_army_tokens(strength))
	var war := HBoxContainer.new()
	war.add_theme_constant_override("separation", 6)
	war.add_child(_button("Truppen werben (30)", func(): _dispatch({"id": "recruit"}), ""))
	war.add_child(_button("Armee aufstellen (50)", _raise_army, ""))
	war.add_child(_button("Hof halten (40)", func(): _dispatch({"id": "court"}), ""))
	chronicle_body.add_child(war)

func _apply_event_art(art_key: String) -> void:
	var tex = EVENT_ARTS.get(art_key) if art_key != "" else null
	event_art.texture = tex
	event_art.visible = tex != null
	if event_art_fallback != null:
		event_art_fallback.visible = tex == null

func _show_event() -> void:
	var vm: Dictionary = ViewModelBuilder.event(game)
	event_title.text = str(vm["title"])
	event_text.text = str(vm["text"])
	var outline := Color(1, 1, 1, 0.95) if ModernInterfaceScript.is_light() else Color(0.015, 0.035, 0.05, 0.95)
	event_title.add_theme_color_override("font_outline_color", outline)
	event_text.add_theme_color_override("font_outline_color", outline)
	var art_key: String = str(EVENT_ART_KEYS.get(str(vm.get("id", "")), ""))
	_apply_event_art(art_key)
	for c in event_buttons.get_children():
		event_buttons.remove_child(c)
		c.queue_free()
	var options: Array = vm["options"]
	var tags := RegEx.new()
	tags.compile("\\[[^\\]]*\\]")
	for i in options.size():
		var opt: Dictionary = options[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var label := str(opt["label"])
		var cut := label.find("  (")
		if cut > 0:
			label = label.substr(0, cut)
		var effects: String = tags.sub(str(opt["chips"]), "", true)
		var choose := _button("", Callable(self, "_choose").bind(i), "")
		choose.accessibility_name = label + (" — " + effects if effects != "" else "")
		choose.tooltip_text = choose.accessibility_name
		choose.custom_minimum_size = Vector2(0, 64 * ModernInterfaceScript.text_scale)
		choose.set_meta("rich_choice", true)
		# Ein gemeinsamer Trefferbereich mit zugänglichem Namen und farbigen Werten.
		for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			choose.add_theme_color_override(role, Color.TRANSPARENT)
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + edge, 8)
		choose.add_child(inset)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 2)
		inset.add_child(content)
		var action_title := _label(label, 16, INK)
		action_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(action_title)
		var effect_values := RichTextLabel.new()
		effect_values.bbcode_enabled = true
		effect_values.fit_content = true
		effect_values.scroll_active = false
		effect_values.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_values.set_meta("atlas_effect_source", str(opt["chips"]))
		effect_values.add_theme_font_size_override("normal_font_size", int(round(14 * ModernInterfaceScript.text_scale)))
		effect_values.add_theme_font_size_override("bold_font_size", int(round(14 * ModernInterfaceScript.text_scale)))
		effect_values.text = "[center]" + ModernInterfaceScript.effect_markup(str(opt["chips"])) + "[/center]"
		content.add_child(effect_values)
		row.add_child(choose)
		event_buttons.add_child(row)
	kernel.push_modal("event")
	event_layer.visible = true
	if has_meta("modern_interface"):
		get_meta("modern_interface")._scale_text(event_layer)
		get_meta("modern_interface")._fit_dialogs()
		get_meta("modern_interface").call_deferred("_fit_dialogs")
	_play_open()

# --- Zeitlauf ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var top: String = kernel.top_modal()
		if top == "game" and has_meta("modern_interface") and get_meta("modern_interface").map_focus:
			get_meta("modern_interface").set_map_focus(false)
			get_viewport().set_input_as_handled()
			return
		if top == "infrastructure":
			_hide_infrastructure()
			get_viewport().set_input_as_handled()
			return
		if top == "game" and selected != "":
			selected = ""
			if map_view != null:
				map_view.select("")
			refresh()
			get_viewport().set_input_as_handled()
			return
		if top == "optionen":
			_hide_options()
			get_viewport().set_input_as_handled()
			return
		if top == "quit_confirm":
			_hide_quit()
			get_viewport().set_input_as_handled()
			return
		if top == "provinz":
			_hide_province()
			get_viewport().set_input_as_handled()
			return
		if top == "hof":
			_hide_court()
			get_viewport().set_input_as_handled()
			return
		if top == "glaube":
			_hide_faith()
			get_viewport().set_input_as_handled()
			return
		if top == "herrschaft":
			_hide_rule()
			get_viewport().set_input_as_handled()
			return
		if top == "customizer":
			_custom_cancel()
			get_viewport().set_input_as_handled()
			return
		if top == "create":
			_hide_create()
			get_viewport().set_input_as_handled()
			return
		if top == "new_game":
			_hide_newgame()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		settings["window_mode"] = 0 if int(settings["window_mode"]) == 1 else 1
		_apply_display_settings(true)
		_save_settings()
		_refresh_options()
		return
	if event is InputEventKey and event.pressed and not event.echo and game != null and kernel.top_modal() == "game" and not _text_input_active():
		var handled := true
		match event.keycode:
			KEY_1:
				_set_map_mode("political")
			KEY_2:
				_set_map_mode("terrain")
			KEY_3:
				_set_map_mode("duchy")
			KEY_4:
				_set_map_mode("kingdom")
			KEY_5:
				_set_map_mode("development")
			KEY_6:
				_set_map_mode("war")
			KEY_M:
				var modes: Array = MapViewScript.MAP_MODES
				var idx: int = modes.find(str(map_view.map_mode))
				_set_map_mode(str(modes[(idx + 1) % modes.size()]))
			KEY_0:
				map_view.reset_view()
			KEY_EQUAL, KEY_PLUS:
				map_view.zoom_by(1.18)
			KEY_MINUS:
				map_view.zoom_by(0.85)
			KEY_H:
				_toggle_side_panel()
			KEY_L:
				_toggle_map_legend()
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()

func _text_input_active() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _process(delta: float) -> void:
	if game == null or game.game_over:
		return
	if game.pending_event != null and bool(settings["pause_events"]):
		return
	if game.speed <= 0:
		return
	accum += delta
	var interval: float = [0.0, 1.4, 0.8, 0.35][clampi(game.speed, 0, 3)]
	if accum >= interval:
		accum = 0.0
		game.advance_month()
		if game.calendar_index() >= 50399 and not game.campaign_sandbox:
			_show_infrastructure()
		if bool(settings["autosave"]) and game.month == 1:
			_write_save()
		refresh()
