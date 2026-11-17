extends Node
## Controlled real-region lifecycle cases; not a regular campaign proof.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const TARGET := "gallien__04"
var checks := 0
var failures := 0

func _ready() -> void:
	_march_cleanup()
	_destroyed_cleanup()
	_peace_cleanup()
	_progress_ownership()
	print("SIEGELIFECYCLETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func fixture():
	var game = Game.new(Data,2)
	var home := str(game.neighbours(TARGET)[0])
	game.province(home).owner = 2
	game.province(TARGET).owner = 1
	game._add_claim(2,TARGET)
	game.house().armies = [army(7,TARGET,500)]
	game.province(TARGET).siege = 45
	game.province(TARGET).siege_owner = 2
	return {"game":game,"home":home}

func army(id: int, at: String, strength: int) -> Dictionary:
	return {"id":id,"province":at,"strength":strength,"upkeep":2,"morale":100}

func _march_cleanup() -> void:
	for retained in [false,true]:
		var f = fixture()
		var game = f.game
		if retained: game.house().armies.append(army(8,TARGET,200))
		check(game.march_army(f.home).ok,"Real own neighbor permits departure from siege")
		check(int(game.province(TARGET).siege)==(45 if retained else 0),"Land departure keeps only genuinely supported progress")
		check(int(game.province(TARGET).siege_owner)==(2 if retained else -1),"Land departure clears unsupported besieger identity")
		if retained:
			check(str(game.house().armies[1].province)==TARGET and int(game.house().armies[1].strength)==200,"Unselected surviving support is unchanged")

func _destroyed_cleanup() -> void:
	for retained in [false,true]:
		var f = fixture()
		var game = f.game
		game.army_for().strength = 0
		if retained: game.house().armies.append(army(8,TARGET,200))
		game._remove_empty_armies(2)
		check(game.house().armies.size()==(1 if retained else 0),"Empty formation removal preserves only actual survivors")
		check(int(game.province(TARGET).siege)==(45 if retained else 0),"Destroyed final formation cannot keep siege or road interruption alive")

func _peace_cleanup() -> void:
	var f = fixture()
	var game = f.game
	var own := str(f.home)
	game.province(own).siege = 30
	game.province(own).siege_owner = 1
	game.houses[1].armies = [army(3,own,350)]
	var unrelated := "anatolien__01"
	game.province(unrelated).owner = 4
	game.province(unrelated).siege = 17
	game.province(unrelated).siege_owner = 3
	game.houses[3].armies = [army(9,unrelated,100)]
	check(game.make_peace(1,2).ok,"Ordinary public peace succeeds")
	check(int(game.province(TARGET).siege)==0 and int(game.province(TARGET).siege_owner)==-1,"Peace clears own attack on partner despite remaining troops")
	check(int(game.province(own).siege)==0 and int(game.province(own).siege_owner)==-1,"Peace clears reciprocal siege on own province")
	check(int(game.province(unrelated).siege)==17 and int(game.province(unrelated).siege_owner)==3,"Peace does not erase unrelated actual warfare")
	var after: Dictionary = game.snapshot()
	check(not game.make_peace(1,2).ok and game.snapshot()==after,"Duplicate peace is pure and cannot clear other state")

func _progress_ownership() -> void:
	var f = fixture()
	var game = f.game
	game.province(TARGET).owner = 3
	game.province(TARGET).siege = 85
	game.province(TARGET).siege_owner = 1
	game.houses[1].armies = [army(3,TARGET,500)]
	var before: Dictionary = game.snapshot()
	seed(4451)
	var expected := randf()
	seed(4451)
	check(not game.advance_siege(TARGET,2).ok,"A supported third-house siege cannot be stolen")
	check(game.snapshot()==before and randf()==expected,"Rejected progress theft preserves full state and random sequence")
	f = fixture()
	game = f.game
	game.province(TARGET).owner = 3
	game.province(TARGET).siege = 85
	game.province(TARGET).siege_owner = 1
	game.houses[1].armies = []
	check(game.advance_siege(TARGET,2).ok,"New besieger can begin after former force disappeared")
	check(int(game.province(TARGET).owner)==3 and int(game.province(TARGET).siege)>0 and int(game.province(TARGET).siege)<85,"Unsupported85percent never becomes free capture for another house")
	check(int(game.province(TARGET).siege_owner)==2,"New progress belongs to actual newly acting house")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("SIEGELIFECYCLETEST FAIL: "+label)
