extends Node
## Real ENet consent/bookings and exact released-PCK schema17 migration.
const Session=preload("res://scripts/LanSession.gd")
const Protocol=preload("res://scripts/LanProtocol.gd")
const Save=preload("res://scripts/SaveGame.gd")
const Trade=preload("res://scripts/MaterialTrade.gd")
const FIXTURE="res://tests/fixtures/lan-191-production-schema17-original.json"
const FIXTURE_HASH="3c4185cd09c17bb4098698aba3ea1cb23e06c3393d4f081d31a6a8f9be7a1596"
const OLD_FINGERPRINT="5a1269fa4d99c6482fcdbaec1782ddba755240dde46caf462310f28753594c4d"
const BACKUP_SUFFIX=".pre-trade-schema17.bak"
var checks:=0
var failures:=0
var host
var guest
var replies: Array=[]

func _ready() -> void:
	seed(20261118)
	await migration_contract()
	await live_contract()
	finish()

func migration_contract() -> void:
	var fixture_path:=OS.get_environment("BQ_MATERIAL_TRADE_FIXTURE")
	if fixture_path.is_empty(): fixture_path=FIXTURE
	var original: PackedByteArray=FileAccess.get_file_as_bytes(fixture_path)
	if not check(not original.is_empty() and FileAccess.get_sha256(fixture_path)==FIXTURE_HASH,"Synthetic save made now by unchanged released production PCK remains byte-exact"): return
	var old: Dictionary=JSON.parse_string(original.get_string_from_utf8())
	check(int(old.state.schema_version)==17 and old.fingerprint==OLD_FINGERPRINT and old.app=="1.9.1" and int(old.v)==3,"Actual untouched predecessor envelope records schema17/protocol3/package identity")
	var session=Session.new()
	session.discovery_enabled=false
	add_child(session)
	if not check(session.host("Handelsmigration","Prüfhost",0,24592).ok,"Private migration lobby opens its reserved port"):
		session.queue_free(); return
	var path: String="user://material-trade-legacy-%d.json" % OS.get_process_id()
	write_raw(path,original)
	check(not Protocol.handshake_error(old,session._app,session._fingerprint).is_empty(),"Old released peer identity is rejected by the unchanged strict network handshake")
	if not check(session.load_host_lobby(path).ok,"Actual old schema17 file loads through the recognized local migration path"):
		session.close_session(); session.queue_free(); return
	var current: Dictionary=session.game.snapshot()
	check(int(current.schema_version)==Save.CURRENT_VERSION and current.material_trades.is_empty() and int(current.trade_serial)==0,"Migration introduces empty trade state and an unused serial")
	var without_trade: Dictionary=current.duplicate(true)
	without_trade.erase("material_trades"); without_trade.erase("trade_serial")
	without_trade.erase("provisioning_report")
	for p in without_trade.provinces: p.erase("provisioning")
	without_trade.schema_version=17
	check(Save.state_equal(without_trade,old.state),"Every actual previous world/resource/context/research/project field is preserved independently of trade defaults")
	check(FileAccess.get_file_as_bytes(path)==original and FileAccess.get_file_as_bytes(path+BACKUP_SUFFIX)==original,"Original file and mandatory backup are byte-identical before any current save")
	var stable: Dictionary=session.game.snapshot()
	for variant in ["fingerprint","current_identity","schema","protocol","future_app","catalog"]:
		var forged: Dictionary=old.duplicate(true)
		match variant:
			"fingerprint": forged.fingerprint="unknown-identity"
			"current_identity": forged.fingerprint=session._fingerprint
			"schema": forged.state.schema_version=18
			"protocol": forged.v=2
			"future_app": forged.app="1.9.2"
			"catalog": forged.state.region_catalog_hash="unrelated-catalog"
		var rejected_path: String=path+"-"+str(variant)
		write_raw(rejected_path,JSON.stringify(forged).to_utf8_buffer())
		check(not session.load_host_lobby(rejected_path).ok and Save.state_equal(session.game.snapshot(),stable),"Forged historical admission changes neither current world nor logs: "+variant)
	check(session.save_host(path).ok,"Migrated lobby writes a genuine current host envelope")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(saved.state.schema_version)==Save.CURRENT_VERSION and saved.fingerprint==session._fingerprint and FileAccess.get_file_as_bytes(path+BACKUP_SUFFIX)==original,"New save uses current identity and preserves the original17 backup")
	var direct:=path+"-direct"
	write_raw(direct,original)
	check(session.save_host(direct).ok and FileAccess.get_file_as_bytes(direct+BACKUP_SUFFIX)==original,"Direct overwrite of never-loaded recognized17 target also protects exact original bytes")
	var changed: Dictionary=stable.duplicate(true)
	changed.trade_serial=int(changed.trade_serial)+1
	check(Protocol.world_hash(stable)!=Protocol.world_hash(changed),"Raw global trade serial participates in the shared world hash")
	session.close_session(); session.queue_free()
	await get_tree().process_frame
	# An actual connection advertising old content must still fail, even though
	# the local file above was admitted and backed up successfully.
	var current_host=Session.new()
	var old_peer=Session.new(null,OLD_FINGERPRINT)
	current_host.discovery_enabled=false; old_peer.discovery_enabled=false
	add_child(current_host); add_child(old_peer)
	check(current_host.host("Identitätsgrenze","Aktuell",0,24593).ok,"Strict handshake test uses a distinct reserved private port")
	check(old_peer.join("127.0.0.1","Alter Fingerabdruck",24593).ok,"Old identity actually attempts an ENet connection")
	check(await until(func():return old_peer.phase=="disconnected"),"Real old-identity peer is disconnected before joining the lobby")
	check(current_host.players.size()==1 and current_host.phase=="lobby","Rejected old peer cannot occupy a current seat or create game state")
	current_host.close_session(); old_peer.close_session()
	current_host.queue_free(); old_peer.queue_free()
	await get_tree().process_frame

