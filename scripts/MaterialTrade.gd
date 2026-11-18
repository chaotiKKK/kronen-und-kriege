extends RefCounted
## Pure inter-house material trading. Game alone owns all mutations.
const Production = preload("res://scripts/RegionalProduction.gd")
const MAX_SERIAL := 1000000000
const MAX_UNITS := 1000000000000
const MAX_DATE := 9223372036854775800
const FIELDS := ["id","seller","buyer","from","to","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots","status"]
const NUMBER_FIELDS := ["id","seller","buyer","proposer","lot_u","lot_gold","created_month","expires_month","accepted_month","last_delivery_month","delivered_lots"]
const RULES := {"algorithm_version":2,"max_contracts":64,"max_active_per_house":2,
	"max_offered_per_proposer":1,"max_lots":3,"expiry_months":6,"max_serial":MAX_SERIAL,"max_units":MAX_UNITS,
	"unit":Production.UNIT,"lot_edge_weight":true,"gold_numerator":2,
	"price_rounds_up":true,"original_stock_only":true,"original_room_only":true,
	"original_funds_only":true,"game_reserves_precede_offers":true,
	"shared_original_npc_target_need_budget":true,"unlisted_target_needs_unbounded":true,
	"one_lot_per_month":true,"expiry_inclusive":true,"first_delivery_after_acceptance":true,
	"equal_contracts_rotate_by_month":true,"ownership_change_closes":true,
	"hostile_presence_pauses":true,"direct_land_neighbours_only":true}

static func quote(source: Dictionary, target: Dictionary) -> Dictionary:
	for province in [source,target]:
		var weight: Variant=province.get("economic_share",1.0)
		if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight)<0.0 or float(weight)>float(Production.MAX_WEIGHT_U)/Production.UNIT:
			return {}
	var lot := maxi(1,Production.edge_weight_u(source,target))
	@warning_ignore("integer_division")
	var gold: int=(2*lot+Production.UNIT-1)/Production.UNIT
	return {"lot_u":lot,"lot_gold":maxi(1,gold)}

static func validate(contracts: Variant, serial: Variant, provinces: Array, houses: Array, adjacency: Dictionary, now: int) -> Array:
	var errors: Array=[]
	if not _whole(serial,0,MAX_SERIAL): errors.append("Ungültige Handelskennung.")
	if not contracts is Array: errors.append("Handelsverträge müssen eine Liste sein."); return errors
	if contracts.size()>int(RULES.max_contracts): errors.append("Zu viele gespeicherte Handelsverträge."); return errors
	if now<0: errors.append("Ungültiger Handelsmonat."); return errors
	var catalog:=_catalog(provinces)
	var admitted: Array=[]
	for raw in contracts:
		var reasons:=_contract_errors(raw,int(serial) if _whole(serial,0,MAX_SERIAL) else 0,catalog,houses.size(),adjacency,now)
		errors.append_array(reasons)
		if reasons.is_empty(): admitted.append(_canonical(raw))
	var limits:=_limit_failures(admitted)
	for reason in limits.values():
		if not errors.has(reason): errors.append(reason)
	return errors

