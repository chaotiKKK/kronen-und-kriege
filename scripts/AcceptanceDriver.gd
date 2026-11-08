extends Node
## Opt-in Windows acceptance driver. It is only created when the process is
## started with `-- --acceptance --out=<absolute path>`. All game mutations are
## still reached through the real buttons and the normal UI callbacks; the
## driver only locates controls in the live scene tree and injects mouse input.

var main: Control
var out_dir := ""
var run_start_ms := 0
var started_wall := ""
var result := {
	"status": "DURCHGEFALLEN",
	"started_wall": "",
	"ended_wall": "",
	"start": {},
	"actions": {},
	"roundtrips": {},
	"ai": {},
	"errors": [],
}
var _log_lines: Array = []
var _action_started: Dictionary = {}
var _target := ""
var _target_house := -1
var _house_for_secret := -1
var smoke := false

func begin(main_node: Control, args: Array) -> void:
	main = main_node
	for arg in args:
		var text := str(arg)
		if text.begins_with("--out="):
			out_dir = text.substr(6).replace("\\", "/")
		if text == "--smoke":
			smoke = true
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("user://acceptance").replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir + "/screens")
	DirAccess.make_dir_recursive_absolute(out_dir + "/saves")
	_log("driver started; out=" + out_dir)
	await get_tree().create_timer(0.8).timeout
	await _run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--acceptance"):
		return
	await _click_button("Neues Spiel")
	await get_tree().create_timer(0.5).timeout
	await _click_button("Haus Sequana")
	await get_tree().create_timer(0.8).timeout
	run_start_ms = Time.get_ticks_msec()
	started_wall = Time.get_datetime_string_from_system()
	result["started_wall"] = started_wall
	result["start"] = _start_values()
	_log("run_start " + started_wall + " values=" + JSON.stringify(result["start"]))

	# 00:30: untouched AI baseline.
	await _wait_until(30)
	await _save_copy("ai-start.json")
	await _wait_until(45)

	# 00:00-05:00; P01/P02, then one yearly tick for the council training.
	var p01 := await _open_rule_and_click("Wechseln", "P01")
	await _close_rule()
	await _wait_until(60)
	var p02 := await _open_rule_and_click("Erbfolge: Ältester", "P02")
	await _close_rule()
	await _advance_months(12)
	var training := _training_log()
	p01["observed"] = "Marschallwechsel; " + training
	p01["pass"] = p01["pass"] and training.find("trainiert") >= 0
	result["actions"]["P01"] = p01
	result["actions"]["P02"] = p02

	# 04:30: first save/load round trip.
	await _wait_until(270)
	result["roundtrips"]["1"] = await _roundtrip(1)

	# 05:00-10:00: P03, P04; screenshot exactly at the window boundary.
	await _wait_until(300)
	await _shot_periodic(5)
	var p03 := await _open_rule_and_click("Steuersatz: 1/2", "P03")
	await _close_rule()
	result["actions"]["P03"] = p03
	await _wait_until(315)
	var p04 := await _do_build("market", "P04")
	result["actions"]["P04"] = p04
	await _close_rule()

	# 10:00-15:00: P05 and P06; screenshot at 10:00 before the actions.
	await _wait_until(600)
	await _shot_periodic(10)
	var p05 := await _do_build("barracks", "P05")
	result["actions"]["P05"] = p05
	await _close_rule()
	await _ensure_gold(30, 30)
	var p06 := await _do_marriage()
	result["actions"]["P06"] = p06
	await _wait_until(870)
	result["roundtrips"]["2"] = await _roundtrip(2)

	# 15:00-20:00: P07/P08 (the five-year income has to be earned first).
	await _wait_until(900)
	await _shot_periodic(15)
	await _ensure_gold(90, 48)
	var p07 := await _do_claim()
	result["actions"]["P07"] = p07
	await _close_rule()
	var p08 := await _do_army()
	result["actions"]["P08"] = p08
	await _close_rule()

	# 20:00-25:00: P09/P10/P12, all while paused; screenshot at 20:00.
	await _wait_until(1200)
	await _shot_periodic(20)
	var p09 := await _do_siege()
	result["actions"]["P09"] = p09
	var p10 := await _do_peace()
	result["actions"]["P10"] = p10
	await _close_rule()
	var p12 := await _check_truce_attack()
	result["actions"]["P12"] = p12

	# 24:30: third round trip, then P11; screenshot at 25:00.
	await _wait_until(1470)
	result["roundtrips"]["3"] = await _roundtrip(3)
	await _wait_until(1500)
	await _shot_periodic(25)
	var p11 := await _do_secret()
	result["actions"]["P11"] = p11
	await _close_rule()

	# 30:00: save and final screenshot must both be on disk.
	await _wait_until(1800)
	await _close_rule()
	await _save_copy("ai-end.json")
	await _shot("win-042-3000.png")
	await _shot("win-042-3000-preview.png")
	result["ai"] = _ai_diff()
	result["ended_wall"] = Time.get_datetime_string_from_system()
	result["status"] = _overall_status()
	_write_result()
	_log("run_end " + str(result["ended_wall"]) + " status=" + str(result["status"]))
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

