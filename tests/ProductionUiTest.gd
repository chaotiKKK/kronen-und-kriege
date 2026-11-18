extends Node
## Real Main controls. Controlled UI fixtures are separate from regular-budget campaign proof.
const ViewModel=preload("res://scripts/ViewModelBuilder.gd")
var main
var ui
var inspector
var checks := 0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(2)
	main.game.speed = 0
	main.settings.autosave = false
	ui = main.get_meta("modern_interface")
	inspector = ui.province_inspector
	var home: String = main.game.house().capital
	main._on_province_selected(home)
	inspector.show_section("buildings")
	await settle()
	if not check(inspector.fields.has("production") and inspector.has_method("_request_construction_cancel"),"Existing Ausbau exposes local production and a real project cancellation flow"):
		finish()
		return
	await project_actions(home)
	await roads_and_context(home)
	await readable_touch(home)
	await actual_lan_pending()
	finish()

func project_actions(home: String) -> void:
	var game = main.game
	game.house().gold = 1000 # Controlled affordability fixture, not campaign funding evidence.
	main.refresh()
	var province: Dictionary = game.province(home)
	var level: int = province.buildings.market
	var preview: Dictionary = game.regional_project_preview(home,"market")
	var gold: int = game.house().gold
	check(preview.ok and not inspector.action_buttons["build:market"].disabled,"Actual start preview and the existing market button agree")
	await tap(inspector.action_buttons["build:market"])
	check(not province.regional_project.is_empty() and int(province.buildings.market) == level and int(game.house().gold) == gold-int(preview.gold),"Real market input pays once and starts construction without granting its completed level (project=%s gold=%d expected=%d modal=%s)" % [province.regional_project,int(game.house().gold),gold-int(preview.gold),main.kernel.top_modal()])
	if province.regional_project.is_empty(): return
	var project: int = province.regional_project.id
	check(inspector.project_controls.has(project),"Current project exposes concrete progress, priority and cancel controls")
	if not inspector.project_controls.has(project): return
	var before: Dictionary = game.snapshot()
	inspector.action_buttons["build:market"].pressed.emit()
	check(game.snapshot() == before,"A repeated stale build callback cannot pay or create a second project")
	await tap(inspector.project_controls[project].priority)
	check(int(province.regional_project.priority) == 1,"Actual priority button changes the existing project's shared-work priority")
	await advance_month_with_events()
	main.refresh()
	await settle()
	var current: Dictionary = province.regional_project
	check(not current.is_empty() and int(current.work_done_u)>0 and int(current.material_spent_u)>0,"One real monthly step creates measurable labor and material progress")
	if not current.is_empty():
		var controls: Dictionary = inspector.project_controls[project]
		check(absf(float(controls.progress.value)-100.0*float(current.work_done_u)/float(current.work_total_u))<0.001,"Shown construction percentage is the real cumulative work fraction")
		check(absf(float(controls.materials.value)-100.0*float(current.material_spent_u)/float(current.material_total_u))<0.001,"Shown material percentage is the real consumed fraction")
		check(inspector.fields.production_last.text.contains("Letzter Monat"),"Current stock is distinguished from actual last-month output and work")
		check(controls.progress.is_visible_in_tree() and not controls.materials.is_visible_in_tree() and controls.text.text.contains("Arbeit"),"Default project shows one explicitly named measured work progress")
		check(not controls.detail.is_visible_in_tree() and not inspector.fields.production_last.is_visible_in_tree(),"Audit ledger and repeated project explanations do not occupy default sidebar space")
		await tap(inspector.action_buttons.details)
		check(inspector.fields.details.is_visible_in_tree() and inspector.fields.details.text.contains("Letzter Monat") and inspector.fields.details.text.contains("Baustoffe") and inspector.fields.details.text.contains("Arbeit"),"Existing Details exposes actual monthly ledger and material/work audit")
		var expected_materials:=("Baustoffe %.2f / %.2f" % [float(current.material_spent_u)/1000000.0,float(current.material_total_u)/1000000.0]).replace(".",",")
		var expected_work:=("Arbeit %.2f / %.2f" % [float(current.work_done_u)/1000000.0,float(current.work_total_u)/1000000.0]).replace(".",",")
		check(inspector.fields.details.text.contains(expected_materials) and inspector.fields.details.text.contains(expected_work),"Visible Details contains the exact actual cumulative material/work quantities")
		await shot("project-details")
		await tap(inspector.action_buttons.details)
	await shot("active-project")
	var progress_before: int=province.regional_project.work_done_u
	var stock_before: int=province.production.materials_u
	province.siege=10; province.siege_owner=(game.player+1)%game.houses.size()
	main.refresh()
	check(inspector.fields.production_last.text.contains("Belagerung"),"Actual hostile siege produces a visible construction/production stall reason")
	check(inspector.fields.has("construction_state") and inspector.fields.get("construction_state").is_visible_in_tree() and inspector.fields.get("construction_state").text.contains("Belagerung"),"Important live blockade stays visible outside collapsed audit Details")
	await advance_month_with_events()
	main.refresh()
	check(int(province.regional_project.work_done_u)==progress_before and int(province.production.materials_u)==stock_before,"Real monthly blocked construction and production preserve progress and stock")
	province.siege=0; province.siege_owner=-1
	main.refresh()
	await tap(inspector.project_controls[project].cancel)
	check(inspector.construction_cancel_box.visible and inspector.fields.construction_confirmation.text.contains("nicht erstattet"),"Cancellation first explains the actual no-refund rule")
	check(inspector.construction_cancel_box.get_parent()==inspector.project_controls[project].box and cancellation_visible_without_driver_scroll(),"Clicked project's cancellation and focused escape are visible locally without test-driver scrolling")
	await shot("project-cancel-local")
	before = game.snapshot()
	main._on_province_selected("")
	inspector._confirm_construction_cancel()
	check(game.snapshot()==before and not inspector.construction_cancel_box.visible,"Selection change discards the old cancellation intent without mutation")
	main._on_province_selected(home)
	inspector.show_section("buildings")
	await settle()
	await tap(inspector.project_controls[project].cancel)
	await tap(inspector.action_buttons.construction_keep)
	check(not province.regional_project.is_empty() and not inspector.construction_cancel_box.visible,"Keep-building closes the confirmation and preserves the project")
	await tap(inspector.project_controls[project].cancel)
	var stock: int = province.production.materials_u
	gold = game.house().gold
	await tap(inspector.action_buttons.construction_confirm)
	check(province.regional_project.is_empty() and int(game.house().gold)==gold and int(province.production.materials_u)==stock and int(province.buildings.market)==level,"Real confirmed cancellation preserves unused stock but refunds neither paid gold nor consumed materials")
	# A replacement at the same province must not be cancelled by an obsolete intent.
	await tap(inspector.action_buttons["build:market"])
	project = int(province.regional_project.id)
	await tap(inspector.project_controls[project].cancel)
	game.cancel_construction(home,project)
	game.start_regional_project(home,"walls")
	var replacement: int = province.regional_project.id
	main.refresh()
	inspector._confirm_construction_cancel()
	check(int(province.regional_project.id)==replacement,"Replacing a project invalidates its old cancellation ID")
	# Complete a real paid project and verify effect only at completion.
	game.cancel_construction(home,replacement)
	main.refresh()
	await tap(inspector.action_buttons["build:market"])
	for month in 90:
		if province.regional_project.is_empty(): break
		await advance_month_with_events()
	main.refresh()
	await settle()
	check(province.regional_project.is_empty() and int(province.buildings.market)==level+1,"Actual monthly production/work eventually completes exactly one paid market level")
	check(inspector.action_buttons["build:market"].is_visible_in_tree() and inspector.action_buttons["build:barracks"].is_visible_in_tree() and main.develop_btn.is_visible_in_tree(),"Natural completion restores actual available next construction decisions")
	check(not inspector.fields.production.text.is_empty() and not inspector.fields.details.visible,"Compact local production remains visible with Details collapsed")

