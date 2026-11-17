extends Node
## Independent controlled real-region edge cases. No regular-play claim.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const Battle = preload("res://scripts/FieldBattleRules.gd")
const HOME := "britannien__03"
const TARGET := "gallien__04"
var checks := 0
var failures := 0

func _ready() -> void:
	_test_zero_morale_land()
	_test_zero_morale_sea()
	_test_zero_morale_offense_and_sea_guards()
	_test_capture_wall_accounting()
	_test_duplicate_legacy_escort()
	_test_duplicate_colocated_escort()
	_test_kernel_notifications()
	_test_kernel_invalid_purity()
	print("FORTRESSEDGETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func army(id: int, at: String, strength: int, morale: int = 100) -> Dictionary:
	return {"id":id,"province":at,"strength":strength,"morale":morale,"upkeep":maxi(1,strength/250)}

func fleet(id: int, base: String, station: String, ships: int) -> Dictionary:
	return {"id":id,"province":base,"station":station,"ships":ships,"morale":100,"upkeep":1,"last_naval_month":-1}

func fixture():
	var game = Game.new(Data,2)
	game.houses[2].gold = 1000
	game.houses[2].armies = [army(1,TARGET,1000)]
	game.province(TARGET).owner = 1
	game.province(TARGET).levy = 100
	game.province(TARGET).dev = 4
	game.province(TARGET).defense = 0
	game.province(TARGET).terrain_defense = 0
	game.houses[1].armies = []
	game._add_claim(2,TARGET)
	game.attack_roll_override = 1.0
	return game

func _reject(game, operation: Callable, label: String) -> void:
	var before: Dictionary = game.snapshot()
	var houses: Array = game.houses.duplicate(true)
	seed(181918)
	var expected := randf()
	seed(181918)
	var result: Dictionary = operation.call()
	check(not result.ok,label+": command is actually rejected")
	check(game.snapshot()==before and game.houses==houses and randf()==expected,label+": full world/log/raw units/RNG unchanged")

func _test_zero_morale_land() -> void:
	var game = fixture()
	game.army_for().morale = 0
	var neighbours: Array = game.neighbours(TARGET).duplicate()
	neighbours.sort()
	var own := str(neighbours[0])
	game.province(own).owner = 2
	var result: Dictionary = game.march_army(own,2)
	check(result.ok and str(game.army_for().province)==own and int(game.army_for().morale)==0,"Morale0living army may use an actual own land neighbour without free healing")
	if result.ok:
		check(int(game.army_for().get("last_siege_month",-1))==game._now(),"Voluntary demoralized land return consumes the shared real monthly action")
	var hostile = fixture()
	hostile.army_for().province = own
	hostile.army_for().morale = 0
	hostile.province(own).owner = 2
	_reject(hostile,func(): return hostile.march_army(TARGET,2),"Morale0cannot use offensive land movement")
	_reject(hostile,func(): return hostile.attack(TARGET,2),"Morale0cannot storm foreign territory")
	_reject(hostile,func(): return hostile.advance_siege(TARGET,2),"Morale0cannot besiege foreign territory")

func _zero_sea():
	var game = fixture()
	game.houses[2].gold = 0
	game.houses[2].claims.clear()
	game.army_for().strength = 100
	game.army_for().morale = 0
	game.houses[2].fleets = [fleet(6,TARGET,TARGET,1)]
	game.houses[2].truces["1"] = game._now()+24
	game.opinion[1] = 100
	return game

func _test_zero_morale_sea() -> void:
	var game = _zero_sea()
	var before: Dictionary = game.snapshot()
	seed(181919)
	var expected := randf()
	seed(181919)
	var preview: Dictionary = game.naval_transport_preview(HOME,2)
	check(preview.ok and game.snapshot()==before and randf()==expected,"Morale0own-shore preview is available and pure despite no claim/gold and peace")
	var result: Dictionary = game.transport_army(HOME,2)
	check(result.ok and bool(result.get("landed",false)) and str(game.army_for().province)==HOME,"Demoralized living army actually returns through the real verified route")
	if not result.ok: return
	check(str(game.fleet_for().province)==HOME and str(game.fleet_for().station)==HOME and int(game.army_for().morale)==0 and int(game.house().gold)==0,"Actual escort moves with unhealed demoralized army and no hidden gold charge")
	check(int(game.army_for().get("last_siege_month",-1))==game._now() and int(game.fleet_for().last_naval_month)==game._now(),"Own-shore morale0return consumes both actual monthly actions")
	_reject(game,func(): return game.transport_army(TARGET,2),"Morale0return creates no same-month offensive crossing")

func _test_zero_morale_offense_and_sea_guards() -> void:
	var game = _zero_sea()
	game.army_for().province = HOME
	game.fleet_for().province = HOME
	game.fleet_for().station = HOME
	game.houses[2].truces.clear()
	game.opinion[1] = 0
	game._add_claim(2,TARGET)
	_reject(game,func(): return game.transport_army(TARGET,2),"Morale0cannot cross offensively even with actual claim and route")
	for condition in ["capacity","fleet_morale","fleet_month","army_month","origin_blockade","target_blockade","empty_army","no_fleet"]:
		var blocked = _zero_sea()
		match condition:
			"capacity": blocked.army_for().strength = 101
			"fleet_morale": blocked.fleet_for().morale = 19
			"fleet_month": blocked.fleet_for().last_naval_month = blocked._now()
			"army_month": blocked.army_for().last_siege_month = blocked._now()
			"origin_blockade":
				blocked.province(TARGET).blockade = 1
				blocked.province(TARGET).blockade_owner = 1
			"target_blockade":
				blocked.province(HOME).blockade = 1
				blocked.province(HOME).blockade_owner = 1
			"empty_army": blocked.army_for().strength = 0
			"no_fleet": blocked.houses[2].fleets.clear()
		_reject(blocked,func(): return blocked.transport_army(HOME,2),"Own-shore morale exception retains real "+condition+" guard")

func _test_capture_wall_accounting() -> void:
	var game = fixture()
	game.province(TARGET).buildings = {"barracks":0,"walls":3,"market":0}
	game.province(TARGET).defense = 52 # 10+15+20 wall points, plus unrelated7.
	game.province(TARGET).siege = 99
	game.province(TARGET).siege_owner = 2
	var result: Dictionary = game.advance_siege(TARGET,2)
	check(result.ok and int(game.province(TARGET).owner)==2 and int(game.province(TARGET).buildings.walls)==2,"Real siege completion destroys exactly the third actual wall tier")
	check(int(game.province(TARGET).defense)==32,"Destroyed wall tier removes its20points once and preserves unrelated7plus lower25")
	_reject(game,func(): return game.advance_siege(TARGET,2),"Finished siege cannot repeat fort damage")
	var assault = fixture()
	assault.province(TARGET).buildings = {"barracks":0,"walls":3,"market":0}
	assault.province(TARGET).defense = 52
	var storm: Dictionary = assault.attack(TARGET,2)
	check(storm.ok and bool(storm.get("won",false)) and int(assault.province(TARGET).buildings.walls)==3 and int(assault.province(TARGET).defense)==52,"Explicit no-building-damage assault path keeps wall tiers and their stored defense")

func _test_duplicate_legacy_escort() -> void:
	var game = fixture()
	game.army_for().strength = 100
	game.province(TARGET).levy = 10000
	for id in game.neighbours(TARGET): game.province(str(id)).owner = 1
	game.houses[2].fleets = [fleet(6,TARGET,TARGET,1),fleet(6,HOME,HOME,20)]
	var saved: Dictionary = game.snapshot()
	check(Save.validate(saved).is_empty(),"Duplicate old fleet IDs at distinct physical stations are accepted by the actual saved format")
	var restored = Game.new(Data,2)
	check(restored.restore(saved),"Actual runtime restore retains the controlled legacy fleet identity edge")
	game = restored
	game.attack_roll_override = 0.0
	var actual_escort: Dictionary = game.houses[2].fleets[0]
	var unrelated_escort: Dictionary = game.houses[2].fleets[1]
	var unrelated_before := unrelated_escort.duplicate(true)
	var result: Dictionary = game.attack(TARGET,2)
	check(result.ok and not bool(result.get("won",true)),"Actual foreign-field defeat resolves before choosing physical sea retreat")
	check(game.army_for().is_empty() or (str(actual_escort.province)==HOME and str(actual_escort.station)==HOME),"Surviving actual sea retreat must move the real co-located escort rather than a duplicate-ID fleet elsewhere")
	check(unrelated_escort==unrelated_before,"Unrelated physically remote legacy fleet is not substituted or monthly-marked by retreat")

func _test_duplicate_colocated_escort() -> void:
	var game = fixture()
	game.army_for().strength = 100
	game.province(TARGET).levy = 10000
	for id in game.neighbours(TARGET): game.province(str(id)).owner = 1
	game.houses[2].fleets = [fleet(6,TARGET,TARGET,1),fleet(6,TARGET,TARGET,2)]
	var before: Dictionary = game.snapshot()
	var survivor: Dictionary = game.army_for().duplicate(true)
	survivor.strength = 80
	seed(181920)
	var expected := randf()
	seed(181920)
	var plan: Dictionary = Battle.retreat_plan(game,2,TARGET,[survivor])
	check(plan.kind=="sea" and plan.fleet_id==6 and plan.fleet_index==0,"Equal eligible legacy fleet IDs use the actual stable physical index as deterministic tie-break")
	check(game.snapshot()==before and randf()==expected,"Duplicate co-located escort plan stays pure and random-free")
	var first: Dictionary = game.houses[2].fleets[0]
	var second: Dictionary = game.houses[2].fleets[1]
	var second_before := second.duplicate(true)
	game.attack_roll_override = 0.0
	var result: Dictionary = game.attack(TARGET,2)
	check(result.ok and not bool(result.get("won",true)) and str(game.army_for().get("province",""))==HOME,"Actual battle executes the deterministic co-located legacy escort plan")
	check(str(first.province)==HOME and str(first.station)==HOME and int(first.last_naval_month)==game._now(),"Exactly the chosen physical co-located escort moves and consumes its action")
	check(second==second_before,"Other eligible co-located duplicate-ID fleet remains completely unchanged")

func _count_note(game, hi: int, message: String) -> int:
	var snapshot: Dictionary = game.snapshot_for_player(hi)
	var count := 0
	for line in snapshot.log:
		if str(line)==message: count += 1
	return count

func _test_kernel_notifications() -> void:
	var game = fixture()
	check(game.configure_human_houses([0,1,2]),"Three actual human contexts for independent recipient verification")
	game.select_player_context(2)
	var kernel = Kernel.new()
	kernel.bind_game(game)
	kernel.select_province(TARGET)
	var result: Dictionary = kernel.dispatch({"id":"attack"})
	check(result.ok and bool(result.get("won",false)),"Actual kernel resolves a controlled local assault")
	check(_count_note(game,2,str(result.message))==1 and _count_note(game,1,str(result.message))==1 and _count_note(game,0,str(result.message))==0,"Actual battle summary reaches actor/enemy once each through Kernel and never an unrelated host")

func _test_kernel_invalid_purity() -> void:
	for command in ["attack","relieve","recover_army","siege","march"]:
		var game = fixture()
		game.army_for().last_siege_month = game._now()
		var location := TARGET
		if command=="relieve":
			game.province(TARGET).owner = 2
			game.houses[1].armies = [army(5,TARGET,100)]
		if command=="recover_army":
			location = HOME
			game.army_for().province = HOME
		if command=="march":
			location = str(game.neighbours(TARGET)[0])
			game.province(location).owner = 2
		var kernel = Kernel.new()
		kernel.bind_game(game)
		kernel.select_province(location)
		_reject(game,func(): return kernel.dispatch({"id":command}),"Invalid actual kernel "+str(command)+" is entirely pure")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FORTRESSEDGETEST FAIL: "+label)
	return ok
