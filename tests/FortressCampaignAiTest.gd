extends Node
## Kontrollierte echte 108er-Graphfälle. Geld, Besitz und Feldheere sind
## explizite Testdaten; kein Nachweis einer regulären Startbudgetkampagne.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
var Planner
const HOME := "britannien__03"
const TARGET := "gallien__04"
const NEAR := "gallien__03"
const FAR := "germanien__02"
var checks := 0
var failures := 0

func _ready() -> void:
	Planner=load("res://scripts/NavalCampaign.gd")
	_test_relief_priority_and_actual_command()
	_test_recovery_and_shared_month()
	_test_assault_and_real_retreat()
	_test_land_route_to_relief()
	_test_escort_limit_and_morale_zero()
	_test_annual_reserve_and_humans()
	_test_readiness_and_purity()
	_test_unsafe_own_camp_and_unaffordable_assault()
	print("FORTRESSCAMPAIGNAITEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func army(at: String, strength: int, morale: int = 100) -> Dictionary:
	return {"id":7,"province":at,"strength":strength,"morale":morale,"upkeep":maxi(1,strength/250)}

func fixture():
	var game = Game.new(Data,0)
	for hi in game.houses.size():
		game.houses[hi].armies=[]
		game.houses[hi].fleets=[]
		game.houses[hi].claims=[]
		game.houses[hi].ruler.martial=0
		game.houses[hi].doctrine="balanced"
		game.houses[hi].legacies.war=0
		game.houses[hi].research.known=[]
	game.houses[2].gold=1000
	game.houses[2].armies=[army(NEAR,1000)]
	game.province(NEAR).owner=2
	game.province(NEAR).levy=300
	var p: Dictionary = game.province(TARGET)
	p.owner=1
	p.levy=50
	p.defense=0
	p.dev=6
	p.terrain_defense=0
	p.terrain_supply=6
	game._add_claim(2,TARGET)
	game.attack_roll_override=1.0
	return game

func _test_relief_priority_and_actual_command() -> void:
	var game = fixture()
	game.province(TARGET).owner=2
	game.province(TARGET).siege=40
	game.province(TARGET).siege_owner=1
	game.houses[1].armies=[army(TARGET,100)]
	game.army_for(1).last_siege_month=game._now()
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="relieve" and order.get("destination")==TARGET,"Bedrohte eigene Nachbarprovinz erhält echten Entsatz vor Angriff oder Erholung")
	var gold: int = game.houses[2].gold
	game._run_ai_military()
	check(str(game.army_for(2).province)==TARGET and int(game.province(TARGET).siege)==0,"NPC führt Entsatz tatsächlich aus und beendet ungestützte Belagerung")
	check(int(game.province(TARGET).owner)==2 and int(game.houses[2].gold)==gold and int(game.army_for(2).strength)==900,"Entsatz verändert keinen Besitz, kostet null Gold und bezahlt echte Kampfverluste")
	var after: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==after,"Auch erfolgreicher KI-Entsatz sperrt weitere Monatsbefehle")

func _test_recovery_and_shared_month() -> void:
	var game = fixture()
	game.houses[2].armies=[army(HOME,100,40)]
	game.province(HOME).levy=300
	game.houses[2].gold=20
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="recover" and order.get("destination")==HOME,"Schwaches eigenes Heer erhält bezahlte Erholung vor einer Expedition")
	game._run_ai_military()
	check(int(game.army_for(2).strength)==200 and int(game.army_for(2).morale)==60 and int(game.houses[2].gold)==5,"NPC-Auffüllen übernimmt hundert echte Soldaten und bezahlt fünfzehn Gold")
	check(int(game.province(HOME).levy)==200,"KI kopiert keine Soldaten aus dem örtlichen Aufgebot")
	var after: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==after,"Erholung und Feldzug teilen dieselbe Monatsaktion")
	game.month+=1
	game.houses[2].gold=0
	order=Planner.next_order(game,2)
	check(order.get("action")=="wait" and not str(order.get("blocked_reason","")).is_empty(),"Unbezahlbare notwendige Erholung liefert belegten Wartezustand statt Angriff")