static func plan(provinces: Array, contracts: Array, offers: Dictionary, funds: Dictionary, month_index: int, blocked: Dictionary, hostile_pairs: Dictionary, adjacency: Dictionary, npc_needs: Dictionary = {}) -> Dictionary:
	var result: Dictionary={"stock_deltas":{},"gold_deltas":{},"deliveries":[],"contracts":[],"statuses":{}}
	if month_index<0: return result
	if contracts.size()>int(RULES.max_contracts):
		for raw in contracts.slice(0,int(RULES.max_contracts)):
			if raw is Dictionary and _whole(raw.get("id"),1,MAX_SERIAL): result.statuses[str(int(raw.id))]="Zu viele gespeicherte Handelsverträge."
		return result
	var catalog:=_catalog(provinces)
	var pending: Array=[]
	var raw_id_counts: Dictionary={}
	for raw in contracts:
		if raw is Dictionary and _whole(raw.get("id"),1,MAX_SERIAL):
			var raw_id:=str(int(raw.id))
			raw_id_counts[raw_id]=int(raw_id_counts.get(raw_id,0))+1
		var reasons:=_contract_errors(raw,MAX_SERIAL,catalog,-1,adjacency,month_index)
		if reasons.is_empty(): pending.append(_canonical(raw))
		elif raw is Dictionary and _whole(raw.get("id"),1,MAX_SERIAL): result.statuses[str(int(raw.id))]="Ungültiger Handelsvertrag: "+str(reasons[0])
	var failures:=_limit_failures(pending)
	for id in raw_id_counts:
		if int(raw_id_counts[id])>1: failures[id]="Doppelte Vertragskennung."
	pending.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.id)<int(b.id))
	var available: Dictionary={}
	var room: Dictionary={}
	var budgets: Dictionary={}
	var need_budgets: Dictionary={}
	for id in catalog:
		if npc_needs.has(id): need_budgets[id]=_budget(npc_needs[id])
		var province: Dictionary=catalog[id]
		var production: Variant=province.get("production")
		if not production is Dictionary or not _whole(production.get("materials_u"),0,MAX_UNITS): continue
		var stock:=int(production.materials_u)
		var capacity:=Production.stock_capacity_u(province)
		if quote(province,province).is_empty() or stock>capacity: continue
		available[id]=mini(stock,_budget(offers.get(id,0)))
		room[id]=capacity-stock
	for key in funds:
		if key is String and str(key).is_valid_int() and str(key)==str(int(key)) and _whole(int(key),0,MAX_SERIAL): budgets[key]=_budget(funds[key])
	var rotation:=posmod(month_index,pending.size()) if not pending.is_empty() else 0
	for position in pending.size():
		var contract: Dictionary=pending[(position+rotation)%pending.size()]
		var id:=str(int(contract.id))
		if failures.has(id): result.statuses[id]=failures[id]; continue
		var source:=str(contract.from)
		var target:=str(contract.to)
		var seller:=str(int(contract.seller))
		var buyer:=str(int(contract.buyer))
		if not _whole(catalog[source].get("owner"),0,MAX_SERIAL) or not _whole(catalog[target].get("owner"),0,MAX_SERIAL) or int(catalog[source].owner)!=int(contract.seller) or int(catalog[target].owner)!=int(contract.buyer):
			result.statuses[id]="Besitz gewechselt: Handel beendet."
			continue
		if month_index>int(contract.expires_month): result.statuses[id]="Angebot oder Vertrag abgelaufen."; continue
		var reason:=""
		if str(contract.status)=="offered": reason="Gegenbestätigung ausstehend."
		elif month_index<=int(contract.accepted_month): reason="Erste Lieferung nach dem Annahmemonat."
		elif int(contract.last_delivery_month)==month_index: reason="Diesen Monat bereits geliefert."
		elif _flag(blocked.get("trade:"+id,false)):
			var restriction: Variant=blocked["trade:"+id]
			reason=str(restriction) if restriction is String else "Handel derzeit gesperrt."
		elif _blocked(catalog[source],blocked) or _blocked(catalog[target],blocked): reason="Feindliche Stellung unterbricht den Handel."
		elif _flag(hostile_pairs.get(_house_pair(int(contract.seller),int(contract.buyer)),false)): reason="Feindliche Vertragsparteien: Handel pausiert."
		elif not available.has(source) or not room.has(target): reason="Ungültiger örtlicher Materialbestand."
		elif int(available[source])<int(contract.lot_u): reason="Keine vollständige freie Baustoffcharge."
		elif int(room[target])<int(contract.lot_u): reason="Nicht genug freier Lagerraum für eine Charge."
		elif need_budgets.has(target) and int(need_budgets[target])<int(contract.lot_u): reason="Der verbleibende NPC-Baustellenbedarf reicht nicht für eine vollständige Charge."
		elif not budgets.has(seller) or not budgets.has(buyer) or int(budgets[buyer])<int(contract.lot_gold): reason="Käufer kann die vollständige Charge nicht bezahlen."
		if not reason.is_empty():
			result.statuses[id]=reason
			result.contracts.append(contract)
			continue
		var lot:=int(contract.lot_u)
		var gold:=int(contract.lot_gold)
		available[source]=int(available[source])-lot
		room[target]=int(room[target])-lot
		if need_budgets.has(target): need_budgets[target]=int(need_budgets[target])-lot
		budgets[buyer]=int(budgets[buyer])-gold
		result.stock_deltas[source]=int(result.stock_deltas.get(source,0))-lot
		result.stock_deltas[target]=int(result.stock_deltas.get(target,0))+lot
		result.gold_deltas[seller]=int(result.gold_deltas.get(seller,0))+gold
		result.gold_deltas[buyer]=int(result.gold_deltas.get(buyer,0))-gold
		result.deliveries.append({"trade_id":int(contract.id),"seller":int(contract.seller),"buyer":int(contract.buyer),"from":source,"to":target,"amount_u":lot,"gold":gold})
		contract.delivered_lots=int(contract.delivered_lots)+1
		contract.last_delivery_month=month_index
		if int(contract.delivered_lots)<int(RULES.max_lots):
			result.contracts.append(contract)
			result.statuses[id]="Charge geliefert · %d/3." % int(contract.delivered_lots)
		else: result.statuses[id]="Drei Chargen geliefert: Vertrag beendet."
	result.contracts.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.id)<int(b.id))
	result.stock_deltas=_ordered_nonzero(result.stock_deltas)
	result.gold_deltas=_ordered_nonzero(result.gold_deltas)
	result.statuses=_ordered(result.statuses)
	return result

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if value is int: return value>=minimum and value<=maximum
	# Beyond the exact JSON-double integer range, do not coerce rounded floats.
	return value is float and is_finite(value) and absf(value)<=9007199254740991.0 and floor(value)==value and value>=minimum and value<=maximum

