extends Node
## Real Main, Game and Kernel controls. Funding is a controlled UI fixture.
class ObservedGame extends "res://scripts/Game.gd":
	var trade_calls: Array=[]
	func offer_material_trade(a: String,b: String,hi: int=-1) -> Dictionary:
		trade_calls.append({"id":"offer","from":a,"to":b,"house":hi})
		return super.offer_material_trade(a,b,hi)
	func accept_material_trade(id: int,hi: int=-1) -> Dictionary:
		trade_calls.append({"id":"accept","trade":id,"house":hi})
		return super.accept_material_trade(id,hi)
	func cancel_material_trade(id: int,hi: int=-1) -> Dictionary:
		trade_calls.append({"id":"cancel","trade":id,"house":hi})
		return super.cancel_material_trade(id,hi)

var main
var ui
var inspector
var panel
var game
var source := ""
var target := ""
var remote := ""
var buyer := -1
var _offer_ready := false
var checks := 0
var failures := 0
var mouse_inputs := 0
var touch_inputs := 0
var images: Array=[]

func _ready() -> void:
	main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.settings.autosave=false
	ui=main.get_meta("modern_interface")
	ui.set_appearance(3)
	ui.set_text_scale(1.0)
	ui.set_touch_layout(true)
	inspector=ui.province_inspector
	game=ObservedGame.new(load("res://scripts/GameRegionData.gd"),0)
	game.speed=0
	main.game=game
	main.kernel.bind_game(game)
	main.refresh()
	panel=inspector.get("trade_panel")
	if not check(panel is Control,"An actually possible border sale appears in one embedded compact trade foldout"):
		finish(); return
	find_regions()
	if source.is_empty() or remote.is_empty(): finish(); return
	await test_empty_and_offer()
	if not _offer_ready: finish(); return
	await test_human_confirmation_and_reparenting()
	await test_stale_callbacks()
	await test_touch_and_readability()
	await test_themes()
	finish()

func find_regions() -> void:
	for province in game.provinces:
		if int(province.owner)==0:
			for id in game.neighbours(str(province.id)):
				if int(game.province(str(id)).owner)!=0:
					source=str(province.id); target=str(id); buyer=int(game.province(target).owner); break
		if not source.is_empty(): break
	for province in game.provinces:
		if int(province.owner)!=0 and not game.is_border_province(0,str(province.id)):
			remote=str(province.id); break
	check(not source.is_empty() and not target.is_empty() and not remote.is_empty(),"Controlled UI fixture has a true own/foreign land edge and irrelevant distant foreign region")

func select_region(id: String, section: String) -> void:
	main._on_province_selected(id)
	inspector.show_section(section)
	await settle()

func offer_key() -> String:
	return "offer:"+source+"|"+target

func test_empty_and_offer() -> void:
	await select_region(source,"buildings")
	check(not panel.visible,"Without real free stock, no empty or disabled offer catalogue consumes province space")
	# Controlled stock and NPC funding establish a real lawful first delivery.
	var a: Dictionary=game.province(source)
	a.production.materials_u=game.ProductionScript.stock_capacity_u(a)
	game.houses[buyer].gold=10000
	check(game.start_regional_project(target,"walls",buyer).ok,"Existing NPC construction creates actual material demand")
	check(bool(game.material_trade_preview(source,target).get("ok",false)),"The underlying Game already admits the actual funded border sale before its UI is checked")
	main.refresh()
	await settle()
	check(panel.is_visible_in_tree() and panel.get_parent()==inspector.sections.buildings,"Real own-region opportunity appears inside existing Ausbau")
	check(panel.toggle.text=="Baustoffhandel ▸" and not panel.body.visible,"Relevant trade starts as one closed foldout")
	await tap(panel.toggle)
	if not check(panel.body.visible and panel.action_buttons.has(offer_key()),"Expanding shows the actually admissible source-to-target offer"): return
	_offer_ready=true
	check(panel.action_buttons.size()>0,"At least one real trade intention is available")
	for button in panel.action_buttons.values(): check(not button.disabled,"New-offer rows omit impossible choices instead of filling the list with disabled buttons")
	var row: Dictionary=panel.rows[offer_key()]
	var preview: Dictionary=game.material_trade_preview(source,target)
	check(row.detail.text.contains(str(int(preview.lot_gold))+" Gold") and row.detail.text.contains("Baustoffe") and row.heading.text.contains("→"),"Each offer shows true direction and its one quantity/price quote")
	await reveal(panel.action_buttons[offer_key()])
	await shot("trade-offer")
	var before: Dictionary=game.snapshot()
	var count: int=game.trade_calls.size()
	panel.refresh(game,source)
	await settle()
	check(game.snapshot()==before and game.trade_calls.size()==count,"Refreshing and expanding presentation never mutate or dispatch the game")
	var instance: int=panel.get_instance_id()
	await select_region(target,"achievements")
	check(panel.get_instance_id()==instance and panel.get_parent()==inspector.sections.achievements and panel.is_visible_in_tree(),"The same one panel moves to foreign-region Diplomatie")
	check(not inspector.sections.buildings.visible and not inspector.sections.research.visible and not inspector.action_buttons.research_plan.visible,"Foreign trade adds neither construction nor research administration")
	check(not panel.body.visible,"Changing province closes old trade contents")
	await select_region(remote,"achievements")
	check(not panel.visible,"A distant unrelated foreign province has no trade foldout")

