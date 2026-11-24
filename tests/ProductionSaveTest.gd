extends Node
## Genuine published schema16 bytes; production/project variations are controlled clones.
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
const Migration = preload("res://scripts/RegionMigration.gd")
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Legacy = preload("res://scripts/Data.gd")
const Session = preload("res://scripts/LanSession.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
const PATH := "res://tests/fixtures/lan-191-campaign-schema16-original.json"
const HASH := "2e2b8befa58ef22ec3547221af2b4a059d4b09df6264a028a012eb9aac563e40"
const FINGERPRINT := "dc8f13abb2f9b93c1aabfcf115f592df02c8af9ceb2b445127bdcefd22fd3903"
const SUFFIX := ".pre-production-schema16.bak"
const PRODUCTION17_PATH := "res://tests/fixtures/lan-191-production-schema17-original.json"
const PRODUCTION17_HASH := "3c4185cd09c17bb4098698aba3ea1cb23e06c3393d4f081d31a6a8f9be7a1596"
class ProductionIdentityVariant extends Session:
	func _production_rules() -> Dictionary:
		var rules: Dictionary = super._production_rules().duplicate(true)
		rules.regional.algorithm_version = int(rules.regional.algorithm_version)+1
		return rules
class TransportIdentityVariant extends Session:
	func _production_rules() -> Dictionary:
		var rules: Dictionary = super._production_rules().duplicate(true)
		rules.transport.algorithm_version = int(rules.transport.algorithm_version)+1
		return rules
class DepotIdentityVariant extends Session:
	func _production_rules() -> Dictionary:
		var rules: Dictionary = super._production_rules().duplicate(true)
		rules.depot.depot_men_per_weight = int(rules.depot.depot_men_per_weight)+1
		return rules
class GameIdentityVariant extends Session:
	func _production_rules() -> Dictionary:
		var rules: Dictionary = super._production_rules().duplicate(true)
		rules.game["controlled_policy_version"] = 2
		return rules
class EconomyPlannerIdentityVariant extends Session:
	func _production_rules() -> Dictionary:
		var rules: Dictionary = super._production_rules().duplicate(true)
		if rules.get("economy_planner") is Dictionary:
			rules.economy_planner.minimum_military_reserve = int(rules.economy_planner.minimum_military_reserve)+1
		return rules
var checks := 0
var failures := 0
var stem := ""

func _ready() -> void:
	stem = "user://production-save-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(FileAccess.get_sha256(PATH)==HASH,"Published campaign16 original remains byte-identical")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(original.state.schema_version==16 and original.app=="1.9.1" and original.v==3 and original.fingerprint==FINGERPRINT,"Actual source bytes identify the supported16family")
	_test_legacy_defaults(original.state)
	_test_previous_production_defaults(original.state)
	_test_current_roundtrip(original.state)
	_test_develop_event_roundtrip()
	_test_project_kinds(original.state)
	_test_raw_rejections(original.state)
	_test_roads(original.state)
	_test_layout()
	_test_legacy_road_graph()
	_test_store(original.state)
	_test_wire_commands()
	_test_fingerprints()
	_test_serialization(original.state)
	check(FileAccess.get_sha256(PATH)==HASH,"Controlled cases leave immutable historical bytes unchanged")
	print("PRODUCTIONSAVETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func _current(source: Dictionary) -> Dictionary:
	var state := _production17(source)
	state.schema_version = Save.CURRENT_VERSION
	state["provisioning_report"]={"month_index":-1,"regions":{}}
	for p in state.provinces: p["provisioning"]=load("res://scripts/CivicProvision.gd").initial_state(p)
	state["material_trades"] = []
	state["trade_serial"] = 0
	return state

func _production17(source: Dictionary) -> Dictionary:
	var state := source.duplicate(true)
	state.schema_version = 17
	state["project_serial"] = 0
	for p in state.provinces:
		p["production"] = {"materials_u":0,"rate_carry":0}
		p["regional_project"] = {}
		p["logistics_sites"] = {"depot":0}
	for road in state.roads:
		road["construction"] = {}
		if str(road.state)=="building": road["legacy_construction"] = true
	return state

func _project() -> Dictionary:
	# First genuine region has economic_share2.23582040167903: weight2235820.
	# Market1 costs6weights material/4weights work. Quarter progress uses3353730.
	return {"id":7,"builder":6,"kind":"market","target_level":1,"paid_gold":134,
		"material_total_u":13414920,"material_spent_u":3353730,"work_total_u":8943280,"work_done_u":2235820,
		"priority":0,"started_month":0}

func _active(source: Dictionary) -> Dictionary:
	var state := _current(source)
	state.project_serial = 9
	state.provinces[0].production = {"materials_u":1234567,"rate_carry":31}
	state.provinces[0].regional_project = _project()
	state.provinces[1].logistics_sites.depot = 1
	return state

func _without_production(state: Dictionary) -> Dictionary:
	var out := _without_trade(state)
	out.schema_version = 16
	out.erase("project_serial")
	for p in out.provinces:
		for key in ["production","regional_project","logistics_sites"]: p.erase(key)
	for road in out.get("roads",[]):
		road.erase("construction")
		road.erase("legacy_construction")
	return out

func _without_trade(state: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	out.schema_version = 17
	out.erase("material_trades")
	out.erase("trade_serial")
	out.erase("provisioning_report")
	for p in out.provinces: p.erase("provisioning")
	return out

func _test_legacy_defaults(source: Dictionary) -> void:
	var before := source.duplicate(true)
	var result: Dictionary = Save.migrate(source)
	check(result.ok and source==before,"Migration reads genuine16source without mutation")
	if not result.ok: return
	check(result.data.schema_version==Save.CURRENT_VERSION,"Genuine16migration advances to the current schema")
	check(result.data.get("material_trades")==[] and result.data.get("trade_serial")==0,"Genuine16migration creates no trade contract, payment or consumed trade ID")
	check(result.data.get("project_serial",-1)==0,"No historical job IDs are invented")
	var defaults := true
	for p in result.data.provinces:
		defaults = defaults and p.get("production")=={"materials_u":0,"rate_carry":0} and p.get("regional_project")=={} and p.get("logistics_sites")=={"depot":0}
	check(defaults,"Every final region receives zero stock, empty project and no depot")
	check(Save.state_equal(_without_production(result.data),source),"Every historical shared/personal field remains exact")
	var second: Dictionary = Save.migrate(result.data)
	check(second.ok and Save.state_equal(second.data,result.data),"Repeated migration cannot grant stock or erase state")
	var present := source.duplicate(true)
	present.project_serial = 9
	present.provinces[0].production = {"materials_u":1234567,"rate_carry":31}
	present.provinces[0].regional_project = _project()
	present.provinces[0].logistics_sites = {"depot":1}
	var retained: Dictionary = Save.migrate(present)
	check(retained.ok and retained.data.provinces[0].get("production")==present.provinces[0].production and retained.data.provinces[0].get("regional_project")==_project(),"Valid present production in an older schema is retained")
	for key in ["production","regional_project","logistics_sites"]:
		var malformed := source.duplicate(true)
		malformed.provinces[0][key] = null
		check(not Save.migrate(malformed).ok,"Malformed present legacy field cannot become a default: "+key)

func _test_previous_production_defaults(source: Dictionary) -> void:
	check(FileAccess.get_sha256(PRODUCTION17_PATH)==PRODUCTION17_HASH,"Unchanged released-PCK synthetic17 reference retains its exact original bytes")
	var envelope: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PRODUCTION17_PATH))
	var previous: Dictionary=envelope.state
	var original: Dictionary=previous.duplicate(true)
	var migrated: Dictionary=Save.migrate(previous)
	check(int(previous.schema_version)==17 and not previous.has("material_trades") and not previous.has("trade_serial"),"Actual published production17 source has no invented trade state")
	check(migrated.ok and previous==original,"Actual production17 migration reads the original state without mutation")
	if migrated.ok:
		check(int(migrated.data.schema_version)==Save.CURRENT_VERSION and migrated.data.material_trades==[] and int(migrated.data.trade_serial)==0,"Actual17 receives an empty trade list and unused serial")
		check(Save.state_equal(_without_trade(migrated.data),previous),"Every actual17 production, research, road, personal and monetary field remains unchanged")
	var active := _production17(source)
	active.project_serial = 9
	active.provinces[0].production = {"materials_u":1234567,"rate_carry":31}
	active.provinces[0].regional_project = _project()
	active.provinces[1].logistics_sites.depot = 1
	var expected: Dictionary=active.duplicate(true)
	var restored: Dictionary=Save.migrate(active)
	check(restored.ok and active==expected,"Controlled partially paid17 project migrates without mutating its source")
	if restored.ok:
		check(restored.data.material_trades==[] and int(restored.data.trade_serial)==0 and Save.state_equal(_without_trade(restored.data),expected),"Active17 stock/carry/recipe/work/paid gold and depot survive exactly, with no trade-created goods")
	check(FileAccess.get_sha256(PRODUCTION17_PATH)==PRODUCTION17_HASH,"Production migration tests leave the archived17 envelope untouched")

func _test_current_roundtrip(source: Dictionary) -> void:
	var state := _active(source)
	var before := state.duplicate(true)
	var result: Dictionary = Save.migrate(state)
	check(result.ok and state==before,"Current partially paid project accepts pure normalization")
	check(Save.validate(state).is_empty(),"Current stock/depot/project structure validates")
	if not result.ok: return
	check(Save.state_equal(result.data,state),"Current stock, carry, frozen project accounting and empty trade state survive unchanged")
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(state))
	var normalized: Dictionary = Save.migrate(json_state)
	if normalized.ok:
		var task: Dictionary = normalized.data.provinces[0].regional_project.duplicate(true)
		task.token = "regional:7"
		var plan: Dictionary = load("res://scripts/RegionalProduction.gd").plan_local(normalized.data.provinces[0],[task],1)
		check(plan.task_updates.size()==1 and int(plan.task_updates[0].work_done_u)>2235820,"JSON-restored integral numbers remain executable by the actual pure planner")
	var game = Game.new(Data,0)
	var restored: bool = game.restore(JSON.parse_string(JSON.stringify(state)))
	check(restored,"Real Game restores current production across JSON numeric types")
	if not restored: return
	var actual: Dictionary = game.snapshot()
	check(not actual.is_empty(),"Current Game snapshot is a nonempty valid state")
	check(Save.state_equal(actual,state),"Real snapshot preserves stock, regional project and separate depot")
	check(not actual.provinces[1].buildings.has("depot"),"Depot never enters the three historical building lines")
	var other = Game.new(Data,0)
	check(other.restore(JSON.parse_string(JSON.stringify(actual))) and Save.state_equal(other.snapshot(),actual),"Second restore is exact and awards no stock/work")
	var projection: Dictionary = game.snapshot_for_player(1)
	var guest = Game.new(Data,1)
	check(guest.restore(JSON.parse_string(JSON.stringify(projection))) and Protocol.world_hash(guest.snapshot())==Protocol.world_hash(actual),"Guest projection restores the same shared production hash")

