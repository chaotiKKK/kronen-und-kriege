extends Node
## Actual108-region game plus explicitly controlled runtime edge cases.
## Only the preview module is under test; no paid campaign claim is made.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Design = preload("res://scripts/HouseDesign.gd")
const HOME := "britannien__03"
const OTHER := "gallien__04"
const FIELDS := ["ok","reason","needed","army_id","origin","current_strength","new_strength","added","capacity","current_morale","new_morale","cost","levy_before","levy_after","reserve","upkeep_before","upkeep_after","house_upkeep_after"]
var rules
var checks := 0
var failures := 0

func _ready() -> void:
	if not check(FileAccess.file_exists("res://scripts/ArmyRecovery.gd"),"Pure ArmyRecovery preview is available"):
		finish()
		return
	rules = load("res://scripts/ArmyRecovery.gd")
	_test_real_london()
	_test_partial_purchases()
	_test_morale_and_no_effect()
	_test_capacity_and_aggregate_upkeep()
	_test_location_and_month_guards()
	_test_foreign_occupants()
	_test_dynamic_house()
	finish()

func _real():
	var game = Game.new(Data,2)
	check(game.raise_army(HOME).ok,"Actual108-region Wessex buys its existing army normally")
	return game

func _controlled(strength: int, morale: int, gold: int, levy: int):
	var game = _real()
	game.army_for().strength = strength
	game.army_for().morale = morale
	game.house().gold = gold
	game.province(HOME).levy = levy
	return game

func _call(game, location: String = HOME, hi: int = 2) -> Dictionary:
	var before: Dictionary = game.snapshot()
	var houses: Array = game.houses.duplicate(true)
	var provinces: Array = game.provinces.duplicate(true)
	var effects: Array = game.effect_log.duplicate(true)
	seed(1911801)
	var expected_rng := randf()
	seed(1911801)
	var result: Dictionary = rules.preview(game,location,hi)
	check(randf()==expected_rng,"Preview leaves the actual global RNG sequence unchanged")
	check(game.snapshot()==before and game.houses==houses and game.provinces==provinces and game.effect_log==effects,"Preview preserves complete snapshot, raw units/provinces and effect log")
	var complete := true
	for key in FIELDS:
		if not result.has(key): complete = false
	check(complete,"Preview always returns the complete public recovery contract")
	return result

func _test_real_london() -> void:
	var game = _real()
	check(game.provinces.size()==108 and int(game.house().gold)==70 and int(game.province(HOME).levy)==696 and int(game.army_for().strength)==438,"Actual London source is696levy/438soldiers and70gold after normal army purchase")
	check(int(game.region_capacity(game.province(HOME)).maximum)==5646,"Frozen actual London share gives5646maximum regional levy")
	var result := _call(game)
	check(result.ok and result.reason=="" and result.needed is bool and result.needed,"Real own stationed army has an actionable recovery need")
	check(result.army_id==1 and result.origin==HOME and result.capacity==2913,"Capacity is maximum5646/2 plus90vassals, independent of current696levy")
	check(result.current_strength==438 and result.new_strength==538 and result.added==100,"Normal affordable action can transfer exactly100 actual local soldiers")
	check(result.current_morale==100 and result.new_morale==100 and result.cost==15,"No excess morale is created and100soldiers cost5+10gold")
	check(result.levy_before==696 and result.levy_after==596 and result.reserve==50,"The real local levy loses precisely the transferred100 and protects50reserve")
	check(result.upkeep_before==1 and result.upkeep_after==2 and result.house_upkeep_after==2,"Actual annual basis increases from1 to2 at538soldiers")
	check(rules.RULES.max_recruits==100 and rules.RULES.local_levy_reserve==50 and rules.RULES.base_gold==5 and rules.RULES.soldiers_per_gold==10 and rules.RULES.morale_gain==20,"Published pure rules bind the specified amounts")

