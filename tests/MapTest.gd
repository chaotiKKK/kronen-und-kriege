extends Node
## Prüft die Europakarte in der Oberfläche: 49 Grafschaften, 9 Königreiche,
## 3 Reiche, Hierarchie in der Auswahl und eigener Grafschaftsstart.

var main
var frames: int = 0
var started: bool = false
var _checks: int = 0

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
	if not _check(g.provinces.size() == 49, "Karte hat nicht 49 Grafschaften."):
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
	if not _check(kingdoms.size() == 9 and duchies.size() >= 20 and empires.size() == 3, "Die Kartenhierarchie ist unvollständig."):
		return

	var owned: Array = g.owned()
	if owned.size() < 5:
		_fail("Haus 2 besitzt nur %d Grafschaften" % owned.size())
		return
	if not _check(owned.size() >= 5, "Haus 2 besitzt weniger als fünf Grafschaften."):
		return
	var p0: Dictionary = owned[0]
	main._on_province_selected(str(p0["id"]))
	# Die aufgeräumte Hofübersicht bleibt beim Herrscher; Details stehen in der Provinzseite.
	main._show_province()
	var detail_text := ""
	for label in main.province_info.get_children():
		if label is Label:
			detail_text += label.text + "\n"
	if not detail_text.contains(str(p0["kingdom_name"])):
		_fail("Auswahl zeigt das Königreich nicht")
		return
	if not detail_text.contains(str(p0["duchy_name"])):
		_fail("Auswahl zeigt das Herzogtum nicht")
		return
	if not detail_text.contains(str(p0["empire_name"])):
		_fail("Auswahl zeigt das Reich nicht")
		return
	if not detail_text.contains(str(p0.get("terrain_name", ""))):
		_fail("Auswahl zeigt das Gelände nicht")
		return
	if not detail_text.contains("Versorgung"):
		_fail("Auswahl zeigt die Versorgung nicht")
		return
	main._hide_province()
	if not _check(main.map_header_meta.text.contains(str(p0["name"])), "Kartenkopf zeigt die Auswahl nicht."):
		return
	if not _check(main.top_crest.texture != null, "Weltkartenkopf ohne Wappen."):
		return
	if not _check(main.minimap != null and main.minimap.host == main.map_view, "Minimap ist nicht an die Weltkarte gebunden."):
		return
	var map_fit: Array = main.map_view._fit()
	var hover_pos: Vector2 = main.map_view._label_point(p0) * float(map_fit[0]) + map_fit[1]
	main.map_view.hover_at(hover_pos)
	if not _check(main.map_view.hovered == str(p0["id"]), "Hover erkennt die Provinz nicht."):
		return
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	main.map_view._gui_input(right_click)
	if not _check(main.selected == "" and not main.province_side_panel.visible, "Rechtsklick hebt die Auswahl nicht auf."):
		return
	main._on_province_selected(str(p0["id"]))
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = hover_pos
	main.map_view._gui_input(double_click)
	if not _check(main.province_layer.visible, "Doppelklick öffnet die Provinzseite nicht."):
		return
	main._hide_province()
	main._toggle_map_legend()
	if not _check(main.map_view.legend_visible and main.legend_button.button_pressed, "Legende lässt sich nicht einblenden."):
		return
	main._toggle_map_legend()
	main._toggle_side_panel()
	if not _check(not main.side_panel.visible, "Hofpanel lässt sich nicht ausblenden."):
		return
	main._toggle_side_panel()
	if not _check(main.side_panel.visible, "Hofpanel lässt sich nicht wieder einblenden."):
		return
	for mode in ["political", "terrain", "duchy", "kingdom", "development", "war"]:
		main._set_map_mode(mode)
		if str(main.map_view.map_mode) != mode:
			_fail("Kartenmodus %s wurde nicht gesetzt" % mode)
			return
		if not bool(main.map_mode_buttons[mode].button_pressed):
			_fail("Kartenmodus %s ist nicht hervorgehoben" % mode)
			return
		if main.selected != str(p0["id"]):
			_fail("Auswahl ging beim Moduswechsel %s verloren" % mode)
			return
		if not main.map_header_title.text.contains(main._map_mode_title(mode).to_upper()):
			_fail("Kartenkopf zeigt den Modus %s nicht" % mode)
			return
	main._set_map_mode("political")
	if not _check(str(main.map_view.map_mode) == "political" and main.selected == str(p0["id"]), "Kartenmodus oder Auswahl ging verloren."):
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
	if not _check(g2 != null and g2.player == 9 and int(cap["owner"]) == 9 and str(cap["name"]) == "Arialand" and str(g2.house().get("capital", "")) == home_id and str(g2.house().get("realm", "")).contains("Arialand"), "Der eigene Grafschaftsstart ist unvollständig."):
		return

	print("MAPTEST OK: 49 Grafschaften, %d Herzogtümer, 9 Königreiche, 3 Reiche, sechs Kartenmodi; Auswahl und eigener Grafschaftsstart funktionieren; %d Prüfungen." % [duchies.size(), _checks])
	get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false