func _test_project_kinds(source: Dictionary) -> void:
	# Independent literal requirements for the first real weight2235820region.
	for values in [["market",1,13414920,8943280],["barracks",1,17886560,11179100],["walls",1,22358200,13414920],["develop",5,17886560,17886560],["depot",1,17886560,13414920]]:
		var state := _active(source)
		var project: Dictionary = state.provinces[0].regional_project
		project.kind = values[0]
		project.target_level = values[1]
		project.material_total_u = values[2]
		project.material_spent_u = 0
		project.work_total_u = values[3]
		project.work_done_u = 0
		if str(values[0])=="depot": state.houses[6].research.known = ["surveying","road_building","logistics"]
		check(Save.migrate(state).ok and Save.validate(state).is_empty(),"Every real project kind preserves its frozen requirements: "+str(values[0]))
		project.material_total_u = int(project.material_total_u)+1
		_reject(state,"Changed frozen recipe rejects: "+str(values[0]))
	var locked := _active(source)
	locked.provinces[0].regional_project.kind = "depot"
	locked.provinces[0].regional_project.material_total_u = 17886560
	locked.provinces[0].regional_project.material_spent_u = 0
	locked.provinces[0].regional_project.work_total_u = 13414920
	locked.provinces[0].regional_project.work_done_u = 0
	_reject(locked,"Active depot requires its builder's existing logistics unlock")

