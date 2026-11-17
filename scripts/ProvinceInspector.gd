extends VBoxContainer
## Stabile örtliche Verwaltung. Keine Spielregeln und keine direkte Mutation.
const ViewModel = preload("res://scripts/ViewModelBuilder.gd")
var main
var selected_id := ""
var section_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var sections: Dictionary = {}
var fields: Dictionary = {}
var current_section := "buildings"
var _own_section := "buildings"
var _own_context := true
var _context_known := false
var title: Label
var summary: Label
var status: Label
var army_picker: OptionButton
var section_tabs: GridContainer
var focus_picker: OptionButton
var focus_box: VBoxContainer
var _focus_province := ""
var disband_box: VBoxContainer
var _pending_disband: Dictionary = {}

func configure(host) -> void:
	main = host
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	title = _text("Wähle eine Spielregion", 16)
	summary = _text("Wähle eine Provinz auf der Karte.")
	var tabs := GridContainer.new()
	section_tabs = tabs
	tabs.columns = 2
	add_child(tabs)
	var group := ButtonGroup.new()
	for entry in [["buildings","Ausbau"],["army","Heer & Flotte"],["research","Wissen"],["achievements","Errungenschaften"]]:
		var id := str(entry[0])
		var button: Button = main._button(entry[1], show_section.bind(id))
		main.get_meta("modern_interface")._style_tool(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.toggle_mode = true
		button.button_group = group
		tabs.add_child(button)
		section_buttons[id] = button
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		sections[id] = content
		add_child(content)
	fields.buildings = _text("", 12, sections.buildings)
	focus_box = VBoxContainer.new()
	focus_box.add_theme_constant_override("separation",4)
	sections.buildings.add_child(focus_box)
	_text("Provinzschwerpunkt",12,focus_box)
	focus_picker = OptionButton.new()
	focus_picker.clip_text = true
	focus_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.get_meta("modern_interface")._style_tool(focus_picker)
	focus_picker.item_selected.connect(func(_index): _preview_focus())
	focus_box.add_child(focus_picker)
	fields.focus_preview = _text("",11,focus_box)
	var change_focus: Button = main._button("Schwerpunkt wechseln",_apply_focus)
	change_focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.get_meta("modern_interface")._style_tool(change_focus)
	focus_box.add_child(change_focus)
	action_buttons.province_focus = change_focus
	for key in ["market","barracks","walls"]:
		var box := VBoxContainer.new()
		sections.buildings.add_child(box)
		_action("build:"+key, "", {"id":"build","key":key}, box)
		fields["build:"+key] = _text("", 11, box)
	# Die bestehenden Test-/Shortcut-Referenzen bleiben dieselben Buttons.
	main.develop_btn.reparent(sections.buildings)
	main.recruit_btn.reparent(sections.army)
	main.attack_btn.reparent(sections.army)
	fields.army = _text("",12,sections.army)
	_action("claim", "Anspruch schmieden · 40 Gold", {"id":"claim"}, sections.army)
	fields.war = _text("",11,sections.army)
	_action("army", "Armee aufstellen · 50 Gold", {"id":"army"}, sections.army)
	army_picker = OptionButton.new()
	army_picker.clip_text = true
	army_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	army_picker.tooltip_text = "Wähle ausdrücklich, welcher vorhandene eigene Verband Befehle erhält."
	main.get_meta("modern_interface")._style_tool(army_picker)
	army_picker.item_selected.connect(_select_army)
	sections.army.add_child(army_picker)
	fields.field_army = _text("",12,sections.army)
	fields.supply = _text("",11,sections.army)
	var focus: Button = main._button("Eigene Armee zeigen",main._focus_field_army)
	main.get_meta("modern_interface")._style_tool(focus)
	sections.army.add_child(focus)
	action_buttons.focus_army = focus
	_action("march", "Hierher marschieren", {"id":"march"}, sections.army)
	fields.transport = _text("",11,sections.army)
	_action("transport_army","Hierher übersetzen",{"id":"transport_army"},sections.army)
	_action("siege", "Belagerung vorantreiben", {"id":"siege"}, sections.army)
	fields.orders = _text("",11,sections.army)
	fields.battle = _text("",11,sections.army)
	_action("relieve","Festung entsetzen",{"id":"relieve"},sections.army)
	_action("recover_army","Auffüllen und ordnen",{"id":"recover_army"},sections.army)
	var disband: Button = main._button("Heer auflösen …",_request_disband)
	main.get_meta("modern_interface")._style_tool(disband)
	disband.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.army.add_child(disband)
	action_buttons.disband_army = disband
	disband_box = VBoxContainer.new()
	disband_box.add_theme_constant_override("separation",4)
	sections.army.add_child(disband_box)
	fields.disband_confirmation = _text("",11,disband_box)
	var confirm: Button = main._button("Heer endgültig auflösen",_confirm_disband)
	var cancel: Button = main._button("Abbrechen",_clear_disband.bind(true))
	for button in [confirm,cancel]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.get_meta("modern_interface")._style_tool(button)
		disband_box.add_child(button)
	action_buttons.disband_confirm = confirm
	action_buttons.disband_cancel = cancel
	disband_box.hide()
	_action("fleet", "Flotte aufstellen", {"id":"fleet"}, sections.army)
	fields.research = _text("",12,sections.research)
	var research_plan: Button = main._button("Forschungsplan öffnen",_open_research_plan)
	main.get_meta("modern_interface")._style_tool(research_plan)
	research_plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.research.add_child(research_plan)
	action_buttons.research_plan = research_plan
	fields.achievements = _text("",12,sections.achievements)
	_action("blockade","Küste blockieren",{"id":"blockade"},sections.army)
	_action("peace","Frieden · 24 Monate",{"id":"peace"},sections.achievements)
	_action("secret_discover","Geheimnis aufdecken",{"id":"secret_discover"},sections.achievements)
	_action("secret_expose","Geheimnis ausnutzen",{"id":"secret_expose"},sections.achievements)
	# Erst die nächste Entscheidung, darunter die ausführlichen Bestandszahlen.
	var war_order: Array = [fields.war,action_buttons.claim,army_picker,fields.field_army,fields.transport,action_buttons.transport_army,fields.battle,action_buttons.march,action_buttons.siege,main.attack_btn,action_buttons.relieve,action_buttons.recover_army,fields.orders,action_buttons.army,action_buttons.focus_army,fields.supply,action_buttons.fleet,action_buttons.blockade,main.recruit_btn,fields.army,action_buttons.disband_army,disband_box]
	for index in war_order.size(): sections.army.move_child(war_order[index],index)
	status = _text("",11)
	show_section(current_section)

func _text(value: String, pixels: int = 12, parent: Node = null) -> Label:
	var label: Label = main._label(value,pixels)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else self).add_child(label)
	return label

