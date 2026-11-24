extends VBoxContainer
## Civilian quantities are read-only projections. Game/Kernel own every change.
const ViewModel=preload("res://scripts/ViewModelBuilder.gd")
const RATIONS := [["scarce","Knapp · 75 %"],["normal","Normal · 100 %"],["generous","Großzügig · 125 %"]]
var main: Node
var toggle: Button
var body: VBoxContainer
var ration_picker: OptionButton
var apply_button: Button
var plan_label: Label
var balance_label: Label
var status_label: Label
var _expanded := false
var _region_id := ""
var _context := ""
var _current_policy := ""
var _generation := 0
var _view_key := ""
var _busy := false
var _apply_callback := Callable()

func setup(host: Node) -> void:
	main=host
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",4)
	toggle=_button("Zivile Versorgung ▸",_toggle)
	toggle.toggle_mode=true
	toggle.accessibility_name="Zivile Vorräte und Rationsplan ein- oder ausblenden"
	add_child(toggle)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",5)
	add_child(body)
	ration_picker=OptionButton.new()
	ration_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ration_picker.clip_text=true
	ration_picker.accessibility_name="Zivile Rationen für die ausgewählte eigene Provinz"
	for entry in RATIONS:
		ration_picker.add_item(str(entry[1]))
		ration_picker.set_item_metadata(ration_picker.item_count-1,str(entry[0]))
	ration_picker.item_selected.connect(_choose_ration)
	body.add_child(ration_picker)
	plan_label=_label()
	balance_label=_label()
	status_label=_label()
	for label in [plan_label,balance_label,status_label]: body.add_child(label)
	apply_button=_button("Rationen anwenden",Callable())
	body.add_child(apply_button)
	body.hide(); hide()
	_sync_styles()