func roads_and_context(home: String) -> void:
	var game = main.game
	var neighbor := ""
	for id in game.neighbours(home):
		if int(game.province(str(id)).owner)==game.player: neighbor=str(id); break
	if neighbor.is_empty():
		neighbor=str(game.neighbours(home)[0])
		game.province(neighbor).owner=game.player # Controlled map fixture.
	game.house().research.known=["surveying","road_building","logistics"]
	game.house().gold=1000
	main._on_province_selected(home)
	inspector.show_section("buildings")
	main.refresh()
	await settle()
	check(inspector.sections.buildings.is_ancestor_of(main.road_buttons) and not main.infrastructure_body.is_ancestor_of(main.road_buttons),"Local roads reside in Ausbau rather than the house research modal")
	check(not main.road_buttons.visible,"Road options begin folded to preserve the compact view")
	await tap(inspector.action_buttons.roads_toggle)
	var button: Button
	for child in main.road_buttons.get_children():
		if child is Button and str(child.get_meta("to",""))==neighbor: button=child
	check(button!=null and not button.disabled,"Actual neighboring own region has a model-backed road choice")
	if button!=null:
		await tap(button)
		check(game.roads.any(func(road):return [str(road.from),str(road.to)].has(home) and [str(road.from),str(road.to)].has(neighbor) and not road.get("construction",{}).is_empty()),"Real road choice starts the paid shared-work road project")
		var road_id:=0
		for road in game.roads:
			if [str(road.from),str(road.to)].has(home) and [str(road.from),str(road.to)].has(neighbor): road_id=int(road.construction.id)
		check(road_id>0 and inspector.project_controls.has(road_id) and not button.is_visible_in_tree(),"Active road appears once as its actual project rather than a duplicate disabled start row")
		if inspector.project_controls.has(road_id):
			await tap(inspector.project_controls[road_id].cancel)
			check(inspector.construction_cancel_box.get_parent()==inspector.project_controls[road_id].box and cancellation_visible_without_driver_scroll(),"Deeply scrolled road cancellation reveals its own confirmation and escape without helper scrolling")
			await shot("road-cancel-local")
			await tap(inspector.action_buttons.construction_keep)
		# Controlled stored-material fixture verifies the UI's actual automatic flow report.
		for id in [home,neighbor]: game.province(id).production.materials_u=game.ProductionScript.stock_capacity_u(game.province(id))
		for month in 8:
			if game.roads.any(func(road):return road.state=="complete" and [str(road.from),str(road.to)].has(home) and [str(road.from),str(road.to)].has(neighbor)): break
			await advance_month_with_events()
		game.province(neighbor).production.materials_u=0
		check(game.start_regional_project(neighbor,"walls").ok,"Actual target construction creates automatic material demand")
		await advance_month_with_events()
		main.refresh()
		var report: Dictionary=game.regional_production_report()
		check(report.flows.any(func(flow):return str(flow.from)==home and str(flow.to)==neighbor and int(flow.amount_u)>0),"Completed actual road exports existing source material to target demand")
		check(inspector.fields.production_delivery.text.contains(str(game.province(neighbor).name)),"Source selection shows the real last-month automatic delivery destination")
		main._on_province_selected(neighbor)
		await settle()
		check(inspector.fields.production_delivery.text.contains(str(game.province(home).name)),"Target selection shows the actual incoming material's source")
		await shot("automatic-delivery")
		main._on_province_selected(home)
	check(inspector.action_buttons.has("build:depot") and inspector.action_buttons["build:depot"].is_visible_in_tree(),"Known logistics exposes the one-level supply depot when its weighted throughput is useful")
	check(game.BUILDING_KEYS.size()==3,"Depot does not add a fourth old building key")
	var foreign := ""
	for p in game.provinces:
		if int(p.owner)!=game.player: foreign=str(p.id); break
	var before: Dictionary = game.snapshot()
	main._on_province_selected(foreign)
	await settle()
	check(not inspector.section_buttons.buildings.visible and not inspector.section_buttons.research.visible and not inspector.action_buttons["build:depot"].is_visible_in_tree(),"Foreign context hides production, depot, road and research administration")
	inspector._request_construction_cancel(1)
	inspector._command({"id":"construction_priority","project":1,"priority":1})
	check(game.snapshot()==before and not inspector.construction_cancel_box.visible,"Old or forged foreign administration callbacks cannot mutate the own construction ledger")
	await shot("foreign-context")
	main._on_province_selected(home)
	await settle()
	check(inspector.section_buttons.values().filter(func(b):return b.visible).size()==3 and ui.pages.size()==3 and not ui.pages.has("world"),"Own three tabs and global three side areas survive the construction integration")
	check(not main.develop_btn.text.contains("0 Gold") and not inspector.action_buttons.province_focus.visible,"Current focus keeps its existing no-redundant-action behavior")

