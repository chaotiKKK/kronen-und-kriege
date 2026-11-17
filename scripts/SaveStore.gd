extends RefCounted
## Validate first; preserve the original bytes before the first layout migration.
const Save = preload("res://scripts/SaveGame.gd")
const Migration = preload("res://scripts/RegionMigration.gd")

static func load_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false,"message":"Kein Spielstand gefunden."}
	var raw := FileAccess.get_file_as_bytes(path)
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok":false,"message":"Der Spielstand ist beschädigt."}
	var normalized: Dictionary = Save.migrate(parsed)
	if not bool(normalized.ok):
		return {"ok":false,"message":"; ".join(normalized.errors)}
	var result: Dictionary = Migration.migrate_state(normalized.data)
	if not bool(result.ok):
		return {"ok":false,"message":"; ".join(result.errors)}
	var errors := Save.validate(result.data)
	if not errors.is_empty():
		return {"ok":false,"message":"; ".join(errors)}
	var backup := ""
	if str(parsed.get("world_layout", "")) != "regions108":
		backup = path + ".pre-regions-v12.bak"
		if FileAccess.file_exists(backup) and FileAccess.get_file_as_bytes(backup) != raw:
			var context := HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			context.update(raw)
			backup = path + ".pre-regions-" + context.finish().hex_encode().substr(0,16) + ".bak"
		if not FileAccess.file_exists(backup):
			var file := FileAccess.open(backup, FileAccess.WRITE)
			if file == null:
				return {"ok":false,"message":"Die Sicherung des ursprünglichen Spielstands konnte nicht angelegt werden."}
			file.store_buffer(raw)
			file.flush()
			file.close()
		if FileAccess.get_file_as_bytes(backup) != raw:
			return {"ok":false,"message":"Die Spielstandsicherung konnte nicht bestätigt werden."}
	return {"ok":true,"data":result.data,"backup":backup,"message":""}

static func write_snapshot(path: String, state: Dictionary) -> bool:
	if not Save.validate(state).is_empty():
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK
