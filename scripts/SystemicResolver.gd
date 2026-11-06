extends RefCounted
## Zentraler Auflösepunkt für die Welle-1-Kanten.
##
## Jede Wirkung ist ein Dictionary mit:
##   edge     Matrix-ID, z. B. "H1" (leer = Hilfswirkung ohne Kante)
##   source   Quellsystem für den Beleg
##   target   Zieldomäne für den Beleg
##   state    konkrete Zustandsgröße, z. B. "provinces[alba].levy"
##   kind     gold | prestige | legitimacy | levy | opinion | building | heir |
##            scandal | dev | defense | siege | faction_power | faction_loyalty |
##            law | ruler_stat | truce
##   house    Hausindex (Default: Spieler)
##   amount   ganze Zahl; building, heir und law ignorieren sie
##   province Provinz-ID für levy/building/dev/defense/siege
##   building market | barracks | walls
##   index    Zielhaus für opinion oder Faktionsindex
##   target_house  Zielhaus für truce
##   law_key, law_value  Gesetzesfeld und neuer Wert
##   stat     Charakterwert für ruler_stat
##
## Der Resolver liest den Wert, schreibt ihn, erzeugt einen Beleg und legt ihn
## über host.record_effect() ab. Wenn eine Kante per Testhook deaktiviert ist,
## wird die Wirkung vollständig übersprungen.

func apply(host, effects: Array) -> Array:
	var applied: Array = []
	for raw in effects:
		if not (raw is Dictionary):
			continue
		var effect: Dictionary = raw
		var edge: String = str(effect.get("edge", ""))
		if edge != "" and bool(host.disabled_edges.get(edge, false)):
			continue
		var before = _read(host, effect)
		var after = _write(host, effect, before)
		if _same(before, after):
			continue
		var entry: Dictionary = {
			"edge": edge,
			"source": str(effect.get("source", "")),
			"target": str(effect.get("target", "")),
			"state": str(effect.get("state", "")),
			"kind": str(effect.get("kind", "")),
			"house": int(effect.get("house", host.player)),
			"before": before,
			"after": after,
			"delta": _delta(before, after),
			"reason": str(effect.get("reason", "")),
		}
		host.record_effect(entry)
		applied.append(entry)
	return applied

func _read(host, effect: Dictionary):
	var house_index: int = int(effect.get("house", host.player))
	match str(effect.get("kind", "")):
		"gold":
			return int(host.houses[house_index]["gold"])
		"prestige":
			return int(host.houses[house_index]["prestige"])
		"legitimacy":
			return int(host.houses[house_index]["legitimacy"])
		"levy":
			var province: Dictionary = host.province(str(effect.get("province", "")))
			return int(province.get("levy", 0))
		"opinion":
			var index: int = int(effect.get("index", -1))
			if index >= 0 and index < host.opinion.size():
				return int(host.opinion[index])
			return 0
		"building":
			var province: Dictionary = host.province(str(effect.get("province", "")))
			if province.is_empty():
				return 0
			var key: String = str(effect.get("building", "barracks"))
			return int((province.get("buildings", {}) as Dictionary).get(key, 0))
		"heir":
			return str(host.houses[house_index].get("heir", ""))
		"scandal":
			return int(host.scandal)
		"dev":
			return int(host.province(str(effect.get("province", ""))).get("dev", 0))
		"defense":
			return int(host.province(str(effect.get("province", ""))).get("defense", 0))
		"siege":
			return int(host.province(str(effect.get("province", ""))).get("siege", 0))
		"faction_power":
			return _faction_value(host, house_index, effect, "power")
		"faction_loyalty":
			return _faction_value(host, house_index, effect, "loyalty")
		"law":
			return (host.houses[house_index].get("laws", {}) as Dictionary).get(str(effect.get("law_key", "tax")), 0)
		"ruler_stat":
			return int((host.houses[house_index].get("ruler", {}) as Dictionary).get(str(effect.get("stat", "martial")), 0))
		"truce":
			return int((host.houses[house_index].get("truces", {}) as Dictionary).get(str(int(effect.get("target_house", -1))), 0))
	return null

