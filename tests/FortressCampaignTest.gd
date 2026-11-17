extends Node
## Kontrollierte echte Game-Einstiegspunkte auf 108 Regionen, keine normale
## Budgetkampagne. Keine Graphabkürzungen; Testkasse/Truppen ausdrücklich gesetzt.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
const NEAR := "gallien__03"
var checks := 0
var failures := 0

func _ready() -> void:
	var game = fixture()
	for entry in [["attack",2],["relieve",2],["recover_army",2],["siege_preview",2],["disband_preview",2],["disband_army",3]]:
		check(has_api(game,str(entry[0]),int(entry[1])),"Tatsächlicher Game-Vertrag vorhanden: "+str(entry[0]))
	_test_no_national_and_shared_month()
	_test_siege_mutation()
	_test_resolved_defeat()
	_test_success_real_retreat_and_surrender()
	_test_actual_sea_retreat()
	if has_api(game,"relieve",2): _test_relief()
	if has_api(game,"recover_army",2): _test_recovery()
	if has_api(game,"disband_army",3): _test_disband()
	if has_api(game,"attack",2) and has_api(game,"recover_army",2): _test_actor_context()
	print("FORTRESSCAMPAIGNTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func army(id: int, at: String, strength: int, morale: int = 100) -> Dictionary:
	return {"id":id,"province":at,"strength":strength,"morale":morale,"upkeep":maxi(1,strength/250)}

func fixture(player: int = 2):
	var game = Game.new(Data,player)
	for hi in game.houses.size():
		game.houses[hi].ruler.martial = 0
		game.houses[hi].doctrine = "balanced"
		game.houses[hi].research.known = []
		game.houses[hi].legacies.war = 0
		game.houses[hi].armies = []
		game.houses[hi].fleets = []
	for p in game.provinces:
		if int(p.owner)==2: p.levy=0
	game.houses[2].gold = 1000
	game.houses[2].armies = [army(7,NEAR,500)]
	game.province(NEAR).owner = 2
	game.province(NEAR).levy = 0
	game.province(NEAR).terrain_supply = 6
	game._add_claim(2,TARGET)
	var p: Dictionary = game.province(TARGET)
	p.owner = 1
	p.levy = 50
	p.dev = 6
	p.defense = 0
	p.terrain_defense = 0
	p.terrain_supply = 6
	game.attack_roll_override = 1.0
	return game

func _test_no_national_and_shared_month() -> void:
	var game = fixture()
	for p in game.provinces:
		if int(p.owner)==2: p.levy=100000
	game.army_for().province = HOME
	var before: Dictionary = game.snapshot()
	seed(197)
	var expected := randf()
	seed(197)
	var result: Dictionary = game.attack(TARGET)
	check(not result.ok and game.snapshot()==before and randf()==expected,"Nationales Aufgebot erlaubt keinen Fernsturm aus London und keine Mutation")
	game = fixture()
	check(game.march_army(TARGET).ok,"Echter Marsch verbraucht die monatliche Feldarmeeaktion")
	before = game.snapshot()
	result = game.attack(TARGET)
	check(not result.ok and game.snapshot()==before,"Sturm nach Marsch erhält keine nationale Ersatzaktion")
	game = fixture()
	game.houses[2].armies.clear()
	before = game.snapshot()
	check(not game.attack(TARGET).ok and game.snapshot()==before,"Ohne ausgewählte Feldarmee gibt es keinen abstrakten Aufgebotsangriff")

func _test_siege_mutation() -> void:
	var game = fixture()
	game.province(TARGET).defense = 100
	# 500 Mann, Martial0, volle Versorgung: (20+8)/2 =14 Punkte.
	if has_api(game,"siege_preview",2):
		var preview: Dictionary = game.siege_preview(TARGET,2)
		check(preview.get("ok",false) and preview.get("progress")==14,"Game-Vorschau meldet literal 14 Festungspunkte statt ungebremsten 28")
	var result: Dictionary = game.advance_siege(TARGET)
	check(result.ok and int(game.province(TARGET).siege)==14 and int(game.province(TARGET).siege_owner)==2,"Tatsächlicher Festungsschritt verwendet dieselbe Mauer-/Versorgungsvorschau")
	game = fixture()
	game.army_for().strength = 1
	game.province(TARGET).levy = 10000
	var before: Dictionary = game.snapshot()
	check(not game.advance_siege(TARGET).ok and game.snapshot()==before,"Ein-Mann-Heer kann starke echte Garnison nicht herunterklicken")
	game = fixture()
	game.houses[1].armies = [army(3,TARGET,100)]
	before = game.snapshot()
	check(not game.advance_siege(TARGET).ok and game.snapshot()==before,"Tatsächlicher verteidigender Feldverband blockiert den Festungsschritt")

func _test_resolved_defeat() -> void:
	var game = fixture()
	game.army_for().strength = 100
	game.province(TARGET).levy = 10000
	var result: Dictionary = game.attack(TARGET)
	check(result.ok and result.get("won")==false,"Aufgelöste Sturmniederlage ist eine erfolgreiche mutierende Antwort mit won=false")
	check(int(game.house().gold)==975 and int(game.army_for().strength)==80 and int(game.army_for().morale)==80,"Niederlage bezahlt genau25 Gold,20 Soldaten und20 Moral")
	check(str(game.army_for().province)==NEAR and int(game.province(TARGET).owner)==1,"Verlierer im eigenen echten Ausgangsland bleibt dort; kein Teleport ins Sturmziel")
	check(int(game.province(TARGET).levy)>=9990 and int(game.province(TARGET).levy)<=10000,"Schwacher Sturm schädigt starke Garnison höchstens anteilig statt pauschal15 Prozent")
	check(int(game.army_for().get("last_siege_month",-1))==game._now(),"Aufgelöste Niederlage verbraucht die echte Monatsaktion")
	var saved: Dictionary = game.snapshot()
	var restored = Game.new(Data,2)
	check(restored.restore(saved) and int(restored.snapshot().schema_version)==Save.CURRENT_VERSION,"Dynamisches aktuelles Schema lädt den wirklichen Gefechtsstand")
	var before: Dictionary = restored.snapshot()
	check(not restored.attack(TARGET).ok and restored.snapshot()==before,"Speichern/Laden erneuert weder Sturm noch militärische Monatsaktion")
	game = fixture()
	game.army_for().strength = 1
	game.province(TARGET).levy = 10000
	result = game.attack(TARGET)
	check(result.ok and result.get("won")==false and game.house().armies.is_empty(),"Positiver Mindestverlust entfernt wirklich besiegtes Ein-Mann-Heer")
	check(int(game.province(TARGET).levy)==10000,"Besiegter einzelner Soldat vernichtet keine große Garnisonsquote")

func _test_success_real_retreat_and_surrender() -> void:
	for escape in [true,false]:
		var game = fixture()
		game.army_for().province = TARGET
		game.army_for().strength = 1000
		game.houses[1].armies = [army(2,TARGET,60),army(5,TARGET,40)]
		game.province(NEAR).owner = 1 if escape else 2
		game.province("gallien__05").owner = 0
		game.province("germanien__02").owner = 0
		var other := army(9,"anatolien__01",777)
		game.houses[3].armies = [other.duplicate(true)]
		var prestige: int = game.house().prestige
		var result: Dictionary = game.attack(TARGET)
		check(result.ok and result.get("won")==true and int(game.province(TARGET).owner)==2,"Siegreicher tatsächlicher Sturm überträgt genau einmal Besitz")
		check(int(game.house().gold)==975 and int(game.house().prestige)==prestige+15 and int(game.province(TARGET).levy)==30 and int(game.province(TARGET).dev)==5,"Sturmsieg bezahlt25, gibt15 Prestige und wendet60-Prozent-/Entwicklungsschaden einmal an")
		check(int(game.army_for().strength)==900 and int(game.army_for().get("last_siege_month",-1))==game._now(),"Gewinner erleidet zehn Prozent und verbraucht seine Monatsaktion")
		if escape:
			check(game.houses[1].armies.size()==2 and int(game.houses[1].armies[0].strength)==36 and int(game.houses[1].armies[1].strength)==24,"Verlierergruppe verliert40 Prozent gemeinsam und proportional")
			check(str(game.houses[1].armies[0].province)==NEAR and str(game.houses[1].armies[1].province)==NEAR,"Beide echten Überlebenden treten in unmittelbar eigenes Land zurück")
		else:
			check(game.houses[1].armies.is_empty(),"Eingeschlossene Überlebende ohne echte Flucht werden entfernt statt zur Hauptstadt versetzt")
		check(game.houses[3].armies==[other],"Unbeteiligter fremder Verband bleibt vollständig erhalten")

func _test_actual_sea_retreat() -> void:
	for escort in [true,false]:
		var game = fixture()
		game.army_for().province = TARGET
		game.army_for().strength = 100
		game.province(TARGET).levy = 10000
		game.province(NEAR).owner = 1
		game.province(TARGET).blockade = 2
		game.province(TARGET).blockade_owner = 2
		if escort:
			game.houses[2].fleets = [{"id":6,"province":HOME,"station":TARGET,"ships":1,"morale":20,"upkeep":1,"last_naval_month":game._now()}]
		var result: Dictionary = game.attack(TARGET)
		check(result.ok and result.get("won")==false,"Tatsächlicher überseeischer Verlust wird als aufgelöster Kampf gemeldet")
		if escort:
			check(str(game.army_for().get("province",""))==HOME and int(game.army_for().get("strength",0))==80,"Überseeischer Verlierer nutzt tatsächliche ausreichende Flotte nach London")
			check(str(game.fleet_for().get("province",""))==HOME and str(game.fleet_for().get("station",""))==HOME and int(game.fleet_for().get("last_naval_month",-1))==game._now(),"Geleit zieht real mit und erhält trotz erzwungener Nutzung dieselbe Monatswache")
			check(int(game.province(TARGET).blockade)==0 and int(game.province(TARGET).blockade_owner)==-1,"Erzwungener Abzug löst die eigene aktive Geleitblockade auf")
		else:
			check(game.house().armies.is_empty(),"Ohne eigene Landnachbarn oder tatsächliches Geleit wird das Restheer aufgegeben")

func _test_relief() -> void:
	for win in [true,false]:
		var game = fixture()
		game.province(TARGET).owner = 2
		game.province(TARGET).siege = 40
		game.province(TARGET).siege_owner = 1
		game.houses[2].claims.clear()
		game.houses[2].gold = 0
		game.army_for().strength = 1000 if win else 10
		game.houses[1].armies = [army(2,TARGET,100)]
		game.province("gallien__05").owner = 1
		var result: Dictionary = game.relieve(TARGET,2)
		check(result.ok and result.get("won")==win and int(game.province(TARGET).owner)==2 and int(game.house().gold)==0,"Entsatz ist tatsächlicher kostenloser Kampf ohne Besitzwechsel oder Anspruch")
		check(int(game.army_for().get("last_siege_month",-1))==game._now(),"Gewonnener und verlorener Entsatz teilen dieselbe Armeemonatsaktion")
		if win:
			check(str(game.army_for().province)==TARGET and int(game.province(TARGET).siege)==0 and int(game.province(TARGET).siege_owner)==-1,"Siegreiches eigenes Heer rückt ein und beendet nicht mehr gestützte Belagerung")
			check(str(game.houses[1].armies[0].province)=="gallien__05" and int(game.houses[1].armies[0].strength)==60,"Tatsächliches Besiegerheer erleidet40 Prozent und zieht zu eigenem Nachbarn ab")
		else:
			check(int(game.province(TARGET).siege)==40 and int(game.province(TARGET).siege_owner)==1,"Verlorener Entsatz löscht keine weiterhin unterstützte Belagerung")

func recovery_fixture(player: int = 2):
	var game = fixture(player)
	game.houses[2].gold = 20
	game.houses[2].armies = [army(7,HOME,490,40)]
	game.province(HOME).levy = 250
	return game

func _test_recovery() -> void:
	var game = recovery_fixture()
	var total := int(game.army_for().strength)+int(game.province(HOME).levy)
	check(game.recover_army(HOME,2).ok,"Realer eigener Feldlagerbefehl wird ausgeführt")
	check(int(game.house().gold)==5 and int(game.army_for().strength)==590 and int(game.army_for().morale)==60 and int(game.army_for().upkeep)==2,"100 Rekruten kosten15 Gold, geben20 Moral und echten neuen Jahresunterhalt")
	check(int(game.province(HOME).levy)==150 and int(game.army_for().strength)+int(game.province(HOME).levy)==total,"Übernommene Soldaten werden genau aus örtlichem Aufgebot übertragen")
	var before: Dictionary = game.snapshot()
	check(not game.recover_army(HOME,2).ok and game.snapshot()==before,"Wiederholtes Auffüllen im selben Monat kostet nichts und dupliziert keine Soldaten")
	var restored = Game.new(Data,2)
	check(restored.restore(before),"Tatsächlich aufgefülltes Heer lässt sich speichern und laden")
	var loaded: Dictionary = restored.snapshot()
	check(not restored.recover_army(HOME,2).ok and restored.snapshot()==loaded,"Laden erneuert die verbrauchte Erholungsaktion nicht")
	game = recovery_fixture()
	game.houses[2].gold = 5
	check(game.recover_army(HOME,2).ok and int(game.army_for().strength)==490 and int(game.army_for().morale)==60 and int(game.house().gold)==0 and int(game.province(HOME).levy)==250,"Reine Moralpflege bezahlt5 Gold ohne fiktive Rekruten")
	game = recovery_fixture()
	game.army_for().morale = 0
	check(game.recover_army(HOME,2).ok and int(game.army_for().morale)==20,"Lebendes demoralisiertes Heer kann tatsächlich im eigenen Feldlager genesen")
	game = recovery_fixture()
	game.province(HOME).blockade = 2
	game.province(HOME).blockade_owner = 1
	before = game.snapshot()
	check(not game.recover_army(HOME,2).ok and game.snapshot()==before,"Feindliche Blockade verhindert Feldlager ohne Abbuchung")

func _test_disband() -> void:
	var game = recovery_fixture()
	game.houses[2].armies.append(army(9,HOME,300))
	var before: Dictionary = game.snapshot()
	check(not game.disband_army(HOME,99,2).ok and game.snapshot()==before,"Falsche Auflösungs-ID ist rein und kann keinen anderen Verband löschen")
	game.army_for().last_siege_month = game._now()
	before = game.snapshot()
	check(not game.disband_army(HOME,7,2).ok and game.snapshot()==before,"Benutzte Armee darf nicht zum Zurücksetzen der Monatswache aufgelöst werden")
	game.army_for().erase("last_siege_month")
	var gold: int = game.house().gold
	var levy: int = game.province(HOME).levy
	var retained: Dictionary = game.house().armies[1].duplicate(true)
	check(game.disband_army(HOME,7,2).ok and game.house().armies==[retained],"Auflösen entfernt genau die ausgewählte tatsächliche Armee")
	check(int(game.house().gold)==gold and int(game.province(HOME).levy)==levy,"Auflösen erstattet weder Gold noch abstrakte Provinzsoldaten")

func _test_actor_context() -> void:
	var game = recovery_fixture(0)
	check(game.configure_human_houses([0,2]),"Echter zweiter menschlicher Sitz für Akteurprüfung")
	var other: Dictionary = game.houses[0].duplicate(true)
	check(game.recover_army(HOME,2).ok and game.player==0 and game.houses[0]==other and int(game.houses[2].gold)==5,"Expliziter Recovery-Akteur belastet nur den richtigen Sitz ohne Perspektivleck")
	game = fixture(0)
	check(game.configure_human_houses([0,2]),"LAN-Perspektiven für expliziten Sturm-Akteur vorhanden")
	game.set_opinion_value(0,1,80)
	game.set_opinion_value(2,1,0)
	game.army_for(2).strength = 1000
	other = game.houses[0].duplicate(true)
	# Vor dem neuen Vertrag besitzt attack nur einen Parameter. Die separate
	# Vertragsprüfung meldet das rot; callv vermeidet einen Parserabbruch.
	var result: Dictionary = game.callv("attack",[TARGET,2])
	check(result.ok and result.get("won")==true and int(game.province(TARGET).owner)==2 and game.player==0 and game.houses[0]==other,"Sturm nutzt eigenen Akteur/Kontext statt aktuellem Spieler oder dessen fremder Beziehung")

func has_api(game, name: String, arguments: int) -> bool:
	for method in game.get_script().get_script_method_list():
		if str(method.name)==name: return method.args.size()>=arguments
	return false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FORTRESSCAMPAIGNTEST FAIL: "+message)
