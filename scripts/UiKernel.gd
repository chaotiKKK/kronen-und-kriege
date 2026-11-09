extends RefCounted
## Flüchtiger UI-Zustand und Kommando-Router.
##
## Der Kernel hält nur Auswahl und Modalstapel. Spielzustand bleibt in Game.gd;
## jede Nutzerabsicht wird als Kommando geroutet und über Game-Methoden
## ausgeführt. Dateizugriff bleibt im Composition Root (Main.gd).

signal state_changed(refresh: Array)
signal modal_changed(top: String, stack: Array)

const FULL_REFRESH := ["top_bar", "map", "province_panel", "log"]

var game = null
var selection: String = ""
var modal_stack: Array = []
var save_handler: Callable = Callable()
var load_handler: Callable = Callable()

# --- Bindung und UI-Zustand ---------------------------------------------

func bind_game(g) -> void:
	game = g
	selection = ""
	reset_modals()

func reset_modals() -> void:
	modal_stack.clear()
	modal_changed.emit("", [])

func set_base_modal(id: String) -> void:
	reset_modals()
	push_modal(id)

func push_modal(id: String) -> void:
	if id == "":
		return
	if not modal_stack.is_empty() and str(modal_stack[-1]) == id:
		return
	modal_stack.append(id)
	modal_changed.emit(top_modal(), modal_stack.duplicate())

func pop_modal(expected: String = "") -> String:
	if modal_stack.is_empty():
		return ""
	if expected != "" and str(modal_stack[-1]) != expected:
		return top_modal()
	var popped := str(modal_stack.pop_back())
	modal_changed.emit(top_modal(), modal_stack.duplicate())
	return popped

func top_modal() -> String:
	return str(modal_stack[-1]) if not modal_stack.is_empty() else ""

func select_province(id: String) -> void:
	if id == selection:
		return
	selection = id
	state_changed.emit(["map", "province_panel"])

func clear_selection() -> void:
	select_province("")

func target_house() -> int:
	if game == null or selection == "":
		return -1
	var p: Dictionary = game.province(selection)
	if p.is_empty():
		return -1
	var owner: int = int(p["owner"])
	return owner if owner != game.player else -1

# --- Kommandovertrag ----------------------------------------------------

func dispatch(command: Dictionary) -> Dictionary:
	var id := str(command.get("id", ""))
	var result: Dictionary
	if id == "save":
		result = _delegate(save_handler, "Speichern nicht verfügbar.")
	elif id == "load":
		result = _delegate(load_handler, "Laden nicht verfügbar.")
	elif game == null:
		result = _blocked("invalid", "Kein Spiel aktiv.")
	else:
		result = _route(id, command)
	if bool(result.get("ok", false)):
		state_changed.emit(result.get("refresh", []))
	return result

func _route(id: String, command: Dictionary) -> Dictionary:
	var before: Dictionary = _digest()
	var raw: Dictionary = {}
	var refresh: Array = FULL_REFRESH.duplicate()
	var log_result := true
	match id:
		"continue_sandbox":
			raw = game.continue_sandbox()
		"research":
			raw = game.start_research(str(command.get("innovation", "")))
		"road":
			raw = game.build_road(selection, str(command.get("to", "")))
		"develop":
			raw = game.develop(selection)
		"recruit":
			raw = game.recruit(selection)
		"attack":
			raw = game.attack(selection)
		"court":
			raw = game.court()
		"bed":
			raw = game.bed()
		"ransom":
			raw = game.ransom_captive()
		"force_marry":
			raw = game.force_marry_captive()
		"marry", "seduce", "murder", "kidnap":
			var target := int(command.get("target", -1))
			if target < 0 or target >= game.houses.size() or target == game.player:
				return _blocked("invalid", "Ungültiges Ziel.")
			raw = game.do_action(id, target)
			log_result = false
		"apply_event":
			var option := int(command.get("option", -1))
			if game.pending_event == null:
				return _blocked("blocked", "Kein offenes Ereignis.")
			var options: Array = game.pending_event.get("options", [])
			if option < 0 or option >= options.size():
				return _blocked("invalid", "Ungültige Ereignisoption.")
			game.apply_event(option)
			raw = {"ok": true, "msg": ""}
			log_result = false
		"set_speed":
			var speed := clampi(int(command.get("value", 0)), 0, 3)
			game.speed = speed
			raw = {"ok": true, "msg": ""}
			refresh = ["top_bar"]
			log_result = false
		"council_assign":
			var office := str(command.get("office", ""))
			var courtiers: Array = game.house().get("courtiers", [])
			if office == "" or courtiers.is_empty():
				return _blocked("blocked", "Kein Rat verfügbar.")
			var index := int(command.get("index", -1))
			if index < 0:
				var current := int(game.house()["council"].get(office, 0))
				index = (current + 1) % courtiers.size()
			raw = game.assign_council(office, index)
		"law_succession":
			var current_law := str(game.house()["laws"]["succession"])
			raw = game.set_law("succession", "youngest" if current_law == "eldest" else "eldest")
		"build":
			if selection == "":
				return _blocked("invalid", "Keine Provinz gewählt.")
			raw = game.build(selection, str(command.get("key", "")))
		"set_tax":
			var current_tax := int(game.house()["laws"]["tax"])
			raw = game.set_law("tax", str((current_tax + 1) % 3))
		"legacy":
			raw = game.unlock_legacy(str(command.get("track", "")))
		"vassal_contract":
			raw = game.change_vassal_contract(int(command.get("vassal", -1)), int(command.get("level", -1)))
		"council_resolution":
			raw = game.enact_council_resolution(str(command.get("resolution", "")))
		"forge_relic":
			raw = game.forge_relic(str(command.get("relic", "")))
		"upgrade_court_hall":
			raw = game.upgrade_court_hall()
		"upgrade_court_amenity":
			raw = game.upgrade_court_amenity(str(command.get("amenity", "")))
		"pilgrimage":
			raw = game.pilgrimage()
		"consecrate_site":
			raw = game.consecrate_site(str(command.get("province", "")))
		"convert_faith":
			raw = game.convert_faith(str(command.get("confession", "")))
		"suppress_heresy":
			raw = game.suppress_heresy()
		"reform_faith":
			raw = game.reform_faith()
		"declare_holy_war":
			raw = game.declare_holy_war(int(command.get("target", -1)))
		"claim":
			if selection == "":
				return _blocked("invalid", "Keine Provinz gewählt.")
			raw = game.fabricate_claim(selection)
		"army":
			if selection == "":
				return _blocked("invalid", "Keine Provinz gewählt.")
			raw = game.raise_army(selection)
		"siege":
			if selection == "":
				return _blocked("invalid", "Keine Provinz gewählt.")
			raw = game.advance_siege(selection)
		"fleet":
			if selection == "":
				return _blocked("invalid", "Keine Provinz gewählt.")
			raw = game.raise_fleet(selection)
		"blockade":
			if selection == "":
				return _blocked("invalid", "Keine Provinz gewählt.")
			raw = game.blockade(selection)
		"peace":
			var peace_target := target_house()
			if peace_target < 0:
				return _blocked("no_target", "Kein fremdes Ziel gewählt.")
			raw = game.make_peace(peace_target)
		"secret_discover":
			var discover_target := target_house()
			if discover_target < 0:
				return _blocked("no_target", "Kein fremdes Ziel gewählt.")
			raw = game.discover_secret(discover_target)
		"secret_expose":
			var expose_target := target_house()
			if expose_target < 0:
				return _blocked("no_target", "Kein fremdes Ziel gewählt.")
			raw = game.expose_secret(expose_target)
		_:
			return _blocked("invalid", "Unbekanntes Kommando: %s" % id)
	return _finish(raw, before, refresh, log_result)

