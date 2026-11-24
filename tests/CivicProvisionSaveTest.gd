extends Node
## Genuine published18 migration and strict new provisioning persistence.
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
const Session = preload("res://scripts/LanSession.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
const Production = preload("res://scripts/RegionalProduction.gd")
const Civic = preload("res://scripts/CivicProvision.gd")
const RegionMigration = preload("res://scripts/RegionMigration.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const FIXTURE := "res://tests/fixtures/lan-191-trade-schema18-original.json"
const FIXTURE_HASH := "a68db0b31a38a07d2e64e18ec9a006b4685e56cc97e4d9e1a3e34a7449b857ad"
const OLD16 := "res://tests/fixtures/lan-191-campaign-schema16-original.json"
const OLD16_HASH := "2e2b8befa58ef22ec3547221af2b4a059d4b09df6264a028a012eb9aac563e40"
const NUMERIC := ["food_u","harvest_carry","ration_carry","satisfaction","changed_month"]
var checks := 0
var failures := 0
var old: Dictionary = {}

func _ready() -> void:
	old = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)).state
	test_original18()
	test_local_lan_envelope(FIXTURE,FIXTURE_HASH,".pre-provisions-schema18.bak",18,46300)
	test_local_lan_envelope("res://tests/fixtures/lan-191-provisions-schema19-original.json","65dfe6c33856eb48145076e1cd99df352063dde79564b2d86fef52c6ea26995b",".pre-front-supply-schema19.bak",19,46900)
	test_local_lan_envelope("res://tests/fixtures/lan-191-front-supply-schema19-original.json","a6914bea136c315648739b1934705c9f3cc15d033444d7fa7a9d9fa47a1a922c",".pre-regional-events-schema19.bak",19,47800)
	test_current_and_raw()
	test_legacy_research()
	test_store()
	test_preserved_contract_and_report()
	test_actual_six_month_research()
	test_legacy49_food()
	print("CIVICPROVISIONSAVETEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func current() -> Dictionary:
	var result := old.duplicate(true)
	result.schema_version = 19
	result["provisioning_report"] = {"month_index":-1,"regions":{}}
	for p in result.provinces:
		p["provisioning"] = {"food_u":3*Production.weight_u(p),"harvest_carry":0,"ration_carry":0,"satisfaction":50,"rations":"normal","changed_month":-1}
	return result

func projection(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	result.erase("provisioning_report")
	result.schema_version = 18
	for p in result.provinces: p.erase("provisioning")
	return result

func test_original18() -> void:
	check(FileAccess.get_sha256(FIXTURE) == FIXTURE_HASH,"Original18 fixture bytes remain exact")
	check(int(old.schema_version) == 18 and old.lan_human_houses.size() == 2,"Fixture is a genuine old two-human world")
	var before := var_to_bytes(old)
	var migrated: Dictionary = Save.migrate(old)
	check(migrated.ok and migrated.to_version == 19 and migrated.data.schema_version == 19,"Real18 advances to19")
	check(Save.CURRENT_VERSION == 19,"Current snapshots require new provisioning schema")
	check(Save.state_equal(migrated.data,current()),"Migration adds exactly initial provisioning and empty report")
	check(Save.state_equal(projection(migrated.data),old),"All old owners, resources, research, projects, trade and human data remain exact")
	check(var_to_bytes(old) == before and FileAccess.get_sha256(FIXTURE) == FIXTURE_HASH,"Migration never alters original fixture/input")
	check(Save.validate(migrated.data).is_empty(),"Migrated actual18 world satisfies full current schema")
	var twice: Dictionary = Save.migrate(migrated.data)
	check(twice.ok and Save.state_equal(twice.data,migrated.data),"Repeat migration cannot replenish food or change old values")

func test_local_lan_envelope(fixture: String, digest: String, suffix: String, schema: int, base_port: int) -> void:
	var original:=FileAccess.get_file_as_bytes(fixture)
	if FileAccess.get_sha256(fixture)!=digest:
		check(false,"Actual historical envelope bytes must retain recorded hash: "+str(schema))
		return
	var envelope:Dictionary=JSON.parse_string(original.get_string_from_utf8())
	var session:=Session.new()
	session.discovery_enabled=false
	add_child(session)
	var opened:=session.host("Sicherung Schema "+str(schema),"Prüfhost",0,base_port+OS.get_process_id()%500)
	check(opened.ok,"Local migration runs in a private LAN lobby")
	if not opened.ok: return
	var path:="user://historical-rations-%d-%d.json" % [base_port,OS.get_process_id()]
	var destination:=FileAccess.open(path,FileAccess.WRITE)
	destination.store_buffer(original)
	destination.close()
	var loaded:=session.load_host_lobby(path)
	check(loaded.ok,"Actual historical network save migrates through the local lobby: "+str(schema))
	check(not Protocol.handshake_error(envelope,session._app,session._fingerprint).is_empty(),"Historical save identity is restricted to local migration")
	if loaded.ok:
		var restored: Dictionary=session.game.snapshot()
		if schema<19: restored=projection(restored)
		check(Save.state_equal(restored,envelope.state),"Lobby migration retains the historical local world exactly")
		check(FileAccess.get_file_as_bytes(path)==original and FileAccess.get_file_as_bytes(path+suffix)==original,"Local migration keeps an exact backup before saving")
		check(session.save_host(path).ok,"Migrated lobby can save with the current content identity")
		var updated:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(int(updated.state.schema_version)==Save.CURRENT_VERSION and updated.fingerprint==session._fingerprint,"Current save owns the new schema and content fingerprint")
	session.close_session()
	session.queue_free()

func test_current_and_raw() -> void:
	var valid := current()
	check(Save.validate(valid).is_empty() and Save.migrate(valid).ok,"Complete current neutral world is valid")
	var progressed := valid.duplicate(true)
	progressed.provinces[0].provisioning = {"food_u":17,"harvest_carry":9999,"ration_carry":99,"satisfaction":0,"rations":"scarce","changed_month":0}
	var roundtrip: Dictionary = Save.migrate(JSON.parse_string(JSON.stringify(progressed)))
	check(roundtrip.ok and Save.state_equal(roundtrip.data,progressed),"JSON roundtrip preserves consumed food, carries, policy and dissatisfaction")
	if roundtrip.ok:
		for field in NUMERIC: check(roundtrip.data.provinces[0].provisioning[field] is int,"Validated whole JSON number canonicalized: "+field)
	var overcap := valid.duplicate(true)
	overcap.provinces[0].provisioning.food_u = 1000000000000
	check(Save.migrate(overcap).ok,"Real above-local-capacity stock remains loadable for explicit next-month overflow")
	var missing_report := valid.duplicate(true); missing_report.erase("provisioning_report")
	rejected(missing_report,"Current report required")
	var missing_state := valid.duplicate(true); missing_state.provinces[0].erase("provisioning")
	rejected(missing_state,"Current region provisioning required")
	for field in NUMERIC:
		for bad in [true,false,0.25,NAN,INF,-2,1000000000001]:
			var changed := valid.duplicate(true); changed.provinces[0].provisioning[field] = bad
			rejected(changed,"Raw "+field+" rejects "+str(bad))
	for field in ["food_u","harvest_carry","ration_carry","satisfaction","rations","changed_month"]:
		var changed := valid.duplicate(true); changed.provinces[0].provisioning.erase(field)
		rejected(changed,"Missing state field "+field)
	for bad in ["extra",false,1]:
		var changed := valid.duplicate(true); changed.provinces[0].provisioning[bad] = 0
		rejected(changed,"Unknown state field cannot pass")
	for pair in [["harvest_carry",10000],["ration_carry",100],["satisfaction",101],["rations","free"],["rations",true],["changed_month",1]]:
		var changed := valid.duplicate(true); changed.provinces[0].provisioning[pair[0]]=pair[1]
		rejected(changed,"State boundary "+str(pair))
	for bad in [{},{"month_index":-1,"regions":{},"extra":0},{"month_index":0,"regions":{}},{"month_index":true,"regions":{}},null]:
		var changed := valid.duplicate(true); changed.provisioning_report=bad
		rejected(changed,"Malformed/nonempty-current report rejected")
	var neutral18 := current(); neutral18.schema_version=18
	check(Save.migrate(neutral18).ok,"Already neutral additive old fields may be retained")
	var smuggled := neutral18.duplicate(true); smuggled.provinces[0].provisioning.food_u=17
	rejected(smuggled,"Old version cannot hide nonneutral new resource progress")

func test_legacy_research() -> void:
	check(FileAccess.get_sha256(OLD16)==OLD16_HASH,"Actual16 research fixture remains byte-identical")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OLD16)).state
	var before := var_to_bytes(source)
	var migrated: Dictionary=Save.migrate(source)
	check(migrated.ok and migrated.data.schema_version==19,"Real16 world migrates through all new schemas")
	if migrated.ok:
		for i in source.houses.size():
			var original: Dictionary=source.houses[i].research
			var got: Dictionary=migrated.data.houses[i].research
			check(got.known==original.known and got.active==original.active and got.months==original.months,"Legacy research progress preserved house%d"%i)
			if ["surveying","road_building","logistics"].has(str(original.active)):
				check(got.get("legacy_duration")=={"surveying":6,"road_building":12,"logistics":10}[str(original.active)],"Legacy active total duration preserved house%d"%i)
	check(var_to_bytes(source)==before and FileAccess.get_sha256(OLD16)==OLD16_HASH,"Legacy16 input/fixture remains exact")