func readable_touch(home: String) -> void:
	main._on_province_selected(home)
	inspector.show_section("buildings")
	var game = main.game
	if not game.province(home).regional_project.is_empty(): game.cancel_construction(home,int(game.province(home).regional_project.id))
	game.start_regional_project(home,"walls")
	main.refresh()
	var project: int = game.province(home).regional_project.id
	for scale in [1.0,2.0]:
		ui.set_touch_layout(true)
		ui.set_text_scale(scale)
		await settle()
		for button in [inspector.project_controls[project].priority,inspector.project_controls[project].cancel,inspector.action_buttons.roads_toggle]:
			await reveal(button)
			check(button.size.y>=44 and button.get_theme_font_size("font_size")>=int(12*scale),"Production action retains a 44-unit Touch target and chosen readable text scale")
		await tap(inspector.project_controls[project].cancel)
		check(cancellation_visible_without_driver_scroll(),"Real cancellation at Touch100/200 reveals both choices and focused escape without helper scrolling")
		await shot("touch-%d-cancel-local" % int(scale*100))
		await reveal(inspector.action_buttons.construction_keep)
		check(main.get_viewport_rect().encloses(inspector.action_buttons.construction_keep.get_global_rect()),"Cancellation escape remains scrollable into the viewport at Touch200%")
		await tap(inspector.action_buttons.construction_keep)
		await shot("touch-%d" % int(scale*100))
		await reveal(inspector.project_controls[project].text)
		await shot("touch-%d-progress" % int(scale*100))
	# Tiny migrated regions have actual micro-stocks and must not appear as zero output.
	var tiny := ""
	for p in game.provinces:
		if float(p.get("economic_share",1.0))>0 and float(p.get("economic_share",1.0))<0.001:
			tiny=str(p.id); p.owner=game.player; break
	if check(not tiny.is_empty(),"Catalog has a genuine very small region for formatting acceptance"):
		main._on_province_selected(tiny)
		inspector.show_section("buildings")
		await settle()
		check(inspector.fields.production.text.contains("<0,01") and inspector.fields.production.text.contains("%"),"Positive tiny output is readable as <0,01 and local storage percentage rather than rounded zero")
		check(not inspector.action_buttons["build:depot"].is_visible_in_tree(),"A zero-throughput tiny depot is omitted even with logistics known")
		await reveal(inspector.fields.production)
		await shot("tiny-touch-200")
	ui.set_text_scale(1.0)
	ui.set_touch_layout(false)

