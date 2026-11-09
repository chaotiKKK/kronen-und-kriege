extends RefCounted
## Übersetzt einen Game-Snapshot in reine Anzeigezeichenketten und Flags.
## Darf ausschließlich lesen; alle Mutationen laufen über UiKernel/Game.

static func refresh(game, selected: String) -> Dictionary:
	var h: Dictionary = game.house()
	var spouse: Dictionary = h["spouse"]
	var spouse_txt := "unvermählt"
	if not spouse.is_empty():
		spouse_txt = "%s (%d, %s)" % [spouse["name"], int(spouse["age"]), "w" if str(spouse["gender"]) == "f" else "m"]
	var heir_txt := "keiner"
	if str(h["heir"]) != "":
		heir_txt = "%s (%d)" % [h["heir"], int(h["heir_age"])]
	var lover_txt := "—"
	if int(h["lover_house"]) >= 0 and int(h["lover_house"]) < game.houses.size():
		lover_txt = str(game.houses[int(h["lover_house"])]["name"])
	var capt_txt := "—"
	if not game.captive.is_empty():
		capt_txt = "%s (noch %d Monate)" % [game.captive["name"], int(game.captive["months"])]
	var family_text := "Gemahl/in: %s\nErbe: %s · Kinder: %d\nGeliebte/r: %s · Gefangene/r: %s\nGold %d · Prestige %d · Legitimität %d · Ruhm %d\nHofpracht %d/100 · Reliquien %d · Hofhalle %d/3\nGlaube %s · Frömmigkeit %d/100 · Kirchenmacht %d/100" % [
		spouse_txt, heir_txt, h["children"].size(), lover_txt, capt_txt,
		int(h["gold"]), int(h["prestige"]), int(h["legitimacy"]), int(h["renown"]),
		game.court_grandeur(), game.court_relics().size(), game.court_hall_level(),
		str(game.faith_confession_info(game.faith_confession()).get("name", "—")), game.faith_piety(), game.faith_church_power(),
	]
	var hint := "Tippe auf eine Grafschaft, um sie auszuwählen."
	if selected != "":
		var p2: Dictionary = game.province(selected)
		if p2.is_empty():
			hint = ""
		elif int(p2["owner"]) == game.player:
			hint = "Eigenes Land: ausbauen oder Truppen werben."
		else:
			hint = "Feindliches Land: angreifen, wenn es an dein Gebiet grenzt."
	return {
		"date": game.date_text(),
		"gold": "Gold: %d" % int(h["gold"]),
		"prestige": "Prestige: %d" % int(h["prestige"]),
		"renown": "Ruhm: %d" % int(h["renown"]),
		"speed": int(game.speed),
		"title": str(h["name"]),
		"info": _info(game, selected),
		"family": family_text,
		"hint": hint,
		"log": "\n".join(game.log_lines),
		"buttons": {
			"develop": game.can_develop(selected),
			"recruit": game.can_recruit(selected),
			"attack": game.can_attack(selected),
			"court": game.can_court(),
			"marry": _any_action(game, "marry"),
			"seduce": _any_action(game, "seduce"),
			"murder": _any_action(game, "murder"),
			"kidnap": _any_action(game, "kidnap"),
			"bed": game.can_bed(),
			"ransom_visible": not game.captive.is_empty(),
			"force_visible": not game.captive.is_empty(),
			"ransom": game.can_ransom(),
			"force": game.can_force_marry(),
		},
		"game_over": bool(game.game_over),
		"has_event": game.pending_event != null,
	}

