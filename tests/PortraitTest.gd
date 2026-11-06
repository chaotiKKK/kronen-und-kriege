extends Node
## Prüft die erweiterte Porträtgalerie: 48 HD-Porträts, Auswahl im
## Herrscher-Werkstatt-Raster, Übernahme ins Hofpanel und Speicherstand.
## Aufruf: godot --headless --path . res://tests/PortraitTest.tscn

var main
var frames := 0
var done := false

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("PORTRAITTEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 8 or done:
		return
	done = true
	_run()

func _run() -> void:
	if main.PORTRAITS.size() != 48:
		_fail("Galerie hat %d statt 48 Porträts" % main.PORTRAITS.size())
		return
	for i in 48:
		if main.PORTRAITS[i] == null:
			_fail("Porträt %d fehlt" % (i + 1))
			return

	main._start(2)
	var g = main.game
	if g == null:
		_fail("Spiel wurde nicht erzeugt")
		return

	main._open_customizer()
	if not main.custom_layer.visible:
		_fail("Werkstatt öffnet nicht")
		return
	if main.custom_portrait_buttons.size() != 48:
		_fail("Werkstatt zeigt %d statt 48 Porträtknöpfe" % main.custom_portrait_buttons.size())
		return

	main._custom_set_portrait(13)
	if int(g.house()["ruler"]["portrait"]) != 13:
		_fail("Porträt 14 wurde nicht übernommen")
		return
	if main.custom_portrait_preview.texture != main.PORTRAITS[13]:
		_fail("Vorschau zeigt nicht das neue Porträt")
		return

	main._custom_apply()
	if main.portrait_rect.texture != main.PORTRAITS[13]:
		_fail("Hofpanel zeigt nicht das neue Porträt")
		return

	for i in 40:
		var fp: int = g._random_portrait("f")
		if fp < 8 or fp > 47:
			_fail("Weibliches Zufallsporträt außerhalb 8..47: %d" % fp)
			return
		var mp: int = g._random_portrait("m")
		if mp < 0 or mp > 7:
			_fail("Männliches Zufallsporträt außerhalb 0..7: %d" % mp)
			return

	var snapshot: Dictionary = g.snapshot()
	g.restore(snapshot)
	if int(g.house()["ruler"]["portrait"]) != 13:
		_fail("Porträt übersteht Speichern und Laden nicht")
		return

	print("PORTRAITTEST OK: 48 HD-Porträts, Auswahl 14, Zufallsbereiche 0..7/8..47, Speichern/Laden.")
	get_tree().quit(0)
