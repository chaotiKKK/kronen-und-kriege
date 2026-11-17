extends SceneTree
## External release probe: launch the exported EXE with --script <this file> -- <absolute output directory>.
## Every game resource is loaded from the EXE's PCK. Mutations use an isolated test game only.
var main
var ui
var output := ""
var results: Array = []
var screenshots: Array = []
var failures := 0
var started := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not str(args[0]).is_absolute_path():
		push_error("An absolute output directory is required after --.")
		quit(2)
		return
	output = str(args[0]).replace("\\", "/")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create release-probe output directory: " + output)
		quit(2)
		return
	seed(1901)
	var scene = load("res://scenes/Main.tscn")
	if not _check(scene is PackedScene, "Embedded Main scene loads"):
		_finish()
		return
	main = scene.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames()
	main._start(0)
	main.game.speed = 0
	main.game.house().gold = 1000
	ui = main.get_meta("modern_interface")
	ui.set_text_scale(1.0)
	main.refresh()
	await _frames()
	_check(str(ProjectSettings.get_setting("application/config/version")) == "1.9.1", "Embedded version is 1.9.1")
	_check(main.game.provinces.size() == 108, "Regular game has 108 provinces")
	var province: Dictionary = main.game.owned()[0]
	ui.show_section("family")
	main._on_province_selected(str(province.id))
	await _frames()
	var inspector = ui.province_inspector
	_check(main.side_panel.visible and ui.current_section == "overview", "Single province selection opens the right inspector")
	_check(inspector.selected_id == str(province.id), "Inspector shows the selected province")
	for section in ["buildings", "army", "research", "achievements"]:
		_check(inspector.section_buttons.has(section), "Province section exists: " + section)
	await _shot("province-inspector-100")
	await _research()
	await _court()
	await _designer()
	ui.set_text_scale(1.0)
	main.game.speed = 0
	main.refresh()
	_finish()

func _research() -> void:
	ui.set_text_scale(1.0)
	main._show_infrastructure()
	main.refresh()
	await _frames()
	var panel = main.get_meta("research_panel")
	_check(panel.cards.size() == 16 and main.research_buttons.size() == 16, "Packaged research has 16 actual cards and buttons")
	_check(panel.prerequisite_labels.crop_rotation.text.contains("Vermessung"), "Research explains the named prerequisite")
	_check(main.research_buttons.crop_rotation.disabled, "Unavailable crop rotation is disabled")
	panel.set_branch("Militär")
	var shown := 0
	for card in panel.cards.values():
		if card.visible:
			shown += 1
			_check(str(card.get_meta("research_branch")) == "Militär", "Military filter contains only military cards")
	_check(shown == 4, "Military filter displays exactly four innovations")
	panel.set_branch("Alle")
	var button: Button = main.research_buttons.surveying
	var identity := button.get_instance_id()
	var before: int = main.game.house().gold
	_check(not button.disabled, "Actual surveying button is enabled")
	button.pressed.emit()
	await _frames()
	_check(int(main.game.house().gold) == before - 20 and str(main.game.house().research.active) == "surveying", "Research button deducts 20 gold and starts surveying")
	_check(main.research_buttons.surveying.get_instance_id() == identity, "Research refresh retains the actual button")
	_check(panel.progress_bar.visible and is_zero_approx(panel.progress_bar.value), "Initial progress uses the actual zero completed months")
	_check(panel.status_label.text.contains("Vermessung"), "Research result is visible")
	await _shot("research-100")
	ui.set_text_scale(2.0)
	main.refresh()
	await _frames()
	var scroll: ScrollContainer = main.infrastructure_body.get_parent()
	_check(_can_scroll(scroll), "Research scrolls at 200 percent text scale")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames()
	_check(scroll.scroll_vertical > 0, "Research bottom is reachable by scrolling at 200 percent")
	await _shot("research-200-scrolled")
	main._hide_infrastructure()

