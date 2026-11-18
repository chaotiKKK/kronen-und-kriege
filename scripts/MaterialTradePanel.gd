extends VBoxContainer
## Compact presenter. All authoritative rules and mutations stay in Game/Kernel.
const ViewModel=preload("res://scripts/ViewModelBuilder.gd")
var main
var inspector
var toggle: Button
var body: VBoxContainer
var rows: Dictionary={}
var action_buttons: Dictionary={}
var _expanded := false
var _context := ""
var _region_id := ""
var _view_key := ""
var _generation := 0
var _busy := false

func configure(host, owner_inspector) -> void:
	main=host
	inspector=owner_inspector
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",5)
	toggle=_button("Baustoffhandel ▸",_toggle)
	toggle.toggle_mode=true
	toggle.accessibility_name="Baustoffhandel ein- oder ausblenden"
	add_child(toggle)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",9)
	add_child(body)
	body.hide()
	hide()

func refresh(game, region_id: String) -> void:
	var context: String="%d|%d|%s" % [game.get_instance_id(),game.player,region_id] if game!=null else ""
	if context!=_context:
		_context=context
		_region_id=region_id
		_expanded=false
		_view_key=""
	if game==null or game!=main.game or region_id.is_empty() or game.province(region_id).is_empty() or str(inspector.selected_id)!=region_id:
		_generation+=1
		_clear_rows()
		_view_key=""
		_expanded=false
		hide(); body.hide()
		toggle.set_pressed_no_signal(false)
		return
	var options:=_relevant_options(game,region_id)
	var locked:=_locked(game)
	var interface=main.get_meta("modern_interface")
	var key:=JSON.stringify([context,options,game.calendar_index(),locked,interface.text_scale,interface.touch_layout,interface.appearance])
	if key!=_view_key:
		_view_key=key
		_generation+=1
		_rebuild(game,options,locked)
	visible=not options.is_empty()
	if not visible: _expanded=false
	body.visible=visible and _expanded
	toggle.text="Baustoffhandel "+("▾" if _expanded else "▸")
	toggle.set_pressed_no_signal(_expanded)

func _relevant_options(game, region_id: String) -> Array:
	var options: Array=[]
	for row in game.material_trade_options(region_id):
		if not row is Dictionary: continue
		if str(row.get("kind",""))=="offer":
			var preview: Dictionary=row.get("preview",{})
			if preview.get("ok",false)==true and region_id in [str(row.get("from","")),str(row.get("to",""))]: options.append(row.duplicate(true))
		elif str(row.get("kind",""))=="contract":
			var contract: Dictionary=row.get("contract",{})
			if not contract.is_empty() and game.player in [int(contract.seller),int(contract.buyer)] and region_id in [str(contract.from),str(contract.to)]: options.append(row.duplicate(true))
	return options

func _button(text: String, callback: Callable) -> Button:
	var button: Button=main._button(text,callback)
	main.get_meta("modern_interface")._style_tool(button)
	# _style_tool is also used for initial dark HUD construction. Dynamic trade
	# controls need the current palette immediately, including light themes.
	var interface=main.get_meta("modern_interface")
	button.set_meta("atlas_color",interface.TEXT)
	interface._recolor(button)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text=false
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return button

