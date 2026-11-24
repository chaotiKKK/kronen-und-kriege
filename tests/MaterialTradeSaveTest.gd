extends Node
## Schema18 trade persistence; controlled worlds use real Game snapshots.
## Original Ari/backup bytes are optional local evidence, never a test dependency.
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Calendar = preload("res://scripts/CampaignCalendar.gd")
const Production = preload("res://scripts/RegionalProduction.gd")
const LEGACY16 := "res://tests/fixtures/lan-191-campaign-schema16-original.json"
const LEGACY16_HASH := "2e2b8befa58ef22ec3547221af2b4a059d4b09df6264a028a012eb9aac563e40"
const LEGACY17 := "res://tests/fixtures/lan-191-production-schema17-original.json"
const LEGACY17_HASH := "3c4185cd09c17bb4098698aba3ea1cb23e06c3393d4f081d31a6a8f9be7a1596"
const INTEGER_FIELDS := ["id","seller","buyer","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots"]
var checks := 0
var failures := 0
var legacy: Dictionary = {}
var proof_dir := ""
var local_legacy17 := ""

func _ready() -> void:
	seed(18181)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--proof-dir="): proof_dir=argument.trim_prefix("--proof-dir=")
		if argument.begins_with("--legacy17-path="): local_legacy17=argument.trim_prefix("--legacy17-path=")
	var game = Game.new(Data,0)
	game.month=4
	check(game.build(str(game.house().capital),"market").ok,"Fixture has a genuinely paid unfinished regional market")
	check(game.start_research("surveying").ok,"Fixture has genuinely paid current research")
	game.owned()[0].production.materials_u=12345
	game.owned()[0].production.rate_carry=7
	legacy=game.snapshot()
	legacy.schema_version=17
	legacy.erase("material_trades")
	legacy.erase("trade_serial")
	legacy.erase("provisioning_report")
	for p in legacy.provinces: p.erase("provisioning")
	if not proof_dir.is_empty() and Save.CURRENT_VERSION==17:
		check(Save.validate(legacy).is_empty(),"Before-version-bump world is a valid genuine schema17 state")
		DirAccess.make_dir_recursive_absolute(proof_dir)
		var path:=proof_dir.path_join("before-schema18-game17.json")
		if not FileAccess.file_exists(path):
			var file:=FileAccess.open(path,FileAccess.WRITE)
			file.store_string(JSON.stringify(legacy,"\t",true)); file.close()
		print("MATERIALTRADESAVETEST fixture17 ",FileAccess.get_sha256(path))
	test_legacy17()
	test_archived17()
	if not local_legacy17.is_empty(): check_original17(local_legacy17,FileAccess.get_sha256(local_legacy17),"Explicit local17 evidence")
	test_legacy16()
	test_roundtrip()
	test_raw_fields()
	test_contract_rejections()
	test_catalog_and_house_limits()
	test_stale_relationships()
	test_store_backups()
	print("MATERIALTRADESAVETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func current() -> Dictionary:
	return with_current_trade_defaults(legacy)

func with_current_trade_defaults(source: Dictionary) -> Dictionary:
	var state:=source.duplicate(true)
	state.schema_version=Save.CURRENT_VERSION
	state["provisioning_report"]={"month_index":-1,"regions":{}}
	for p in state.provinces: p["provisioning"]=load("res://scripts/CivicProvision.gd").initial_state(p)
	state["material_trades"]=[]
	state["trade_serial"]=0
	return state

func test_legacy17() -> void:
	var bytes:=var_to_bytes(legacy)
	var result: Dictionary=Save.migrate(legacy)
	check(result.ok,"Published17-format complete Game world remains migratable")
	check(result.to_version==Save.CURRENT_VERSION and result.data.schema_version==Save.CURRENT_VERSION,"Trade migration advances to the current schema")
	check(result.data.get("material_trades",null) is Array and result.data.get("material_trades",[1]).is_empty() and result.data.get("trade_serial",-1)==0,"Migration adds no offer, delivery, serial or goods")
	var expected:=with_current_trade_defaults(legacy)
	check(Save.state_equal(expected,result.data),"Every pre-existing17 research, production, project and personal value is preserved")
	check(var_to_bytes(legacy)==bytes,"Migration never mutates its historical input")
	check(Save.validate(result.data).is_empty(),"Migrated17 state satisfies the full current schema")
	var again: Dictionary=Save.migrate(result.data)
	check(again.ok and Save.state_equal(again.data,result.data),"Repeated migration grants no trade, gold, material or progress")

func test_legacy16() -> void:
	check(FileAccess.get_sha256(LEGACY16)==LEGACY16_HASH,"Historical LAN16 fixture remains byte-identical")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LEGACY16)).state
	var before:=var_to_bytes(source)
	var result: Dictionary=Save.migrate(source)
	check(result.ok and result.data.schema_version==Save.CURRENT_VERSION,"Genuine16 source advances through production to the current schema")
	if not result.ok: return
	for index in source.houses.size():
		var old: Dictionary=source.houses[index].research
		var migrated: Dictionary=result.data.houses[index].research
		check(migrated.known==old.known and migrated.active==old.active and migrated.months==old.months,"Legacy16 research progress is preserved for house%d" % index)
		if ["surveying","road_building","logistics"].has(str(old.active)):
			var durations: Dictionary={"surveying":6,"road_building":12,"logistics":10}
			check(migrated.get("legacy_duration")==durations[str(old.active)],"Historical research retains its genuine original total duration")
	check(result.data.get("material_trades",[1]).is_empty() and result.data.get("trade_serial",-1)==0,"Legacy16 migration invents neither contract nor delivery")
	check(var_to_bytes(source)==before and FileAccess.get_sha256(LEGACY16)==LEGACY16_HASH,"Legacy16 source/backup-family fixture is unchanged")

