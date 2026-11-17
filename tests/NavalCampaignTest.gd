extends Node
## Kontrollierte Planungsfälle mit dem echten108er-Spielmodell. Kein Beleg
## für die reguläre120Gold-Kampagne; diese wird getrennt von Root geprüft.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
const REMOTE := "anatolien__01"
var Planner
var checks := 0
var failures := 0

func _ready() -> void:
	check(FileAccess.file_exists("res://scripts/NavalCampaign.gd"),"Gemeinsamer reiner Feldzugsplaner fehlt")
	if not FileAccess.file_exists("res://scripts/NavalCampaign.gd"):
		finish()
		return
	Planner = load("res://scripts/NavalCampaign.gd")
	_test_all_claims_and_purity()
	_test_staging_and_shared_month()
	_test_blockers()
	_test_own_land_only()
	_test_near_siege()
	_test_preparation()
	_test_preparation_position_and_capacity()
	_test_other_house_and_retreat()
	var has_claim_target := false
	for method in Planner.get_script_method_list():
		if str(method.name)=="claim_target": has_claim_target=true
	check(has_claim_target,"Reine erreichbare Auswahl eines neuen Anspruchsziels fehlt")
	if has_claim_target:
		_test_claim_target_reachability()
		_test_claim_target_sea_and_purity()
	finish()

func funded():
	var game = Game.new(Data,2)
	game.house().gold = 1000
	check(game.raise_army(HOME).ok and game.raise_fleet(HOME).ok,"Kontrollierte Aufstellung über reale Käufe")
	make_ready(game,2)
	return game

func make_ready(game, hi: int) -> void:
	# Diese Fälle isolieren Route/Ansprüche. Bereitschaft wird ebenfalls mit
	# echten Kosten hergestellt; neue Erholungsentscheidungen prüft die AI-Suite.
	for step in 8:
		if not bool(Planner.readiness(game,hi).get("needed",false)): return
		var at := str(game.army_for(hi).province)
		if not check_recovery(game,at,hi): return
		game.month+=1
	check(false,"Kontrollierte Routefixture erreicht bezahlte Bereitschaft")

func check_recovery(game, at: String, hi: int) -> bool:
	var result: Dictionary = game.recover_army(at,hi)
	check(bool(result.ok),"Routefixture bezahlt tatsächliche Erholung vor der Transportprüfung")
	return bool(result.ok)

func claim(game, id: String) -> void:
	game._add_claim(2,id)

func _test_all_claims_and_purity() -> void:
	var game = funded()
	claim(game,REMOTE)
	claim(game,TARGET)
	var before: Dictionary = game.snapshot()
	seed(1711)
	var expected_random := randf()
	seed(1711)
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("target")==TARGET and order.get("action")=="transport" and order.get("destination")==TARGET,"Unerreichbarer erster Anspruch verdrängt nicht die echte Kanalüberfahrt")
	check(randf()==expected_random and game.snapshot()==before,"Planung verbraucht weder Weltzustand noch Zufall")
	game.house().claims.reverse()
	check(Planner.next_order(game,2)==order,"Umgekehrte Anspruchsreihenfolge ändert die gewählte nächste Aktion nicht")
	check(Planner.next_order(game,-1).is_empty() and Planner.next_order(game,999).is_empty(),"Ungültige Haus-IDs erzeugen keinen Befehl")
	game.province(TARGET).owner = 2
	check(Planner.next_order(game,2).is_empty(),"Bereits eigener Zielbesitz wird nicht weiter belagert oder als Fremdziel verfolgt")

func _test_staging_and_shared_month() -> void:
	var game = funded()
	claim(game,TARGET)
	game.army_for().province = "britannien__04"
	make_ready(game,2)
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="march" and order.get("destination")==HOME and order.get("target")==TARGET,"Heer marschiert zunächst über eigene Landnachbarn zum tatsächlichen Geleitort")
	check(game.march_army(HOME).ok,"Echter Landmarsch zum Abfahrtshafen")
	check(Planner.next_order(game,2).is_empty(),"Marsch verbraucht auch die anschließende geplante Überfahrt dieses Monats")
	game.month += 1
	check(Planner.next_order(game,2).get("action")=="transport","Im folgenden Monat wird die echte Überfahrt gewählt")
	check(game.transport_army(TARGET).ok,"Modell führt den geplanten Seeschritt tatsächlich aus")
	check(Planner.next_order(game,2).is_empty(),"Nach Landung kein zweiter Heeresbefehl im selben Monat")
	game.month += 1
	order = Planner.next_order(game,2)
	check(order.get("action")=="siege" and order.get("destination")==TARGET,"Gelandenes Heer belagert erst im nächsten Monat")

