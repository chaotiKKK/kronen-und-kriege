extends Node
## Real protocol/kernel/authority; controlled stock is not normal-campaign proof.
const Protocol=preload("res://scripts/LanProtocol.gd")
const Kernel=preload("res://scripts/UiKernel.gd")
const Authority=preload("res://scripts/LanAuthority.gd")
const Session=preload("res://scripts/LanSession.gd")
const Game=preload("res://scripts/Game.gd")
const Data=preload("res://scripts/GameRegionData.gd")
const Trade=preload("res://scripts/MaterialTrade.gd")
class TradeRuleVariant extends Session:
	func _material_trade_rules() -> Dictionary:
		var rules: Dictionary=super._material_trade_rules().duplicate(true)
		rules.contract["algorithm_version"]=int(rules.contract.algorithm_version)+1
		return rules
class TradeStateVariant extends Session:
	func _material_trade_rules() -> Dictionary:
		var rules: Dictionary=super._material_trade_rules().duplicate(true)
		rules.state_fields.append("controlled_extra_field")
		return rules
class GameTradePolicyVariant extends Session:
	func _material_trade_rules() -> Dictionary:
		var rules: Dictionary=super._material_trade_rules().duplicate(true)
		if rules.get("game") is Dictionary:
			rules.game["source_reserve_weights"]=int(rules.game.source_reserve_weights)+1
		return rules
var checks:=0
var failures:=0

func _ready() -> void:
	protocol_contract()
	fingerprint_contract()
	actor_contract()
	print("MATERIALTRADECOMMANDTEST %s; %d Prüfungen." % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)

func protocol_contract() -> void:
	for command in [{"id":"material_trade_offer","from":"germanien__05","to":"gallien__01"},{"id":"material_trade_accept","trade":1},{"id":"material_trade_cancel","trade":1000000000}]:
		var valid: Dictionary=Protocol.validate_command(command)
		check(valid.ok,"Only endpoint/trade-ID intent is a valid typed command: "+str(command.id))
		for key in ["house","seller","buyer","proposer","gold","lot_u","lot_gold","amount_u","expires_month","accepted_month","status"]:
			var forged: Dictionary=command.duplicate(true)
			forged[key]=1
			check(not Protocol.validate_command(forged).ok,"Client cannot prescribe authoritative trade field "+key)
	for id in ["material_trade_accept","material_trade_cancel"]:
		for value in [null,true,false,0,-1,1.5,INF,NAN,1000000001,"1",{}]:
			check(not Protocol.validate_command({"id":id,"trade":value}).ok,"Malformed/zero/out-of-range trade ID is rejected: "+str(value))
		check(not Protocol.validate_command({"id":id}).ok,"Missing trade ID is rejected")
	for key in ["from","to"]:
		for value in ["","a\nb","a".repeat(81),1,true,{},[]]:
			var bad: Dictionary={"id":"material_trade_offer","from":"a","to":"b"}
			bad[key]=value
			check(not Protocol.validate_command(bad).ok,"Malformed endpoint never reaches authority: "+key)

func fingerprint_contract() -> void:
	var session=Session.new()
	if check(session.has_method("_material_trade_rules"),"Actual LAN identity exposes all pure trade rules and authoritative state fields"):
		var identity: Dictionary=session._material_trade_rules()
		check(identity.get("contract")==Trade.RULES and identity.get("state_fields")==["material_trades","trade_serial"],"Identity binds the exact actual contract rules and both raw shared fields")
		check(identity.get("game")==Game.MATERIAL_TRADE_RULES,"LAN identity binds the actual authoritative reserves, own transport, phase and NPC trade policies")
		var original: String=session._fingerprint
		var variants: Array=[]
		for type in [TradeRuleVariant,TradeStateVariant]:
			var changed=type.new()
			check(not changed._fingerprint.is_empty() and changed._fingerprint!=original and not variants.has(changed._fingerprint),"Rules-only/state-only identity changes invalidate the populated fingerprint cache")
			variants.append(changed._fingerprint)
			changed.free()
		var game_policy=GameTradePolicyVariant.new()
		check(game_policy._fingerprint!=original and not variants.has(game_policy._fingerprint),"A Game-only source-reserve policy change invalidates the populated content fingerprint cache")
		game_policy.free()
		check(original!="5a1269fa4d99c6482fcdbaec1782ddba755240dde46caf462310f28753594c4d","Current trade peers cannot advertise the actual published schema17 identity")
	session.free()