static func _budget(value: Variant) -> int:
	return int(value) if value is int and value>=0 and value<=MAX_UNITS else 0

static func _catalog(provinces: Array) -> Dictionary:
	var counts: Dictionary={}
	for raw in provinces:
		if raw is Dictionary and raw.get("id") is String and not str(raw.id).is_empty(): counts[raw.id]=int(counts.get(raw.id,0))+1
	var catalog: Dictionary={}
	for raw in provinces:
		if raw is Dictionary and raw.get("id") is String and int(counts.get(raw.id,0))==1: catalog[raw.id]=raw
	return catalog

static func _contract_errors(raw: Variant, serial: int, catalog: Dictionary, house_count: int, adjacency: Dictionary, now: int) -> Array:
	if not raw is Dictionary: return ["Ungültiger Handelsvertrag."]
	var keys: Array=raw.keys()
	if keys.size()!=FIELDS.size(): return ["Fehlende oder fremde Vertragsfelder."]
	for key in FIELDS:
		if not raw.has(key): return ["Fehlende oder fremde Vertragsfelder."]
	for key in NUMBER_FIELDS:
		var minimum: int=-1 if key in ["accepted_month","last_delivery_month"] else 0
		var maximum: int=MAX_DATE+6 if key in ["created_month","expires_month","accepted_month","last_delivery_month"] else MAX_UNITS
		if not _whole(raw[key],minimum,maximum): return ["Ungültige ganze Vertragszahl: "+str(key)]
	if not _whole(raw.id,1,serial): return ["Vertragskennung liegt außerhalb der gespeicherten Serie."]
	var maximum_house: int=house_count-1 if house_count>=0 else MAX_SERIAL
	for key in ["seller","buyer","proposer"]:
		if not _whole(raw[key],0,maximum_house): return ["Unbekannte Vertragspartei."]
	if int(raw.seller)==int(raw.buyer) or not int(raw.proposer) in [int(raw.seller),int(raw.buyer)]: return ["Verkäufer, Käufer und Vorschlagender passen nicht zusammen."]
	if not raw.from is String or not raw.to is String or str(raw.from)==str(raw.to) or not catalog.has(raw.from) or not catalog.has(raw.to): return ["Unbekannte oder gleiche Handelsregionen."]
	var neighbours: Variant=adjacency.get(raw.from,[])
	var reverse: Variant=adjacency.get(raw.to,[])
	if not neighbours is Array or not reverse is Array or not neighbours.has(raw.to) or not reverse.has(raw.from): return ["Handelsregionen sind keine direkten Landnachbarn."]
	var price:=quote(catalog[raw.from],catalog[raw.to])
	if price.is_empty() or int(raw.lot_u)!=int(price.lot_u) or int(raw.lot_gold)!=int(price.lot_gold): return ["Chargenmenge oder Preis widerspricht der festen Grenzformel."]
	if not raw.status is String or not str(raw.status) in ["offered","active"]: return ["Unbekannter Handelsstatus."]
	var created:=int(raw.created_month)
	var expires:=int(raw.expires_month)
	var accepted:=int(raw.accepted_month)
	var delivered:=int(raw.delivered_lots)
	var last:=int(raw.last_delivery_month)
	if created>now or created>MAX_DATE or expires!=created+int(RULES.expiry_months): return ["Ungültige Erstellungs- oder Ablauffrist."]
	if str(raw.status)=="offered":
		if accepted!=-1 or last!=-1 or delivered!=0: return ["Offenes Angebot enthält Annahme oder Lieferung."]
	else:
		if accepted<created or accepted>mini(now,expires) or delivered<0 or delivered>=int(RULES.max_lots): return ["Ungültige Annahme oder Lieferanzahl."]
		if (delivered==0 and last!=-1) or (delivered>0 and (last<=accepted or last-accepted<delivered or last>mini(now,expires))): return ["Ungültiger letzter Liefermonat."]
	return []

