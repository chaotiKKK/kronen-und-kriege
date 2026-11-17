extends RefCounted
## Stable presenter for the court-management body. Rules stay in Game;
## all mutations pass through the composition root's command dispatcher.
const ViewModel = preload("res://scripts/ViewModelBuilder.gd")
const Interface = preload("res://scripts/ModernInterface.gd")

var action_buttons: Dictionary = {}
var action_details: Dictionary = {}
var action_reasons: Dictionary = {}
var summary_label: Label
var status_label: Label
var _main
var _game
var _root: VBoxContainer
var _benefit: Label
var _grand_fill: ColorRect
var _grand_target: ColorRect
var _message := "Wähle eine Hofaktion. Kosten und laufender Unterhalt stehen bei jeder Aktion."
var _pending_action := ""
var _dispatching := false

func configure(main) -> void:
	if _main == main and is_instance_valid(_root):
		return
	_main = main
	for child in main.court_body.get_children():
		main.court_body.remove_child(child)
		child.queue_free()
	_root = VBoxContainer.new()
	_root.name = "Hofverwaltung"
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 8)
	main.court_body.add_child(_root)
	summary_label = _label("", 13)
	summary_label.name = "HofZusammenfassung"
	_root.add_child(summary_label)
	# The result must stay reachable when the action list is scrolled down.
	# Main owns this fixed shell (heading / status / scrolling body).
	var shell: Node = main.court_title.get_parent().get_parent()
	status_label = shell.get_node_or_null("HofAktionsstatus") as Label
	if status_label == null:
		status_label = _label(_message, 12)
		status_label.name = "HofAktionsstatus"
		shell.add_child(status_label)
		shell.move_child(status_label, 1)
	status_label.accessibility_name = "Ergebnis und Bestätigung der Hofaktion"
	_benefit = _label("", 11)
	_root.add_child(_benefit)
	_build_action("court", "Hoftag", {"id":"court"})
	_root.add_child(_label("Reliquien", 17))
	for relic in ["crown", "blade", "seal"]:
		_build_action("relic:" + relic, "", {"id":"forge_relic","relic":relic})
	_build_hall_summary()
	_build_action("hall", "Hofhalle ausbauen", {"id":"upgrade_court_hall"})
	_root.add_child(_label("Hofausstattung", 17))
	main.court_amenity_pips = []
	main.court_amenity_buttons = {}
	for amenity in ["table", "chambers", "retinue"]:
		var pips := _pips(3)
		_root.add_child(pips)
		main.court_amenity_pips.append(pips)
		_build_action("amenity:" + amenity, "", {"id":"upgrade_court_amenity","amenity":amenity})
		main.court_amenity_buttons[amenity] = action_buttons["amenity:" + amenity]