func test_human_confirmation_and_reparenting() -> void:
	check(game.configure_human_houses([0,buyer]),"Two real human houses require a visible counter-confirmation")
	await select_region(source,"buildings")
	await tap(panel.toggle)
	var button: Button=panel.action_buttons[offer_key()]
	var count: int=game.trade_calls.size()
	var stock: int=game.province(source).production.materials_u
	var gold: int=game.house().gold
	await tap(button)
	check(game.trade_calls.size()==count+1 and game.material_trades.size()==1,"Real offer control routes exactly one Game intention through the existing Kernel")
	if game.material_trades.is_empty(): return
	var contract: Dictionary=game.material_trades[0]
	var id: int=contract.id
	check(contract.status=="offered" and contract.accepted_month==-1 and int(game.house().gold)==gold and int(game.province(source).production.materials_u)==stock,"Offer waits for the other human without premature payment or material")
	check(panel.rows.has("contract:"+str(id)) and not panel.action_buttons.has("accept:"+str(id)),"Proposer sees the pending contract, never a self-confirmation button")
	check(game.select_player_context(buyer),"Actual buyer context becomes active")
	main.kernel.bind_game(game)
	await select_region(target,"buildings")
	await tap(panel.toggle)
	check(panel.action_buttons.has("accept:"+str(id)),"Receiving human has a real acceptance action on the same pending contract")
	await tap(panel.action_buttons["accept:"+str(id)])
	check(game.material_trades[0].status=="active" and game.material_trades[0].delivered_lots==0,"Counter-confirmation activates only future paid deliveries")
	check(panel.rows["contract:"+str(id)].state.text.contains("0/3") and panel.rows["contract:"+str(id)].state.text.contains("Monat"),"Active contract shows actual delivered count and remaining time")
	var expected_reason:=""
	for option in game.material_trade_options(target):
		if str(option.kind)=="contract" and int(option.contract.id)==id: expected_reason=str(option.reason)
	var presented: Dictionary=panel.rows["contract:"+str(id)]
	check(not expected_reason.is_empty() and presented.reason.text==expected_reason,"Active delivery forecast comes from the actual Game reason, not a guaranteed or fabricated delivery")
	var repeats:=0
	for label in panel.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and label.text==expected_reason: repeats+=1
	check(repeats==1,"Current delivery reason is shown once across the expanded trade panel")
	game.province(source).siege=10
	game.province(source).siege_owner=buyer
	var blocked_before: Dictionary=game.snapshot()
	main.refresh()
	await settle()
	presented=panel.rows["contract:"+str(id)]
	check(presented.reason.text.contains("Feind") and presented.reason.is_visible_in_tree(),"Actual hostile source explains the paused existing contract without hiding its cancellation")
	check(game.snapshot()==blocked_before and panel.action_buttons.has("cancel:"+str(id)),"Presenting a pause mutates no stock or contract and preserves ending future deliveries")
	game.province(source).siege=0
	game.province(source).siege_owner=-1
	main.refresh()
	check(game.select_player_context(0),"Original seller context is restored")
	main.kernel.bind_game(game)
	await select_region(target,"achievements")
	await tap(panel.toggle)
	check(panel.action_buttons.has("cancel:"+str(id)) and panel.get_parent()==inspector.sections.achievements,"Existing contract can be ended from its foreign endpoint without own administration")
	await tap(panel.action_buttons["cancel:"+str(id)])
	check(game.material_trades.is_empty() and game.province(source).production.materials_u==stock and game.house().gold==gold,"Ending future deliveries preserves the original untransferred goods and money")

