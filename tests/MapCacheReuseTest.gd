extends Node
class CountingMap extends "res://scripts/MapView.gd":
	var builds := 0
	func _rebuild_edge_cache() -> void:
		builds += 1
		super._rebuild_edge_cache()

func _ready() -> void:
	var map := CountingMap.new()
	var game = load("res://scripts/Game.gd")
	var regions = load("res://scripts/GameRegionData.gd")
	var first = game.new(regions, 0)
	var next = game.new(regions, 0)
	if not next.restore(first.snapshot()):
		print("MAPCACHEREUSETEST FAIL: gültiger Folgezustand fehlt")
		get_tree().quit(1)
		return
	var started := Time.get_ticks_msec()
	map.set_game(first)
	var cold_ms := Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	map.set_game(next)
	var warm_ms := Time.get_ticks_msec() - started
	print("MAPCACHE_TIMING cold_ms=%d snapshot_ms=%d builds=%d" % [cold_ms, warm_ms, map.builds])
	if map.builds != 1:
		print("MAPCACHEREUSETEST FAIL: identischer unveränderlicher Katalog wird beim Snapshot erneut aufgebaut")
		map.free()
		get_tree().quit(1)
		return
	map.set_game(game.new(load("res://scripts/Data.gd"), 0))
	if map.builds != 2:
		print("MAPCACHEREUSETEST FAIL: Layoutwechsel verwirft Cache nicht")
		map.free()
		get_tree().quit(1)
		return
	map.free()
	print("MAPCACHEREUSETEST OK: 3 Prüfungen")
	get_tree().quit(0)