func _action(key: String, label: String, command: Dictionary, parent: Node) -> Button:
	var button: Button = main._button(label, _command.bind(command))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	main.get_meta("modern_interface")._style_tool(button)
	parent.add_child(button)
	action_buttons[key] = button
	return button

func _command(command: Dictionary) -> void:
	if main.game==null or main.game.province(selected_id).is_empty(): return
	if str(command.get("id","")) in ["build","province_focus","army","fleet","relieve","recover_army","disband_army"] and not _owns_selection(): return
	var result: Dictionary = main._dispatch(command)
	status.text = str(result.get("message", ""))
	status.visible = not status.text.is_empty()

func _owns_selection() -> bool:
	if main==null or main.game==null or selected_id.is_empty(): return false
	var province: Dictionary = main.game.province(selected_id)
	return not province.is_empty() and int(province.owner)==main.game.player

func _open_research_plan() -> void:
	if _owns_selection(): main._show_infrastructure()

func _select_army(index: int) -> void:
	if index < 0 or index >= army_picker.item_count: return
	_clear_disband()
	_command({"id":"select_army","army":army_picker.get_item_id(index)})

func _request_disband() -> void:
	_clear_disband()
	if not _owns_selection(): return
	var preview: Dictionary=main.game.disband_preview(selected_id)
	if not bool(preview.ok): return
	_pending_disband={"province":selected_id,"army":int(preview.army_id),"strength":int(preview.strength),"morale":int(preview.morale),"month":main.game._now()}
	fields.disband_confirmation.text="Heer %d in %s mit %d Mann wirklich auflösen?\nSoldaten und Gold werden nicht erstattet." % [int(preview.army_id),str(main.game.province(selected_id).name),int(preview.strength)]
	for key in ["disband_confirm","disband_cancel"]:
		action_buttons[key].show()
		action_buttons[key].disabled=false
	disband_box.show()
	action_buttons.disband_cancel.grab_focus()

