extends VBoxContainer
## Stabile örtliche Verwaltung. Keine Spielregeln und keine direkte Mutation.
const ViewModel = preload("res://scripts/ViewModelBuilder.gd")
var main
var selected_id := ""
var section_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var sections: Dictionary = {}
var fields: Dictionary = {}
var research_rows: Dictionary = {}
var current_section := "buildings"
var title: Label
var summary: Label
var status: Label
var army_picker: OptionButton
var section_tabs: GridContainer
var focus_picker: OptionButton
var focus_box: VBoxContainer
var _focus_province := ""

func configure(host) -> void:
	main = host
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	title = _text("Wähle eine Spielregion", 16)
	summary = _text("Gebäude, Forschung und Truppen erscheinen hier direkt nach der Auswahl.")
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
	_action("siege", "Belagerung vorantreiben", {"id":"siege"}, sections.army)
	fields.orders = _text("",11,sections.army)
	fields.battle = _text("",11,sections.army)
	_action("fleet", "Flotte aufstellen", {"id":"fleet"}, sections.army)
	fields.research = _text("Forschung des Hauses – ihre Wirkungen gelten auch für diese Provinz.",12,sections.research)
	fields.achievements = _text("",12,sections.achievements)
	_action("blockade","Küste blockieren",{"id":"blockade"},sections.army)
	_action("peace","Frieden · 24 Monate",{"id":"peace"},sections.achievements)
	_action("secret_discover","Geheimnis aufdecken",{"id":"secret_discover"},sections.achievements)
	_action("secret_expose","Geheimnis ausnutzen",{"id":"secret_expose"},sections.achievements)
	# Erst die nächste Entscheidung, darunter die ausführlichen Bestandszahlen.
	var war_order: Array = [fields.war,action_buttons.claim,army_picker,fields.field_army,action_buttons.march,action_buttons.siege,main.attack_btn,fields.orders,fields.battle,action_buttons.army,action_buttons.focus_army,fields.supply,action_buttons.fleet,action_buttons.blockade,main.recruit_btn,fields.army]
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
	var result: Dictionary = main._dispatch(command)
	status.text = str(result.get("message", ""))

func _select_army(index: int) -> void:
	if index < 0 or index >= army_picker.item_count: return
	_command({"id":"select_army","army":army_picker.get_item_id(index)})

func _apply_focus() -> void:
	if focus_picker.selected < 0: return
	_command({"id":"province_focus","focus":str(focus_picker.get_item_metadata(focus_picker.selected))})

func _preview_focus() -> void:
	if main.game == null or selected_id.is_empty() or focus_picker.selected < 0: return
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
	for key in sections:
		sections[key].visible = key == id
		section_buttons[key].set_pressed_no_signal(key == id)

