extends RefCounted
## Reine Feldzugsplanung. Game führt die zurückgegebenen Aktionen aus.
const Transport = preload("res://scripts/NavalTransport.gd")
const ARMY_GOLD := 50
const CLAIM_GOLD := 40

static func claim_target(game, hi: int) -> String:
	if hi<0 or hi>=game.houses.size(): return ""
	var army: Dictionary = game.army_for(hi)
	if army.is_empty():
		var capital := str(game.houses[hi].get("capital",""))
		var strength: int = game.army_raise_strength(capital,hi)
		if strength<=0: return ""
		army = {"province":capital,"strength":strength,"morale":100}
	if not _living_army(army): return ""
	var origin := str(army.province)
	# Eine Monatswache ist kein Grund für einen weiteren Anspruchskauf.
	# Nur die strukturelle Erreichbarkeit wird hier für künftige Züge geprüft.
	for claim in game.houses[hi].get("claims",[]):
		var target := str(claim.get("province",""))
		if _hostile_claim(game,target,hi) and _reachable(game,hi,origin,target,army): return ""
	var best := ""
	var best_score := -INF
	for region in game.provinces:
		var target := str(region.id)
		if int(region.owner)==hi or game.claim_active(target,hi) or not _hostility_allowed(game,hi,int(region.owner)): continue
		if not game._is_border_province(hi,target) and not game.coastal_claim_reason(target,hi).is_empty(): continue
		if not _reachable(game,hi,origin,target,army): continue
		var score := float(game.region_income(region)*4)-float(region.get("levy",0))/100.0-float(region.get("defense",0))
		if score>best_score or (score==best_score and target<best):
			best_score=score
			best=target
	return best

static func next_order(game, hi: int) -> Dictionary:
	if hi<0 or hi>=game.houses.size(): return {}
	var army: Dictionary = game.army_for(hi)
	if not _living_army(army) or int(army.get("last_siege_month",-1))==game._now(): return {}
	var targets: Array[String] = []
	for claim in game.houses[hi].get("claims",[]):
		var id := str(claim.get("province",""))
		if not targets.has(id) and _hostile_claim(game,id,hi): targets.append(id)
	targets.sort()
	var candidates: Array[Dictionary] = []
	for target in targets:
		if game.can_siege(target,hi):
			candidates.append(_order(target,"siege",target,1,false))
			continue
		var path := _path_to_siege(game,hi,str(army.province),target,army)
		if path.is_empty(): continue
		var first: Dictionary = path[0]
		if not _executable(game,hi,first): continue
		var uses_sea := false
		for step in path:
			if str(step.action)=="transport": uses_sea=true
		candidates.append(_order(target,str(first.action),str(first.destination),path.size()+1,uses_sea))
	if not candidates.is_empty():
		candidates.sort_custom(func(a,b): return int(a.steps)<int(b.steps) if int(a.steps)!=int(b.steps) else str(a.target)<str(b.target))
		return candidates[0]
	return _retreat(game,hi,army)

static func preparation(game, hi: int) -> Dictionary:
	if hi<0 or hi>=game.houses.size() or _foreign_land_border(game,hi): return {}
	var routes = game.naval_routes()
	var army: Dictionary = game.army_for(hi)
	if not army.is_empty() and not _living_army(army): return {}
	var fleet: Dictionary = game.fleet_for(hi)
	if not fleet.is_empty() and not Transport.fleet_availability_reason(game,fleet,hi).is_empty(): return {}
	var ports: Array[String] = []
	for region in game.provinces:
		var id := str(region.id)
		if int(region.owner)==hi and routes.is_port(id): ports.append(id)
	ports.sort()
	for port in ports:
		if not fleet.is_empty() and str(fleet.get("province",""))!=port: continue
		if not army.is_empty() and not _own_land_path(game,hi,str(army.province),port): continue
		var strength: int = int(army.strength) if not army.is_empty() else game.army_raise_strength(port,hi)
		var ships: int = int(fleet.get("ships",0)) if not fleet.is_empty() else game.fleet_raise_ships(port,hi)
		var capacity: int = ships*int(Transport.RULES.soldiers_per_ship)
		if strength<=0 or ships<=0 or capacity<strength: continue
		for destination in routes.destinations(port):
			var target: Dictionary = game.province(str(destination))
			if target.is_empty() or int(target.owner)==hi or not _hostility_allowed(game,hi,int(target.owner)): continue
			if not _open_coasts(game,hi,port,str(destination)): continue
			var needs_claim: bool = not game.claim_active(str(destination),hi)
			var gold := (ARMY_GOLD if army.is_empty() else 0)+(int(game.FLEET_COST) if fleet.is_empty() else 0)+(CLAIM_GOLD if needs_claim else 0)
			return {"port":port,"target":str(destination),"required_gold":gold,
				"available_gold":int(game.houses[hi].gold),"affordable":int(game.houses[hi].gold)>=gold,
				"needs_army":army.is_empty(),"needs_fleet":fleet.is_empty(),"needs_claim":needs_claim,
				"strength":strength,"ships":ships,"capacity":capacity}
	return {}

static func _order(target: String, action: String, destination: String, steps: int, uses_sea: bool) -> Dictionary:
	return {"target":target,"action":action,"destination":destination,"steps":steps,"uses_sea":uses_sea,"retreat":false}

