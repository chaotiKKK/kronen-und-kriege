extends RefCounted
## Reine Transport-/Küstenreichweitenregeln. Mutationen bleiben in Game.
const Routes = preload("res://scripts/NavalRoutes.gd")
const RULES := {"soldiers_per_ship":100,"minimum_fleet_morale":20,
	"shared_monthly_army_action":true,"shared_monthly_fleet_action":true,
	"crossing_gold":0,"active_claims_only":true,"resolved_combat_result_version":1}
static var _routes: RefCounted

static func shared_routes() -> RefCounted:
	if _routes == null:
		_routes = Routes.new()
		_routes.load_data()
	return _routes

static func fleet_availability_reason(game, fleet: Dictionary, hi: int) -> String:
	if fleet.is_empty() or int(fleet.get("ships",0)) <= 0: return "Kein Geleit verfügbar."
	if int(fleet.get("morale",0)) < int(RULES.minimum_fleet_morale): return "Die Flottenmoral muss mindestens 20 betragen."
	var base := str(fleet.get("province",""))
	var station := str(fleet.get("station",base))
	var at: Dictionary = game.province(station)
	if not at.is_empty() and int(at.get("blockade",0)) > 0 and int(at.get("blockade_owner",-1)) == hi:
		return "Das Geleit blockiert noch %d Monate die Küste von %s." % [int(at.blockade),str(at.name)]
	if base != station: return "Das Geleit liegt nicht an seinem operativen Stützpunkt."
	return ""

static func coastal_claim_reason(game, target_id: String, hi: int) -> String:
	if hi < 0 or hi >= game.houses.size(): return "Ungültiges Haus."
	var target: Dictionary = game.province(target_id)
	if target.is_empty() or int(target.owner)==hi: return "Anspruch nur auf fremdes Land."
	var routes = shared_routes()
	if not routes.is_port(target_id): return "Kein verifizierter Küstenweg zum Ziel."
	var fleet: Dictionary = game.fleet_for(hi)
	var reason := fleet_availability_reason(game,fleet,hi)
	if not reason.is_empty(): return reason
	var origin := str(fleet.get("province",""))
	var port: Dictionary = game.province(origin)
	if port.is_empty() or int(port.owner)!=hi: return "Der Küstenanspruch benötigt ein Geleit an einem eigenen Stützpunkt."
	if routes.route(origin,target_id).is_empty(): return "Kein verifizierter Küstenweg von deinem Geleit zum Ziel."
	return ""

static func preview(game, target_id: String, hi: int) -> Dictionary:
	var out := {"ok":false,"reason":"","origin":"","target":target_id,
		"route_id":"","route_points":PackedVector2Array(),"army_id":-1,"fleet_id":-1,
		"strength":0,"capacity":0,"ships_required":0,"ships_available":0,"defending_ships":0}
	if hi < 0 or hi >= game.houses.size(): return _blocked(out,"Ungültiges Haus.")
	var target: Dictionary = game.province(target_id)
	if target.is_empty(): return _blocked(out,"Ungültiges Landungsziel.")
	var army: Dictionary = game.army_for(hi)
	if army.is_empty(): return _blocked(out,"Stelle zuerst eine Feldarmee auf.")
	out.origin = str(army.get("province",""))
	out.army_id = int(army.get("id",-1))
	out.strength = int(army.get("strength",0))
	out.ships_required = ceili(float(out.strength)/int(RULES.soldiers_per_ship))
	var route: Dictionary = shared_routes().route(str(out.origin),target_id)
	if route.is_empty(): return _blocked(out,"Für diese beiden Küsten ist kein Seeweg zugelassen.")
	out.route_id = str(route.id)
	out.route_points = route.points
	if out.strength <= 0 or int(army.get("morale",0)) <= 0: return _blocked(out,"Die ausgewählte Armee ist nicht kampffähig.")
	var fleet: Dictionary = game.fleet_for(hi)
	if not fleet.is_empty():
		out.fleet_id = int(fleet.get("id",-1))
		out.ships_available = int(fleet.get("ships",0))
		out.capacity = int(out.ships_available)*int(RULES.soldiers_per_ship)
	var reason := fleet_availability_reason(game,fleet,hi)
	if not reason.is_empty(): return _blocked(out,reason)
	if str(fleet.get("province",""))!=str(out.origin) or str(fleet.get("station",fleet.get("province","")))!=str(out.origin):
		return _blocked(out,"Armee und Geleit müssen am selben Küstenstützpunkt stehen.")
	if int(out.capacity)<int(out.strength):
		return _blocked(out,"Geleit zu klein: %d Schiffe benötigt, %d vorhanden (%d Mann Kapazität)." % [int(out.ships_required),int(out.ships_available),int(out.capacity)])
	if int(army.get("last_siege_month",-1))==game._now(): return _blocked(out,"Die Armee hat diesen Monat bereits gehandelt.")
	if int(fleet.get("last_naval_month",-1))==game._now(): return _blocked(out,"Das Geleit hat diesen Monat bereits gehandelt.")
	for id in [str(out.origin),target_id]:
		var coast: Dictionary = game.province(id)
		if not coast.is_empty() and int(coast.get("blockade",0))>0 and int(coast.get("blockade_owner",-1))!=hi:
			return _blocked(out,"Feindliche Blockade bei %s: noch %d Monate." % [str(coast.name),int(coast.blockade)])
	if int(target.owner)!=hi:
		if not game.claim_active(target_id,hi): return _blocked(out,"Die fremde Landung benötigt einen aktiven Anspruch.")
		if game.truce_until(int(target.owner),hi)>game._now(): return _blocked(out,"Ein Waffenstillstand sperrt die fremde Landung.")
		if game.opinion_value(hi,int(target.owner))>=60: return _blocked(out,"Die gute Beziehung verhindert feindlichen Einmarsch.")
		var defender: Dictionary = game._defending_fleet(target_id,int(target.owner))
		out.defending_ships = int(defender.get("ships",0))
	out.ok = true
	return out

static func _blocked(out: Dictionary, reason: String) -> Dictionary:
	out.reason = reason
	return out