static func _info(game, selected: String) -> String:
	var h: Dictionary = game.house()
	var info := "%s\nHerrscher: %s (%s, %d Jahre)\nKrieg %d · Diplomatie %d · Verwaltung %d · Intrige %d\nGrafschaften: %d" % [
		str(h.get("realm", "Hausbesitz")), h["ruler"]["name"],
		"w" if str(h["ruler"]["gender"]) == "f" else "m", int(h["ruler"]["age"]),
		int(h["ruler"]["martial"]), int(h["ruler"]["diplomacy"]),
		int(h["ruler"]["stewardship"]), int(h["ruler"]["intrigue"]),
		game.owned().size(),
	]
	if selected != "":
		var p: Dictionary = game.province(selected)
		if not p.is_empty():
			var owner_house: Dictionary = game.houses[int(p["owner"])]
			var nb: Array = []
			for n in game.neighbours(selected):
				var q: Dictionary = game.province(n)
				if not q.is_empty():
					nb.append("%s (%s)" % [q["name"], game.houses[int(q["owner"])]["name"]])
			var capital_txt := "ja" if bool(p.get("capital", false)) else "nein"
			var terrain_name: String = str(p.get("terrain_name", "Ebenen"))
			var terrain_def: int = int(p.get("terrain_defense", 0))
			var supply: int = int(p.get("terrain_supply", 6))
			info = "Provinz %s\nLand: %s · %s\nHerzogtum: %s\nBesitzer: %s · Haltung %+d\nGelände: %s · Verteidigung %+d%% · Versorgung %d\nHauptstadt: %s · Entwicklung: %d / 10 · Truppen: %d\nNachbarn: %s" % [
				p["name"], p["kingdom_name"], p["empire_name"], p["duchy_name"],
				owner_house["name"], int(game.opinion[int(p["owner"])]),
				terrain_name, terrain_def, supply * 100,
				capital_txt, int(p["dev"]), int(p["levy"]), ", ".join(nb),
			]
	return info

static func _any_action(game, kind: String) -> bool:
	for i in game.houses.size():
		if game.can_action(kind, i):
			return true
	return false

static func picker(game, kind: String) -> Dictionary:
	var title: String = {
		"marry": "Wen heiratest du?",
		"seduce": "Wen verführst du?",
		"murder": "Wen lässt du beseitigen?",
		"kidnap": "Wen lässt du entführen?",
	}.get(kind, "Ziel wählen")
	var options: Array = []
	for i in game.houses.size():
		if i == game.player:
			continue
		var h: Dictionary = game.houses[i]
		var chance: int = int(round(game.action_chance(kind, i) * 100.0))
		var cost: int = game.action_cost(kind)
		options.append({
			"index": i,
			"text": "%s — %s · Haltung %+d · %d%% · %d Gold" % [
				h["name"], h["ruler"]["name"], int(game.opinion[i]), chance, cost
			],
			"enabled": game.can_action(kind, i),
		})
	return {"title": title, "options": options}

static func event(game) -> Dictionary:
	var ev = game.pending_event
	if ev == null:
		return {"title": "", "text": "", "options": []}
	var options: Array = []
	for opt in ev.get("options", []):
		options.append({"label": str(opt["label"]), "chips": _effect_chips(opt.get("effects", {}))})
	return {"id": str(ev.get("id", "")), "title": str(ev["title"]), "text": str(ev["text"]), "options": options}

const EFFECT_NAMES := {
	"gold": ["Gold", 1], "prestige": ["Prestige", 1], "legitimacy": ["Legitimität", 1],
	"levy": ["Truppen", 1], "dev": ["Entwicklung", 1], "health": ["Gesundheit", 1],
	"heir": ["Erbe", 0],
}

static func _effect_chips(effects: Dictionary) -> String:
	var parts: Array = []
	for key in effects:
		var meta: Array = EFFECT_NAMES.get(str(key), [str(key), 1])
		var value: int = int(effects[key])
		if value == 0:
			parts.append("[b][color=#d8c9a6]%s[/color][/b]" % str(meta[0]))
			continue
		var sign_text := "+" if value > 0 else "−"
		var text := "%s%d %s" % [sign_text, absi(value), str(meta[0])]
		var col := "#1c6b2f" if value > 0 else "#9c2f24"
		parts.append("[b][color=%s]%s[/color][/b]" % [col, text])
	return "   ".join(parts)