func _label(text: String, pixels: int, color: Color=Color("edf3f5")) -> Label:
	var label: Label=main._label(text,pixels,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.clip_text=false
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return label

func _clear_rows() -> void:
	var interface=main.get_meta("modern_interface")
	for button in action_buttons.values():
		if is_instance_valid(button): interface._hud_buttons.erase(button)
	action_buttons.clear()
	rows.clear()
	for child in body.get_children():
		# A touch-release handler can still reference the pressed control while
		# its successful command rebuilds this list. Keep it in the tree until
		# the event completes; retire it immediately from layout and input.
		child.hide()
		child.process_mode=Node.PROCESS_MODE_DISABLED
		child.queue_free()

func _rebuild(game, options: Array, locked: bool) -> void:
	var focused_key:=""
	var previous_focus: Control=get_viewport().gui_get_focus_owner()
	for key in action_buttons:
		if action_buttons[key]==previous_focus: focused_key=str(key); break
	_clear_rows()
	for option in options:
		var is_offer: bool=str(option.kind)=="offer"
		var data: Dictionary=option.preview if is_offer else option.contract
		var source: String=str(option.from) if is_offer else str(data.from)
		var target: String=str(option.to) if is_offer else str(data.to)
		var id: String="offer:"+source+"|"+target if is_offer else "contract:"+str(int(data.id))
		var direction: String="Verkauf" if int(data.seller)==game.player else "Einkauf"
		var route: String="%s → %s" % [str(game.province(source).get("name",source)),str(game.province(target).get("name",target))]
		var row:=VBoxContainer.new()
		row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",3)
		body.add_child(row)
		var heading:=_label(direction+" · "+route,12)
		var detail:=_label("Je Charge: %s Baustoffe · %d Gold" % [ViewModel.material_text(int(data.lot_u)),int(data.lot_gold)],12,Color("d4a875"))
		var state:=_label("",11,Color("afbfca"))
		var reason:=_label("",11)
		for label in [heading,detail,state,reason]: row.add_child(label)
		rows[id]={"box":row,"heading":heading,"detail":detail,"state":state,"reason":reason}
		if is_offer:
			state.text="Bis zu drei Chargen · sechs Monate"
			reason.hide()
			_action(id,"Angebot senden",{"id":"material_trade_offer","from":source,"to":target},row,locked,detail.text+". "+route)
		else:
			var contract_id:=int(data.id)
			var remaining:=maxi(0,int(data.expires_month)-int(game.calendar_index()))
			var duration: String="noch %d Monate" % remaining if remaining>0 else "endet diesen Monat"
			state.text=("Angebot" if str(data.status)=="offered" else "Aktiv")+" · %d/3 geliefert · %s" % [int(data.delivered_lots),duration]
			reason.text=str(option.get("reason",""))
			if reason.text.is_empty() and str(data.status)=="offered" and int(data.proposer)==game.player: reason.text="Wartet auf die Gegenseite."
			reason.visible=not reason.text.is_empty()
			if str(data.status)=="offered" and int(data.proposer)!=game.player:
				_action("accept:"+str(contract_id),"Angebot annehmen",{"id":"material_trade_accept","trade":contract_id},row,locked or not bool(option.get("can_accept",false)),detail.text+". "+route)
			if bool(option.get("can_cancel",false)):
				_action("cancel:"+str(contract_id),"Handel beenden" if str(data.status)=="active" else "Angebot beenden",{"id":"material_trade_cancel","trade":contract_id},row,locked,"Bereits bezahlte Ware bleibt übergeben. "+route)
	if not focused_key.is_empty() and is_visible_in_tree() and _expanded:
		if action_buttons.has(focused_key) and not action_buttons[focused_key].disabled: action_buttons[focused_key].call_deferred("grab_focus")
		else: toggle.call_deferred("grab_focus")

func _action(key: String, text: String, command: Dictionary, parent: Node, disabled: bool, description: String) -> void:
	var button:=_button(text,_activate.bind(command.duplicate(true),_region_id,_context,_generation))
	button.disabled=disabled
	button.accessibility_name=text+". "+description
	parent.add_child(button)
	action_buttons[key]=button

func _toggle() -> void:
	if not visible or main.game==null: return
	_expanded=not _expanded
	body.visible=_expanded
	toggle.text="Baustoffhandel "+("▾" if _expanded else "▸")
	toggle.set_pressed_no_signal(_expanded)

func _locked(game) -> bool:
	return _busy or bool(game.game_over) or (main._lan_active() and main.lan_session.pending_command)

func _activate(command: Dictionary, region_id: String, context: String, generation: int) -> void:
	if main.game==null or _busy or not visible or not _expanded or str(main.selected)!=region_id or str(inspector.selected_id)!=region_id or _context!=context or _generation!=generation: return
	if not is_visible_in_tree() or _locked(main.game): return
	# Refresh authoritative options before routing: stale stock, ownership,
	# acceptance or cancellation must not turn into a different new intention.
	refresh(main.game,region_id)
	if _generation!=generation or not visible: return
	var matching:=false
	for row in _relevant_options(main.game,region_id):
		match str(command.get("id","")):
			"material_trade_offer":
				if str(row.kind)=="offer" and str(row.from)==str(command.get("from","")) and str(row.to)==str(command.get("to","")): matching=true
			"material_trade_accept":
				if str(row.kind)=="contract" and int(row.contract.id)==int(command.get("trade",-1)) and bool(row.can_accept): matching=true
			"material_trade_cancel":
				if str(row.kind)=="contract" and int(row.contract.id)==int(command.get("trade",-1)) and bool(row.can_cancel): matching=true
	if not matching: return
	_busy=true
	var result: Dictionary=main._dispatch(command)
	_busy=false
	if inspector.status!=null:
		inspector.status.text=str(result.get("message",result.get("msg","")))
		inspector.status.visible=not inspector.status.text.is_empty()
	refresh(main.game,region_id)