func test_store() -> void:
	var path := "user://civic-original18.json"
	var bytes := JSON.stringify(old,"\t",true).to_utf8_buffer()
	var f := FileAccess.open(path,FileAccess.WRITE); f.store_buffer(bytes); f.close()
	var loaded: Dictionary=Store.load_snapshot(path)
	check(loaded.ok,"Store migrates an old18 file")
	check(FileAccess.get_file_as_bytes(path)==bytes,"Store load leaves old file bytes unchanged")
	if loaded.ok:
		check(not str(loaded.backup).is_empty() and FileAccess.get_file_as_bytes(str(loaded.backup))==bytes,"Pre18 backup holds original exact bytes")
		check(Store.write_snapshot(path,loaded.data),"Store writes full valid19 only after backup")
		var again: Dictionary=Store.load_snapshot(path)
		check(again.ok and Save.state_equal(again.data,loaded.data),"Written19 reload changes neither food nor old state")
		check(FileAccess.get_file_as_bytes(str(loaded.backup))==bytes,"Writing/reloading19 keeps old backup exact")
	var invalid := current(); invalid.provinces[0].provisioning.food_u=true
	var before := FileAccess.get_file_as_bytes(path)
	check(not Store.write_snapshot(path,invalid) and FileAccess.get_file_as_bytes(path)==before,"Raw invalid provisioning never overwrites current save")