static func tree(game) -> Dictionary:
	var h: Dictionary = game.house()
	var spouse: Dictionary = h["spouse"]
	var law: String = str(h["laws"]["succession"])
	return {
		"title": "Stammbaum — %s" % h["name"],
		"order": game.succession_order(game.player),
		"spouse": "Gemahl/in: %s" % ("unvermählt" if spouse.is_empty() else spouse["name"]),
		"ruler": "Herrscher: %s (%d Jahre)" % [h["ruler"]["name"], int(h["ruler"]["age"])],
		"law": "Erbfolgegesetz: %s." % ("Ältester" if law == "eldest" else "Jüngster"),
	}

static func rule(game, selected: String) -> Dictionary:
	var h: Dictionary = game.house()
	var target: int = _target_house(game, selected)
	var offices: Array = []
	var vote_preview: Dictionary = game.council_vote_preview("land_frieden")
	var vote_by_office: Dictionary = {}
	for vote in vote_preview.get("votes", []):
		vote_by_office[str(vote["office"])] = vote
	for office_id in game.COUNCIL_ROLES:
		var office: String = str(office_id)
		var role: Dictionary = game.COUNCIL_OFFICES[office]
		var member: Dictionary = game.council_member(game.player, office)
		var stat: String = str(role["stat"])
		var member_text := "unbesetzt"
		if not member.is_empty():
			member_text = "%s · %s %d" % [member["name"], stat, int(member[stat])]
		var vote: Dictionary = vote_by_office.get(office, {})
		offices.append({
			"id": office, "name": str(role["name"]), "effect": str(role["effect"]),
			"text": "%s: %s" % [str(role["name"]), member_text],
			"vote": "Ja" if bool(vote.get("vote", false)) else "Nein",
			"icon": "council_%s" % office,
		})
	var vassals: Array = []
	for vi in int(h.get("vassals", []).size()):
		var contract: Dictionary = game.vassal_contract_info(vi)
		if contract.is_empty():
			continue
		var next_level: int = int(contract["next_level"])
		var next_contract: Dictionary = game.VASSAL_CONTRACTS[next_level]
		contract["effect"] = "Steuern +%d Gold/Jahr · Aufgebot +%d · Meinung %d" % [
			int(contract["tax"]), int(contract["levy"]), int(contract["opinion"])
		]
		contract["next_effect"] = "%s: +%d Gold, +%d Aufgebot, Meinung −10" % [
			str(next_contract["name"]), int(next_contract["tax"]), int(next_contract["levy"])
		]
		contract["raise_text"] = "Erhöhen · %d G" % int(contract["raise_cost"])
		contract["lower_text"] = "Senken"
		vassals.append(contract)
	var resolutions: Array = []
	for resolution_id in ["war_levy", "land_frieden", "crown_tax", "shadow_network"]:
		var resolution: Dictionary = game.council_resolution_info(str(resolution_id))
		if resolution.is_empty():
			continue
		resolution["votes_text"] = "%d/%d Stimmen · %s" % [
			int(resolution["yes"]), int(resolution["required"]), "angenommen" if bool(resolution["passed"]) else "abgelehnt"
		]
		resolution["cost_text"] = "%d Gold%s" % [
			int(resolution["cost_gold"]),
			"" if int(resolution["cost_prestige"]) <= 0 else " · %d Prestige" % int(resolution["cost_prestige"])
		]
		resolution["icon"] = "council_%s" % str(resolution["role"])
		resolutions.append(resolution)
	var p: Dictionary = {}
	if selected != "":
		p = game.province(selected)
	var buildings: Array = []
	if not p.is_empty():
		for entry in [["market", "Markt"], ["barracks", "Kaserne"], ["walls", "Mauern"]]:
			var key: String = str(entry[0])
			var level: int = int((p.get("buildings", {}) as Dictionary).get(key, 0))
			buildings.append({
				"key": key,
				"name": str(entry[1]),
				"level": level,
				"text": "%s: Stufe %d/3 · %d Gold" % [entry[1], level, game.building_cost(key)],
				"disabled": not game.can_build(selected, key),
			})
	var legacies: Array = []
	for track in ["war", "crown", "guile"]:
		var info: Dictionary = game.legacy_track_info(track)
		var level: int = game.legacy_level(track)
		var cost: int = game.legacy_cost(track)
		legacies.append({
			"id": track,
			"name": str(info.get("name", track)),
			"effect": str(info.get("effect", "")),
			"level": level,
			"max": game.LEGACY_MAX_LEVEL,
			"cost": cost,
			"maxed": level >= game.LEGACY_MAX_LEVEL,
			"disabled": not game.can_unlock_legacy(track),
			"icon": "legacy_%s" % track,
		})
	var law: String = str(h["laws"]["succession"])
	var fleet: Dictionary = game.fleet_for(game.player)
	var fleet_text := "Flotte: keine · Küstenblockade nicht möglich"
	if not fleet.is_empty():
		var port: Dictionary = game.province(str(fleet.get("province", "")))
		var station: Dictionary = game.province(str(fleet.get("station", "")))
		var location: String = str(port.get("name", "?"))
		if not station.is_empty() and str(station.get("id", "")) != str(port.get("id", "")):
			location = "blockiert %s" % str(station.get("name", "?"))
		fleet_text = "Flotte: %d Schiffe · Moral %d · Unterhalt %d Gold/Jahr · %s" % [
			int(fleet.get("ships", 0)), int(fleet.get("morale", 0)), int(fleet.get("upkeep", 0)), location
		]
	return {
		"title": "Herrschaft — %s" % str(h["name"]),
		"summary": "Legitimität %d/100 · Prestige %d · Ruhm %d · Gold %d · Steuersatz %d" % [
			int(h["legitimacy"]), int(h["prestige"]), int(h["renown"]), int(h["gold"]), int(h["laws"]["tax"])
		],
		"renown_value": int(h["renown"]),
		"renown_hint": "Ruhm wächst monatlich durch Prestige, Besitz und Diplomatie; Ehen und Geburten bringen zusätzlichen Ruhm.",
		"legacies": legacies,
		"faction": "Faktionsdruck %d/100 · Ansprüche %d · Armeen %d · Schiffe %d" % [
			game.faction_power(game.player), h["claims"].size(), h["armies"].size(), int(fleet.get("ships", 0))
		],
		"fleet": fleet_text,
		"vassals": vassals,
		"vassal_tax": game.vassal_tax_income(game.player),
		"vassal_levy": game.vassal_levy_bonus(game.player),
		"vassal_opinion": game.vassal_opinion_avg(game.player),
		"offices": offices,
		"resolutions": resolutions,
		"council_intrigue": "Spionmeister: +%d Prozentpunkte Intrigenchance (passiv + Schattennetz)." % game.council_intrigue_percent(game.player),
		"training": "Marschallstraining: +%d Truppen pro Jahr (Martial und Legitimität zählen)." % game.council_training_amount(game.player),
		"law": "Erbfolge: %s" % ("Ältester" if law == "eldest" else "Jüngster"),
		"tax": "Steuersatz: %d/2" % int(h["laws"]["tax"]),
		"heir": "Erbe: %s" % (str(h["heir"]) if str(h["heir"]) != "" else "keiner"),
		"target": ("Ziel: %s · Meinung %d · Waffenstillstand bis %d" % [
			str(game.houses[target]["name"]), int(game.opinion[target]), game.truce_until(target)
		]) if target >= 0 else "Wähle eine fremde Provinz als Ziel.",
		"target_house": target,
		"claim_disabled": selected == "" or not game.is_border_province(game.player, selected) or int(h["gold"]) < 40,
		"army_disabled": selected == "" or int(game.province(selected).get("owner", -1)) != game.player or int(h["gold"]) < 50,
		"siege_disabled": selected == "" or not game.has_claim(selected) or game.army_for(game.player).is_empty(),
		"fleet_disabled": selected == "" or not game.can_raise_fleet(selected),
		"blockade_disabled": selected == "" or not game.can_blockade(selected),
		"peace_disabled": target < 0,
		"discover_disabled": target < 0,
		"expose_disabled": target < 0,
		"province_hint": "Wähle auf der Karte eine eigene Provinz.",
		"province_text": ("%s · %s · Truppen %d" % [p["name"], p.get("terrain_name", "Ebenen"), int(p["levy"])]) if not p.is_empty() else "",
		"buildings": buildings,
		"defense": ("%s · Verteidigung %d/100 · Gelände %+d%% · Belagerung %d%%%s" % [p.get("terrain_name", "Ebenen"), int(p.get("defense", 0)), int(p.get("terrain_defense", 0)), int(p.get("siege", 0)), (" · Blockade %d Monate" % int(p.get("blockade", 0))) if int(p.get("blockade", 0)) > 0 else ""]) if not p.is_empty() else "",
	}

