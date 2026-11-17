extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/Data.gd")
var checks := 0
var failures := 0
func _ready() -> void:
	var g = Game.new(Data)
	var target := ""
	var home := ""
	for p in g.owned():
		for n in g.neighbours(p.id):
			if g.province(n).owner != 0: home=p.id;target=n
	assert(target != "")
	g._add_claim(0,target)
	g.house().armies=[{"id":1,"province":home,"strength":1000,"upkeep":1,"morale":100}]
	var r=g.advance_siege(target)
	check(r.ok,"Valid neighboring siege")
	var progress=g.province(target).siege
	check(not g.advance_siege(target).ok,"Double click must not add progress")
	check(g.province(target).siege==progress,"No duplicate progress")
	check(g.has_method("can_siege"),"UI can query siege")
	var snapshot=g.snapshot()
	var fresh=Game.new(Data)
	check(fresh.restore(snapshot),"Roundtrip works")
	check(not fresh.advance_siege(target).ok,"Save cannot bypass rate limit")
	for value in [-1,1.5,99999,"bad"]:
		var bad=snapshot.duplicate(true)
		bad.houses[0].armies[0].last_siege_month=value
		check(not fresh.restore(bad),"Invalid siege date rejected")
	check(not g.can_siege("missing"),"Unknown target")
	check(not g.can_siege(target,999),"Unknown house")
	g.house().gold=0
	check(not g.advance_siege(target).ok,"No extra action in same month")
	g.month+=1
	check(g.advance_siege(target).ok,"Next month no gold required")
	g.province(target).siege=0
	g.opinion[int(g.province(target).owner)]=60
	check(not g.advance_siege(target).ok,"Friendly owner")
	g.opinion[int(g.province(target).owner)]=0
	g.month+=1
	g.house().truces[str(g.province(target).owner)]=g._now()+24
	check(not g.can_siege(target),"Truce cannot be bypassed")
	g.house().truces={}
	g.house().armies[0].morale=0
	check(not g.can_siege(target),"Demoralized army")
	g.house().armies[0].morale=100
	g.house().armies[0].strength=0
	check(not g.can_siege(target),"Empty army")
	g.house().armies[0].strength=1000
	var remote := ""
	for p in g.provinces:
		if p.owner != 0 and not g.neighbours(home).has(p.id): remote=p.id
	check(not g.advance_siege(remote).ok,"Remote target")
	g._add_claim(0,remote)
	check(not g.advance_siege(remote).ok,"Remote claim no teleport")
	check(g.house().armies[0].province==target,"No remote mutation")
	print("SIEGESAFETYTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;print("SIEGESAFETYTEST FAIL: "+message)
