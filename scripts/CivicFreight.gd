extends RefCounted
## Local provisions and materials share the same completed-road allocator.
const Food = preload("res://scripts/CivicProvision.gd")
const Transport = preload("res://scripts/MaterialTransport.gd")
const EXPORT_RESERVE := 4
const SPECIALIST_RESERVE := 3
const RELIEF_RESERVE := 2
const RULES := {"version":1,"agricultural_export_reserve":EXPORT_RESERVE,
	"specialists":["workshops","trade"],"specialist_reserve":SPECIALIST_RESERVE,
	"other_relief_below":RELIEF_RESERVE,"maximum_receipt":"one-chosen-ration",
	"declared_stock":"opening-only-with-donor-ration-protected","goods":"food-first-materials-use-remaining",
	"eligible_owner_and_topology":"same-as-materials"}

static func plan(provinces: Array, roads: Array, month: int, blocked: Dictionary, storage_bonuses: Dictionary) -> Dictionary:
	var bins := {}
	var offers := {}
	var demands: Array=[]
	for p in provinces:
		var id:=str(p.id)
		if blocked.has(id):
			continue
		var stock:=int(p.provisioning.food_u)
		var need:=Food.need_u(p)
		var ration:=Food.requested_u(p)
		var focus:=str(p.get("economic_focus","balanced"))
		var capacity:=Food.capacity_u(p,storage_bonuses.get(id,{}))
		bins[id]={"stock_u":stock,"room_u":maxi(0,capacity-stock)}
		if focus=="agriculture":
			var available:=maxi(0,stock-EXPORT_RESERVE*need-ration)
			if available>0: offers[id]=available
		var specialist:bool=focus in RULES.specialists
		if not specialist and stock>=RELIEF_RESERVE*need:
			continue
		var reserve:=SPECIALIST_RESERVE if specialist else RELIEF_RESERVE
		var amount:=mini(ration,maxi(0,need*reserve+ration-stock))
		if amount>0:
			demands.append({"province":id,"house":int(p.owner),"amount_u":amount,"priority":1 if stock<RELIEF_RESERVE*need else 0,"project_id":0})
	if offers.is_empty() or demands.is_empty():
		return {"deltas":{},"flows":[],"edges":[]}
	return Transport.plan(provinces,roads,demands,offers,month,blocked,bins)

static func used_space(flows: Array) -> Dictionary:
	var space := {}
	for flow in flows:
		for i in flow.path.size()-1:
			var key:=Transport.edge_key(str(flow.path[i]),str(flow.path[i+1]))
			space[key]=int(space.get(key,0))+int(flow.amount_u)
	return space
