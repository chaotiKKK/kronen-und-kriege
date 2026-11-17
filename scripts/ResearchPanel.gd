extends RefCounted
## Stable, house-wide research view; the Game owns prerequisites and effects.
const Definitions = preload("res://scripts/Infrastructure.gd")
const Interface = preload("res://scripts/ModernInterface.gd")

var cards: Dictionary = {}
var detail_labels: Dictionary = {}
var prerequisite_labels: Dictionary = {}
var reason_labels: Dictionary = {}
var applicability_labels: Dictionary = {}
var branch_filter: OptionButton
var scope_label: Label
var status_label: Label
var progress_bar: ProgressBar
var selected_branch := "Alle"
var _branches: Array = ["Alle"]
var _main
var _root: VBoxContainer
var _game
var _province_id := ""
var _last_active := ""
var _pending_id := ""
var _dispatching := false
var _message := "Ein Projekt kann gleichzeitig erforscht werden. Voraussetzungen und Kosten stehen bei jeder Innovation."

func configure(main, parent: VBoxContainer) -> void:
	if _main == main and is_instance_valid(_root):
		return
	_main = main
	_root = VBoxContainer.new()
	_root.name = "Forschungsplan"
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 8)
	parent.add_child(_root)
	scope_label = _label("", 12)
	scope_label.name = "ForschungsGeltungsbereich"
	_root.add_child(scope_label)
	main.research_label = _label("", 12)
	main.research_label.name = "Forschungsfortschritt"
	_root.add_child(main.research_label)
	progress_bar = ProgressBar.new()
	progress_bar.name = "MessbarerForschungsfortschritt"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(progress_bar)
	status_label = _label(_message, 12)
	status_label.name = "ForschungsAktionsstatus"
	_root.add_child(status_label)
	for definition in Definitions.INNOVATIONS.values():
		var branch := str(definition.branch)
		if not _branches.has(branch):
			_branches.append(branch)
	branch_filter = main._drop_option(_branches)
	branch_filter.name = "Forschungszweig"
	branch_filter.accessibility_name = "Forschungszweig anzeigen"
	branch_filter.custom_minimum_size.y = 44 if OS.has_feature("android") else 36
	branch_filter.item_selected.connect(func(index: int): set_branch(str(_branches[index])))
	_root.add_child(branch_filter)
	main.research_buttons = {}
	for id in Definitions.INNOVATIONS:
		_build_card(str(id), Definitions.INNOVATIONS[id])

func _label(text: String, pixels: int) -> Label:
	var label: Label = _main._label(text, pixels)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _build_card(id: String, definition: Dictionary) -> void:
	var card := VBoxContainer.new()
	card.name = "Forschung_" + id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 4)
	card.set_meta("research_branch", str(definition.branch))
	_root.add_child(card)
	card.add_child(HSeparator.new())
	card.add_child(_label("%s · %s" % [definition.branch, definition.name], 15))
	card.add_child(_label(str(definition.description), 12))
	var detail := _label("", 12)
	card.add_child(detail)
	detail_labels[id] = detail
	var prerequisite := _label("", 11)
	card.add_child(prerequisite)
	prerequisite_labels[id] = prerequisite
	var applicability := _label("", 11)
	card.add_child(applicability)
	applicability_labels[id] = applicability
	var button: Button = _main._button("", _start.bind(id))
	button.name = "ForschungStart_" + id
	button.set_meta("atlas_font_size", 12)
	button.set_meta("atlas_applied_scale", -1.0)
	button.add_theme_font_size_override("font_size", int(round(12 * Interface.text_scale)))
	button.custom_minimum_size = Vector2(0, 44 if OS.has_feature("android") else 36)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for role in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style = button.get_theme_stylebox(role)
		if style is StyleBoxFlat:
			var compact: StyleBoxFlat = style.duplicate()
			compact.content_margin_top = 4
			compact.content_margin_bottom = 4
			button.add_theme_stylebox_override(role, compact)
	card.add_child(button)
	_main.research_buttons[id] = button
	var reason := _label("", 11)
	reason.name = "ForschungVoraussetzung_" + id
	card.add_child(reason)
	reason_labels[id] = reason
	cards[id] = card

func set_branch(branch: String) -> void:
	var index := _branches.find(branch)
	if index < 0:
		return
	selected_branch = branch
	branch_filter.select(index)
	for card in cards.values():
		card.visible = branch == "Alle" or str(card.get_meta("research_branch")) == branch

