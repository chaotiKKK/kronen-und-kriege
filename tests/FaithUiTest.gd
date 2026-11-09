extends Node
## UI-Test für den Glauben-/Kirchenbildschirm im echten Main-Fenster.
##
## Aufruf: godot --headless --path . res://tests/FaithUiTest.tscn

const MAIN_SCENE := "res://scenes/Main.tscn"
const GameScript = preload("res://scripts/Game.gd")
var main
var frames := 0
var started := false
var _checks := 0
var _failed := false

func _ready() -> void:
	main = load(MAIN_SCENE).instantiate()
	add_child(main)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 5 or started:
		return
	started = true
	_run()

func _run() -> void:
	main._start(0)
	var g = main.game
	if not _check(g != null, "Kein Spiel gestartet."):
		return
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["faith"]["piety"] = 50
	g._refresh_faith_power(0)
	main._show_faith()
	_check(main.faith_layer != null and main.faith_layer.visible, "Glaubensbildschirm ist nicht sichtbar.")
	var token_names: Array = ["faith_sun", "faith_moon", "faith_earth"]
	for key in GameScript.FAITH_TOKEN_ORDER:
		token_names.append("faith_%s" % str(key))
	for token in token_names:
		_check(main.TOKENS.has(token) and main.TOKENS[token] != null, "Token %s fehlt in Main.TOKENS." % token)
	var text := _collect_text(main.faith_body)
	_check(str(main.faith_title.text).contains("Glaube & Kirche"), "Glaubenstitel fehlt.")
	_check(text.contains("Sonnenbund"), "Sonnenbund fehlt.")
	_check(text.contains("Frömmigkeit 50/100"), "Frömmigkeit wird nicht angezeigt.")
	_check(text.contains("Kirchenmacht 23/100"), "Kirchenmacht wird nicht angezeigt.")
	_check(main.faith_heresy_icon != null and main.faith_heresy_icon.texture == main.TOKENS["faith_heresy_low"], "Ketzerei-Stufe 0 nutzt nicht das Low-Icon.")
	_check(main.faith_reform_icon != null and main.faith_reform_icon.texture == main.TOKENS["faith_reform_0"], "Reformstufe 0 nutzt nicht das Stufen-0-Icon.")
	for target in main.ViewModelBuilder.faith(g)["holy_war_targets"]:
		var target_row := _war_row_for_name(main.faith_body, str(target["name"]))
		_check(target_row != null, "Kriegszielzeile für %s fehlt." % str(target["name"]))
		_check(_has_texture(target_row, main.TOKENS[str(target["icon"])]), "Kriegsziel %s nutzt nicht sein Wappen." % str(target["name"]))

	var pilgrimage: Button = null
	for button in _all_buttons(main.faith_body):
		if button.text.begins_with("Wallfahrt"):
			pilgrimage = button
			break
	if not _check(pilgrimage != null, "Kein Wallfahrtsbutton gefunden."):
		return
	pilgrimage.emit_signal("pressed")
	_check(g.faith_piety() == 62, "Wallfahrtsbutton erhöht die Frömmigkeit nicht.")
	_check(int(h["gold"]) == 970, "Wallfahrtsbutton zieht nicht 30 Gold ab.")

	var convert: Button = null
	for button in _all_buttons(main.faith_body):
		if button.text.begins_with("Wechseln") and _collect_text(button.get_parent()).contains("Mondorakel"):
			convert = button
			break
	if not _check(convert != null, "Kein Bekehrungsbutton für das Mondorakel gefunden."):
		return
	convert.emit_signal("pressed")
	_check(g.faith_confession() == "moon", "Bekehrungsbutton setzt die Konfession nicht.")
	_check(int(h["gold"]) == 890, "Bekehrungsbutton zieht nicht 80 Gold ab.")
	_check(int(h["prestige"]) == 85, "Bekehrungsbutton zieht nicht 15 Prestige ab.")

	var capital: Dictionary = g.province(str(h["capital"]))
	var site_button: Button = null
	for button in _all_buttons(main.faith_body):
		if button.text.begins_with("Weihen") and _collect_text(button.get_parent()).contains(str(capital["name"])):
			site_button = button
			break
	if not _check(site_button != null, "Kein Weihebutton für die Hauptstadt gefunden."):
		return
	site_button.emit_signal("pressed")
	_check(g.faith_site_count() == 1, "Weihebutton speichert keine Stätte.")
	_check(int(h["gold"]) == 830, "Weihebutton zieht nicht 60 Gold ab.")
	_check(g.faith_piety() == 47, "Weihebutton zieht nicht 15 Frömmigkeit ab.")
	_check(int(h["prestige"]) == 91, "Weihebutton gibt nicht +6 Prestige.")
	_check(_collect_text(main.faith_body).contains("◆ %s" % str(capital["name"])), "Geweihte Stätte wird nicht neu gezeichnet.")

	h["faith"]["heresy"] = 60
	main._refresh_faith()
	_check(main.faith_heresy_icon.texture == main.TOKENS["faith_heresy_high"], "Ketzerei 60 nutzt nicht das High-Icon.")
	var suppress := _find_button(main.faith_body, "Ketzergericht")
	if not _check(suppress != null, "Kein Ketzergerichtsbutton gefunden."):
		return
	suppress.emit_signal("pressed")
	_check(g.faith_heresy() == 35, "Ketzergerichtsbutton senkt die Ketzerei nicht.")
	_check(int(h["gold"]) == 780, "Ketzergericht zieht nicht 50 Gold ab.")
	_check(int(h["prestige"]) == 81, "Ketzergericht zieht nicht 10 Prestige ab.")
	_check(main.faith_heresy_icon.texture == main.TOKENS["faith_heresy_mid"], "Ketzerei 35 nutzt nicht das Mid-Icon.")

	var reform := _find_button(main.faith_body, "Reform beschließen")
	if not _check(reform != null, "Kein Reformbutton gefunden."):
		return
	reform.emit_signal("pressed")
	_check(g.faith_reform() == 1, "Reformbutton erhöht die Stufe nicht.")
	_check(int(h["gold"]) == 680, "Reform zieht nicht 100 Gold ab.")
	_check(g.faith_piety() == 22, "Reform zieht nicht 25 Frömmigkeit ab.")
	_check(int(h["prestige"]) == 71, "Reform zieht nicht 10 Prestige ab.")
	_check(g.faith_heresy() == 25, "Reform senkt die Ketzerei nicht um 10.")
	var reform_text := _collect_text(main.faith_body)
	_check(reform_text.contains("Reform 1/3"), "Reformstufe wird nicht neu gezeichnet.")
	_check(reform_text.contains("Ketzerei 25/100"), "Ketzerei wird nach Reform nicht neu gezeichnet.")
	_check(main.faith_reform_icon.texture == main.TOKENS["faith_reform_1"], "Reformstufe 1 nutzt nicht das Stufen-1-Icon.")
	_check(main.faith_heresy_icon.texture == main.TOKENS["faith_heresy_low"], "Ketzerei 25 nutzt nicht wieder das Low-Icon.")

	var target_name := str(g.houses[2]["name"])
	var holy_war := _find_button(main.faith_body, "Krieg erklären", target_name)
	if not _check(holy_war != null, "Kein Heiliger-Krieg-Button für das Erdenhaus gefunden."):
		return
	holy_war.emit_signal("pressed")
	_check(g.faith_holy_war_target() == 2, "Heiliger-Krieg-Button speichert das Ziel nicht.")
	_check(int(h["gold"]) == 620, "Heiliger Krieg zieht nicht 60 Gold ab.")
	_check(g.faith_piety() == 2, "Heiliger Krieg zieht nicht 20 Frömmigkeit ab.")
	_check(int(h["prestige"]) == 61, "Heiliger Krieg zieht nicht 10 Prestige ab.")
	var war_text := _collect_text(main.faith_body)
	var target_capital := str(g.province(str(g.houses[2]["capital"]))["name"])
	_check(main.faith_war_marker != null and main.faith_war_marker.visible, "Kriegsziel-Marker fehlt nach der Erklärung.")
	_check(main.faith_war_marker_label != null and main.faith_war_marker_label.text.contains("Kriegsziel: %s" % target_name), "Kriegsziel-Marker nennt nicht das Ziel.")
	_check(main.faith_war_marker_label.text.contains("Hauptstadt %s" % target_capital), "Kriegsziel-Marker nennt nicht die Hauptstadt.")
	_check(main.faith_war_marker_label.text.contains("noch 24 Monate"), "Kriegsdauer wird nicht angezeigt.")
	_check(main.faith_war_marker_label.text.contains("Anspruch 240 Monate"), "Anspruchsdauer wird nicht angezeigt.")
	_check(main.faith_war_marker_icon != null and main.faith_war_marker_icon.texture == main.TOKENS["faith_holy_war_2"], "Kriegsziel-Marker nutzt nicht das Zielwappen.")
	_check(war_text.contains("Hauptstadt %s" % target_capital), "Kriegszielzeile nennt nicht die Hauptstadt.")

	# Zielwechsel und Restlaufzeit müssen sofort im Marker erscheinen.
	var changed_target := 3
	var changed_capital := str(g.houses[changed_target]["capital"])
	_check(g._add_claim(0, changed_capital, 3), "Testanspruch für Zielwechsel fehlt.")
	h["faith"]["holy_war"] = {"target": changed_target, "months": 9}
	main._refresh_faith()
	_check(g.faith_holy_war_target() == changed_target, "Zielwechsel wird nicht übernommen.")
	_check(main.faith_war_marker_label.text.contains(str(g.houses[changed_target]["name"])), "Marker folgt dem Zielwechsel nicht.")
	_check(main.faith_war_marker_label.text.contains("Hauptstadt %s" % str(g.province(changed_capital)["name"])), "Marker folgt der neuen Hauptstadt nicht.")
	_check(main.faith_war_marker_label.text.contains("noch 9 Monate"), "Marker folgt der Restlaufzeit nicht.")
	_check(main.faith_war_marker_icon.texture == main.TOKENS["faith_holy_war_%d" % changed_target], "Marker folgt dem neuen Wappen nicht.")
	h["faith"]["holy_war"]["months"] = 7
	main._refresh_faith()
	_check(main.faith_war_marker_label.text.contains("noch 7 Monate"), "Marker folgt der geänderten Restlaufzeit nicht.")

	# Erlischt der Anspruch, verschwindet der Marker aus dem echten Zustand.
	for claim in h["claims"]:
		if str(claim.get("province", "")) == changed_capital:
			claim["expires"] = g._now() - 1
	main._refresh_faith()
	_check(g.faith_holy_war_target() == -1, "Erloschener Anspruch beendet das Kriegsziel nicht.")
	_check(main.faith_war_marker == null, "Kriegsziel-Marker bleibt nach Anspruchsablauf sichtbar.")
	main._hide_faith()
	_check(not main.faith_layer.visible, "Glaubensbildschirm bleibt nach Schließen sichtbar.")
	if _checks > 0 and not _failed:
		print("FAITHUITEST OK: Glaubensbildschirm, drei Konfessionstoken, echte Wallfahrts-, Bekehrungs-, Weihe-, Ketzergerichts-, Reform- und Heiliger-Krieg-Buttons; %d Prüfungen." % _checks)
	get_tree().quit(1 if _failed else 0)

func _find_button(node: Node, prefix: String, context: String = "") -> Button:
	for button in _all_buttons(node):
		if button.text.begins_with(prefix) and (context == "" or _collect_text(button.get_parent()).contains(context)):
			return button
	return null

func _war_row_for_name(node: Node, target_name: String) -> HBoxContainer:
	for child in _all_nodes(node):
		if child is HBoxContainer and _collect_text(child).contains(target_name) and _has_button(child, "Krieg erklären"):
			return child
	return null

func _has_button(node: Node, prefix: String) -> bool:
	for button in _all_buttons(node):
		if button.text.begins_with(prefix):
			return true
	return false

func _has_texture(node: Node, expected: Texture2D) -> bool:
	for child in _all_nodes(node):
		if child is TextureRect and child.texture == expected:
			return true
	return false

func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out

func _all_buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_all_buttons(child))
	return out

func _collect_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += str(node.text) + "\n"
	for child in node.get_children():
		out += _collect_text(child)
	return out

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failed = true
	print("FAITHUITEST FAIL: " + message)
	get_tree().quit(1)
	return false