# --- Control lookup and real input ---------------------------------------

func _buttons(root: Node, prefix: String, include_disabled := false) -> Array:
	var found: Array = []
	_collect_buttons(root, prefix, include_disabled, found)
	return found

func _collect_buttons(node: Node, prefix: String, include_disabled: bool, found: Array) -> void:
	for child in node.get_children():
		if child is Button:
			var b := child as Button
			if b.is_visible_in_tree() and (include_disabled or not b.disabled) and b.text.begins_with(prefix):
				found.append(b)
		_collect_buttons(child, prefix, include_disabled, found)

func _click_button(prefix: String, root: Node = null, include_disabled := false, index := 0) -> bool:
	var scope: Node = main if root == null else root
	for _attempt in range(30):
		var candidates: Array = _buttons(scope, prefix, include_disabled)
		if candidates.size() > index:
			var b: Button = candidates[index]
			await _ensure_visible(b)
			var pos: Vector2 = b.get_global_rect().get_center()
			await _click_at(pos)
			await get_tree().create_timer(0.25).timeout
			return true
		await get_tree().create_timer(0.1).timeout
	_log("button not found: " + prefix)
	return false

func _click_at(pos: Vector2) -> void:
	var viewport := get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	viewport.push_input(up, true)
	await get_tree().process_frame

