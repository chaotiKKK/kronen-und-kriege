extends Node
## Kontrollierte Regeln auf echter 108er-Geometrie, kein Budgetkampagnenbeleg.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
const NEAR := "gallien__03"
var Rules
var checks := 0
var failures := 0

func _ready() -> void:
	check(FileAccess.file_exists("res://scripts/FieldBattleRules.gd"),"Reiner Feldkampf-Regelkern vorhanden")
	if not FileAccess.file_exists("res://scripts/FieldBattleRules.gd"):
		finish()
		return
	Rules = load("res://scripts/FieldBattleRules.gd")
	_test_literal_chances_and_purity()
	_test_assault_guards()
	_test_local_defenders_and_bonuses()
	_test_relief()
	_test_losses()
	_test_retreat()
	finish()

func army(id: int, at: String, strength: int, morale: int = 100) -> Dictionary:
	return {"id":id,"province":at,"strength":strength,"morale":morale,"upkeep":1}

func fixture():
	var game = Game.new(Data,2)
	game.houses[2].gold = 1000
	for hi in game.houses.size():
		game.houses[hi].ruler.martial = 0
		game.houses[hi].doctrine = "balanced"
		game.houses[hi].research.known = []
		game.houses[hi].legacies.war = 0
		game.houses[hi].armies = []
	game.houses[2].armies = [army(10,TARGET,100)]
	game._add_claim(2,TARGET)
	var p: Dictionary = game.province(TARGET)
	p.owner = 1
	p.levy = 50
	p.dev = 12
	p.defense = 0
	p.terrain_defense = 0
	return game

func _test_literal_chances_and_purity() -> void:
	var game = fixture()
	var before: Dictionary = game.snapshot()
	seed(731)
	var expected := randf()
	seed(731)
	var p: Dictionary = Rules.assault_preview(game,TARGET,2)
	check(p.get("ok",false) and p.get("kind")=="assault" and p.get("cost")==25,"Bereiter tatsächlicher Sturm erhält Preis und Aktionsart")
	check(p.get("army_id")==10 and p.get("origin")==TARGET and p.get("target")==TARGET and p.get("attacker_house")==2 and p.get("defender_house")==1,"Vorschau bindet echte Armee, Ort und Hausbesitzer")
	check(near(p.get("attack_power",-1),100) and near(p.get("defense",-1),100) and near(p.get("chance",-1),0.5),"100 Angriff gegen 100 Verteidigung ergibt exakt 50 Prozent")
	check(p.get("field_army_strength")==100 and p.get("garrison")==50 and p.get("defender_army_ids")==[] and p.get("defender_strength")==0,"Garnison und Feldverbände werden getrennt berichtet")
	check(game.snapshot()==before and randf()==expected,"Sturmvorschau verändert weder Welt noch RNG")
	game.army_for().strength = 80
	check(near(Rules.assault_preview(game,TARGET,2).get("chance",-1),0),"80 gegen 100 ergibt echte null Prozent")
	game.army_for().strength = 120
	check(near(Rules.assault_preview(game,TARGET,2).get("chance",-1),1),"120 gegen 100 ergibt echte hundert Prozent")
	game.army_for().strength = 100
	game.province(TARGET).blockade = 2
	game.province(TARGET).blockade_owner = 2
	p = Rules.assault_preview(game,TARGET,2)
	check(near(p.get("naval_bonus",-1),1.25) and near(p.get("chance",-1),1),"Eigene aktive Blockade wirkt einmal mit Faktor 1,25")
	game.province(TARGET).blockade_owner = 3
	check(near(Rules.assault_preview(game,TARGET,2).get("naval_bonus",-1),1),"Fremde Blockade ist kein eigener Sturmbonus")

