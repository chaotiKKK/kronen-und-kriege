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
	await construction_cue_acceptance()
	game.cancel_construction(home,project)
	main.refresh()
	await settle()
	check(not map.construction_markers().any(func(item):return int(item.id)==project),"Cancelled project has neither a visible nor a targetable cached marker after refresh")
	finish()

func construction_cue_acceptance() -> void:
	# Catches an invisible/misanchored leader, an endpoint hidden inside the badge,
	# and accidental expansion of its hit area into the decorative cue.
	var map=main.map_view
	var original_game=main.game
	var original_selected: String=main.selected
	var presentation: Dictionary={"zoom":map.zoom,"pan":map.pan,"mode":map.map_mode,"text_scale":preload("res://scripts/ModernInterface.gd").text_scale,"appearance":preload("res://scripts/ModernInterface.gd").appearance}
	# Reproduce the actual reported Wien market with a regular starting budget;
	# the broader original test above intentionally uses a Wessex walls fixture.
	var game=CountingGame.new(load("res://scripts/GameRegionData.gd"),0)
	game.speed=0
	var home: String="germanien__05"
	check(str(game.province(home).name)=="Wien" and int(game.province(home).owner)==game.player,"Reported cue fixture is the real owned Wien region")
	var starting_gold: int=game.house().gold
	check(game.start_regional_project(home,"market").ok and int(game.house().gold)==starting_gold-13,"Cue fixture starts the actual Wien market for 13 gold without extra funding")
	var project: int=game.province(home).regional_project.id
	check(game.raise_army(home).ok and int(game.house().gold)==starting_gold-63,"Cue fixture raises its overlapping actual army for 50 gold within the same regular budget")
	main.game=game
	main.kernel.bind_game(game)
	main.refresh()
	map.hovered="" # A comparison screenshot must not retain the prior fixture's tooltip.
	map.queue_redraw()
	var ui=main.get_meta("modern_interface")
	var before: Dictionary=game.snapshot()
	main._set_map_mode("political")
	ui.set_appearance(1)
	ui.set_touch_layout(true)
	for scale in [1.0,2.0]:
		ui.set_text_scale(scale)
		main._on_province_selected(home)
		map.zoom=1.0
		map.center_on(map._label_point(game.province(home)))
		await settle()
		await shot("construction-cue-overview-%d" % int(scale*100))
		if DisplayServer.get_name()!="headless" and map.has_method("_construction_cue"):
			for marker in map.construction_markers():
				if int(marker.id)==project: await assert_cue_raster(map,marker,"overview %d%%" % int(scale*100))
	if not check(map.has_method("_construction_cue"),"Displaced construction exposes its actual anchor-to-badge-edge cue geometry"):
		restore_marker_game(original_game,original_selected,presentation)
		return
	# Independently hand-derived diagonal intersection: rect centre (140,120),
	# ray towards (40,20) reaches top edge y=100 at (120,100), not (100,100).
	for sample in [
		{"anchor":Vector2(40,20),"end":Vector2(120,100)},
		{"anchor":Vector2(20,120),"end":Vector2(100,120)},
		{"anchor":Vector2(260,120),"end":Vector2(180,120)},
		{"anchor":Vector2(140,200),"end":Vector2(140,140)}]:
		var cue: Dictionary=map._construction_cue({"anchor":sample.anchor,"rect":Rect2(100,100,80,40),"blocked":false})
		check(not cue.is_empty() and (cue.get("anchor",Vector2.INF) as Vector2).is_equal_approx(sample.anchor) and (cue.get("end",Vector2.INF) as Vector2).is_equal_approx(sample.end),"Cue terminates at the true ray/rectangle intersection, including diagonal and axis-aligned cases")
	check(map._construction_cue({"anchor":Vector2(140,120),"rect":Rect2(100,100,80,40),"blocked":false}).is_empty(),"An anchor covered by its own badge emits no misleading external leader")
	var foreign: String=""
	for province in game.provinces:
		if int(province.owner)!=game.player: foreign=str(province.id); break
	main._on_province_selected(foreign)
	ui.province_inspector.show_section("research")
	ui.set_text_scale(2.0)
	main._set_map_mode("war")
	var displaced: Dictionary={}
	for candidate_zoom in [1.0,1.1,1.2,1.3,1.4,1.6,1.8,2.0,2.49,2.51,3.0,4.0]:
		map.zoom=candidate_zoom
		map.center_on(map._label_point(game.province(home)))
		await settle()
		for marker in map.construction_markers():
			if int(marker.id)!=project: continue
			var under: Dictionary=game.province(map._province_at((marker.hit_rect as Rect2).get_center()))
			print("CONSTRUCTION_CUE_FIXTURE home=%s zoom=%.2f badge=%s anchor=%s under=%s distance=%.2f" % [home,candidate_zoom,marker.rect,marker.anchor,str(under.get("id","water")),(marker.rect as Rect2).get_center().distance_to(marker.anchor)])
			if not under.is_empty() and int(under.owner)!=game.player and (marker.rect as Rect2).get_center().distance_to(marker.anchor)>70:
				displaced=marker; break
		if not displaced.is_empty(): break
	if check(not displaced.is_empty(),"Real Wien construction at 200% has a displaced badge above a foreign land region for input acceptance"):
		check(main.selected==foreign and foreign!=home,"Displaced-marker input begins with a different province selected")
		check(displaced.hit_rect==displaced.rect,"Anchor point and leader never expand the actual construction hit rectangle")
		var cue: Dictionary=displaced.get("cue",{})
		check(not cue.is_empty(),"The real displaced construction marker carries the geometry used by its visible cue")
		if not cue.is_empty():
			var fit: Array=map._fit()
			var actual_anchor: Vector2=map._label_point(game.province(home))*float(fit[0])+Vector2(fit[1])
			check((cue.anchor as Vector2).is_equal_approx(actual_anchor),"Cue anchor is the real province position under the current camera, not the displaced badge position")
			if DisplayServer.get_name()!="headless":
				await assert_cue_raster(map,displaced,"displaced foreign target 200%")
			await shot("construction-cue-200-foreign-target")
			var decorative: Vector2=(cue.anchor as Vector2).lerp(cue.end,0.45)
			var signals: Array=[]
			var observe:=func(province_id,project_id):signals.append([province_id,project_id])
			map.construction_selected.connect(observe)
			check(not (displaced.hit_rect as Rect2).has_point(decorative),"Decorative leader point is outside the badge target")
			await tap_map(map,decorative)
			check(signals.is_empty(),"Actual input on a decorative leader alone emits no construction selection")
			map.construction_selected.disconnect(observe)
		# Re-select another region, because the preceding normal map click may select Wien.
		main._on_province_selected(foreign)
		ui.province_inspector.show_section("research")
		await settle()
		for marker in map.construction_markers():
			if int(marker.id)==project: displaced=marker; break
		await tap_map(map,(displaced.hit_rect as Rect2).get_center())
		check(main.selected==home and ui.province_inspector.current_section=="buildings","Actual input on the displaced badge above foreign land selects Wien and opens its existing Ausbau")
		await shot("construction-cue-200-wien-selected")
	check(game.snapshot()==before,"Cue geometry, raster and actual decorative/badge input never mutate the simulation")
	restore_marker_game(original_game,original_selected,presentation)

