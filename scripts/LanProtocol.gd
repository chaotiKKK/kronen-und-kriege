extends RefCounted
## Kleines, ausdrücklich typisiertes LAN-Protokoll. Keine Objektdekodierung.

const VERSION := 1
const GAME_PORT := 28741
const DISCOVERY_PORT := 28740
const MAX_PLAYERS := 4
const MAX_PACKET_BYTES := 2097152
const MAX_COMMAND_BYTES := 4096
const Save = preload("res://scripts/SaveGame.gd")
const PERSONAL_FIELDS := ["player", "opinion", "cooldowns", "captive", "scandal", "event_timer",
	"event_instance", "pending", "game_over", "victory", "history", "log", "lan_contexts", "lan_projection"]
const FIELDS := {
	"continue_sandbox":{}, "develop":{}, "recruit":{}, "attack":{}, "court":{}, "bed":{},
	"ransom":{}, "force_marry":{}, "law_succession":{}, "set_tax":{}, "upgrade_court_hall":{},
	"pilgrimage":{}, "suppress_heresy":{}, "reform_faith":{}, "claim":{}, "army":{},
	"siege":{}, "fleet":{}, "blockade":{}, "peace":{}, "secret_discover":{}, "secret_expose":{},
	"research":{"innovation":"text"}, "road":{"to":"text"}, "build":{"key":"text"},
	"marry":{"target":"house"}, "seduce":{"target":"house"}, "murder":{"target":"house"},
	"kidnap":{"target":"house"}, "declare_holy_war":{"target":"house"},
	"apply_event":{"option":"option", "event_instance":"sequence"},
	"set_speed":{"value":"speed"}, "council_assign":{"office":"text", "index":"optional_index"},
	"legacy":{"track":"text"}, "vassal_contract":{"vassal":"index", "level":"level"},
	"council_resolution":{"resolution":"text"}, "forge_relic":{"relic":"text"},
	"upgrade_court_amenity":{"amenity":"text"}, "consecrate_site":{"province":"text"},
	"convert_faith":{"confession":"text"},
}

static func integer(value, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func validate_command(command: Dictionary) -> Dictionary:
	if command.size() > 8 or not _json_safe(command, 0) or JSON.stringify(command).to_utf8_buffer().size() > MAX_COMMAND_BYTES:
		return failure("Ungültiger oder zu großer Spielbefehl.")
	var id = command.get("id")
	if not id is String or not FIELDS.has(id):
		return failure("Unbekannter WLAN-Spielbefehl.")
	var fields: Dictionary = FIELDS[id]
	for key in command:
		if key != "id" and key != "selection" and not fields.has(key):
			return failure("Nicht erlaubtes Befehlsfeld: %s." % str(key))
	var selection = command.get("selection", "")
	if not selection is String or selection.length() > 80:
		return failure("Ungültige Provinzauswahl.")
	var clean := {"id":id, "selection":selection}
	for key in fields:
		var kind: String = fields[key]
		if kind == "optional_index" and not command.has(key):
			continue
		if not command.has(key):
			return failure("Fehlendes Befehlsfeld: %s." % key)
		var value = command[key]
		if kind == "text":
			if not value is String or value.is_empty() or value.length() > 80 or "\n" in value:
				return failure("Ungültiger Bezeichner: %s." % key)
			clean[key] = value
		else:
			var bounds: Array = {"house":[0,255], "index":[0,127], "optional_index":[-1,127],
				"option":[0,31], "sequence":[0,2147483647], "speed":[0,3], "level":[0,2]}[kind]
			if not integer(value, bounds[0], bounds[1]):
				return failure("Ungültiger Zahlenwert: %s." % key)
			clean[key] = int(value)
	return {"ok":true, "code":"ok", "message":"", "command":clean}

static func encode_packet(message: Dictionary) -> PackedByteArray:
	if not _json_safe(message, 0):
		return PackedByteArray()
	var raw := JSON.stringify(message).to_utf8_buffer()
	return raw if raw.size() <= MAX_PACKET_BYTES else PackedByteArray()

static func decode_packet(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size() > MAX_PACKET_BYTES:
		return failure("Ungültige Paketgröße.")
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return failure("Die Netzwerknachricht ist beschädigt.")
	var value = json.data
	if not value is Dictionary or value.size() > 16 or not _json_safe(value, 0):
		return failure("Ungültige Netzwerknachricht.")
	if not integer(value.get("v"), 1, 65535) or not value.get("type") is String or value.type.length() > 32:
		return failure("Unbekanntes Nachrichtenformat.")
	return {"ok":true, "message":value}

static func handshake_error(message: Dictionary, app: String, fingerprint: String) -> String:
	if not integer(message.get("v"), VERSION, VERSION):
		return "Die WLAN-Protokollversionen passen nicht zusammen."
	if message.get("app") != app:
		return "Die Spielversionen unterscheiden sich. Bitte dieselbe Version verwenden."
	if message.get("fingerprint") != fingerprint:
		return "Die Spieldaten unterscheiden sich. Bitte dieselbe vollständige Fassung verwenden."
	return ""

static func world_hash(state: Dictionary) -> String:
	var shared := state.duplicate(true)
	for field in PERSONAL_FIELDS:
		shared.erase(field)
	for house in shared.get("houses", []):
		if house is Dictionary:
			house.erase("crest_file")
	return JSON.stringify(Save.canonical(shared)).sha256_text()

static func failure(message: String, code: String = "invalid") -> Dictionary:
	return {"ok":false, "code":code, "message":message, "delta":{}, "refresh":[]}

static func _json_safe(value, depth: int) -> bool:
	if depth > 18:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			return value.length() <= 32768
		TYPE_ARRAY:
			if value.size() > 20000:
				return false
			for item in value:
				if not _json_safe(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 256:
				return false
			for key in value:
				if not key is String or key.length() > 96 or not _json_safe(value[key], depth + 1):
					return false
			return true
	return false