func actual_lan_pending() -> void:
	var host = load("res://scripts/LanSession.gd").new()
	host.discovery_enabled=false
	main.lan_session.discovery_enabled=false
	add_child(host)
	var guest=main.lan_session
	var port := 48900+OS.get_process_id()%500
	if not check(host.host("Production UI","Host",0,port).ok,"Real host opens for production acknowledgement acceptance"): return
	check(guest.join("127.0.0.1","Guest",port).ok,"Actual Main guest connects to the production host")
	if not await until(func():return guest.phase=="lobby" and host.players.size()==2):
		check(false,"Production host and Main guest reach actual lobby")
		host.close_session(); guest.close_session(); host.queue_free(); return
	guest.choose_house(1)
	guest.set_ready(true)
	check(await until(func():return bool(host.players[guest.local_peer_id].ready)),"Guest's actual readiness arrives at host")
	check(host.start_match().ok and await until(func():return guest.phase=="playing"),"Main receives the real authoritative production world")
	host.game.speed=0
	main.game.speed=0
	var home: String=main.game.house().capital
	main._on_province_selected(home)
	inspector.show_section("buildings")
	await settle()
	var before: Dictionary=main.game.snapshot()
	var gold: int=main.game.house().gold
	var price: int=main.game.regional_project_preview(home,"market").gold
	var button: Button=inspector.action_buttons["build:market"]
	check(not button.disabled,"Actual guest's affordable project starts enabled")
	button.pressed.emit()
	check(guest.pending_command and button.disabled and main.game.snapshot()==before,"Guest shows pending host confirmation and no premature local payment/effect")
	button.pressed.emit()
	check(main.game.snapshot()==before,"Repeated pending callback does not apply a local duplicate")
	check(await until(func():return not guest.pending_command and not main.game.province(home).regional_project.is_empty()),"Authoritative host confirms the actual UI construction intent")
	check(int(main.game.house().gold)==gold-price and main.LanSessionScript.Protocol.world_hash(main.game.snapshot())==main.LanSessionScript.Protocol.world_hash(host.game.snapshot()),"Confirmed UI pays once and leaves host/guest production worlds identical")
	check(main.production_report.ledger.is_empty(),"Guest starts with no invented monthly ledger before the first actual host month")
	# Only the authoritative host simulates. No guest tick, manual Main refresh,
	# fabricated report, extra stock or extra gold may create this UI evidence.
	host.game.advance_month()
	var expected_month: int=host.game.calendar_index()
	var expected: Dictionary=host.game.regional_production_report(guest.local_house())
	if not check(expected.ledger.has(home),"Actual host month creates the guest region's real production ledger"):
		host.close_session(); guest.close_session(); host.queue_free(); return
	var expected_ledger: Dictionary=expected.ledger[home].duplicate(true)
	check(int(expected_ledger.produced_u)>0 and int(expected_ledger.used_u)>0 and int(expected_ledger.work_u)>0,"Existing paid guest project consumes only real first-month host production and work")
	host.revision+=1
	var month_revision: int=host.revision
	host._broadcast_snapshot()
	check(await until(func():return guest.phase=="playing" and guest.revision>=month_revision and main.game.calendar_index()==expected_month),"Real ENet month snapshot reaches the actual Main guest")
	await settle()
	var received: Dictionary=guest.game.regional_production_report()
	check(main.game==guest.game and main.selected==home and received.ledger.get(home,{})==expected_ledger,"Guest report and retained Main selection expose the exact authoritative month without guest simulation")
	check(main.production_report.ledger.get(home,{})==expected_ledger,"LAN update automatically refreshes Main's production cache before Inspector presentation")
	var expected_produced:=ViewModel.material_text(int(expected_ledger.produced_u))
	var expected_used:=ViewModel.material_text(int(expected_ledger.used_u))
	check(inspector.fields.production.text.contains("+%s zuletzt" % expected_produced),"Guest's compact resource line shows measured host output instead of missing-ledger potential")
	if not inspector.action_buttons.details.button_pressed: await tap(inspector.action_buttons.details)
	var expected_month_text:="Letzter Monat: +%s erzeugt · %s verbaut" % [expected_produced,expected_used]
	check(inspector.fields.details.is_visible_in_tree() and inspector.fields.details.text.contains(expected_month_text),"Actual guest Details renders the host's real produced and consumed monthly quantities")
	check(main.LanSessionScript.Protocol.world_hash(main.game.snapshot())==main.LanSessionScript.Protocol.world_hash(host.game.snapshot()),"Showing received monthly audit changes no guest or host accounts/world state")
	await shot("lan-guest-month-details")
	host.close_session(); guest.close_session(); host.queue_free()

