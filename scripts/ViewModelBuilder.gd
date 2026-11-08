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
	var family_text := "Gemahl/in: %s\nErbe: %s · Kinder: %d\nGeliebte/r: %s · Gefangene/r: %s\nGold %d · Prestige %d · Legitimität %d" % [
		spouse_txt, heir_txt, h["children"].size(), lover_txt, capt_txt,
		int(h["gold"]), int(h["prestige"]), int(h["legitimacy"]),
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
		options.append(str(opt["label"]))
	return {"title": str(ev["title"]), "text": str(ev["text"]), "options": options}

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
	for office in [["marshal", "Marschall", "martial"], ["chancellor", "Kanzler", "diplomacy"], ["steward", "Verwalter", "stewardship"]]:
		var member: Dictionary = game.council_member(game.player, str(office[0]))
		var member_text := "unbesetzt"
		if not member.is_empty():
			member_text = "%s · %s %d" % [member["name"], office[2], int(member[str(office[2])])]
		offices.append({
			"id": str(office[0]),
			"text": "%s: %s" % [office[1], member_text],
		})
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
				"text": "%s: Stufe %d/3 · %d Gold" % [entry[1], level, game.building_cost(key)],
				"disabled": not game.can_build(selected, key),
			})
	var law: String = str(h["laws"]["succession"])
	return {
		"title": "Herrschaft — %s" % str(h["name"]),
		"summary": "Legitimität %d/100 · Prestige %d · Gold %d · Steuersatz %d" % [
			int(h["legitimacy"]), int(h["prestige"]), int(h["gold"]), int(h["laws"]["tax"])
		],
		"faction": "Faktionsdruck %d/100 · Ansprüche %d · Armeen %d" % [
			game.faction_power(game.player), h["claims"].size(), h["armies"].size()
		],
		"offices": offices,
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
		"peace_disabled": target < 0,
		"discover_disabled": target < 0,
		"expose_disabled": target < 0,
		"province_hint": "Wähle auf der Karte eine eigene Provinz.",
		"province_text": ("%s · %s · Truppen %d" % [p["name"], p.get("terrain_name", "Ebenen"), int(p["levy"])]) if not p.is_empty() else "",
		"buildings": buildings,
		"defense": ("%s · Verteidigung %d/100 · Gelände %+d%% · Belagerung %d%%" % [p.get("terrain_name", "Ebenen"), int(p.get("defense", 0)), int(p.get("terrain_defense", 0)), int(p.get("siege", 0))]) if not p.is_empty() else "",
	}

static func _target_house(game, selected: String) -> int:
	if selected == "":
		return -1
	var p: Dictionary = game.province(selected)
	if p.is_empty():
		return -1
	var owner: int = int(p["owner"])
	return owner if owner != game.player else -1