func _label(text: String, pixels: int) -> Label:
	var label: Label = _main._label(text, pixels)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _build_action(key: String, title: String, command: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.name = "Hofaktion_" + key.replace(":", "_")
	row.add_theme_constant_override("separation", 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(row)
	var heading := _label(title, 14)
	heading.name = "Aktionsname"
	row.add_child(heading)
	var details := _label("", 12)
	row.add_child(details)
	var button: Button = _main._button(title, _activate.bind(key, command))
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
	row.add_child(button)
	var reason := _label("", 11)
	reason.name = "Aktionsvoraussetzung"
	row.add_child(reason)
	action_buttons[key] = button
	action_details[key] = details
	action_reasons[key] = reason
	button.set_meta("court_heading", heading)

func _build_hall_summary() -> void:
	_root.add_child(_label("Hofhalle", 17))
	_main.court_hall_preview = TextureRect.new()
	_main.court_hall_preview.texture = _main.TEX_COURT
	_main.court_hall_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_main.court_hall_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_main.court_hall_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.court_hall_preview.custom_minimum_size = Vector2(0, 110)
	_root.add_child(_main.court_hall_preview)
	_main.court_hall_stage_label = _label("", 15)
	_root.add_child(_main.court_hall_stage_label)
	_main.court_hall_stats_label = _label("", 12)
	_root.add_child(_main.court_hall_stats_label)
	_main.court_hall_pips = _pips(3)
	_root.add_child(_main.court_hall_pips)
	_main.court_expectation_label = _label("", 12)
	_root.add_child(_main.court_expectation_label)
	_main.court_expectation_track = Control.new()
	_main.court_expectation_track.custom_minimum_size = Vector2(0, 8)
	_main.court_expectation_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_main.court_expectation_track)
	var background := ColorRect.new()
	background.color = Color("514838")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.court_expectation_track.add_child(background)
	_grand_fill = ColorRect.new()
	_grand_fill.color = Color("b79b61")
	_grand_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grand_fill.anchor_bottom = 1
	_main.court_expectation_track.add_child(_grand_fill)
	_grand_target = ColorRect.new()
	_grand_target.color = Color("ede3ce")
	_grand_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grand_target.anchor_bottom = 1
	_grand_target.offset_left = -1
	_grand_target.offset_right = 1
	_main.court_expectation_track.add_child(_grand_target)

func _pips(count: int) -> HBoxContainer:
	var pips := HBoxContainer.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in count:
		var pip := PanelContainer.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(28, 5)
		pips.add_child(pip)
	return pips

func _update_pips(pips: HBoxContainer, level: int) -> void:
	for index in pips.get_child_count():
		var style := StyleBoxFlat.new()
		style.bg_color = Color("b79b61") if index < level else Color("514838")
		style.set_meta("atlas_fixed_color", true)
		pips.get_child(index).add_theme_stylebox_override("panel", style)

func _network_pending() -> bool:
	return _main.lan_session != null and str(_main.lan_session.phase) == "playing" and bool(_main.lan_session.pending_command)

func refresh(game) -> void:
	if game == null or not is_instance_valid(_root):
		return
	_game = game
	var vm: Dictionary = ViewModel.court(game)
	_main.court_title.text = str(vm.title)
	summary_label.text = "%s\nHofausstattung: %d Stufen · %d Gold/Jahr Unterhalt" % [vm.summary, vm.amenity_total, vm.amenity_upkeep]
	_benefit.text = str(vm.benefit)
	var pending := _network_pending()
	if not _pending_action.is_empty() and not pending:
		_message = str(_main.lan_session.status) if _main.lan_session != null else "Die WLAN-Verbindung wurde beendet."
		_pending_action = ""
	status_label.text = "Gastgeber bestätigt die Hofaktion …" if pending else _message
	var reason := "" if game.can_court() else "Zu wenig Gold: Ein Hoftag benötigt 40 Gold."
	_update_action("court", "Hoftag", "Hoftag veranstalten · 40 Gold", "40 Gold → +12 Prestige. Die Hofpracht bleibt unverändert; kein zusätzlicher Jahresunterhalt.", reason, pending)
	for relic in vm.relics:
		var key := "relic:" + str(relic.id)
		var blocked: String = game._relic_reason(str(relic.id), game.player)
		_update_action(key, str(relic.name), str(relic.button_text), "%s · Kosten: %d Gold, %d Prestige · kein zusätzlicher Jahresunterhalt" % [relic.effect, relic.cost_gold, relic.cost_prestige], blocked, pending)
	_main.court_hall_stage_label.text = "Hofhalle · Stufe %d/%d" % [vm.hall, vm.hall_max]
	_main.court_hall_stats_label.text = "Hofpracht %d/100 · Reliquien %d/%d" % [vm.grandeur, vm.relics_owned, vm.relics_total]
	_main.court_expectation_label.text = str(vm.expectation_text) + " · " + str(vm.expectation_corridor)
	_grand_fill.anchor_right = clampf(float(vm.grandeur) / 100, 0, 1)
	_grand_target.anchor_left = clampf(float(vm.expected) / 100, 0, 1)
	_grand_target.anchor_right = _grand_target.anchor_left
	_update_pips(_main.court_hall_pips, int(vm.hall))
	_update_action("hall", "Hofhalle", str(vm.hall_button), "%s Kosten: %d Gold, %d Prestige · kein zusätzlicher Jahresunterhalt" % [vm.hall_effect, vm.hall_cost, vm.hall_prestige], game._hall_reason(game.player), pending)
	for index in vm.amenities.size():
		var amenity: Dictionary = vm.amenities[index]
		var key := "amenity:" + str(amenity.id)
		var additional: int = 0 if bool(amenity.maxed) else int(amenity.upkeep)
		_update_action(key, "%s · Stufe %s" % [amenity.name, amenity.level_text], str(amenity.button_text), "%s · Ausbau: %d Gold · zusätzlicher Unterhalt: %d Gold/Jahr · danach gesamt: %d Gold/Jahr" % [amenity.effect, amenity.cost, additional, int(vm.amenity_upkeep) + additional], game._amenity_reason(str(amenity.id), game.player), pending)
		_update_pips(_main.court_amenity_pips[index], int(amenity.level))

func _update_action(key: String, title: String, caption: String, detail: String, reason: String, pending: bool) -> void:
	var button: Button = action_buttons[key]
	var heading: Label = button.get_meta("court_heading")
	heading.text = title
	button.text = caption
	button.accessibility_name = title + ". " + detail
	button.tooltip_text = detail if reason.is_empty() else reason
	action_details[key].text = detail
	var blocked := reason
	if bool(_game.game_over):
		blocked = "Dieses Haus ist beendet. Hofaktionen sind nicht mehr verfügbar."
	elif pending or _dispatching:
		blocked = "Die laufende Hofaktion wird noch bestätigt."
	button.disabled = not blocked.is_empty()
	action_reasons[key].text = blocked
	action_reasons[key].visible = not blocked.is_empty()

func _activate(key: String, command: Dictionary) -> void:
	if _game == null or action_buttons[key].disabled:
		return
	_dispatching = true
	refresh(_game)
	var result: Dictionary = _main._dispatch(command.duplicate(true))
	_dispatching = false
	_message = str(result.get("message", ""))
	_pending_action = key if _network_pending() else ""
	refresh(_main.game)
