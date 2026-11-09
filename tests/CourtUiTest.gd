extends Node
## UI-Test für den Hof-/Reliquienbildschirm im echten Main-Fenster.
##
## Aufruf: godot --headless --path . res://tests/CourtUiTest.tscn

const MAIN_SCENE := "res://scenes/Main.tscn"
const COURT_TEXTURE = preload("res://assets/ui/court/court_hall.png")
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
	h["legitimacy"] = 50
	main._show_court()
	_check(main.court_layer != null and main.court_layer.visible, "Hofbildschirm ist nicht sichtbar.")
	for token in ["relic_crown", "relic_blade", "relic_seal"]:
		_check(main.TOKENS.has(token) and main.TOKENS[token] != null, "Token %s fehlt in Main.TOKENS." % token)
	var text := _collect_text(main.court_body)
	_check(text.contains("Reliquien"), "Reliquienbereich fehlt im Hofbildschirm.")
	_check(text.contains("Hofhalle"), "Hallenbereich fehlt im Hofbildschirm.")
	_check(text.contains("Hofpracht 20/100"), "Starthofpracht wird nicht angezeigt.")
	_check(main.court_hall_preview != null and main.court_hall_preview.texture == COURT_TEXTURE, "Hofhallen-Vorschau fehlt oder nutzt nicht die Blender-Kulisse.")
	_check(main.court_hall_stage_label != null and main.court_hall_stage_label.text.contains("Stufe 0/3"), "Hofhallen-Stufe fehlt in der Vorschau.")
	_check(main.court_hall_stats_label != null and main.court_hall_stats_label.text.contains("Reliquien 0/3"), "Reliquienstatus fehlt in der Vorschau.")
	_check(main.court_expectation_label != null and main.court_expectation_label.text.contains("Erwartet"), "Zielkorridor fehlt in der Hallenvorschau.")
	_check(main.court_expectation_label.text.contains("Aktuell 20"), "Aktuelle Hofpracht fehlt im Zielkorridor.")
	_check(main.court_expectation_track != null and main.court_expectation_track.is_visible_in_tree(), "Zielmarke ist nicht sichtbar.")
	_check(main.court_amenity_pips.size() == 3, "Es fehlen die drei Ausstattungslinien in der Vorschau.")
	for pips in main.court_amenity_pips:
		_check(pips.get_child_count() == 3, "Eine Ausstattungslinie zeigt nicht drei Stufen-Pips.")
	_check(text.contains("Hofausstattung"), "Ausstattungsbereich fehlt im Hofbildschirm.")
	_check(text.contains("Tafel") and text.contains("Gemächer") and text.contains("Gefolge"), "Tafel, Gemächer oder Gefolge fehlen im Hofbildschirm.")

	var crown: Button = null
	for button in _all_buttons(main.court_body):
		if button.text.begins_with("Schmieden") and _collect_text(button.get_parent()).contains("Krone der Ahnen"):
			crown = button
			break
	if not _check(crown != null, "Kein Schmieden-Button für die Krone gefunden."):
		return
	crown.emit_signal("pressed")
	_check(g.has_relic("crown"), "Kronenbutton vergab keine Reliquie.")
	_check(int(h["gold"]) == 900, "Kronenbutton zieht nicht 100 Gold ab.")
	_check(g.court_grandeur() == 35, "Kronenbutton erhöht die Hofpracht nicht.")
	var owned := false
	for button in _all_buttons(main.court_body):
		if button.text == "Im Besitz":
			owned = true
			break
	_check(owned, "Besitzstatus wird nicht neu gezeichnet.")

	var hall: Button = null
	for button in _all_buttons(main.court_body):
		if button.text.begins_with("Halle ausbauen"):
			hall = button
			break
	if not _check(hall != null, "Kein Hallenausbau-Button gefunden."):
		return
	hall.emit_signal("pressed")
	_check(g.court_hall_level() == 1, "Hallenbutton baut die Halle nicht aus.")
	_check(int(h["gold"]) == 820, "Hallenbutton zieht nicht 80 Gold ab.")
	_check(_collect_text(main.court_body).contains("Stufe 1/3"), "Hallenstufe wird nicht neu gezeichnet.")
	_check(main.court_hall_stats_label.text.contains("Hofpracht 50/100 · Reliquien 1/3"), "Hofwerte werden in der Vorschau nicht neu gezeichnet.")

	var table_button = main.court_amenity_buttons.get("table", null)
	if not _check(table_button is Button, "Kein Ausbau-Button für die Tafel gefunden."):
		return
	var opinion_before: int = int(h["vassals"][0]["opinion"])
	table_button.emit_signal("pressed")
	_check(g.court_amenity_level("table") == 1, "Tafelbutton baut die Tafel nicht aus.")
	_check(int(h["gold"]) == 770, "Tafelbutton zieht nicht 50 Gold ab.")
	_check(g.court_grandeur() == 55, "Tafelbutton erhöht die Hofpracht nicht.")
	_check(g.court_amenity_upkeep() == 8, "Tafelbutton erzeugt keinen Jahresunterhalt.")
	_check(int(h["vassals"][0]["opinion"]) == opinion_before + 2, "Tafelbutton verbessert die Vasallenmeinung nicht.")
	_check(main.court_hall_stats_label.text.contains("Hofpracht 55/100"), "Tafelstufe wird in der Vorschau nicht neu gezeichnet.")
	_check(main.court_expectation_label.text.contains("Erwartet") and main.court_expectation_label.text.contains("Aktuell 55"), "Zielkorridor wird nach dem Ausbau nicht neu gezeichnet.")
	main._hide_court()
	_check(not main.court_layer.visible, "Hofbildschirm bleibt nach Schließen sichtbar.")
	if _checks > 0 and not _failed:
		print("COURTUITEST OK: Hofbildschirm, Blender-Hofhallen-Vorschau, drei Reliquien-Token, Zielkorridor, drei Ausstattungslinien, echter Schmieden-/Hallen-/Ausstattungsbutton; %d Prüfungen." % _checks)
	get_tree().quit(1 if _failed else 0)

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
	print("COURTUITEST FAIL: " + message)
	get_tree().quit(1)
	return false
