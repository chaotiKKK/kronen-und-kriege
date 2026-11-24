extends Node
## Normal-budget Main journey. No subclasses, gifted resources or NPC changes.
## Selection uses Main's normal selection handler; it is not a map-hit test.
## Renderer runs use real alternating mouse/touch input. Headless proves only
## callbacks, accounting and layout geometry, never actual input or rendering.
const GameScript = preload("res://scripts/Game.gd")
const SaveScript = preload("res://scripts/SaveGame.gd")
const CAMPAIGN_SEED := 20261118
const SOURCE := "germanien__09"
var main
var game
var ui
var inspector
var panel
var target := ""
var contract_id := -1
var checks := 0
var failures := 0
var mouse_inputs := 0
var touch_inputs := 0
var headless_callbacks := 0
var images: Array = []
var actions: Array = []
var delivery: Dictionary = {}
var quote: Dictionary = {}
var before_delivery: Dictionary = {}
var buyer_production: Dictionary = {}
var original_buyer_project: Dictionary = {}
var proof_dir := ""

func _ready() -> void:
	proof_dir=OS.get_environment("BQ_MATERIAL_TRADE_REGULAR_UI_PROOF")
	if proof_dir.is_empty(): proof_dir=OS.get_environment("BQ_PRODUCTION_PROOF")
	if proof_dir.is_empty(): proof_dir=ProjectSettings.globalize_path("user://material-trade-regular-ui")
	DirAccess.make_dir_recursive_absolute(proof_dir)
	main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await settle()
	# Main is fully ready before establishing the exact normal campaign RNG.
	seed(CAMPAIGN_SEED)
	main._start(0)
	game=main.game
	game.speed=0
	main.settings.autosave=false
	ui=main.get_meta("modern_interface")
	ui.set_appearance(3)
	ui.set_text_scale(1.0)
	ui.set_touch_layout(true)
	inspector=ui.province_inspector
	panel=inspector.trade_panel
	await settle()
	check(game.get_script()==GameScript,"Main uses the original unmodified Game class, without an observation mock")
	check(game.player==0 and game.calendar_index()==0 and game.provinces.size()==108 and game.houses.size()==9 and game.house().gold==140,"Normal new game retains house0, all108 regions, all9 houses and original140Gold")
	check(game.provinces.all(func(p): return int(p.production.materials_u)==0 and p.regional_project.is_empty()),"Every stock and project begins at its untouched normal empty state")
	check(game.house().research.known.is_empty() and game.house().armies.is_empty(),"No research or army gifts precede the ordinary player decisions")
	check(not main._lan_active(),"Singleplayer keeps the ordinary NPC decision makers active")
	write_state("normal-start")
	await select_source()
	check(str(game.province(SOURCE).name)=="Lublin" and int(game.province(SOURCE).owner)==0,"The legitimately selected exporter is owned Lublin")
	check(not panel.visible,"No empty trade catalogue is shown before the exporter has goods")
	var workshops_index := -1
	for index in inspector.focus_picker.item_count:
		if str(inspector.focus_picker.get_item_metadata(index))=="workshops": workshops_index=index
	if not check(workshops_index>=0,"The normal focus selector offers workshops"): finish(); return
	var initial: Dictionary=game.snapshot()
	inspector.focus_picker.select(workshops_index)
	inspector.focus_picker.item_selected.emit(workshops_index)
	await settle()
	check(SaveScript.state_equal(initial,game.snapshot()),"Selecting the workshop preview changes no authoritative state")
	var focus_button: Button=inspector.action_buttons.province_focus
	check(focus_button.text=="Wechseln · 3 Gold","Lublin's actual workshop decision costs3Gold")
	await tap(focus_button)
	if not check(str(game.province(SOURCE).economic_focus)=="workshops" and int(game.house().gold)==137,"Real paid-focus control spends exactly3 of the original140Gold"): finish(); return
	actions.append({"month":0,"action":"paid_workshops_ui","paid_gold":3,"selection":"Main._on_province_selected normal selection setup; no map-click claim"})
	write_state("after-paid-workshops")
	for step in 4: await advance_regular_month(step)
	if not check(game.calendar_index()==4,"Four seeded legal world steps reach month4 without bypassing NPCs"): finish(); return
	for option in game.material_trade_options(SOURCE):
		if str(option.kind)!="offer" or str(option.from)!=SOURCE or not bool(option.preview.ok): continue
		var p: Dictionary=game.province(str(option.to))
		if game.is_human_house(int(p.owner)) or p.regional_project.is_empty(): continue
		target=str(option.to)
		quote=option.preview.duplicate(true)
		original_buyer_project=p.regional_project.duplicate(true)
		break
	if not check(not target.is_empty(),"Month4 offers an actually funded sale of own production to a real NPC construction project"): finish(); return
	check(int(quote.lot_gold)==1 and int(quote.lot_u)>0,"The naturally affordable normal-budget quote charges1Gold for one whole lot")
	await select_source()
	if not check(panel.is_visible_in_tree() and panel.get_parent()==inspector.sections.buildings,"The real normal-budget opportunity appears inside existing Ausbau"): finish(); return
	await tap(panel.toggle)
	var offer_key:="offer:"+SOURCE+"|"+target
	if not check(panel.body.visible and panel.action_buttons.has(offer_key),"The real foldout exposes this actual sale action"): finish(); return
	await capture_scales("normal-offer",offer_key)
	var offered_from: Dictionary=game.snapshot()
	var old_serial: int=game.trade_serial
	await tap(panel.action_buttons[offer_key])
	contract_id=int(game.trade_serial)
	var contract:=find_contract()
	if not check(contract_id==old_serial+1 and not contract.is_empty(),"The offer button dispatches exactly one genuine monotonic contract"): finish(); return
	check(str(contract.status)=="active" and int(contract.buyer)==int(game.province(target).owner) and not game.is_human_house(int(contract.buyer)),"The real NPC approves its funded project purchase through ordinary rules")
	check(int(contract.delivered_lots)==0 and int(contract.accepted_month)==4,"Acceptance schedules future deliveries without delivering on the offer click")
	var offered_to: Dictionary=game.snapshot()
	check(SaveScript.state_equal({"houses":offered_to.houses,"provinces":offered_to.provinces},{"houses":offered_from.houses,"provinces":offered_from.provinces}),"Contract creation transfers no advance gold, goods, ownership or research")
	actions.append({"month":4,"action":"offer_ui","from":SOURCE,"to":target,"quote":quote.duplicate(true),"contract":contract.duplicate(true),"buyer_project":original_buyer_project.duplicate(true)})
	write_state("accepted-no-prepayment")
	await capture_scales("normal-active","contract:"+str(contract_id))
	before_delivery=game.snapshot()
	write_json("before-delivery.json",before_delivery)
	await advance_regular_month(4)
	for row in game._last_material_trade.get("deliveries",[]):
		if int(row.trade_id)==contract_id: delivery=row.duplicate(true)
	if not check(not delivery.is_empty(),"Month5 actually delivers the accepted normal-budget contract"): finish(); return
	check(int(delivery.gold)==1 and int(delivery.amount_u)==int(quote.lot_u) and str(delivery.from)==SOURCE and str(delivery.to)==target,"The actual full charge uses the displayed original endpoints, whole lot and1Gold price")
	var buyer: int=int(delivery.buyer)
	var stock_deltas: Dictionary=game._last_material_trade.stock_deltas
	var gold_deltas: Dictionary=game._last_material_trade.gold_deltas
	check(int(stock_deltas.get(SOURCE,0))==-int(delivery.amount_u) and int(gold_deltas.get("0",0))==1,"The human exporter really loses its lot and earns exactly1Gold in the trade ledger")
	check(int(stock_deltas.get(target,0))>=int(delivery.amount_u) and int(gold_deltas.get(str(buyer),0))<=-1,"The buyer is charged and its receiving stock records the delivered whole lot")
	var material_total:=0
	var gold_total:=0
	for value in stock_deltas.values(): material_total+=int(value)
	for value in gold_deltas.values(): gold_total+=int(value)
	check(material_total==0 and gold_total==0,"All simultaneous normal NPC trades conserve world material and gold")
	for id in [SOURCE,target]:
		var old: Dictionary=find_province(before_delivery.provinces,id)
		var ledger: Dictionary=game._last_production.get("regions",{}).get(id,{})
		check(not ledger.is_empty() and int(ledger.before_u)==int(old.production.materials_u)+int(stock_deltas.get(id,0)),"Actual production at%s begins with old stock plus recorded trade delta" % id)
	buyer_production=game._last_production.get("regions",{}).get(target,{}).duplicate(true)
	check(int(buyer_production.get("used_u",0))>0 and int(buyer_production.get("work_u",0))>0,"The funded NPC buyer really uses material for normal construction work in the delivery month")
	var after_project: Dictionary=game.province(target).regional_project
	var completed_level: int=game.province(target).buildings.get(str(original_buyer_project.kind),0)
	check((not after_project.is_empty() and int(after_project.id)==int(original_buyer_project.id) and int(after_project.work_done_u)>int(original_buyer_project.work_done_u)) or completed_level>=int(original_buyer_project.target_level),"The same legitimate NPC project progresses or completes after receiving goods")
	contract=find_contract()
	check(not contract.is_empty() and int(contract.delivered_lots)==1,"The same active contract visibly records exactly1of3 real deliveries")
	check(game.houses.size()==9 and game.provinces.size()==108 and game.player==0 and game.human_houses.is_empty(),"No NPC is removed, disabled, converted to human or replaced during the journey")
	check(SaveScript.validate(game.snapshot()).is_empty(),"The actual post-delivery world remains a valid current save")
	write_state("after-delivery")
	await select_source()
	await capture_scales("normal-delivered","contract:"+str(contract_id))
	finish()

