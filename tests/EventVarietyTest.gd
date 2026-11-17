extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var pool: Array = Data.events()
	if not check(pool.size() >= 32, "Mindestens 32 kontextuelle Ereignisse fehlen"):
		finish()
		return
	var ids := {}
	for event in pool:
		check(not ids.has(event.id), "Stabile Ereigniskennung ist eindeutig")
		ids[event.id] = true
		check(not str(event.get("art", "")).is_empty(), "Alle Ereignisse haben eine Bildkategorie")
		for option in event.options:
			for effect in option.effects:
				check(effect in ["gold", "prestige", "levy", "dev", "health", "heir"], "Ereignis verspricht keinen unimplementierten Effekt")
	var g = Game.new(Data, 0)
	var recent: Array = []
	seed(11919)
	for index in 36:
		g._trigger_event()
		check(not recent.has(g.pending_event.id), "Keine Wiederholung unter den letzten sechs Ereignissen")
		recent.append(g.pending_event.id)
		if recent.size() > 6:
			recent.pop_front()
		g.apply_event(1)
	check(g.house().event_history.size() == 6, "Ereignishistorie bleibt auf sechs Einträge begrenzt")
	g._trigger_event()
	var expected := str(g.pending_event.id)
	var history: Array = g.house().event_history.duplicate()
	var loaded = Game.new(Data, 0)
	check(loaded.restore(JSON.parse_string(JSON.stringify(g.snapshot()))), "Neue Ereignisse bleiben ladbar")
	check(str(loaded.pending_event.id) == expected and loaded.house().event_history == history, "Ausstehende ID und Wiederholungssperre überleben Laden")
	var director = load("res://scripts/EventDirector.gd")
	var context := {"coastal":false,"war":false,"research":false,"sick":false,"poor":false,"rich":false,"no_heir":false,"roads":false,"developed":false}
	for event in director.eligible(pool, context):
		check(str(event.get("condition", "")) == "", "Fehlende Bedingungen lassen nur allgemeine Ereignisse zu")
	var tiny := [{"id":"one","condition":""},{"id":"two","condition":""}]
	check(director.choose(tiny, context, ["one","two"], 0.0).id == "one", "Deterministischer Fallback vermeidet den letzten Fall auch bei kleinem Pool")
	var humans = Game.new(Data, 0)
	check(humans.configure_human_houses([0,1]), "Zwei menschliche Ereigniskontexte vorhanden")
	humans.select_player_context(0)
	humans._trigger_event()
	var first_history: Array = humans.houses[0].event_history.duplicate()
	humans.select_player_context(1)
	humans._trigger_event()
	check(humans.houses[0].event_history == first_history and humans.houses[1].event_history.size() == 1, "Historie eines anderen menschlichen Hauses wird nicht überschrieben")
	var weighted = Game.new(Data, 0)
	var first: Dictionary = weighted.owned()[0]
	var second: Dictionary = weighted.owned()[1]
	first.economic_share = 0.01
	first.levy = 35
	second.levy = 0
	weighted._apply_effects({"levy":180})
	check(first.levy == 40 and second.levy == 175, "Ereignistruppen beachten regionale Kapazität und erhalten das gesamte Stärkebudget")
	first.levy = 5000
	weighted._apply_effects({"levy":1})
	check(first.levy == 5000, "Ein positiver Ereigniseffekt vernichtet keinen geerbten Überhang")
	finish()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("EVENTVARIETYTEST FAIL: " + message)
	return ok

func finish() -> void:
	print("EVENTVARIETYTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