func _test_blockers() -> void:
	var game = funded()
	claim(game,TARGET)
	var owner: int = game.province(TARGET).owner
	game.house().claims[0].expires = game._now()
	check(Planner.next_order(game,2).get("action")=="transport","Anspruch gilt einschließlich seines Ablaufmonats")
	game.house().claims[0].expires = game._now()-1
	check(Planner.next_order(game,2).is_empty(),"Gespeicherter abgelaufener Anspruch ergibt keine Überfahrt")
	game.house().claims[0].expires = game._now()+240
	game.house().truces[str(owner)] = game._now()+1
	check(Planner.next_order(game,2).is_empty(),"Aktiver Waffenstillstand entfernt feindlichen Feldzug aus der Planung")
	game.house().truces[str(owner)] = game._now()
	check(Planner.next_order(game,2).get("action")=="transport","Am Ende der Waffenstillstandsfrist wird neu geplant")
	game.opinion[owner] = 60
	check(Planner.next_order(game,2).is_empty(),"Gute Beziehung sperrt auch den KI-Einmarsch")
	game.opinion[owner] = 0
	for id in [HOME,TARGET]:
		game.province(id).blockade = 2
		game.province(id).blockade_owner = owner
		check(Planner.next_order(game,2).is_empty(),"Feindliche Blockade am Abfahrts- oder Zielufer verhindert den Seeplan")
		game.province(id).blockade = 0
		game.province(id).blockade_owner = -1
	game.fleet_for().last_naval_month = game._now()
	check(Planner.next_order(game,2).is_empty(),"Bereits verwendetes Geleit erzeugt keinen weiteren Seebefehl")
	game.fleet_for().last_naval_month = -1
	game.fleet_for().morale = 19
	check(Planner.next_order(game,2).is_empty(),"Unzureichende Geleitmoral ergibt keinen ausführbaren Plan")
	game.fleet_for().morale = 100
	game.fleet_for().ships = 1
	check(Planner.next_order(game,2).is_empty(),"Zu kleine reale Flotte wird nicht durch prognostizierte Schiffe ersetzt")

func _test_own_land_only() -> void:
	var game = funded()
	claim(game,TARGET)
	game.army_for().province = "britannien__02"
	var owner: int = game.province(TARGET).owner
	game.province("britannien__01").owner = owner
	game.province("britannien__04").owner = owner
	check(Planner.next_order(game,2).is_empty(),"Fremde unbeanspruchte Zwischenregionen werden auf dem Weg zum Geleit nicht durchquert")
	game = funded()
	claim(game,TARGET)
	game.fleet_for().province = TARGET
	game.fleet_for().station = TARGET
	check(Planner.next_order(game,2).is_empty(),"Eine auf der anderen Kanalseite liegende Flotte wird nicht zum Heer teleportiert")
	game.fleet_for().province = HOME
	game.fleet_for().station = "gallien__01"
	check(Planner.next_order(game,2).is_empty(),"Abweichende tatsächliche Station wird nicht als freies Geleit am Stützpunkt behandelt")

func _test_near_siege() -> void:
	var game = Game.new(Data,0)
	var home := ""
	var target := ""
	for region in game.owned():
		for id in game.neighbours(str(region.id)):
			if int(game.province(id).owner)!=0:
				home = region.id
				target = id
				break
		if not home.is_empty(): break
	check(not home.is_empty(),"Echte eigene Landgrenze für unmittelbare Belagerung vorhanden")
	if home.is_empty(): return
	game.house().gold = 1000
	check(game.raise_army(home).ok and game.fabricate_claim(target).ok,"Kontrollierte Grenzarmee und bezahlter Anspruch")
	make_ready(game,0)
	# Isoliert die tatsächliche direkte Reichweite von der separaten Festungs-
	# und Feldheerstärkeprüfung; Katalogkanten bleiben unverändert.
	game.province(target).levy=50
	game.province(target).defense=0
	game.province(target).terrain_defense=0
	var order: Dictionary = Planner.next_order(game,0)
	check(order.get("action")=="siege" and order.get("destination")==target,"Bereits nahe Armee belagert statt eines unnötigen zusätzlichen Marsches")
	game.army_for().last_siege_month = game._now()
	check(Planner.next_order(game,0).is_empty(),"Landziel umgeht keine verbrauchte Heeresaktion")