func _ensure_visible(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var n: Node = control.get_parent()
	while n != null:
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible(control)
			break
		n = n.get_parent()
	await get_tree().process_frame
	await get_tree().process_frame

func _open_rule() -> bool:
	var ok := await _click_button("Herrschaft")
	if ok:
		await get_tree().create_timer(0.4).timeout
	return ok and main.rule_layer.visible

func _close_rule() -> void:
	if main.rule_layer != null and main.rule_layer.visible:
		await _click_button("Schließen", main.rule_layer)
		await get_tree().create_timer(0.2).timeout

func _open_rule_and_click(button_text: String, action_id: String) -> Dictionary:
	_action_started[action_id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "button: " + button_text, "time": _clock()}
	if not await _open_rule():
		out["observed"] = "Herrschaft konnte nicht geöffnet werden."
		return out
	var before := _rule_state()
	var ok := await _click_button(button_text, main.rule_layer)
	await get_tree().create_timer(0.3).timeout
	var after := _rule_state()
	out["observed"] = "vor=" + JSON.stringify(before) + " nach=" + JSON.stringify(after)
	out["pass"] = ok and before != after
	return out

# --- Map selection: click the actual province polygon --------------------

func _select_province(id: String) -> bool:
	await _close_rule()
	if main.event_layer.visible:
		await _handle_event()
	var province: Dictionary = main.game.province(id)
	if province.is_empty():
		return false
	var parts: Array = main.map_view._province_parts(province)
	if parts.is_empty():
		return false
	var fit: Array = main.map_view._fit()
	var scale: float = float(fit[0])
	var off: Vector2 = fit[1]
	var candidates: Array = _interior_candidates(parts)
	for point in candidates:
		var local: Vector2 = off + (point as Vector2) * scale
		var rect: Rect2 = main.map_view.get_global_rect()
		var pos: Vector2 = main.map_view.get_global_transform_with_canvas() * local
		if not rect.has_point(pos):
			continue
		await _click_at(pos)
		await get_tree().create_timer(0.3).timeout
		if main.selected == id:
			return true
	return main.selected == id

func _interior_candidates(parts: Array) -> Array:
	var out: Array = []
	for part_v in parts:
		var part: PackedVector2Array = part_v
		var centroid := Vector2.ZERO
		for point in part:
			centroid += point
		centroid /= maxf(1.0, float(part.size()))
		out.append(centroid)
		var box := Rect2(part[0], Vector2.ZERO)
		for point in part:
			box = box.expand(point)
		out.append(box.get_center())
		for point in part:
			out.append(point.lerp(centroid, 0.2))
		var filtered: Array = []
		for candidate in out:
			if Geometry2D.is_point_in_polygon(candidate, part):
				filtered.append(candidate)
		if not filtered.is_empty():
			return filtered
	return out

# --- Actions -------------------------------------------------------------

func _do_build(key: String, action_id: String) -> Dictionary:
	_action_started[action_id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Bauen", "time": _clock()}
	var own: String = str(main.game.house().get("capital", "lugdunum"))
	if not await _select_province(own):
		out["observed"] = "Provinz " + own + " nicht auswählbar."
		return out
	var level_before := int((main.game.province(own).get("buildings", {}) as Dictionary).get(key, 0))
	var gold_before := int(main.game.house()["gold"])
	var label: String = "Markt" if key == "market" else ("Kaserne" if key == "barracks" else "Mauern")
	if not await _open_rule():
		out["observed"] = "Herrschaft nicht geöffnet."
		return out
	var ok := await _click_button(label + ": Stufe", main.rule_layer)
	await get_tree().create_timer(0.3).timeout
	var level_after := int((main.game.province(own).get("buildings", {}) as Dictionary).get(key, 0))
	var gold_after := int(main.game.house()["gold"])
	out["observed"] = "%s Stufe %d->%d, Gold %d->%d" % [own, level_before, level_after, gold_before, gold_after]
	out["pass"] = ok and level_after > level_before and gold_after < gold_before
	out["evidence"] = out["observed"]
	return out

func _do_marriage() -> Dictionary:
	var id := "P06"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Heiraten", "time": _clock()}
	var game = main.game
	var target := -1
	for attempt in range(3):
		target = _best_marriage_target()
		if target < 0:
			out["observed"] = "Kein aktivierbares Heiratsziel."
			return out
		await _close_rule()
		if not await _click_button("Heiraten  (30 Gold)"):
			out["observed"] = "Heiraten-Button nicht gefunden."
			return out
		await get_tree().create_timer(0.3).timeout
		var pick_buttons: Array = _buttons(main.pick_layer, "Haus ")
		if pick_buttons.is_empty():
			out["observed"] = "Heirats-Picker leer."
			return out
		var target_house: Dictionary = game.houses[target]
		var target_button: Button = null
		for b in pick_buttons:
			if (b as Button).text.begins_with(str(target_house["name"])):
				target_button = b as Button
				break
		if target_button == null:
			await _click_button("Abbrechen", main.pick_layer)
			out["observed"] = "Zielbutton im Picker nicht gefunden."
			return out
		var name_before := str(game.house()["spouse"].get("name", "")) if not game.house()["spouse"].is_empty() else ""
		await _ensure_visible(target_button)
		await _click_at(target_button.get_global_rect().get_center())
		await get_tree().create_timer(0.4).timeout
		var spouse_name := str(game.house()["spouse"].get("name", "")) if not game.house()["spouse"].is_empty() else ""
		if spouse_name != "":
			out["observed"] = "Gemahl/in: %s; Legitimität %d" % [spouse_name, int(game.house()["legitimacy"])]
			out["pass"] = spouse_name != name_before
			out["evidence"] = "Heirat Picker/Log"
			return out
		out["observed"] = "Antrag abgelehnt; Versuch %d" % (attempt + 1)
		await _advance_months(13)
		await _ensure_gold(30, 36)
	return out

func _best_marriage_target() -> int:
	var best := -1
	var best_chance := -1.0
	for i in main.game.houses.size():
		if i == main.game.player or not main.game.can_marry(i):
			continue
		var chance: float = float(main.game.action_chance("marry", i))
		if chance > best_chance:
			best_chance = chance
			best = i
	return best

func _do_claim() -> Dictionary:
	var id := "P07"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Anspruch", "time": _clock()}
	_target = _find_foreign_neighbour()
	if _target == "":
		out["observed"] = "Keine fremde Nachbarprovinz gefunden."
		return out
	_target_house = int(main.game.province(_target)["owner"])
	if not await _select_province(_target):
		out["observed"] = "Zielprovinz " + _target + " nicht auswählbar."
		return out
	var claims_before: int = main.game.house()["claims"].size()
	var gold_before := int(main.game.house()["gold"])
	if not await _open_rule():
		out["observed"] = "Herrschaft nicht geöffnet."
		return out
	var ok := await _click_button("Anspruch schmieden (40 Gold)", main.rule_layer)
	await get_tree().create_timer(0.4).timeout
	var claims_after: int = main.game.house()["claims"].size()
	out["observed"] = "%s (%s): Ansprüche %d->%d, Gold %d->%d, Angreifen disabled=%s" % [
		_target, str(main.game.houses[_target_house]["name"]), claims_before, claims_after,
		gold_before, int(main.game.house()["gold"]), str(main.attack_btn.disabled)]
	out["pass"] = ok and claims_after > claims_before and main.game.has_claim(_target)
	out["evidence"] = out["observed"]
	return out

func _find_foreign_neighbour() -> String:
	var game = main.game
	var candidates: Array = []
	for p in game.owned():
		for nid in game.neighbours(str(p["id"])):
			var q: Dictionary = game.province(str(nid))
			if q.is_empty() or int(q["owner"]) == game.player:
				continue
			var owner: int = int(q["owner"])
			if int(game.opinion[owner]) >= 50 or game.truce_until(owner) > _month_index():
				continue
			if not candidates.has(str(nid)):
				candidates.append(str(nid))
	if candidates.is_empty():
		return ""
	return str(candidates[0])

func _do_army() -> Dictionary:
	var id := "P08"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Armee", "time": _clock()}
	var own: String = str(main.game.house().get("capital", "lugdunum"))
	if not await _select_province(own):
		out["observed"] = "Eigene Provinz nicht auswählbar."
		return out
	var armies_before: int = main.game.house()["armies"].size()
	var gold_before := int(main.game.house()["gold"])
	if not await _open_rule():
		out["observed"] = "Herrschaft nicht geöffnet."
		return out
	var ok := await _click_button("Armee aufstellen (50 Gold)", main.rule_layer)
	await get_tree().create_timer(0.3).timeout
	var armies_after: int = main.game.house()["armies"].size()
	out["observed"] = "Armeen %d->%d, Gold %d->%d" % [armies_before, armies_after, gold_before, int(main.game.house()["gold"])]
	out["pass"] = ok and armies_after > armies_before
	out["evidence"] = out["observed"]
	return out

func _do_siege() -> Dictionary:
	var id := "P09"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Belagerung", "time": _clock()}
	if _target == "" or not main.game.has_claim(_target):
		out["observed"] = "Kein beanspruchtes Ziel aus P07."
		return out
	if not await _select_province(_target):
		out["observed"] = "Zielprovinz nicht auswählbar."
		return out
	var before := int(main.game.province(_target).get("siege", 0))
	if not await _open_rule():
		out["observed"] = "Herrschaft nicht geöffnet."
		return out
	var ok := await _click_button("Belagerung vorantreiben", main.rule_layer)
	await get_tree().create_timer(0.4).timeout
	var after := int(main.game.province(_target).get("siege", 0))
	out["observed"] = "%s Belagerung %d%%->%d%%" % [_target, before, after]
	out["pass"] = ok and after > before
	out["evidence"] = out["observed"]
	return out

func _do_peace() -> Dictionary:
	var id := "P10"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Frieden", "time": _clock()}
	if _target_house < 0:
		out["observed"] = "Kein Zielhaus aus P07."
		return out
	var opinion_before := int(main.game.opinion[_target_house])
	if not main.rule_layer.visible:
		if not await _open_rule():
			out["observed"] = "Herrschaft nicht geöffnet."
			return out
	var ok := await _click_button("Frieden schließen (24 Monate)", main.rule_layer)
	await get_tree().create_timer(0.4).timeout
	var truce := int(main.game.truce_until(_target_house))
	out["observed"] = "Haus %s: Waffenstillstand bis %d, Meinung %d->%d" % [
		str(main.game.houses[_target_house]["name"]), truce, opinion_before, int(main.game.opinion[_target_house])]
	out["pass"] = ok and truce > _month_index() and int(main.game.opinion[_target_house]) > opinion_before
	out["evidence"] = out["observed"]
	return out

func _check_truce_attack() -> Dictionary:
	var id := "P12"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Angreifen disabled", "time": _clock()}
	if _target_house < 0 or _target == "":
		out["observed"] = "Kein Ziel aus P07."
		return out
	if not await _select_province(_target):
		out["observed"] = "Zielprovinz nicht auswählbar."
		return out
	var disabled: bool = main.attack_btn.disabled
	var truce := int(main.game.truce_until(_target_house))
	out["observed"] = "%s: Angreifen disabled=%s, Waffenstillstand bis %d (jetzt %d)" % [_target, str(disabled), truce, _month_index()]
	out["pass"] = disabled and truce > _month_index()
	out["evidence"] = out["observed"]
	return out

func _do_secret() -> Dictionary:
	var id := "P11"
	_action_started[id] = _elapsed()
	var out := {"pass": false, "observed": "", "evidence": "Geheimnis", "time": _clock()}
	_house_for_secret = _find_secret_house()
	if _house_for_secret < 0:
		out["observed"] = "Kein anderes Haus mit freier Hauptstadt gefunden."
		return out
	var province_id := str(main.game.houses[_house_for_secret].get("capital", ""))
	if province_id == "" or not await _select_province(province_id):
		out["observed"] = "Hauptstadt des Zielhauses nicht auswählbar."
		return out
	var opinion_before := int(main.game.opinion[_house_for_secret])
	var claims_before: int = main.game.house()["claims"].size()
	if not await _open_rule():
		out["observed"] = "Herrschaft nicht geöffnet."
		return out
	var ok1 := await _click_button("Geheimnis aufdecken", main.rule_layer)
	await get_tree().create_timer(0.3).timeout
	var ok2 := await _click_button("Geheimnis ausnutzen", main.rule_layer)
	await get_tree().create_timer(0.4).timeout
	var opinion_after := int(main.game.opinion[_house_for_secret])
	var claims_after: int = main.game.house()["claims"].size()
	out["observed"] = "Haus %s: Haltung %d->%d, Ansprüche %d->%d" % [
		str(main.game.houses[_house_for_secret]["name"]), opinion_before, opinion_after, claims_before, claims_after]
	out["pass"] = ok1 and ok2 and opinion_after < opinion_before and claims_after > claims_before
	out["evidence"] = out["observed"]
	return out

func _find_secret_house() -> int:
	var game = main.game
	for i in game.houses.size():
		if i == game.player or i == _target_house:
			continue
		var capital := str(game.houses[i].get("capital", ""))
		if capital == "" or game.has_claim(capital):
			continue
		return i
	return -1

# --- Roundtrip and save evidence ----------------------------------------

func _roundtrip(number: int) -> Dictionary:
	var tags := {1: "04:30", 2: "14:30", 3: "24:30"}
	var out := {"pass": false, "time": _clock(), "target": tags[number], "before": {}, "after": {}, "diff": {}, "save": ""}
	await _close_rule()
	if main.event_layer.visible:
		await _handle_event()
	if not await _click_button("Spiel speichern"):
		out["error"] = "Speichern-Button nicht gefunden."
		return out
	await get_tree().create_timer(0.5).timeout
	out["before"] = _digest()
	var save_name := "roundtrip%d-before.json" % number
	_copy_save(save_name)
	out["save"] = "saves/" + save_name
	if not await _click_button("Spielstand laden"):
		out["error"] = "Laden-Button nicht gefunden."
		return out
	await get_tree().create_timer(0.7).timeout
	out["after"] = _digest()
	out["diff"] = _digest_diff(out["before"], out["after"])
	out["pass"] = out["diff"].is_empty()
	_write_result()
	return out

func _digest() -> Dictionary:
	var game = main.game
	var owned: Array = []
	for p in game.owned():
		owned.append(str(p["id"]))
	owned.sort()
	return {
		"date": game.date_text(), "gold": int(game.house()["gold"]),
		"prestige": int(game.house()["prestige"]), "legitimacy": int(game.house()["legitimacy"]),
		"heir": str(game.house()["heir"]), "succession": str(game.house()["laws"]["succession"]),
		"claims": game.house()["claims"].size(), "armies": game.house()["armies"].size(),
		"owned": owned, "speed": int(game.speed),
	}

func _digest_diff(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for key in before.keys():
		if before[key] != after.get(key):
			out[key] = {"before": before[key], "after": after.get(key)}
	return out

func _save_copy(name: String) -> void:
	await _close_rule()
	if main.event_layer.visible:
		await _handle_event()
	var ok := await _click_button("Spiel speichern")
	await get_tree().create_timer(0.5).timeout
	if ok:
		_copy_save(name)

func _copy_save(name: String) -> bool:
	var source := ProjectSettings.globalize_path("user://spielstand.json")
	if not FileAccess.file_exists(source):
		_log("save missing: " + source)
		return false
	var target := out_dir + "/saves/" + name
	var err := DirAccess.copy_absolute(source, target)
	_log("copy save " + source + " -> " + target + " err=" + str(err))
	return err == OK

# --- Timeline and engine helpers ----------------------------------------

func _elapsed() -> float:
	return float(Time.get_ticks_msec() - run_start_ms) / 1000.0

func _clock() -> String:
	return "%s (%0.1fs)" % [Time.get_time_string_from_system(), _elapsed()]

func _wait_until(seconds: float) -> void:
	if smoke:
		return
	while _elapsed() < seconds:
		await get_tree().create_timer(0.5).timeout

func _advance_months(count: int) -> void:
	var game = main.game
	var target: int = _month_index() + count
	await _set_speed(3)
	var guard := 0
	while _month_index() < target:
		guard += 1
		if game.game_over:
			result["errors"].append("game_over during advance")
			break
		if game.pending_event != null:
			await _set_speed(0)
			await _handle_event()
			await _set_speed(3)
		await get_tree().create_timer(0.05).timeout
		if guard > 6000:
			result["errors"].append("time advance guard")
			break
	await _set_speed(0)

func _ensure_gold(amount: int, max_years: int) -> void:
	for _i in range(max_years):
		if int(main.game.house()["gold"]) >= amount:
			return
		if main.game.game_over:
			return
		await _advance_months(12)
	if int(main.game.house()["gold"]) < amount:
		_log("gold target not reached: %d < %d" % [int(main.game.house()["gold"]), amount])

func _set_speed(value: int) -> void:
	if main.event_layer.visible:
		if main.game.pending_event != null:
			await _handle_event()
		else:
			event_layer_close()
	var label: String = ["Pause", "x1", "x2", "x3"][clampi(value, 0, 3)]
	for _i in range(10):
		if main.game != null and int(main.game.speed) == value:
			return
		if await _click_button(label):
			if int(main.game.speed) == value:
				return
		await get_tree().create_timer(0.15).timeout

func _handle_event() -> void:
	if main.game.pending_event == null:
		if main.event_layer.visible:
			event_layer_close()
		return
	var buttons: Array = []
	for _i in range(20):
		buttons = _buttons(main.event_layer, "")
		if not buttons.is_empty():
			break
		await get_tree().create_timer(0.1).timeout
	if buttons.is_empty():
		result["errors"].append("event without option button")
		return
	var choice: Button = buttons[0]
	var ev = main.game.pending_event
	if ev != null:
		var options: Array = ev.get("options", [])
		var best := 0
		var best_score := -9999
		for i in options.size():
			var effects: Dictionary = options[i].get("effects", {})
			var score: int = int(effects.get("gold", 0)) + 2 * int(effects.get("health", 0))
			if score > best_score:
				best_score = score
				best = i
		if best < buttons.size():
			choice = buttons[best]
	if not is_instance_valid(choice):
		result["errors"].append("event button freed before click")
		return
	_log("event choice: " + choice.text)
	await _ensure_visible(choice)
	if not is_instance_valid(choice) or not main.event_layer.visible:
		return
	await _click_at(choice.get_global_rect().get_center())
	await get_tree().create_timer(0.3).timeout

func event_layer_close() -> void:
	if main.event_layer != null:
		main.event_layer.visible = false

func _month_index() -> int:
	var game = main.game
	return (int(game.year) - (-2000)) * 12 + int(game.month)

func _start_values() -> Dictionary:
	var game = main.game
	return {
		"date": game.date_text(), "gold": int(game.house()["gold"]),
		"prestige": int(game.house()["prestige"]), "legitimacy": int(game.house()["legitimacy"]),
		"heir": str(game.house()["heir"]), "claims": game.house()["claims"].size(),
		"armies": game.house()["armies"].size(), "capital": str(game.house()["capital"]),
	}

func _rule_state() -> Dictionary:
	var game = main.game
	return {
		"succession": str(game.house()["laws"]["succession"]),
		"tax": int(game.house()["laws"]["tax"]),
		"gold": int(game.house()["gold"]),
		"marshal": str(game.council_member(game.player, "marshal").get("name", "")),
		"claims": game.house()["claims"].size(),
		"armies": game.house()["armies"].size(),
	}

func _training_log() -> String:
	for line in main.game.log_lines:
		if str(line).find("trainiert") >= 0:
			return str(line)
	return "kein Trainings-Log"

# --- AI diff -------------------------------------------------------------

func _ai_diff() -> Dictionary:
	var start_path := out_dir + "/saves/ai-start.json"
	var end_path := out_dir + "/saves/ai-end.json"
	var out := {"pass": false, "hits": [], "edges": [], "error": ""}
	if not FileAccess.file_exists(start_path) or not FileAccess.file_exists(end_path):
		out["error"] = "ai-start/ai-end fehlt"
		return out
	var before = JSON.parse_string(FileAccess.get_file_as_string(start_path))
	var after = JSON.parse_string(FileAccess.get_file_as_string(end_path))
	if not (before is Dictionary) or not (after is Dictionary):
		out["error"] = "Save-JSON ungültig"
		return out
	var player := int(before.get("player", 0))
	var bh: Array = before.get("houses", [])
	var ah: Array = after.get("houses", [])
	for i in mini(bh.size(), ah.size()):
		if i == player:
			continue
		var b: Dictionary = bh[i]
		var a: Dictionary = ah[i]
		if int(b.get("laws", {}).get("tax", -1)) != int(a.get("laws", {}).get("tax", -1)):
			out["hits"].append("AI2: Haus %d Steuersatz %d -> %d" % [i, int(b["laws"]["tax"]), int(a["laws"]["tax"])])
		var spouse_before := str(b.get("spouse", {}).get("name", "")) if b.get("spouse", {}) is Dictionary else ""
		var spouse_after := str(a.get("spouse", {}).get("name", "")) if a.get("spouse", {}) is Dictionary else ""
		if spouse_before == "" and spouse_after != "":
			out["hits"].append("AI3: Haus %d hat geheiratet" % i)
	var bp: Array = before.get("provinces", [])
	var ap: Array = after.get("provinces", [])
	for j in mini(bp.size(), ap.size()):
		var bo := int(bp[j].get("owner", -1))
		var eo := int(ap[j].get("owner", -1))
		if bo != eo and bo != player and eo != player:
			out["hits"].append("AI4: Provinz %s Besitzer %d -> %d" % [str(bp[j].get("name", "?")), bo, eo])
	for hit in out["hits"]:
		var prefix := str(hit).split(":")[0]
		if not out["edges"].has(prefix):
			out["edges"].append(prefix)
	out["pass"] = out["edges"].size() >= 2
	return out

# --- Screenshots, status, files -----------------------------------------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := out_dir + "/screens/" + name
	var err := img.save_png(path)
	_log("screenshot " + path + " err=" + str(err))

func _shot_periodic(minutes: int) -> void:
	var path := "win-043-%02d.png" % minutes
	await _shot(path)

func _overall_status() -> String:
	if not result["errors"].is_empty():
		return "DURCHGEFALLEN"
	for key in ["P01", "P02", "P03", "P04", "P05", "P06", "P07", "P08", "P09", "P10", "P11", "P12"]:
		if not result["actions"].has(key) or not bool(result["actions"][key].get("pass", false)):
			return "DURCHGEFALLEN"
	for key in ["1", "2", "3"]:
		if not result["roundtrips"].has(key) or not bool(result["roundtrips"][key].get("pass", false)):
			return "DURCHGEFALLEN"
	if not bool(result["ai"].get("pass", false)):
		return "DURCHGEFALLEN"
	return "BESTANDEN"

func _write_result() -> void:
	var path := out_dir + "/acceptance-result.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, "\t"))
		f.close()
	_log("result written " + path)

func _log(message: String) -> void:
	var line := "%s %s" % [Time.get_time_string_from_system(), message]
	_log_lines.append(line)
	print("ACCEPTANCE ", line)
	var f := FileAccess.open(out_dir + "/acceptance.log", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log_lines) + "\n")
		f.close()