func _clear_disband(focus_back: bool = false) -> void:
	_pending_disband.clear()
	if disband_box!=null: disband_box.hide()
	if focus_back and action_buttons.has("disband_army") and action_buttons.disband_army.is_visible_in_tree():
		action_buttons.disband_army.grab_focus()

func _confirm_disband() -> void:
	if _pending_disband.is_empty() or not _owns_selection():
		_clear_disband()
		return
	var preview: Dictionary=main.game.disband_preview(selected_id)
	if not _confirmation_matches(preview):
		_clear_disband()
		return
	var army_id:=int(_pending_disband.army)
	_clear_disband()
	_command({"id":"disband_army","army":army_id})

func _confirmation_matches(preview: Dictionary) -> bool:
	return not _pending_disband.is_empty() and bool(preview.get("ok",false)) and selected_id==str(_pending_disband.province) and int(preview.army_id)==int(_pending_disband.army) and int(preview.strength)==int(_pending_disband.strength) and int(preview.morale)==int(_pending_disband.morale) and main.game._now()==int(_pending_disband.month)

func _apply_focus() -> void:
	if not _owns_selection() or focus_picker.selected < 0: return
	_command({"id":"province_focus","focus":str(focus_picker.get_item_metadata(focus_picker.selected))})

func _preview_focus() -> void:
	if not _owns_selection() or focus_picker.selected < 0: return
	var focus_id := str(focus_picker.get_item_metadata(focus_picker.selected))
	var preview: Dictionary = main.game.province_economy_preview(selected_id,focus_id)
	if preview.is_empty(): return
	var pending: bool = main._lan_active() and main.lan_session.pending_command
	var reason := str(preview.get("reason",""))
	fields.focus_preview.text = "Ertrag %s → %s Gold/Jahr\nVersorgung %d → %d Mann\nZwölf Monate Bindung nach einem Wechsel." % [_gold(preview.current_income),_gold(preview.projected_income),int(preview.current_supply),int(preview.projected_supply)]
	fields.focus_preview.text += "\n" + (reason if not reason.is_empty() else "Bereit · Änderung gilt nach Bestätigung.")
	fields.focus_preview.tooltip_text = "Örtlicher Grund- und Marktbeitrag vor Haussteuern. Die endgültigen Markteinnahmen werden für das Haus gemeinsam gerundet."
	action_buttons.province_focus.text = "Wechseln · %d Gold" % int(preview.cost)
	action_buttons.province_focus.disabled = pending or main.game.game_over or not reason.is_empty()

func _gold(value) -> String:
	return ("%.2f" % float(value)).replace(".",",")

func _refresh_focus(game, vm: Dictionary) -> void:
	focus_box.visible = bool(vm.own)
	if not vm.own:
		_focus_province = ""
		focus_picker.clear()
		focus_picker.disabled = true
		fields.focus_preview.text = ""
		return
	var choices: Array = game.province_focus_choices(selected_id)
	if _focus_province != selected_id or focus_picker.item_count != choices.size():
		_focus_province = selected_id
		focus_picker.clear()
		for choice in choices:
			focus_picker.add_item(str(choice.name))
			focus_picker.set_item_metadata(focus_picker.item_count-1,str(choice.id))
			if bool(choice.selected): focus_picker.select(focus_picker.item_count-1)
	focus_picker.disabled = game.game_over or (main._lan_active() and main.lan_session.pending_command)
	_preview_focus()