func rejected(state: Dictionary,message: String) -> void:
	var before := var_to_bytes(state)
	check(not Save.migrate(state).ok and not Save.validate(state).is_empty(),message)
	check(var_to_bytes(state)==before,"Rejected raw input remains unchanged")

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("CIVICPROVISIONSAVE FAIL: "+message)

func test_preserved_contract_and_report() -> void:
	# Controlled serialization case derived from actual neighboring catalog regions.
	var source:=old.duplicate(true);var by_id:Dictionary={};var endpoints:Array=[]
	for p in source.provinces: by_id[str(p.id)]=p
	for p in source.provinces:
		for neighbor in Regions.adjacency().get(str(p.id),[]):
			if by_id.has(str(neighbor)) and int(by_id[str(neighbor)].owner)!=int(p.owner): endpoints=[p,by_id[str(neighbor)]];break
		if not endpoints.is_empty(): break
	check(endpoints.size()==2,"Preservation contract uses actual foreign land neighbors")
	if endpoints.size()==2:
		var lot:=Production.edge_weight_u(endpoints[0],endpoints[1])
		source.trade_serial=1
		source.material_trades=[{"id":1,"seller":int(endpoints[0].owner),"buyer":int(endpoints[1].owner),"from":str(endpoints[0].id),"to":str(endpoints[1].id),"proposer":int(endpoints[0].owner),"lot_u":lot,"lot_gold":maxi(1,ceili(2.0*lot/Production.UNIT)),"created_month":0,"expires_month":6,"accepted_month":-1,"last_delivery_month":-1,"delivered_lots":0,"status":"offered"}]
		var preserved:Dictionary=Save.migrate(source)
		check(preserved.ok and Save.state_equal(projection(preserved.data),source),"A genuine18-format existing contract, serial and all old balances survive19 exactly")
	var state:=current();state.month=2;state.month_index=1
	var report:Dictionary={"month_index":1,"regions":{}}
	for p in state.provinces:
		var plan:Dictionary=Civic.plan(p,1,1)
		check(plan.ok,"Pure real food plan creates a settled row: "+str(p.id))
		if not plan.ok: continue
		p.provisioning=plan.state;report.regions[str(p.id)]=plan.ledger
	state.provisioning_report=report
	var roundtrip:Dictionary=Save.migrate(JSON.parse_string(JSON.stringify(state)))
	check(roundtrip.ok and Save.state_equal(roundtrip.data,state),"Full real108-region settled report survives schema19 JSON")
	var changed:=state.duplicate(true);changed.provinces[0].provisioning.rations="generous";changed.provinces[0].provisioning.changed_month=1
	check(Save.migrate(changed).ok,"Same-month selected policy may differ from settled historical ration")
	var id:=str(state.provinces[0].id)
	changed=state.duplicate(true);changed.provisioning_report.regions[id].produced_u=true
	rejected(changed,"Save validates raw report quantities before normalization")
	changed=state.duplicate(true);changed.provisioning_report.regions[id].owner=state.houses.size()
	rejected(changed,"Save rejects report owner outside historical house catalog")
	changed=state.duplicate(true);changed.provinces[0].provisioning.food_u+=1
	rejected(changed,"Report stock must match actual saved stock")
	changed=state.duplicate(true);changed["production_report"]={"month_index":1,"regions":{}}
	for key in report.regions:
		changed.production_report.regions[key]={"work_u":0,"production_work_u":0,"legacy_work_u":0}
	changed.production_report.regions[id].work_u=int(report.regions[id].industry_labor_u)+1
	rejected(changed,"Save cross-validates actual monthly industry work against food remainder")
	var earlier:=state.duplicate(true);earlier.schema_version=18
	rejected(earlier,"Historical18 cannot conceal an already settled food phase")

