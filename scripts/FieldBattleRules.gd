extends RefCounted
## Reine Kampfvorschauen und numerische Pläne; Game besitzt jede Mutation.
const Transport = preload("res://scripts/NavalTransport.gd")
const RULES := {"version":1,"assault_gold":25,"relief_gold":0,
	"attack_roll_min":0.85,"attack_roll_max":1.15,
	"attack_martial_divisor":20.0,"defense_martial_divisor":25.0,
	"garrison_development_divisor":12.0,"naval_assault_bonus":1.25,
	"relief_garrison_share":0.25,"attack_win_attacker_loss":0.10,
	"attack_win_defender_loss":0.40,"attack_loss_attacker_loss":0.20,
	"attack_loss_defender_loss":0.10,"max_garrison_loss_fraction":0.15,
	"loser_morale_loss":20,"loser_minimum_morale":10,"winner_morale_gain":5,
	"group_largest_remainders":true,"positive_fraction_minimum_group_loss":1,
	"winner_group_keeps_one":true,
	"forced_retreat_ignores_month_guard":true,"land_retreat_first":true,
	"existing_assault_diagnostic_edges":["K2","D6","K7"],"physical_retreat_fleet_index":true}

static func assault_preview(game, target_id: String, hi: int) -> Dictionary:
	var out := _empty("assault",target_id,hi,int(RULES.assault_gold))
	if not _valid_house(game,hi): return _blocked(out,"Ungültiges Haus.")
	var target: Dictionary = game.province(target_id)
	if target.is_empty(): return _blocked(out,"Unbekanntes Sturmziel.")
	var owner := int(target.get("owner",-1))
	out.defender_house = owner
	if owner==hi or not _valid_house(game,owner): return _blocked(out,"Sturm nur auf fremdes Land.")
	if not bool(game.disabled_edges.get("K2",false)) and not game.claim_active(target_id,hi): return _blocked(out,"Der Sturm benötigt einen aktiven Anspruch.")
	var reason := _diplomacy_reason(game,hi,owner,true)
	if not reason.is_empty(): return _blocked(out,reason)
	reason = _ready_army_reason(game,target_id,hi)
	if not reason.is_empty(): return _blocked(out,reason)
	var army: Dictionary = game.army_for(hi)
	_bind_attacker(out,army)
	var defenders := _stationed(game,owner,target_id)
	out.defender_army_ids = _ids(defenders)
	out.defender_strength = _strength(defenders)
	out.garrison = maxi(0,int(target.get("levy",0)))
	out.attack_power = _attack_power(game,hi,army)
	out.defense = _garrison_power(game,owner,target)+_group_power(game,owner,defenders,target)
	if int(target.get("blockade",0))>0 and int(target.get("blockade_owner",-1))==hi:
		out.naval_bonus = float(RULES.naval_assault_bonus)
	out.chance = _chance(float(out.attack_power)*float(out.naval_bonus),float(out.defense))
	if int(game.houses[hi].get("gold",0))<int(out.cost): return _blocked(out,"Ein Sturm kostet 25 Gold.")
	out.ok = true
	return out

static func relief_preview(game, target_id: String, hi: int) -> Dictionary:
	var out := _empty("relief",target_id,hi,int(RULES.relief_gold))
	if not _valid_house(game,hi): return _blocked(out,"Ungültiges Haus.")
	var target: Dictionary = game.province(target_id)
	if target.is_empty() or int(target.get("owner",-1))!=hi: return _blocked(out,"Entsatz nur im eigenen Land.")
	var reason := _ready_army_reason(game,target_id,hi)
	if not reason.is_empty(): return _blocked(out,reason)
	var army: Dictionary = game.army_for(hi)
	_bind_attacker(out,army)
	var groups: Array[Dictionary] = []
	for owner in game.houses.size():
		if owner==hi or not _diplomacy_reason(game,hi,owner).is_empty(): continue
		var defenders := _stationed(game,owner,target_id)
		if not defenders.is_empty():
			groups.append({"house":owner,"armies":defenders,"power":_group_power(game,owner,defenders,target)})
	if groups.is_empty(): return _blocked(out,"Kein zulässiger feindlicher Feldverband vor Ort.")
	var siege_owner := int(target.get("siege_owner",-1)) if int(target.get("siege",0))>0 else -1
	groups.sort_custom(func(a,b):
		if int(a.house)==siege_owner: return int(b.house)!=siege_owner
		if int(b.house)==siege_owner: return false
		return float(a.power)>float(b.power) if float(a.power)!=float(b.power) else int(a.house)<int(b.house))
	var chosen: Dictionary = groups[0]
	out.defender_house = int(chosen.house)
	out.defender_army_ids = _ids(chosen.armies)
	out.defender_strength = _strength(chosen.armies)
	out.garrison = maxi(0,int(target.get("levy",0)))
	out.attack_power = _attack_power(game,hi,army)+_garrison_power(game,hi,target)*float(RULES.relief_garrison_share)
	# Die gegnerischen Feldheere stehen außerhalb der eigenen Festung.
	out.defense = float(chosen.power)
	out.chance = _chance(float(out.attack_power),float(out.defense))
	out.ok = true
	return out