func _refresh_supply(game, id: String) -> void:
	var report: Dictionary = game.supply_report()
	var supply: Dictionary = report.get("regions",{}).get(id,{})
	fields.supply.visible = not supply.is_empty()
	if supply.is_empty(): return
	fields.supply.text = "Versorgung · gemeinsamer Bedarf %d Mann\nÖrtlich %d · Import %d · Fehlbedarf %d\nVersorgungsverluste werden jährlich abgerechnet." % [int(supply.demand),int(supply.local_capacity),int(supply["import"]),int(supply.shortfall)]
	if int(supply.get("export_available",0)) > 0:
		fields.supply.text += "\nKornkammerüberschuss %d · davon geliefert %d" % [int(supply.export_available),int(supply["export"])]

func show_section(id: String) -> void:
	if not sections.has(id) or not section_buttons[id].visible or section_buttons[id].disabled: return
	current_section = id
	if _context_known and _own_context: _own_section = id
	for key in sections:
		sections[key].visible = key == id
		section_buttons[key].set_pressed_no_signal(key == id)

func fit_tabs() -> void:
	var visible_tabs := 0
	for button in section_buttons.values():
		if button.visible: visible_tabs+=1
	section_tabs.columns = 1 if main.get_meta("modern_interface").text_scale > 1.3 else maxi(1,visible_tabs)

func _refresh_administration(own: bool) -> void:
	for key in ["build:market","build:barracks","build:walls","province_focus","research_plan"]:
		action_buttons[key].visible = own
		if not own: action_buttons[key].disabled = true
	action_buttons.research_plan.disabled = not own
	main.develop_btn.visible = own
	if own: return
	_focus_province = ""
	focus_picker.clear()
	focus_picker.disabled = true
	focus_box.hide()
	fields.focus_preview.text = ""
	fields.research.text = ""
	fields.buildings.text = ""
	for key in ["market","barracks","walls"]: fields["build:"+key].text = ""

