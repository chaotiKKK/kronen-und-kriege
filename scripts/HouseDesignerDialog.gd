extends Control
## Derselbe Entwurf vor Einzelspieler- und WLAN-Partien. Änderungen bleiben lokal bis Übernehmen.
const Design = preload("res://scripts/HouseDesign.gd")
const Appearance = preload("res://scripts/ModernInterface.gd")
signal accepted(profile: Dictionary)
signal cancelled
var main
var card: PanelContainer
var scroll: ScrollContainer
var fields: Dictionary = {}
var home_picker: OptionButton
var doctrine_picker: OptionButton
var status_label: Label
var budget_label: Label
var preview_label: Label
var portrait_preview: TextureRect
var crest_preview: TextureRect
var apply_button: Button
var cancel_button: Button
var _callback: Callable
var _initial: Dictionary = {}
var _closed := false
var _data
const DOCTRINE_NAMES := ["Ausgewogen", "Fußvolk", "Reiterei", "Belagerung"]
const DOCTRINE_TEXT := ["Keine Abzüge oder laufenden Mehrkosten.", "Verteidigung +10 % · Angriff −5 % · normaler Unterhalt.", "Angriff +10 % · Unterhalt +25 %.", "Belagerungsfortschritt +8 · Angriff −10 % · Verteidigung −5 % · Unterhalt +10 %."]
const COLOR_NAMES := ["Kupferrot", "Königsblau", "Waldgrün", "Goldocker", "Petrol", "Purpur", "Bronze", "Schiefer", "Oliv"]

func configure(owner, initial_profile: Dictionary, callback: Callable = Callable()) -> void:
	main = owner
	_data = main.DataScript
	_callback = callback
	var checked: Dictionary = Design.validate(initial_profile, _data)
	_initial = checked.profile if checked.ok else Design.defaults(_data)
	name = "HouseDesignerDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(self)
	main.kernel.push_modal("house_designer")
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.015,0.02,0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 24
	card.offset_top = 24
	card.offset_right = -24
	card.offset_bottom = -24
	card.add_theme_stylebox_override("panel", Appearance.surface(Appearance.PANEL,16))
	add_child(card)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	card.add_child(layout)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation",12)
	layout.add_child(title)
	portrait_preview = _image(Vector2(44,56))
	crest_preview = _image(Vector2(36,44))
	title.add_child(portrait_preview)
	title.add_child(crest_preview)
	title.add_child(main._label("Dein Haus · Reich & Armee",24))
	var intro: Label = main._label("Eine Heimatregion, 150 Gold, 12 Prestige. Dieselben Gründungsregeln für alle; das Profil erzeugt keine zusätzlichen Truppen.",13)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(intro)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	layout.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	var form := GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("h_separation",12)
	form.add_theme_constant_override("v_separation",6)
	body.add_child(form)
	for entry in [["house","Hausname"],["ruler","Herrschername"],["land","Name deiner Heimat (optional)"]]:
		var field: LineEdit = main._field(str(_initial[entry[0]]), "")
		field.max_length = 48
		field.accessibility_name = str(entry[1])
		field.text_changed.connect(func(_text): _update())
		fields[entry[0]] = field
		_row(form, str(entry[1]),field)
	var gender := _options(["Mann","Frau"])
	gender.select(0 if _initial.gender == "m" else 1)
	fields.gender = gender
	_row(form,"Geschlecht",gender)
	var age := _number(16,90,int(_initial.age))
	fields.age = age
	_row(form,"Alter",age)
	home_picker = _options([])
	var index := 0
	for region in Design.catalog(_data):
		home_picker.add_item(str(region.name))
		home_picker.set_item_metadata(index,str(region.id))
		if region.id == _initial.province: home_picker.select(index)
		index += 1
	fields.province = home_picker
	_row(form,"Heimatregion",home_picker)
	var portraits := _options([])
	for portrait in Design.PORTRAITS:
		portraits.add_item("Porträt %d" % (portrait+1))
	portraits.select(int(_initial.portrait))
	fields.portrait = portraits
	_row(form,"Porträt",portraits)
	var crests := _options([])
	for crest in Design.CRESTS:
		crests.add_item("Wappen %d" % (crest+1))
	crests.select(int(_initial.crest))
	fields.crest = crests
	_row(form,"Wappen",crests)
	var colors := _options(COLOR_NAMES)
	colors.select(int(_initial.color))
	fields.color = colors
	_row(form,"Hausfarbe",colors)
	for entry in [["martial","Kriegskunst"],["diplomacy","Diplomatie"],["stewardship","Verwaltung"],["intrigue","Intrige"]]:
		var field := _number(3,20,int(_initial[entry[0]]))
		fields[entry[0]] = field
		_row(form,str(entry[1]),field)
	doctrine_picker = _options(DOCTRINE_NAMES)
	doctrine_picker.select(Design.DOCTRINES.find(_initial.doctrine))
	fields.doctrine = doctrine_picker
	_row(form,"Doktrin",doctrine_picker)
	budget_label = main._label("",14)
	preview_label = main._label("",14)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(budget_label)
	body.add_child(preview_label)
	status_label = main._label("",13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	layout.add_child(footer)
	cancel_button = main._button("Abbrechen",cancel)
	apply_button = main._button("Entwurf übernehmen",submit)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cancel_button)
	footer.add_child(apply_button)
	if main.has_meta("modern_interface"):
		main.get_meta("modern_interface")._recolor(self)
		main.get_meta("modern_interface")._scale_text(self)
	_update()
	fields.house.grab_focus()

