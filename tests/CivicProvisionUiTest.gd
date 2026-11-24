extends Node
## Real Main/Game/Kernel integration; missing feature fails as an assertion.
var checks := 0
var failures := 0
var main
var game
var ui
var inspector
var panel
var own_id := ""
var second_id := ""
var foreign_id := ""
var mouse_inputs := 0
var touch_inputs := 0
var images: Array=[]

func _ready() -> void:
	if not check(FileAccess.file_exists("res://scripts/CivicProvisionPanel.gd"),"Own Ausbau contains a compact civilian stock/ration presenter"):
		finish(); return
	var panel_script=load("res://scripts/CivicProvisionPanel.gd")
	if not check(panel_script!=null,"Civilian presenter is a loadable script"): finish(); return
	main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.settings.autosave=false
	game=main.game
	game.speed=0
	ui=main.get_meta("modern_interface")
	ui.set_appearance(3); ui.set_text_scale(1.0); ui.set_touch_layout(true)
	inspector=ui.province_inspector
	panel=inspector.get("civic_panel")
	if not check(panel is Control,"Real province inspector embeds the civilian presenter"): finish(); return
	for province in game.provinces:
		if int(province.owner)==game.player:
			if own_id.is_empty(): own_id=str(province.id)
			elif second_id.is_empty(): second_id=str(province.id)
		elif foreign_id.is_empty(): foreign_id=str(province.id)
	if not check(not own_id.is_empty() and not second_id.is_empty() and not foreign_id.is_empty(),"Unmodified regular start supplies own and foreign UI contexts"): finish(); return
	await test_closed_and_policy()
	await test_stale_intentions()
	await test_readability()
	finish()

func select_region(id: String) -> void:
	main._on_province_selected(id)
	if not id.is_empty() and int(game.province(id).owner)==game.player: inspector.show_section("buildings")
	await settle()

func choose_ration(index: int) -> void:
	panel.ration_picker.select(index)
	panel.ration_picker.item_selected.emit(index)
	await settle()

func callback(button: Button) -> Callable:
	return button.pressed.get_connections()[0].callable

func test_closed_and_policy() -> void:
	await select_region(own_id)
	check(panel.get_parent()==inspector.sections.buildings and panel.is_visible_in_tree(),"Civilian plan stays inside existing own Ausbau with no global administration")
	check(not panel.body.visible and panel.toggle.text.contains("Mon.") and panel.toggle.text.contains("50"),"Closed foldout contains actual stock-months and satisfaction")
	var first: Dictionary=game.provision_preview(own_id)
	check(panel.toggle.text.contains(("%.1f" % float(first.stock_months)).replace(".",",")),"Closed reserve uses authoritative stock-months rather than soldier capacity")
	await tap(panel.toggle)
	check(panel.body.visible and panel.ration_picker.item_count==3,"Single compact plan exposes exactly three ration policies")
	check(not panel.apply_button.visible,"Current ration omits unnecessary Apply button")
	for index in 3: check(str(panel.ration_picker.get_item_metadata(index)) in ["scarce","normal","generous"],"Ration metadata is a defined Game policy")
	var before: Dictionary=game.snapshot()
	await choose_ration(2)
	var preview: Dictionary=game.provision_preview(own_id,"generous")
	check(game.snapshot()==before,"Choosing a preview changes no food, satisfaction, money or log")
	check(panel.apply_button.is_visible_in_tree() and not panel.apply_button.disabled,"Different permitted policy has one enabled confirmation")
	check(panel.plan_label.text.contains("125") and panel.plan_label.text.contains(str(int(preview.next.satisfaction_after))),"Plan names actual ration rate and projected satisfaction")
	check(panel.plan_label.text.contains("Landarbeit") and panel.plan_label.text.contains("Industrie") and panel.plan_label.text.contains("Steuern"),"Civilian preview explains the shared labor and actual tax consequence")
	check(panel.balance_label.text.contains("Erzeugt") and panel.balance_label.text.contains("Verbraucht") and panel.balance_label.text.contains("Überlauf"),"Expandable plan contains a complete monthly quantity balance")
	var old_callback: Callable=callback(panel.apply_button)
	var sender: Button=panel.apply_button
	await tap(sender)
	check(sender.is_inside_tree(),"A pressed sender remains in-tree through successful refresh and native touch release")
	check(str(game.province(own_id).provisioning.rations)=="generous","Actual UI command applies the selected own ration through Kernel")
	var after: Dictionary=game.snapshot()
	var prior: Dictionary=before.provinces.filter(func(p): return str(p.id)==own_id)[0].provisioning
	var actual: Dictionary=game.province(own_id).provisioning
	for key in ["food_u","satisfaction","harvest_carry","ration_carry"]: check(actual[key]==prior[key],"Policy confirmation does not immediately book "+key)
	check(not panel.apply_button.visible,"Successful policy leaves no duplicate current-policy confirmation")
	old_callback.call()
	check(game.snapshot()==after,"Repeated stale pressed callback changes neither state nor log")
	await shot("own-rations-applied")

