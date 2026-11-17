extends Node
## Reale 108-Regionen-Welt, ausdrücklich kontrollierte Zahlen/Legacy-Verbände.
## Kein Kampagnenbudgetbeleg, keine Main, keine Textur und kein Zufall im Reader.
const Game = preload("res://scripts/Game.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const HOME := "gallien__03"
const TARGET := "gallien__04"
const FIELDS := ["ok","reason","current","next","progress","remaining_actions","army_id","origin","strength","effective_strength","required_strength","garrison","defender_strength","fort_bonus","wall_level","coverage","supply","blockade_factor","doctrine_bonus","research_bonus"]
var Rules
var checks := 0
var failures := 0

func _ready() -> void:
	if not check(FileAccess.file_exists("res://scripts/SiegeRules.gd"),"Reines Festungsregelmodul fehlt vor der Implementierung"):
		finish()
		return
	Rules = load("res://scripts/SiegeRules.gd")
	if not check(Rules!=null and Rules.can_instantiate(),"Festungsregelmodul ist als tatsächliches GDScript ladbar"):
		finish()
		return
	_test_literals()
	_test_supply()
	_test_guards()
	_test_occupants()
	_test_progress_owner()
	_test_house_and_legacy()
	finish()

func fixture(hi: int = 2, owner: int = 1):
	var game = Game.new(Regions,2)
	game.houses[hi].doctrine = "balanced"
	game.houses[hi].ruler.martial = 12
	game.houses[hi].research.known = []
	game.houses[owner].research.known = []
	game.houses[owner].armies = []
	game.houses[hi].armies = [{"id":7,"province":TARGET,"strength":600,"morale":100,"upkeep":2,"last_siege_month":0}]
	game.houses[hi].claims = [{"province":TARGET,"strength":1,"expires":game._now()+24}]
	game.houses[hi].truces = {}
	game.opinion.fill(0)
	var target: Dictionary = game.province(TARGET)
	target.owner = owner
	target.levy = 400
	target.defense = 0
	target.terrain_defense = 0
	target.terrain_supply = 6
	target.economic_focus = "balanced"
	target.buildings.walls = 0
	target.siege = 0
	target.siege_owner = -1
	target.blockade = 0
	target.blockade_owner = -1
	game.roads = []
	return game

func preview(game, target: String = TARGET, hi: int = 2) -> Dictionary:
	var before: Dictionary = game.snapshot()
	check(not before.is_empty(),"Kontrollierte Testwelt ergibt einen tatsächlich gültigen Snapshot")
	var contexts: Dictionary = game._player_contexts.duplicate(true)
	var raw := {"houses":game.houses.duplicate(true),"provinces":game.provinces.duplicate(true),"roads":game.roads.duplicate(true),"effects":game.effect_log.duplicate(true)}
	seed(58173)
	var expected_rng := randf()
	seed(58173)
	var out: Dictionary = Rules.preview(game,target,hi)
	var next_rng := randf()
	check(game.snapshot()==before and game._player_contexts==contexts and game.houses==raw.houses and game.provinces==raw.provinces and game.roads==raw.roads and game.effect_log==raw.effects,"Vorschau ist welt-, history-, effekt- und kontextrein, auch außerhalb der gespeicherten Felder")
	check(next_rng==expected_rng,"Vorschau verbraucht keinen echten RNG-Wert")
	return out

func _test_literals() -> void:
	var game = fixture()
	check(game.provinces.size()==108 and game.neighbours(HOME).has(TARGET),"Zahlenfälle benutzen tatsächliche 108er-IDs mit echter Landkante")
	var out := preview(game)
	for field in FIELDS: check(out.has(field),"Öffentliches Vorschaufeld vorhanden: "+field)
	check(out.ok and str(out.reason).is_empty(),"Bereites reales Feldheer darf unverteidigte fremde Festung belagern")
	check(out.army_id==7 and out.origin==TARGET and out.strength==600 and out.effective_strength==600,"Vorschau ist an tatsächlichen ausgewählten Verband und Ort gebunden")
	check(out.garrison==400 and out.required_strength==140 and out.defender_strength==0,"400 Mann Besatzung verlangen140effektive Soldaten")
	check(out.progress==33 and out.current==0 and out.next==33 and out.remaining_actions==4,"600Mann/Martial12 ergeben33Punkte und4Aktionen")
	game.province(TARGET).defense = 100
	game.province(TARGET).buildings.walls = 3
	game.province(TARGET).siege = 30
	game.province(TARGET).siege_owner = 2
	out = preview(game)
	check(out.fort_bonus==100 and out.wall_level==3 and out.required_strength==280,"Gespeicherte100Verteidigung zählt einmal, nicht nochmals plus Mauerstufen")
	check(out.current==30 and out.progress==16 and out.next==46 and out.remaining_actions==5,"Doppelter Festungsfaktor halbiert Grund33 auf16, Rest70 braucht5Aktionen")
	game.province(TARGET).buildings.walls = 0
	check(preview(game).progress==16,"Gleiche tatsächliche Verteidigung ergibt unabhängig vom Mauerlabel denselben Schritt")
	game.province(TARGET).defense = 12
	game.province(TARGET).terrain_defense = 10
	game.houses[1].research.known = ["surveying","masonry","fortification"]
	game.houses[2].research.known = ["surveying","masonry","engineering"]
	game.houses[2].doctrine = "siege"
	out = preview(game)
	check(out.fort_bonus==30 and out.required_strength==182,"Echte Besitzerforschung8 plus12Verteidigung plus10Gelände")
	check(out.doctrine_bonus==8 and out.research_bonus==1 and out.progress==34,"Doktrin8/Forschung1 bleiben zusätzliche Punkte nach floor33/1,3")
	game.houses[2].doctrine = "balanced"
	game.houses[2].research.known = []
	game.houses[1].research.known = []
	game.province(TARGET).defense = 0
	game.province(TARGET).terrain_defense = -5
	out = preview(game)
	check(out.required_strength==133 and out.progress==34,"Negatives echtes Steppe-Geländebonusniveau verwendet Faktor0,95")
	game.province(TARGET).terrain_defense = -80
	out = preview(game)
	check(out.required_strength==70 and out.progress==66,"Kontrollierter negativer Grenzfall unterschreitet Festungsfaktor0,5 nicht")
	game = fixture()
	game.houses[2].armies[0].strength = 601
	game.houses[2].armies[0].morale = 50
	game.province(TARGET).terrain_supply = 20
	out = preview(game)
	check(out.effective_strength==300 and out.progress==28,"601Mann mit50Moral werden vor dem Grundschritt auf300effektiv abgerundet")
	game.houses[2].armies[0].strength = 140
	game.houses[2].armies[0].morale = 100
	check(preview(game).ok and preview(game).progress==25,"Mindestdruck140ist inklusive, Grundschritt20+2+3")
	game.houses[2].armies[0].strength = 139
	game.houses[2].doctrine = "siege"
	game.houses[2].research.known = ["surveying","masonry","engineering"]
	out = preview(game)
	check(not out.ok and out.progress==0 and out.next==out.current and out.remaining_actions==0 and not str(out.reason).is_empty(),"Bonus9umgeht fehlenden Mindestdruck139gegen140nicht")
	game = fixture()
	game.province(TARGET).blockade = 4
	game.province(TARGET).blockade_owner = 2
	out = preview(game)
	check(is_equal_approx(out.blockade_factor,1.15) and out.progress==37,"Eigene aktive Blockade: floor33mal1,15ist37")
	game.province(TARGET).blockade_owner = 4
	check(preview(game).progress==33,"Fremde Blockade schenkt keinen eigenen Belagerungsbonus")
	game.province(TARGET).blockade_owner = 2
	game.province(TARGET).blockade = 0
	check(preview(game).progress==33,"Abgelaufene eigene Blockade gibt keinen Bonus")

func _test_supply() -> void:
	var game = fixture()
	game.province(TARGET).terrain_supply = 3
	var out := preview(game)
	check(is_equal_approx(out.coverage,.5) and out.progress==16,"600Bedarf/300Deckung halbiert33auf16")
	check(out.supply.get("demand")==600 and out.supply.get("shortfall")==300 and out.supply.get("annual_in_months")==12,"Januarvorschau zeigt reale300Fehlbedarf und12Monate bis nächster Januarabrechnung")
	game.houses[2].armies.append({"id":8,"province":TARGET,"strength":600,"morale":100,"upkeep":2})
	out = preview(game)
	check(out.supply.get("demand")==1200 and is_equal_approx(out.coverage,.25) and out.progress==8,"Zwei echte Legacy-Heere teilen Kapazität, kein fiktives600MannEinzelbudget")
	game.province(TARGET).terrain_supply = 0
	check(preview(game).progress==8,"Versorgungsfaktor wird bei fehlender Deckung auf0,25begrenzt")
	game.houses[2].armies.resize(1)
	game.houses[2].armies[0].province = HOME
	game.province(HOME).owner = 2
	game.province(HOME).terrain_supply = 6
	game.province(HOME).economic_focus = "balanced"
	out = preview(game)
	check(out.ok and out.origin==HOME and out.progress==33 and out.supply.get("local_capacity")==600,"Erster benachbarter Belagerungsschritt versorgt tatsächlichen Ausgangsort, nicht das noch unerreichte Ziel")
	out.supply["shortfall"] = 99999
	out.supply["nested_probe"] = {"changed":true}
	check(preview(game).supply.get("shortfall")==0,"Zurückgegebener Versorgungsbericht ist eine unabhängige Kopie")
	game.month = 12
	check(preview(game).supply.get("annual_in_months")==1,"Dezember bedeutet noch eine Monatsschaltung bis Januarabrechnung")

func _test_guards() -> void:
	var game = fixture()
	for id in [-1,999]:
		var bad := preview(game,TARGET,id)
		check(not bad.ok and not str(bad.reason).is_empty(),"Ungültiges explizites Haus wird failclosed abgewiesen")
	check(not preview(game,"missing").ok,"Unbekannte Ziel-ID bleibt ohne Mutation gesperrt")
	game.houses[2].armies[0].last_siege_month = game._now()
	var out := preview(game)
	check(not out.ok and str(out.reason).contains("Monat") and out.progress==33,"Monatssperre behält die echte hypothetische Nächste-Aktions-Vorschau")
	game.houses[2].armies[0].last_siege_month = 0
	game.houses[2].truces["1"] = game._now()+3
	out = preview(game)
	check(not out.ok and str(out.reason).contains("Waffenstillstand") and out.progress==33,"Waffenstillstand sperrt Aktion, ohne Zahlenvorschau zu erfinden")
	game.houses[2].truces = {}
	game.opinion[1] = 60
	check(not preview(game).ok,"Gute Beziehung60sperrt feindliche Belagerung")
	game.opinion[1] = 0
	game.houses[2].claims[0].expires = game._now()-1
	check(not preview(game).ok,"Abgelaufener Anspruch trägt keine neue Belagerungsaktion")
	game.houses[2].claims[0].expires = game._now()
	check(preview(game).ok,"Am Ablaufmonat noch aktiver Anspruch bleibt gültig")
	game.houses[2].armies[0].province = "britannien__03"
	check(not preview(game).ok,"Grobe Reichsnachbarschaft ersetzt keine echte direkte Heeresreichweite")
	game.houses[2].armies[0].province = TARGET
	game.houses[2].armies[0].morale = 0
	out = preview(game)
	check(not out.ok and out.effective_strength==0 and out.progress==0,"Demoralisiertes lebendes Heer kann keinen Festungsfortschritt erzeugen")
	game.houses[2].armies = []
	check(not preview(game).ok,"Keine ausgewählte Feldarmee bleibt gesperrt")
	game = fixture()
	game.province(TARGET).owner = 2
	check(not preview(game).ok,"Eigener Besitz ist kein feindliches Belagerungsziel")

func _test_occupants() -> void:
	var game = fixture()
	game.houses[1].armies = [{"id":10,"province":TARGET,"strength":200,"morale":50,"upkeep":1,"last_siege_month":0},{"id":11,"province":TARGET,"strength":100,"morale":100,"upkeep":1,"last_siege_month":0},{"id":12,"province":HOME,"strength":9000,"morale":100,"upkeep":36,"last_siege_month":0}]
	var out := preview(game)
	check(not out.ok and out.defender_strength==300 and out.progress==0,"Nur tatsächliche kampffähige Besitzerheere im Ziel blockieren mit ihren300Soldaten")
	game.houses[1].armies[0].morale = 0
	game.houses[1].armies[1].strength = 0
	game.houses[3].armies = [{"id":13,"province":TARGET,"strength":9000,"morale":100,"upkeep":36,"last_siege_month":0}]
	out = preview(game)
	check(out.ok and out.defender_strength==0 and out.progress==33,"Ferne, leere, demoraliserte und fremde Nichtbesitzerheere werden nicht als Besitzerverteidigung erfunden")

func _test_progress_owner() -> void:
	var game = fixture()
	game.province(TARGET).siege = 95
	game.province(TARGET).siege_owner = 2
	var out := preview(game)
	check(out.current==95 and out.next==100 and out.remaining_actions==1,"Unterstützter eigener Fortschritt95endet nach einer begrenzten Aktion bei100")
	game.houses[2].armies[0].province = HOME
	out = preview(game)
	check(out.current==0 and out.next>0 and game.province(TARGET).siege==95,"Verlassener eigener Altfortschritt wird rein als0bewertet, ohne Daten zu bereinigen")
	game.houses[2].armies.append({"id":8,"province":TARGET,"strength":20,"morale":10,"upkeep":1})
	check(preview(game).current==95,"Ein anderes tatsächlich verbliebenes kampffähiges eigenes Legacy-Heer erhält den Fortschritt")
	game.province(TARGET).siege = 40
	game.province(TARGET).siege_owner = 3
	game.houses[3].armies = [{"id":9,"province":TARGET,"strength":50,"morale":50,"upkeep":1,"last_siege_month":0}]
	out = preview(game)
	check(not out.ok and out.current==40 and out.next==40 and out.progress==0,"Tatsächlich unterstützter Drittsieger verliert keine40Prozent an neuen Angreifer")
	game.houses[3].armies[0].morale = 0
	out = preview(game)
	check(out.ok and out.current==0 and out.next>0 and game.province(TARGET).siege_owner==3,"Ununterstützter Drittaltzustand sperrt nicht und wird von der Vorschau nicht umgeschrieben")

func _test_house_and_legacy() -> void:
	var game = fixture(3,4)
	var out := preview(game,TARGET,3)
	check(out.ok and out.progress==33 and out.required_strength==140 and game.player==2,"Explizites inaktives Haus nutzt dieselben Regeln ohne Spielerperspektivwechsel")
	check(game.configure_human_houses([0,2]),"Tatsächliche LAN-Mehrperspektivwelt wird eingerichtet")
	game.set_opinion_value(3,4,60)
	game.set_opinion_value(2,4,0)
	out = preview(game,TARGET,3)
	check(not out.ok and str(out.reason).contains("Beziehung") and out.progress==33,"Inaktives Haus nutzt eigene gute Beziehung statt feindlicher Spielerperspektive")
	game.set_opinion_value(3,4,0)
	game.set_opinion_value(2,4,90)
	check(preview(game,TARGET,3).ok and game.player==2,"Feindliches inaktives Haus darf trotz guter Spielerbeziehung belagern, ohne Perspektivwechsel")
	game = Game.new(preload("res://scripts/Data.gd"),0)
	var home := str(game.house().capital)
	var target := str(game.neighbours(home)[0])
	game.province(target).owner = 1
	game.province(target).levy = 400
	game.province(target).defense = 0
	game.province(target).terrain_defense = 0
	game.province(home).terrain_supply = 6
	game.house().ruler.martial = 12
	game.house().doctrine = "balanced"
	game.house().research.known = []
	game.houses[1].research.known = []
	game.houses[1].armies = []
	game.house().armies = [{"id":1,"province":home,"strength":600,"morale":100,"upkeep":2,"last_siege_month":0}]
	game.house().claims = [{"province":target,"strength":1,"expires":game._now()+12}]
	game.opinion[1] = 0
	game.roads = []
	out = preview(game,target,0)
	check(out.ok and out.progress==33,"Getrennte kontrollierte Legacy-Welt benötigt keinen 108er-Sonderpfad")

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("FORTRESSSIEGERULESTEST FAIL: "+message)
	return ok

func finish() -> void:
	print("FORTRESSSIEGERULESTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