func _test_partial_purchases() -> void:
	var limited := _call(_controlled(200,100,100,72))
	check(limited.ok and limited.added==22 and limited.new_strength==222 and limited.cost==8 and limited.levy_after==50,"Only22actual local soldiers above50reserve are available; price rounds upward")
	var capacity := _call(_controlled(2890,100,100,696))
	check(capacity.ok and capacity.added==23 and capacity.new_strength==2913 and capacity.cost==8 and capacity.levy_after==673,"Missing23capacity caps the charge without creating an oversized army")
	for item in [[6,10],[14,90]]:
		var poor := _call(_controlled(200,100,int(item[0]),696))
		check(poor.ok and poor.added==int(item[1]) and poor.cost==int(item[0]),"The actual budget buys an affordable partial charge: "+str(item))
	var one := _call(_controlled(200,100,6,51))
	check(one.ok and one.added==1 and one.cost==6 and one.levy_after==50,"A single genuine remaining recruit costs one rounded recruitmentgold")
	for levy in [0,49,50]:
		var empty := _call(_controlled(200,100,100,levy))
		check(not empty.ok and not str(empty.reason).is_empty() and empty.added==0 and empty.levy_after==levy,"Full morale cannot sell a no-effect charge without recruits: "+str(levy))

func _test_morale_and_no_effect() -> void:
	var moral := _call(_controlled(200,70,5,696))
	check(moral.ok and moral.added==0 and moral.new_strength==200 and moral.new_morale==90 and moral.cost==5 and moral.levy_after==696,"Fivegold buys actual moralecare, not unaffordable soldiers")
	var zero := _call(_controlled(200,0,5,0))
	check(zero.ok and zero.new_morale==20 and zero.added==0 and zero.cost==5,"A living moralezero own army can recover even without local recruits")
	var cap := _call(_controlled(2913,95,5,696))
	check(cap.ok and cap.added==0 and cap.new_morale==100 and cap.new_strength==2913,"Moralecare caps at100 without increasing a full army")
	var price := _call(_controlled(200,100,5,696))
	check(not price.ok and price.needed and price.added==0 and not str(price.reason).is_empty(),"Fivegold and full morale cannot pay for zero actual effect")
	var poor := _call(_controlled(200,50,4,696))
	check(not poor.ok and not str(poor.reason).is_empty(),"Even pure moralecare requires the real fivegold base price")
	var full := _call(_controlled(2913,100,100,696))
	check(not full.ok and not full.needed and full.added==0,"A fully recovered army offers no payable action")
	var oversized = _controlled(3200,80,5,696)
	oversized.army_for().upkeep = 17
	var old := _call(oversized)
	check(old.ok and old.added==0 and old.new_strength==3200 and old.new_morale==100 and old.upkeep_after==17,"Inherited oversized army is not cut and moralecare preserves its saved basisupkeep")

func _test_capacity_and_aggregate_upkeep() -> void:
	var legacy = _controlled(200,100,100,696)
	legacy.house().legacies.war = 2
	for vassal in legacy.house().vassals: vassal.level = 2
	var inherited := _call(legacy)
	check(inherited.capacity==3568,"Maximum-based2823 at1.2legacy rounds3388, then adds180actual vassals")
	# Use the genuinely tiny admitted region; never forge the frozen share.
	var tiny = Game.new(Data,0)
	var tiny_id := "skythien__51"
	var tiny_owner := int(tiny.province(tiny_id).owner)
	check(tiny.raise_army(tiny_id,tiny_owner).ok,"Actual tiny catalog region legally raises an army for its real owner")
	tiny.army_for(tiny_owner).strength = 20
	tiny.army_for(tiny_owner).morale = 80
	tiny.houses[tiny_owner].gold = 100
	tiny.province(tiny_id).levy = 80
	for vassal in tiny.houses[tiny_owner].vassals: vassal.level = 0
	var minimum := _call(tiny,tiny_id,tiny_owner)
	check(minimum.capacity==100 and minimum.added==30 and minimum.new_strength==50,"A tiny region preserves100minimum capacity but only transfers its actual30surplus")
	var game = _controlled(499,80,100,200)
	game.house().doctrine = "cavalry"
	game.house().armies.append({"id":7,"province":HOME,"strength":660,"upkeep":2,"morale":100})
	check(game.army_upkeep()==4,"Controlled two-army cavalry basis before recovery is ceil(3*1.25)=4")
	var combined := _call(game)
	check(combined.new_strength==599 and combined.upkeep_before==1 and combined.upkeep_after==2 and combined.house_upkeep_after==5,"Doctrine rounds once across both bases: ceil((2+2)*1.25)=5, not6")
	check(game.house().armies[1].strength==660 and game.house().armies[1].upkeep==2,"Other legacy army is neither recruited from nor rewritten")