func _network_pending() -> bool:
	return _main.lan_session != null and str(_main.lan_session.phase) == "playing" and bool(_main.lan_session.pending_command)

func refresh(game, province_id: String = "") -> void:
	if game == null or not is_instance_valid(_root):
		return
	_game = game
	_province_id = province_id
	var house: Dictionary = game.house()
	var research: Dictionary = house.research
	var active := str(research.active)
	var known: Array = research.known
	if not _last_active.is_empty() and active.is_empty() and known.has(_last_active):
		_message = str(Definitions.INNOVATIONS[_last_active].name) + " abgeschlossen. Weitere Projekte sind jetzt verfügbar."
	_last_active = active
	var pending := _network_pending()
	if not _pending_id.is_empty() and not pending:
		_message = str(_main.lan_session.status) if _main.lan_session != null else "Die WLAN-Verbindung wurde beendet."
		_pending_id = ""
	status_label.text = "Gastgeber bestätigt das Forschungsprojekt …" if pending else _message
	scope_label.text = "Forschung gilt für das gesamte Haus %s. Geländeabhängige Wirkungen greifen nur in passenden eigenen Regionen." % house.name
	var province: Dictionary = game.province(province_id)
	if not province.is_empty():
		scope_label.text += " Ausgewähltes Gebiet: %s." % province.name
		if int(province.owner) != int(game.player):
			scope_label.text += " Dieses Gebiet gehört einem anderen Haus; örtliche Vorteile gelten erst bei eigenem Besitz."
	progress_bar.visible = not active.is_empty()
	if active.is_empty():
		_main.research_label.text = "%d von %d Innovationen erforscht · kein Projekt aktiv · Straßenhandel: +%d Gold/Jahr" % [known.size(), Definitions.INNOVATIONS.size(), game.road_income()]
		progress_bar.value = 0
	else:
		var definition: Dictionary = Definitions.INNOVATIONS[active]
		var total := int(definition.months)
		var remaining := int(research.months)
		_main.research_label.text = "%s · noch %d Monate · %d von %d Monaten abgeschlossen" % [definition.name, remaining, total - remaining, total]
		progress_bar.value = clampf(float(total - remaining) / float(total) * 100, 0, 100)
		progress_bar.accessibility_name = "%s: %d von %d Monaten abgeschlossen" % [definition.name, total - remaining, total]
	for choice in game.research_choices(game.player, province_id):
		var id := str(choice.id)
		if not cards.has(id):
			continue
		detail_labels[id].text = "Wirkung: %s\nKosten: %d Gold · Forschungszeit: %d Monate" % [choice.effect_text, choice.gold, choice.months]
		var prerequisite := str(choice.requires)
		prerequisite_labels[id].text = "Voraussetzung: keine" if prerequisite.is_empty() else "Voraussetzung: %s" % str(Definitions.INNOVATIONS[prerequisite].name)
		var applicability := str(choice.applicability)
		if not province.is_empty():
			applicability += " · Hier anwendbar" if bool(choice.province_applicable) else " · In dieser Region nicht anwendbar"
		applicability_labels[id].text = applicability
		var button: Button = _main.research_buttons[id]
		var reason := str(choice.get("blocked_reason", choice.reason))
		if bool(choice.known):
			button.text = str(choice.name) + " · Erforscht"
		elif bool(choice.active):
			button.text = "%s · In Arbeit · noch %d Monate" % [choice.name, choice.remaining]
			reason = "Dieses Projekt wird bereits erforscht."
		else:
			button.text = "%s erforschen · %d Gold · %d Monate" % [choice.name, choice.gold, choice.months]
		if pending or _dispatching:
			reason = "Die laufende Forschungsanfrage wird noch bestätigt."
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason if not reason.is_empty() else str(choice.effect_text)
		button.accessibility_name = str(choice.name) + ". " + str(detail_labels[id].text) + ". " + reason
		reason_labels[id].text = reason
		reason_labels[id].visible = not reason.is_empty()
	set_branch(selected_branch)

func _start(innovation: String) -> void:
	if _game == null or _main.research_buttons[innovation].disabled:
		return
	_dispatching = true
	refresh(_game, _province_id)
	var result: Dictionary = _main._dispatch({"id":"research","innovation":innovation})
	_dispatching = false
	_message = str(result.get("message", ""))
	_pending_id = innovation if _network_pending() else ""
	refresh(_main.game, _province_id)
