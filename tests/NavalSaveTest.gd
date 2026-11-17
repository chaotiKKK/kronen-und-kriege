extends Node
## Genuine Schema14 originals remain byte-identical; controlled15 cases
## exercise the saved fleet action instead of just migration defaults.
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
const Game = preload("res://scripts/Game.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const Legacy = preload("res://scripts/Data.gd")
const Migration = preload("res://scripts/RegionMigration.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
const Session = preload("res://scripts/LanSession.gd")
const FLEET_PATH := "res://tests/fixtures/wessex-context-schema14-fleet-original.json"
const FLEET_HASH := "718510a7355b856962070c8a63022634bf89f04a82e27daf051d6778e75f56ff"
const LAN_PATH := "res://tests/fixtures/lan-191-context-schema14-original.json"
const LAN_HASH := "4485f3fe576f2c1b2cd001bb13af0c77638c80c3183e5d89c34f8a207f424fbc"
const LAN_FINGERPRINT := "49efe0af83dff5e58b98eff1d9e2978a8200f835562ac0202da13b036ac884a6"
const LAN_SUFFIX := ".pre-naval-schema14.bak"
var checks := 0
var failures := 0
var stem := ""

func _ready() -> void:
	stem = "user://naval-save-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(FileAccess.get_sha256(FLEET_PATH) == FLEET_HASH,"Genuine old Context fleet bytes remain unchanged")
	check(FileAccess.get_sha256(LAN_PATH) == LAN_HASH,"Genuine Context LAN bytes remain unchanged")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLEET_PATH))
	check(old.schema_version == 14 and old.houses[2].gold == 10 and old.houses[2].fleets[0].ships == 18 and old.houses[2].armies[0].strength == 438,"Old EXE legally paid fleet60+army50 from120gold")
	_test_old_fleet(old)
	_test_raw_dates(old)
	_test_used_runtime_date(old)
	_test_claim_dates(old)
	_test_old_layout()
	_test_local_store(old)
	_test_fingerprint_closed()
	_test_context_lan()
	check(FileAccess.get_sha256(FLEET_PATH) == FLEET_HASH and FileAccess.get_sha256(LAN_PATH) == LAN_HASH,"All tests leave both genuine originals byte-identical")
	print("NAVALSAVETEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)

func _test_old_fleet(old: Dictionary) -> void:
	var before := old.duplicate(true)
	var result: Dictionary = Save.migrate(old)
	check(result.ok and int(result.data.schema_version) == 15,"Actual old fleet save migrates to schema15")
	check(old == before,"Pure save migration does not alter its input")
	if not result.ok: return
	check(int(result.data.houses[2].fleets[0].get("last_naval_month",-99)) == -1,"An old fleet with no offensive action gets explicit−1")
	check(Save.state_equal(_as_schema14(result.data),old),"Old fleet migration changes only version and new−1markers")
	var restored = Game.new(Regions,2)
	check(restored.restore(old),"Actual old fleet save restores in real regional Game")
	check(int(restored.fleet_for().get("last_naval_month",-99)) == -1,"Runtime normalizer keeps the migrated unused fleet marker")

func _current(old: Dictionary, value = -1) -> Dictionary:
	var state := old.duplicate(true)
	state.schema_version = 15
	for house in state.houses:
		for fleet in house.fleets: fleet["last_naval_month"] = value
	return state

func _test_raw_dates(old: Dictionary) -> void:
	for value in [-1,1,1.0]:
		var state := _current(old,value)
		check(Save.migrate(state).ok and Save.validate(state).is_empty(),"Finite integral current naval date is accepted: "+str(value))
	for value in [-2,0,2,0.5,NAN,INF,true,"1",null]:
		var state := _current(old,value)
		check(not Save.migrate(state).ok and not Save.validate(state).is_empty(),"Invalid current raw date is rejected before normalization: "+str(value))
	var missing := _current(old)
	missing.houses[2].fleets[0].erase("last_naval_month")
	check(not Save.migrate(missing).ok and not Save.validate(missing).is_empty(),"Current fleet cannot regain an action by omitting its marker")
	var invalid_old := old.duplicate(true)
	invalid_old.houses[2].fleets[0]["last_naval_month"] = 2
	check(not Save.migrate(invalid_old).ok,"An invalid preexisting marker is rejected even in an old source schema")
	invalid_old.houses[2].fleets[0].last_naval_month = 0
	check(not Save.migrate(invalid_old).ok,"Zero is not a valid historical offensive action or unused sentinel")
	var calendar := old.duplicate(true)
	calendar.year = 0
	calendar.month = 12
	calendar.erase("calendar_version")
	calendar.erase("month_index")
	calendar.houses[2].fleets[0]["last_naval_month"] = 24012
	var migrated: Dictionary = Save.migrate(calendar)
	check(migrated.ok and migrated.data.year == 1 and migrated.data.houses[2].fleets[0].get("last_naval_month",-99) == 24012,"Legacy yearzero uses the same absolute fleet-action month")
	calendar.houses[2].fleets[0].last_naval_month = 24013
	check(not Save.migrate(calendar).ok,"Legacy yearzero still rejects a genuinely future naval action")

func _test_used_runtime_date(old: Dictionary) -> void:
	var current := _current(old,1)
	var game = Game.new(Regions,2)
	if not check(game.restore(current),"Current used fleet date can restore from JSON-shaped state"): return
	check(int(game.fleet_for().get("last_naval_month",-99)) == 1,"Runtime fleet itself retains its used action, not just later migrated snapshots")
	check(int(game.snapshot().schema_version) == 15 and int(game.snapshot().houses[2].fleets[0].get("last_naval_month",-99)) == 1,"Actual current snapshot preserves schema and used fleet date")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var again = Game.new(Regions,2)
	check(again.restore(decoded) and int(again.fleet_for().get("last_naval_month",-99)) == 1,"JSON and second runtime normalization cannot reset the monthly fleet guard")

func _test_claim_dates(old: Dictionary) -> void:
	var state := _current(old)
	var ids := [str(state.provinces[0].id),str(state.provinces[1].id),str(state.provinces[2].id)]
	state.houses[2].claims = [
		{"province":ids[0],"strength":2},
		{"province":ids[1],"strength":3,"expires":0},
		{"province":ids[2],"strength":1,"expires":241},
	]
	var before := state.duplicate(true)
	var migrated: Dictionary = Save.migrate(state)
	check(migrated.ok and state == before,"Claim migration accepts optional historical expiry without mutating its source")
	if not migrated.ok: return
	check(migrated.data.houses[2].claims == state.houses[2].claims,"Absent expiry stays absent; explicit zero and real dates stay unchanged")
	var game = Game.new(Regions,2)
	if not check(game.restore(state),"Claim expiry variants restore through real Game"): return
	check(game.has_claim(ids[0]) and not game.has_claim(ids[1]) and game.has_claim(ids[2]),"Unbounded historical claim stays active; zero remains expired and dated claim active")
	var snapshot: Dictionary = game.snapshot()
	check(snapshot.houses[2].claims == state.houses[2].claims,"Snapshot does not invent an expiry or a new free claim duration")
	var again = Game.new(Regions,2)
	check(again.restore(JSON.parse_string(JSON.stringify(snapshot))) and again.has_claim(ids[0]) and not again.has_claim(ids[1]),"Second JSON restore preserves distinct missing and zero expiry semantics")

func _test_old_layout() -> void:
	var game = Game.new(Legacy,0)
	var old: Dictionary = game.snapshot()
	old.schema_version = 14
	old.houses[0].fleets = [{"id":3,"province":"frisia","station":"frisia","ships":7,"morale":81,"upkeep":1}]
	var normalized: Dictionary = Save.migrate(old)
	if not check(normalized.ok,"Controlled49region source with old fleet can normalize"): return
	var regional: Dictionary = Migration.migrate_state(normalized.data)
	check(regional.ok and int(regional.data.schema_version) == 15,"49→108 layout conversion cannot roll schema15 back to14")
	if not regional.ok: return
	check(Save.validate(regional.data).is_empty(),"Composed schema and layout migration produces a valid current save")
	check(regional.data.houses[0].fleets[0].ships == 7 and regional.data.houses[0].fleets[0].get("last_naval_month",-99) == -1,"Legacy fleet position conversion retains ships and new unused action marker")

func _test_local_store(old: Dictionary) -> void:
	var raw := FileAccess.get_file_as_bytes(FLEET_PATH)
	var path := stem+"-single.json"
	_write(path,raw)
	var loaded: Dictionary = Store.load_snapshot(path)
	check(loaded.ok and loaded.data.schema_version == 15,"Local Store loads genuine fleet source to15")
	check(FileAccess.get_file_as_bytes(path) == raw and FileAccess.get_file_as_bytes(path+".pre-schema-v14.bak") == raw,"Local load leaves original and byte-identical schema14 backup")
	var direct := stem+"-single-direct.json"
	_write(direct,raw)
	check(Store.write_snapshot(direct,_current(old,1)),"Direct local save may replace old14 only after backup")
	check(FileAccess.get_file_as_bytes(direct+".pre-schema-v14.bak") == raw,"Direct local save protects genuinely old fleet bytes")
	var collision := stem+"-single-collision.json"
	_write(collision,raw)
	_write(collision+".pre-schema-v14.bak","unrelated".to_utf8_buffer())
	var result: Dictionary = Store.load_snapshot(collision)
	check(result.ok and result.backup != collision+".pre-schema-v14.bak" and FileAccess.get_file_as_bytes(str(result.backup)) == raw,"Collision gets a distinct byte-identical original backup")
	check(FileAccess.get_file_as_string(collision+".pre-schema-v14.bak") == "unrelated","Existing unrelated local backup is retained")
	var blocked := stem+"-single-blocked.json"
	_write(blocked,raw)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked+".pre-schema-v14.bak"))
	check(not Store.load_snapshot(blocked).ok and not Store.write_snapshot(blocked,_current(old,1)) and FileAccess.get_file_as_bytes(blocked) == raw,"Local backup failure preserves original on both load and directwrite")

