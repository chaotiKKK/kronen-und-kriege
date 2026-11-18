extends Node
## Real simulation projects and actual map draws, with bounded report-call auditing.
class CountingGame extends "res://scripts/Game.gd":
	var supply_calls := 0
	var production_calls := 0
	func supply_report(hi: int = -1) -> Dictionary:
		supply_calls+=1
		return super.supply_report(hi)
	func regional_production_report(hi: int = -1) -> Dictionary:
		production_calls+=1
		return super.regional_production_report(hi)

var main
var checks:=0
var failures:=0

func _ready() -> void:
	main=load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	main._start(2)
	main.settings.autosave=false
	main.game.speed=0
	var map=main.map_view
	if not check(map.has_method("set_simulation_reports") and map.has_method("construction_markers"),"Map accepts one fresh simulation snapshot and exposes actual construction-marker geometry"):
		finish(); return
	var game=CountingGame.new(load("res://scripts/GameRegionData.gd"),2)
	check(game.restore(main.game.snapshot()),"Counting observer restores the actual starting world without replacing simulation rules")
	main.game=game
	main.kernel.bind_game(game)
	game.speed=0
	game.house().gold=1000 # Controlled marker fixture, not normal campaign proof.
	var home: String=game.house().capital
	check(game.start_regional_project(home,"walls").ok,"Marker fixture starts a real paid project through Game")
	var project: int=game.province(home).regional_project.id
	game.advance_month()
	# Simultaneous military overlays at the same real project anchor exercise collision envelopes.
	game.house().armies=[{"id":77,"province":home,"strength":200,"morale":100,"upkeep":1,"last_siege_month":0}]
	game.house().fleets=[{"id":78,"station":home,"province":home,"ships":3,"upkeep":1,"last_naval_month":-1}]
	main._on_province_selected(home)
	var ui=main.get_meta("modern_interface")
	ui.set_touch_layout(true)
	for scale in [1.0,2.0]:
		ui.set_text_scale(scale)
		for mode in ["political","economy","war"]:
			main._set_map_mode(mode)
			for zoom in [1.0,2.49,2.5,2.51,4.0,12.0]:
				map.zoom=zoom
				map.center_on(map._label_point(game.province(home)))
				await settle()
				var markers: Array=map.construction_markers()
				check(markers.any(func(item):return int(item.id)==project and str(item.province)==home),"Real construction persists in %s map at zoom %.2f and text %d%%" % [mode,zoom,int(scale*100)])
				var placed: Array=[]
				for marker in markers:
					var hit: Rect2=marker.hit_rect
					check(Rect2(Vector2.ZERO,map.size).encloses(hit) and hit.size.x>=44 and hit.size.y>=44,"Visible project marker has a complete, touchable in-map hit rectangle")
					check(not placed.any(func(rect):return rect.intersects(hit)),"Distinct construction markers retain distinct target rectangles")
					placed.append(hit)
					for army in map.army_markers():
						check(not hit.intersects(army.rect),"Construction marker cannot cover an actual army target")
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					check(map.construction_markers_drawn.any(func(item):return int(item.id)==project),"Actual draw path rendered the real project, including either side of zoom 2.5")
					for marker in map.construction_markers_drawn:
						check(map.atlas_obstacles.any(func(rect):return rect.encloses(marker.hit_rect)),"Actual construction hit/drawing bounds reserve atlas label space")
						for label in map.atlas_layer.audit_labels:
							check(not marker.hit_rect.intersects(label.rect),"Real atlas labels do not overlap the construction marker")
						for fleet in map.fleet_markers_drawn:
							var number_size:=ThemeDB.fallback_font.get_string_size(str(fleet.label),HORIZONTAL_ALIGNMENT_LEFT,-1,9)
							var fleet_box: Rect2=(fleet.token_rect as Rect2).grow(3).merge(Rect2(fleet.label_pos-Vector2(0,9),number_size+Vector2(1,3)))
							check(not marker.hit_rect.intersects(fleet_box),"Construction leaves actual fleet ring, token and ship count uncovered")
		await shot("construction-touch-%d" % int(scale*100))
	# Camera changes must not invoke either simulation planner/report producer.
	var supply_before: int=game.supply_calls
	var production_before: int=game.production_calls
	var world_before: Dictionary=game.snapshot()
	check(not world_before.is_empty(),"Controlled military/project fixture remains a valid complete save state")
	for index in 24:
		map.pan+=Vector2(2,-1)
		map._clamp_pan(); map._sync_base_transform(); map.queue_redraw()
		map.construction_markers(); map.infrastructure_segments()
		await get_tree().process_frame
	check(game.supply_calls==supply_before and game.production_calls==production_before,"Actual repeated pan/redraw/marker queries reuse Main's reports and perform no supply/production planning")
	check(game.snapshot()==world_before,"Map presentation and transforms do not mutate production, armies or materials")
	main._set_map_mode("political")
	map.zoom=4.0
	map.center_on(map._label_point(game.province(home)))
	await settle()
	var target: Dictionary={}
	for marker in map.construction_markers():
		if int(marker.id)==project: target=marker; break
	if check(not target.is_empty(),"Real construction marker remains available for input acceptance"):
		ui.province_inspector.show_section("research")
		await tap_map(map,(target.hit_rect as Rect2).get_center())
		check(main.selected==home and ui.province_inspector.current_section=="buildings", "Actual marker input opens the existing region Ausbau without a province modal")
		check(game.snapshot()==world_before,"Marker selection changes view only, never the project or supply state")
	game.cancel_construction(home,project)
	main.refresh()
	await settle()
	check(not map.construction_markers().any(func(item):return int(item.id)==project),"Cancelled project has neither a visible nor a targetable cached marker after refresh")
	finish()

func tap_map(map,point: Vector2) -> void:
	if DisplayServer.get_name()=="headless":
		map._pick_at(point)
		await settle()
		return
	var global_point: Vector2=map.get_viewport().get_screen_transform()*map.get_global_transform_with_canvas()*point
	var motion:=InputEventMouseMotion.new()
	motion.position=global_point; motion.global_position=global_point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=global_point; event.global_position=global_point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()

func settle() -> void:
	for index in 5: await get_tree().process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var root:=OS.get_environment("BQ_PRODUCTION_PROOF")
	if root.is_empty(): root=ProjectSettings.globalize_path("user://construction-map")
	DirAccess.make_dir_recursive_absolute(root)
	check(get_viewport().get_texture().get_image().save_png(root.path_join(name+".png"))==OK,"Actual rendered construction proof saved: "+name)

func check(ok: bool,message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("CONSTRUCTIONMAPTEST FAIL: "+message)
	return ok

func finish() -> void:
	print("CONSTRUCTIONMAPTEST %s; %d Prüfungen." % ["OK" if failures==0 else "FAIL",checks])
	get_tree().quit(0 if failures==0 else 1)