func reveal(control: Control) -> void:
	var scroll: Node=control.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	if scroll is ScrollContainer: scroll.ensure_control_visible(control)
	await settle()
	if scroll is ScrollContainer:
		check(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Actual requested control fits completely inside the sidebar scroll viewport (%s control=%s scroll=%s)" % [control.name,control.get_global_rect(),scroll.get_global_rect()])

func cancellation_visible_without_driver_scroll() -> bool:
	var scroll: Node=inspector.construction_cancel_box.get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll=scroll.get_parent()
	if not scroll is ScrollContainer: return false
	return scroll.get_global_rect().grow(1).encloses(inspector.action_buttons.construction_keep.get_global_rect()) and scroll.get_global_rect().grow(1).encloses(inspector.action_buttons.construction_confirm.get_global_rect()) and inspector.action_buttons.construction_keep.has_focus()

func tap(control: Control) -> void:
	await reveal(control)
	if DisplayServer.get_name()=="headless":
		# Headless validates the actual control callback and model only; the window run exercises input routing.
		control.pressed.emit()
		await settle()
		return
	# Input.parse_input_event receives window pixels; Controls use stretched canvas coordinates.
	var point: Vector2=control.get_viewport().get_screen_transform()*control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion:=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control()==control,"Real transformed input resolves to the intended visible control: "+str(control.name))
	if OS.get_environment("BQ_INPUT_DEBUG")=="1":
		print("PRODUCTION_INPUT target=",control.name," text=",control.get("text")," rect=",control.get_global_rect()," input=",point," hovered=",get_viewport().gui_get_hovered_control()," modal=",main.kernel.top_modal()," final_transform=",get_viewport().get_final_transform()," screen_transform=",get_viewport().get_screen_transform()," window=",get_window().size," viewport=",get_viewport().get_visible_rect())
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()