func refresh(game, id: String) -> void:
	var selection_changed := selected_id != id
	if selection_changed:
		status.text = ""
		_clear_disband()
	selected_id = id
	var vm: Dictionary = ViewModel.province(game,id)
	_refresh_administration(not vm.is_empty() and bool(vm.own))
	section_tabs.visible = not vm.is_empty()
	for key in section_buttons:
		section_buttons[key].disabled = vm.is_empty()
		section_buttons[key].visible = not vm.is_empty() and (key != "achievements" if vm.own else key in ["army","achievements"])
	if vm.is_empty():
		_clear_disband()
		_context_known = false
		title.text = "Provinz auswählen"
		summary.text = "Eigenes Land: Ausbau, Heer und Wissen.\nFremdes Land: Diplomatie und passende Kriegsaktionen."
		status.hide()
		army_picker.clear()
		army_picker.hide()
		for button in action_buttons.values():
			button.hide()
			button.disabled = true
		for field in fields.values(): field.text = ""
		main.recruit_btn.hide()
		main.attack_btn.hide()
		for section in sections.values(): section.visible = false
		return
	var army: Dictionary = game.army_for()
	var military: Dictionary = vm.military
	var claimed: bool = game.has_claim(id)
	var border: bool = game.is_border_province(game.player,id)
	var transport: Dictionary = game.naval_transport_preview(id)
	var naval_context := not str(transport.get("route_id","")).is_empty()
	var coastal_reason: String = game.coastal_claim_reason(id)
	var claim_reason: String = game.claim_reason(id)
	var claim_relevant: bool = border or coastal_reason.is_empty() or (naval_context and not game.fleet_for().is_empty())
	var army_near: bool = not army.is_empty() and (str(army.province) == id or game.neighbours(str(army.province)).has(id))
	var military_context: bool = border or claimed or army_near or game.can_blockade(id) or naval_context or coastal_reason.is_empty() or int(vm.siege)>0 or int(vm.blockade)>0
	# Erhaltene Spielstände können mehrere Heere enthalten. Ein anderes eigenes
	# Heer oder Geleit im Ziel darf nicht vom aktiven Verband verdeckt werden.
	for own_army in game.house().get("armies",[]):
		if str(own_army.get("province",""))==id or game.neighbours(str(own_army.get("province",""))).has(id): military_context = true
	for own_fleet in game.house().get("fleets",[]):
		if str(own_fleet.get("station",own_fleet.get("province","")))==id: military_context = true
	section_buttons.army.visible = bool(vm.own) or military_context
	if not _context_known or _own_context != bool(vm.own) or (not vm.own and selection_changed):
		current_section = _own_section if vm.own else ("army" if military_context else "achievements")
	if not section_buttons[current_section].visible:
		current_section = _own_section if vm.own else ("army" if military_context else "achievements")
	_own_context = bool(vm.own)
	_context_known = true
	fit_tabs()
	section_buttons.army.text = "Militär" if vm.own else "Krieg"
	section_buttons.achievements.text = "Diplomatie"
	title.text = str(vm.name)
	summary.text = "%s · %s\n%d Gold/Jahr" % [vm.terrain,vm.owner,vm.income]
	if vm.own: summary.text += " · Aufgebot %d · Verteidigung %+d%%" % [vm.levy,int(vm.defense)+int(vm.terrain_defense)]
	summary.tooltip_text = "%s · %s\nEntwicklung %d/10 · Versorgung %d" % [vm.kingdom,vm.empire,vm.development,vm.supply]
	var pending: bool = main._lan_active() and main.lan_session.pending_command
	_refresh_focus(game,vm)
	_refresh_supply(game,id)
	if vm.own:
		fields.buildings.text = "Entwicklung %d/10 · Örtliche Gebäude mit höchstens drei Stufen" % int(vm.development)
		for building in vm.buildings:
			var key := "build:"+str(building.key)
			action_buttons[key].text = "%s %d/3 · %d Gold" % [building.name,building.level,building.cost]
			action_buttons[key].disabled = not building.enabled or pending or game.game_over
			fields[key].text = str(building.effect) + ("\n"+str(building.reason) if not str(building.reason).is_empty() else "")
	_refresh_local_forces(game,vm,army)
	action_buttons.army.disabled = not vm.own or int(game.house().gold) < 50 or pending or game.game_over
	var armies: Array = game.house().get("armies",[])
	var rebuild: bool = army_picker.item_count != armies.size()
	if not rebuild:
		for index in armies.size():
			if army_picker.get_item_id(index) != int(armies[index].id): rebuild = true; break
	if rebuild: army_picker.clear()
	for index in armies.size():
		var field_army: Dictionary = armies[index]
		var station: Dictionary = game.province(str(field_army.province))
		var label := "Heer %d · %d Mann · %s" % [int(field_army.id),int(field_army.strength),str(station.get("name","?"))]
		if rebuild: army_picker.add_item(label,int(field_army.id))
		else: army_picker.set_item_text(index,label)
	army_picker.visible = army_picker.item_count > 1 and (vm.own or military_context)
	army_picker.disabled = pending or game.game_over
	if army_picker.item_count > 0: army_picker.select(0)
	action_buttons.army.visible = vm.own and army.is_empty()
	fields.field_army.visible = not army.is_empty() and (vm.own or military_context)
	action_buttons.focus_army.visible = fields.field_army.visible and str(army.province) != id
	action_buttons.focus_army.disabled = not action_buttons.focus_army.visible
	action_buttons.march.visible = army_near and str(army.province) != id and (vm.own or claimed)
	action_buttons.march.disabled = pending or game.game_over or not game.can_march(id)
	action_buttons.siege.visible = not vm.own and claimed and army_near
	action_buttons.siege.disabled = pending or game.game_over or not bool(military.siege.get("ok",false))
	action_buttons.siege.tooltip_text = str(military.siege.get("reason",""))
	if not army.is_empty():
		var station: Dictionary = game.province(str(army.province))
		fields.field_army.text = "Deine Feldarmee · %d Mann · Moral %d\nStation: %s · Grundunterhalt %d Gold/Jahr" % [int(army.strength),int(army.morale),str(station.get("name","?")),int(army.get("upkeep",0))]
	action_buttons.fleet.disabled = not game.can_raise_fleet(id) or pending
	action_buttons.fleet.text = "Flotte aufstellen · 60 Gold"
	main.recruit_btn.visible = vm.own
	action_buttons.fleet.visible = vm.own and vm.coastal and game.fleet_for().is_empty()
	action_buttons.blockade.visible = not vm.own and vm.coastal and not game.fleet_for().is_empty() and game._maritime_reachable(str(game.fleet_for().get("province","")),id)
	action_buttons.blockade.disabled = pending or game.game_over or not game.can_blockade(id)
	action_buttons.blockade.tooltip_text = game.blockade_reason(id)
	for key in ["peace","secret_discover","secret_expose"]:
		action_buttons[key].visible = not vm.own
		action_buttons[key].disabled = pending or game.game_over
	if not vm.own:
		var secret_known := false
		for secret in game.house().get("secrets",[]):
			if int(secret.get("target",-1)) == int(vm.owner_index): secret_known = true
		action_buttons.secret_discover.visible = not secret_known
		action_buttons.secret_expose.visible = secret_known
		var peace_reason: String = game.peace_reason(int(vm.owner_index))
		action_buttons.peace.visible = peace_reason.is_empty()
		action_buttons.peace.tooltip_text = peace_reason
	main.attack_btn.visible = not vm.own and claimed and army_near
	main.attack_btn.disabled = pending or game.game_over or not bool(military.assault.get("ok",false))
	main.attack_btn.tooltip_text = str(military.assault.get("reason",""))
	main.attack_btn.text = "Stürmen · %d Gold" % int(military.assault.get("cost",25))
	action_buttons.claim.visible = not vm.own and not claimed and claim_relevant
	action_buttons.claim.disabled = pending or game.game_over or not claim_reason.is_empty()
	action_buttons.claim.tooltip_text = claim_reason
	fields.war.visible = not vm.own and military_context
	fields.war.text = "Anspruch vorhanden." if claimed else ("Anspruch als Kriegsgrund vorbereiten." if claim_reason.is_empty() else claim_reason)
	_refresh_transport(game,transport,pending)
	_refresh_campaign(game,vm,army,pending,naval_context,military_context,army_near)
	if vm.own: _refresh_knowledge(game,vm)
	fields.achievements.text = ""
	if not vm.own:
		fields.achievements.text = "%s · Beziehung %+d" % [vm.owner,int(game.opinion[int(vm.owner_index)])]
		if not military_context: fields.achievements.text += "\nKein unmittelbares Kriegsziel. Diplomatie betrifft das besitzende Haus."
	if main._lan_active():
		status.text = "Gastgeber bestätigt die Aktion …" if pending else str(main.lan_session.status)
	status.visible = not status.text.is_empty()
	show_section(current_section)

