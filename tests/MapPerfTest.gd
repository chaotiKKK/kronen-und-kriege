extends Node
## Misst die Bildrate der Karte in einem echten Fenster.
## Aufruf: godot --path . res://tests/MapPerfTest.tscn --resolution 1600x900
## Gemessen wird die politische Karte bei Übersicht und 4x Zoom, jeweils mit
## ruhender Kamera und erzwungenem Host-Redraw. Ein eigener 4x-Pan-Lauf bewegt
## die Kamera tatsächlich und erfasst dadurch Atlas-Neuberechnungen. Zusätzlich
## entstehen Gelände-Screenshots des geografischen Untergrunds.

const WARMUP_FRAMES := 60
const SAMPLE_SECONDS := 4.0

var main
var _bench_redraw := false
var _bench_pan := false
var _samples: Array[float] = []
var _checks: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("MapPerfTest braucht ein echtes Fenster")
		return
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main._start(2)
	main.game.speed = 0
	main._set_map_mode("political")
	main.map_view.select("")
	if main.ambient_player != null:
		main.ambient_player.stop()
	await get_tree().process_frame
	await get_tree().process_frame

	var tex: Texture2D = main.map_view._base.terrain_texture()
	if not _expect(tex != null, "Der tatsächlich verwendete Atlas-Untergrund wurde nicht geladen."):
		return
	var relief_tex: Texture2D = load("res://assets/map/generated/relief_shaded.png")
	if not _expect(relief_tex != null, "Generiertes Relief wurde nicht geladen."):
		return
	if not _expect(main.map_view.marker_textures_loaded(), "3D-Markertexturen wurden nicht geladen."):
		return
	if not _expect(main.map_view.marker_specs().size() == 9, "Es sind nicht neun Halte-/Königreichssitze markiert."):
		return
	print("MAPPERF assets relief=%s markers=%d" % [relief_tex.resource_path, main.map_view.marker_specs().size()])
	var map_rect: Rect2 = main.map_view.get_global_rect()
	print("MAPPERF env godot=%s renderer=%s adapter=%s window=%s viewport=%s map_rect=%s texture=%s vsync=%s" % [
		Engine.get_version_info().get("string", "?"),
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		DisplayServer.window_get_size(),
		get_viewport().get_visible_rect().size,
		map_rect.size,
		tex.get_size() if tex != null else Vector2.ZERO,
		DisplayServer.window_get_vsync_mode(),
	])

	await _run_measurement("overview-idle", false)
	await _run_measurement("overview-redraw", true)
	_bench_redraw = false
	await _shot("map-perf-overview")
	main.map_view.zoom_by(4.0)
	await get_tree().process_frame
	print("MAPPERF zoom value=%.2f pan=%s" % [main.map_view.zoom, main.map_view.pan])
	await _run_measurement("zoom4-idle", false)
	await _run_measurement("zoom4-redraw", true)
	var previous_pan: Vector2 = main.map_view.pan
	await _run_measurement("zoom4-pan", true, true)
	if not _expect(not main.map_view.pan.is_equal_approx(previous_pan), "Der Pan-Messlauf hat die tatsächliche Kartenkamera nicht bewegt."):
		return
	main.map_view.pan = previous_pan
	main.map_view._clamp_pan()
	main.map_view._sync_base_transform()
	main.map_view.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _expect(main.map_view.pan.is_equal_approx(previous_pan), "Der Pan-Messlauf verändert die anschließenden Screenshot- und Markerpositionen."):
		return
	_bench_redraw = false
	await _shot("map-perf-zoom4")
	# Sichtprüfung der Biomtextur bei voller Kartenauflösung.
	main.map_view.reset_view()
	main._set_map_mode("terrain")
	await get_tree().process_frame
	await _shot("map-perf-terrain-overview")
	main.map_view.zoom_by(4.0)
	await get_tree().process_frame
	await _shot("map-perf-terrain-zoom4")
	print("MAPPERF OK; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _process(delta: float) -> void:
	if main == null:
		return
	if _bench_pan:
		# Zeitbasierte Bewegung hält Baseline und Kandidat bei anderer FPS vergleichbar.
		main.map_view.pan += Vector2(24.0, -12.0) * delta
		main.map_view._clamp_pan()
		main.map_view._sync_base_transform()
	if _bench_redraw or _bench_pan:
		main.map_view.queue_redraw()

func _run_measurement(label: String, redraw: bool, pan_camera: bool = false) -> void:
	_bench_redraw = redraw
	_bench_pan = pan_camera
	main.map_view.queue_redraw()
	for i in WARMUP_FRAMES:
		await get_tree().process_frame
	_samples.clear()
	var sampled_pan_start: Vector2 = main.map_view.pan
	var started: int = Time.get_ticks_usec()
	var last: int = started
	while Time.get_ticks_usec() - started < int(SAMPLE_SECONDS * 1_000_000.0):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		_samples.append(float(now - last) / 1000.0)
		last = now
	var elapsed: float = float(last - started) / 1_000_000.0
	var fps: float = float(_samples.size()) / maxf(elapsed, 0.0001)
	if not _expect(_samples.size() > 0, "Keine Messframes für %s." % label):
		return
	if not _expect(elapsed > 0.0, "Keine Messzeit für %s." % label):
		return
	if not _expect(fps > 0.0, "Keine positive Bildrate für %s." % label):
		return
	_samples.sort()
	var p50: float = _percentile(50.0)
	var p95: float = _percentile(95.0)
	var p99: float = _percentile(99.0)
	print("MAPPERF %-16s zoom=%.2f redraw=%s frames=%d wall=%.3f fps=%.1f p50=%.2fms p95=%.2fms p99=%.2fms low1=%.1f draw_calls=%d primitives=%d pan=%s pan_distance=%.1f" % [
		label,
		main.map_view.zoom,
		"yes" if redraw else "no",
		_samples.size(),
		elapsed,
		fps,
		p50,
		p95,
		p99,
		1000.0 / maxf(p99, 0.001),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"yes" if pan_camera else "no",
		main.map_view.pan.distance_to(sampled_pan_start),
	])
	_bench_redraw = false
	_bench_pan = false
	var target_text := OS.get_environment("ATLAS_MIN_PAN_FPS")
	if pan_camera and not target_text.is_empty():
		var target_fps := target_text.to_float()
		if not _expect(target_fps > 0.0 and fps >= target_fps,
				"Echter Kartenschwenk erreicht %.1f statt mindestens %.1f FPS." % [fps, target_fps]):
			return

func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/verify"))
	print("MAPPERF capture start ", name)
	main.map_view.queue_redraw()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://build/verify/%s.png" % name
	var err := img.save_png(path)
	if not _expect(err == OK, "%s konnte nicht gespeichert werden (%d)." % [path, err]):
		return
	if not _expect(img.get_width() > 0, "%s hat keine Bildbreite." % path):
		return
	print("MAPPERF shot %s %dx%d" % [path, img.get_width(), img.get_height()])

func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_fail(message)
	return false

func _percentile(p: float) -> float:
	if _samples.is_empty():
		return 0.0
	var idx: int = clampi(int(round((p / 100.0) * float(_samples.size() - 1))), 0, _samples.size() - 1)
	return _samples[idx]

func _fail(msg: String) -> void:
	print("MAPPERF FAIL: " + msg)
	get_tree().quit(1)