func _test_assault_guards() -> void:
	var game = fixture()
	game.army_for().province = HOME
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"London darf Brüssel nicht durch grobe Reichsreichweite stürmen")
	game.army_for().province = NEAR
	check(Rules.assault_preview(game,TARGET,2).get("ok",false),"Echter direkter Landnachbar darf stürmen")
	game.army_for().last_siege_month = game._now()
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Verbrauchte Marsch-/Landungsaktion liefert keine nationale Ersatzkraft")
	game.army_for().last_siege_month = -1
	game.houses[2].claims[0].expires = game._now()-1
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Abgelaufener Anspruch sperrt Sturm")
	game.houses[2].claims[0].expires = game._now()
	check(Rules.assault_preview(game,TARGET,2).get("ok",false),"Ablaufmonat bleibt einschließlich gültig")
	game.houses[2].truces["1"] = game._now()+1
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Aktiver Waffenstillstand sperrt Sturm")
	game.houses[2].truces["1"] = game._now()
	game.opinion[1] = 60
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Gute Beziehung sperrt Sturm")
	game.opinion[1] = 0
	game.houses[2].gold = 24
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Fehlendes echtes Sturmgold wird nicht umgangen")
	game.houses[2].gold = 25
	check(Rules.assault_preview(game,TARGET,2).get("ok",false),"Genau 25 Gold genügen ohne Vorschauabzug")
	game.army_for().morale = 0
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Demoralisiertes Heer stürmt nicht")
	game.army_for().morale = 100
	game.province(TARGET).owner = 2
	check(not Rules.assault_preview(game,TARGET,2).get("ok",true),"Eigenes Land benötigt gegebenenfalls Entsatz statt Sturm")
	check(not Rules.assault_preview(game,TARGET,-1).get("ok",true) and not Rules.assault_preview(game,TARGET,999).get("ok",true),"Ungültige Akteure dürfen keine fremde Partei behaupten")
	check(not Rules.assault_preview(game,"missing",2).get("ok",true),"Unbekanntes Ziel ist rein gesperrt")
	check(not Rules.assault_preview(game,TARGET,1).get("ok",true),"Fehlende eigene Feldarmee wird nicht durch fremden Verband ersetzt")

func _test_local_defenders_and_bonuses() -> void:
	var game = fixture()
	for p in game.provinces:
		if int(p.owner)==2: p.levy=100000
	check(near(Rules.assault_preview(game,TARGET,2).get("attack_power",-1),100),"Nationale Provinzaufgebote ersetzen keine stationierte Feldarmee")
	game.houses[1].armies = [army(9,NEAR,500),army(7,TARGET,100),army(3,TARGET,0),army(5,TARGET,100,0)]
	var p: Dictionary = Rules.assault_preview(game,TARGET,2)
	check(p.get("defender_army_ids")==[7] and p.get("defender_strength")==100 and near(p.get("defense",-1),200),"Nur kampffähige tatsächlich im Ziel stehende Besitzerheere zählen")
	game.houses[1].armies[1].morale = 50
	game.province(TARGET).defense = 100
	game.province(TARGET).terrain_defense = 25
	p = Rules.assault_preview(game,TARGET,2)
	check(near(p.get("defense",-1),275),"Garnison erhält 225 Festungsverteidigung; 50 effektive Feldsoldaten keine doppelten Mauern")
	game = fixture()
	game.army_for().strength = 101
	game.army_for().morale = 50
	game.houses[2].ruler.martial = 20
	game.houses[2].legacies.war = 1
	game.houses[2].doctrine = "cavalry"
	game.houses[2].research.known = ["military_staff"]
	p = Rules.assault_preview(game,TARGET,2)
	check(p.get("field_army_strength")==50 and near(p.get("attack_power",-1),127.05),"Effektive Soldaten werden vor Herrscher/Vermächtnis/Doktrin/Forschung abgerundet")
	game.houses[1].ruler.martial = 25
	game.houses[1].doctrine = "infantry"
	game.houses[1].research.known = ["fortification"]
	game.houses[1].armies = [army(7,TARGET,100,50)]
	p = Rules.assault_preview(game,TARGET,2)
	check(near(p.get("defense",-1),355.8),"Garnison 237 plus 118,8 Feldverteidigung nutzt echte Besitzerboni genau einmal")