static func loss_plan(armies: Array, fraction: float, keep_one: bool = false) -> Array:
	if not is_finite(fraction): return []
	var rows: Array[Dictionary] = []
	var seen := {}
	var total := 0
	for army in armies:
		if not army is Dictionary or int(army.get("id",0))<=0: return []
		var id := int(army.id)
		if seen.has(id): return []
		seen[id] = true
		var strength := maxi(0,int(army.get("strength",0)))
		if strength==0: continue
		total += strength
		rows.append({"id":id,"before":strength,"loss":0,"remaining":strength})
	if total==0: return []
	var rate := clampf(fraction,0.0,1.0)
	var requested := maxi(int(RULES.positive_fraction_minimum_group_loss),roundi(total*rate)) if rate>0.0 else 0
	var budget := mini(requested,total-1 if keep_one else total)
	var allocated := 0
	var remainders: Array[Dictionary] = []
	for row in rows:
		var numerator: int = int(row.before)*budget
		@warning_ignore("integer_division")
		row.loss = numerator/total
		allocated += int(row.loss)
		remainders.append({"row":row,"remainder":numerator%total})
	remainders.sort_custom(func(a,b):return int(a.remainder)>int(b.remainder) if int(a.remainder)!=int(b.remainder) else int(a.row.id)<int(b.row.id))
	for index in budget-allocated:
		remainders[index].row.loss = int(remainders[index].row.loss)+1
	for row in rows: row.remaining=int(row.before)-int(row.loss)
	rows.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return rows

static func retreat_plan(game, hi: int, origin: String, armies: Array) -> Dictionary:
	var out := {"kind":"surrender","from":origin,"to":"","fleet_id":-1,"fleet_index":-1,"cancel_blockade":false}
	if not _valid_house(game,hi) or game.province(origin).is_empty(): return out
	var survivors := _surviving_strength(game,hi,origin,armies)
	if survivors<=0: return out
	var neighbours: Array = game.neighbours(origin).duplicate()
	neighbours.sort()
	for id in neighbours:
		if _free_own_location(game,hi,str(id)):
			out.kind="land"
			out.to=str(id)
			return out
	if _hostile_blockade(game,hi,origin): return out
	var fleets: Array[Dictionary] = []
	var all_fleets: Array = game.houses[hi].get("fleets",[])
	for fleet_index in all_fleets.size():
		var fleet = all_fleets[fleet_index]
		if not fleet is Dictionary: continue
		if str(fleet.get("station",fleet.get("province","")))!=origin: continue
		if int(fleet.get("morale",0))<int(Transport.RULES.minimum_fleet_morale): continue
		if int(fleet.get("ships",0))*int(Transport.RULES.soldiers_per_ship)<survivors: continue
		if int(fleet.get("id",0))>0: fleets.append({"index":fleet_index,"fleet":fleet})
	fleets.sort_custom(func(a,b):return int(a.fleet.id)<int(b.fleet.id) if int(a.fleet.id)!=int(b.fleet.id) else int(a.index)<int(b.index))
	if fleets.is_empty(): return out
	for id in game.naval_routes().destinations(origin):
		if not _free_own_location(game,hi,str(id)) or _hostile_blockade(game,hi,str(id)): continue
		out.kind="sea"
		out.to=str(id)
		out.fleet_id=int(fleets[0].fleet.id)
		out.fleet_index=int(fleets[0].index)
		var at: Dictionary = game.province(origin)
		out.cancel_blockade=int(at.get("blockade",0))>0 and int(at.get("blockade_owner",-1))==hi
		return out
	return out

static func _empty(kind: String, target: String, hi: int, cost: int) -> Dictionary:
	return {"ok":false,"reason":"","kind":kind,"cost":cost,"army_id":-1,
		"origin":"","target":target,"attacker_house":hi,"defender_house":-1,
		"attack_power":0.0,"defense":0.0,"chance":0.0,"naval_bonus":1.0,
		"field_army_strength":0,"garrison":0,"defender_army_ids":[],"defender_strength":0}

static func _blocked(out: Dictionary, reason: String) -> Dictionary:
	out.reason=reason
	return out

static func _valid_house(game, hi: int) -> bool:
	return hi>=0 and hi<game.houses.size()

static func _diplomacy_reason(game, hi: int, other: int, assault_edges: bool = false) -> String:
	if not (assault_edges and bool(game.disabled_edges.get("K7",false))) and game.truce_until(other,hi)>game._now(): return "Ein Waffenstillstand verhindert den Kampf."
	if not (assault_edges and bool(game.disabled_edges.get("D6",false))) and game.opinion_value(hi,other)>=60: return "Die gute Beziehung verhindert diesen Kampf."
	return ""