func _finish(raw: Dictionary, before: Dictionary, refresh: Array, log_result: bool) -> Dictionary:
	var ok := bool(raw.get("ok", false))
	var message := str(raw.get("msg", ""))
	if log_result and message != "":
		game.note(message)
	return {
		"ok": ok,
		"code": "ok" if ok else "blocked",
		"message": message,
		"delta": _delta(before, _digest()),
		"refresh": refresh.duplicate(),
	}

func _blocked(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"delta": {},
		"refresh": [],
	}

func _delegate(handler: Callable, fallback: String) -> Dictionary:
	if not handler.is_valid():
		return _blocked("invalid", fallback)
	var out = handler.call()
	if out is Dictionary:
		var result: Dictionary = out
		var ok := bool(result.get("ok", false))
		result["ok"] = ok
		result["code"] = str(result.get("code", "ok" if ok else "blocked"))
		if not result.has("message"):
			result["message"] = ""
		if not result.has("delta"):
			result["delta"] = {}
		if not result.has("refresh"):
			result["refresh"] = []
		return result
	var ok := bool(out) if out is bool else true
	return {
		"ok": ok,
		"code": "ok" if ok else "blocked",
		"message": "",
		"delta": {},
		"refresh": [],
	}

func _digest() -> Dictionary:
	if game == null:
		return {}
	var h: Dictionary = game.house()
	var out := {
		"speed": int(game.speed),
		"gold": int(h["gold"]),
		"prestige": int(h["prestige"]),
		"legitimacy": int(h["legitimacy"]),
		"renown": int(h.get("renown", 0)),
		"vassal_opinion": game.vassal_opinion_avg(),
		"intrigue_bonus": game.council_intrigue_percent(),
		"court_grandeur": game.court_grandeur(),
		"court_expected": game.court_expected_grandeur(),
		"court_expectation_delta": game.court_expectation_delta(),
		"court_hall": game.court_hall_level(),
		"court_amenities": game.court_amenity_total(),
		"court_upkeep": game.court_amenity_upkeep(),
		"relics": game.court_relics().size(),
		"confession": game.faith_confession(),
		"faith_piety": game.faith_piety(),
		"church_power": game.faith_church_power(),
		"faith_heresy": game.faith_heresy(),
		"faith_reform": game.faith_reform(),
		"holy_war_target": game.faith_holy_war_target(),
		"holy_sites": game.faith_site_count(),
	}
	if selection != "":
		var p: Dictionary = game.province(selection)
		if not p.is_empty():
			out["owner"] = int(p["owner"])
			out["dev"] = int(p["dev"])
			out["levy"] = int(p["levy"])
	return out

func _delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in before.keys():
		if key == "player":
			continue
		if before[key] != after.get(key):
			out[key] = after.get(key)
	return out