func test_archived17() -> void:
	check_original17(LEGACY17,LEGACY17_HASH,"Real published PCK/ENet17 fixture")

func check_original17(path: String, expected_hash: String, label: String) -> void:
	check(FileAccess.get_sha256(path)==expected_hash,label+": original bytes match")
	var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var source: Dictionary=document.get("state",document)
	check(int(source.get("schema_version",0))==17,label+": genuine source version is17")
	var before:=var_to_bytes(source)
	var result: Dictionary=Save.migrate(source)
	check(result.ok and result.data.schema_version==Save.CURRENT_VERSION,label+": source migrates to the current schema")
	var expected:=with_current_trade_defaults(source)
	check(Save.state_equal(expected,result.data),label+": all historical values remain exact alongside neutral new defaults")
	check(var_to_bytes(source)==before and FileAccess.get_sha256(path)==expected_hash,label+": no original or source mutation")

func pair(state: Dictionary) -> Array:
	var by_id: Dictionary={}
	for p in state.provinces: by_id[str(p.id)]=p
	var adjacency: Dictionary=Data.adjacency()
	for p in state.provinces:
		for neighbor in adjacency.get(str(p.id),[]):
			if by_id.has(str(neighbor)) and int(by_id[str(neighbor)].owner)!=int(p.owner): return [p,by_id[str(neighbor)]]
	return []

func trade(state: Dictionary, id: int=1, reverse: bool=false, active: bool=true) -> Dictionary:
	var endpoints:=pair(state)
	if endpoints.is_empty(): return {}
	if reverse: endpoints.reverse()
	var source: Dictionary=endpoints[0]
	var target: Dictionary=endpoints[1]
	var lot:=maxi(1,Production.edge_weight_u(source,target))
	return {"id":id,"seller":int(source.owner),"buyer":int(target.owner),"from":str(source.id),"to":str(target.id),"proposer":int(source.owner),"lot_u":lot,"lot_gold":maxi(1,ceili(2.0*float(lot)/Production.UNIT)),"created_month":0,"expires_month":6,"accepted_month":1 if active else -1,"last_delivery_month":2 if active else -1,"delivered_lots":1 if active else 0,"status":"active" if active else "offered"}

func with_trade() -> Dictionary:
	var state:=current()
	state.material_trades=[trade(state)]
	state.trade_serial=1
	return state

func test_roundtrip() -> void:
	var state:=with_trade()
	state.material_trades.append(trade(state,2,true,false))
	state.trade_serial=2
	check(not state.material_trades[0].is_empty(),"Roundtrip uses real neighboring foreign regions and their frozen weights")
	check(Save.validate(state).is_empty(),"Current active and offered contracts validate together")
	var parsed: Dictionary=JSON.parse_string(JSON.stringify(state))
	var result: Dictionary=Save.migrate(parsed)
	check(result.ok and Save.state_equal(state,result.data),"JSON roundtrip preserves both contract states and all accounting")
	if result.ok:
		check(typeof(result.data.trade_serial)==TYPE_INT,"Serial is canonical Integer after successful raw validation")
		for contract in result.data.material_trades:
			for field in INTEGER_FIELDS: check(typeof(contract[field])==TYPE_INT,"Trade %s becomes canonical Integer" % field)
		var game = Game.new(Data,0)
		check(game.restore(parsed),"Real Game restores current contractual state")
		check(Save.state_equal(game.snapshot(),result.data),"Actual Game snapshot preserves all contracts/serial without executing a delivery")
	var floats:=state.duplicate(true)
	floats.trade_serial=float(floats.trade_serial)
	for contract in floats.material_trades:
		for field in INTEGER_FIELDS: contract[field]=float(contract[field])
	result=Save.migrate(floats)
	check(result.ok and Save.state_equal(result.data,state),"Finite whole JSON numbers are accepted before canonicalization")