func _image(minimum: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.custom_minimum_size = minimum
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return image

func _row(form: GridContainer, caption: String, control: Control) -> void:
	var label: Label = main._label(caption,14)
	label.custom_minimum_size.x = 170
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(label)
	control.custom_minimum_size.y = 44
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.accessibility_name = caption
	form.add_child(control)

func _options(names: Array) -> OptionButton:
	var options := OptionButton.new()
	for value in names: options.add_item(str(value))
	options.set_meta("atlas_font_size",14)
	options.add_theme_font_size_override("font_size",int(round(14*Appearance.text_scale)))
	options.add_theme_stylebox_override("normal",Appearance.surface(Appearance.BG,6))
	options.add_theme_stylebox_override("focus",Appearance.focus_surface(6))
	options.item_selected.connect(func(_index): _update())
	return options

func _number(minimum: int, maximum: int, value: int) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.value = value
	field.get_line_edit().set_meta("atlas_font_size",14)
	field.get_line_edit().add_theme_font_size_override("font_size",int(round(14*Appearance.text_scale)))
	field.get_line_edit().add_theme_stylebox_override("normal",main._field_style())
	field.value_changed.connect(func(_value): _update())
	return field

func profile() -> Dictionary:
	var result := _initial.duplicate(true)
	for key in ["house","ruler","land"]: result[key] = fields[key].text
	result.gender = "m" if fields.gender.selected == 0 else "f"
	result.age = int(fields.age.value)
	result.province = str(home_picker.get_item_metadata(home_picker.selected))
	for key in ["portrait","crest","color"]: result[key] = fields[key].selected
	for key in Design.STATS: result[key] = int(fields[key].value)
	result.doctrine = Design.DOCTRINES[doctrine_picker.selected]
	return result

func _update() -> void:
	if budget_label == null: return
	var draft := profile()
	var total := 0
	for key in Design.STATS: total += int(draft[key])
	budget_label.text = "Charakterwerte: %d / 44 Punkte · %d Punkte frei" % [total,maxi(0,44-total)]
	preview_label.text = "Armeeprofil: %s\n%s" % [DOCTRINE_NAMES[doctrine_picker.selected],DOCTRINE_TEXT[doctrine_picker.selected]]
	portrait_preview.texture = main.PORTRAITS[int(draft.portrait)]
	crest_preview.texture = main.CRESTS[int(draft.crest)]
	var checked: Dictionary = Design.validate(draft,_data)
	status_label.text = "" if checked.ok else checked.message
	apply_button.disabled = not checked.ok

func submit() -> void:
	if _closed: return
	var checked: Dictionary = Design.validate(profile(),_data)
	if not checked.ok:
		status_label.text = checked.message
		return
	_close()
	accepted.emit(checked.profile)
	if _callback.is_valid(): _callback.call(checked.profile)

func cancel() -> void:
	if _closed: return
	_close()
	cancelled.emit()

func _close() -> void:
	_closed = true
	main.kernel.pop_modal("house_designer")
	visible = false
	queue_free()
