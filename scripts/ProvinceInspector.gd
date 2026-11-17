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

func configure(host) -> void:
	main = host
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	title = _text("Wähle eine Spielregion", 16)
	summary = _text("Gebäude, Forschung und Truppen erscheinen hier direkt nach der Auswahl.")
	var tabs := GridContainer.new()
	tabs.columns = 2
	add_child(tabs)
	var group := ButtonGroup.new()
	for entry in [["buildings","Ausbau"],["army","Heer & Flotte"],["research","Wissen"],["achievements","Errungenschaften"]]:
		var id := str(entry[0])
		var button: Button = main._button(entry[1], show_section.bind(id))
		main.get_meta("modern_interface")._style_tool(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		tabs.add_child(button)
		section_buttons[id] = button
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		sections[id] = content
		add_child(content)
	fields.buildings = _text("", 12, sections.buildings)
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
	_action("army", "Armee aufstellen · 50 Gold", {"id":"army"}, sections.army)
	_action("fleet", "Flotte aufstellen", {"id":"fleet"}, sections.army)
	fields.research = _text("Forschung des Hauses – ihre Wirkungen gelten auch für diese Provinz.",12,sections.research)
	fields.achievements = _text("",12,sections.achievements)
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

func show_section(id: String) -> void:
	if not sections.has(id): return
	current_section = id
	for key in sections:
		sections[key].visible = key == id
		section_buttons[key].set_pressed_no_signal(key == id)

func refresh(game, id: String) -> void:
	selected_id = id
	var vm: Dictionary = ViewModel.province(game,id)
	for button in section_buttons.values():
		button.disabled = vm.is_empty()
	if vm.is_empty():
		title.text = "Dein Haus · %d Spielregionen" % game.owned().size()
		summary.text = "Wähle auf der Karte eine Provinz. Ihre Verwaltung öffnet sich hier ohne zusätzlichen Dialog."
		for section in sections.values(): section.visible = false
		return
	title.text = str(vm.name)
	summary.text = "%s · %s\n%s · %s\nLandsertrag %d Gold/Jahr · Entwicklung %d/10\nAufgebot %d · Versorgung %d · Verteidigung %+d%%" % [vm.terrain,vm.owner,vm.kingdom,vm.empire,vm.income,vm.development,vm.levy,vm.supply,int(vm.defense)+int(vm.terrain_defense)]
	var pending: bool = main._lan_active() and main.lan_session.pending_command
	fields.buildings.text = "Örtliche Gebäude · höchstens drei Stufen" if vm.own else "Fremde Provinz · Anlagen sind einsehbar, nicht veränderbar"
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
	action_buttons.fleet.disabled = not game.can_raise_fleet(id) or pending
	action_buttons.fleet.text = "Flotte aufstellen" if vm.coastal else "Keine Küste · Flotte nicht möglich"
	fields.research.text = "Forschung von %s · hausweite Projekte. Bei jeder Innovation steht, ob sie hier örtlich wirkt." % vm.owner
	for choice in vm.research:
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
	for legacy in vm.legacies:
		fields.achievements.text += "\n%s · Stufe %d\n%s" % [legacy.name,legacy.level,legacy.effect]
	fields.achievements.text += "\n\nErforschtes Wissen: %d Innovationen" % game.houses[int(vm.owner_index)].research.known.size()
	if main._lan_active():
		status.text = "Gastgeber bestätigt die Aktion …" if pending else str(main.lan_session.status)
	show_section(current_section)
