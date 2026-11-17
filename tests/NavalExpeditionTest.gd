extends Node
## One predeclared seed, ordinary public player commands and every NPC enabled.
## This bounded campaign proves its own path, not long-term balance or all fun.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const SEED := 20261117
const MAX_MONTHS := 240
const HOME := "britannien__03"
const TARGET := "gallien__04"
var checks := 0
var failures := 0
var game
var proof_dir := "user://naval-expedition"
var journal: Array = []
var advanced := 0
var landed_month := -1
var first_siege_month := -1
var conquered_month := -1
var positive_event_gold := 0
var initial_npcs: Array = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--proof-dir="):
			proof_dir = argument.trim_prefix("--proof-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(proof_dir))
	seed(SEED)
	game = Game.new(Data,2)
	initial_npcs = _npcs()
	check(int(game.house().gold)==120 and str(game.house().capital)==HOME,"Unmodified Wessex starts at actual London capital with120gold")
	check(game.army_for().is_empty() and game.fleet_for().is_empty(),"Regular start has no free expedition units")
	check(game.human_houses.is_empty() and game.disabled_edges.is_empty() and game.attack_roll_override<0,"Every other house remains NPC and every rule/random roll stays enabled")
	_write_json("initial-world.json",game.snapshot())
	var before := _state()
	var result: Dictionary = game.raise_army(HOME)
	_record("raise_army",before,{"result":result})
	check(result.ok and int(game.house().gold)==70 and int(game.army_for().strength)==438,"Public army purchase pays50 from120 and raises438 soldiers")
	before = _state()
	result = game.raise_fleet(HOME)
	_record("raise_fleet",before,{"result":result})
	check(result.ok and int(game.house().gold)==10 and int(game.fleet_for().ships)==18,"Public escort purchase pays60 leaving10gold and18 ships")
	check(not game.claim_reason(TARGET).is_empty(),"The remaining10gold cannot buy the40gold claim")
	_record("start_claim_blocked",_state(),{"reason":game.claim_reason(TARGET)})
	for step in MAX_MONTHS+1:
		if game.game_over: break
		_resolve_event()
		if int(game.province(TARGET).owner)==2:
			conquered_month = game._now()
			break
		if landed_month<0:
			_prepare_and_cross()
		else:
			_besiege()
		if int(game.province(TARGET).owner)==2:
			conquered_month = game._now()
			break
		if step==MAX_MONTHS: break
		before = _state()
		game.advance_month()
		advanced += 1
		_record("advance_month",before,{"npc_state":_npcs(),"effect_window":game.effect_log.duplicate(true),"notes":game.log_lines.duplicate()})
	check(landed_month>0,"The fixed-seed regular campaign actually lands before the240month observation limit")
	check(first_siege_month>landed_month and landed_month>0,"Real siege progress begins in a later month than the real landing")
	check(conquered_month>first_siege_month and first_siege_month>0,"This declared campaign completes the ordinary conquest after actual siege turns")
	var final_npcs := _npcs()
	var changed_npcs := 0
	for i in final_npcs.size():
		if final_npcs[i]!=initial_npcs[i]: changed_npcs += 1
	check(changed_npcs==8 and advanced>0,"All eight other houses actually evolve during ordinary world months")
	var booked_gold := 120
	for entry in journal: booked_gold += int(entry.gold_delta)
	check(booked_gold==int(game.house().gold),"Complete action/month/event ledger reconciles initial120gold to the real final treasury")
	check(game.human_houses.is_empty() and game.disabled_edges.is_empty() and game.attack_roll_override<0,"NPCs and random combat are still unmodified at the final checkpoint")
	_write_json("final-world.json",game.snapshot())
	var report := {"scenario":"regular-wessex-expedition","seed":SEED,"max_observation_months":MAX_MONTHS,"advanced_months":advanced,"checks_before_report_write":checks,"failures_before_report_write":failures,"landed_month":landed_month,"first_siege_month":first_siege_month,"conquered_month":conquered_month,"positive_event_gold":positive_event_gold,"npc_count":game.houses.size()-1,"changed_npc_count":changed_npcs,"ledger_final_gold":booked_gold,"final":_state(),"npc_state":final_npcs,"journal":journal,"scope":"One legal headless Game campaign; no Main, GPU, device, resource injection, RNG override, NPC disable or ownership edits. Not an overall gameplay/balance acceptance."}
	_write_json("campaign.json",report)
	print("NAVALEXPEDITIONTEST SUMMARY ",JSON.stringify({"seed":SEED,"advanced_months":advanced,"landed_month":landed_month,"first_siege_month":first_siege_month,"conquered_month":conquered_month,"positive_event_gold":positive_event_gold,"final":_state()}))
	print("NAVALEXPEDITIONTEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func _prepare_and_cross() -> void:
	if game.army_for().is_empty() and int(game.house().gold)>=50:
		var before := _state()
		var result: Dictionary = game.raise_army(HOME)
		_record("replace_lost_army",before,{"result":result})
	if game.fleet_for().is_empty() and game.can_raise_fleet(HOME):
		var before := _state()
		var result: Dictionary = game.raise_fleet(HOME)
		_record("replace_lost_escort",before,{"result":result})
	if not game.has_claim(TARGET):
		var reason: String = game.claim_reason(TARGET)
		if not reason.is_empty():
			_record("claim_wait",_state(),{"reason":reason})
			return
		var before := _state()
		var result: Dictionary = game.fabricate_claim(TARGET)
		_record("fabricate_claim",before,{"result":result})
		check(result.ok and int(game.house().gold)==int(before.gold)-40,"A real foreign coastal claim is paid40gold from earned/event funds")
	var preview: Dictionary = game.naval_transport_preview(TARGET)
	if not preview.ok:
		_record("crossing_wait",_state(),{"preview":preview})
		return
	var before := _state()
	var result: Dictionary = game.transport_army(TARGET)
	_record("transport_army",before,{"result":result,"preview":preview})
	check(result.ok,"An available ordinary crossing resolves through the public command")
	if not bool(result.get("landed",false)): return
	landed_month = game._now()
	check(int(game.province(TARGET).owner)==int(before.target_owner) and int(game.province(TARGET).siege)==0,"First landing changes neither the actual foreign owner nor zero siege progress")
	check(str(game.army_for().province)==TARGET and str(game.fleet_for().province)==TARGET and str(game.fleet_for().station)==TARGET,"The paid army and original escort actually arrive together")
	check(int(game.house().gold)==int(before.gold),"Ordinary transport charges no hidden extra gold")
	check(int(game.army_for().get("last_siege_month",-1))==landed_month and int(game.fleet_for().get("last_naval_month",-1))==landed_month,"Real landing consumes both offensive monthly actions")
	var landed: Dictionary = game.snapshot()
	var siege: Dictionary = game.advance_siege(TARGET)
	var blockade: Dictionary = game.blockade(TARGET)
	var back: Dictionary = game.transport_army(HOME)
	check(not siege.ok and not blockade.ok and not back.ok and game.snapshot()==landed,"Siege, blockade and return are blocked without world mutation in the landing month")
	_record("same_month_guards",_state(),{"siege":siege,"blockade":blockade,"return":back})
	_write_json("landed-world.json",landed)
	var decoded = JSON.parse_string(FileAccess.get_file_as_string(proof_dir+"/landed-world.json"))
	var restored = Game.new(Data,2)
	if check(decoded is Dictionary and restored.restore(decoded),"Actual landing file is read through JSON and restored into a new Game"):
		check(Save.state_equal(restored.snapshot(),landed),"The whole real landing world survives file/JSON/runtime restore")
		game = restored
		check(int(game.army_for().get("last_siege_month",-1))==landed_month and int(game.fleet_for().get("last_naval_month",-1))==landed_month,"Both actual used monthly guards survive the restore path")
		var loaded_state: Dictionary = game.snapshot()
		check(not game.advance_siege(TARGET).ok and not game.blockade(TARGET).ok and not game.transport_army(HOME).ok and game.snapshot()==loaded_state,"Restored runtime really blocks the same-month siege, blockade and return without mutation")
		_record("resume_landing_json",_state(),{})

func _besiege() -> void:
	if str(game.army_for().get("province",""))!=TARGET:
		_record("siege_wait",_state(),{"reason":"No surviving army remains on the actual landing province."})
		return
	var reason: String = game.siege_reason(TARGET)
	if not reason.is_empty():
		_record("siege_wait",_state(),{"reason":reason})
		return
	var before := _state()
	var result: Dictionary = game.advance_siege(TARGET)
	_record("advance_siege",before,{"result":result})
	check(result.ok,"An actual available later-month siege uses the public command")
	if first_siege_month<0 and result.ok and (int(game.province(TARGET).siege)>int(before.target_siege) or int(game.province(TARGET).owner)==2):
		first_siege_month = game._now()
		check(first_siege_month>landed_month,"First actual siege progress is later than the landing, never granted by crossing")
	if int(game.province(TARGET).owner)==2:
		conquered_month = game._now()
		check(int(game.province(TARGET).siege)==0 and not game.has_claim(TARGET),"Ordinary completed siege captures the province and consumes its claim")

func _resolve_event() -> void:
	if game.pending_event==null: return
	var event: Dictionary = game.pending_event.duplicate(true)
	var selected := -1
	var best_reward := true
	var best_gold := 0
	for index in event.options.size():
		if not game.event_option_reason(index).is_empty(): continue
		var gold := int(event.options[index].get("effects",{}).get("gold",0))
		var reward := gold>0
		if selected<0 or (best_reward and not reward) or (reward==best_reward and ((reward and gold<best_gold) or (not reward and gold>best_gold))):
			selected = index
			best_reward = reward
			best_gold = gold
	var before := _state()
	var result: Dictionary
	if selected<0:
		result = game.decline_event()
	else:
		result = game.apply_event(selected)
		if result.ok: positive_event_gold += maxi(0,best_gold)
	_record("event_decision",before,{"event":event,"selected_index":selected,"policy":"Prefer any affordable nonreward; within nonrewards minimize gold cost; otherwise smallest legal positive gold reward; if all options unaffordable use public decline.","result":result})
	check(result.ok and game.pending_event==null,"Pending event is resolved through an affordable original choice or legal decline")

func _state() -> Dictionary:
	return {"year":game.year,"month":game.month,"action_month":game._now(),"gold":int(game.house().gold),"army":game.army_for().duplicate(true),"fleet":game.fleet_for().duplicate(true),"claim_active":game.has_claim(TARGET),"target_owner":int(game.province(TARGET).owner),"target_siege":int(game.province(TARGET).siege),"home_owner":int(game.province(HOME).owner),"home_blockade":int(game.province(HOME).blockade),"target_blockade":int(game.province(TARGET).blockade),"game_over":game.game_over}

func _npcs() -> Array:
	var result: Array = []
	for i in game.houses.size():
		if i==2: continue
		var h: Dictionary = game.houses[i]
		var own: Array = []
		for province in game.provinces:
			if int(province.owner)==i: own.append(str(province.id))
		result.append({"house":i,"name":h.name,"gold":int(h.gold),"armies":h.armies.duplicate(true),"fleets":h.fleets.duplicate(true),"claims":h.claims.duplicate(true),"owned":own})
	return result

func _record(kind: String, before: Dictionary, details: Dictionary) -> void:
	var entry := {"kind":kind,"before":before,"after":_state(),"gold_delta":int(game.house().gold)-int(before.gold),"details":details}
	journal.append(entry)
	print("EXPEDITION ",JSON.stringify({"kind":kind,"month":game._now(),"gold":game.house().gold,"gold_delta":entry.gold_delta,"detail":details.get("reason",details.get("result",{}))}))

func _write_json(name: String, data) -> void:
	var file := FileAccess.open(proof_dir+"/"+name,FileAccess.WRITE)
	if not check(file!=null,"Proof file opens: "+name): return
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	check(file.get_error()==OK,"Proof file writes completely: "+name)
	file.close()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALEXPEDITIONTEST FAIL: "+label)
	return ok
