extends Node
## Integrationsfälle am echten Game-Modell. Kontrollierte Testkassen und
## Besitzumlegung sind KEIN regulärer 120-Gold-Kampagnennachweis.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
const REMOTE := "anatolien__01"
var checks := 0
var failures := 0

func _ready() -> void:
	seed(202611171)
	_test_actual_alternative_and_siege()
	_test_staging_and_fleet_guard()
	_test_annual_reserve_and_purchases()
	_test_existing_fleet_costs()
	_test_actual_claimless_retreat()
	_test_other_house_and_humans()
	print("NAVALAIINTEGRATIONTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func _funded_npc(hi: int = 2):
	var game = Game.new(Data,0)
	if hi!=2:
		for region in game.provinces:
			if int(region.owner)==hi: region.owner=1
			if str(region.id).begins_with("britannien__"): region.owner=hi
		game.houses[hi].capital = HOME
	game.houses[hi].gold = 1000
	game.houses[hi].claims.clear()
	check(game.raise_army(HOME,hi).ok and game.raise_fleet(HOME,hi).ok,"Kontrollierte NPC-Kasse bezahlt Heer und Geleit über echte Befehle")
	return game

func _test_actual_alternative_and_siege() -> void:
	var game = _funded_npc()
	game._add_claim(2,REMOTE)
	game._add_claim(2,TARGET)
	var gold: int = game.houses[2].gold
	var owner: int = game.province(TARGET).owner
	game._run_ai_military()
	check(str(game.army_for(2).province)==TARGET and str(game.fleet_for(2).province)==TARGET and str(game.fleet_for(2).station)==TARGET,"NPC übersetzt tatsächlich zum erreichbaren Zweitanspruch trotz unerreichbarem Erstanspruch")
	check(int(game.army_for(2).get("last_siege_month",-1))==game._now() and int(game.fleet_for(2).get("last_naval_month",-1))==game._now(),"Echte KI-Überfahrt verbraucht beide offensiven Monatsaktionen")
	check(int(game.houses[2].gold)==gold and int(game.province(TARGET).owner)==owner and int(game.province(TARGET).siege)==0,"KI-Landung berechnet keine Überfahrtkasse und erobert/belagert noch nicht")
	var landed: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==landed,"Wiederholter KI-Militärlauf führt im Landemonat keinen zweiten Befehl aus")
	game.month += 1
	game._run_ai_military()
	check(int(game.province(TARGET).siege)>0 and int(game.province(TARGET).siege_owner)==2,"NPC belagert den tatsächlich erreichten Anspruch in einem späteren Monat")

func _test_staging_and_fleet_guard() -> void:
	var game = _funded_npc()
	game._add_claim(2,TARGET)
	game.army_for(2).province = "britannien__04"
	game._run_ai_military()
	check(str(game.army_for(2).province)==HOME and str(game.fleet_for(2).station)==HOME,"KI marschiert zunächst zum vorhandenen Geleit statt Flotte oder Heer zu teleportieren")
	var staged: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==staged,"Marsch zum Hafen verhindert KI-Überfahrt im selben Monat")
	game.month += 1
	game._run_ai_military()
	check(str(game.army_for(2).province)==TARGET,"Nach echtem Hafenmarsch übersetzt die KI erst im nächsten Monat")
	game = _funded_npc()
	game._add_claim(2,TARGET)
	game.fleet_for(2).last_naval_month = game._now()
	var guarded: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==guarded,"Auch freie NPC-Armee umgeht keine bereits verbrauchte Geleitaktion")
	game.month += 1
	game._run_ai_military()
	check(str(game.army_for(2).province)==TARGET,"Freies Geleit im Folgemonat erlaubt den neu geplanten realen Transport")