static func court(game) -> Dictionary:
	var h: Dictionary = game.house()
	var relics: Array = []
	var owned_relics: int = 0
	for relic_id in game.RELIC_ORDER:
		var info: Dictionary = game.relic_info(str(relic_id))
		if info.is_empty():
			continue
		info["button_text"] = "Im Besitz" if bool(info["owned"]) else "Schmieden · %d G · %d P" % [int(info["cost_gold"]), int(info["cost_prestige"])]
		info["disabled"] = bool(info["owned"]) or not bool(info["can_forge"])
		relics.append(info)
		if bool(info["owned"]):
			owned_relics += 1
	var hall: int = game.court_hall_level()
	var max_hall: int = game.COURT_MAX_HALL
	var cost: int = game.court_hall_cost()
	var prestige_cost: int = game.court_hall_prestige_cost()
	var expected: int = game.court_expected_grandeur()
	var delta: int = game.court_expectation_delta()
	var delta_text := ("+%d" % delta) if delta >= 0 else ("−%d" % absi(delta))
	var expectation_effect: Dictionary = game.court_expectation_effect()
	var amenities: Array = []
	var amenity_total := 0
	for amenity_id in game.COURT_AMENITY_ORDER:
		var info: Dictionary = game.court_amenity_info(str(amenity_id))
		if info.is_empty():
			continue
		amenity_total += int(info["level"])
		info["level_text"] = "%d/%d" % [int(info["level"]), int(info["max"])]
		amenities.append(info)
	return {
		"title": "Hof & Reliquien — %s" % str(h["name"]),
		"summary": "Hofpracht %d/100 · Erwartet %d · Hofhalle %d/%d · Legitimität %d · Prestige %d · Gold %d" % [
			game.court_grandeur(), expected, hall, max_hall, int(h["legitimacy"]), int(h["prestige"]), int(h["gold"])
		],
		"grandeur": game.court_grandeur(),
		"expected": expected,
		"expectation_delta": delta,
		"expectation_text": "Erwartet %d · Aktuell %d (%s)" % [expected, game.court_grandeur(), delta_text],
		"expectation_corridor": "Zielkorridor %d–%d" % [maxi(0, expected - 5), mini(100, expected + 5)],
		"expectation_effect": expectation_effect,
		"prestige_gain": game.court_prestige_gain(),
		"opinion_gain": game.court_opinion_gain(),
		"benefit": "Jährlich +%d Prestige; +%d Meinung je Vasall bei Hofpracht ab 60. Erwartung: %+d Prestige, %+d Meinung je Vasall." % [
			game.court_prestige_gain(), game.court_opinion_gain(), int(expectation_effect["prestige"]), int(expectation_effect["opinion"])
		],
		"relics": relics,
		"relics_owned": owned_relics,
		"relics_total": relics.size(),
		"hall": hall,
		"hall_max": max_hall,
		"hall_cost": cost,
		"hall_prestige": prestige_cost,
		"hall_maxed": hall >= max_hall,
		"hall_button": "Halle vollendet" if hall >= max_hall else "Halle ausbauen · %d G · %d P" % [cost, prestige_cost],
		"can_upgrade_hall": game.can_upgrade_court_hall(),
		"hall_effect": "Jede Hallenstufe gibt +%d Hofpracht; jede Ausstattungsstufe gibt +%d Hofpracht." % [game.COURT_GRANDEUR_HALL, game.COURT_AMENITY_GRANDEUR],
		"amenities": amenities,
		"amenity_total": amenity_total,
		"amenity_upkeep": game.court_amenity_upkeep(),
		"amenity_grandeur": game.COURT_AMENITY_GRANDEUR,
	}