func _test_assault_and_real_retreat() -> void:
	var game = fixture()
	game.houses[1].armies=[army(TARGET,100)]
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="attack" and float(game.attack_preview(TARGET,2).chance)>=0.55,"Tatsächlicher Verteidiger löst aussichtsreichen Sturm statt blockierter Belagerung aus")
	game._run_ai_military()
	check(int(game.province(TARGET).owner)==2 and int(game.army_for(2).strength)==900,"NPC benutzt den öffentlichen Sturm mit realer Eroberung und Verlusten")
	game=fixture()
	game.houses[2].armies=[army(TARGET,10,30)]
	game.province(TARGET).levy=10000
	order=Planner.next_order(game,2)
	check(order.get("action")=="march" and order.get("destination")==NEAR and bool(order.get("retreat",false)),"Aussichtsloses gelandetes Restheer plant echten eigenen Landnachbarn zur Erholung")
	game._run_ai_military()
	check(str(game.army_for(2).province)==NEAR and int(game.province(TARGET).siege)==0,"NPC zieht real zurück statt wiederholt aussichtslos zu belagern")
	game=fixture()
	game.houses[2].armies=[army(TARGET,10)]
	game.province(TARGET).levy=10000
	game.province(NEAR).owner=1
	order=Planner.next_order(game,2)
	check(order.get("action")=="wait" and not str(order.get("blocked_reason","")).is_empty(),"Eingeschlossener schwacher Angreifer wartet ausdrücklich statt Kapitalteleport oder Fernsturm")

func _test_land_route_to_relief() -> void:
	var game = fixture()
	# Echte Katalogkanten: Paris -> Brüssel -> Elsass, nicht Reichsnachbarschaft.
	check(game.neighbours(NEAR).has(TARGET) and game.neighbours(TARGET).has(FAR) and not game.neighbours(NEAR).has(FAR),"Entsatzroute benutzt zwei tatsächlich vorhandene Graphkanten")
	game.province(TARGET).owner=2
	game.province(FAR).owner=2
	game.province(FAR).siege=40
	game.province(FAR).siege_owner=1
	game.houses[1].armies=[army(FAR,100)]
	game.army_for(1).last_siege_month=game._now()
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="march" and order.get("target")==FAR and order.get("destination")==TARGET,"KI marschiert über eigenes Land an die bedrohte Front")
	game._run_ai_military()
	check(str(game.army_for(2).province)==TARGET,"Entsatz-Anmarsch wird als echte einzelne Monatsbewegung ausgeführt")
	game.province(TARGET).owner=1
	game.houses[2].armies=[army(NEAR,1000)]
	check(Planner.next_order(game,2).get("target")!=FAR,"Feindliches Zwischenland wird nicht als Entsatzabkürzung verwendet")

func _test_escort_limit_and_morale_zero() -> void:
	var game = fixture()
	game.houses[2].armies=[army(HOME,90,40)]
	game.province(HOME).levy=300
	game.houses[2].fleets=[{"id":5,"province":HOME,"station":HOME,"ships":1,"morale":100,"last_naval_month":-1}]
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="wait" and str(order.get("blocked_reason","")).contains("Geleit"),"KI lehnt echte Erholungscharge über realer Geleitkapazität ausdrücklich ab")
	var before: Dictionary = game.snapshot()
	game._run_ai_military()
	check(game.snapshot()==before,"Geleitgrenze erzeugt weder übergroßes Heer noch künstliche Ressourcenmutation")
	game.houses[2].fleets=[]
	game.houses[2].armies=[army(HOME,100,0)]
	check(Planner.next_order(game,2).get("action")=="recover","Auch moralisch vollständig erschöpftes lebendes NPC-Heer darf sich im eigenen Land erholen")

