extends Node
## Prüft, dass jedes der acht Ereignisse eine eigene, vorhandene Bilddatei lädt
## und dass ein fehlendes Bild auf den Vektor-Fallback ausweicht.
## Aufruf: godot --headless --path . res://tests/EventArtTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const MainScene = preload("res://scenes/Main.tscn")

var _checks: int = 0
var _failed: bool = false
var _seen_keys: Dictionary = {}
var _seen_files: Dictionary = {}


func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start(0)
	for i in 8:
		await get_tree().process_frame

	var events: Array = DataScript.events()
	_check(events.size() == 8, "acht Ereignisse erwartet, gefunden %d" % events.size())
	_check(main.EVENT_ART_KEYS.size() == 8, "acht Zuordnungen erwartet, gefunden %d" % main.EVENT_ART_KEYS.size())
	_check(main.EVENT_ARTS.size() == 8, "acht geladene Ereignisbilder erwartet, gefunden %d" % main.EVENT_ARTS.size())

	var manifest_text := FileAccess.get_file_as_string("res://assets/asset_manifest.json")
	var parsed = JSON.parse_string(manifest_text)
	_check(parsed is Dictionary, "Asset-Manifest nicht lesbar")
	var open_list: Array = []
	var event_files: Array = []
	if parsed is Dictionary:
		open_list = parsed.get("open", [])
		event_files = parsed.get("families", {}).get("events", {}).get("files", [])
	_check(open_list.is_empty(), "Manifest-Offenliste ist nicht leer: %s" % str(open_list))
	_check(event_files.size() == 8, "acht Ereignisdateien im Manifest erwartet, gefunden %d" % event_files.size())

	for key in main.EVENT_ART_KEYS.values():
		_check(not _seen_keys.has(str(key)), "Bildschlüssel doppelt: %s" % str(key))
		_seen_keys[str(key)] = true

	for ev in events:
		var id: String = str(ev.get("id", ""))
		var key: String = str(main.EVENT_ART_KEYS.get(id, ""))
		_check(key != "", "Ereignis ohne Bildzuordnung: %s" % id)
		if key == "":
			continue
		var path: String = "res://assets/ui/events/%s.png" % key
		_check(FileAccess.file_exists(path), "Bilddatei fehlt: %s -> %s" % [id, path])
		_check(not _seen_files.has(key), "Bilddatei doppelt zugeordnet: %s" % key)
		_seen_files[key] = true
		_check(main.EVENT_ARTS.has(key), "Bild nicht im Cache: %s" % key)
		var tex = load(path)
		_check(tex != null, "Bild nicht ladbar: %s" % path)
		if tex != null:
			_check(tex.resource_path == path, "falscher Bildpfad: %s" % tex.resource_path)

	for ev in events:
		var id: String = str(ev.get("id", ""))
		var key: String = str(main.EVENT_ART_KEYS.get(id, ""))
		var path: String = "res://assets/ui/events/%s.png" % key
		main.game.pending_event = ev
		main._show_event()
		await get_tree().process_frame
		_check(main.event_art.texture != null, "Ereignis ohne sichtbares Bild: %s" % id)
		_check(main.event_art.visible, "Textur nicht sichtbar: %s" % id)
		_check(not main.event_art_fallback.visible, "Fallback trotz Bild sichtbar: %s" % id)
		if main.event_art.texture != null:
			_check(main.event_art.texture.resource_path == path,
				"falsches Bild für %s: %s" % [id, main.event_art.texture.resource_path])
		main._hide_event()

	# Fehlendes Bild und unbekannte Ereignis-ID müssen den Vektor-Fallback zeigen.
	main._apply_event_art("event_gibt_es_nicht")
	_check(main.event_art.texture == null, "fehlendes Bild lieferte eine Textur")
	_check(not main.event_art.visible, "fehlendes Bild ließ die Textur sichtbar")
	_check(main.event_art_fallback.visible, "Vektor-Fallback blieb unsichtbar")
	main._apply_event_art("")
	_check(main.event_art_fallback.visible, "leerer Schlüssel zeigte keinen Vektor-Fallback")

	if _failed:
		get_tree().quit(1)
		return
	print("EVENTARTTEST OK: 8 Ereignisse, 8 eindeutige Bilddateien, 8 Cache-Treffer, Vektor-Fallback aktiv; %d Prüfungen." % _checks)
	get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failed = true
	print("EVENTARTTEST FAIL: " + message)