func _test_preparation() -> void:
	var game = Game.new(Data,2)
	var before: Dictionary = game.snapshot()
	seed(812)
	var expected_random := randf()
	seed(812)
	var plan: Dictionary = Planner.preparation(game,2)
	check(plan.get("port")==HOME and plan.get("target")==TARGET and plan.get("required_gold")==150,"Regulärer Inselstarter plant50GoldHeer plus60GoldFlotte plus40GoldAnspruch")
	check(plan.get("needs_army")==true and plan.get("needs_fleet")==true and plan.get("needs_claim")==true,"Vorbereitung unterscheidet die drei fehlenden Anschaffungen")
	check(plan.get("strength")==438 and plan.get("ships")==18 and plan.get("capacity")==1800,"Vorbereitung verwendet die tatsächlich gemeinsame438Mann/18Schiffe-Prognose")
	check(game.snapshot()==before and randf()==expected_random,"Vorbereitung verändert auch bei fehlender Kasse weder Welt noch Zufall")
	check(Planner.preparation(game,0).is_empty(),"Festlandhaus mit fremder Landgrenze erhält keine Insel-Expeditionsreserve")
	check(game.raise_fleet(HOME).ok,"Vorhandenes Geleit wird regulär gekauft")
	plan = Planner.preparation(game,2)
	check(plan.get("required_gold")==90 and plan.get("needs_fleet")==false,"Bereits bezahlte Flotte wird nicht nochmals in die Anschaffungskosten gerechnet")
	game.house().gold = 1000
	check(game.fabricate_claim(TARGET).ok,"Maritimer Anspruch wird über vorhandenes Geleit bezahlt")
	plan = Planner.preparation(game,2)
	check(plan.get("required_gold")==50 and plan.get("needs_claim")==false,"Aktiver Anspruch wird nicht doppelt gekauft")
	game.house().claims[0].expires = game._now()-1
	plan = Planner.preparation(game,2)
	check(plan.get("required_gold")==90 and plan.get("needs_claim")==true,"Abgelaufener Anspruch wird als reguläre bezahlte Erneuerung eingeplant")

func _test_preparation_position_and_capacity() -> void:
	var game = funded()
	game.fleet_for().ships = 1
	check(Planner.preparation(game,2).is_empty(),"Zu kleines vorhandenes Geleit erzeugt keine angeblich vorbereitbare Expedition")
	game.house().fleets = []
	game.army_for().strength = 5000
	check(Planner.preparation(game,2).is_empty(),"Auch prognostizierte Neuflotte muss das vorhandene Heer tatsächlich tragen können")
	game.army_for().strength = 438
	game.house().fleets = [{"id":1,"province":TARGET,"station":TARGET,"ships":18,"morale":100,"upkeep":2,"last_naval_month":-1}]
	check(Planner.preparation(game,2).is_empty(),"Vorhandenes Geleit an fremder Küste wird nicht als neuer Londonkauf ersetzt")
	game = funded()
	var other: String = "gallien__01"
	check(game.blockade(other).ok,"Reale bestehende Blockade als Beleg eines anderweitig eingesetzten Geleits")
	check(Planner.preparation(game,2).is_empty(),"Blockierende Flotte ist kein gleichzeitig verfügbares Transportgeleit")
	game = Game.new(Data,2)
	game.province(TARGET).owner = 2
	check(Planner.preparation(game,2).is_empty(),"Eigene Gegenseite braucht keine neue fremde Invasion")

func _test_other_house_and_retreat() -> void:
	var game = Game.new(Data,0)
	for region in game.provinces:
		if int(region.owner)==5: region.owner=0
		if str(region.id).begins_with("britannien__"): region.owner=5
	game.houses[5].capital = HOME
	game.houses[5].gold = 1000
	var plan: Dictionary = Planner.preparation(game,5)
	check(plan.get("port")==HOME and plan.get("required_gold")==150,"Inselvorbereitung hängt von Besitz und Routen ab, nicht von Haus-ID2")
	check(game.raise_army(HOME,5).ok and game.raise_fleet(HOME,5).ok,"Andere Haus-ID bezahlt dieselben realen Einheiten")
	make_ready(game,5)
	game._add_claim(5,TARGET)
	check(Planner.next_order(game,5).get("action")=="transport","Dasselbe Transportmodell plant auch für eine andere Haus-ID")
	game = funded()
	claim(game,TARGET)
	check(game.transport_army(TARGET).ok,"Tatsächliche feindliche Landung vor legalem Rückzugsfall")
	game.month += 1
	game.house().claims.clear()
	game.house().gold = 0
	var order: Dictionary = Planner.next_order(game,2)
	check(order.get("action")=="transport" and order.get("destination")==HOME and order.get("retreat")==true,"Ohne aktiven Invasionsanspruch zieht das Heer über echte Route in eigenes Land zurück")

