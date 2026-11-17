extends RefCounted
## Pure field-camp forecast. Game alone transfers levy, money and monthly action.
const Limits = preload("res://scripts/CampaignLimits.gd")
const RULES := {"version":1,"max_recruits":100,"local_levy_reserve":50,
	"base_gold":5,"soldiers_per_gold":10,"morale_gain":20,"maximum_morale":100,
	"minimum_capacity":100,"soldiers_per_upkeep":250,"minimum_upkeep":1,
	"shared_monthly_army_action":true,"requires_actual_own_station":true,
	"blocks_hostile_siege":true,"blocks_hostile_blockade":true,
	"blocks_foreign_combat_armies":true,"morale_zero_allowed":true,
	"partial_purchase_by_gold":true,"preserve_oversize_armies":true,
	"morale_only_preserves_upkeep":true,"levy_is_conserved":true,
	"maximum_capacity":Limits.MAX_ARMY_STRENGTH,
	"disband_requires_unused_month":true,"disband_requires_unique_id":true,
	"disband_gold_refund":0,"disband_levy_refund":0}

static func preview(game, location: String, house_index: int = -1) -> Dictionary:
	var out := {"ok":false,"reason":"","needed":false,"army_id":-1,"origin":"",
		"current_strength":0,"new_strength":0,"added":0,"capacity":0,
		"current_morale":0,"new_morale":0,"cost":0,
		"levy_before":0,"levy_after":0,"reserve":int(RULES.local_levy_reserve),
		"upkeep_before":0,"upkeep_after":0,"house_upkeep_after":0}
	var hi: int = game.player if house_index==-1 else house_index
	if hi<0 or hi>=game.houses.size(): return _blocked(out,"Ungültiges Haus.")
	var army: Dictionary = game.army_for(hi)
	if army.is_empty() or int(army.get("strength",0))<=0:
		return _blocked(out,"Keine lebende Feldarmee zum Auffüllen verfügbar.")
	out.army_id = int(army.get("id",-1))
	out.origin = str(army.get("province",""))
	out.current_strength = int(army.strength)
	out.new_strength = out.current_strength
	out.current_morale = int(army.get("morale",100))
	out.new_morale = out.current_morale
	out.upkeep_before = int(army.get("upkeep",0))
	out.upkeep_after = out.upkeep_before
	out.house_upkeep_after = game.army_upkeep(hi)
	var province: Dictionary = game.province(location)
	if province.is_empty(): return _blocked(out,"Unbekannter Feldlagerstandort.")
	if int(province.get("owner",-1))!=hi:
		return _blocked(out,"Auffüllen und Ordnen ist nur im eigenen Land möglich.")
	out.levy_before = int(province.get("levy",0))
	out.levy_after = out.levy_before
	var regional: Dictionary = game.region_capacity(province)
	out.capacity = mini(int(RULES.maximum_capacity),maxi(int(RULES.minimum_capacity),roundi((float(regional.maximum)/2.0)*game.legacy_war_multiplier(hi)))+game.vassal_levy_bonus(hi))
	out.needed = int(out.current_strength)<int(out.capacity) or int(out.current_morale)<int(RULES.maximum_morale)
	if str(out.origin)!=location:
		return _blocked(out,"Die ausgewählte Armee muss tatsächlich an diesem eigenen Standort stehen.")
	if int(army.get("last_siege_month",-1))==game._now():
		return _blocked(out,"Die Armee hat diesen Monat bereits gehandelt.")
	if int(province.get("siege",0))>0 and int(province.get("siege_owner",-1))>=0 and int(province.siege_owner)!=hi:
		return _blocked(out,"Eine feindliche Belagerung verhindert das Auffüllen und Ordnen.")
	if int(province.get("blockade",0))>0 and int(province.get("blockade_owner",-1))>=0 and int(province.blockade_owner)!=hi:
		return _blocked(out,"Eine feindliche Blockade verhindert das Auffüllen und Ordnen.")
	for other in game.houses.size():
		if other==hi: continue
		for foreign in game.houses[other].get("armies",[]):
			if str(foreign.get("province",""))==location and int(foreign.get("strength",0))>0 and int(foreign.get("morale",0))>0:
				return _blocked(out,"Fremde kampffähige Truppen stehen am Feldlagerstandort.")
	if not out.needed: return _blocked(out,"Die Feldarmee ist bereits vollständig aufgefüllt und geordnet.")
	var gold: int = int(game.houses[hi].get("gold",0))
	out.cost = int(RULES.base_gold)
	if gold<int(RULES.base_gold): return _blocked(out,"Das Feldlager benötigt mindestens 5 Gold.")
	var available := maxi(0,int(out.levy_before)-int(RULES.local_levy_reserve))
	var missing := maxi(0,int(out.capacity)-int(out.current_strength))
	var affordable := maxi(0,gold-int(RULES.base_gold))*int(RULES.soldiers_per_gold)
	out.added = mini(int(RULES.max_recruits),mini(missing,mini(available,affordable)))
	out.new_strength = int(out.current_strength)+int(out.added)
	out.new_morale = mini(int(RULES.maximum_morale),int(out.current_morale)+int(RULES.morale_gain))
	if int(out.added)==0 and int(out.new_morale)==int(out.current_morale):
		return _blocked(out,"Keine bezahlbaren örtlichen Soldaten über der Reserve verfügbar; die Moral ist bereits vollständig.")
	out.cost = int(RULES.base_gold)+ceili(float(out.added)/float(RULES.soldiers_per_gold))
	out.levy_after = int(out.levy_before)-int(out.added)
	if int(out.added)>0:
		out.upkeep_after = maxi(int(RULES.minimum_upkeep),floori(float(out.new_strength)/float(RULES.soldiers_per_upkeep)))
	var basis := 0
	var armies: Array = game.houses[hi].get("armies",[])
	for index in armies.size():
		basis += int(out.upkeep_after) if index==0 else int(armies[index].get("upkeep",0))
	out.house_upkeep_after = ceili(float(basis)*float(game.doctrine_info(hi).upkeep_multiplier))
	out.ok = true
	return out

