extends Node
## UI-Test für den Dynastie-Abschnitt im Herrschaftsbildschirm.
##
## Öffnet die echte Main-Szene, prüft Ruhm-Anzeige, die drei Blender-Token und
## die drei Zweige und löst den ersten Kauf über den tatsächlichen Button aus.
##
## Aufruf: godot --headless --path . res://tests/DynastyUiTest.tscn

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
	g.house()["renown"] = 80
	main._show_rule()
	_check(main.rule_layer != null and main.rule_layer.visible, "Herrschaftsbildschirm ist nicht sichtbar.")
	_check(str(main.renown_label.text) == "Ruhm: 80", "Top-Leiste zeigt nicht 80 Ruhm.")
	for token in ["legacy_war", "legacy_crown", "legacy_guile"]:
		_check(main.TOKENS.has(token) and main.TOKENS[token] != null, "Token %s fehlt in Main.TOKENS." % token)
	var text := _collect_text(main.rule_body)
	for name in ["Kriegsvermächtnis", "Kronvermächtnis", "Ränkevermächtnis"]:
		_check(text.contains(name), "Zweig %s fehlt im Herrschaftsbildschirm." % name)
	var target: Button = null
	for button in _all_buttons(main.rule_body):
		if button.text.begins_with("Stufe 1") and button.text.contains("80 Ruhm"):
			target = button
			break
	if not _check(target != null, "Kein kaufbarer Stufe-1-Button gefunden."):
		return
	target.emit_signal("pressed")
	_check(int(g.house()["legacies"]["war"]) == 1, "Buttonkauf erhöht Kriegsvermächtnis nicht.")
	_check(int(g.house()["renown"]) == 0, "Buttonkauf zieht keine 80 Ruhm ab.")
	_check(str(main.renown_label.text) == "Ruhm: 0", "Top-Leiste wurde nach dem Kauf nicht aktualisiert.")
	_check(_collect_text(main.rule_body).contains("Stufe 1/3"), "Stufe 1/3 wird nach dem Kauf nicht angezeigt.")
	if _checks > 0:
		print("DYNASTYUITEST OK: Herrschaftsbildschirm, Ruhm, drei Token/Zweige und echter Buttonkauf; %d Prüfungen." % _checks)
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
	print("DYNASTYUITEST FAIL: " + message)
	get_tree().quit(1)
	return false