func advance_month_with_events() -> void:
	main.game.advance_month()
	main.refresh()
	await settle()
	if main.game.pending_event==null: return
	# A normal monthly step may open an actual blocking event. Answer its real
	# UI instead of clicking through it or mutating pending_event/event_layer.
	var options: Array=main.game.pending_event.options
	var choice:=-1
	for index in options.size():
		if not main.game.event_option_reason(index).is_empty(): continue
		var effects: Dictionary=options[index].get("effects",{})
		if int(effects.get("gold",0))==0 and int(effects.get("dev",0))==0:
			choice=index; break
		if choice<0: choice=index
	var button: Button
	if choice>=0:
		button=main.event_buttons.get_child(choice).get_child(0)
	else:
		for candidate in main.event_buttons.find_children("*","Button",true,false):
			if not candidate.disabled: button=candidate; break
	if not check(button!=null,"Monthly blocking event offers a genuine legal UI answer"): return
	await tap(button)
	check(main.game.pending_event==null and not main.event_layer.visible,"Real event input answers the monthly event before the next construction action")

func until(condition: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.02).timeout
	return condition.call()

func settle() -> void:
	for index in 5: await get_tree().process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var root:=OS.get_environment("BQ_PRODUCTION_PROOF")
	if root.is_empty(): root=ProjectSettings.globalize_path("user://production-ui")
	DirAccess.make_dir_recursive_absolute(root)
	check(get_viewport().get_texture().get_image().save_png(root.path_join(name+".png"))==OK,"Actual renderer evidence saved: "+name)

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PRODUCTIONUITEST FAIL: "+message)
	return ok

func finish() -> void:
	print("PRODUCTIONUITEST %s; %d Prüfungen." % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
