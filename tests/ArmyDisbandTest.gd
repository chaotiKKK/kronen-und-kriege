extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const HOME := "britannien__03"
var Recovery
var checks := 0
var failures := 0
func _ready() -> void:
	Recovery = load("res://scripts/ArmyRecovery.gd")
	var available := false
	for method in Recovery.get_script_method_list():
		if str(method.name)=="disband_preview": available=true
	check(available,"Pure disband forecast is missing")
	if available: _cases()
	print("ARMYDISBANDTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
func fixture():
	var game = Game.new(Data,0)
	game.houses[2].armies = [{"id":7,"province":HOME,"strength":400,"upkeep":1,"morale":100}]
	return game
func preview(game, location: String=HOME, hi: int=2) -> Dictionary:
	var before: Dictionary = game.snapshot()
	var raw: Array = game.houses.duplicate(true)
	seed(6614)
	var expected := randf()
	seed(6614)
	var result: Dictionary = Recovery.disband_preview(game,location,hi)
	check(game.snapshot()==before and game.houses==raw and randf()==expected,"Disband forecast preserves raw state/snapshot/RNG")
	return result
func _cases() -> void:
	var game = fixture()
	var result := preview(game)
	check(result.ok and int(result.army_id)==7 and str(result.origin)==HOME and int(result.strength)==400 and int(result.morale)==100,"A healthy unused army at its own actual station can be disbanded")
	game.army_for(2).morale=0
	check(preview(game).ok,"A demoralized own formation may stand down")
	game.army_for(2).last_siege_month=game._now()
	check(not preview(game).ok,"Spent army cannot be disbanded to reset its monthly action")
	game=fixture()
	check(not preview(game,"britannien__02").ok,"Another own province does not remotely remove the army")
	check(not preview(game,"gallien__04").ok,"Foreign selected province cannot remove an own army")
	check(not preview(game,"missing").ok,"Unknown selected province is rejected")
	check(not preview(game,HOME,-2).ok and not preview(game,HOME,999).ok,"Invalid explicit actors are rejected")
	check(not preview(game,HOME,-1).ok,"Default actor does not borrow inactive house2 army")
	game.province(HOME).siege=20
	game.province(HOME).siege_owner=1
	check(not preview(game).ok,"Hostile siege blocks standing down")
	game=fixture()
	game.province(HOME).blockade=2
	game.province(HOME).blockade_owner=1
	check(not preview(game).ok,"Hostile blockade blocks standing down")
	game=fixture()
	game.houses[1].armies=[{"id":3,"province":HOME,"strength":100,"upkeep":1,"morale":100}]
	check(not preview(game).ok,"Actual foreign combat formation blocks standing down")
	game.houses[1].armies[0].morale=0
	check(preview(game).ok,"Noncombat foreign remnant does not block standing down")
	game=fixture()
	game.houses[2].armies.append({"id":7,"province":"britannien__02","strength":100,"upkeep":1,"morale":100})
	check(not preview(game).ok,"Ambiguous selected identity cannot be confirmed for removal")
	game=fixture()
	game.army_for(2).strength=0
	check(not preview(game).ok,"An empty record is handled by ordinary cleanup, not a paid or confirmed army action")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("ARMYDISBANDTEST FAIL: "+label)