func _refresh_local_forces(game, vm: Dictionary, selected_army: Dictionary) -> void:
	var rows: Array[String] = []
	if vm.own: rows.append("Aufgebotsgrenze %d Mann" % int(vm.capacity.maximum))
	if int(vm.blockade)>0: rows.append("Blockade noch %d Monate" % int(vm.blockade))
	if vm.own and game.house().get("armies",[]).size()>1:
		rows.append("Heeresunterhalt des Hauses: %d Gold/Jahr" % int(vm.army_upkeep_total))
	for house_index in game.houses.size():
		var house: Dictionary = game.houses[house_index]
		for army in house.get("armies",[]):
			if str(army.get("province",""))!=str(vm.id): continue
			if house_index==game.player and not selected_army.is_empty() and int(army.id)==int(selected_army.id): continue
			rows.append("%s · Heer %d: %d Mann · Moral %d" % [house.name,int(army.id),int(army.strength),int(army.get("morale",100))])
	for fleet in vm.fleets:
		rows.append("%s: %d Schiffe vor Ort" % [fleet.house,fleet.ships])
	fields.army.text = "\n".join(rows)
	fields.army.visible = not rows.is_empty()

func _refresh_campaign(game, vm: Dictionary, army: Dictionary, pending: bool, naval_context: bool, military_context: bool, army_near: bool) -> void:
	var military: Dictionary=vm.military
	var recovery: Dictionary=military.recovery
	var relief: Dictionary=military.relief
	var disband: Dictionary=military.disband
	var locked: bool=pending or game.game_over
	action_buttons.relieve.visible = vm.own and bool(military.threatened)
	action_buttons.relieve.disabled = locked or not bool(relief.get("ok",false))
	action_buttons.relieve.tooltip_text = str(relief.get("reason",""))
	action_buttons.recover_army.visible = vm.own and bool(military.own_station) and not bool(military.threatened) and bool(recovery.get("needed",false))
	action_buttons.recover_army.disabled = locked or not bool(recovery.get("ok",false))
	action_buttons.recover_army.tooltip_text = str(recovery.get("reason",""))
	action_buttons.recover_army.text = "Auffüllen und ordnen"+(" · %d Gold" % int(recovery.cost) if bool(recovery.get("ok",false)) else "")
	action_buttons.disband_army.visible = vm.own and bool(military.own_station) and not bool(military.threatened)
	action_buttons.disband_army.disabled = locked or not bool(disband.get("ok",false))
	action_buttons.disband_army.tooltip_text = str(disband.get("reason","")) if not bool(disband.get("ok",false)) else "Diesen Verband ohne Gold- oder Soldatenerstattung auflösen. Bestätigung folgt."
	if not _pending_disband.is_empty() and (locked or not _confirmation_matches(disband)): _clear_disband()
	var lines: Array[String]=[]
	var reasons: Array[String]=[]
	if not vm.own and military_context:
		var siege: Dictionary=military.siege
		var assault: Dictionary=military.assault
		lines.append("Festung · Mauern %d · Garnison %d" % [int(siege.get("wall_level",0)),int(siege.get("garrison",vm.levy))])
		lines.append("Verteidigung %+d%%" % int(siege.get("fort_bonus",0)))
		if int(siege.get("defender_strength",0))>0:
			lines.append("Verteidigende Feldheere: %d Mann" % int(siege.defender_strength))
		if army_near and int(siege.get("progress",0))>0:
			lines.append("Belagerung %d → %d%% · etwa %d Aktionen" % [int(siege.current),int(siege.next),int(siege.remaining_actions)])
		elif int(siege.get("current",0))>0: lines.append("Belagerung %d%%" % int(siege.current))
		if bool(assault.get("ok",false)):
			lines.append("Sturmchance %d%% · Angriff %d / Abwehr %d" % [roundi(float(assault.chance)*100),roundi(float(assault.attack_power)),roundi(float(assault.defense))])
		if army_near and siege.get("supply",{}) is Dictionary and not siege.get("supply",{}).is_empty():
			var supply: Dictionary=siege.supply
			var shortfall:=int(supply.get("shortfall",0))
			lines.append(("Versorgung gedeckt" if shortfall==0 else "Versorgung: %d Mann ungedeckt" % shortfall)+" · Bilanz in %d Monaten" % int(supply.get("annual_in_months",0)))
		if not naval_context and game.has_claim(selected_id):
			_add_reason(reasons,str(siege.get("reason","")))
			if not army.is_empty() and int(army.get("morale",0))>0:
				_add_reason(reasons,str(assault.get("reason","")))
		fields.battle.tooltip_text="Der Belagerungsschritt nutzt tatsächlichen Festungswiderstand, effektive Stärke und gemeinsame Versorgung. Die geschätzte Dauer gilt bei unveränderter Lage. Sturm und Belagerung verbrauchen dieselbe Heeresaktion."
	elif action_buttons.relieve.visible:
		lines.append("Eigene Festung · Garnison %d" % int(vm.levy))
		lines.append("Fremde Feldheere vor Ort: %d Mann" % int(military.foreign_strength))
		if bool(relief.get("ok",false)):
			lines.append("Entsatzchance %d%% · Angriff %d / Abwehr %d" % [roundi(float(relief.chance)*100),roundi(float(relief.attack_power)),roundi(float(relief.defense))])
		_add_reason(reasons,str(relief.get("reason","")))
		fields.battle.tooltip_text="Entsatz greift tatsächliche fremde Verbände an. Er verändert keinen Besitz und kostet kein Gold."
	elif action_buttons.recover_army.visible:
		if bool(recovery.get("ok",false)):
			lines.append("Feldlager · %d → %d Mann" % [int(recovery.current_strength),int(recovery.new_strength)])
			lines.append("Moral %d → %d · Aufgebot %d → %d" % [int(recovery.current_morale),int(recovery.new_morale),int(recovery.levy_before),int(recovery.levy_after)])
			lines.append("Heeresunterhalt danach: %d Gold/Jahr" % int(recovery.house_upkeep_after))
		else:
			lines.append("Feldlager · %d Mann · Moral %d" % [int(recovery.get("current_strength",0)),int(recovery.get("current_morale",0))])
		fields.field_army.hide()
		_add_reason(reasons,str(recovery.get("reason","")))
		fields.battle.tooltip_text="Die neuen Soldaten werden dem örtlichen Aufgebot entnommen. Mindestens %d Mann bleiben Reserve. Auffüllen verbraucht eine Heeresaktion; Unterhalt bleibt jährlich." % int(recovery.get("reserve",50))
	if action_buttons.march.visible:
		_add_reason(reasons,game.march_reason(selected_id))
	fields.battle.text="\n".join(lines)
	fields.battle.visible=not lines.is_empty()
	if fields.battle.visible: fields.supply.hide()
	fields.orders.text="\n".join(reasons)
	fields.orders.visible=not reasons.is_empty()