func _test_context_lan() -> void:
	var raw := FileAccess.get_file_as_bytes(LAN_PATH)
	var original: Dictionary = JSON.parse_string(raw.get_string_from_utf8())
	check(original.fingerprint == LAN_FINGERPRINT and original.state.schema_version == 14 and original.app == "1.9.1" and original.v == 3,"New migration identity is pinned to genuine context metadata")
	var session = Session.new()
	session.discovery_enabled = false
	add_child(session)
	if not check(session.host("Naval migration","Host",0,54000+OS.get_process_id()%1000).ok,"Independent own LAN lobby for file migration"): return
	check(not Protocol.handshake_error(original,session._app,session._fingerprint).is_empty(),"An old context network peer remains rejected despite permitted local migration")
	var path := stem+"-lan.json"
	_write(path,raw)
	var loaded: Dictionary = session.load_host_lobby(path)
	check(loaded.ok,"Genuine Context LAN14 loads locally under the new rules: "+str(loaded.message))
	if loaded.ok:
		check(session.game.snapshot().schema_version == 15 and Save.state_equal(_as_schema14(session.game.snapshot()),original.state),"Context migration preserves the complete old world and all human contexts")
	else:
		# Independent direct-target path still exercises the same old bytes in red.
		session.game = Game.new(Regions,0)
		session.game.configure_human_houses([0,1])
		session._resume_state = session.game.snapshot()
	check(FileAccess.get_file_as_bytes(path) == raw and FileAccess.get_file_as_bytes(path+LAN_SUFFIX) == raw,"LAN load protects original bytes before adopting the new world")
	var live: Dictionary = session.game.snapshot()
	var direct := stem+"-lan-direct.json"
	_write(direct,raw)
	check(session.save_host(direct).ok,"Direct LAN save recognizes an old target that was never loaded")
	check(FileAccess.get_file_as_bytes(direct+LAN_SUFFIX) == raw and session.game.snapshot() == live,"Direct LAN save creates exact old backup without changing live world")
	for variant in ["fingerprint","current_fingerprint","app","wire","schema","catalog","future_schema","forged_regional15"]:
		var bad := original.duplicate(true)
		match variant:
			"fingerprint": bad.fingerprint = "unknown"
			"current_fingerprint": bad.fingerprint = session._fingerprint
			"app": bad.app = "1.9.0"
			"wire": bad.v = 2
			"schema": bad.state.schema_version = 13
			"catalog": bad.state.region_catalog_hash = "wrong"
			"future_schema": bad.state.schema_version = 16
			"forged_regional15":
				bad.app = "1.8.0"
				bad.state.schema_version = 15
				bad.fingerprint = "unknown-regional"
		var bytes := JSON.stringify(bad).to_utf8_buffer()
		var bad_path := stem+"-lan-"+str(variant)+".json"
		_write(bad_path,bytes)
		check(not session.load_host_lobby(bad_path).ok and not session.save_host(bad_path).ok,"Unknown or contradictory source metadata rejected by both LAN file paths: "+variant)
		check(FileAccess.get_file_as_bytes(bad_path) == bytes and not FileAccess.file_exists(bad_path+LAN_SUFFIX) and session.game.snapshot() == live,"Rejected metadata preserves file, backups and live game: "+variant)
	var blocked := stem+"-lan-blocked.json"
	_write(blocked,raw)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked+LAN_SUFFIX))
	check(not session.load_host_lobby(blocked).ok and not session.save_host(blocked).ok and FileAccess.get_file_as_bytes(blocked) == raw and session.game.snapshot() == live,"Failed Context backup prevents both load and direct overwrite without world mutation")
	session.close_session()
	session.queue_free()

