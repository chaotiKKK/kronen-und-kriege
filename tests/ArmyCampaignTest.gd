extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
const Save = preload("res://scripts/SaveGame.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	_test_claim_and_march_guards()
	_test_context_and_reaction()
	_test_ai_route()
	_test_preview()
	_test_attack_monthly_action()
	_test_selection()
	_test_raw_save()
	print("ARMYCAMPAIGNTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func _army(home: String, id: int = 1) -> Dictionary:
	return {"id":id,"province":home,"strength":500,"upkeep":2,"morale":100}

func _test_claim_and_march_guards() -> void:
	var g = Game.new(Data)
	var home := str(g.house().capital)
	var target := str(g.neighbours(home)[0])
	g.province(target).owner = 1
	g.house().gold = 1000
	g.house().armies = [_army(home)]
	var before: Dictionary = g.snapshot()
	check(not g.march_army(target).ok and g.snapshot() == before,"Fremdes Land ohne Anspruch bleibt ohne Mutation gesperrt")
	check(g.fabricate_claim(target).ok,"Grenzanspruch lässt sich erwerben")
	before = g.snapshot()
	check(not g.fabricate_claim(target).ok and g.snapshot() == before,"Doppelter Anspruch kostet weder Gold noch Zustand")
	g.house().truces[str(1)] = g._now() + 12
	before = g.snapshot()
	check(not g.march_army(target).ok and g.snapshot() == before,"Waffenstillstand blockiert Einmarsch ohne Mutation")
	g.house().truces = {}
	check(g.march_army(target).ok,"Anspruch erlaubt benachbarten Marsch")
	check(not g.can_siege(target) and g.siege_reason(target).contains("Monat"),"Marsch und Belagerung teilen dieselbe monatliche Aktion")
	g.advance_month()
	check(g.advance_siege(target).ok,"Im Folgemonat beginnt die Belagerung am Standort")

func _test_context_and_reaction() -> void:
	var g = Game.new(Data)
	g.configure_human_houses([0,1])
	var home := str(g.houses[1].capital)
	var target := str(g.neighbours(home)[0])
	g.province(target).owner = 2
	g.houses[1].armies = [_army(home)]
	g._add_claim(1,target)
	g.set_opinion_value(0,2,80)
	g.set_opinion_value(1,2,0)
	check(g.can_march(target,1),"Explizites Haus nutzt eigene Beziehung beim Marsch")
	check(g.can_siege(target,1),"Explizites Haus nutzt eigene Beziehung bei Belagerung")
	g.set_opinion_value(1,2,80)
	check(not g.can_march(target,1) and not g.can_siege(target,1),"Eigene gute Beziehung sperrt beide Aktionen")
	g.set_opinion_value(0,1,10)
	g.set_opinion_value(1,0,20)
	var captured := str(g.houses[1].capital)
	g._capture_province(captured,0)
	check(g.opinion_value(0,1) == -20,"Eroberer erhält Beziehungsfolge")
	check(g.opinion_value(1,0) == -10,"Verteidiger erhält dieselbe Beziehungsfolge")
	check(str(g.log_lines[-2]).contains("Eroberung"),"Eroberung erscheint in Chronik")
	g.select_player_context(1)
	check(str(g.log_lines[-1]).contains("Eroberung"),"Auch inaktiver menschlicher Verteidiger wird informiert")

func _test_ai_route() -> void:
	var g = Game.new(Data)
	var hi := 1
	var home := str(g.houses[hi].capital)
	var step := ""
	var target := ""
	for n in g.neighbours(home):
		for t in g.neighbours(str(n)):
			if str(t) != home and not g.neighbours(home).has(t):
				step = str(n)
				target = str(t)
	check(target != "","KI-Test besitzt einen echten Zwei-Schritte-Weg")
	if target == "": return
	for p in g.provinces: p.owner = 0
	g.province(home).owner = hi
	g.province(step).owner = hi
	g.houses[hi].armies = [_army(home)]
	g.houses[hi].claims = []
	g._add_claim(hi,target)
	g.houses[hi].gold = 0
	# Die Route ist Gegenstand dieses Falls. Lokale Aufgebote sind kontrolliert
	# klein, sodass das echte500er-Heer schon bereit ist und keine Erholung braucht.
	g.province(home).levy=200
	g.province(step).levy=200
	g.province(step).terrain_supply=6
	g.province(target).levy=100
	g.province(target).defense=0
	g.province(target).terrain_defense=0
	g.opinion[0] = 0
	g.run_ai_turn()
	check(g.army_for(hi).province == step,"KI marschiert zur entfernten eigenen Front")
	check(int(g.province(target).siege) == 0,"KI erzeugt keinen Marsch-und-Belagerungs-Doppelschritt")
	g.month += 1
	g.run_ai_turn()
	check(int(g.province(target).siege) > 0,"KI belagert nach Ankunft im nächsten Monat")

func _test_preview() -> void:
	var g = Game.new(Data)
	var home := str(g.house().capital)
	var target := str(g.neighbours(home)[0])
	g.province(target).owner = 1
	g._add_claim(0,target)
	g.house().gold = 1000
	var before: Dictionary = g.snapshot()
	var base: Dictionary = g.attack_preview(target)
	check(g.snapshot() == before,"Vorschau verändert keinen Spielzustand")
	g.house().armies = [_army(home)]
	var with_army: Dictionary = g.attack_preview(target)
	check(not base.ok and base.attack_power==0 and with_army.ok and with_army.attack_power==500*(1.0+int(g.house().ruler.martial)/20.0),"Nur tatsächliches Feldheer liefert moral- und herrscherabhängige Angriffskraft")
	check(with_army.field_army_strength == 500 and with_army.chance >= 0 and with_army.chance <= 1,"Vorschau liefert konsistente Prozentgrundlage")
	g.house().armies[0].morale = 50
	check(g.attack_preview(target).field_army_strength == 250,"Moral beeinflusst tatsächlichen Armeebeitrag")
	g.province(target).levy = 100000
	g.attack_roll_override = 1.0
	var defeat: Dictionary = g.attack(target)
	check(defeat.ok and defeat.get("won")==false,"Überlegener Verteidiger gewinnt eine tatsächlich aufgelöste Schlacht")
	check(int(g.army_for().strength) == 400,"Beteiligte Feldarmee erleidet reale Niederlageverluste")
	g.province(target).levy = 0
	g.month += 1
	var old_opinion := int(g.opinion[1])
	check(g.attack(target).ok and int(g.province(target).owner) == 0,"Angriff nimmt reales Ziel ein")
	check(int(g.opinion[1]) == maxi(-100,old_opinion - 30),"Angriff teilt die Beziehungsfolge der Belagerung")

func _test_attack_monthly_action() -> void:
	var g = Game.new(Data)
	var home := str(g.house().capital)
	var target := str(g.neighbours(home)[0])
	g.province(target).owner = 1
	g.province(target).levy = 100000
	g._add_claim(0,target)
	g.house().gold = 1000
	g.house().armies = [_army(home)]
	g.attack_roll_override = 1.0
	check(g.march_army(target).ok,"Feldheer marschiert zum Schlachtziel")
	check(not g.can_siege(target) and not g.can_attack(target),"Verbrauchtes Feldheer sperrt Belagerung und Sturm ohne nationale Ersatzaktion")
	check(g.attack_preview(target).field_army_strength == 0,"Bereits marschierte Armee trägt im selben Monat nicht zum Angriff bei")
	g.attack(target)
	check(int(g.army_for().strength) == 500,"Abgewiesener Sturm verändert das bereits marschierte Feldheer nicht")
	var restored = Game.new(Data)
	check(restored.restore(g.snapshot()) and restored.attack_preview(target).field_army_strength == 0,"Laden erneuert keinen verbrauchten Armeebeitrag")
	g.month += 1
	check(g.attack_preview(target).field_army_strength == 500,"Im nächsten Monat ist der Armeebeitrag wieder verfügbar")
	g.attack(target)
	check(int(g.army_for().strength) == 400,"Tatsächlich beteiligte Armee erleidet Niederlageverluste")
	check(int(g.army_for().get("last_siege_month", -1)) == g._now(),"Tatsächliche Schlacht verbraucht die Monatsaktion der Armee")
	check(g.attack_preview(target).field_army_strength == 0 and not g.can_siege(target),"Schlacht verhindert erneuten Armeebeitrag und Belagerung im selben Monat")
	g.attack(target)
	check(int(g.army_for().strength) == 400,"Abgewiesener Wiederholungssturm schädigt verbrauchtes Feldheer nicht erneut")
	g.house().armies.append(_army(home,2))
	check(g.select_army(2).ok and g.attack_preview(target).field_army_strength == 500,"Unverbrauchte zweite Bestandsarmee besitzt eigene Monatsaktion")
	g.attack(target)
	check(g.attack_preview(target).field_army_strength == 0,"Auch zweite Armee ist nach ihrer Schlacht verbraucht")
	check(g.select_army(1).ok and g.attack_preview(target).field_army_strength == 0,"Zurückwechseln reaktiviert verbrauchte erste Armee nicht")
	check(restored.restore(g.snapshot()) and restored.attack_preview(target).field_army_strength == 0,"Mehrarmeen-Save erhält Monatsaktionen")
	check(restored.select_army(2).ok and restored.attack_preview(target).field_army_strength == 0,"Nach Laden bleibt auch zweite Armee verbraucht")

func _test_selection() -> void:
	var g = Game.new(Data)
	var home := str(g.house().capital)
	g.house().armies = [_army(home,1),_army(str(g.neighbours(home)[0]),2)]
	if not g.has_method("select_army"):
		check(false,"Armeeauswahl fehlt")
		return
	var before: Dictionary = g.snapshot()
	check(g.select_army(2).ok and int(g.army_for().id) == 2,"Bestandsarmee explizit auswählen")
	check(g.house().gold == before.houses[0].gold and g._now() == int(before.month_index) + 1,"Auswahl kostet weder Gold noch Zeit")
	check(g.house().armies.size() == 2 and g.house().armies[1] == before.houses[0].armies[0],"Auswahl bewahrt sämtliche Armeen")
	var restored = Game.new(Data)
	check(restored.restore(g.snapshot()) and int(restored.army_for().id) == 2,"Auswahl überlebt Speichern und Laden")
	before = g.snapshot()
	check(not g.select_army(999).ok and g.snapshot() == before,"Unbekannte ID verändert nichts")
	g.house().armies[1].id = 2
	check(not g.select_army(2).ok,"Mehrdeutige Roh-ID wird abgewiesen")
	var legacy: Dictionary = before.duplicate(true)
	legacy.houses[0].armies[1].id = legacy.houses[0].armies[0].id
	var migrated: Dictionary = Save.migrate(legacy)
	check(migrated.ok and migrated.data.houses[0].armies[0].id != migrated.data.houses[0].armies[1].id,"Migration repariert doppelte Alt-IDs ohne Truppenverlust")
	check(migrated.data.houses[0].armies[0].strength == 500 and migrated.data.houses[0].armies[1].strength == 500,"ID-Reparatur bewahrt jede Stärke")
	var repaired: Array = Save._migrate_armies([_army(home,0),_army(home,1),_army(home,1)])
	check(repaired[1].id == 1,"Gültige Bestands-ID bleibt trotz vorher fehlender ID stabil")
	check(repaired[0].id > 0 and repaired[0].id != repaired[1].id and repaired[2].id != repaired[0].id and repaired[2].id != repaired[1].id,"Fehlende/doppelte Alt-IDs werden eindeutig repariert")
	check(Save._migrate_armies(repaired) == repaired,"ID-Migration ist idempotent")

func _test_raw_save() -> void:
	var g = Game.new(Data)
	var s: Dictionary = g.snapshot()
	s.houses[0].armies = "invalid"
	check(not Save.migrate(s).ok,"Ungültiger Armeecontainer wird sicher abgewiesen")
	s = g.snapshot()
	s.houses = 1
	check(not Save.migrate(s).ok,"Ungültiger Hauscontainer wird sicher abgewiesen")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("ARMYCAMPAIGNTEST FAIL: " + message)