func _test_annual_reserve_and_humans() -> void:
	var game = fixture()
	game.houses[2].armies=[army(HOME,100,40)]
	game.province(HOME).levy=300
	game.houses[2].gold=30
	game.houses[2].spouse={}
	game.run_ai_turn(false)
	check(int(game.houses[2].gold)>=15 and game.houses[2].spouse.is_empty(),"Jährliche KI reserviert fünfzehn Erholungsgold statt konkurrierender dreißig-Gold-Hochzeit")
	var saved_gold: int = game.houses[2].gold
	game._run_ai_military()
	check(int(game.houses[2].gold)==saved_gold-15 and int(game.army_for(2).strength)==200,"Die echte Monatsphase verwendet die reservierten Mittel ausschließlich für Erholung")
	game=fixture()
	game.configure_human_houses([0,2])
	game.houses[2].armies=[army(HOME,100,40)]
	var human: Dictionary = game.houses[2].duplicate(true)
	game.run_ai_turn()
	check(game.houses[2]==human,"Menschlicher LAN-Sitz wird auch bei dringender Erholung nicht automatisiert")

func _test_readiness_and_purity() -> void:
	var has_readiness := false
	var has_reserve := false
	for method in Planner.get_script_method_list():
		if str(method.name)=="readiness": has_readiness=true
		if str(method.name)=="military_reserve": has_reserve=true
	check(has_readiness and has_reserve,"Planer bietet reine Bereitschaft und echten nächsten Militärreservebedarf")
	if not has_readiness or not has_reserve: return
	var game = fixture()
	game.houses[2].armies=[army(HOME,100,40)]
	game.province(HOME).levy=300
	var before: Dictionary = game.snapshot()
	seed(1726)
	var expected := randf()
	seed(1726)
	var ready: Dictionary = Planner.readiness(game,2)
	var reserve: int = Planner.military_reserve(game,2)
	Planner.next_order(game,2)
	check(game.snapshot()==before and randf()==expected,"Bereitschaft, Reserve und Feldzugsentscheidung erhalten Welt, Log und RNG")
	check(int(ready.minimum_strength)<int(ready.capacity)*0.6 and int(ready.minimum_strength)==ceili(game.army_raise_strength(HOME,2)*1.25),"Große echte Regionalreserve erzwingt keine jahrelange Maximalaufrüstung statt begrenzter Aufstellungsprognose")
	check(reserve==15,"Militärreserve entspricht exakt der nächsten tatsächlichen hundert-Mann-Charge")
	game.province(HOME).levy=50
	game.army_for(2).morale=100
	ready=Planner.readiness(game,2)
	check(not bool(ready.needed),"Nicht verfügbare örtliche Soldaten oberhalb der fünfzig-Mann-Reserve erzwingen kein unerreichbares Bereitschaftsziel")

func _test_unsafe_own_camp_and_unaffordable_assault() -> void:
	var game = fixture()
	game.province(TARGET).owner=2
	game.houses[2].armies=[army(TARGET,10,30)]
	game.houses[1].armies=[army(TARGET,10000)]
	game.army_for(1).last_siege_month=game._now()
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="march" and order.get("destination")==NEAR and bool(order.get("retreat",false)),"Unterlegener Verteidiger verlässt sein feindbesetztes Feldlager über einen echten freien eigenen Nachbarn")
	game._run_ai_military()
	check(str(game.army_for(2).province)==NEAR,"Unmöglicher Entsatz und blockierte Erholung führen tatsächlich zum sicheren Feldlager")
	game=fixture()
	game.houses[2].armies=[army(TARGET,10,0)]
	check(Planner.next_order(game,2).get("destination")==NEAR,"Moralnull-Heer kann eine echte eigene Rückzugsetappe planen")
	game._run_ai_military()
	check(str(game.army_for(2).province)==NEAR,"Moralnull-Rückzug benutzt denselben öffentlichen eigenen Marschbefehl")
	game=fixture()
	game.houses[1].armies=[army(TARGET,100)]
	game.army_for(1).last_siege_month=game._now()
	game.houses[2].gold=20
	var before: Dictionary = game.snapshot()
	var preview: Dictionary = game.attack_preview(TARGET,2)
	check(not bool(preview.ok) and float(preview.chance)==1.0 and float(preview.attack_power)>0 and game.snapshot()==before,"Geldgesperrter Sturm behält echte reine100-Prozent-Kampfprognose ohne virtuelle Testkasse")
	order=Planner.next_order(game,2)
	check(order.get("action")=="wait" and Planner.military_reserve(game,2)==25,"Bereites überlegenes Heer spart fünfundzwanzig Gold für Sturm statt unnötig erneut aufzurüsten")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
