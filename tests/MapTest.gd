extends Node
## Prüft die Europakarte in der Oberfläche: 49 Grafschaften, 9 Königreiche,
## 3 Reiche, Hierarchie in der Auswahl und eigener Grafschaftsstart.

var main
var frames: int = 0
var started: bool = false

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

func _fail(msg: String) -> void:
	print("MAPTEST FAIL: " + msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	frames += 1
	if frames < 5 or started:
		return
	started = true
	_run()

func _run() -> void:
	main._start(2)
	var g = main.game
	if g == null:
		_fail("Spiel wurde nicht erzeugt")
		return
	if g.provinces.size() != 49:
		_fail("Karte hat %d statt 49 Grafschaften" % g.provinces.size())
		return
	var kingdoms := {}
	var duchies := {}
	var empires := {}
	for p in g.provinces:
		for key in ["kingdom", "kingdom_name", "duchy", "duchy_name", "empire", "empire_name"]:
			if not p.has(key) or str(p[key]) == "":
				_fail("Grafschaft %s ohne %s" % [p["id"], key])
				return
		kingdoms[p["kingdom"]] = true
		duchies[p["duchy"]] = true
		empires[p["empire"]] = true
		if (g.neighbours(str(p["id"])) as Array).is_empty():
			_fail("Grafschaft %s hat keine Nachbarn" % p["id"])
			return
	if kingdoms.size() != 9 or duchies.size() < 20 or empires.size() != 3:
		_fail("Hierarchie unvollständig: %d Königreiche, %d Herzogtümer, %d Reiche" % [kingdoms.size(), duchies.size(), empires.size()])
		return

	var owned: Array = g.owned()
	if owned.size() < 5:
		_fail("Haus 2 besitzt nur %d Grafschaften" % owned.size())
		return
	var p0: Dictionary = owned[0]
	main._on_province_selected(str(p0["id"]))
	if not main.info_label.text.contains(str(p0["kingdom_name"])):
		_fail("Auswahl zeigt das Königreich nicht")
		return
	if not main.info_label.text.contains(str(p0["duchy_name"])):
		_fail("Auswahl zeigt das Herzogtum nicht")
		return
	if not main.info_label.text.contains(str(p0["empire_name"])):
		_fail("Auswahl zeigt das Reich nicht")
		return

	main._show_create()
	var home_id := str(main.create_home.get_item_metadata(0))
	main.edit_ruler.text = "Ari"
	main.edit_house.text = "Haus Aria"
	main.edit_land.text = "Arialand"
	main.create_home.selected = 0
	main.stat_values = {"martial": 20, "diplomacy": 20, "stewardship": 20, "intrigue": 20}
	main._create_begin()
	var g2 = main.game
	if g2 == null or g2.player != 9:
		_fail("Eigener Grafschaftsstart erzeugte kein neues Haus")
		return
	var cap: Dictionary = g2.province(home_id)
	if int(cap["owner"]) != 9 or str(cap["name"]) != "Arialand":
		_fail("Eigene Grafschaft wurde nicht übernommen")
		return
	if str(g2.house().get("capital", "")) != home_id or not str(g2.house().get("realm", "")).contains("Arialand"):
		_fail("Eigenes Haus ohne Grafschaftssitz")
		return

	print("MAPTEST OK: 49 Grafschaften, %d Herzogtümer, 9 Königreiche, 3 Reiche; Auswahl und eigener Grafschaftsstart funktionieren" % duchies.size())
	get_tree().quit(0)