func select_source() -> void:
	# Selection setup follows Main/Kernel exactly; this suite isolates paid GUI
	# decisions and makes no claim that a geographic map click was tested.
	main._on_province_selected(SOURCE)
	inspector.show_section("buildings")
	await settle()
	check(main.selected==SOURCE and inspector.selected_id==SOURCE,"Main and province inspector agree on the real selected Lublin context")

func advance_regular_month(step: int) -> void:
	if not check(game.pending_event==null,"No outstanding event is bypassed before legal month%d" % (step+1)): return
	seed(CAMPAIGN_SEED+(step+1)*7919)
	game.advance_month()
	main.refresh()
	await settle()
	check(game.calendar_index()==step+1 and game.speed==0,"Legal month%d advances the ordinary paused world exactly once" % (step+1))
	write_state("month-%d" % (step+1))
	if game.pending_event!=null:
		main._show_event(false)
		await settle()
		var chosen: Button=null
		if game.event_decline_reason().is_empty():
			for row in main.event_buttons.get_children():
				var candidate: Button=row.get_child(0)
				if not candidate.disabled and candidate.text.begins_with("Derzeit ablehnen"): chosen=candidate; break
		else:
			for row in main.event_buttons.get_children():
				var candidate: Button=row.get_child(0)
				if not candidate.disabled: chosen=candidate; break
		if check(chosen!=null,"A pending event is answered only by an actually legal event UI control"):
			actions.append({"month":game.calendar_index(),"action":"ordinary_event_ui","event":str(game.pending_event.id),"button":chosen.accessibility_name})
			await tap(chosen)
			check(game.pending_event==null,"The real event UI resolves its pending ordinary choice")