func callback(button: Button) -> Callable:
	return button.pressed.get_connections()[0].callable

func test_stale_callbacks() -> void:
	await select_region(source,"buildings")
	if not panel.body.visible: await tap(panel.toggle)
	var obsolete: Callable=callback(panel.action_buttons[offer_key()])
	await select_region(remote,"achievements")
	var before: Dictionary=game.snapshot()
	var count: int=game.trade_calls.size()
	obsolete.call()
	check(game.snapshot()==before and game.trade_calls.size()==count,"A retained callback cannot trade after province selection changes")
	await select_region(source,"buildings")
	await tap(panel.toggle)
	obsolete=callback(panel.action_buttons[offer_key()])
	# Change affordability without telling the UI first: the callback must requery.
	var original_stock: int=game.province(source).production.materials_u
	game.province(source).production.materials_u=0
	before=game.snapshot(); count=game.trade_calls.size()
	obsolete.call()
	check(game.snapshot()==before and game.trade_calls.size()==count,"A stale once-valid offer rechecks actual original stock before dispatch")
	game.province(source).production.materials_u=original_stock
	main.refresh()
	await settle()
	if not panel.body.visible: await tap(panel.toggle)
	obsolete=callback(panel.action_buttons[offer_key()])
	var old_owner: int=game.province(target).owner
	var old_project: Dictionary=game.province(target).regional_project.duplicate(true)
	game.province(target).owner=(old_owner+1)%game.houses.size()
	if int(game.province(target).owner)==0: game.province(target).owner=(old_owner+2)%game.houses.size()
	var new_owner: int=game.province(target).owner
	var new_owner_gold: int=game.houses[new_owner].gold
	game.houses[new_owner].gold=10000
	game.province(target).regional_project.builder=new_owner
	check(bool(game.material_trade_preview(source,target).get("ok",false)),"Changed-owner controlled fixture remains legally funded, so a stale click could otherwise silently replace its counterparty")
	before=game.snapshot(); count=game.trade_calls.size()
	check(not before.is_empty(),"Counterparty-change fixture is a valid complete game state before stale input")
	obsolete.call()
	check(game.snapshot()==before and game.trade_calls.size()==count,"A callback cannot silently replace the agreed counterparty after ownership changes")
	game.province(target).owner=old_owner
	game.province(target).regional_project=old_project
	game.houses[new_owner].gold=new_owner_gold
	main.refresh()
	await settle()
	before=game.snapshot(); count=game.trade_calls.size()
	main._on_province_selected("")
	obsolete.call()
	check(not panel.visible and game.snapshot()==before and game.trade_calls.size()==count,"Empty selection removes the foldout and rejects old offers without log mutations")
	await select_region(source,"buildings")
	await tap(panel.toggle)
	await tap(panel.action_buttons[offer_key()])
	var first: int=game.material_trades[0].id
	obsolete=callback(panel.action_buttons["cancel:"+str(first)])
	check(game.cancel_material_trade(first).ok and game.offer_material_trade(source,target).ok,"Controlled replacement closes the old agreement and creates a different actual monotonic ID")
	var replacement: int=game.material_trades[0].id
	before=game.snapshot(); count=game.trade_calls.size()
	obsolete.call()
	check(replacement!=first and game.snapshot()==before and game.trade_calls.size()==count,"A retained cancellation cannot act on a replacement agreement at the same endpoints")
	await settle()
	if not panel.body.visible: await tap(panel.toggle)
	await tap(panel.action_buttons["cancel:"+str(replacement)])

