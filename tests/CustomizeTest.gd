extends Node
## Prüft die Herrscher-Werkstatt: Klick auf das Porträt öffnet sie, Änderungen
## an Porträt, Wappen, Hausfarbe, Namen und Werten landen im Haus und im
## Spielstand; Abbrechen stellt den vorherigen Zustand wieder her.
## Aufruf: godot --headless --path . res://tests/CustomizeTest.tscn

var main
var frames := 0
var done := false

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("CUSTOMIZETEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 8 or done:
		return
	done = true
	_run()

func _run() -> void:
	main._start(2)
	var g = main.game
	if g == null:
		_fail("Spiel wurde nicht erzeugt")
		return
	var h: Dictionary = g.house()
	var original_name: String = str(h["name"])
	var original_house: String = str(h["name"])
	var original_portrait: int = int(h["ruler"].get("portrait", 0))
	var original_crest: int = int(h.get("crest", 0))
	var original_stat: int = int(h["ruler"]["martial"])
	var original_color: Color = h["color"]

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.portrait_rect.gui_input.emit(click)
	if main.custom_layer == null or not main.custom_layer.visible:
		_fail("Klick auf das Porträt öffnet die Werkstatt nicht")
		return

	main._custom_house_changed("Haus Aria")
	main._custom_name_changed("Ari")
	main._custom_gender_changed(1)
	main._custom_age_changed(42)
	main._custom_set_portrait(7)
	main._custom_set_crest(4)
	var new_color := Color(0.24, 0.58, 0.38)
	main._custom_set_color(new_color)
	main._custom_adjust("martial", 1)
	if str(g.house()["name"]) != "Haus Aria":
		_fail("Hausname wurde nicht übernommen")
		return
	if str(g.house()["ruler"]["name"]) != "Ari" or str(g.house()["ruler"]["gender"]) != "f":
		_fail("Name oder Geschlecht wurde nicht übernommen")
		return
	if int(g.house()["ruler"]["age"]) != 42:
		_fail("Alter wurde nicht übernommen")
		return
	if int(g.house()["ruler"]["portrait"]) != 7 or int(g.house().get("crest", -1)) != 4:
		_fail("Porträt oder Wappen wurde nicht übernommen")
		return
	if g.house()["color"] != new_color:
		_fail("Hausfarbe wurde nicht übernommen")
		return
	if int(g.house()["ruler"]["martial"]) != original_stat + 1:
		_fail("Charakterwert wurde nicht verändert")
		return

	main._custom_apply()
	if main.custom_layer.visible:
		_fail("Werkstatt schließt nach Übernehmen nicht")
		return
	if main.portrait_rect.texture != main.PORTRAITS[7] or main.crest_rect.texture != main.CRESTS[4]:
		_fail("Hofpanel zeigt nicht das gewählte Porträt/Wappen")
		return
	var snapshot: Dictionary = g.snapshot()
	g.restore(snapshot)
	if str(g.house()["name"]) != "Haus Aria" or int(g.house().get("crest", -1)) != 4:
		_fail("Wappen/Haus überstehen Speichern und Laden nicht")
		return
	if str(g.house()["ruler"]["name"]) != "Ari" or int(g.house()["ruler"]["portrait"]) != 7:
		_fail("Herrscher übersteht Speichern und Laden nicht")
		return

	var before_cancel: String = str(g.house()["name"])
	main._open_customizer()
	main._custom_house_changed("Haus Temporär")
	main._custom_cancel()
	if str(g.house()["name"]) != before_cancel:
		_fail("Abbrechen stellt den alten Hausnamen nicht wieder her")
		return
	if int(g.house()["ruler"]["portrait"]) != 7 or int(g.house().get("crest", -1)) != 4:
		_fail("Abbrechen beschädigt Porträt oder Wappen")
		return
	print("CUSTOMIZETEST OK: Porträt-Klick, Wappen, Hausfarbe, Name, Geschlecht, Alter und Werte angepasst; Speichern/Laden und Abbrechen geprüft (alt: %s/%d/%d)." % [original_house, original_portrait, original_crest])
	get_tree().quit(0)