func _test_relief() -> void:
	var game = fixture()
	game.province(TARGET).owner = 2
	game.army_for().strength = 75
	game.houses[2].gold = 0
	game.houses[2].claims.clear()
	game.houses[1].armies = [army(7,TARGET,100)]
	var p: Dictionary = Rules.relief_preview(game,TARGET,2)
	check(p.get("ok",false) and p.get("cost")==0 and p.get("kind")=="relief","Eigener echter Entsatz braucht weder Gold noch fremden Anspruch")
	check(near(p.get("attack_power",-1),100) and near(p.get("defense",-1),100) and near(p.get("chance",-1),0.5),"75 Soldaten plus 25 Garnisonsausfall ergeben 50 Prozent gegen 100")
	game.army_for().strength = 50
	game.province(TARGET).defense = 100
	p = Rules.relief_preview(game,TARGET,2)
	check(near(p.get("attack_power",-1),100) and near(p.get("defense",-1),100),"Eigene Mauern verstärken nur den Ausfallbonus, niemals den draußen stehenden Feind")
	game.army_for().strength = 75
	game.province(TARGET).defense = 0
	var before: Dictionary = game.snapshot()
	seed(19)
	var expected := randf()
	seed(19)
	Rules.relief_preview(game,TARGET,2)
	check(game.snapshot()==before and randf()==expected,"Entsatzvorschau verändert weder Welt noch RNG")
	game.houses[3].armies = [army(9,TARGET,500)]
	game.province(TARGET).siege = 20
	game.province(TARGET).siege_owner = 1
	check(Rules.relief_preview(game,TARGET,2).get("defender_house")==1,"Tatsächlicher Besieger hat Vorrang vor einer stärkeren unbeteiligten Feindgruppe")
	game.province(TARGET).siege_owner = 4
	check(Rules.relief_preview(game,TARGET,2).get("defender_house")==3,"Ohne tatsächlichen Besieger wird die stärkste zulässige feindliche Gruppe gewählt")
	game.houses[3].armies[0].strength = 100
	check(Rules.relief_preview(game,TARGET,2).get("defender_house")==1,"Gleiche gegnerische Stärke entscheidet nach Haus-ID")
	game.province(TARGET).siege_owner = 1
	game.houses[2].truces["1"] = game._now()+1
	check(Rules.relief_preview(game,TARGET,2).get("defender_house")==3,"Geschützte Gruppe wird nicht als Entsatzgegner ausgewählt")
	game.opinion[3] = 60
	check(not Rules.relief_preview(game,TARGET,2).get("ok",true),"Nur geschützte fremde Gruppen erlauben keinen grundlosen Entsatzkampf")
	game.houses[2].truces.clear()
	game.opinion[3] = 0
	game.army_for().last_siege_month = game._now()
	check(not Rules.relief_preview(game,TARGET,2).get("ok",true),"Entsatz teilt die vorhandene Armeemonatswache")
	game.army_for().last_siege_month = -1
	game.army_for().province = HOME
	check(not Rules.relief_preview(game,TARGET,2).get("ok",true),"Entsatz wird nicht aus London nach Brüssel erfunden")
	game.army_for().province = TARGET
	game.houses[1].armies.clear()
	game.houses[3].armies.clear()
	check(not Rules.relief_preview(game,TARGET,2).get("ok",true),"Bloßer Belagerungsindex ohne tatsächlichen Feindverband reicht nicht")

func _test_losses() -> void:
	var inputs := [army(7,TARGET,3),army(5,TARGET,1),army(2,TARGET,1)]
	var before: Array = inputs.duplicate(true)
	var plan: Array = Rules.loss_plan(inputs,0.4)
	check(plan==[{"id":2,"before":1,"loss":1,"remaining":0},{"id":5,"before":1,"loss":0,"remaining":1},{"id":7,"before":3,"loss":1,"remaining":2}],"Zwei Verluste auf 3/1/1 werden mit größten Resten und stabilen IDs verteilt")
	inputs.reverse()
	check(Rules.loss_plan(inputs,0.4)==plan,"Verlustplan ist unabhängig von Listenreihenfolge")
	check(inputs==[before[2],before[1],before[0]],"Verlustplan verändert keine Eingabeverbände")
	check(Rules.loss_plan([army(1,TARGET,1)],1.0,true)==[{"id":1,"before":1,"loss":0,"remaining":1}],"Siegergruppe behält mindestens einen Soldaten")
	check(Rules.loss_plan([army(1,TARGET,1)],1.0,false)==[{"id":1,"before":1,"loss":1,"remaining":0}],"Verlierer dürfen vollständig aufgerieben werden")
	check(Rules.loss_plan([army(1,TARGET,5)],0.1)==[{"id":1,"before":5,"loss":1,"remaining":4}],"Gruppenverlust rundet eine halbe Einheit deterministisch auf")
	check(Rules.loss_plan([army(1,TARGET,5)],-1.0)==[{"id":1,"before":5,"loss":0,"remaining":5}],"Negative Bruchteile erzeugen keine Truppen")
	check(Rules.loss_plan([army(1,TARGET,5)],2.0)==[{"id":1,"before":5,"loss":5,"remaining":0}],"Verlustbudget überschreitet nie vorhandene Stärke")
	check(Rules.loss_plan([army(1,TARGET,1)],0.2)==[{"id":1,"before":1,"loss":1,"remaining":0}],"Positiver Gruppenverlust reibt ein besiegtes Ein-Mann-Heer wirklich auf")
	check(Rules.loss_plan([army(1,TARGET,2)],0.1,true)==[{"id":1,"before":2,"loss":1,"remaining":1}],"Positiver Mindestverlust bewahrt zugleich den einen Gewinner-Soldaten")
	check(Rules.loss_plan([army(1,TARGET,1)],0.0)==[{"id":1,"before":1,"loss":0,"remaining":1}],"Explizite Nullrate erzeugt keinen künstlichen Mindestverlust")
	check(Rules.loss_plan([army(2,TARGET,1),army(1,TARGET,1)],1.0,true)==[{"id":1,"before":1,"loss":1,"remaining":0},{"id":2,"before":1,"loss":0,"remaining":1}],"Siegerminimum gilt gruppenweit und wird durch Fragmentierung nicht vervielfacht")
	var split: Array = []
	for id in 10: split.append(army(id+1,TARGET,1))
	var split_losses := 0
	for row in Rules.loss_plan(split,0.1): split_losses+=int(row.loss)
	check(split_losses==1,"Zehn Einzelverbände tragen dasselbe eine Verlustbudget wie zehn Soldaten zusammen")
	check(Rules.loss_plan([army(1,TARGET,5)],NAN)==[],"Nichtendliche Verlustrate wird sicher abgewiesen")
	check(Rules.loss_plan([],0.4)==[] and Rules.loss_plan([army(1,TARGET,3),army(1,TARGET,2)],0.4)==[],"Leere oder mehrdeutige Gruppen erzeugen keinen unsicheren Verlustplan")
	if not plan.is_empty():
		plan[0].remaining = 900
		check(int(inputs[0].strength)==1,"Ergebnis enthält nur Zahlen, keine veränderlichen Weltreferenzen")