static func disband_preview(game, location: String, house_index: int=-1) -> Dictionary:
	var out := {"ok":false,"reason":"","army_id":-1,"origin":"","strength":0,"morale":0}
	var hi: int = game.player if house_index==-1 else house_index
	if hi<0 or hi>=game.houses.size(): return _blocked(out,"Ungültiges Haus.")
	var army: Dictionary = game.army_for(hi)
	if army.is_empty() or int(army.get("strength",0))<=0: return _blocked(out,"Keine lebende ausgewählte Feldarmee.")
	out.army_id = int(army.get("id",-1))
	out.origin = str(army.get("province",""))
	out.strength = int(army.strength)
	out.morale = int(army.get("morale",0))
	var identities := 0
	for candidate in game.houses[hi].get("armies",[]):
		if int(candidate.get("id",-1))==int(out.army_id): identities+=1
	if int(out.army_id)<=0 or identities!=1: return _blocked(out,"Die ausgewählte Armee ist nicht eindeutig.")
	var p: Dictionary = game.province(location)
	if p.is_empty() or int(p.get("owner",-1))!=hi or str(out.origin)!=location:
		return _blocked(out,"Auflösen ist nur am tatsächlichen eigenen Standort möglich.")
	if int(army.get("last_siege_month",-1))==game._now(): return _blocked(out,"Die Armee hat diesen Monat bereits gehandelt.")
	if int(p.get("siege",0))>0 and int(p.get("siege_owner",-1))>=0 and int(p.siege_owner)!=hi:
		return _blocked(out,"Eine feindliche Belagerung verhindert das Auflösen.")
	if int(p.get("blockade",0))>0 and int(p.get("blockade_owner",-1))>=0 and int(p.blockade_owner)!=hi:
		return _blocked(out,"Eine feindliche Blockade verhindert das Auflösen.")
	for other in game.houses.size():
		if other==hi: continue
		for foreign in game.houses[other].get("armies",[]):
			if str(foreign.get("province",""))==location and int(foreign.get("strength",0))>0 and int(foreign.get("morale",0))>0:
				return _blocked(out,"Fremde kampffähige Truppen stehen am Standort.")
	out.ok = true
	return out

static func _blocked(out: Dictionary, reason: String) -> Dictionary:
	out.reason = reason
	return out