func _write(host, effect: Dictionary, before):
	var house_index: int = int(effect.get("house", host.player))
	var amount: int = int(effect.get("amount", 0))
	match str(effect.get("kind", "")):
		"gold":
			host.houses[house_index]["gold"] = maxi(0, int(before) + amount)
			return int(host.houses[house_index]["gold"])
		"prestige":
			host.houses[house_index]["prestige"] = maxi(0, int(before) + amount)
			return int(host.houses[house_index]["prestige"])
		"legitimacy":
			host.houses[house_index]["legitimacy"] = clampi(int(before) + amount, 0, 100)
			return int(host.houses[house_index]["legitimacy"])
		"levy":
			var province: Dictionary = host.province(str(effect.get("province", "")))
			if province.is_empty():
				return before
			province["levy"] = clampi(int(before) + amount, 0, 4000)
			return int(province["levy"])
		"opinion":
			var index: int = int(effect.get("index", -1))
			if index < 0 or index >= host.opinion.size():
				return before
			host.opinion[index] = clampi(int(before) + amount, -100, 100)
			return int(host.opinion[index])
		"building":
			var province: Dictionary = host.province(str(effect.get("province", "")))
			if province.is_empty():
				return before
			var key: String = str(effect.get("building", "barracks"))
			var buildings: Dictionary = province.get("buildings", {})
			buildings[key] = clampi(int(before) + amount, 0, 3)
			province["buildings"] = buildings
			return int(buildings[key])
		"heir":
			return _write_heir(host, house_index)
		"scandal":
			host.scandal = maxi(0, int(before) + amount)
			return int(host.scandal)
		"dev":
			var dev_province: Dictionary = host.province(str(effect.get("province", "")))
			if dev_province.is_empty():
				return before
			dev_province["dev"] = clampi(int(before) + amount, 1, 10)
			return int(dev_province["dev"])
		"defense":
			var defense_province: Dictionary = host.province(str(effect.get("province", "")))
			if defense_province.is_empty():
				return before
			defense_province["defense"] = clampi(int(before) + amount, 0, 100)
			return int(defense_province["defense"])
		"siege":
			var siege_province: Dictionary = host.province(str(effect.get("province", "")))
			if siege_province.is_empty():
				return before
			siege_province["siege"] = clampi(int(before) + amount, 0, 100)
			siege_province["siege_owner"] = int(effect.get("house", host.player))
			return int(siege_province["siege"])
		"faction_power":
			return _write_faction(host, house_index, effect, "power", before)
		"faction_loyalty":
			return _write_faction(host, house_index, effect, "loyalty", before)
		"law":
			var laws: Dictionary = host.houses[house_index].get("laws", {})
			laws[str(effect.get("law_key", "tax"))] = effect.get("law_value", before)
			host.houses[house_index]["laws"] = laws
			return laws[str(effect.get("law_key", "tax"))]
		"ruler_stat":
			var ruler: Dictionary = host.houses[house_index].get("ruler", {})
			var stat: String = str(effect.get("stat", "martial"))
			ruler[stat] = clampi(int(before) + amount, 1, 20)
			return int(ruler[stat])
		"truce":
			var truces: Dictionary = host.houses[house_index].get("truces", {})
			var target_house: int = int(effect.get("target_house", -1))
			if target_house < 0:
				return before
			if amount <= 0:
				truces.erase(str(target_house))
				return 0
			truces[str(target_house)] = amount
			host.houses[house_index]["truces"] = truces
			return amount
	return before

func _faction_value(host, house_index: int, effect: Dictionary, key: String) -> int:
	var factions: Array = host.houses[house_index].get("factions", [])
	var index: int = int(effect.get("index", 0))
	if index < 0 or index >= factions.size():
		return 0
	return int(factions[index].get(key, 0))

func _write_faction(host, house_index: int, effect: Dictionary, key: String, before) -> int:
	var factions: Array = host.houses[house_index].get("factions", [])
	var index: int = int(effect.get("index", 0))
	if index < 0 or index >= factions.size():
		return before
	factions[index][key] = clampi(int(before) + int(effect.get("amount", 0)), 0, 100)
	return int(factions[index][key])

func _write_heir(host, house_index: int) -> String:
	var house: Dictionary = host.houses[house_index]
	var children: Array = house.get("children", [])
	if children.is_empty():
		house["heir"] = ""
		house["heir_age"] = 0
		return ""
	var law: String = str((house.get("laws", {}) as Dictionary).get("succession", "eldest"))
	var best: Dictionary = children[0]
	for child in children:
		if law == "youngest":
			if int(child.get("age", 0)) < int(best.get("age", 0)):
				best = child
		elif int(child.get("age", 0)) > int(best.get("age", 0)):
			best = child
	house["heir"] = str(best.get("name", ""))
	house["heir_age"] = int(best.get("age", 0))
	return str(house["heir"])

func _delta(before, after):
	if (before is int or before is float) and (after is int or after is float):
		return after - before
	return 0

func _same(before, after) -> bool:
	if before is float and after is float:
		return is_equal_approx(before, after)
	return before == after