func _test_retreat() -> void:
	var game = fixture()
	game.houses[2].armies = [army(1,TARGET,300),army(3,TARGET,100)]
	for unit in game.houses[2].armies: unit.last_siege_month=game._now()
	var survivors := [army(1,TARGET,150),army(3,TARGET,50)]
	game.houses[2].fleets = [{"id":6,"province":HOME,"station":TARGET,"ships":2,"morale":20,"last_naval_month":game._now(),"upkeep":1}]
	game.province(TARGET).blockade = 2
	game.province(TARGET).blockade_owner = 2
	var before: Dictionary = game.snapshot()
	var p: Dictionary = Rules.retreat_plan(game,2,TARGET,survivors)
	check(p.get("kind")=="sea" and p.get("from")==TARGET and p.get("to")==HOME and p.get("fleet_id")==6 and p.get("cancel_blockade")==true,"Forced Retreat nutzt tatsächliche Blockadestation, reale Route und genau 200 verbleibende Soldaten")
	check(game.snapshot()==before,"Rückzugsplan beendet keine Blockade und bewegt keine Weltobjekte")
	check(Rules.retreat_plan(game,2,TARGET,[army(999,TARGET,1)]).get("kind")=="surrender","Unbekannte Truppen-ID kann trotz verfügbarem echtem Seeweg keine eigene Partei vortäuschen")
	game.houses[2].armies[0].province = HOME
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="surrender","Kopien dürfen trotz verfügbarem Geleit keinen tatsächlich anderen Armeeort behaupten")
	game.houses[2].armies[0].province = TARGET
	game.fleet_for().ships = 10
	check(Rules.retreat_plan(game,2,TARGET,[army(1,TARGET,301)]).get("kind")=="surrender","Reine Kopie darf bei ausreichender Flotte keine zusätzlichen Soldaten erfinden")
	game.fleet_for().ships = 2
	game.houses[2].fleets.append({"id":1,"province":HOME,"station":TARGET,"ships":3,"morale":100,"last_naval_month":game._now()})
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("fleet_id")==1,"Mehrere geeignete reale Legacy-Flotten entscheiden nach stabiler ID")
	game.houses[2].fleets.pop_back()
	survivors[0].strength = 151
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="surrender","Zu wenig Kapazität erzeugt keine Teilevakuierung")
	survivors[0].strength = 150
	game.fleet_for().morale = 19
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="surrender","Auch erzwungene Überfahrt braucht ausreichende reale Geleitmoral")
	game.fleet_for().morale = 20
	game.fleet_for().station = HOME
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="surrender","Geburtshafen ersetzt keine Flotte am Kampfplatz")
	game.fleet_for().station = TARGET
	game.province(HOME).blockade = 2
	game.province(HOME).blockade_owner = 1
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="surrender","Feindlich gesperrter Zielhafen ist kein sicherer Seerückzug")
	game.province(HOME).blockade = 0
	game.province(NEAR).owner = 2
	game.province("gallien__05").owner = 2
	p = Rules.retreat_plan(game,2,TARGET,survivors)
	check(p.get("kind")=="land" and p.get("to")==NEAR and p.get("fleet_id")==-1 and p.get("cancel_blockade")==false,"Freier echter eigener Landnachbar hat vor See Vorrang und stabile ID")
	game.houses[1].armies = [army(8,NEAR,100)]
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("to")=="gallien__05","Tatsächliche fremde Feldarmee sperrt einen Rückzugsort")
	game.province("gallien__05").owner = 1
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="sea","Nach blockiertem Landweg bleibt nur der echte Seeweg")
	game.houses[2].fleets.clear()
	check(Rules.retreat_plan(game,2,TARGET,survivors).get("kind")=="surrender","Ohne echten Ausweg kein Teleport zur Hauptstadt")

func near(value, expected: float) -> bool:
	return is_equal_approx(float(value),expected)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FIELDBATTLERULESTEST FAIL: "+message)

func finish() -> void:
	print("FIELDBATTLERULESTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