func _test_develop_event_roundtrip() -> void:
	# Real event dispatch changes the first owned province. Its paid project keeps
	# the start-time reference for the recipe rather than claiming the live level.
	for delta in [1,-1]:
		seed(17180)
		var game = Game.new(Data,0)
		var owned: Array = game.owned()
		if not check(not owned.is_empty(),"Actual development/event case has an owned province"): continue
		var p: Dictionary = owned[0]
		var id := str(p.id)
		var start_dev := int(p.dev)
		var started: Dictionary = game.start_regional_project(id,"develop")
		if not check(started.ok,"Actual first-owned development starts from normal treasury: "+str(delta)): continue
		var frozen: Dictionary = p.regional_project.duplicate(true)
		var paid_gold := int(game.house().gold)
		game._apply_effects({"dev":delta})
		check(int(p.dev)==start_dev+delta and p.regional_project==frozen and int(game.house().gold)==paid_gold,"Ordinary development event changes only live development and keeps its paid project: "+str(delta))
		var state: Dictionary = game.snapshot()
		check(not state.is_empty() and Save.validate(state).is_empty(),"Development event leaves a nonempty valid current snapshot: "+str(delta))
		var restored = Game.new(Data,0)
		var loaded: bool = restored.restore(JSON.parse_string(JSON.stringify(state)))
		check(loaded,"Actual development/event snapshot restores across JSON: "+str(delta))
		if loaded:
			check(int(restored.province(id).dev)==start_dev+delta and Save.state_equal(restored.province(id).regional_project,frozen) and int(restored.house().gold)==paid_gold,"JSON restore keeps changed live development, frozen reference and single payment: "+str(delta))
			check(Save.state_equal(restored.snapshot(),state),"Repeated save after development event is exact: "+str(delta))
		for stored_dev in [10,12]:
			var controlled := state.duplicate(true)
			for region in controlled.provinces:
				if str(region.id)==id: region.dev=stored_dev
			var normalized: Dictionary = Save.migrate(controlled)
			check(normalized.ok and Save.validate(controlled).is_empty(),"Frozen development reference remains valid with controlled current level"+str(stored_dev))
		for invalid_reference in [0,11,1.5]:
			var bad := state.duplicate(true)
			for region in bad.provinces:
				if str(region.id)==id: region.regional_project.target_level=invalid_reference
			check(not Save.migrate(bad).ok,"Development start reference remains bounded and integral: "+str(invalid_reference))