func live_contract() -> void:
	host=Session.new(); guest=Session.new()
	host.discovery_enabled=false; guest.discovery_enabled=false
	add_child(host); add_child(guest)
	if not check(host.host("Baustoff-Grenzhandel","Verkäufer",0,24591).ok,"Current host opens reserved actual trade port"): return
	check(guest.join("127.0.0.1","Käufer",24591).ok,"Actual second human connects")
	if not check(await until(func():return guest.phase=="lobby" and host.players.size()==2),"Two actual peers pass the current content handshake"): return
	guest.choose_house(1); guest.set_ready(true)
	if not check(await until(func():return host.players[guest.local_peer_id].ready),"Counterparty seat/consent setup reaches authority"): return
	check(host.start_match().ok,"Host creates actual two-human trade world")
	if not check(await until(func():return guest.phase=="playing"),"Guest restores authoritative current world"): return
	host.game.speed=0
	guest.command_finished.connect(func(result):replies.append(result))
	var pair:=border(host.game,0,1)
	if not check(not pair.is_empty(),"Unchanged map supplies an actual shared land border"): return
	var source: Dictionary=host.game.province(str(pair.from))
	var target: Dictionary=host.game.province(str(pair.to))
	# Controlled pre-existing stock, never presented as normal production proof.
	source.production.materials_u=host.game.ProductionScript.stock_capacity_u(source)
	target.production.materials_u=0
	var quote: Dictionary=Trade.quote(source,target)
	if not check(not quote.is_empty(),"Actual rule module prices the genuine border charge"): return
	var stocks: Array=[int(source.production.materials_u),int(target.production.materials_u)]
	var funds: Array=[int(host.game.houses[0].gold),int(host.game.houses[1].gold)]
	check(host.submit({"id":"material_trade_offer","selection":str(pair.from),"from":str(pair.from),"to":str(pair.to)}).ok,"Actual host intent proposes the human-human contract")
	if not check(await until(func():return guest.game.material_trades.size()==1),"Offer arrives as authoritative raw contract state at the real guest"): return
	var trade_id: int=host.game.material_trades[0].id
	check(str(host.game.material_trades[0].status)=="offered" and int(host.game.material_trades[0].accepted_month)==-1,"Other human's goods/funds are not automatically committed")
	check([int(source.production.materials_u),int(target.production.materials_u)]==stocks and [int(host.game.houses[0].gold),int(host.game.houses[1].gold)]==funds,"Proposing books neither stock nor money")
	check(same_world() and int(guest.game.trade_serial)==int(host.game.trade_serial),"Contracts and serial are included in the actual shared snapshot/hash")
	host.game.advance_month()
	host.revision+=1; host._broadcast_snapshot()
	if not check(await until(func():return guest.game.calendar_index()==host.game.calendar_index()),"A real month also passes while the human offer is still unaccepted"): return
	check(str(host.game.material_trades[0].status)=="offered" and int(host.game.material_trades[0].delivered_lots)==0 and int(host.game.material_trades[0].accepted_month)==-1,"Autonomous monthly NPC logic never accepts or books the other human's open offer")
	check(int(host.game._last_production.regions[str(pair.from)].before_u)==int(stocks[0]) and int(host.game._last_production.regions[str(pair.to)].before_u)==int(stocks[1]) and [int(host.game.houses[0].gold),int(host.game.houses[1].gold)]==funds,"No hidden cross-house trade precedes ordinary production while consent is missing")
	var before: String=exact_host()
	check(not host.submit({"id":"material_trade_accept","selection":str(pair.from),"trade":trade_id}).ok and exact_host()==before,"Host cannot forge the counterparty's acceptance")
	check(await command({"id":"material_trade_accept","selection":str(pair.to),"trade":trade_id}) and bool(replies[-1].ok),"Actual guest explicitly accepts its offered contract through ENet")
	check(str(host.game.material_trades[0].status)=="active" and same_world(),"Acceptance is host-authoritative and equal at both peers")
	before=exact_host()
	host.game._tick_material_trade()
	check(exact_host()==before,"No delivery or log mutation occurs in the acceptance month")
	for id in ["material_trade_accept","material_trade_cancel"]:
		for key in ["house","seller","buyer","lot_gold","lot_u","delivered_lots","accepted_month"]:
			var forged: Dictionary={"id":id,"selection":str(pair.to),"trade":trade_id}
			forged[key]=0
			check(not guest.submit(forged).ok and exact_host()==before,"Real guest submission refuses forged authoritative trade field: "+key)
	var unrelated: String=""
	for p in host.game.provinces:
		if not [str(pair.from),str(pair.to)].has(str(p.id)): unrelated=str(p.id); break
	check(await command({"id":"material_trade_cancel","selection":unrelated,"trade":trade_id}) and not bool(replies[-1].ok) and exact_host()==before,"Actual stale guest selection cannot cancel a different region's contract")
	check(await command({"id":"material_trade_accept","selection":str(pair.to),"trade":trade_id}) and not bool(replies[-1].ok) and exact_host()==before,"Repeated actual guest acceptance cannot alter state or append a log")
	check(await command({"id":"set_speed","value":3}) and not bool(replies[-1].ok) and exact_host()==before,"Guest cannot advance the shared trading clock")
	var stock_source:=int(source.production.materials_u)
	var stock_target:=int(target.production.materials_u)
	var gold_seller:=int(host.game.houses[0].gold)
	var gold_buyer:=int(host.game.houses[1].gold)
	var accepted_month:=int(host.game.material_trades[0].accepted_month)
	host.game.advance_month()
	host.revision+=1; host._broadcast_snapshot()
	if not check(await until(func():return guest.game.calendar_index()==host.game.calendar_index()),"Only actual host monthly simulation delivers and synchronizes the trade"): return
	check(int(host.game.material_trades[0].delivered_lots)==1 and int(host.game.material_trades[0].last_delivery_month)>accepted_month,"Exactly one whole charge is recorded in the later real month")
	check(int(host.game._last_production.regions[str(pair.from)].before_u)==stock_source-int(quote.lot_u) and int(host.game._last_production.regions[str(pair.to)].before_u)==stock_target+int(quote.lot_u),"Existing production ledger begins after exact source/target trade stock booking")
	check(int(host.game.houses[0].gold)==gold_seller+int(quote.lot_gold) and int(host.game.houses[1].gold)==gold_buyer-int(quote.lot_gold),"Actual existing buyer money pays the actual seller atomically")
	check(same_world(),"Actual delivered contract/raw serial and ensuing production remain equal at both peers")
	before=exact_host()
	var source_before_cancel:=int(source.production.materials_u)
	var target_before_cancel:=int(target.production.materials_u)
	check(await command({"id":"material_trade_cancel","selection":str(pair.to),"trade":trade_id}) and bool(replies[-1].ok),"Actual buyer may cancel future deliveries")
	check(host.game.material_trades.is_empty() and int(source.production.materials_u)==source_before_cancel and int(target.production.materials_u)==target_before_cancel and int(host.game.houses[0].gold)==gold_seller+int(quote.lot_gold) and int(host.game.houses[1].gold)==gold_buyer-int(quote.lot_gold) and same_world(),"Cancellation removes only future contract and refunds neither real goods nor money")
	before=exact_host()
	check(await command({"id":"material_trade_cancel","selection":str(pair.to),"trade":trade_id}) and not bool(replies[-1].ok) and exact_host()==before,"Repeated actual cancellation changes neither world, serial nor personal logs")

func border(game,seller: int,buyer: int) -> Dictionary:
	for p in game.provinces:
		if int(p.owner)!=seller: continue
		for id in game.neighbours(str(p.id)):
			if int(game.province(str(id)).owner)==buyer: return {"from":str(p.id),"to":str(id)}
	return {}

func exact_host() -> String:
	var state: Dictionary=host.game.snapshot()
	check(not state.is_empty(),"Compared authoritative trade world remains valid")
	return JSON.stringify(state).sha256_text()

func same_world() -> bool:
	return Protocol.world_hash(host.game.snapshot())==Protocol.world_hash(guest.game.snapshot())

func command(value: Dictionary) -> bool:
	var count:=replies.size()
	if not guest.submit(value).ok: return false
	return await until(func():return not guest.pending_command and replies.size()>count)

func until(condition: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.015).timeout
	return condition.call()

func write_raw(path: String,raw: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	check(file!=null,"Own test file is writable")
	if file==null: return
	file.store_buffer(raw); file.close()

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADELANTEST FAIL: "+message)
	return ok

func finish() -> void:
	if host!=null: host.close_session()
	if guest!=null: guest.close_session()
	print("MATERIALTRADELANTEST %s; %d Prüfungen." % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