func capture_scales(label: String,key: String) -> void:
	for scale in [1.0,2.0]:
		ui.set_text_scale(scale)
		main.refresh()
		await settle()
		# Exercise reachable collapse/expand controls at both text sizes. Actual
		# renderer taps alternate mouse/touch; no authoritative state changes.
		if panel.body.visible: await tap(panel.toggle)
		await tap(panel.toggle)
		check(panel.body.visible,"The normal trade foldout responds at%dpercent" % int(scale*100))
		if not check(panel.rows.has(key),"The actual%s row remains present at%dpercent" % [label,int(scale*100)]): continue
		var row: Dictionary=panel.rows[key]
		for text in [row.heading,row.detail,row.state,row.reason]:
			check(text.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and not text.clip_text,"Normal-budget trade text wraps without clipping at%dpercent" % int(scale*100))
		check(panel.toggle.custom_minimum_size.y>=44,"The compact trade foldout retains its44px touch target at%dpercent" % int(scale*100))
		var button: Button=panel.action_buttons[key] if key.begins_with("offer:") else panel.action_buttons.get("cancel:"+str(contract_id))
		if check(button!=null,"The actual%s row retains its reachable action" % label):
			await reveal(button)
			check(button.size.y>=44 and not button.clip_text,"The real action stays readable and touch-sized at%dpercent" % int(scale*100))
			await shot(label+"-%d" % int(scale*100))
		if label=="normal-delivered": check(row.state.text.contains("1/3"),"Actual delivered progress is displayed at%dpercent" % int(scale*100))
	ui.set_text_scale(1.0)
	main.refresh()
	await settle()