func _reject(state: Dictionary, label: String) -> void:
	check(not Save.migrate(state).ok and not Save.validate(state).is_empty(),label)
	var game = Game.new(Data,0)
	var before: Dictionary = game.snapshot()
	check(not game.restore(state) and Protocol.world_hash(game.snapshot())==Protocol.world_hash(before),"Rejected restore preserves shared world: "+label)

func _test_raw_rejections(source: Dictionary) -> void:
	for key in ["production","regional_project","logistics_sites"]:
		var missing := _current(source)
		missing.provinces[0].erase(key)
		_reject(missing,"Missing current province field rejects before defaults: "+key)
	var missing_serial := _current(source)
	missing_serial.erase("project_serial")
	_reject(missing_serial,"Missing current global serial rejects")
	for field in ["materials_u","rate_carry"]:
		for value in [-1,0.5,true,"1",null,NAN,INF,1000000000001 if field=="materials_u" else 32]:
			var bad := _current(source)
			bad.provinces[0].production[field] = value
			_reject(bad,"Invalid production "+field+": "+str(value))
	for field in _project():
		var missing := _active(source)
		missing.provinces[0].regional_project.erase(field)
		_reject(missing,"Missing current frozen project field rejects: "+str(field))
	for pair in [["id",0],["id",1000000001],["builder",0],["kind","unknown"],["target_level",2],["paid_gold",-1],["material_total_u",1000000000001],["material_spent_u",0],["work_total_u",0],["work_done_u",8943280],["priority",2],["started_month",1]]:
		var bad := _active(source)
		bad.provinces[0].regional_project[pair[0]] = pair[1]
		_reject(bad,"Invalid project relation: "+str(pair))
	var stale := _active(source)
	stale.project_serial = 6
	_reject(stale,"Global serial cannot be below activeID")
	var exhausted := _current(source)
	exhausted.project_serial = 1000000001
	_reject(exhausted,"Global serial is bounded")
	var exact_serial := _active(source)
	exact_serial.project_serial = 7
	check(Save.migrate(exact_serial).ok,"Global serial may equal the greatest activeID")
	var misplaced := _current(source)
	misplaced.provinces[0].buildings.depot = 1
	_reject(misplaced,"A misplaced fourth building cannot silently lose a depot")
	var duplicate := _active(source)
	duplicate.provinces[1].regional_project = _project()
	duplicate.provinces[1].regional_project.builder = duplicate.provinces[1].owner
	_reject(duplicate,"Regional IDs are globally unique")
	for value in [-1,2,true,"1",null]:
		var bad := _current(source)
		bad.provinces[0].logistics_sites.depot = value
		_reject(bad,"Invalid separate depot: "+str(value))
	for value in [true,"17",17.5,"18",18.5,INF]:
		var bad := _current(source)
		bad.schema_version = value
		_reject(bad,"Schema type cannot evade raw current checks: "+str(value))

