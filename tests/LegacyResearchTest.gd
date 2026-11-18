extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
const PATH := "res://tests/fixtures/ari190-campaign-schema16-original.json"
const HASH := "8c767fa3e3f157bf8c2fa1f707c77e79a99db419fa78cd643782a302338e7ba8"
var checks := 0
var failures := 0

func _ready() -> void:
	check(FileAccess.get_sha256(PATH)==HASH,"Actual Android Ari16 bytes are immutable")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(original.schema_version==16 and original.player==9 and original.houses[9].ruler.name=="Ari190" and original.houses[9].gold==45 and Save.state_equal(original.houses[9].research,{"active":"surveying","known":[],"months":6}),"Actual Code18 profile pins Ari190 and its already-paid six remaining research months")
	test_original_store_and_time(original)
	test_historical_totals(original)
	test_invalid_current_markers(original)
	test_new_starts()
	check(FileAccess.get_sha256(PATH)==HASH,"All cases preserve historical fixture bytes")
	print("LEGACYRESEARCHTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func test_original_store_and_time(original: Dictionary) -> void:
	var before:=original.duplicate(true)
	var result: Dictionary=Save.migrate(original)
	if not check(result.ok and original==before,"Actual Ari16 save migrates without mutating original research or source"): return
	check(result.data.houses[9].research=={"active":"surveying","known":[],"months":6,"legacy_duration":6},"Migration retains six remaining months and records the historical total")
	var projected: Dictionary=result.data.duplicate(true)
	projected.schema_version=16
	check(projected.get("material_trades")==[] and projected.get("trade_serial")==0,"Ari16 migration adds only empty trade bookkeeping without goods or contract")
	projected.erase("material_trades")
	projected.erase("trade_serial")
	projected.erase("project_serial")
	for p in projected.provinces:
		for key in ["production","regional_project","logistics_sites"]: p.erase(key)
	projected.houses[9].research.erase("legacy_duration")
	check(Save.state_equal(projected,original),"Every old Ari world value remains exact apart from additive production and research duration")
	var file_path:="user://ari16-legacy-%d.json" % OS.get_process_id()
	var raw:=FileAccess.get_file_as_bytes(PATH)
	var file:=FileAccess.open(file_path,FileAccess.WRITE)
	file.store_buffer(raw); file.close()
	var loaded: Dictionary=Store.load_snapshot(file_path)
	check(loaded.ok and FileAccess.get_file_as_bytes(file_path)==raw and FileAccess.get_file_as_bytes(file_path+".pre-schema-v16.bak")==raw,"Actual SaveStore keeps original16file and byte-exact backup before migration")
	if not loaded.ok: return
	var game=Game.new(Data,9)
	check(game.restore(JSON.parse_string(JSON.stringify(loaded.data))),"Actual Ari17 restores through JSON without clipped research")
	check(Store.write_snapshot(file_path,game.snapshot()),"Actual migrated Ari17 is saved normally")
	for elapsed in 6:
		var research: Dictionary=game.house().research
		check(int(research.months)==6-elapsed and not research.known.has("surveying"),"Historical surveying does not finish before its actual remaining month"+str(elapsed))
		var choice:=active_choice(game)
		check(int(choice.get("months",0))==6 and int(choice.get("remaining",0))==6-elapsed and int(choice.get("elapsed_months",-1))==elapsed,"Measured UI research choice uses the original six-month denominator")
		var snapshot: Dictionary=game.snapshot()
		var copy=Game.new(Data,9)
		check(not snapshot.is_empty() and Save.validate(snapshot).is_empty() and copy.restore(JSON.parse_string(JSON.stringify(snapshot))) and Save.state_equal(copy.snapshot(),snapshot),"Every historical remaining duration survives exact current JSON roundtrip")
		advance(game)
	check(game.house().research.known.has("surveying") and str(game.house().research.active).is_empty() and int(game.house().research.months)==0 and not game.house().research.has("legacy_duration"),"After exactly six real months surveying completes and removes its legacy marker")
	var gold: int=game.house().gold
	check(game.start_research("road_building").ok and int(game.house().gold)==gold-40 and int(game.house().research.months)==6 and not game.house().research.has("legacy_duration"),"Next normally paid research uses the new duration and no stale marker")

func test_historical_totals(original: Dictionary) -> void:
	# Controlled research prerequisites/dates are format cases, not claimed as a
	# second genuine Android capture or a normally financed campaign.
	for values in [["surveying",6,[]],["road_building",12,["surveying"]],["logistics",10,["surveying","road_building"]]]:
		for remaining in [int(values[1]),3]:
			var state:=original.duplicate(true)
			state.houses[9].research={"active":values[0],"known":values[2].duplicate(),"months":remaining}
			var result: Dictionary=Save.migrate(state)
			if not check(result.ok,"Controlled historical active research keeps its bounded original duration: "+str(values[0])): continue
			check(int(result.data.houses[9].research.months)==remaining and int(result.data.houses[9].research.get("legacy_duration",0))==int(values[1]),"Old partial progress retains the old denominator even below the new duration")
			var game=Game.new(Data,9)
			if not check(game.restore(result.data),"Controlled historical research restores"): continue
			for month in remaining-1: advance(game)
			check(str(game.house().research.active)==str(values[0]) and int(game.house().research.months)==1,"Historical project survives all but the final actual remaining month")
			advance(game)
			check(game.house().research.known.has(values[0]) and not game.house().research.has("legacy_duration"),"Historical project completes exactly once at its remaining deadline")
	var boundary:=original.duplicate(true)
	boundary.year=-1; boundary.month=12; boundary.month_index=23999
	var result: Dictionary=Save.migrate(boundary)
	if check(result.ok,"Controlled December1BCE legacy research date remains valid"):
		var game=Game.new(Data,9)
		if game.restore(result.data):
			advance(game)
			check(int(game.year)==1 and int(game.month)==1 and int(game.calendar_index())==24000 and int(game.house().research.months)==5,"Calendar skips yearzero without shortening active legacy research")

func current(original: Dictionary) -> Dictionary:
	var state:=original.duplicate(true)
	state.schema_version=Save.CURRENT_VERSION
	state["material_trades"]=[]
	state["trade_serial"]=0
	state["project_serial"]=0
	for p in state.provinces:
		p["production"]={"materials_u":0,"rate_carry":0}
		p["regional_project"]={}
		p["logistics_sites"]={"depot":0}
	state.houses[9].research.months=3
	state.houses[9].research["legacy_duration"]=6
	return state

func test_invalid_current_markers(original: Dictionary) -> void:
	var valid:=current(original)
	check(Save.migrate(valid).ok and Save.validate(valid).is_empty(),"Valid current historical marker is retained")
	for marker in [0,4,7,true,"6",null,6.5,NAN,INF]:
		var bad:=current(original)
		bad.houses[9].research.legacy_duration=marker
		check(not Save.migrate(bad).ok and not Save.validate(bad).is_empty(),"Invalid current legacy denominator rejects: "+str(marker))
	for variant in ["inactive","unchanged_id","already_known","missing_active","missing_months","too_many","zero","unmarked_old"]:
		var bad:=current(original)
		match variant:
			"inactive": bad.houses[9].research.active=""; bad.houses[9].research.months=0
			"unchanged_id": bad.houses[9].research.active="accounting"; bad.houses[9].research.known=["surveying"]
			"already_known": bad.houses[9].research.known=["surveying"]
			"missing_active": bad.houses[9].research.erase("active")
			"missing_months": bad.houses[9].research.erase("months")
			"too_many": bad.houses[9].research.months=7
			"zero": bad.houses[9].research.months=0
			"unmarked_old": bad.houses[9].research.erase("legacy_duration"); bad.houses[9].research.months=5
		check(not Save.migrate(bad).ok and not Save.validate(bad).is_empty(),"Invalid current legacy research state rejects: "+variant)

func test_new_starts() -> void:
	seed(20261118)
	var game=Game.new(Data,0)
	for values in [["surveying",4,20],["road_building",6,40],["logistics",6,55]]:
		var gold: int=game.house().gold
		if not check(game.start_research(str(values[0])).ok,"Ordinary new research starts from real available treasury: "+str(values[0])): return
		check(int(game.house().gold)==gold-int(values[2]) and int(game.house().research.months)==int(values[1]) and not game.house().research.has("legacy_duration"),"New research has current duration, one real payment and no legacy marker")
		for i in int(values[1])-1: advance(game)
		check(str(game.house().research.active)==str(values[0]),"New research also cannot finish early")
		advance(game)
		check(game.house().research.known.has(values[0]),"New research completes at current duration")

func active_choice(game) -> Dictionary:
	for choice in game.research_choices():
		if bool(choice.active): return choice
	return {}

func advance(game) -> void:
	game.advance_month()
	if game.pending_event==null: return
	if game.event_decline_reason().is_empty(): game.decline_event(); return
	for option in game.pending_event.options.size():
		if game.event_option_reason(option).is_empty() and int(game.pending_event.options[option].effects.get("gold",0))==0: game.apply_event(option); return
	for option in game.pending_event.options.size():
		if game.event_option_reason(option).is_empty(): game.apply_event(option); return

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("LEGACYRESEARCHTEST FAIL: "+message)
	return ok