func _button(text: String,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	if callback.is_valid(): button.pressed.connect(callback)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text=false
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return button

func _label() -> Label:
	var label: Label=main._label("",11)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.clip_text=false
	return label

func _sync_styles() -> void:
	var interface=main.get_meta("modern_interface")
	for button in [toggle,ration_picker,apply_button]: interface._style_tool(button)
	interface._scale_text(self)
	interface._recolor(self)
	var popup:=ration_picker.get_popup()
	popup.add_theme_font_size_override("font_size",int(round(12*interface.text_scale)))
	popup.add_theme_constant_override("v_separation",28)

func _valid(game,region_id: String) -> bool:
	if game==null or game!=main.game or region_id.is_empty(): return false
	var province: Dictionary=game.province(region_id)
	if province.is_empty() or int(province.owner)!=int(game.player): return false
	var inspector=main.get_meta("modern_interface").province_inspector
	return str(main.selected)==region_id and inspector!=null and str(inspector.selected_id)==region_id

func _locked(game) -> bool:
	return _busy or bool(game.game_over) or (main._lan_active() and main.lan_session.pending_command)

func refresh(game,id: String) -> void:
	if not _valid(game,id):
		_generation+=1
		_context=""; _region_id=""; _view_key=""; _current_policy=""
		_expanded=false
		ration_picker.disabled=true
		apply_button.disabled=true; apply_button.hide()
		plan_label.text=""; balance_label.text=""; status_label.text=""
		body.hide(); hide()
		toggle.set_pressed_no_signal(false)
		return
	var context:="%d|%d|%s|%d" % [game.get_instance_id(),int(game.player),id,int(game.province(id).owner)]
	var current: Dictionary=game.provision_preview(id)
	if current.is_empty() or not current.has("next") or not current.has("current_rations"):
		hide(); body.hide(); return
	var policy:=str(current.current_rations)
	if context!=_context or policy!=_current_policy:
		if context!=_context: _expanded=false
		_context=context; _region_id=id; _current_policy=policy
		_select_policy(policy)
	var proposed:=_selected_policy()
	var preview: Dictionary=current if proposed==policy else game.provision_preview(id,proposed)
	var interface=main.get_meta("modern_interface")
	var key:=JSON.stringify([context,preview,game.calendar_index(),_locked(game),interface.appearance,interface.text_scale,interface.touch_layout])
	if key!=_view_key:
		_view_key=key; _generation+=1
		_sync_styles()
		_render(preview,game.provision_report().regions.get(id,{}))
		if _apply_callback.is_valid() and apply_button.pressed.is_connected(_apply_callback): apply_button.pressed.disconnect(_apply_callback)
		_apply_callback=_apply.bind(proposed,id,_context,_generation,policy)
		apply_button.pressed.connect(_apply_callback)
	visible=true
	body.visible=_expanded
	toggle.text="Vorrat %s Mon. · Zufriedenheit %d %% %s" % [_decimal(float(current.stock_months)),int(current.satisfaction),"▾" if _expanded else "▸"]
	toggle.set_pressed_no_signal(_expanded)
	ration_picker.disabled=_locked(game)
	apply_button.disabled=_locked(game) or not bool(preview.get("ok",false))
	apply_button.visible=proposed!=policy

func _select_policy(policy: String) -> void:
	for index in ration_picker.item_count:
		if str(ration_picker.get_item_metadata(index))==policy: ration_picker.select(index); return

func _selected_policy() -> String:
	return str(ration_picker.get_item_metadata(ration_picker.selected)) if ration_picker.selected>=0 else ""

func _render(preview: Dictionary,last: Dictionary) -> void:
	var next: Dictionary=preview.get("next",{})
	var taxes: int=int(preview.get("tax_level",1))
	var tax_name: String=["niedrig (+1)","normal (±0)","hoch (−2)"][clampi(taxes,0,2)]
	plan_label.text="Rationen %d %% · Steuern %s\nZufriedenheit %d → %d %%\nLandarbeit %s · Industriebudget %s (gesamt %s Arbeit)\nNächster Vorrat %s Nahrung · Lager %s Monatsrationen" % [int(preview.get("ration_rate",100)),tax_name,int(next.get("satisfaction_before",preview.get("satisfaction",50))),int(next.get("satisfaction_after",preview.get("satisfaction",50))),ViewModel.material_text(int(next.get("farm_work_u",0))),ViewModel.material_text(int(next.get("industry_labor_u",0))),ViewModel.material_text(int(next.get("total_labor_u",0))),ViewModel.material_text(int(next.get("after_u",0))),_decimal(float(preview.get("capacity_months",0)))]
	balance_label.text="Nahrungsbilanz: Anfang %s · Erzeugt %s · Verbraucht %s\nFehlbedarf %s · Überlauf %s · Ende %s\nVorschau bei unverändertem Stand; Forschung, Steuern und Blockaden können den nächsten Monat verändern." % [ViewModel.material_text(int(next.get("before_u",0))),ViewModel.material_text(int(next.get("produced_u",0))),ViewModel.material_text(int(next.get("consumed_u",0))),ViewModel.material_text(int(next.get("shortfall_u",0))),ViewModel.material_text(int(next.get("wasted_u",0))),ViewModel.material_text(int(next.get("after_u",0)))]
	if not last.is_empty():
		balance_label.text+="\nZuletzt abgerechnet: %s erzeugt · %s verbraucht · %s Fehlbedarf." % [ViewModel.material_text(int(last.produced_u)),ViewModel.material_text(int(last.consumed_u)),ViewModel.material_text(int(last.shortfall_u))]
	status_label.text=str(preview.get("reason",""))
	var blocked:=str(preview.get("blocked_reason",""))
	if not blocked.is_empty(): status_label.text+=("\n" if not status_label.text.is_empty() else "")+blocked+" · vorhandene Vorräte werden weiter verbraucht."
	status_label.visible=not status_label.text.is_empty()
	apply_button.accessibility_name="Gewählte Rationen für "+str(main.game.province(_region_id).get("name",_region_id))+" anwenden. Nahrung und Zufriedenheit werden erst im nächsten Monat abgerechnet."

func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".",",")

func _toggle() -> void:
	if not _valid(main.game,_region_id) or not visible: return
	_expanded=not _expanded
	refresh(main.game,_region_id)

func _choose_ration(_index: int) -> void:
	if not _valid(main.game,_region_id) or not _expanded: return
	refresh(main.game,_region_id)

func _apply(policy: String,id: String,context: String,generation: int,previous_policy: String) -> void:
	if _busy or not visible or not _expanded or not is_visible_in_tree(): return
	if not _valid(main.game,id): refresh(main.game,id); return
	if _context!=context or _generation!=generation: return
	var game=main.game
	if _locked(game): refresh(game,id); return
	var current: Dictionary=game.provision_preview(id,policy)
	if str(current.get("current_rations",""))!=previous_policy or policy==previous_policy or not bool(current.get("ok",false)):
		refresh(game,id); return
	# The selected province and authenticated house are supplied by Kernel/LAN.
	# A persistent sender stays in-tree throughout dispatch and touch release.
	_busy=true
	var result: Dictionary=main._dispatch({"id":"province_rations","rations":policy})
	_busy=false
	refresh(main.game,id)
	if not bool(result.get("ok",false)) and visible:
		status_label.text=str(result.get("message",result.get("msg","Änderung nicht möglich.")))
		status_label.visible=not status_label.text.is_empty()