func _test_roads(source: Dictionary) -> void:
	for remaining in [1,2,3]:
		var old := source.duplicate(true)
		old.roads = [{"from":"anatolien__01","to":"anatolien__02","builder":6,"months":remaining,"state":"building"}]
		var result: Dictionary = Save.migrate(old)
		check(result.ok and result.data.roads[0].get("construction")=={} and result.data.roads[0].get("legacy_construction")==true and result.data.roads[0].months==remaining,"Prepaid historical road keeps exact remaining timing: "+str(remaining))
	var malformed := _current(source)
	malformed.roads = [{"from":"anatolien__01","to":"anatolien__02","builder":6,"months":2,"state":"building"}]
	_reject(malformed,"Current pending road missing construction metadata rejects")
	var finished := _current(source)
	finished.roads = [{"from":"anatolien__01","to":"anatolien__02","builder":6,"months":0,"state":"complete","construction":{}}]
	check(Save.migrate(finished).ok,"Complete road requires no new project or payment")
	var current := _active(source)
	current.houses[6].research.known = ["surveying","road_building"]
	current.roads = [{"from":"anatolien__01","to":"anatolien__02","builder":6,"months":3,"state":"building",
		"construction":{"id":8,"paid_gold":38,"priority":1,"started_month":0,"legs":[
			{"province":"anatolien__01","material_total_u":3811263,"material_spent_u":3811263,"work_total_u":3811263,"work_done_u":3811263},
			{"province":"anatolien__02","material_total_u":3811263,"material_spent_u":1000000,"work_total_u":3811263,"work_done_u":1000000}]}}]
	check(Save.migrate(current).ok and Save.validate(current).is_empty(),"New road preserves two independently accounted legs including one complete endpoint")
	var locked := current.duplicate(true)
	locked.houses[6].research.known = ["surveying"]
	_reject(locked,"New road requires the builder's road-building unlock")
	for variant in ["duplicate_id","missing_leg","endpoint","missing_total","wrong_total","material","foreign_owner","legacy_tag"]:
		var bad := current.duplicate(true)
		match variant:
			"duplicate_id": bad.roads[0].construction.id = 7
			"missing_leg": bad.roads[0].construction.legs.pop_back()
			"endpoint": bad.roads[0].construction.legs[1].province = "anatolien__03"
			"missing_total": bad.roads[0].construction.legs[1].erase("work_total_u")
			"wrong_total": bad.roads[0].construction.legs[1].work_total_u = 3811264
			"material": bad.roads[0].construction.legs[1].material_spent_u = 999999
			"foreign_owner": bad.provinces[1].owner = 0
			"legacy_tag": bad.roads[0].legacy_construction = true
		_reject(bad,"Malformed new road accounting rejects: "+variant)

func _test_layout() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_v1.json"))
	var migrated: Dictionary = Save.migrate(original)
	if not check(migrated.ok,"Actual49region legacy normalizes"): return
	var regional: Dictionary = Migration.migrate_state(migrated.data)
	check(regional.ok,"Actual49region source converts into108regions")
	if not regional.ok: return
	var all_zero: bool = regional.data.provinces.size()==108
	for p in regional.data.provinces:
		all_zero = all_zero and p.get("production")=={"materials_u":0,"rate_carry":0} and p.get("regional_project")=={} and p.get("logistics_sites")=={"depot":0}
	check(all_zero and Save.validate(regional.data).is_empty(),"Final108regions receive zero additions after layout conversion")
	var active49: Dictionary = Game.new(Legacy,0).snapshot()
	active49.project_serial = 1
	for p in active49.provinces:
		p.production = {"materials_u":1,"rate_carry":0}
		p.regional_project = {}
		p.logistics_sites = {"depot":0}
	active49.provinces[0].regional_project = {"id":1,"builder":int(active49.provinces[0].owner),"kind":"market","target_level":1,"paid_gold":60,
		"material_total_u":6000000,"material_spent_u":0,"work_total_u":4000000,"work_done_u":0,"priority":0,"started_month":0}
	for schema in [17,18]:
		var historical_or_current: Dictionary=active49.duplicate(true)
		if schema==17: historical_or_current=_without_trade(historical_or_current)
		historical_or_current.schema_version=schema
		check(Save.migrate(historical_or_current).ok,"Controlled49production remains valid before unsupported layout conversion in schema"+str(schema))
		check(not Migration.migrate_state(historical_or_current).ok,"Active production cannot silently disappear during49to108conversion in schema"+str(schema))