func test_actual_six_month_research() -> void:
	var path:="res://tests/fixtures/ari190-campaign-schema16-original.json"
	var expected:="8c767fa3e3f157bf8c2fa1f707c77e79a99db419fa78cd643782a302338e7ba8"
	check(FileAccess.get_sha256(path)==expected,"Actual Ari16 original remains exact")
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(Save.state_equal(source.houses[9].research,{"active":"surveying","known":[],"months":6}),"Actual saved surveying has its paid six remaining months")
	var migrated:Dictionary=Save.migrate(source)
	check(migrated.ok and Save.state_equal(migrated.data.houses[9].research,{"active":"surveying","known":[],"months":6,"legacy_duration":6}),"Food migration preserves all six old research months and historical denominator")
	check(FileAccess.get_sha256(path)==expected,"Actual research fixture is not overwritten")

func test_legacy49_food() -> void:
	var path:="res://tests/fixtures/legacy_v1.json"
	var expected:="796589994e0385f4f21a57764e4212f188569f323c69242c828ca2729a6b704d"
	check(FileAccess.get_sha256(path)==expected,"Original49-region legacy1 fixture is exact")
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var normalized:Dictionary=Save.migrate(source)
	check(normalized.ok and normalized.data.provinces.size()==49,"Legacy1 obtains a valid neutral49-region current state")
	if not normalized.ok: return
	var bytes:=var_to_bytes(normalized.data)
	var mapped:Dictionary=RegionMigration.migrate_state(normalized.data)
	check(mapped.ok and mapped.data.provinces.size()==108,"Neutral legacy49 can migrate to canonical108")
	if mapped.ok:
		for p in mapped.data.provinces:
			check(p.has("provisioning") and Save.state_equal(p.provisioning,Civic.initial_state(p)),"Successor gets only its own canonical weighted initial reserve: "+str(p.id))
		check(Save.validate(mapped.data).is_empty(),"Converted108 current state includes complete valid provisioning")
		if mapped.data.provinces[0].has("provisioning"):
			var id:=str(mapped.data.provinces[0].id)
			mapped.data.provinces[0].provisioning.food_u=17
			mapped.data.provinces[0].provisioning.rations="scarce"
			var again:Dictionary=RegionMigration.migrate_state(mapped.data)
			check(again.ok and Save.state_equal(again.data,mapped.data) and int(again.data.provinces[0].provisioning.food_u)==17,"Already108 active food survives layout idempotence without refill")
	check(var_to_bytes(normalized.data)==bytes,"Layout food migration never mutates49 source")
	for key in ["food_u","harvest_carry","ration_carry","satisfaction","rations","changed_month"]:
		var active:Dictionary=normalized.data.duplicate(true)
		active.provinces[0].provisioning[key]={"food_u":17,"harvest_carry":1,"ration_carry":1,"satisfaction":49,"rations":"scarce","changed_month":0}[key]
		check(not RegionMigration.migrate_state(active).ok,"Active49 food cannot be silently discarded or duplicated: "+key)
	var posted:Dictionary=normalized.data.duplicate(true);var ledger:Dictionary={"month_index":int(posted.month_index),"regions":{}}
	for p in posted.provinces:
		var plan:Dictionary=Civic.plan(p,int(posted.month_index),1)
		p.provisioning=plan.state;ledger.regions[str(p.id)]=plan.ledger
	posted.provisioning_report=ledger
	check(Save.validate(posted).is_empty(),"Controlled49 settled ledger is genuinely schema-valid before conversion")
	check(not RegionMigration.migrate_state(posted).ok,"Existing49 food phase cannot be deleted by layout conversion")
	var local:="user://civic-legacy49.json";var file:=FileAccess.open(local,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close()
	var loaded:Dictionary=Store.load_snapshot(local)
	check(loaded.ok and loaded.data.provinces.size()==108 and Save.validate(loaded.data).is_empty(),"Actual store path migrates legacy1 through49 to complete108 provisioning")
	check(FileAccess.get_sha256(path)==expected,"Legacy1 original stays unchanged after all migrations")