static func faith(game) -> Dictionary:
	var h: Dictionary = game.house()
	var confession: String = game.faith_confession()
	var doctrine: Dictionary = game.faith_confession_info(confession)
	var sites: Array = []
	for site_id in game.faith_holy_sites():
		var p: Dictionary = game.province(str(site_id))
		sites.append({"id": str(site_id), "name": str(p.get("name", site_id)) if not p.is_empty() else str(site_id)})
	var confessions: Array = []
	for confession_id in game.FAITH_ORDER:
		var info: Dictionary = game.faith_confession_info(str(confession_id))
		var active: bool = str(confession_id) == confession
		info["active"] = active
		info["cost_gold"] = game.FAITH_CONVERT_COST_GOLD
		info["cost_prestige"] = game.FAITH_CONVERT_COST_PRESTIGE
		info["button_text"] = "Aktiv" if active else "Wechseln · %d G · %d P" % [game.FAITH_CONVERT_COST_GOLD, game.FAITH_CONVERT_COST_PRESTIGE]
		info["disabled"] = active or not game.can_convert_faith(str(confession_id))
		confessions.append(info)
	var site_options: Array = []
	for p in game.owned():
		var site_id: String = str(p["id"])
		var active: bool = game.faith_holy_sites().has(site_id)
		site_options.append({
			"id": site_id, "name": str(p.get("name", site_id)), "active": active,
			"button_text": "Geweiht" if active else "Weihen · %d G · %d P" % [game.FAITH_SITE_COST_GOLD, game.FAITH_SITE_COST_PIETY],
			"disabled": active or not game.can_consecrate_site(site_id),
		})
	var war: Dictionary = game.faith_holy_war()
	var war_target: int = game.faith_holy_war_target()
	var war_target_name: String = ""
	var war_capital_name: String = ""
	var war_target_confession: String = ""
	if war_target >= 0 and war_target < game.houses.size():
		war_target_name = str(game.houses[war_target]["name"])
		var war_capital_id: String = str(game.houses[war_target].get("capital", ""))
		var war_capital: Dictionary = game.province(war_capital_id)
		war_capital_name = str(war_capital.get("name", war_capital_id)) if not war_capital.is_empty() else war_capital_id
		var war_confession_id: String = game.faith_confession(war_target)
		var war_confession_info: Dictionary = game.faith_confession_info(war_confession_id)
		war_target_confession = str(war_confession_info.get("name", war_confession_id))
	var heresy_value: int = game.faith_heresy()
	var heresy_icon: String = "faith_heresy_low"
	if heresy_value >= 60:
		heresy_icon = "faith_heresy_high"
	elif heresy_value >= 30:
		heresy_icon = "faith_heresy_mid"
	var reform_icon: String = "faith_reform_%d" % game.faith_reform()
	var war_targets: Array = []
	for target_index in game.houses.size():
		if target_index == game.player:
			continue
		var target_house: Dictionary = game.houses[target_index]
		var target_capital: String = str(target_house.get("capital", ""))
		if game.province(target_capital).is_empty():
			continue
		var target_confession: String = game.faith_confession(target_index)
		var target_info: Dictionary = game.faith_confession_info(target_confession)
		var target_capital_info: Dictionary = game.province(target_capital)
		war_targets.append({
			"index": target_index, "name": str(target_house["name"]),
			"confession": str(target_info.get("name", target_confession)),
			"capital": str(target_capital_info.get("name", target_capital)),
			"icon": "faith_holy_war_%d" % target_index,
			"heresy": game.faith_heresy(target_index),
			"reason": "Ketzerei" if target_confession == confession else "Andersgläubig",
			"button_text": "Krieg erklären · %d G · %d F · %d P" % [game.FAITH_HOLY_WAR_COST_GOLD, game.FAITH_HOLY_WAR_COST_PIETY, game.FAITH_HOLY_WAR_COST_PRESTIGE],
			"disabled": not game.can_declare_holy_war(target_index),
		})
	return {
		"title": "Glaube & Kirche — %s" % str(h["name"]),
		"summary": "%s · Frömmigkeit %d/100 · Kirchenmacht %d/100 · Ketzerei %d/100 · Reform %d/%d · Heilige Stätten %d/%d" % [
			str(doctrine.get("name", "—")), game.faith_piety(), game.faith_church_power(), game.faith_heresy(), game.faith_reform(), game.FAITH_MAX_REFORM, game.faith_site_count(), game.FAITH_MAX_SITES
		],
		"confession": doctrine,
		"piety": game.faith_piety(),
		"church_power": game.faith_church_power(),
		"piety_gain": game.faith_piety_gain(),
		"opinion_gain": game.faith_church_opinion_gain(),
		"benefit": "Jährlich +%d Frömmigkeit; Kirchenmacht gibt ab 60 +1 und ab 80 +2 Vasallenmeinung." % game.faith_piety_gain(),
		"pilgrimage_cost": game.FAITH_PILGRIMAGE_COST,
		"pilgrimage_piety": game.FAITH_PILGRIMAGE_PIETY,
		"can_pilgrimage": game.can_pilgrimage(),
		"confessions": confessions,
		"sites": sites,
		"site_options": site_options,
		"site_cost_gold": game.FAITH_SITE_COST_GOLD,
		"site_cost_piety": game.FAITH_SITE_COST_PIETY,
		"heresy": game.faith_heresy(),
		"heresy_icon": heresy_icon,
		"heresy_growth": game.faith_heresy_growth(),
		"heresy_legitimacy_penalty": game.faith_heresy_legitimacy_penalty(),
		"heresy_opinion_penalty": game.faith_heresy_opinion_penalty(),
		"reform": game.faith_reform(),
		"reform_icon": reform_icon,
		"reform_max": game.FAITH_MAX_REFORM,
		"can_reform": game.can_reform_faith(),
		"reform_gold": int(game.reform_cost()["gold"]),
		"reform_piety": int(game.reform_cost()["piety"]),
		"reform_prestige": int(game.reform_cost()["prestige"]),
		"reform_text": "Reform abgeschlossen" if game.faith_reform() >= game.FAITH_MAX_REFORM else "Reform beschließen · %d G · %d F · %d P" % [int(game.reform_cost()["gold"]), int(game.reform_cost()["piety"]), int(game.reform_cost()["prestige"])],
		"can_suppress": game.can_suppress_heresy(),
		"suppress_text": "Ketzergericht · %d Gold · %d Prestige · %d Ketzerei" % [game.FAITH_SUPPRESS_COST_GOLD, game.FAITH_SUPPRESS_COST_PRESTIGE, game.FAITH_SUPPRESS_HERESY],
		"holy_war_target": war_target,
		"holy_war_target_name": war_target_name,
		"holy_war_active": war_target >= 0,
		"holy_war_icon": "faith_holy_war_%d" % war_target if war_target >= 0 else "",
		"holy_war_capital": war_capital_name,
		"holy_war_confession": war_target_confession,
		"holy_war_months": int(war.get("months", 0)),
		"holy_war_claim_months": game.faith_holy_war_claim_months(),
		"holy_war_targets": war_targets,
		"gold": int(h["gold"]), "prestige": int(h["prestige"]),
	}

static func _target_house(game, selected: String) -> int:
	if selected == "":
		return -1
	var p: Dictionary = game.province(selected)
	if p.is_empty():
		return -1
	var owner: int = int(p["owner"])
	return owner if owner != game.player else -1