func _test_fingerprint_closed() -> void:
	var naval = load("res://scripts/NavalTransport.gd")
	var original = naval.shared_routes()
	var baseline = Session.new()
	var baseline_fingerprint: String = baseline._fingerprint
	baseline.free()
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_routes.json"))
	definitions.routes[0].id = "channel_identity_test"
	var alternative = load("res://scripts/NavalRoutes.gd").new()
	check(alternative.load_bytes(JSON.stringify(definitions)),"A controlled alternative identity keeps the same actual verified geometry")
	naval._routes = alternative
	var changed = Session.new()
	check(changed._fingerprint != baseline_fingerprint,"LAN content identity changes when an admitted route identity changes")
	changed.free()
	var empty = load("res://scripts/NavalRoutes.gd").new()
	naval._routes = empty
	Session._cached_fingerprints.clear()
	var unavailable = Session.new()
	check(unavailable._fingerprint.is_empty(),"Unloaded route data cannot advertise a valid LAN content fingerprint")
	unavailable.free()
	naval._routes = original
	Session._cached_fingerprints.clear()

func _as_schema14(state: Dictionary) -> Dictionary:
	var old := state.duplicate(true)
	old.schema_version = 14
	for house in old.houses:
		for fleet in house.fleets:
			if fleet.has("last_naval_month"):
				check(int(fleet.last_naval_month) == -1,"Only the expected unused old-fleet marker may be projected out")
				fleet.erase("last_naval_month")
	return old

func _write(path: String, raw: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("NAVALSAVETEST FAIL: "+label)
	return ok
