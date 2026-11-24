extends Node
## Real ENet delivery first; malformed reports never replace the accepted world.
const Session = preload("res://scripts/LanSession.gd")
const Protocol = preload("res://scripts/LanProtocol.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Game = preload("res://scripts/Game.gd")
var checks := 0
var failures := 0
var host
var guest
var Report

class ReportIdentityVariant extends Session:
	func _production_rules() -> Dictionary:
		var rules: Dictionary=super._production_rules().duplicate(true)
		if rules.has("network_report"): rules.network_report.version=int(rules.network_report.version)+1
		return rules

func _ready() -> void:
	seed(20261118)
	host=Session.new(Data); guest=Session.new(Data)
	host.discovery_enabled=false; guest.discovery_enabled=false
	add_child(host); add_child(guest)
	var port:=45500+OS.get_process_id()%500
	check(host.host("Production report","Host",1,port).ok,"Real independent host opens")
	check(guest.join("127.0.0.1","Guest",port).ok,"Real ENet guest joins")
	if not check(await until(func():return guest.phase=="lobby" and host.players.size()==2),"Actual peers reach the lobby"): finish(); return
	guest.choose_house(0); guest.set_ready(true)
	if not check(await until(func():return bool(host.players[guest.local_peer_id].ready) and int(host.players[guest.local_peer_id].house)==0),"Actual guest owns its distinct assigned house"): finish(); return
	check(host.start_match().ok,"Actual shared108region world starts")
	if not check(await until(func():return guest.phase=="playing"),"Initial authoritative world reaches guest"): finish(); return
	check(guest.game._last_production.is_empty(),"Initial action report remains truly absent instead of inventing a month")
	var game=host.game
	game.speed=0
	# Controlled preexisting road/research only. Actual focus/project pay normal gold;
	# no material is injected and actual monthly Game computes the real delivery.
	game.houses[0].research.known=["surveying","road_building"]
	var source:="germanien__03"
	var target:="germanien__05"
	game.roads=[{"from":source,"to":target,"builder":0,"months":0,"state":"complete","construction":{}}]
	check(game.set_province_focus(source,"workshops",0).ok and game.start_regional_project(target,"walls",0).ok,"Guest house legally pays actual workshop and destination construction")
	check(int(game.province(source).production.materials_u)==0,"Delivery source starts without material gifts")
	var expected: Dictionary={}
	var delivered:=false
	for attempt in 4:
		game.advance_month()
		expected=game.regional_production_report(0)
		delivered=expected.flows.any(func(flow):return str(flow.from)==source and str(flow.to)==target and int(flow.amount_u)>0)
		if delivered: break
	if not check(delivered,"A Game month sends earned surplus over the real road as soon as reserves permit"): finish(); return
	host.revision+=1; host._broadcast_snapshot()
	check(await until(func():return guest.game.calendar_index()==game.calendar_index()),"Actual monthly snapshot arrives over ENet")
	var actual: Dictionary=guest.game.regional_production_report()
	check(not actual.ledger.is_empty() and actual.ledger==expected.ledger,"Guest receives the actual month ledger without simulating production")
	check(not actual.flows.is_empty() and actual.flows==expected.flows,"Guest sees the real delivery source, destination, path and quantities")
	check(load("res://scripts/SaveGame.gd").state_equal(actual,expected) and not actual.regions.has(str(game.houses[1].capital)),"Existing report API preserves guest-house perspective and the established JSON numeric contract")
	check(Protocol.world_hash(game.snapshot())==Protocol.world_hash(guest.game.snapshot()),"Transient report leaves ordinary world hash and accounts equal")
	var restored=Game.new(Data,0)
	check(restored.restore(game.snapshot()) and restored._last_production.is_empty(),"Offline restore has no invented monthly history or recovery simulation")
	if not check(ResourceLoader.exists("res://scripts/ProductionNetworkReport.gd"),"Pure strict report DTO module exists"): finish(); return
	Report=load("res://scripts/ProductionNetworkReport.gd")
	await pure_and_frames()
	await legacy_self_report()
	await abandoned_road_report(false)
	await ration_command()
	await abandoned_road_report(true)
	finish()

func pure_and_frames() -> void:
	var state: Dictionary=host._authority.snapshot_for_peer(guest.local_peer_id)
	var original: Dictionary=host.game._last_production.duplicate(true)
	var dto: Dictionary=Report.pack(original,state)
	var normalized: Dictionary=Report.normalize(dto,state)
	check(normalized.ok and normalized.data==original,"Strict DTO reproduces the authoritative transient report")
	check(host.game._last_production==original,"Packing and normalizing never mutate authoritative data")
	check(Report.normalize(Report.pack({},state),state).data.is_empty(),"Empty DTO normalizes to absence, not zero fake accounting")
	var numeric: Dictionary=JSON.parse_string(JSON.stringify(dto))
	check(Report.normalize(numeric,state).ok and Report.normalize(numeric,state).data==original,"JSON integral numeric quantities normalize exactly back to integer quanta")
	var counterfeit_state: Dictionary=state.duplicate(true)
	var p: Dictionary=state.provinces[0].duplicate(true)
	p.production.materials_u=1
	counterfeit_state.provinces=[p]
	var row: Dictionary={"owner":int(p.owner),"before_u":0,"produced_u":1,"used_u":0,"wasted_u":0,"work_u":0,"production_work_u":0,"legacy_work_u":0,"import_u":0,"export_u":0,"after_u":1}
	var counterfeit: Dictionary={"version":1,"month_index":state.month_index,"regions":{str(p.id):row},"flows":[],"edges":[]}
	check(not Report.normalize(counterfeit,counterfeit_state).ok,"Even one counterfeit material quantum without production work is rejected")
	var severed: Dictionary=state.duplicate(true); severed.roads=[]
	check(not Report.normalize(dto,severed).ok,"A report cannot invent a completed transport edge absent from the authoritative world")
	var cyclic: Dictionary=dto.duplicate(true); cyclic.flows.append(cyclic)
	check(not Report.normalize(cyclic,state).ok,"Cyclic Variant data is rejected before JSON serialization or recursion")
	cyclic.flows.clear()
	var id: String=dto.regions.keys()[0]
	var variants: Array=[]
	var bad: Dictionary=dto.duplicate(true); bad["gold"]=999; variants.append(bad)
	bad=dto.duplicate(true); bad.version=2; variants.append(bad)
	bad=dto.duplicate(true); bad.month_index=int(dto.month_index)+1; variants.append(bad)
	bad=dto.duplicate(true); bad.regions[id]["paid_gold"]=1; variants.append(bad)
	for value in [true,"1",0.5,-1,1000000000001,NAN,INF,null]:
		bad=dto.duplicate(true); bad.regions[id].produced_u=value; variants.append(bad)
	bad=dto.duplicate(true); bad.regions["unknown"]=bad.regions[id]; bad.regions.erase(id); variants.append(bad)
	bad=dto.duplicate(true); bad.regions[id].after_u=int(bad.regions[id].after_u)+1; variants.append(bad)
	bad=dto.duplicate(true); bad.regions[id].work_u=1000000000000; variants.append(bad)
	bad=dto.duplicate(true); bad.flows[0].path=[bad.flows[0].from,bad.flows[0].from,bad.flows[0].to]; variants.append(bad)
	bad=dto.duplicate(true); bad.flows[0].amount_u=int(bad.flows[0].amount_u)+1; variants.append(bad)
	bad=dto.duplicate(true); bad.flows[0].to="unknown"; variants.append(bad)
	bad=dto.duplicate(true); bad.edges.append(bad.edges[0].duplicate(true)); variants.append(bad)
	bad=dto.duplicate(true); bad.flows.resize(4097); variants.append(bad)
	bad=dto.duplicate(true); bad.edges.resize(1403); variants.append(bad)
	for index in variants.size():
		check(not Report.normalize(variants[index],state).ok,"Malformed accounting/IDs/bounds are rejected before commit: "+str(index))
	var frame: Dictionary={"v":Protocol.VERSION,"type":"snapshot","revision":guest.revision+1,"hash":Protocol.world_hash(state),"state":state,"missing_peer":false,"all_over":false,"production_report":dto}
	var packet: PackedByteArray=Protocol.encode_packet(frame)
	check(not packet.is_empty() and JSON.stringify(frame).to_utf8_buffer().size()<2097152 and Protocol.decode_packet(packet).ok,"Actual108region world plus bounded report fits compressed and unpacked2MiB contract")
	var too_large: Dictionary=frame.duplicate(true)
	too_large.state["padding"]=[]
	for index in 65: too_large.state.padding.append("x".repeat(32768))
	check(Protocol.encode_packet(too_large).is_empty(),"Unpacked world+report over2MiB is rejected even if highly compressible")
	var malformed_compressed: PackedByteArray="BQZ2".to_utf8_buffer(); malformed_compressed.resize(9); malformed_compressed.encode_u32(4,2097153)
	check(not Protocol.decode_packet(malformed_compressed).ok,"Declared inflated2MiB report packet is rejected before decompression")
	# Inject a valid candidate world with a bad DTO: acceptance must be atomic.
	var before: Dictionary=guest.game.snapshot()
	var before_report: Dictionary=guest.game._last_production.duplicate(true)
	var revision: int=guest.revision
	bad=frame.duplicate(true); bad.state.houses[0].gold+=1; bad.hash=Protocol.world_hash(bad.state); bad.production_report["gold"]=999
	guest._receive_snapshot(bad)
	check(guest.game.snapshot()==before and guest.game._last_production==before_report and guest.revision==revision,"Invalid DTO cannot commit even an otherwise valid newer world or replace its ledger")
	# The same rejected DTO crosses actual ENet, rather than a test-only decoder.
	var notices: Array=[]
	guest.status_changed.connect(func():notices.append(guest.status))
	check(host._send(guest.local_peer_id,bad),"Malformed DTO is sent through the real existing ENet peer")
	check(await until(func():return not notices.is_empty()),"Guest actually handles the malformed report frame")
	check(guest.game.snapshot()==before and guest.game._last_production==before_report and guest.revision==revision,"Actual malformed ENet frame leaves world and monthly report untouched")
	maximum_packet(state)
	var current=Session.new(Data)
	var changed=ReportIdentityVariant.new(Data)
	check(current._production_rules().network_report==Report.RULES and current._fingerprint!=changed._fingerprint,"Report rules participate in actual fingerprint and cache identity")
	current.free(); changed.free()

func maximum_packet(source: Dictionary) -> void:
	# Controlled schema/packet boundary fixture, not ordinary campaign financing.
	var state: Dictionary=source.duplicate(true)
	var by_id: Dictionary={}
	var serial:=0
	state.roads=[]
	for p in state.provinces:
		p.owner=0; p.buildings.market=2
		p.production.materials_u=host.game.ProductionScript.stock_capacity_u(p)
		serial+=1
		var requirement: Dictionary=host.game.ProductionScript.requirements(p,"market",3)
		p.regional_project={"id":serial,"builder":0,"kind":"market","target_level":3,"paid_gold":1000000000000,"material_total_u":int(requirement.material_total_u),"material_spent_u":0,"work_total_u":int(requirement.work_total_u),"work_done_u":0,"priority":1,"started_month":int(state.month_index)}
		by_id[str(p.id)]=p
	for a in Data.adjacency():
		for b in Data.adjacency()[a]:
			if str(a)>=str(b): continue
			serial+=1
			var requirement: Dictionary=host.game.ProductionScript.road_requirements(by_id[a],by_id[b])
			state.roads.append({"from":str(a),"to":str(b),"builder":0,"months":3,"state":"building","construction":{"id":serial,"paid_gold":1000000000000,"priority":1,"started_month":int(state.month_index),"legs":requirement.legs}})
	state.project_serial=1000000000
	state.houses[0].research.known=["surveying","road_building"]
	check(serial==334 and load("res://scripts/SaveGame.gd").validate(state).is_empty(),"Controlled maximum108regional/226road construction world is a genuinely valid snapshot")
	var world=Game.new(Data,0)
	if not check(world.restore(state),"Maximum production topology restores through real Game"): return
	world.advance_month()
	var projection: Dictionary=world.snapshot_for_player(0)
	var dto: Dictionary=Report.pack(world._last_production,projection)
	check(not dto.is_empty() and Report.normalize(dto,projection).ok,"Actual maximum-topology month produces a bounded valid shared-work report")
	var frame: Dictionary={"v":Protocol.VERSION,"type":"snapshot","revision":2,"hash":Protocol.world_hash(projection),"state":projection,"missing_peer":false,"all_over":false,"production_report":dto}
	var raw: PackedByteArray=Protocol.encode_packet(frame)
	var decoded: Dictionary=Protocol.decode_packet(raw)
	check(not raw.is_empty() and decoded.ok and Protocol.valid_snapshot_frame(decoded.message) and Report.normalize(decoded.message.production_report,decoded.message.state).ok,"Maximum valid world plus report encodes, bounded-decompresses and retains validated integer accounting")
	var unpacked: int=JSON.stringify(frame).to_utf8_buffer().size()
	check(unpacked<2097152,"Maximum production world and actual monthly report stay below uncompressed2MiB")
	print("PRODUCTION_REPORT_PACKET_BOUNDS unpacked_bytes=",unpacked," wire_bytes=",raw.size()," report_bytes=",JSON.stringify(dto).to_utf8_buffer().size())

func legacy_self_report() -> void:
	# Controlled old-road backing; the published original fixtures had no roads.
	var Legacy=load("res://scripts/Data.gd")
	var Save=load("res://scripts/SaveGame.gd")
	var old: Dictionary=Game.new(Legacy,0).snapshot()
	old.schema_version=16
	var a:="suebia"
	var b: String=Legacy.adjacency()[a][0]
	old.roads=[{"from":a,"to":b,"builder":0,"months":0,"state":"complete"}]
	var normalized: Dictionary=Save.migrate(old)
	if not check(normalized.ok,"Controlled old road with a real legacy adjacency normalizes"): return
	var converted: Dictionary=load("res://scripts/RegionMigration.gd").migrate_state(normalized.data)
	if not check(converted.ok,"Controlled old road gains actual original-backed region migration metadata"): return
	var state: Dictionary=converted.data
	var self_road: Dictionary=state.roads[0].duplicate(true)
	self_road.to=self_road.from
	state.roads.append(self_road)
	state.roads.append(state.roads[0].duplicate(true))
	if not check(Save.validate(state).is_empty(),"Original-backed controlled legacy self/duplicate road world is genuinely Save-valid"): return
	var world=Game.new(Data,1)
	if not check(world.restore(state) and world.configure_human_houses([1,0]),"Real regional Game restores the accepted exceptional road world"): return
	world.select_player_context(1)
	world.advance_month()
	var projection: Dictionary=world.snapshot_for_player(0)
	check(Save.validate(projection).is_empty(),"Actual exceptional-road month remains a valid projected world")
	var dto: Dictionary=Report.pack(world._last_production,projection)
	if not check(not dto.is_empty(),"Actual legacy self-edge month packs instead of blocking authoritative broadcast"): return
	var self_edges: Array=dto.edges.filter(func(edge):return str(edge.from)==str(edge.to))
	check(dto.edges.size()==2 and self_edges.size()==1 and not self_edges[0].active and int(self_edges[0].capacity_u)==0 and int(self_edges[0].used_u)==0 and self_edges[0].reason=="Identical road endpoints.","Duplicate old road shares one capacity and self-edge stays exactly inactive zero")
	var missing: Dictionary=projection.duplicate(true)
	missing.roads=missing.roads.filter(func(road):return str(road.from)!=str(road.to))
	check(not Report.normalize(dto,missing).ok,"Invented self-edge without exact historical world road remains rejected")
	var index: int=dto.edges.find(self_edges[0])
	for change in [{"active":true,"reason":""},{"capacity_u":1},{"used_u":1},{"reason":"Hostile occupation blocks the road."}]:
		var bad: Dictionary=dto.duplicate(true)
		bad.edges[index].merge(change,true)
		check(not Report.normalize(bad,projection).ok,"Active/nonzero/mislabelled self-edge remains rejected: "+str(change))
	host.game=world
	host._authority.game=world
	host.revision+=1
	host._broadcast_snapshot()
	check(await until(func():return guest.revision==host.revision),"Actual ENet broadcast accepts the Save-valid historical self/duplicate world")
	check(guest.game._last_production==world._last_production and guest.game.regional_production_report().ledger==world.regional_production_report(0).ledger,"Actual guest retains the validated legacy month and its own complete ledger")

func abandoned_road_report(captured: bool) -> void:
	# Normal constructors, funded research and the actual paid road API. No gifts.
	var world=Game.new(Data,1)
	world.configure_human_houses([1,0])
	var label:="capture" if captured else "cancel"
	check(world.start_research("surveying",0).ok,"Ordinary road history case pays surveying: "+label)
	for month in 4: world.advance_month()
	check(world.start_research("road_building",0).ok,"Ordinary road history case pays road research: "+label)
	for month in 6: world.advance_month()
	var a:="germanien__03"
	var b:="germanien__05"
	var gold: int=world.houses[0].gold
	var price: int=world.road_preview(a,b,0).gold
	if not check(world.build_road(a,b,0).ok and int(world.houses[0].gold)==gold-price,"Ordinary road API accepts and pays the new project exactly once: "+label): return
	var road: Dictionary={}
	for item in world.roads:
		if [str(item.from),str(item.to)].has(a) and [str(item.from),str(item.to)].has(b): road=item; break
	world.advance_month()
	if not check(not road.is_empty() and str(road.state)=="building" and not road.construction.is_empty(),"Actual next month has worked but not completed the paid road: "+label): return
	var report_before: Dictionary=world._last_production.duplicate(true)
	check(report_before.edges.any(func(edge):return [str(edge.from),str(edge.to)].has(a) and [str(edge.from),str(edge.to)].has(b) and not edge.active and int(edge.used_u)==0),"Actual last-month diagnostics contain the inactive unfinished edge: "+label)
	gold=int(world.houses[0].gold)
	var stock: Dictionary=world.province(b).production.duplicate(true)
	if captured: world._capture_province(b,1)
	else: check(world.cancel_construction(a,int(road.construction.id),0).ok,"Actual explicit construction cancellation succeeds")
	check(not world.roads.any(func(item):return [str(item.from),str(item.to)].has(a) and [str(item.from),str(item.to)].has(b)) and int(world.houses[0].gold)==gold and world.province(b).production==stock,"Actual removal retains real stock and never refunds the paid road: "+label)
	check(world._last_production==report_before,"Removing a road never rewrites the already completed month's accounting: "+label)
	var projection: Dictionary=world.snapshot_for_player(0)
	check(not Report.pack(report_before,projection).is_empty(),"Valid past inactive diagnostics do not block an ordinary authoritative snapshot: "+label)
	host.game=world; host._authority.game=world
	host.revision+=1; host._broadcast_snapshot()
	check(await until(func():return guest.revision==host.revision),"Actual ENet snapshot after removing the worked road arrives: "+label)
	check(load("res://scripts/SaveGame.gd").state_equal(guest.game.regional_production_report(),world.regional_production_report(0)) and guest.game._last_production==report_before,"Guest public report and genuine past ledger remain equal after removal: "+label)
	check(Protocol.world_hash(guest.game.snapshot())==Protocol.world_hash(world.snapshot()),"Removed-road host and guest retain identical actual world accounts: "+label)

func ration_command() -> void:
	var world=host.game
	var id:String=str(world.houses[0].capital)
	var foreign:String=str(world.houses[1].capital)
	var old_food:int=int(world.province(id).provisioning.food_u)
	var replies:Array=[]
	var observe:=func(result):replies.append(result)
	guest.command_finished.connect(observe)
	for variant in [{"rations":true},{"rations":"free"},{"rations":"normal","food_u":999}]:
		var command:Dictionary={"id":"province_rations","selection":id}
		command.merge(variant)
		check(not guest.submit(command).ok,"Guest cannot inject or invent a ration")
	check(guest.submit({"id":"province_rations","selection":foreign,"rations":"generous"}).ok,"Actual ENet request attempts to use the other house")
	if not check(await until(func():return replies.size()==1),"Authority replies to the attempted foreign change"): return
	check(not replies[0].ok and str(world.province(foreign).provisioning.rations)=="normal","Actual host rejects foreign ration adjustments")
	check(guest.submit({"id":"province_rations","selection":id,"rations":"generous"}).ok,"Real guest submits a ration for its house")
	if not check(await until(func():return replies.size()==2 and str(guest.game.province(id).provisioning.rations)=="generous"),"Actual host accepts and broadcasts the guest policy"): return
	check(replies[1].ok and int(world.province(id).provisioning.food_u)==old_food,"Policy acknowledgement alone books no food")
	world.advance_month()
	host.revision+=1
	host._broadcast_snapshot()
	if not check(await until(func():return guest.revision==host.revision),"New actual food ledger arrives over ENet"): return
	var host_food:Dictionary=world.provision_report(0)
	var guest_food:Dictionary=guest.game.provision_report(0)
	check(host_food==guest_food and host_food.regions[id].consumed_u>0 and host_food.regions[id].rations=="generous","Both peers share the one real consumption ledger")
	check(Protocol.world_hash(world.snapshot())==Protocol.world_hash(guest.game.snapshot()),"Food and real monthly ledger participate in the same world hash")
	guest.command_finished.disconnect(observe)

func until(condition: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.015).timeout
	return condition.call()

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PRODUCTIONLANREPORTTEST FAIL: "+message)
	return ok

func finish() -> void:
	if host!=null: host.close_session()
	if guest!=null: guest.close_session()
	print("PRODUCTIONLANREPORTTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
