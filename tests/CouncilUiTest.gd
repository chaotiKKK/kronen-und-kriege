extends Node
## UI-Test für Vasallenverträge und Rat im echten Herrschaftsbildschirm.
##
## Öffnet die Main-Szene, prüft Vertrags-/Rats-Token und ändert zuerst den
## Vertrag, dann einen Ratsbeschluss über die tatsächlich sichtbaren Buttons.
##
## Aufruf: godot --headless --path . res://tests/CouncilUiTest.tscn

const MAIN_SCENE := "res://scenes/Main.tscn"

var main
var frames := 0
var started := false
var _checks := 0

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
	h["gold"] = 500
	h["legitimacy"] = 80
	h["prestige"] = 50
	for c in h["courtiers"]:
		c["loyalty"] = 100
		c["martial"] = 18
		c["diplomacy"] = 18
		c["stewardship"] = 18
		c["intrigue"] = 18
	for vi in 3:
		h["vassals"][vi]["opinion"] = 50
	g.assign_council("marshal", 0)
	g.assign_council("chancellor", 1)
	g.assign_council("steward", 2)
	g.assign_council("spymaster", 3)
	main._show_rule()
	_check(main.rule_layer != null and main.rule_layer.visible, "Herrschaftsbildschirm ist nicht sichtbar.")
	for token in ["council_marshal", "council_chancellor", "council_steward", "council_spymaster", "contract_0", "contract_1", "contract_2"]:
		_check(main.TOKENS.has(token) and main.TOKENS[token] != null, "Token %s fehlt in Main.TOKENS." % token)
	var text := _collect_text(main.rule_body)
	_check(text.contains("Vasallenverträge"), "Vertragsbereich fehlt im Herrschaftsbildschirm.")
	_check(text.contains("Rat"), "Ratsbereich fehlt im Herrschaftsbildschirm.")
	_check(text.contains("Meinung 50"), "Startmeinung wird nicht angezeigt.")

	var raise: Button = null
	for button in _all_buttons(main.rule_body):
		if button.text.begins_with("Erhöhen") and button.text.contains("80 G"):
			raise = button
			break
	if not _check(raise != null, "Kein Erhöhen-Button für Stufe 1 gefunden."):
		return
	raise.emit_signal("pressed")
	_check(g.vassal_contract_level(0) == 2, "Vertragsbutton erhöht die Stufe nicht.")
	_check(int(h["gold"]) == 420, "Vertragsbutton zieht nicht 80 Gold ab.")
	_check(int(h["vassals"][0]["opinion"]) == 40, "Vertragsbutton senkt die Meinung nicht.")
	_check(_collect_text(main.rule_body).contains("Stufe 2/2"), "Stufe 2/2 wird nach dem Vertragswechsel nicht angezeigt.")

	var enact: Button = null
	for button in _all_buttons(main.rule_body):
		if button.text != "Beschließen" or button.disabled:
			continue
		if _collect_text(button.get_parent()).contains("Landfrieden"):
			enact = button
			break
	if not _check(enact != null, "Kein aktiver Landfrieden-Button gefunden."):
		return
	var gold_before: int = int(h["gold"])
	enact.emit_signal("pressed")
	_check(int(h["gold"]) == gold_before - 60, "Ratsbeschluss zieht nicht 60 Gold ab.")
	_check(int(h["vassals"][0]["opinion"]) == 46, "Ratsbeschluss erhöht die Vasallenmeinung nicht.")
	_check(int(h["legitimacy"]) == 82, "Ratsbeschluss erhöht die Legitimität nicht.")
	_check(_collect_text(main.rule_body).contains("Landfrieden"), "Ratsbeschluss bleibt nicht sichtbar.")
	if _checks > 0:
		print("COUNCILUITEST OK: Herrschaftsbildschirm, sieben Token, echter Vertrags- und Ratsbutton; %d Prüfungen." % _checks)
	get_tree().quit(0)

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
	print("COUNCILUITEST FAIL: " + message)
	get_tree().quit(1)
	return false
