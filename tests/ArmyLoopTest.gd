extends Node
const Game=preload("res://scripts/Game.gd")
const Data=preload("res://scripts/Data.gd")
var checks:=0
var failures:=0
func _ready() -> void:
	var g=Game.new(Data)
	if not g.has_method("can_march"):
		check(false,"Army missing")
		finish()
		return
	g.house().gold=1000
	check(g.raise_army(g.house().capital).ok,"raise")
	check(not g.raise_army(g.house().capital).ok,"duplicate")
	var home=g.army_for().province
	var next=""
	for n in g.neighbours(home):
		if g.province(n).owner==0: next=n
	check(next!="","fixture")
	check(g.can_march(next),"next")
	check(g.march_army(next).ok,"move")
	check(not g.march_army(home).ok,"same month")
	var s=g.snapshot()
	var h=Game.new(Data)
	check(h.restore(s),"roundtrip")
	check(not h.march_army(home).ok,"save")
	check(h.has_method("attack_preview"),"preview")
	check(h.fabricate_claim(home).ok==false,"own")
	var foreign=""
	for p in g.provinces:
		if p.owner!=0:foreign=p.id
	g._add_claim(0,foreign)
	check(not g.fabricate_claim(foreign).ok,"duplicate")
	print("ARMYLOOPTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1
func finish() -> void:
	print("ARMYLOOPTEST FAIL")
	get_tree().quit(1)