func actor_contract() -> void:
	var game=Game.new(Data,0)
	check(game.configure_human_houses([0,1]),"Controlled actual world assigns both trading parties to humans")
	var pair:=border(game,0,1)
	if not check(not pair.is_empty(),"Actual unchanged 108-region map contains the two human houses' land border"): return
	# Controlled pre-existing stock isolates consent/authority; no extra money.
	var source: Dictionary=game.province(str(pair.from))
	source.production.materials_u=game.ProductionScript.stock_capacity_u(source)
	game.province(str(pair.to)).production.materials_u=0
	var pristine: Dictionary=game.snapshot()
	var outsider=Authority.new(game,{3:2})
	check(not outsider.execute(3,1,{"id":"material_trade_offer","selection":str(pair.from),"from":str(pair.from),"to":str(pair.to)}).ok and game.snapshot()==pristine,"Uninvolved actual seat cannot propose a presently deliverable contract between the two other parties")
	var kernel=Kernel.new()
	kernel.bind_game(game)
	kernel.select_province(str(pair.from))
	var first: Dictionary=kernel.dispatch({"id":"material_trade_offer","from":str(pair.from),"to":str(pair.to)})
	if not check(first.ok,"Actual UiKernel routes a real own-party material offer into Game"): return
	check(game.material_trades.size()==1 and str(game.material_trades[0].status)=="offered","A human counterparty is never automatically committed by the offer")
	var trade_id: int=game.material_trades[0].id
	var before: Dictionary=game.snapshot()
	check(not before.is_empty(),"Compared trade world is genuinely valid and saveable")
	for command in [
		{"id":"material_trade_offer","from":str(pair.from),"to":str(pair.to)},
		{"id":"material_trade_accept","trade":trade_id},
		{"id":"material_trade_accept","trade":true},
		{"id":"material_trade_cancel","trade":trade_id,"house":1},
		{"id":"material_trade_offer","from":str(pair.from),"to":str(pair.to),"lot_gold":0}]:
		check(not kernel.dispatch(command).ok and game.snapshot()==before,"Repeated, self-accepting or forged direct kernel intent changes neither world nor log")
	var unrelated:=other_region(game,[str(pair.from),str(pair.to)])
	kernel.select_province(unrelated)
	for command in [{"id":"material_trade_offer","from":str(pair.from),"to":str(pair.to)},{"id":"material_trade_cancel","trade":trade_id},{"id":"material_trade_accept","trade":trade_id}]:
		check(not kernel.dispatch(command).ok and game.snapshot()==before,"Stale callback after a different province selection cannot retarget or cancel a trade")
	kernel.select_province(str(pair.from))
	check(not kernel.dispatch({"id":"material_trade_cancel","trade":trade_id,"selection":unrelated}).ok and game.snapshot()==before,"Forged command selection cannot replace the current local province context")
	var authority=Authority.new(game,{1:0,2:1,3:2})
	var sequence:=1
	check(not authority.execute(3,sequence,{"id":"material_trade_accept","selection":str(pair.to),"trade":trade_id}).ok and game.snapshot()==before,"Third-house seat cannot accept another pair's contract")
	check(authority.execute(2,sequence,{"id":"material_trade_accept","selection":str(pair.to),"trade":trade_id}).ok,"Only the actual counterparty seat can accept the real offer")
	check(str(game.material_trades[0].status)=="active" and game.player==0,"Host authority records acceptance and restores its prior player perspective")
	before=game.snapshot()
	check(not authority.execute(2,sequence,{"id":"material_trade_accept","selection":str(pair.to),"trade":trade_id}).ok and game.snapshot()==before,"Replayed network sequence cannot repeat acceptance or log output")
	check(not authority.execute(3,sequence+1,{"id":"material_trade_cancel","selection":str(pair.to),"trade":trade_id}).ok and game.snapshot()==before,"Third-house seat cannot cancel an active contract")
	check(authority.execute(2,sequence+1,{"id":"material_trade_cancel","selection":str(pair.to),"trade":trade_id}).ok and game.material_trades.is_empty(),"Actual counterparty can end future deliveries without refund fiction")
	before=game.snapshot()
	check(not authority.execute(2,sequence+2,{"id":"material_trade_cancel","selection":str(pair.to),"trade":trade_id}).ok and game.snapshot()==before,"Repeated cancellation has no world, serial or log side effect")

func border(game,seller: int,buyer: int) -> Dictionary:
	for p in game.provinces:
		if int(p.owner)!=seller: continue
		for adjacent in game.neighbours(str(p.id)):
			var q: Dictionary=game.province(str(adjacent))
			if not q.is_empty() and int(q.owner)==buyer: return {"from":str(p.id),"to":str(q.id)}
	return {}

func other_region(game,excluded: Array) -> String:
	for p in game.provinces:
		if not excluded.has(str(p.id)): return str(p.id)
	return ""

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADECOMMANDTEST FAIL: "+message)
	return ok