func reveal(control: Control) -> void:
	var scroll: Node=control.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	if scroll is ScrollContainer: scroll.ensure_control_visible(control)
	await settle()
	if scroll is ScrollContainer: check(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"The intended real control fits in the existing scroll viewport")

func tap(button: Button) -> void:
	await reveal(button)
	if not check(button.is_visible_in_tree() and not button.disabled,"The intended ordinary GUI action is visible and enabled before input"): return
	if DisplayServer.get_name()=="headless":
		headless_callbacks+=1
		button.pressed.emit()
		await settle()
		return
	var point: Vector2=button.get_viewport().get_screen_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion:=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	if not check(get_viewport().gui_get_hovered_control()==button,"Transformed actual input hits the intended ordinary action"): return
	var use_touch: bool=(mouse_inputs+touch_inputs)%2==1
	for down in [true,false]:
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

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path:=proof_dir.path_join(label+".png")
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"Actual normal-budget rendered frame saved: "+label)
	images.append(path)

func find_contract() -> Dictionary:
	for contract in game.material_trades:
		if int(contract.id)==contract_id: return contract
	return {}

func find_province(provinces: Array,id: String) -> Dictionary:
	for province in provinces:
		if str(province.id)==id: return province
	return {}

func write_state(label: String) -> void:
	write_json(label+"-state.json",game.snapshot())

func write_json(label: String,data: Dictionary) -> void:
	var file:=FileAccess.open(proof_dir.path_join(label),FileAccess.WRITE)
	if file==null:
		check(false,"Proof can be written: "+label)
		return
	file.store_string(JSON.stringify(data,"\t",true))
	file.close()

func settle() -> void:
	for frame in 6: await get_tree().process_frame

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADEREGULARUITEST FAIL: "+message)
	return ok

func finish() -> void:
	if DisplayServer.get_name()!="headless": check(mouse_inputs>0 and touch_inputs>0,"The renderer journey exercised actual mouse and screen-touch decisions")
	var result: Dictionary={"passed":failures==0,"checks":checks,"failures":failures,"display_server":DisplayServer.get_name(),"seed":CAMPAIGN_SEED,"source":SOURCE,"target":target,"contract_id":contract_id,"actions":actions,"delivery":delivery,"buyer_production":buyer_production,"images":images,"mouse_inputs":mouse_inputs,"touch_inputs":touch_inputs,"headless_callbacks":headless_callbacks,"normal_budget":true,"resource_or_owner_injection":false,"all_npcs_active":true,"selection_setup":"Main._on_province_selected; not an actual map click","headless_limit":"Callbacks, accounting and geometry only; actual input/rendering requires the windowed run."}
	write_json("regular-ui-result.json",result)
	print("MATERIALTRADEREGULARUITEST "+JSON.stringify(result))
	print("MATERIALTRADEREGULARUITEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