func restore_marker_game(game,selected_id: String,presentation: Dictionary) -> void:
	main.game=game
	main.kernel.bind_game(game)
	main._on_province_selected(selected_id)
	main.refresh()
	var ui=main.get_meta("modern_interface")
	ui.set_text_scale(float(presentation.text_scale))
	ui.set_appearance(int(presentation.appearance))
	main._set_map_mode(str(presentation.mode))
	main.map_view.zoom=float(presentation.zoom)
	main.map_view.pan=Vector2(presentation.pan)
	main.map_view._sync_base_transform()
	main.map_view.queue_redraw()

func assert_cue_raster(map,marker: Dictionary,context: String) -> void:
	var cue: Dictionary=marker.get("cue",{})
	if not check(not cue.is_empty(),"Actual construction has a visible external cue in "+context): return
	await RenderingServer.frame_post_draw
	var pixels: Image=get_viewport().get_texture().get_image()
	var ratio:=Vector2(pixels.get_size())/get_viewport().get_visible_rect().size
	var transform: Transform2D=map.get_global_transform_with_canvas()
	var anchor: Vector2=cue.anchor
	var ink:=Color("dfb765")
	for point in [anchor,anchor.lerp(cue.end,0.45)]:
		var pixel: Color=pixels.get_pixelv(Vector2i(((transform*point)*ratio).round()))
		check(maxf(absf(pixel.r-ink.r),maxf(absf(pixel.g-ink.g),absf(pixel.b-ink.b)))<0.14,"Actual anchor and leader remain opaque gold above map labels in "+context)
	var halo_point: Vector2=anchor+Vector2(float(cue.radius)+1.0,0)
	var halo: Color=pixels.get_pixelv(Vector2i(((transform*halo_point)*ratio).round()))
	check(maxf(halo.r,maxf(halo.g,halo.b))<0.22,"Actual anchor has a contrasting dark halo on the rendered map in "+context)

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
