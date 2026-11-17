extends Node
## Reale Minimap-Draws mit echtem MapView/Game; der Host bleibt ohne Atlas-_ready.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const MiniMap = preload("res://scripts/WorldMiniMap.gd")
var checks := 0
var failures := 0
var overlay_draws := 0
var host
var mini
var output := "res://build/verify/atlas-cache/minimap-cache-test"

class CountingMapView:
	extends "res://scripts/MapView.gd"
	var part_queries := 0
	func _province_parts(province: Dictionary) -> Array:
		part_queries += 1
		return super._province_parts(province)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("MINIMAPCACHETEST requires a real renderer for CanvasItem draw evidence")
		get_tree().quit(2)
		return
	var requested := OS.get_environment("MINIMAP_TEST_OUTPUT")
	if not requested.is_empty(): output = requested
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	host = CountingMapView.new()
	host.game = Game.new(Data,0)
	host.game.speed = 0
	host.size = Vector2(720,420)
	host.zoom = 4.0
	host.pan = Vector2.ZERO
	host.map_mode = "political"
	mini = MiniMap.new()
	mini.host = host
	mini.position = Vector2(24,24)
	mini.size = Vector2(300,210)
	mini.draw.connect(_overlay_drawn)
	add_child(mini)
	await settle()
	check(not host.is_inside_tree(),"Echter MapView bleibt off-tree und lädt keinen großen Referenzatlas")
	check(host.game.provinces.size()==108,"Echter regionaler Spielstand enthält108 unveränderte Spielgebiete")
	check(overlay_draws>0 and host.part_queries>=108,"Initialer echter Canvas-Draw liest die vollständige Regionsgeometrie")
	shot("initial")
	var first_image := image_hash()
	var first_draws := overlay_draws
	host.part_queries = 0
	for step in 10:
		host.pan = Vector2((step+1)*20,-(step+1)*5)
		var previous_draws := overlay_draws
		await settle()
		check(overlay_draws>previous_draws,"Kamerabewegung%d zeichnet das aktuelle Overlay tatsächlich neu" % (step+1))
	check(host.part_queries==0,"Zehn reine Pans fragen keine Regionsgeometrie erneut ab (ist%d)" % host.part_queries)
	check(overlay_draws>=first_draws+10 and image_hash()!=first_image,"Sichtbares Kamerarechteck verändert sich trotz wiederverwendeter Karteninhalte")
	shot("pan")
	var pan_image := image_hash()
	var pan_draws := overlay_draws
	host.part_queries = 0
	host.zoom = 5.0
	await settle()
	check(overlay_draws>pan_draws and image_hash()!=pan_image,"Zoom aktualisiert sichtbares Kamerarechteck und Zoomanzeige")
	check(host.part_queries==0,"Reiner Zoom trianguliert die statischen Regionen nicht erneut")
	shot("zoom")

	host.part_queries = 0
	var selection_image := image_hash()
	host.selected = str(host.game.house().capital)
	await settle()
	check(host.part_queries>0 and image_hash()!=selection_image,"Auswahl erneuert den echten Inhalt samt sichtbarer Provinzumrandung")
	host.selected = ""
	await settle()
	var target: Dictionary = host.game.provinces[0]
	var owner_colors := actual_colors()
	host.part_queries = 0
	target.owner = (int(target.owner)+1)%host.game.houses.size()
	await settle()
	check(actual_colors()!=owner_colors,"Besitzwechsel ändert die echte MapModes-Farbliste")
	check(host.part_queries>0,"Besitzwechsel aktualisiert den Minimap-Inhalt bei ruhender Kamera")
	var house_colors := actual_colors()
	host.part_queries = 0
	var owner: int = int(target.owner)
	host.game.houses[owner].color = host.game.houses[owner].color.lightened(.23)
	await settle()
	check(actual_colors()!=house_colors,"Geänderte Hausfarbe wird über echte MapModes ausgewertet")
	check(host.part_queries>0,"Hausfarbwechsel aktualisiert Inhalt ohne Besitzer-/Panänderung")

	host.map_mode = "titles"
	host.title_level = "duchy"
	await settle()
	var duchy_colors := actual_colors()
	host.part_queries = 0
	host.title_level = "empire"
	await settle()
	check(actual_colors()!=duchy_colors,"Reale Rechtstitelfarben unterscheiden Herzogtümer und Reiche")
	check(host.part_queries>0,"Titelstufenwechsel aktualisiert den Inhalt ohne Änderung der Kartenmodus-ID")

	host.map_mode = "economy"
	await settle()
	var economy_colors := actual_colors()
	var focus_id := ""
	for province in host.game.owned():
		var alternative: Dictionary = province.duplicate()
		alternative.economic_focus = "agriculture"
		if host._fill_color(alternative)!=host._fill_color(province):
			focus_id = str(province.id)
			break
	check(not focus_id.is_empty(),"Reale Wirtschaftskarte besitzt eine farblich wirksame Kornkammerwahl")
	host.part_queries = 0
	if not focus_id.is_empty():
		var change: Dictionary = host.game.set_province_focus(focus_id,"agriculture")
		check(bool(change.ok),"Echte Spielaktion setzt den finanzierbaren Kornkammerschwerpunkt")
		await settle()
		check(actual_colors()!=economy_colors,"Fokuswahl ändert die echte Ertragsfarbe ohne Entwicklungsänderung")
		check(host.part_queries>0,"Fokuswahl aktualisiert die ruhende Wirtschaftsminimap")
	shot("economy")

	var old_game_id: int = host.game.get_instance_id()
	host.part_queries = 0
	host.game = Game.new(Data,0)
	host.game.speed = 0
	await settle()
	check(host.game.get_instance_id()!=old_game_id and host.part_queries>=108,"Neuer echter Spielstand erneuert alle Regionsinhalte")
	host.part_queries = 0
	var before_resize := image_hash()
	mini.size = Vector2(340,230)
	await settle()
	check(host.part_queries>=108 and image_hash()!=before_resize,"Größenwechsel erneuert die vollständige Geometrie an der neuen Minimap-Skalierung")
	shot("resized")
	host.part_queries = 0
	await settle()
	check(host.part_queries==0,"Unveränderter Folgelauf erzeugt keine zusätzlichen Geometrieabfragen")
	var tested_region_count: int = host.game.provinces.size()
	var host_was_off_tree: bool = not host.is_inside_tree()
	await host_lifecycle()
	var report := {"checks":checks,"failures":failures,"region_count":tested_region_count,"actual_overlay_draws":overlay_draws,"renderer":RenderingServer.get_current_rendering_method(),"minimap_source_sha256":FileAccess.get_sha256("res://scripts/WorldMiniMap.gd"),"host_off_tree":host_was_off_tree}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	mini.host = null
	if is_instance_valid(host): host.free()
	mini.queue_free()
	print("MINIMAPCACHETEST %s; %d Prüfungen; %d Fehler." % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func host_lifecycle() -> void:
	var previous = host
	var replacement := CountingMapView.new()
	replacement.game = host.game
	replacement.size = host.size
	replacement.zoom = host.zoom
	replacement.pan = host.pan
	replacement.map_mode = host.map_mode
	replacement.title_level = host.title_level
	replacement.selected = host.selected
	host = replacement
	mini.host = replacement
	await settle()
	check(host.part_queries>=108,"Ein neuer echter Host mit derselben Gameinstanz fragt die vollständige Geometrie neu ab (ist%d)" % host.part_queries)
	previous.free()
	await settle()
	check(not is_instance_valid(previous) and is_instance_valid(mini),"Der vorherige OffTree-Host wird bei weiterlebender Minimap sicher freigegeben")
	var saved_game = host.game
	host.game = null
	mini.queue_redraw()
	await settle()
	check(interior_is_dark(),"Ein gültiger Host ohne Game leert die alte Landkarte im echten Draw")
	host.game = saved_game
	await settle()
	check(not interior_is_dark(),"Ein wiederhergestelltes echtes Game zeichnet den Karteninhalt erneut")
	mini.host = null
	mini.queue_redraw()
	await settle()
	check(interior_is_dark(),"Null-Host mit weiterlebender Minimap leert auch den zwischengespeicherten Karteninhalt")
	shot("host-null")
	var released = host
	host.free()
	host = null
	mini.queue_redraw()
	await settle()
	check(not is_instance_valid(released) and is_instance_valid(mini),"Nach Hostfreigabe läuft ein weiterer echter Bildaufbau mit lebender Minimap")

func interior_is_dark() -> bool:
	var image: Image = get_viewport().get_texture().get_image()
	var point: Vector2 = mini.global_position + mini._map_rect().get_center()
	var ratio: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var pixel := Vector2i(roundi(point.x*ratio.x),roundi(point.y*ratio.y))
	var ink: Color = image.get_pixelv(pixel)
	return maxf(ink.r,maxf(ink.g,ink.b)) < .12

func actual_colors() -> Array:
	var colors: Array = []
	for province in host.game.provinces: colors.append(host._fill_color(province))
	return colors

func settle() -> void:
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw

func image_hash() -> int:
	return hash(get_viewport().get_texture().get_image().get_data())

func shot(label: String) -> void:
	get_viewport().get_texture().get_image().save_png(output+"/"+label+".png")

func _overlay_drawn() -> void:
	overlay_draws += 1

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MINIMAPCACHETEST FAIL: "+message)