func _test_claim_target_reachability() -> void:
	var game = Game.new(Data,0)
	for region in game.provinces:
		region.owner = 1
	for id in ["britannien__01",HOME,"britannien__04",REMOTE]:
		game.province(id).owner = 0
	game.house().capital = HOME
	game.house().gold = 1000
	game.house().claims.clear()
	# Das unerreichbare Fernziel hat absichtlich den größten alten Zielwert.
	game.province("anatolien__02").base_income = 100000
	check(game.raise_army(HOME).ok,"Reales Heer vor der kontrollierten Splitbesitz-Zielauswahl")
	check(Planner.claim_target(game,0)=="britannien__02","Neuer Anspruch folgt der erreichbaren eigenen Landkette statt lukrativem Fernbesitz")
	game._add_claim(0,"britannien__02")
	game.army_for().last_siege_month = game._now()
	check(Planner.claim_target(game,0)=="","Erreichbarer aktiver Anspruch braucht während der Monatswache keinen Ersatzkauf")
	game.house().claims[0].expires = game._now()-1
	check(Planner.claim_target(game,0)=="britannien__02","Abgelaufener erreichbarer Anspruch kann als regulärer neuer Kauf gewählt werden")
	game.house().armies.clear()
	check(Planner.claim_target(game,0)=="britannien__02","Ohne Heer beginnt die reine Wegprognose an der tatsächlichen eigenen Hauptstadt")
	game.province(HOME).owner = 1
	check(Planner.claim_target(game,0)=="","Verlorene Hauptstadt wird nicht durch einen erfundenen Aufstellungsort ersetzt")
	check(Planner.claim_target(game,-1)=="" and Planner.claim_target(game,999)=="","Ungültige Haus-ID erhält kein neues Anspruchsziel")

func _test_claim_target_sea_and_purity() -> void:
	var game = funded()
	game.house().claims.clear()
	var before: Dictionary = game.snapshot()
	seed(961)
	var expected_random := randf()
	seed(961)
	check(Planner.claim_target(game,2)==TARGET,"Neuer Küstenanspruch benutzt die echte London-Brüssel-Verbindung und das vorhandene Geleit")
	check(game.snapshot()==before and randf()==expected_random,"Anspruchsprognose verändert weder Ansprüche noch Ressourcen noch Zufallsfolge")
	game.house().gold = 0
	check(Planner.claim_target(game,2)==TARGET,"Strukturelles Anspruchsziel bleibt auch zum Ansparen bei leerer Kasse verfügbar")
	claim(game,REMOTE)
	check(Planner.claim_target(game,2)==TARGET,"Ein alter unerreichbarer Anspruch sperrt kein neues erreichbares Küstenziel")
	claim(game,TARGET)
	game.fleet_for().last_naval_month = game._now()
	check(Planner.claim_target(game,2)=="","Verbrauchte Flottenaktion löst keinen unnötigen Neukauf neben aktivem erreichbarem Anspruch aus")
	game.house().claims.clear()
	game.fleet_for().last_naval_month = -1
	var owner: int = game.province(TARGET).owner
	game.house().truces[str(owner)] = game._now()+1
	check(Planner.claim_target(game,2)=="","Neuer Küstenanspruch wird bei aktivem Waffenstillstand nicht als Kriegsziel vorbereitet")
	game.house().truces.clear()
	game.opinion[owner] = 60
	check(Planner.claim_target(game,2)=="","Freundliche Gegenseite wird nicht als neuer Feldzug gewählt")
	game.opinion[owner] = 0
	game.province(TARGET).blockade = 2
	game.province(TARGET).blockade_owner = owner
	check(Planner.claim_target(game,2)=="","Feindliche Blockade sperrt auch die Auswahl eines noch nicht beanspruchten Seeziels")
	game.province(TARGET).blockade = 0
	game.fleet_for().province = TARGET
	game.fleet_for().station = TARGET
	check(Planner.claim_target(game,2)=="","Neues Küstenziel benutzt keine auf die Abfahrtsseite teleportierte Flotte")
	game.house().fleets.clear()
	check(Planner.claim_target(game,2)=="","Ohne vorhandene Flotte wird ein Seeanspruch erst durch die getrennte bezahlte Vorbereitung ermöglicht")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALCAMPAIGNTEST FAIL: "+text)

func finish() -> void:
	print("NAVALCAMPAIGNTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