func _add_reason(reasons: Array[String], reason: String) -> void:
	if not reason.is_empty() and not reasons.has(reason): reasons.append(reason)

func _refresh_transport(game, preview: Dictionary, pending: bool) -> void:
	var relevant := not str(preview.get("route_id","")).is_empty()
	var button: Button = action_buttons.transport_army
	button.visible = relevant
	fields.transport.visible = relevant
	if not relevant: return
	var reason := str(preview.get("reason",""))
	button.disabled = pending or game.game_over or not bool(preview.ok)
	button.tooltip_text = reason if not reason.is_empty() else "Vorhandenes Heer und Geleit über den geprüften Küstenweg versetzen."
	var origin: Dictionary = game.province(str(preview.origin))
	var target: Dictionary = game.province(str(preview.target))
	fields.transport.text = "%s → %s\n%d Schiffe nötig · %d vorhanden\nKapazität %d Mann" % [origin.get("name","?"),target.get("name","?"),int(preview.ships_required),int(preview.ships_available),int(preview.capacity)]
	if not reason.is_empty():
		if not fields.war.visible or fields.war.text!=reason:
			fields.transport.text += "\n"+reason
	else:
		fields.transport.text += "\nLandung ohne Eroberung · Belagerung ab dem nächsten Monat."
	if int(preview.get("defending_ships",0))>0:
		fields.transport.text += "\n%d feindliche Schiffe am Ziel · Seekampf möglich." % int(preview.defending_ships)