func reject(state: Dictionary, label: String) -> void:
	var before:=var_to_bytes(state)
	check(not Save.migrate(state).ok,"Raw migration rejects: "+label)
	check(not Save.validate(state).is_empty(),"Strict validation rejects: "+label)
	check(var_to_bytes(state)==before,"Rejected raw input is unchanged: "+label)

func test_raw_fields() -> void:
	for field in ["material_trades","trade_serial"]:
		var state:=current(); state.erase(field); reject(state,"missing18/"+field)
	for value in [null,{},true,0,"[]"]:
		var state:=current(); state.material_trades=value; reject(state,"non-array contracts/"+str(value))
	for value in [null,true,false,-1,0.5,NAN,INF,1000000001,"1"]:
		var state:=current(); state.trade_serial=value; reject(state,"raw serial/"+str(value))
	for field in ["material_trades","trade_serial"]:
		var state:=legacy.duplicate(true)
		state[field]=null
		reject(state,"malformed present17 field/"+field)
	var historical_injection:=with_trade(); historical_injection.schema_version=17
	reject(historical_injection,"historical17 cannot assert already existing trade state")

func test_contract_rejections() -> void:
	for field in INTEGER_FIELDS:
		for value in [true,0.5,NAN,INF,"1",null]:
			var state:=with_trade(); state.material_trades[0][field]=value
			reject(state,"raw contract number/"+field+"/"+str(value))
	for field in ["id","seller","buyer","from","to","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots","status"]:
		var state:=with_trade(); state.material_trades[0].erase(field); reject(state,"missing contract/"+field)
	var unknown:=with_trade(); unknown.material_trades[0]["extra"]=1; reject(unknown,"unknown contract field")
	var mutations: Array=[{"id":0},{"id":2},{"buyer":99},{"seller":-1},{"proposer":99},{"from":"missing"},{"to":"missing"},{"lot_u":1},{"lot_gold":999},{"created_month":4},{"expires_month":7},{"accepted_month":4},{"last_delivery_month":4},{"last_delivery_month":1},{"delivered_lots":3},{"delivered_lots":-1},{"status":"complete"}]
	for mutation in mutations:
		var state:=with_trade(); state.material_trades[0].merge(mutation,true); reject(state,"contract relation/"+str(mutation))
	var same_house:=with_trade(); same_house.material_trades[0].buyer=same_house.material_trades[0].seller; reject(same_house,"same parties")
	var same_region:=with_trade(); same_region.material_trades[0].to=same_region.material_trades[0].from; reject(same_region,"same region")
	var duplicate:=with_trade(); duplicate.material_trades.append(duplicate.material_trades[0].duplicate(true)); reject(duplicate,"duplicate contract ID")
	var too_many:=with_trade()
	for index in 64: too_many.material_trades.append(too_many.material_trades[0].duplicate(true))
	reject(too_many,"world contract limit")
	var offered:=with_trade(); offered.material_trades[0].status="offered"; reject(offered,"offered contract carrying acceptance/delivery")
	var silent_delivery:=with_trade(); silent_delivery.material_trades[0].delivered_lots=0; reject(silent_delivery,"zero deliveries carrying a delivery date")

func test_stale_relationships() -> void:
	var state:=with_trade()
	var old: Dictionary=state.material_trades[0].duplicate(true)
	for p in state.provinces:
		if str(p.id)==str(old.from): p.owner=int(old.buyer)
	var result: Dictionary=Save.migrate(state)
	check(result.ok and result.data.get("material_trades",[])==state.material_trades,"Ownership changes preserve historical parties for the execution layer to close")
	state=with_trade()
	var date: Dictionary=Calendar.from_index(7)
	state.year=date.year; state.month=date.month; state.month_index=7
	result=Save.migrate(state)
	check(result.ok and result.data.get("material_trades",[])==state.material_trades,"Expired but structurally genuine contracts survive restore until the next execution cleanup")