func _test_legacy_road_graph() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_v1.json"))
	old["roads"] = []
	var graph: Dictionary = Legacy.adjacency()
	for a in graph:
		for b in graph[a]:
			if str(a)<str(b): old.roads.append({"from":str(a),"to":str(b),"builder":0,"months":2,"state":"building"})
	var normalized: Dictionary = Save.migrate(old)
	if not check(normalized.ok,"Controlled historical49road graph normalizes without recharging"): return
	var converted: Dictionary = Migration.migrate_state(normalized.data)
	if not check(converted.ok,"All actual legacy adjacency edges survive layout migration"): return
	check(converted.data.roads.size()==old.roads.size(),"Concurrent historical road count is preserved")
	var metadata_preserved := true
	for road in converted.data.roads:
		metadata_preserved = metadata_preserved and road.get("construction")=={} and road.get("legacy_construction")==true and road.get("legacy_connection")==true and int(road.months)==2
	check(metadata_preserved and Save.validate(converted.data).is_empty(),"Historical prepaid timing and original-backed metadata remain valid")
	# Controlled exceptional current roads retain genuine old-edge backing.
	var exceptions: Dictionary = converted.data.duplicate(true)
	var self_edge: Dictionary = exceptions.roads[0].duplicate(true)
	self_edge.to = self_edge.from
	exceptions.roads.append(self_edge)
	exceptions.roads.append(exceptions.roads[0].duplicate(true))
	check(Save.migrate(exceptions).ok and Save.validate(exceptions).is_empty(),"Original-backed self and duplicate legacy routes remain loadable")
	self_edge.erase("legacy_connection")
	check(not Save.migrate(exceptions).ok,"Unbacked self edge cannot gain the legacy adjacency exception")

func _test_store(source: Dictionary) -> void:
	var path := stem+"-old.json"
	var raw := JSON.stringify(source).to_utf8_buffer()
	_write(path,raw)
	var loaded: Dictionary = Store.load_snapshot(path)
	check(loaded.ok and FileAccess.get_file_as_bytes(path+".pre-schema-v16.bak")==raw and FileAccess.get_file_as_bytes(path)==raw,"Actual local Store protects unchanged16bytes before migration")
	var direct := stem+"-direct.json"
	_write(direct,raw)
	check(Store.write_snapshot(direct,_active(source)) and FileAccess.get_file_as_bytes(direct+".pre-schema-v16.bak")==raw,"Direct Store overwrite protects never-loaded16target")

func _test_wire_commands() -> void:
	for command in [{"id":"construction_cancel","project":7},{"id":"construction_priority","project":7,"priority":1}]:
		check(Protocol.validate_command(command).ok,"Bounded construction intent is allowed: "+str(command.id))
	for command in [{"id":"construction_priority","project":7,"priority":2},{"id":"construction_priority","project":7,"priority":true},{"id":"construction_cancel","project":7,"builder":6},{"id":"construction_cancel","project":-1}]:
		check(not Protocol.validate_command(command).ok,"Malformed or actor-spoofed construction intent rejects")

func _test_fingerprints() -> void:
	var baseline = Session.new()
	var identity: Dictionary = baseline._production_rules()
	check(identity.regional==load("res://scripts/RegionalProduction.gd").RULES and identity.transport==load("res://scripts/MaterialTransport.gd").RULES and identity.depot==load("res://scripts/DepotSupply.gd").RULES and identity.game==Game.PRODUCTION_RULES,"Actual identity includes each pure model and authoritative policy")
	check(identity.get("economy_planner")==load("res://scripts/EconomyPlanner.gd").RULES,"Actual identity includes NPC budget and investment-goal rules")
	var current_hash: String = baseline._fingerprint
	check(not current_hash.is_empty(),"Complete current production definitions advertise an identity")
	baseline.free()
	var variants: Array = []
	# Deliberately keep the real fingerprint cache populated between constructors.
	for type in [ProductionIdentityVariant,TransportIdentityVariant,DepotIdentityVariant,GameIdentityVariant,EconomyPlannerIdentityVariant]:
		var changed = type.new()
		check(changed._fingerprint!=current_hash and not variants.has(changed._fingerprint),"Rule-only changes invalidate content and cache identity")
		variants.append(changed._fingerprint)
		changed.free()

