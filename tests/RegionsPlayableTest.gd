extends Node
const Legacy = preload("res://scripts/Data.gd")
const Game = preload("res://scripts/Game.gd")
const Save = preload("res://scripts/SaveGame.gd")
var checks := 0
var main

func _ready() -> void:
	seed(1800)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start(7)
	if not check(main.game.provinces.size() == 108, "Regulärer Menüstart nutzt 108 Regionen"):
		return
	if not check(main.game.snapshot().get("world_layout", "") == "regions108", "Neuer Spielstand ist an Regionslayout gebunden"):
		return
	var berlin: Array = main.map_view.atlas_data.search("Berlin", 4)
	if not check(not berlin.is_empty(), "Ortsuche enthält Berlin"):
		return
	main.map_view.focus_atlas_location(berlin[0])
	if not check(not main.game.province(main.selected).is_empty(), "Atlas-Ortsuche wählt die neue Spielregion aus"):
		return
	var fit: Array = main.map_view._fit()
	main.map_view._pick_at(berlin[0].point * float(fit[0]) + fit[1])
	if not check(not main.game.province(main.selected).is_empty(), "Tippen auf einen Ortsanker wählt die neue Spielregion"):
		return
	var old: Dictionary = Game.new(Legacy, 0).snapshot()
	old.schema_version = 12
	var raw := JSON.stringify(old)
	var path := "user://spielstand.json"
	var primary_backup := path + ".pre-regions-v12.bak"
	var had_primary := FileAccess.file_exists(primary_backup)
	var primary_before := FileAccess.get_file_as_bytes(primary_backup) if had_primary else PackedByteArray()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(raw)
	f.close()
	if not check(main._load(), "Alter vollständiger Spielstand regulär geladen"):
		return
	if not check(main.game.provinces.size() == 108, "Altpartie spielt auf 108 Regionen weiter"):
		return
	var backup_path := ""
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with("spielstand.json.pre-regions") and filename.ends_with(".bak"):
			if FileAccess.get_file_as_bytes("user://"+filename) == raw.to_utf8_buffer():
				backup_path = "user://"+filename
	if not check(not backup_path.is_empty(), "Bytegleiche Altstand-Sicherung vorhanden"):
		return
	if not check(not had_primary or FileAccess.get_file_as_bytes(primary_backup) == primary_before, "Vorhandene fremde Altstandsicherung bleibt unverändert"):
		return
	if not check(bool(main._save().ok), "Migrierter Stand regulär gespeichert"):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(int(saved.schema_version) == Save.CURRENT_VERSION and saved.region_catalog_hash.length() == 64, "Aktueller Stand trägt Schema und Kataloghash"):
		return
	main._show_create()
	main.edit_ruler.text = "Ari Test"
	main.edit_house.text = "Haus Regionen"
	main.create_home.select(0)
	main._create_begin()
	if not check(main.game.custom_start and str(main.game.house().ruler.name) == "Ari Test" and main.game.provinces.size() == 108, "Eigener Charakter und regulärer Spielstart"):
		return
	for index in 18:
		if main.game.pending_event != null:
			main.game.apply_event(0)
		main.game.advance_month()
	if not check(not main.game.game_over and main.game.calendar_index() == 18, "Neue Charakterpartie 18 Monate spielbar"):
		return
	if not check(bool(main._save().ok) and main._load(), "Charakterpartie speicher- und ladbar"):
		return
	if not check(main.game.calendar_index() == 18 and str(main.game.house().ruler.name) == "Ari Test", "Laden erhält Charakter und Zeit"):
		return
	var gold := int(main.game.house().gold)
	saved = main.game.snapshot()
	saved.region_catalog_hash = "kaputt"
	if not check(not main.game.restore(saved) and int(main.game.house().gold) == gold and main.game.provinces.size() == 108, "Fremder Katalog ändert keine laufende Partie"):
		return
	var store = load("res://scripts/SaveStore.gd")
	var before := FileAccess.get_file_as_bytes(path)
	if not check(not store.write_snapshot(path, saved) and FileAccess.get_file_as_bytes(path) == before, "Ungültiges Speichern erhält vorhandene Originaldatei"):
		return
	old.houses[0].gold += 17
	var different_raw := JSON.stringify(old)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(different_raw)
	f.close()
	var second: Dictionary = store.load_snapshot(path)
	if not check(bool(second.ok) and str(second.backup) != backup_path, "Zweiter Altstand bekommt eigene Sicherung"):
		return
	if not check(FileAccess.get_file_as_string(backup_path) == raw and FileAccess.get_file_as_string(second.backup) == different_raw, "Beide Altstände bytegleich erhalten"):
		return
	if not check(FileAccess.get_file_as_string(path) == different_raw, "Laden überschreibt den Altstand nicht vor ausdrücklich gewähltem Speichern"):
		return
	print("REGIONSPLAYABLETEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	print("REGIONSPLAYABLETEST FAIL: " + message)
	get_tree().quit(1)
	return false