func test_catalog_and_house_limits() -> void:
	var state:=with_trade()
	var contract: Dictionary=state.material_trades[0]
	var adjacency: Dictionary=Data.adjacency()
	var from: Dictionary={}
	for p in state.provinces:
		if str(p.id)==str(contract.from): from=p
	var remote: Dictionary={}
	for p in state.provinces:
		if int(p.owner)==int(contract.buyer) and str(p.id)!=str(contract.from) and not adjacency.get(str(contract.from),[]).has(str(p.id)):
			remote=p; break
	if check(not remote.is_empty(),"Catalog case has a genuine foreign region beyond direct land adjacency"):
		contract.to=str(remote.id)
		contract.lot_u=maxi(1,Production.edge_weight_u(from,remote))
		contract.lot_gold=maxi(1,ceili(2.0*float(contract.lot_u)/Production.UNIT))
		state["adjacency"]={str(contract.from):[str(remote.id)]} # Forged save metadata is never the authoritative graph.
		reject(state,"non-neighbor pair despite matching quantities and forged saved adjacency")
	state=with_trade()
	var seller: int=state.material_trades[0].seller
	var by_id: Dictionary={}
	for p in state.provinces: by_id[str(p.id)]=p
	state.material_trades=[]
	for p in state.provinces:
		if int(p.owner)!=seller: continue
		for id in adjacency.get(str(p.id),[]):
			if not by_id.has(str(id)) or int(by_id[str(id)].owner)==seller: continue
			var next: Dictionary=trade(state)
			next.id=state.material_trades.size()+1; next.from=str(p.id); next.to=str(id)
			next.seller=seller; next.buyer=int(by_id[str(id)].owner); next.proposer=seller
			next.lot_u=maxi(1,Production.edge_weight_u(p,by_id[str(id)]))
			next.lot_gold=maxi(1,ceili(2.0*float(next.lot_u)/Production.UNIT))
			state.material_trades.append(next)
			if state.material_trades.size()==3: break
		if state.material_trades.size()==3: break
	if check(state.material_trades.size()==3,"House-limit case has three distinct genuine directed border relations"):
		state.trade_serial=3
		reject(state,"three active contracts for the same house")
		state.material_trades.pop_back(); state.trade_serial=2
		for offered in state.material_trades:
			offered.status="offered"; offered.accepted_month=-1; offered.last_delivery_month=-1; offered.delivered_lots=0
		reject(state,"two own open offers despite distinct directed regions")
	state=current(); state.trade_serial=1000000000.0
	var result: Dictionary=Save.migrate(state)
	check(result.ok and typeof(result.data.trade_serial)==TYPE_INT and result.data.trade_serial==1000000000,"Maximum serial is valid and canonical even after all past contracts have ended")
	state=with_trade()
	state.material_trades[0].accepted_month=3
	state.material_trades[0].last_delivery_month=-1
	state.material_trades[0].delivered_lots=0
	check(Save.validate(state).is_empty(),"A newly accepted contract has no fabricated same-month delivery")

func test_store_backups() -> void:
	var path: String=(proof_dir.path_join("store") if not proof_dir.is_empty() else "user://material-trade-save")+"-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	var raw:=JSON.stringify(legacy).to_utf8_buffer()
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(raw); file.close()
	var older: Dictionary={".pre-schema-v16.bak":"Earlier schema16 backup must survive".to_utf8_buffer(),".pre-regions-v12.bak":"Earlier layout backup must survive".to_utf8_buffer()}
	for suffix in older:
		file=FileAccess.open(path+suffix,FileAccess.WRITE)
		file.store_buffer(older[suffix]); file.close()
	var result: Dictionary=Store.load_snapshot(path)
	check(result.ok and FileAccess.get_file_as_bytes(path)==raw,"Actual Store reads17 without overwriting its original bytes")
	check(FileAccess.get_file_as_bytes(path+".pre-schema-v17.bak")==raw,"Actual Store creates a byte-exact original17 backup")
	if result.ok:
		check(Store.write_snapshot(path,result.data),"Actual Store atomically writes the validated18 migration")
		var loaded: Dictionary=Store.load_snapshot(path)
		check(loaded.ok and Save.state_equal(loaded.data,result.data),"Actual Store reload preserves all values and empty trade accounting")
		var written:=FileAccess.get_file_as_bytes(path)
		var malformed: Dictionary=result.data.duplicate(true)
		malformed.erase("material_trades")
		check(not Store.write_snapshot(path,malformed) and FileAccess.get_file_as_bytes(path)==written,"An invalid18 overwrite cannot change the already valid saved bytes")
	check(FileAccess.get_file_as_bytes(path+".pre-schema-v17.bak")==raw,"Writing/reloading18 never overwrites its original17 backup")
	for suffix in older: check(FileAccess.get_file_as_bytes(path+suffix)==older[suffix],"Migration leaves earlier backup family unchanged: "+suffix)

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADESAVETEST FAIL: "+message)
	return ok