func _test_serialization(source: Dictionary) -> void:
	var state := _active(source)
	var envelope := {"kind":"BQ-LAN-SAVE","v":3,"app":"1.9.1","fingerprint":"controlled-current","state":state}
	var raw: PackedByteArray = Protocol.encode_packet(envelope)
	check(not raw.is_empty() and raw.size()<2097152,"Actual bounded18envelope remains below2MiB")
	var large := envelope.duplicate(true)
	large.state["oversized"] = "x".repeat(2097152)
	check(Protocol.encode_packet(large).is_empty(),"Compression cannot bypass raw2MiB/field limits")
	var production = load("res://scripts/RegionalProduction.gd")
	var maximum := _current(source)
	var by_id := {}
	var serial := 0
	for p in maximum.provinces:
		p.owner = 0
		p.buildings.market = 2
		p.production.materials_u = production.stock_capacity_u(p)
		serial+=1
		var requirements: Dictionary = production.requirements(p,"market",3)
		p.regional_project = {"id":serial,"builder":0,"kind":"market","target_level":3,"paid_gold":1000000000000,
			"material_total_u":requirements.material_total_u,"material_spent_u":0,"work_total_u":requirements.work_total_u,"work_done_u":0,"priority":1,"started_month":0}
		by_id[str(p.id)] = p
	var graph: Dictionary = Data.adjacency()
	for a in graph:
		for b in graph[a]:
			if str(a)>=str(b): continue
			serial+=1
			var road: Dictionary = production.road_requirements(by_id[a],by_id[b])
			maximum.roads.append({"from":str(a),"to":str(b),"builder":0,"months":3,"state":"building",
				"construction":{"id":serial,"paid_gold":1000000000000,"priority":1,"started_month":0,"legs":road.legs}})
	maximum.project_serial = 1000000000
	maximum.houses[0].research.known = ["surveying","road_building"]
	check(serial==334 and maximum.roads.size()==226 and Save.validate(maximum).is_empty(),"All108regional and226road projects fit the actual bounded topology")
	var maximum_envelope := {"kind":"BQ-LAN-SAVE","v":3,"app":"1.9.1","fingerprint":"controlled-maximum","state":maximum}
	var maximum_raw: PackedByteArray = Protocol.encode_packet(maximum_envelope)
	check(not maximum_raw.is_empty() and maximum_raw.size()<2097152,"Maximum allowed production topology saves below2MiB without compression")
	var world = Game.new(Data,0)
	if check(world.restore(maximum),"Maximum production topology restores through real Game"):
		var projection: Dictionary = world.snapshot_for_player(1)
		var snapshot := {"v":3,"type":"snapshot","revision":1,"hash":Protocol.world_hash(projection),"state":projection,"missing_peer":false,"all_over":false}
		var snapshot_raw: PackedByteArray = Protocol.encode_packet(snapshot)
		var decoded: Dictionary = Protocol.decode_packet(snapshot_raw)
		check(not snapshot_raw.is_empty() and decoded.ok and Protocol.world_hash(decoded.message.state)==snapshot.hash,"Maximum guest snapshot encodes, bounded-decompresses and preserves its shared hash")
		print("PRODUCTION_PACKET_BOUNDS save_bytes=",maximum_raw.size()," guest_raw_bytes=",JSON.stringify(snapshot).to_utf8_buffer().size()," guest_wire_bytes=",snapshot_raw.size())
	var oversized := {"v":3,"type":"snapshot","padding":[]}
	for i in 65: oversized.padding.append("x".repeat(32768))
	check(Protocol.encode_packet(oversized).is_empty(),"Individually valid compressible strings still obey the uncompressed2MiB packet boundary")
	var invalid_frame := "BQZ2".to_utf8_buffer()
	invalid_frame.resize(8)
	invalid_frame.encode_u32(4,2097153)
	invalid_frame.append(0)
	check(not Protocol.decode_packet(invalid_frame).ok,"Declared decompression above2MiB is rejected before allocation")

func _write(path: String, raw: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("PRODUCTIONSAVETEST FAIL: "+label)
	return ok