func _test_location_and_month_guards() -> void:
	var game = _real()
	for hi in [-2,999]:
		var invalid := _call(game,HOME,hi)
		check(not invalid.ok and not str(invalid.reason).is_empty(),"Unknown house is blocked: "+str(hi))
	for location in ["unknown",OTHER]:
		var invalid := _call(game,location)
		check(not invalid.ok and not str(invalid.reason).is_empty(),"Unknown/foreign location is blocked: "+location)
	var remote := ""
	for region in game.owned():
		if str(region.id)!=HOME:
			remote = region.id
			break
	var elsewhere := _call(game,remote)
	check(not elsewhere.ok and not str(elsewhere.reason).is_empty(),"Owned location cannot remotely recover an army stationed elsewhere")
	game.army_for().last_siege_month = game._now()
	var used := _call(game)
	check(not used.ok and str(used.reason).contains("Monat"),"Recovery shares the actually used siege/march/transport monthguard")
	game.house().armies = []
	var absent := _call(game)
	check(not absent.ok and not str(absent.reason).is_empty(),"No army cannot buy recovery")
	game.house().armies = [{"id":1,"province":HOME,"strength":0,"morale":50,"upkeep":1}]
	check(not _call(game).ok,"An empty ghost army cannot recover")
	for kind in ["siege","blockade"]:
		var occupied = _real()
		occupied.province(HOME)[kind] = 1
		occupied.province(HOME)[kind+"_owner"] = 0
		check(not _call(occupied).ok,"A hostile "+kind+" blocks recovery even without a currently supported army")
	var own = _real()
	own.province(HOME).siege = 1
	own.province(HOME).siege_owner = 2
	own.province(HOME).blockade = 1
	own.province(HOME).blockade_owner = 2
	check(_call(own).ok,"Own stale markers are not treated as hostile siege/blockade")

func _test_foreign_occupants() -> void:
	for value in [[100,100,false],[100,0,true],[0,100,true]]:
		var game = _real()
		game.houses[0].armies = [{"id":12,"province":HOME,"strength":value[0],"morale":value[1],"upkeep":1}]
		var preview := _call(game)
		check(bool(preview.ok)==bool(value[2]),"Only a foreign actually combat-capable army blocks recovery: "+str(value))
	var remote = _real()
	remote.houses[0].armies = [{"id":12,"province":OTHER,"strength":100,"morale":100,"upkeep":1}]
	check(_call(remote).ok,"A foreign army at another actual location creates no phantom recovery blockade")

func _test_dynamic_house() -> void:
	var profile: Dictionary = Design.defaults(Data,HOME)
	profile.house = "Haus Feldlager"
	var game = Game.new(Data,0,profile)
	check(game.player==9 and game.province(HOME).owner==9 and game.raise_army(HOME).ok,"Actual house designer creates and pays for a dynamic house9army")
	var preview := _call(game,HOME,9)
	check(preview.ok and preview.army_id==1 and preview.added==100,"Recovery is not restricted to the nine historical house IDs")
	var different_view = Game.new(Data,0)
	check(different_view.raise_army(HOME,2).ok,"Actual actor2buys army while current view is actor0")
	check(_call(different_view,HOME,2).ok and int(different_view.houses[0].gold)==140,"Explicit actor supplies own army, budget and vassals without changing current view")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("ARMYRECOVERYTEST FAIL: "+label)
	return ok

func finish() -> void:
	print("ARMYRECOVERYTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