func test_stale_intentions() -> void:
	await choose_ration(0)
	var obsolete: Callable=callback(panel.apply_button)
	await select_region(second_id)
	var before: Dictionary=game.snapshot()
	obsolete.call()
	check(game.snapshot()==before,"Old selection callback cannot apply rations to a newly selected own province")
	await select_region(own_id)
	await tap(panel.toggle)
	await choose_ration(0)
	obsolete=callback(panel.apply_button)
	await select_region(foreign_id)
	before=game.snapshot(); obsolete.call()
	check(not panel.visible and not panel.body.visible and game.snapshot()==before,"Foreign land hides stocks and rejects retained administration input")
	await shot("foreign-no-civilian-admin")
	await select_region(own_id)
	await tap(panel.toggle)
	await choose_ration(0)
	obsolete=callback(panel.apply_button)
	var owner: int=game.province(own_id).owner
	game.province(own_id).owner=int(game.province(foreign_id).owner)
	before=game.snapshot(); obsolete.call()
	check(not panel.visible and game.snapshot()==before,"Unannounced owner change is rechecked before any Kernel mutation")
	game.province(own_id).owner=owner
	await select_region(own_id)
	await tap(panel.toggle)
	await choose_ration(0)
	obsolete=callback(panel.apply_button)
	check(game.set_province_rations(own_id,"normal").ok,"Controlled same-month external policy change is legal")
	before=game.snapshot(); obsolete.call()
	check(game.snapshot()==before,"Same-month policy change invalidates the old proposed confirmation")
	main.refresh(); await settle()
	if not panel.body.visible: await tap(panel.toggle)
	await choose_ration(2)
	obsolete=callback(panel.apply_button)
	await select_region("")
	before=game.snapshot(); obsolete.call()
	check(not panel.visible and game.snapshot()==before,"Empty selection removes own controls and leaves state/log unchanged")
	await select_region(own_id)
	await tap(panel.toggle)
	await choose_ration(2)
	obsolete=callback(panel.apply_button)
	game.game_over=true
	before=game.snapshot(); obsolete.call()
	check(game.snapshot()==before and panel.apply_button.disabled,"End-of-game stale input fails closed")
	game.game_over=false; main.refresh(); await settle()

func test_readability() -> void:
	for theme in 6:
		ui.set_appearance(theme)
		for scale in [1.0,2.0]:
			ui.set_text_scale(scale); ui.set_touch_layout(true)
			await select_region(own_id)
			if not panel.body.visible: await tap(panel.toggle)
			await choose_ration(2)
			var count: int=ui._hud_buttons.size()
			for index in 8: panel.refresh(game,own_id)
			check(ui._hud_buttons.size()==count,"Repeated refresh retains bounded registered controls")
			for control in [panel.toggle,panel.ration_picker,panel.apply_button]:
				await reveal(control)
				check(control.size.y>=44,"Actual ration control has a44px touch target at theme%d/%d%%" % [theme,int(scale*100)])
				check(control.get_theme_color("font_color").is_equal_approx(ui.readable(ui.TEXT)),"Ration control follows current readable palette at theme%d/%d%%" % [theme,int(scale*100)])
			for label in [panel.plan_label,panel.balance_label,panel.status_label]:
				check(label.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and not label.clip_text,"Civilian explanation wraps without clipping at200percent")
			if theme in [1,2,3] and (scale==2.0 or theme==3): await shot("rations-theme-%d-scale-%d" % [theme,int(scale*100)])
	ui.set_appearance(3); ui.set_text_scale(1.0)

func reveal(control: Control) -> void:
	var scroll: Node=control.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	if scroll is ScrollContainer: scroll.ensure_control_visible(control)
	await settle()
	if scroll is ScrollContainer: check(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Ration control is reachable inside existing province scroll")

func tap(button: Button) -> void:
	await reveal(button)
	check(button.is_visible_in_tree() and not button.disabled,"Intended civilian control is visible and enabled")
	if DisplayServer.get_name()=="headless": button.pressed.emit(); await settle(); return
	var point: Vector2=button.get_viewport().get_screen_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
	var use_touch: bool=(mouse_inputs+touch_inputs)%2==1
	var motion:=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	Input.parse_input_event(motion); await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control()==button,"Actual transformed input hits the intended civilian control")
	for down in [true,false]:
		if use_touch:
			var event:=InputEventScreenTouch.new()
			event.index=0; event.position=point; event.pressed=down; Input.parse_input_event(event)
		else:
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point; Input.parse_input_event(event)
		await get_tree().process_frame
	if use_touch: touch_inputs+=1
	else: mouse_inputs+=1
	await settle()

func settle() -> void:
	for index in 6: await get_tree().process_frame

func proof_root() -> String:
	var path:=OS.get_environment("BQ_CIVIC_UI_PROOF")
	if path.is_empty(): path=ProjectSettings.globalize_path("user://civilian-ui")
	DirAccess.make_dir_recursive_absolute(path)
	return path

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path:=proof_root().path_join(label+".png")
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"Saved actual civilian UI frame: "+label)
	images.append(path)

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("CIVICPROVISIONUITEST FAIL: "+message)
	return ok

func finish() -> void:
	if DisplayServer.get_name()!="headless":
		check(mouse_inputs>0 and touch_inputs>0,"Rendered run exercised actual mouse and screen-touch controls")
		var file:=FileAccess.open(proof_root().path_join("ui-result.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"mouse_inputs":mouse_inputs,"touch_inputs":touch_inputs,"images":images,"display_server":DisplayServer.get_name()},"\t",true))
	print("CIVICPROVISIONUITEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