func _test_annual_reserve_and_purchases() -> void:
	var game = Game.new(Data,0)
	check(int(game.houses[2].gold)==120 and game.army_for(2).is_empty() and game.fleet_for(2).is_empty(),"Originaler NPC-Wessex startet mit 120 Gold ohne Expeditionskäufe")
	var claims: Array = game.houses[2].claims.duplicate(true)
	var spouse: Dictionary = game.houses[2].spouse.duplicate(true)
	game.run_ai_turn(false)
	check(int(game.houses[2].gold)==120 and game.army_for(2).is_empty() and game.fleet_for(2).is_empty(),"Jährliche KI spart die unzureichenden 120 Gold vollständig für die Expedition")
	check(game.houses[2].claims==claims and game.houses[2].spouse==spouse,"Unfertige Expeditionsreserve wird weder für Teilkäufe noch optionale Hochzeit verbraucht")
	# Ab hier ausdrückliche Testkasse; keine aus Einkommen erzielten 30 Gold.
	game = Game.new(Data,0)
	game.houses[2].gold = 150
	game.run_ai_turn(false)
	check(int(game.houses[2].gold)==0,"Kontrollierte 150-Gold-Kasse bezahlt genau 50 Heer + 60 Flotte + 40 Anspruch")
	check(game.houses[2].armies.size()==1 and game.houses[2].fleets.size()==1 and game.claim_active(TARGET,2),"Bezahlbare Vorbereitung stellt genau ein Heer/ein Geleit und den echten Küstenanspruch bereit")
	check(str(game.army_for(2).get("province",""))==HOME and str(game.fleet_for(2).get("station",""))==HOME and int(game.fleet_for(2).get("last_naval_month",-1))!=game._now(),"Jährliche Vorbereitung verbraucht benötigtes Geleit nicht nebenher für eine Blockade")
	game._run_ai_military()
	check(str(game.army_for(2).get("province",""))==TARGET,"Reguläre KI-Militärphase führt die bezahlte vorbereitete Expedition tatsächlich aus")

func _test_existing_fleet_costs() -> void:
	var game = Game.new(Data,0)
	game.houses[2].gold = 150
	check(game.raise_fleet(HOME,2).ok and int(game.houses[2].gold)==90,"Vorhandenes Geleit wurde im Test regulär mit 60 Gold bezahlt")
	var fleet: Dictionary = game.fleet_for(2).duplicate(true)
	game.run_ai_turn(false)
	check(int(game.houses[2].gold)==0 and game.houses[2].fleets.size()==1 and game.fleet_for(2)==fleet,"KI ersetzt vorhandenes Geleit nicht und bezahlt nur fehlende 50+40 Gold")
	check(game.houses[2].armies.size()==1 and game.claim_active(TARGET,2),"Teilvorbereitung ergänzt echtes Heer und Küstenanspruch")

func _test_actual_claimless_retreat() -> void:
	var game = _funded_npc()
	game._add_claim(2,TARGET)
	check(game.transport_army(TARGET,2).ok,"Rückzugsfall beginnt mit echter öffentlicher Landung")
	game.houses[2].claims.clear()
	game.houses[2].gold = 0
	var landed: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==landed,"Anspruchsloser NPC-Rückzug verbraucht keine zweite Aktion im Landemonat")
	game.month += 1
	game._run_ai_military()
	check(str(game.army_for(2).province)==HOME and str(game.fleet_for(2).province)==HOME and str(game.fleet_for(2).station)==HOME,"NPC ohne Ansprüche zieht Heer und echtes Geleit im Folgemonat in eigenes Land zurück")
	check(int(game.houses[2].gold)==0 and game.houses[2].claims.is_empty(),"Legaler Heimtransport benötigt weder Goldinjektion noch erfundenen Anspruch")

func _test_other_house_and_humans() -> void:
	var game = _funded_npc(5)
	game._add_claim(5,REMOTE)
	game._add_claim(5,TARGET)
	game._run_ai_military()
	check(str(game.army_for(5).province)==TARGET and str(game.fleet_for(5).station)==TARGET,"Echter KI-Transport funktioniert nach kontrolliertem Besitzerwechsel auch für Haus 5")
	game = _funded_npc()
	game._add_claim(2,TARGET)
	check(game.configure_human_houses([0,2]),"Wessex wird regulär zum menschlichen LAN-Sitz")
	var human: Dictionary = game.houses[2].duplicate(true)
	game._run_ai_military()
	check(game.houses[2]==human,"KI-Militärphase führt keine Befehle für menschliches Wessex aus")
	game.run_ai_turn(false)
	check(game.houses[2]==human,"Jährliche KI kauft und entscheidet nicht für menschlichen LAN-Sitz")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALAIINTEGRATIONTEST FAIL: "+text)
