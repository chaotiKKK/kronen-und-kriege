extends Node
## Actual untouched published naval15 envelope; large armies are controlled clones.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Legacy = preload("res://scripts/Data.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
const Migration = preload("res://scripts/RegionMigration.gd")
const Session = preload("res://scripts/LanSession.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
const PATH := "res://tests/fixtures/lan-191-naval-schema15-original.json"
const HASH := "afa14969367ce1d06333e3e89f2e724674779a0dc022bc65b532b1e2fc91277d"
const FINGERPRINT := "d1d986d4adf5714ae629f351b377f3f159d58b126f72ba3b62ca3fccbdd84582"
const SUFFIX := ".pre-campaign-schema15.bak"
# Controlled policy-identity variants exercise the real base cache algorithm.
# They never replace preview behavior or modify the actual immutable RULES.
class SiegeIdentityVariant extends Session:
	func _field_campaign_rules() -> Dictionary:
		var rules: Dictionary = super._field_campaign_rules().duplicate(true)
		rules.siege.version = int(rules.siege.version)+1
		return rules
class BattleIdentityVariant extends Session:
	func _field_campaign_rules() -> Dictionary:
		var rules: Dictionary = super._field_campaign_rules().duplicate(true)
		rules.battle.version = int(rules.battle.version)+1
		return rules
class RecoveryIdentityVariant extends Session:
	func _field_campaign_rules() -> Dictionary:
		var rules: Dictionary = super._field_campaign_rules().duplicate(true)
		rules.recovery.version = int(rules.recovery.version)+1
		return rules
var checks := 0
var failures := 0
var stem := ""

func _ready() -> void:
	stem = "user://fortress-save-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(FileAccess.get_sha256(PATH)==HASH,"Published naval15 original remains genuine and byte-identical")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(original.state.schema_version==15 and original.fingerprint==FINGERPRINT and original.app=="1.9.1" and original.v==3,"Historical schema15/app/wire/fingerprint pins come from actual original bytes")
	check(Save.CURRENT_VERSION==18,"Large untruncated armies remain supported in trade schema18")
	var constants: Dictionary = Save.new().get_script().get_script_constant_map()
	check(constants.get("MAX_ARMY_STRENGTH")==100000 and constants.get("MAX_ARMY_UPKEEP")==400,"Shared explicit strength100000/upkeep400 limits are published by Save")
	_test_large_world(original.state)
	_test_current_raw_bounds(original.state)
	_test_old_compatibility(original.state)
	_test_old_layout()
	_test_local_store(original.state)
	_test_rule_fingerprint()
	_test_published_lan(original)
	check(FileAccess.get_sha256(PATH)==HASH,"All controlled cases leave the genuine historical fixture untouched")
	print("FORTRESSSAVETEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func _large(source: Dictionary, version: int = Save.CURRENT_VERSION) -> Dictionary:
	var state: Dictionary = Save.migrate(source).data if version>=17 else source.duplicate(true)
	if version==17:
		# Historical17 already required production, while trade did not exist.
		check(state.get("material_trades")==[] and state.get("trade_serial")==0,"Controlled17 projection contains only empty new trade fields")
		state.erase("material_trades")
		state.erase("trade_serial")
	state.schema_version = version
	var home := str(state.houses[0].capital)
	state.houses[0].armies = [
		{"id":1,"province":home,"strength":7500,"upkeep":30,"morale":80,"last_siege_month":1},
		{"id":7,"province":home,"strength":50000,"upkeep":200,"morale":60,"last_siege_month":1},
	]
	return state

## Project current additive fields away only for comparison with untouched history.
func _historical_projection(source: Dictionary, version: int) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	state.schema_version = version
	if version<18:
		check(state.get("material_trades")==[] and state.get("trade_serial")==0,"Historical army projection removes only proven empty trade additions")
		state.erase("material_trades")
		state.erase("trade_serial")
	if version<17:
		state.erase("project_serial")
		for p in state.provinces:
			for field in ["production","regional_project","logistics_sites"]:
				p.erase(field)
		for road in state.roads:
			road.erase("construction")
			road.erase("legacy_construction")
	return state

func _test_large_world(source: Dictionary) -> void:
	var state := _large(source)
	var before := state.duplicate(true)
	var migrated: Dictionary = Save.migrate(state)
	check(migrated.ok and state==before,"Current large-army normalization is pure and accepted")
	if migrated.ok:
		check(migrated.data.houses[0].armies==state.houses[0].armies,"7500/30 and50000/200 are preserved without the old5000/50 truncation")
		check(Save.validate(migrated.data).is_empty(),"Normalized large-army world is a valid current save")
	var game = Game.new(Data,0)
	var restored: bool = game.restore(state)
	check(restored,"Real Game restores controlled large armies under the current production schema")
	if not restored: return
	check(game.houses[0].armies==state.houses[0].armies and game.army_upkeep()==230,"Actual runtime armies and annual230upkeep remain intact")
	var actual: Dictionary = game.snapshot()
	check(actual.schema_version==Save.CURRENT_VERSION and actual.houses[0].armies==state.houses[0].armies,"Actual current snapshot keeps both complete forces")
	var again = Game.new(Data,0)
	check(again.restore(JSON.parse_string(JSON.stringify(actual))) and Save.state_equal({"armies":again.houses[0].armies},{"armies":state.houses[0].armies}),"JSON and second Game restore do not clip either army/upkeep or alter any unit field")

func _test_current_raw_bounds(source: Dictionary) -> void:
	for pair in [[1,0],[100000,400],[7500.0,30.0]]:
		var state := _large(source)
		state.houses[0].armies[0].strength = pair[0]
		state.houses[0].armies[0].upkeep = pair[1]
		var result: Dictionary = Save.migrate(state)
		check(result.ok and Save.validate(state).is_empty(),"Integral finite current army bounds are accepted: "+str(pair))
		if result.ok:
			check(result.data.houses[0].armies[0].strength==pair[0] and result.data.houses[0].armies[0].upkeep==pair[1],"Valid current bounds survive exactly: "+str(pair))
	for field in ["strength","upkeep"]:
		var bad_values: Array = [-1,0.5,true,"30",null,NAN,INF,100001 if field=="strength" else 401]
		for value in bad_values:
			var bad := _large(source)
			bad.houses[0].armies[0][field] = value
			check(not Save.migrate(bad).ok and not Save.validate(bad).is_empty(),"Current raw "+field+" is rejected instead of coerced/clipped: "+str(value))
		var missing := _large(source)
		missing.houses[0].armies[0].erase(field)
		check(not Save.migrate(missing).ok and not Save.validate(missing).is_empty(),"Current missing "+field+" cannot regain a silent default")
	var zero := _large(source)
	zero.houses[0].armies[0].strength = 0
	var removed: Dictionary = Save.migrate(zero)
	check(removed.ok and removed.data.houses[0].armies.size()==1 and removed.data.houses[0].armies[0].id==7,"Current zero remains an explicitly removable empty unit, not a live ghost")

func _test_old_compatibility(source: Dictionary) -> void:
	for version in range(1,Save.CURRENT_VERSION):
		var controlled := _large(source,version)
		var before := controlled.duplicate(true)
		var result: Dictionary = Save.migrate(controlled)
		check(result.ok and controlled==before,"Controlled old source migration remains pure/accepted for version"+str(version))
		if result.ok:
			check(result.data.schema_version==Save.CURRENT_VERSION and result.data.houses[0].armies==controlled.houses[0].armies,"Valid large old armies retain original men/upkeep in the current schema from"+str(version))
	var actual: Dictionary = Save.migrate(source)
	check(actual.ok,"Actual unmodified published15world migrates")
	if actual.ok:
		var projected: Dictionary = _historical_projection(actual.data,15)
		check(Save.state_equal(projected,source),"Genuine published15world changes only its schema number and additive production fields")

func _test_old_layout() -> void:
	var old: Dictionary = _historical_projection(Game.new(Legacy,0).snapshot(),15)
	old.houses[0].armies = [{"id":4,"province":"suebia","strength":50000,"upkeep":200,"morale":75}]
	var normalized: Dictionary = Save.migrate(old)
	if not check(normalized.ok,"Controlled old49region large army normalizes"): return
	var result: Dictionary = Migration.migrate_state(normalized.data)
	check(result.ok and result.data.schema_version==Save.CURRENT_VERSION,"49→108 conversion never rolls the current schema back")
	if result.ok:
		check(result.data.houses[0].armies[0].strength==50000 and result.data.houses[0].armies[0].upkeep==200 and Save.validate(result.data).is_empty(),"Layout migration preserves controlled large legacy force and current validity")

func _test_local_store(source: Dictionary) -> void:
	var old := _large(source,15)
	var raw := JSON.stringify(old).to_utf8_buffer()
	var path := stem+"-single.json"
	_write(path,raw)
	var result: Dictionary = Store.load_snapshot(path)
	check(result.ok and Save.state_equal({"armies":result.data.houses[0].armies},{"armies":old.houses[0].armies}),"Actual Store load preserves controlled old15large units and dates across JSON number types")
	check(FileAccess.get_file_as_bytes(path)==raw and FileAccess.get_file_as_bytes(path+".pre-schema-v15.bak")==raw,"Local migration leaves old15bytes and exact original backup")
	var direct := stem+"-direct.json"
	_write(direct,raw)
	check(Store.write_snapshot(direct,_large(source)) and FileAccess.get_file_as_bytes(direct+".pre-schema-v15.bak")==raw,"Direct local write protects never-loaded source15before replacing it")

func _test_published_lan(original: Dictionary) -> void:
	var raw := FileAccess.get_file_as_bytes(PATH)
	var session = Session.new()
	session.discovery_enabled = false
	add_child(session)
	if not check(session.host("Fortress15migration","Host",0,55000+OS.get_process_id()%1000).ok,"Own independent lobby for actual local file migration"): return
	check(not Protocol.handshake_error(original,session._app,session._fingerprint).is_empty(),"Historical published naval15peer cannot join the new rules")
	var path := stem+"-lan.json"
	_write(path,raw)
	var loaded: Dictionary = session.load_host_lobby(path)
	check(loaded.ok,"Genuine published naval15file resumes locally: "+str(loaded.message))
	if loaded.ok:
		var projection: Dictionary = _historical_projection(session.game.snapshot(),15)
		check(Save.state_equal(projection,original.state),"Actual old LAN migration retains the complete shared/personal world")
	else:
		session.game = Game.new(Data,0)
		session.game.configure_human_houses([0,1])
		session._resume_state = session.game.snapshot()
	check(FileAccess.get_file_as_bytes(path)==raw and FileAccess.get_file_as_bytes(path+SUFFIX)==raw,"Local old15load first preserves actual originalbytes")
	var live: Dictionary = session.game.snapshot()
	var direct := stem+"-lan-direct.json"
	_write(direct,raw)
	check(session.save_host(direct).ok and FileAccess.get_file_as_bytes(direct+SUFFIX)==raw and session.game.snapshot()==live,"Direct LAN target recognizes and protects never-loaded genuine old15bytes")
	for variant in ["hash","current_hash","app","wire","schema14","schema16","catalog"]:
		var bad := original.duplicate(true)
		match variant:
			"hash": bad.fingerprint = "unknown"
			"current_hash": bad.fingerprint = session._fingerprint
			"app": bad.app = "1.9.0"
			"wire": bad.v = 2
			"schema14": bad.state.schema_version = 14
			"schema16": bad.state.schema_version = 16
			"catalog": bad.state.region_catalog_hash = "wrong"
		var bytes := JSON.stringify(bad).to_utf8_buffer()
		var bad_path: String = stem+"-bad-"+str(variant)+".json"
		_write(bad_path,bytes)
		check(not session.load_host_lobby(bad_path).ok and not session.save_host(bad_path).ok,"Contradictory/unknown published15identity rejected in both local paths: "+variant)
		check(FileAccess.get_file_as_bytes(bad_path)==bytes and session.game.snapshot()==live and not FileAccess.file_exists(bad_path+SUFFIX),"Rejected identity leaves actual file/world/backups unchanged: "+variant)
	var collision := stem+"-collision.json"
	_write(collision,raw)
	_write(collision+SUFFIX,"unrelated".to_utf8_buffer())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	var digest: String = context.finish().hex_encode().substr(0,16)
	check(session.load_host_lobby(collision).ok and FileAccess.get_file_as_string(collision+SUFFIX)=="unrelated" and FileAccess.get_file_as_bytes(collision+".pre-regions-"+digest+".bak")==raw,"Backup collision preserves both unrelated history and exact naval15original")
	var blocked := stem+"-blocked.json"
	_write(blocked,raw)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked+SUFFIX))
	check(not session.load_host_lobby(blocked).ok and not session.save_host(blocked).ok and FileAccess.get_file_as_bytes(blocked)==raw and session.game.snapshot()==live,"Unwritable original backup prevents load/direct overwrite without state mutation")
	session.close_session()
	session.queue_free()

func _test_rule_fingerprint() -> void:
	var baseline = Session.new()
	var identity: Dictionary = baseline._field_campaign_rules()
	check(identity.siege==load("res://scripts/SiegeRules.gd").RULES and identity.battle==load("res://scripts/FieldBattleRules.gd").RULES and identity.recovery==load("res://scripts/ArmyRecovery.gd").RULES,"Fingerprint input contains every actual pure rule set without omissions")
	check(identity.army_limits=={"strength":100000,"upkeep":400},"Serialized army bounds are also part of current rule identity")
	var original: String = baseline._fingerprint
	check(not original.is_empty(),"Actual admitted current rules advertise a nonempty identity")
	baseline.free()
	# No cache clearing between these real Session constructors: stale reuse
	# would hide a rules-only change even when the data resource path is equal.
	var values: Array = []
	for type in [SiegeIdentityVariant,BattleIdentityVariant,RecoveryIdentityVariant]:
		var changed = type.new()
		check(changed._fingerprint!=original and not values.has(changed._fingerprint),"A rules-only policy change independently changes both identity and cache selection")
		values.append(changed._fingerprint)
		changed.free()

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FORTRESSSAVETEST FAIL: "+label)
	return ok
