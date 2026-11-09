extends Node
## Prüft reale Forschung, Bau, Eigentumsunterbrechung, Wirkung und Save.
const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveScript = preload("res://scripts/SaveGame.gd")
const KernelScript = preload("res://scripts/UiKernel.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	seed(20261109)
	var g = GameScript.new(DataScript, 0)
	if not g.has_method("start_research"):
		_check(false, "Forschung muss im echten Game vorhanden sein.")
		_finish()
		return
	g.house()["gold"] = 500
	var a: String = str(g.provinces[0].id)
	var b: String = str(g.neighbours(a)[0])
	g.province(a).owner = 0
	g.province(b).owner = 0
	var before: Dictionary = g.snapshot()
	_check(not g.build_road(a, b).ok, "Straße ohne Wissen muss gesperrt sein.")
	_check(SaveScript.diff(before, g.snapshot()).is_empty(), "Abgelehnter Bau verändert den Spielstand.")
	_check(not g.start_research("road_building").ok, "Straßenbau braucht Vermessung.")
	_check(not g.start_research("unknown").ok, "Unbekannte Innovation ist gesperrt.")
	var kernel = KernelScript.new()
	kernel.bind_game(g)
	_check(kernel.dispatch({"id": "research", "innovation": "surveying"}).ok, "Forschung nicht über UI-Kernel startbar.")
	_check(int(g.house().gold) == 480, "Vermessung muss 20 Gold kosten.")
	_check(not g.start_research("surveying").ok, "Aktive Forschung darf nicht doppelt bezahlt werden.")
	for i in 5:
		g.advance_month()
	_check(not g.house().research.known.has("surveying"), "Forschung schließt vor ihrer Dauer ab.")
	g.advance_month()
	_check(g.house().research.known.has("surveying"), "Vermessung fehlt nach sechs Monaten.")
	_check(g.start_research("road_building").ok, "Straßenbau nach Vermessung gesperrt.")
	for i in 12:
		g.advance_month()
	_check(g.house().research.known.has("road_building"), "Straßenbau fehlt nach zwölf Monaten.")
	g.house().gold = 0
	before = g.snapshot()
	_check(not g.build_road(a, b).ok, "Bau ohne Gold muss scheitern.")
	_check(SaveScript.diff(before, g.snapshot()).is_empty(), "Fehlendes Gold verändert Zustand.")
	g.house().gold = 500
	_check(not g.build_road(a, a).ok, "Selbstverbindung darf nicht gebaut werden.")
	_check(not g.build_road(a, "missing").ok, "Unbekannte Provinz darf nicht gebaut werden.")
	kernel.select_province(a)
	_check(kernel.dispatch({"id": "road", "to": b}).ok, "Bau nicht über UI-Kernel startbar.")
	_check(int(g.house().gold) == 470, "Straße muss 30 Gold kosten.")
	_check(not g.build_road(b, a).ok, "Umgekehrte Kante erzeugt doppelten Bau.")
	_check(g.road_segments().size() == 1 and g.road_segments()[0].state == "building", "Baustelle muss sichtbar abfragbar sein.")
	g.advance_month()
	_check(int(g.roads[0].months) == 2, "Baustelle tickt nicht.")
	g.province(b).owner = 1
	g.advance_month()
	_check(int(g.roads[0].months) == 2, "Besitzverlust muss Bau pausieren.")
	g.province(b).owner = 0
	g.advance_month()
	g.advance_month()
	_check(g.roads[0].state == "complete" and int(g.roads[0].months) == 0, "Straße wird nicht fertig.")
	_check(g.road_income(0) == 2, "Fertige Verbindung muss wirtschaftlich wirken.")
	g.province(b).owner = 1
	_check(g.road_income(0) == 0, "Geteilte Besitzgrenze darf keinen Bonus geben.")
	g.province(b).owner = 0
	var gold: int = int(g.house().gold)
	g._apply_road_income(0)
	_check(int(g.house().gold) == gold + 2, "Straßenbonus wird nicht tatsächlich gebucht.")
	g.disabled_edges["I1"] = true
	g._apply_road_income(0)
	_check(int(g.house().gold) == gold + 2, "Deaktivierte Infrastrukturkante wirkt trotzdem.")
	var saved: Dictionary = g.snapshot()
	var restored = GameScript.new(DataScript, 0)
	_check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Infrastrukturstand nicht ladbar.")
	_check(SaveScript.diff(saved, restored.snapshot()).is_empty(), "Save-Roundtrip verliert Forschung oder Straße.")
	_check(restored.road_income(0) == 2 and restored.road_segments().size() == 1, "Nach Laden fehlen Wirkung oder Kartensegment.")
	var broken: Dictionary = saved.duplicate(true)
	broken.roads.append(broken.roads[0].duplicate(true))
	_check(not SaveScript.validate(broken).is_empty(), "Doppelte Save-Verbindung wird nicht abgewiesen.")
	broken = saved.duplicate(true)
	broken.houses[0].erase("research")
	_check(not SaveScript.validate(broken).is_empty(), "Aktueller Save darf Forschungsdaten nicht still verlieren.")
	broken = saved.duplicate(true)
	for p in g.provinces:
		if str(p.id) != a and not g.neighbours(a).has(str(p.id)):
			broken.roads[0]["from"] = a
			broken.roads[0]["to"] = str(p.id)
			break
	_check(not SaveScript.validate(broken).is_empty(), "Nicht benachbarte Save-Verbindung wird nicht abgewiesen.")
	_finish()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("INFRASTRUCTURETEST FAIL: " + message)

func _finish() -> void:
	print("INFRASTRUCTURETEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