static func _hostile_claim(game, id: String, hi: int) -> bool:
	var target: Dictionary = game.province(id)
	return not target.is_empty() and int(target.owner)!=hi and game.claim_active(id,hi) and _hostility_allowed(game,hi,int(target.owner))

static func _hostility_allowed(game, hi: int, owner: int) -> bool:
	return owner>=0 and owner<game.houses.size() and game.truce_until(owner,hi)<=game._now() and game.opinion_value(hi,owner)<60

static func _living_army(army: Dictionary) -> bool:
	return not army.is_empty() and int(army.get("strength",0))>0 and int(army.get("morale",0))>0

static func _reachable(game, hi: int, origin: String, target: String, army: Dictionary) -> bool:
	return origin==target or game.neighbours(origin).has(target) or not _path_to_siege(game,hi,origin,target,army).is_empty()

static func _path_to_siege(game, hi: int, origin: String, target: String, army: Dictionary) -> Array:
	var fleet: Dictionary = game.fleet_for(hi)
	var escort := ""
	if Transport.fleet_availability_reason(game,fleet,hi).is_empty() and int(fleet.get("ships",0))*int(Transport.RULES.soldiers_per_ship)>=int(army.strength):
		escort = str(fleet.get("province",""))
	# Heer und Geleit werden getrennt geführt: Landmarsch bewegt keine Schiffe,
	# eine echte Überfahrt nimmt genau das vorhandene Geleit mit.
	var queue: Array[Dictionary] = [{"at":origin,"escort":escort,"path":[]}]
	var visited := {JSON.stringify([origin,escort]):true}
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var at := str(current.at)
		if at==target or game.neighbours(at).has(target): return current.path
		var steps: Array[Dictionary] = []
		var neighbours: Array = game.neighbours(at).duplicate()
		neighbours.sort()
		for id in neighbours:
			var region: Dictionary = game.province(str(id))
			if not region.is_empty() and int(region.owner)==hi:
				steps.append({"action":"march","destination":str(id),"escort":str(current.escort)})
		if not str(current.escort).is_empty() and str(current.escort)==at:
			for id in game.naval_routes().destinations(at):
				var region: Dictionary = game.province(str(id))
				if region.is_empty() or (int(region.owner)!=hi and str(id)!=target): continue
				if not _open_coasts(game,hi,at,str(id)): continue
				steps.append({"action":"transport","destination":str(id),"escort":str(id)})
		# Stabiler Ziel-/Aktionstiebreak auch bei mehreren gleich langen Routen.
		steps.sort_custom(func(a,b):return str(a.destination)<str(b.destination) if str(a.destination)!=str(b.destination) else str(a.action)<str(b.action))
		for step in steps:
			var key := JSON.stringify([str(step.destination),str(step.escort)])
			if visited.has(key): continue
			visited[key] = true
			var path: Array = current.path.duplicate()
			path.append({"action":str(step.action),"destination":str(step.destination)})
			queue.append({"at":str(step.destination),"escort":str(step.escort),"path":path})
	return []

static func _executable(game, hi: int, step: Dictionary) -> bool:
	if str(step.action)=="march": return game.can_march(str(step.destination),hi)
	if str(step.action)=="transport": return bool(game.naval_transport_preview(str(step.destination),hi).ok)
	return false

static func _open_coasts(game, hi: int, origin: String, destination: String) -> bool:
	for id in [origin,destination]:
		var region: Dictionary = game.province(id)
		if region.is_empty(): return false
		if int(region.get("blockade",0))>0 and int(region.get("blockade_owner",-1))!=hi: return false
	return true

static func _own_land_path(game, hi: int, origin: String, destination: String) -> bool:
	var start: Dictionary = game.province(origin)
	if start.is_empty() or int(start.owner)!=hi: return false
	var queue: Array[String] = [origin]
	var visited := {origin:true}
	while not queue.is_empty():
		var at: String = queue.pop_front()
		if at==destination: return true
		var neighbours: Array = game.neighbours(at).duplicate()
		neighbours.sort()
		for id in neighbours:
			if visited.has(str(id)): continue
			var region: Dictionary = game.province(str(id))
			if not region.is_empty() and int(region.owner)==hi:
				visited[str(id)]=true
				queue.append(str(id))
	return false

static func _foreign_land_border(game, hi: int) -> bool:
	for region in game.provinces:
		if int(region.owner)!=hi: continue
		for id in game.neighbours(str(region.id)):
			var neighbour: Dictionary = game.province(str(id))
			if not neighbour.is_empty() and int(neighbour.owner)!=hi: return true
	return false

static func _retreat(game, hi: int, army: Dictionary) -> Dictionary:
	var origin := str(army.province)
	var region: Dictionary = game.province(origin)
	if region.is_empty() or int(region.owner)==hi: return {}
	for id in game.naval_routes().destinations(origin):
		var destination: Dictionary = game.province(str(id))
		if destination.is_empty() or int(destination.owner)!=hi: continue
		if bool(game.naval_transport_preview(str(id),hi).ok):
			var order := _order(str(id),"transport",str(id),1,true)
			order.retreat = true
			return order
	return {}
