extends Node
const Game = preload("res://scripts/Game.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const Store = preload("res://scripts/SaveStore.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var g = Game.new(Regions,0)
	var current: Dictionary = g.snapshot()
	var old: Dictionary = current.duplicate(true)
	old.schema_version = 13
	for p in old.provinces:
		p.erase("economic_focus")
		p.erase("focus_changed_month")
	var raw := " \n" + JSON.stringify(old,"\t") + "\n"
	var stem := "user://focus-store-" + str(Time.get_ticks_usec())
	var load_path := stem + "-load.json"
	_write(load_path,raw)
	var loaded: Dictionary = Store.load_snapshot(load_path)
	check(loaded.ok and int(loaded.data.schema_version) == 14,"Regionaler Schema13-Spielstand wird vor Ladung auf14 gehoben")
	check(loaded.backup != "" and FileAccess.get_file_as_string(str(loaded.backup)) == raw,"Regionaler Altstand erhält bytegleiche Sicherung samt Leerraum")
	check(FileAccess.get_file_as_string(load_path) == raw,"Prüfung und Migration überschreiben Quelle nicht")
	var direct_path := stem + "-direct.json"
	_write(direct_path,raw)
	check(Store.write_snapshot(direct_path,current),"Direktes Speichern eines aktuellen Stands über Schema13 ist möglich")
	check(FileAccess.file_exists(direct_path + ".pre-schema-v13.bak") and FileAccess.get_file_as_string(direct_path + ".pre-schema-v13.bak") == raw,"Auch direktes Speichern sichert unveränderte alte Regionaldatei vor Überschreiben")
	var invalid: Dictionary = current.duplicate(true)
	invalid.provinces[0].economic_focus = "unknown"
	var before := FileAccess.get_file_as_bytes(direct_path)
	check(not Store.write_snapshot(direct_path,invalid) and FileAccess.get_file_as_bytes(direct_path) == before,"Ungültiger neuer Stand lässt bestehende Datei unverändert")
	var blocked_path := stem + "-blocked.json"
	_write(blocked_path,raw)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked_path + ".pre-schema-v13.bak"))
	check(not Store.load_snapshot(blocked_path).ok and FileAccess.get_file_as_string(blocked_path) == raw,"Gescheiterte Sicherung verhindert Laden ohne Quellenänderung")
	check(not Store.write_snapshot(blocked_path,current) and FileAccess.get_file_as_string(blocked_path) == raw,"Gescheiterte Sicherung verhindert auch direktes Überschreiben")
	var collision_path := stem + "-collision.json"
	_write(collision_path,raw)
	_write(collision_path + ".pre-schema-v13.bak","fremde Sicherung")
	var collision: Dictionary = Store.load_snapshot(collision_path)
	check(collision.ok and FileAccess.get_file_as_string(collision_path + ".pre-schema-v13.bak") == "fremde Sicherung","Vorhandene fremde Sicherung wird nicht ersetzt")
	check(collision.backup != collision_path + ".pre-schema-v13.bak" and FileAccess.get_file_as_string(str(collision.backup)) == raw,"Kollision erhält zweite bytegleiche Sicherung mit Inhaltskennung")
	print("PROVINCEECONOMYSTORETEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)

func _write(path: String,value: String) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(value)
	f.close()

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PROVINCEECONOMYSTORETEST FAIL: " + message)