static func _canonical(raw: Dictionary) -> Dictionary:
	var contract:=raw.duplicate(true)
	for key in NUMBER_FIELDS: contract[key]=int(contract[key])
	return contract

static func _limit_failures(contracts: Array) -> Dictionary:
	var ids: Dictionary={}; var pairs: Dictionary={}; var active: Dictionary={}; var offered: Dictionary={}
	for contract in contracts:
		var id:=str(int(contract.id))
		var pair:=JSON.stringify([contract.from,contract.to])
		ids[id]=int(ids.get(id,0))+1
		pairs[pair]=int(pairs.get(pair,0))+1
		if str(contract.status)=="active":
			for house in [str(int(contract.seller)),str(int(contract.buyer))]: active[house]=int(active.get(house,0))+1
		else:
			var proposer:=str(int(contract.proposer))
			offered[proposer]=int(offered.get(proposer,0))+1
	var result: Dictionary={}
	for contract in contracts:
		var id:=str(int(contract.id))
		if int(ids[id])>1: result[id]="Doppelte Vertragskennung."
		elif int(pairs[JSON.stringify([contract.from,contract.to])])>1: result[id]="Doppelte gerichtete Handelsbeziehung."
		elif str(contract.status)=="active" and (int(active.get(str(int(contract.seller)),0))>int(RULES.max_active_per_house) or int(active.get(str(int(contract.buyer)),0))>int(RULES.max_active_per_house)): result[id]="Mehr als zwei aktive Verträge je Haus."
		elif str(contract.status)=="offered" and int(offered.get(str(int(contract.proposer)),0))>int(RULES.max_offered_per_proposer): result[id]="Mehr als ein eigenes offenes Angebot."
	return result

static func _house_pair(a: int,b: int) -> String:
	return str(mini(a,b))+"|"+str(maxi(a,b))

static func _flag(value: Variant) -> bool:
	if value is bool: return value
	if value is String: return not value.is_empty()
	return true # Malformed blockade data must not enable a transfer.

static func _blocked(province: Dictionary, blocked: Dictionary) -> bool:
	if _flag(blocked.get(str(province.id),false)): return true
	var siege: Variant=province.get("siege",0)
	var besieger: Variant=province.get("siege_owner",-1)
	if not _whole(siege,0,100) or not _whole(besieger,-1,MAX_SERIAL): return true
	return int(siege)>0 and int(besieger)>=0 and int(besieger)!=int(province.owner)

static func _ordered(values: Dictionary) -> Dictionary:
	var keys: Array=values.keys(); keys.sort()
	var result: Dictionary={}
	for key in keys: result[key]=values[key]
	return result

static func _ordered_nonzero(values: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in _ordered(values):
		if int(values[key])!=0: result[key]=values[key]
	return result