func _refresh_knowledge(game, vm: Dictionary) -> void:
	var research: Dictionary = game.house().research
	var active := str(research.active)
	fields.research.text = "%d Innovationen erforscht · gelten im ganzen Haus." % research.known.size()
	var available: Array[String] = []
	var effects: Array[String] = []
	for choice in vm.research:
		if str(choice.id) == active:
			fields.research.text = "%s · noch %d Monate\n" % [choice.name,int(research.months)] + fields.research.text
		if bool(choice.get("known",false)) and bool(choice.get("province_applicable",false)):
			effects.append("%s: %s" % [choice.name,choice.get("effect_text","")])
		elif not bool(choice.get("known",false)) and str(choice.get("reason","")).is_empty():
			available.append(str(choice.name))
	if not effects.is_empty():
		fields.research.text += "\n\nHier wirksam:\n" + "\n".join(effects.slice(0,3))
		if effects.size() > 3: fields.research.text += "\nWeitere Wirkungen im Forschungsplan."
	elif active.is_empty():
		fields.research.text += "\nNoch keine örtlichen Forschungsboni."
	if active.is_empty() and not available.is_empty():
		fields.research.text += "\n\nMöglich: " + ", ".join(available.slice(0,3))
	fields.research.tooltip_text = "\n".join(effects)
