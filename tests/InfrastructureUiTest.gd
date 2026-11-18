extends Node
## Actual research and Ausbau controls; empty-stock fixture proves finite road work.
var main
var checks := 0
var failures := 0

func _ready() -> void:
	main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(0)
	main.game.speed=0
	main.settings.autosave=false
	main.game.house().gold=500 # Existing controlled affordability fixture.
	main.refresh()
	main._show_infrastructure()
	_check(main.infrastructure_layer.visible,"Shared research plan is visible")
	var button: Button=main.research_buttons.surveying
	_check(not button.disabled,"Surveying is legally available")
	await tap(button)
	_check(main.game.house().research.active=="surveying" and int(main.game.house().research.months)==4,"Actual surveying button starts the defined four-month research")
	main._hide_infrastructure()
	for month in 4: await month_step()
	_check(main.game.house().research.known.has("surveying"),"Four actual months complete surveying")
	main._show_infrastructure()
	await tap(main.research_buttons.road_building)
	_check(main.game.house().research.active=="road_building" and int(main.game.house().research.months)==6,"Actual road-building button starts the defined six-month research")
	main._hide_infrastructure()
	for month in 6: await month_step()
	_check(main.game.house().research.known.has("road_building"),"Six actual months unlock road construction")
	var a: String=main.game.house().capital
	var b: String=str(main.game.neighbours(a)[0])
	main.game.province(b).owner=main.game.player # Controlled neighboring ownership, no material gift.
	for id in [a,b]: main.game.province(id).production.materials_u=0
	main._on_province_selected(a)
	var inspector=main.get_meta("modern_interface").province_inspector
	inspector.show_section("buildings")
	await settle()
	_check(inspector.sections.buildings.is_ancestor_of(main.road_buttons) and not main.infrastructure_body.is_ancestor_of(main.road_buttons),"Actual local road controls belong to Ausbau instead of duplicate research content")
	await tap(inspector.action_buttons.roads_toggle)
	var road_button: Button
	for child in main.road_buttons.find_children("*","Button",true,false):
		if str(child.get_meta("to",""))==b and child.is_visible_in_tree(): road_button=child; break
	if not _check(road_button!=null and not road_button.disabled,"Expanded actual Ausbau offers the legal neighbor road"):
		_finish(); return
	var price: int=main.game.road_preview(a,b).gold
	var gold: int=main.game.house().gold
	var roads_before: int=main.game.roads.size()
	await tap(road_button)
	var road: Dictionary={}
	for candidate in main.game.roads:
		if [str(candidate.from),str(candidate.to)].has(a) and [str(candidate.from),str(candidate.to)].has(b): road=candidate; break
	if not _check(not road.is_empty() and main.game.roads.size()==roads_before+1 and int(main.game.house().gold)==gold-price,"Actual road input creates exactly one paid road project"):
		_finish(); return
	_check(str(road.state)=="building" and not road.construction.is_empty(),"New road begins with real two-end construction instead of instant transport")
	for month in 3: await month_step()
	_check(str(road.state)=="building" and not road.get("construction",{}).is_empty(),"An empty-stock road cannot complete from the old three-month timer")
	if not road.get("construction",{}).is_empty():
		_check(road.construction.legs.any(func(leg):return int(leg.work_done_u)>0 and int(leg.material_spent_u)>0),"Real local production supplies measurable road work and consumed material")
	var months:=3
	while str(road.state)!="complete" and months<64:
		await month_step(); months+=1
	_check(str(road.state)=="complete" and road.construction.is_empty() and months>3,"Actual finite production and shared work finish both road ends")
	main.refresh()
	var segments: Array=main.map_view.infrastructure_segments().filter(func(item):return [str(item.from),str(item.to)].has(a) and [str(item.from),str(item.to)].has(b))
	_check(segments.size()==1 and str(segments[0].state)=="complete","Real completed connection appears exactly once in cached map segments")
	main.game.year=2200; main.game.month=12
	main.refresh(); main._show_infrastructure()
	_check(main.sandbox_button.visible,"Sandbox continuation remains available at campaign end")
	await tap(main.sandbox_button)
	_check(main.game.campaign_sandbox,"Actual sandbox control changes the existing campaign")
	main.game.year=-1999; main.game.month=10
	main._hide_infrastructure()
	main._on_province_selected(a)
	inspector.show_section("buildings")
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var proof:=OS.get_environment("BQ_PRODUCTION_PROOF")
		if proof.is_empty(): proof=ProjectSettings.globalize_path("user://infrastructure-ui")
		DirAccess.make_dir_recursive_absolute(proof)
		_check(get_viewport().get_texture().get_image().save_png(proof.path_join("infrastructure-road.png"))==OK,"Actual shared-view road renderer evidence saved")
	_finish()

func month_step() -> void:
	main.game.advance_month()
	main.refresh()
	await settle()
	if main.game.pending_event==null: return
	var choice:=-1
	for index in main.game.pending_event.options.size():
		if not main.game.event_option_reason(index).is_empty(): continue
		var effects: Dictionary=main.game.pending_event.options[index].get("effects",{})
		if int(effects.get("gold",0))==0 and int(effects.get("dev",0))==0: choice=index; break
		if choice<0: choice=index
	var button: Button
	if choice>=0: button=main.event_buttons.get_child(choice).get_child(0)
	else:
		for candidate in main.event_buttons.find_children("*","Button",true,false):
			if not candidate.disabled: button=candidate; break
	if _check(button!=null,"Monthly event offers a legal actual UI answer"):
		await tap(button)
		_check(main.game.pending_event==null,"Actual monthly event input resolves its blocking dialog")

func tap(control: Control) -> void:
	# A newly shown research/modal child needs layout before its scroll range is valid.
	await settle()
	var scroll: Node=control.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	if scroll is ScrollContainer: scroll.ensure_control_visible(control)
	await settle()
	if scroll is ScrollContainer: _check(control.is_visible_in_tree() and scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Intended control is visible inside its actual scroll viewport before input: "+str(control.name))
	if DisplayServer.get_name()=="headless": control.pressed.emit(); await settle(); return
	var point: Vector2=control.get_viewport().get_screen_transform()*control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion:=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	_check(get_viewport().gui_get_hovered_control()==control,"Real input targets the intended research/Ausbau control: %s (%s)" % [control.name,str(control.get("text"))])
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()

func settle() -> void:
	for index in 5: await get_tree().process_frame

func _check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("INFRASTRUCTUREUITEST FAIL: "+message)
	return ok

func _finish() -> void:
	print("INFRASTRUCTUREUITEST %s; %d Prüfungen." % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
