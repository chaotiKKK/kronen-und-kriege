extends Node
## Kontrollierte Modellfälle; der reguläre120Gold-Feldzug wird separat geprüft.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
const OTHER := "gallien__01"
var checks := 0
var failures := 0

func _ready() -> void:
	_test_expired_claims()
	_test_unit_forecasts()
	_test_station_and_sink()
	_test_resolved_blockade()
	_test_blockade_binding()
	var probe = Game.new(Data,2)
	check(probe.has_method("naval_transport_preview") and probe.has_method("transport_army"), "Echter Seetransport fehlt im gemeinsamen Spielmodell")
	if probe.has_method("naval_transport_preview") and probe.has_method("transport_army"):
		_test_crossing_and_return()
		_test_invalid_cases()
		_test_shared_fleet_guard()
		_test_combat_capacity()
		_test_no_replacement_escort()
		_test_siege_support()
	print("NAVALTRANSPORTTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)

func _funded():
	var game = Game.new(Data,2)
	game.house().gold = 1000
	check(game.raise_army(HOME).ok and game.raise_fleet(HOME).ok, "Kontrolliertes Wessex-Heer und Geleit über echte Kaufbefehle")
	game.houses[int(game.province(TARGET).owner)].fleets = []
	return game

func _fleet(id: int, base: String, station: String, ships: int) -> Dictionary:
	return {"id":id,"province":base,"station":station,"ships":ships,"morale":100,"upkeep":1,"last_naval_month":-1}

func _test_expired_claims() -> void:
	var game = Game.new(Data,0)
	var target := ""
	for region in game.provinces:
		if int(region.owner) != game.player and game.is_border_province(game.player,str(region.id)):
			target = region.id
			break
	check(not target.is_empty(), "Echte fremde Landgrenze für Anspruchserneuerung")
	if target.is_empty(): return
	game.house().gold = 100
	check(game.fabricate_claim(target).ok,"Bezahlter ursprünglicher Grenzanspruch")
	game.house().claims[0].expires = game._now()
	check(game.has_claim(target),"Anspruch gilt einschließlich seines Ablaufmonats")
	game.house().claims[0].expires = game._now()-1
	check(not game.has_claim(target),"Gespeicherter abgelaufener Anspruch ist kein gültiger Kriegsgrund")
	var gold: int = game.house().gold
	check(game.fabricate_claim(target).ok and int(game.house().gold)==gold-40,"Abgelaufener Grenzanspruch lässt sich regulär für40Gold erneuern")
	check(game.house().claims.size()==1 and game.claim_expiry(target)==game._now()+240,"Erneuerung ersetzt alten Eintrag ohne doppelte Ansprüche")
	game.house().claims[0].erase("expires")
	var loaded = Game.new(Data,0)
	check(loaded.restore(game.snapshot()) and loaded.has_claim(target),"Historischer Anspruch ohne Enddatum bleibt auch über Speichern/Laden aktiv")

func _test_unit_forecasts() -> void:
	var game = Game.new(Data,2)
	check(game.has_method("army_raise_strength") and game.has_method("fleet_raise_ships"),"Gemeinsame reine Aufstellungsprognosen für Feldzugsplanung fehlen")
	if not game.has_method("army_raise_strength") or not game.has_method("fleet_raise_ships"): return
	game.house().gold = 0
	check(game.army_raise_strength(HOME)==438 and game.fleet_raise_ships(HOME)==18,"Echte Wessex-Prognose438Mann/18Schiffe bleibt ohne Kassenänderung lesbar")
	check(int(game.house().gold)==0 and game.army_for().is_empty() and game.fleet_for().is_empty(),"Aufstellungsprognosen kaufen keine Einheiten")
	check(game.army_raise_strength(TARGET)==0 and game.fleet_raise_ships("unbekannt")==0,"Prognosen erfinden keine fremde oder ungültige Aufstellung")
	game.house().gold = 120
	check(game.raise_army(HOME).ok and game.raise_fleet(HOME).ok and int(game.army_for().strength)==438 and int(game.fleet_for().ships)==18,"Echter Kauf verwendet dieselben438Mann/18Schiffe wie die reguläre Anfangslage")

func _test_station_and_sink() -> void:
	var game = Game.new(Data,2)
	game.house().fleets = [_fleet(1,HOME,TARGET,8)]
	check(game._defending_fleet(HOME,2).is_empty(),"Andernorts stationierte Flotte verteidigt keinen entfernten Basishafen")
	check(not game._defending_fleet(TARGET,2).is_empty(),"Flottenverteidigung folgt der tatsächlichen Station")
	game.house().fleets.append(_fleet(2,HOME,OTHER,8))
	game.province(OTHER).blockade = 4
	game.province(OTHER).blockade_owner = 2
	game._sink_fleet(2,game.house().fleets[0])
	check(game.house().fleets.size()==1 and int(game.house().fleets[0].id)==2,"Versenken entfernt nur die betroffene Legacy-Flotte")
	check(int(game.province(OTHER).blockade)==4 and str(game.house().fleets[0].station)==OTHER,"Andere wirklich unterstützte Blockade bleibt bei Geleitverlust erhalten")

func _test_resolved_blockade() -> void:
	var game = _funded()
	var enemy: int = game.province(TARGET).owner
	game.houses[enemy].fleets = [_fleet(1,TARGET,TARGET,40)]
	game.attack_roll_override = 0.1
	var before: int = game.fleet_for().ships
	var result: Dictionary = game.blockade(TARGET)
	check(result.ok and not bool(result.get("blockaded",true)),"Aufgelöste Seeabwehr wird als mutierender Befehl mit blockaded=false gemeldet")
	check(game.fleet_for().is_empty() or int(game.fleet_for().ships)<before,"Tatsächliche Seeabwehr bewahrt Schiffsverluste")
	if not game.fleet_for().is_empty():
		check(int(game.fleet_for().get("last_naval_month",-1))==game._now(),"Aufgelöste Blockade verbraucht eine Flotten-Monatsaktion")
	check(not game.can_blockade(TARGET),"Auch abgewehrte Blockade ist diesen Monat nicht beliebig wiederholbar")

func _claimed_game():
	var game = _funded()
	check(game.fabricate_claim(TARGET).ok,"Vorhandenes Geleit eröffnet einen regulären40Gold-Küstenanspruch")
	return game

func _test_blockade_binding() -> void:
	var game = _funded()
	check(game.blockade(TARGET).ok,"Erste reguläre Blockade bindet das konkrete Geleit")
	game.advance_month()
	var before: Dictionary = game.snapshot()
	check(not game.can_blockade(OTHER),"Ein weiterhin blockierendes Geleit eröffnet keine zweite gleichzeitige Blockade")
	check(not game.blockade(OTHER).ok and game.snapshot()==before,"Zweite Blockade verändert weder erste Station noch Weltzustand")

func _test_crossing_and_return() -> void:
	var game = _claimed_game()
	var preview: Dictionary = game.naval_transport_preview(TARGET)
	check(preview.ok and int(preview.ships_required)>0 and int(preview.capacity)>=int(game.army_for().strength),"Vorschau meldet echte Armee und vorhandene Transportkapazität")
	check(str(preview.origin)==HOME and str(preview.target)==TARGET and str(preview.route_id)!="","Vorschau ist an den tatsächlichen Kanalweg gebunden")
	var owner: int = game.province(TARGET).owner
	var gold: int = game.house().gold
	var strength: int = game.army_for().strength
	var result: Dictionary = game.transport_army(TARGET)
	check(result.ok and bool(result.get("landed",false)),"Legale Überfahrt landet tatsächlich auf dem Festland")
	check(str(game.army_for().province)==TARGET and str(game.fleet_for().province)==TARGET and str(game.fleet_for().station)==TARGET,"Heer und beide Geleitorte wechseln atomar ans Ziel")
	check(int(game.house().gold)==gold and int(game.army_for().strength)==strength,"Überfahrt kassiert keine Zusatzreisegebühr und löscht keine Soldaten")
	check(int(game.province(TARGET).owner)==owner and int(game.province(TARGET).siege)==0,"Landung erobert nicht automatisch und gewährt keinen Belagerungsfortschritt")
	check(not game.can_siege(TARGET) and not game.can_blockade(TARGET),"Überfahrt sperrt Belagerung und Flottenblockade im selben Monat")
	var snapshot: Dictionary = game.snapshot()
	check(not snapshot.is_empty() and int(snapshot.schema_version)==Save.CURRENT_VERSION,"Transportzustand ergibt einen gültigen aktuellen Spielstand")
	var loaded = Game.new(Data,2)
	check(loaded.restore(JSON.parse_string(JSON.stringify(snapshot))),"Tatsächlicher JSON-Spielstand lässt sich wieder laden")
	if loaded.fleet_for().is_empty(): return
	check(int(loaded.fleet_for().get("last_naval_month",-1))==game._now(),"Laden erhält die tatsächlich verbrauchte Flotten-Monatsmarke")
	_reject(loaded,HOME,"Rückfahrt im selben Monat")
	loaded.advance_month()
	loaded.house().gold = 0
	loaded.house().claims = []
	loaded.house().truces[str(owner)] = loaded._now()+24
	var returned: Dictionary = loaded.transport_army(HOME)
	check(returned.ok and returned.landed and str(loaded.army_for().province)==HOME,"Rückzug vom fremden Strand ins eigene London trotz Frieden und fehlendem Anspruch")
	check(int(loaded.house().gold)==0 and str(loaded.fleet_for().station)==HOME,"Eigener Rückweg benötigt kein Reisegold und teleportiert das Geleit nicht anderswohin")

func _reject(game, target: String, label: String) -> void:
	var before: Dictionary = game.snapshot()
	seed(18331)
	var expected_rng := randf()
	seed(18331)
	var preview: Dictionary = game.naval_transport_preview(target)
	var result: Dictionary = game.transport_army(target)
	check(not preview.ok and not str(preview.reason).is_empty() and not result.ok,"Reine Abweisung: "+label)
	check(game.snapshot()==before,"Keine Weltmutation bei "+label)
	check(randf()==expected_rng,"Keine Zufallszahl bei "+label)

func _test_invalid_cases() -> void:
	var game = _funded()
	_reject(game,TARGET,"fehlendem Anspruch")
	check(game.fabricate_claim(TARGET).ok,"Küstenanspruch für getrennte Negativfälle")
	_reject(game,"anatolien__01","ungeprüftem Fernseeweg")
	game.army_for().strength = 501
	game.fleet_for().ships = 5
	_reject(game,TARGET,"501Soldaten auf nur5Schiffen")
	game.army_for().strength = 500
	check(game.naval_transport_preview(TARGET).ok,"Genau500Soldaten passen auf5Schiffe")
	game.fleet_for().morale = 19
	_reject(game,TARGET,"unzureichender Flottenmoral")
	game.fleet_for().morale = 100
	game.fleet_for().station = OTHER
	_reject(game,TARGET,"Geleit an einer anderen Station")
	game.fleet_for().station = HOME
	var enemy: int = game.province(TARGET).owner
	game.house().truces[str(enemy)] = game._now()+2
	_reject(game,TARGET,"Waffenstillstand")
	game.house().truces.clear()
	game.province(HOME).blockade = 2
	game.province(HOME).blockade_owner = enemy
	_reject(game,TARGET,"feindlicher Blockade am Abfahrtsufer")
	game.province(HOME).blockade = 0
	game.province(HOME).blockade_owner = -1
	game.fleet_for().last_naval_month = game._now()
	_reject(game,TARGET,"bereits eingesetzter Flotte")
	game.fleet_for().last_naval_month = -1
	game.army_for().last_siege_month = game._now()
	_reject(game,TARGET,"bereits eingesetztem Heer")

func _test_shared_fleet_guard() -> void:
	var game = _claimed_game()
	check(game.transport_army(TARGET).landed,"Erste Armee nutzt das eigene Geleit")
	game.house().armies.append({"id":2,"province":TARGET,"strength":200,"morale":100,"upkeep":1})
	check(game.select_army(2).ok,"Andere erhaltene Legacy-Armee bleibt auswählbar")
	_reject(game,HOME,"Armeewechsel mit derselben bereits benutzten Flotte")

func _test_combat_capacity() -> void:
	var game = _claimed_game()
	game.army_for().strength = 600
	game.fleet_for().ships = 6
	var enemy: int = game.province(TARGET).owner
	game.houses[enemy].fleets = [_fleet(1,TARGET,TARGET,1)]
	game.attack_roll_override = 10.0
	var result: Dictionary = game.transport_army(TARGET)
	check(result.ok and not bool(result.get("landed",true)),"Seesieg mit zu kleiner Restflotte ist ein aufgelöster abgewehrter Landeversuch")
	check(str(game.army_for().province)==HOME and int(game.army_for().strength)==600 and int(game.fleet_for().ships)==5,"Erneute Kapazitätsprüfung nach Kampf bewahrt600Soldaten am Abfahrtsufer")
	check(int(game.fleet_for().last_naval_month)==game._now() and int(game.army_for().last_siege_month)==game._now(),"Aufgelöster Kampf verbraucht beide Monatsaktionen")

func _test_no_replacement_escort() -> void:
	var game = _claimed_game()
	var enemy: int = game.province(TARGET).owner
	game.fleet_for().ships = 1
	game.army_for().strength = 100
	game.house().fleets.append(_fleet(9,HOME,OTHER,8))
	game.province(OTHER).blockade = 5
	game.province(OTHER).blockade_owner = 2
	game.houses[enemy].fleets = [_fleet(1,TARGET,TARGET,40)]
	game.attack_roll_override = 0.01
	var result: Dictionary = game.transport_army(TARGET)
	check(result.ok and not result.landed and str(game.army_for().province)==HOME,"Versenktes erstes Geleit wird nicht durch andere Flotte ersetzt")
	check(game.house().fleets.size()==1 and int(game.fleet_for().id)==9 and str(game.fleet_for().station)==OTHER,"Andere Legacy-Flotte bleibt am tatsächlichen anderen Ort")
	check(int(game.province(OTHER).blockade)==5,"Geleitverlust hebt keine weiterhin unterstützte andere Blockade auf")

func _test_siege_support() -> void:
	for keep_second in [false,true]:
		var game = _claimed_game()
		check(game.transport_army(TARGET).landed,"Echter fremder Brückenkopf für Rückzugsfall")
		game.advance_month()
		game.province(TARGET).siege = 45
		game.province(TARGET).siege_owner = 2
		if keep_second:
			game.house().armies.append({"id":2,"province":TARGET,"strength":200,"morale":100,"upkeep":1})
		check(game.transport_army(HOME).landed,"Rückfahrt aus bestehendem Brückenkopf")
		check(int(game.province(TARGET).siege)==(45 if keep_second else 0),"Zurückbleibendes eigenes Heer trägt Belagerung; andernfalls endet ungestützter Fortschritt")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALTRANSPORTTEST FAIL: "+label)