func _court() -> void:
	ui.set_text_scale(1.0)
	main._show_court()
	main.refresh()
	await _frames()
	var panel = main.get_meta("court_management")
	var button: Button = panel.action_buttons.court
	var identity := button.get_instance_id()
	var gold: int = main.game.house().gold
	var prestige: int = main.game.house().prestige
	var grandeur: int = main.game.court_grandeur()
	_check(not button.disabled, "Actual court action is available")
	button.pressed.emit()
	await _frames()
	_check(int(main.game.house().gold) == gold - 40 and int(main.game.house().prestige) == prestige + 12, "Court action deducts 40 gold once and grants 12 prestige")
	_check(main.game.court_grandeur() == grandeur, "Court action matches its unchanged grandeur description")
	_check(panel.action_buttons.court.get_instance_id() == identity, "Court refresh retains the same action button")
	_check(panel.status_label.text.contains("Prestige"), "Court result is visibly reported")
	_check(not main.court_body.is_ancestor_of(panel.status_label), "Court feedback stays outside the scrolling action list")
	await _shot("court-100")
	ui.set_text_scale(2.0)
	main.refresh()
	await _frames()
	var close: Button = main.court_title.get_parent().get_child(1)
	_check(_within_viewport(close), "Court close button remains reachable at 200 percent")
	_check(_within_viewport(panel.status_label), "Court result remains inside the viewport at 200 percent")
	var scroll: ScrollContainer = main.court_body.get_parent()
	_check(_can_scroll(scroll), "Court actions scroll at 200 percent")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames()
	_check(scroll.scroll_vertical > 0, "Last court actions are reachable by scrolling at 200 percent")
	await _shot("court-200-scrolled")
	main._hide_court()

func _designer() -> void:
	ui.set_text_scale(1.0)
	main.refresh()
	var before: String = main.LanSessionScript.Protocol.world_hash(main.game.snapshot())
	main._show_house_designer()
	await _frames()
	var designer = main.get_meta("singleplayer_designer")
	if not _check(is_instance_valid(designer), "Packaged shared house designer opens"):
		return
	_check(main.kernel.top_modal() == "house_designer", "House designer owns the modal")
	_check(_within_viewport(designer.apply_button) and _within_viewport(designer.cancel_button), "House designer footer is reachable at 100 percent")
	await _shot("house-designer-100")
	ui.set_text_scale(2.0)
	main.refresh()
	await _frames()
	_check(_within_viewport(designer.apply_button) and _within_viewport(designer.cancel_button), "House designer footer is reachable at 200 percent")
	_check(designer.fields.age.get_line_edit().get_theme_font_size("font_size") == 28, "Numeric designer values use 28 px at 200 percent")
	var caption: Label = null
	for label in designer.find_children("*", "Label", true, false):
		if label.text in ["Armeedoktrin", "Doktrin"]: caption = label
	_check(caption != null and caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x <= caption.size.x, "Doctrine caption fits one line at 200 percent")
	_check(_can_scroll(designer.scroll), "House designer form scrolls at 200 percent")
	designer.scroll.scroll_vertical = int(designer.scroll.get_v_scroll_bar().max_value)
	await _frames()
	_check(designer.scroll.scroll_vertical > 0, "Final house and army fields are reachable by scrolling at 200 percent")
	await _shot("house-designer-200-scrolled")
	designer.cancel_button.pressed.emit()
	await _frames()
	_check(main.kernel.top_modal() != "house_designer", "Cancel closes the designer safely")
	_check(main.LanSessionScript.Protocol.world_hash(main.game.snapshot()) == before, "Opening and cancelling the house designer leaves the world unchanged")

func _within_viewport(control: Control) -> bool:
	var area := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var bounds := control.get_global_rect()
	return control.is_visible_in_tree() and bounds.size.x > 0 and bounds.size.y > 0 and area.grow(1).encloses(bounds)

func _can_scroll(scroll: ScrollContainer) -> bool:
	return scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 1

func _frames() -> void:
	for frame in 6:
		await process_frame

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "A rendered viewport is required for screenshot: " + name)
		return
	await RenderingServer.frame_post_draw
	var path := output.path_join(name + ".png")
	var error := root.get_texture().get_image().save_png(path)
	_check(error == OK, "Screenshot saved: " + name)
	if error == OK: screenshots.append(path)

func _check(ok: bool, label: String) -> bool:
	results.append({"ok":ok,"label":label})
	if not ok:
		failures += 1
		print("STRATEGY_RELEASE FAIL: " + label)
	return ok

func _finish() -> void:
	var report := {"version":str(ProjectSettings.get_setting("application/config/version")),"engine":Engine.get_version_info().string,"checks":results.size(),"failures":failures,"passed":failures == 0,"elapsed_ms":Time.get_ticks_msec()-started,"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"results":results,"screenshots":screenshots,"scope":"Exported Windows PCK and real UI commands; isolated fixture, no physical Android/WLAN claim"}
	var file := FileAccess.open(output.path_join("strategy-ui-result.json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write strategy-ui-result.json")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	print("STRATEGY_RELEASE %s: %d checks, %d failures" % ["OK" if failures == 0 else "FAIL",results.size(),failures])
	quit(0 if failures == 0 else 1)