func refresh(game, id: String) -> void:
	if selected_id != id:
		status.text = ""
	selected_id = id
	var vm: Dictionary = ViewModel.province(game,id)
	section_tabs.columns = 1 if main.get_meta("modern_interface").text_scale > 1.3 else 2
	for key in section_buttons:
		section_buttons[key].disabled = vm.is_empty()
		section_buttons[key].visible = vm.is_empty() or vm.own or not key in ["buildings","research"]
	if vm.is_empty():
		title.text = "Dein Haus · %d Spielregionen" % game.owned().size()
		summary.text = "Wähle auf der Karte eine Provinz. Ihre Verwaltung öffnet sich hier ohne zusätzlichen Dialog."
		for section in sections.values(): section.visible = false
		return
	if not vm.own and current_section in ["buildings","research"]:
		current_section = "army"
	section_buttons.army.text = "Heer & Flotte" if vm.own else "Krieg"
	section_buttons.achievements.text = "Vermächtnis" if vm.own else "Diplomatie"
	title.text = str(vm.name)
	summary.text = "%s · %s\n%d Gold/Jahr · Aufgebot %d · Verteidigung %+d%%" % [vm.terrain,vm.owner,vm.income,vm.levy,int(vm.defense)+int(vm.terrain_defense)]
	summary.tooltip_text = "%s · %s\nEntwicklung %d/10 · Versorgung %d" % [vm.kingdom,vm.empire,vm.development,vm.supply]
	var pending: bool = main._lan_active() and main.lan_session.pending_command
	_refresh_focus(game,vm)
	_refresh_supply(game,id)
	fields.buildings.text = "Entwicklung %d/10 · Örtliche Gebäude mit höchstens drei Stufen" % int(vm.development)
	for building in vm.buildings:
		var key := "build:"+str(building.key)
		action_buttons[key].text = "%s %d/3 · %d Gold" % [building.name,building.level,building.cost]
		action_buttons[key].disabled = not building.enabled or pending
		fields[key].text = str(building.effect) + ("\n"+str(building.reason) if not str(building.reason).is_empty() else "")
	fields.army.text = "Örtliches Aufgebot: %d / Kapazität %d\nBelagerung %d%% · Blockade %d Monate\nHeeresunterhalt des Hauses: %d Gold/Jahr" % [vm.levy,vm.capacity.maximum,vm.siege,vm.blockade,vm.army_upkeep_total]
	for army in vm.armies:
		fields.army.text += "\n%s: %d Mann · Moral %d · Grundunterhalt %d" % [army.house,army.strength,army.morale,army.upkeep]
	for fleet in vm.fleets:
		fields.army.text += "\n%s: %d Schiffe vor Ort" % [fleet.house,fleet.ships]
	action_buttons.army.disabled = not vm.own or int(game.house().gold) < 50 or pending
	var army: Dictionary = game.army_for()
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
	army_picker.visible = army_picker.item_count > 1
	army_picker.disabled = pending or game.game_over
	if army_picker.item_count > 0: army_picker.select(0)
	action_buttons.army.visible = vm.own and army.is_empty()
	fields.field_army.visible = not army.is_empty()
	action_buttons.focus_army.visible = not army.is_empty()
	action_buttons.march.visible = not army.is_empty() and str(army.province) != id
	action_buttons.march.disabled = pending or game.game_over or not game.can_march(id)
	action_buttons.siege.visible = not vm.own
	action_buttons.siege.disabled = pending or game.game_over or not game.can_siege(id)
	fields.orders.visible = not army.is_empty() or not vm.own
	if not army.is_empty():
		var station: Dictionary = game.province(str(army.province))
		fields.field_army.text = "Deine Feldarmee · %d Mann · Moral %d\nStation: %s · Unterhalt %d Gold/Jahr" % [int(army.strength),int(army.morale),str(station.get("name","?")),game.army_upkeep()]
		fields.orders.text = game.march_reason(id) if str(army.province) != id else "Armee am Ziel."
	else:
		fields.orders.text = "Stelle zuerst in einer eigenen Provinz eine Feldarmee auf."
	if not action_buttons.march.disabled and action_buttons.march.visible:
		fields.orders.text = "Marsch ins ausgewählte Nachbargebiet. Ein Befehl je Monat; die Belagerung folgt frühestens im nächsten Monat."
	if not vm.own:
		var siege_reason: String = game.siege_reason(id)
		fields.orders.text += "\n" + (siege_reason if not siege_reason.is_empty() else "Belagerung bereit: ein Schritt je Monat, ohne zusätzliche Goldkosten.")
	fields.battle.visible = not vm.own
	if not vm.own:
		var preview: Dictionary = game.attack_preview(id)
		var army_contribution := int(preview.get("field_army_strength",0))
		main.attack_btn.text = "Sturmangriff · 25 Gold" if army_contribution > 0 else "Aufgebotsangriff · 25 Gold"
		fields.battle.text = "%d%% Siegchance · Angriff %d / Abwehr %d\nFeldarmee: +%d Kampfkraft" % [int(round(float(preview.get("chance",0))*100)),int(preview.get("attack_power",0)),int(preview.get("defense",0)),army_contribution]
		fields.battle.tooltip_text = "Berechnung aus Gelände, Doktrin, Forschung und örtlichem Aufgebot. Eine bereite benachbarte Feldarmee verstärkt einen Angriff pro Monat. Niederlage: −20 % Stärke der beteiligten Feldarmee."
		if not army.is_empty() and int(army.get("last_siege_month",-1)) == game._now():
			fields.battle.text += "\nFeldheer diesen Monat bereits eingesetzt. Dieser Angriff nutzt nur das Aufgebot."
	action_buttons.fleet.disabled = not game.can_raise_fleet(id) or pending
	action_buttons.fleet.text = "Flotte aufstellen" if vm.coastal else "Keine Küste · Flotte nicht möglich"
	main.recruit_btn.visible = vm.own
	action_buttons.fleet.visible = vm.own and vm.coastal
	action_buttons.blockade.visible = not vm.own and vm.coastal and not game.fleet_for().is_empty()
	action_buttons.blockade.disabled = pending or game.game_over or not game.can_blockade(id)
	for key in ["peace","secret_discover","secret_expose"]:
		action_buttons[key].visible = not vm.own
		action_buttons[key].disabled = pending or game.game_over
	if not vm.own:
		var secret_known := false
		for secret in game.house().get("secrets",[]):
			if int(secret.get("target",-1)) == int(vm.owner_index): secret_known = true
		action_buttons.secret_discover.visible = not secret_known
		action_buttons.secret_expose.visible = secret_known
		action_buttons.peace.visible = game.truce_until(int(vm.owner_index)) <= game._now()
	main.attack_btn.visible = not vm.own
	main.attack_btn.disabled = pending or game.game_over or not game.can_attack(id)
	var claimed: bool = game.has_claim(id)
	var border: bool = game.is_border_province(game.player,id)
	action_buttons.claim.visible = not vm.own and not claimed
	action_buttons.claim.disabled = pending or game.game_over or vm.own or claimed or not border or int(game.house().gold) < 40
	fields.war.visible = not vm.own
	fields.war.text = "Anspruch vorhanden." if claimed else ("Für einen Angriff benötigst du einen Anspruch." if border else "Ein Anspruch ist nur an der eigenen Grenze möglich.")
	if not claimed and border and int(game.house().gold) < 40:
		fields.war.text = "Nicht genug Gold: Ein Anspruch kostet 40 Gold."
	if claimed:
		var owner: int = int(vm.owner_index)
		if game.truce_until(owner) > game._now():
			fields.war.text += " Waffenstillstand: noch %d Monate." % (game.truce_until(owner)-game._now())
		elif int(game.opinion[owner]) >= 60:
			fields.war.text += " Die gute Beziehung verhindert einen Angriff."
		elif int(game.house().gold) < 25:
			fields.war.text += " Für einen Sturmangriff fehlen 25 Gold."
	fields.research.text = "Forschung von %s · hausweite Projekte. Bei jeder Innovation steht, ob sie hier örtlich wirkt." % vm.owner
	var choices: Array = vm.research if vm.own else []
	for choice in choices:
		var key := str(choice.id)
		if not research_rows.has(key):
			var box := VBoxContainer.new()
			sections.research.add_child(box)
			_action("research:"+key,"",{"id":"research","innovation":key},box)
			research_rows[key] = _text("",11,box)
		var known: bool = bool(choice.get("known",game.houses[int(vm.owner_index)].research.known.has(key)))
		action_buttons["research:"+key].text = str(choice.name) + (" · Erforscht" if known else " · %d Gold" % int(choice.gold))
		action_buttons["research:"+key].disabled = not vm.own or not str(choice.get("reason","")).is_empty() or pending
		var local_effect := "Hier örtlich wirksam." if bool(choice.get("province_applicable",true)) else "Hier ohne örtliche Wirkung."
		research_rows[key].text = str(choice.get("effect_text","")) + "\n" + str(choice.get("applicability","Hausweit")) + "\n" + local_effect + ("\n"+str(choice.get("reason","")) if not known and not str(choice.get("reason","")).is_empty() else "")
	fields.achievements.text = "Vermächtnisse des besitzenden Hauses"
	if not vm.own:
		fields.achievements.text = "%s · Beziehung %+d\nAnsprüche, Heer und Belagerung stehen unter Krieg. Diplomatie betrifft das besitzende Haus." % [vm.owner,int(game.opinion[int(vm.owner_index)])]
	for legacy in vm.legacies:
		if vm.own: fields.achievements.text += "\n%s · Stufe %d\n%s" % [legacy.name,legacy.level,legacy.effect]
	if vm.own:
		fields.achievements.text += "\n\nErforschtes Wissen: %d Innovationen" % game.houses[int(vm.owner_index)].research.known.size()
	if main._lan_active():
		status.text = "Gastgeber bestätigt die Aktion …" if pending else str(main.lan_session.status)
	show_section(current_section)