static func _ready_army_reason(game, target: String, hi: int) -> String:
	var army: Dictionary = game.army_for(hi)
	if not _combat_ready(army): return "Keine kampffähige ausgewählte Feldarmee."
	var id := int(army.get("id",0))
	var found := 0
	for unit in game.houses[hi].get("armies",[]):
		if int(unit.get("id",0))==id: found+=1
	if id<=0 or found!=1: return "Die eigene Armee-ID ist nicht eindeutig."
	if int(army.get("last_siege_month",-1))==game._now(): return "Die Armee hat diesen Monat bereits gehandelt."
	var origin := str(army.get("province",""))
	if game.province(origin).is_empty(): return "Unbekannter tatsächlicher Heerort."
	if origin!=target and not game.neighbours(origin).has(target): return "Das Heer muss am Ziel oder in einem direkten Nachbargebiet stehen."
	return ""

static func _combat_ready(army: Dictionary) -> bool:
	return int(army.get("strength",0))>0 and int(army.get("morale",0))>0

static func _effective(army: Dictionary) -> int:
	return floori(maxi(0,int(army.get("strength",0)))*clampi(int(army.get("morale",0)),0,100)/100.0)

static func _bind_attacker(out: Dictionary, army: Dictionary) -> void:
	out.army_id=int(army.id)
	out.origin=str(army.province)
	out.field_army_strength=_effective(army)

static func _attack_power(game, hi: int, army: Dictionary) -> float:
	return _effective(army)*(1.0+int(game.houses[hi].ruler.get("martial",0))/float(RULES.attack_martial_divisor))*game.legacy_war_multiplier(hi)*float(game.doctrine_info(hi).attack_multiplier)*(1.0+game.research_bonus("attack_percent",hi)/100.0)

static func _garrison_power(game, hi: int, target: Dictionary) -> float:
	var fort := int(target.get("defense",0))+int(target.get("terrain_defense",0))+int(game.research_bonus("defense",hi,target))
	return float(int(maxi(0,int(target.get("levy",0)))*(1.0+int(target.get("dev",0))/float(RULES.garrison_development_divisor))*(1.0+int(game.houses[hi].ruler.get("martial",0))/float(RULES.defense_martial_divisor))*(1.0+fort/100.0)*float(game.doctrine_info(hi).defense_multiplier)))

static func _group_power(game, hi: int, armies: Array, target: Dictionary) -> float:
	var effective := 0
	for army in armies: effective+=_effective(army)
	return effective*(1.0+int(game.houses[hi].ruler.get("martial",0))/float(RULES.defense_martial_divisor))*float(game.doctrine_info(hi).defense_multiplier)*(1.0+game.research_bonus("defense",hi,target)/100.0)

static func _stationed(game, hi: int, location: String) -> Array:
	var units: Array[Dictionary] = []
	for army in game.houses[hi].get("armies",[]):
		if army is Dictionary and _combat_ready(army) and str(army.get("province",""))==location:
			units.append(army)
	units.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return units

static func _ids(armies: Array) -> Array:
	var result: Array[int] = []
	for army in armies: result.append(int(army.id))
	return result

static func _strength(armies: Array) -> int:
	var result := 0
	for army in armies: result+=maxi(0,int(army.get("strength",0)))
	return result

static func _chance(power: float, defense: float) -> float:
	if power<=0.0: return 0.0
	return clampf((float(RULES.attack_roll_max)-defense/power)/(float(RULES.attack_roll_max)-float(RULES.attack_roll_min)),0.0,1.0)

static func _surviving_strength(game, hi: int, origin: String, armies: Array) -> int:
	var total := 0
	var seen := {}
	for copy in armies:
		if not copy is Dictionary: return -1
		var id := int(copy.get("id",0))
		if id<=0 or seen.has(id): return -1
		seen[id]=true
		var strength := int(copy.get("strength",0))
		if strength<=0: continue
		var found := 0
		for real in game.houses[hi].get("armies",[]):
			if int(real.get("id",0))!=id: continue
			found+=1
			if str(real.get("province",""))!=origin or strength>int(real.get("strength",0)): return -1
		if found!=1 or str(copy.get("province",origin))!=origin: return -1
		total+=strength
	return total

static func _free_own_location(game, hi: int, location: String) -> bool:
	var target: Dictionary = game.province(location)
	if target.is_empty() or int(target.get("owner",-1))!=hi: return false
	if int(target.get("siege",0))>0 and int(target.get("siege_owner",-1))>=0 and int(target.siege_owner)!=hi: return false
	for owner in game.houses.size():
		if owner!=hi and not _stationed(game,owner,location).is_empty(): return false
	return true

static func _hostile_blockade(game, hi: int, location: String) -> bool:
	var target: Dictionary = game.province(location)
	return int(target.get("blockade",0))>0 and int(target.get("blockade_owner",-1))!=hi
