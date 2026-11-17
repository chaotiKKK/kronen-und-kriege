extends RefCounted
## Reine Festungsvorschau; Zustandsänderungen bleiben in Game.
const RULES := {"version":1,"garrison_pressure":0.35,"minimum_fort_factor":0.5,
	"minimum_coverage":0.25,"minimum_required_strength":1,"base_progress":20,
	"soldiers_per_progress":60,"martial_per_progress":4,"morale_scale":100,
	"blockade_multiplier":1.15,"completion":100,"annual_months":12,
	"shared_monthly_army_action":true,"active_claims_only":true,
	"owner_field_armies_block":true,"unsupported_progress_resets":true,
	"damaged_wall_tier_removes_defense":true}

static func preview(game, target_id: String, hi: int) -> Dictionary:
	var out := {"ok":false,"reason":"","current":0,"next":0,
		"progress":0,"remaining_actions":0,"army_id":-1,"origin":"","strength":0,
		"effective_strength":0,"required_strength":0,"garrison":0,"defender_strength":0,
		"fort_bonus":0,"wall_level":0,"coverage":1.0,"supply":{},"blockade_factor":1.0,
		"doctrine_bonus":0,"research_bonus":0}
	if game==null or hi<0 or hi>=game.houses.size(): return _blocked(out,"Ungültiges Haus.")
	var target: Dictionary = game.province(target_id)
	if target.is_empty(): return _blocked(out,"Ungültiges Belagerungsziel.")
	var owner := int(target.get("owner",-1))
	if owner<0 or owner>=game.houses.size() or owner==hi:
		return _blocked(out,"Belagerung braucht fremdes Land.")
	out.garrison = maxi(0,int(target.get("levy",0)))
	out.wall_level = maxi(0,int(target.get("buildings",{}).get("walls",0)))
	out.fort_bonus = int(target.get("defense",0))+int(target.get("terrain_defense",0))+game.research_bonus("defense",owner,target)
	var fort_factor := maxf(float(RULES.minimum_fort_factor),1.0+float(out.fort_bonus)/100.0)
	out.required_strength = maxi(int(RULES.minimum_required_strength),ceili(float(out.garrison)*float(RULES.garrison_pressure)*fort_factor))
	out.defender_strength = _stationed_strength(game,owner,target_id)
	var siege_owner := int(target.get("siege_owner",-1))
	var supported: bool = siege_owner>=0 and siege_owner<game.houses.size() and siege_owner!=owner and _stationed_strength(game,siege_owner,target_id)>0
	if supported:
		out.current = clampi(int(target.get("siege",0)),0,int(RULES.completion))
	out.next = out.current
	var army: Dictionary = game.army_for(hi)
	if army.is_empty(): return _blocked(out,"Stelle zuerst eine Feldarmee auf.")
	out.army_id = int(army.get("id",-1))
	out.origin = str(army.get("province",""))
	out.strength = maxi(0,int(army.get("strength",0)))
	out.effective_strength = floori(float(out.strength)*clampi(int(army.get("morale",0)),0,int(RULES.morale_scale))/int(RULES.morale_scale))
	var report: Dictionary = game.supply_report(hi)
	out.supply = report.get("regions",{}).get(str(out.origin),{}).duplicate(true)
	out.supply["annual_in_months"] = int(RULES.annual_months)-int(game.month)+1
	var demand := int(out.supply.get("demand",0))
	if demand>0:
		out.coverage = clampf(float(demand-int(out.supply.get("shortfall",0)))/demand,float(RULES.minimum_coverage),1.0)
	if int(target.get("blockade",0))>0 and int(target.get("blockade_owner",-1))==hi:
		out.blockade_factor = float(RULES.blockade_multiplier)
	out.doctrine_bonus = int(game.doctrine_info(hi).get("siege_bonus",0))
	out.research_bonus = int(game.research_bonus("siege",hi,target))
	if int(out.strength)<=0 or int(out.effective_strength)<=0:
		return _blocked(out,"Keine kampffähige Feldarmee verfügbar. Erhole dich im eigenen Feldlager.")
	if int(out.defender_strength)>0:
		return _blocked(out,"%d feindliche Feldsoldaten verteidigen das Ziel. Besiege zunächst ihre Verbände." % int(out.defender_strength))
	if supported and int(out.current)>0 and siege_owner!=hi:
		return _blocked(out,"Hier belagert bereits %s mit einem kampffähigen Heer." % str(game.houses[siege_owner].name))
	if int(out.effective_strength)<int(out.required_strength):
		return _blocked(out,"Belagerungsdruck zu gering: %d effektive Mann nötig, %d vorhanden. Fülle das Heer auf oder erhole seine Moral im eigenen Feldlager." % [int(out.required_strength),int(out.effective_strength)])
	var base := int(RULES.base_progress)+floori(float(out.effective_strength)/int(RULES.soldiers_per_progress))+floori(float(game.houses[hi].ruler.get("martial",0))/int(RULES.martial_per_progress))
	out.progress = maxi(1,floori(float(base)/fort_factor*float(out.coverage)*float(out.blockade_factor))+int(out.doctrine_bonus)+int(out.research_bonus))
	out.next = mini(int(RULES.completion),int(out.current)+int(out.progress))
	out.remaining_actions = ceili(float(int(RULES.completion)-int(out.current))/int(out.progress))
	# Diese vorübergehenden Sperren behalten die reine Vorschau der nächsten
	# möglichen Aktion. current/next verändern niemals den tatsächlichen Stand.
	if not game.claim_active(target_id,hi): return _blocked(out,"Belagerung braucht einen aktiven Anspruch.")
	if game.opinion_value(hi,owner)>=60: return _blocked(out,"Die gute Beziehung verhindert diese Belagerung.")
	if game.truce_until(owner,hi)>game._now(): return _blocked(out,"Ein Waffenstillstand gilt.")
	if int(army.get("last_siege_month",0))==game._now(): return _blocked(out,"Die Armee hat diesen Monat bereits gehandelt.")
	if str(out.origin)!=target_id and not game.neighbours(str(out.origin)).has(target_id):
		return _blocked(out,"Die Armee muss zunächst in direkte Reichweite marschieren.")
	out.ok = true
	return out

static func _stationed_strength(game, hi: int, target_id: String) -> int:
	var strength := 0
	for army in game.houses[hi].get("armies",[]):
		if str(army.get("province",""))==target_id and int(army.get("strength",0))>0 and int(army.get("morale",0))>0:
			strength+=int(army.strength)
	return strength

static func _blocked(out: Dictionary, reason: String) -> Dictionary:
	out.reason = reason
	return out
