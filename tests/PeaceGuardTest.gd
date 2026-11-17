extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const Authority = preload("res://scripts/LanAuthority.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	_test_reason_api()
	_test_replay()
	_test_expiry()
	_test_authority_and_save()
	print("PEACEGUARDTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)

func _test_reason_api() -> void:
	var g = Game.new(Data,0)
	check(g.has_method("peace_reason"),"Reine Friedensgrund-API ist verfügbar")
	if not g.has_method("peace_reason"):
		return
	var before: Dictionary = g.snapshot()
	seed(191425)
	var expected := randi()
	seed(191425)
	check(str(g.call("peace_reason",1)) == "","Erster gültiger Frieden hat keinen Sperrgrund")
	check(str(g.call("peace_reason",0)) != "" and str(g.call("peace_reason",999)) != "","Eigener und unbekannter Friedenspartner haben Sperrgründe")
	check(str(g.call("peace_reason",1,999)) != "","Ungültiger handelnder Hausindex hat einen sicheren Sperrgrund")
	check(g.snapshot() == before and randi() == expected,"Alle Grundabfragen bewahren Spielzustand und Zufallsfolge")
	g.make_peace(1)
	before = g.snapshot()
	seed(191426)
	expected = randi()
	seed(191426)
	var reason := str(g.call("peace_reason",1))
	check(reason.contains("24") and not reason.is_empty(),"Bestehender Frieden nennt die genaue verbleibende Monatsfrist")
	check(g.snapshot() == before and randi() == expected,"Auch die gesperrte Grundabfrage ist frei von Mutation und Ehe-Neuwürfen")

func _test_replay() -> void:
	var g = Game.new(Data,0)
	check(g.make_peace(1).ok,"Erster gültiger Frieden bleibt verfügbar")
	var before: Dictionary = g.snapshot()
	seed(191424)
	var expected := randi()
	seed(191424)
	check(not g.make_peace(1).ok,"Bestehender Waffenstillstand weist wiederholten Frieden ab")
	check(g.snapshot() == before,"Keine zweite Beziehung, Frist, Ehe, Ausgabe oder Chronikmutation")
	check(randi() == expected,"Friedenswiederholung würfelt keine Ehe neu")
	var k := Kernel.new()
	k.bind_game(g)
	for p in g.provinces:
		if int(p.owner) == 1: k.select_province(str(p.id)); break
	check(not k.dispatch({"id":"peace"}).ok,"Auch Kernel weist ein neues Friedenskommando während bestehender Frist ab")
	check(g.snapshot() == before,"Gerouteter Friedens-Replay bewahrt den vollständigen Spielzustand")
	check(not g.make_peace(1,999).ok,"Ungültiger handelnder Hausindex wird sicher abgewiesen")

func _test_expiry() -> void:
	var g = Game.new(Data,0)
	g.make_peace(1)
	for month in 23: g.advance_month()
	check(g.truce_until(1) - g._now() == 1 and not g.make_peace(1).ok,"Auch einen Monat vor Ablauf bleibt Frieden gesperrt")
	if g.has_method("peace_reason"):
		check(str(g.call("peace_reason",1)).contains("1"),"Grundabfrage meldet einen Monat vor Ablauf die verbleibende Frist")
	g.advance_month()
	check(g.truce_until(1) == g._now(),"Exakter24Monatsablauf wird erreicht")
	if g.has_method("peace_reason"):
		check(str(g.call("peace_reason",1)) == "","Grundabfrage öffnet genau bei Ablauf")
	check(g.make_peace(1).ok and g.truce_until(1) == g._now()+24,"Genau bei Ablauf ist ein neuer24Monatsfrieden erlaubt")

func _test_authority_and_save() -> void:
	var g = Game.new(Data,0)
	g.configure_human_houses([0,1])
	var target := ""
	for p in g.provinces:
		if int(p.owner) == 2: target = str(p.id); break
	var authority := Authority.new(g,{1:0,2:1})
	check(authority.execute(2,1,{"id":"peace","selection":target}).ok,"Gast handelt Frieden ausschließlich im zugewiesenen Haus aus")
	check(g.truce_until(2,1) > g._now() and g.truce_until(2,0) == 0,"Gastfrist wird nicht dem Host zugeschrieben")
	var before: Dictionary = g.snapshot()
	check(not authority.execute(2,2,{"id":"peace","selection":target}).ok,"Neuer Gast-Sequenzwert umgeht bestehende Friedensfrist nicht")
	check(g.player == 0 and g.snapshot() == before,"Abgewiesener Gast-Replay verändert weder Hauszustände noch aktive Perspektive")
	var restored = Game.new(Data,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(before))),"Gemeinsamer Friedensstand überlebt JSON-Roundtrip")
	check(not restored.make_peace(2,1).ok,"Expliziter inaktiver Hauskontext wahrt gespeicherten Waffenstillstand")
	var resumed := Authority.new(restored,{1:0,2:1})
	check(not resumed.execute(2,1,{"id":"peace","selection":target}).ok,"Neue Sitzung nach Laden erlaubt keinen Bonus-Replay")

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PEACEGUARDTEST FAIL: " + message)