func test_touch_and_readability() -> void:
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		await select_region(source,"buildings")
		if not panel.body.visible: await tap(panel.toggle)
		check(panel.toggle.custom_minimum_size.y>=44,"Foldout retains a44px touch target at%dpercent" % int(scale*100))
		for row in panel.rows.values():
			for label in [row.heading,row.detail,row.state,row.reason]:
				check(label.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and not label.clip_text,"Trade text wraps without clipping at%dpercent" % int(scale*100))
		for button in panel.action_buttons.values():
			await reveal(button)
			check(button.size.y>=44 and not button.clip_text and button.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"Actual trade button wraps and remains touchable at%dpercent" % int(scale*100))
		var buttons: int=ui._hud_buttons.size()
		for index in 12: panel.refresh(game,source)
		check(ui._hud_buttons.size()==buttons,"Unchanged refreshes retain controls instead of leaking registered touch targets")
		await shot("trade-touch-%d" % int(scale*100))
	ui.set_text_scale(1.0)
	ui.set_touch_layout(false)

func reveal(control: Control) -> void:
	var scroll: Node=control.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	if scroll is ScrollContainer: scroll.ensure_control_visible(control)
	await settle()
	if scroll is ScrollContainer: check(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Actual trade control is reachable inside its existing province scroll viewport")

func test_themes() -> void:
	for theme in [0,1,2,3,4,5]:
		ui.set_appearance(theme)
		main.refresh()
		await select_region(source,"buildings")
		if not panel.body.visible: await tap(panel.toggle)
		check(not panel.action_buttons.is_empty(),"Readability fixture retains an actual available trade after theme%d" % theme)
		for button in panel.action_buttons.values():
			check(button.get_theme_color("font_color").is_equal_approx(ui.readable(ui.TEXT)),"Newly rebuilt trade text follows the selected readable palette in theme%d" % theme)
			await reveal(button)
		await shot("trade-theme-%d" % theme)
	ui.set_appearance(3)

func tap(button: Button) -> void:
	await reveal(button)
	check(button.is_visible_in_tree() and not button.disabled,"Intended trade control is visible and enabled before input")
	if DisplayServer.get_name()=="headless":
		button.pressed.emit()
		await settle()
		return
	var point: Vector2=button.get_viewport().get_screen_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion:=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control()==button,"Transformed real input hits the intended trade control")
	var use_touch: bool=ui.touch_layout and (mouse_inputs+touch_inputs)%2==1
	for down in [true,false]:
		if OS.get_environment("BQ_TRADE_INPUT_DEBUG")=="1": print("TRADE_INPUT mode=",("touch" if use_touch else "mouse")," down=",down," target=",button.text," point=",point," generation=",panel._generation)
		if use_touch:
			var event:=InputEventScreenTouch.new()
			event.index=0; event.position=point; event.pressed=down
			Input.parse_input_event(event)
		else:
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point
			Input.parse_input_event(event)
		await get_tree().process_frame
	if use_touch: touch_inputs+=1
	else: mouse_inputs+=1
	await settle()

func proof_root() -> String:
	var path:=OS.get_environment("BQ_MATERIAL_TRADE_UI_PROOF")
	if path.is_empty(): path=OS.get_environment("BQ_PRODUCTION_PROOF")
	if path.is_empty(): path=ProjectSettings.globalize_path("user://material-trade-ui")
	DirAccess.make_dir_recursive_absolute(path)
	return path

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path:=proof_root().path_join(label+".png")
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"Actual rendered trade frame saved: "+label)
	images.append(path)

func settle() -> void:
	for index in 6: await get_tree().process_frame

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADEUITEST FAIL: "+message)
	return ok

func finish() -> void:
	if DisplayServer.get_name()!="headless":
		check(mouse_inputs>0 and touch_inputs>0,"Window run exercised both actual mouse and screen-touch input")
		var file:=FileAccess.open(proof_root().path_join("ui-result.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"mouse_inputs":mouse_inputs,"touch_inputs":touch_inputs,"images":images,"display_server":DisplayServer.get_name()},"\t",true))
	print("MATERIALTRADEUITEST %s: %d Prüfungen" % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
