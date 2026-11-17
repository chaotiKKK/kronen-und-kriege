extends RefCounted
## Gemeinsamer, rein datenbasierter Startentwurf. Keine Ressourcenpfade oder freien Budgets.
const VERSION := 1
const MAX_BYTES := 2048
const PORTRAITS := 48
const CRESTS := 9
const COLORS := 9
const STATS := ["martial", "diplomacy", "stewardship", "intrigue"]
const DOCTRINES := ["balanced", "infantry", "cavalry", "siege"]
const FIELDS := ["design_version", "ruler", "house", "land", "province", "gender", "age", "portrait", "crest", "color", "martial", "diplomacy", "stewardship", "intrigue", "doctrine"]

static func defaults(data, province_id: String = "") -> Dictionary:
	var provinces: Array = data.provinces()
	return {"design_version":VERSION, "ruler":"Ari", "house":"Haus Neu", "land":"", "province":province_id if province_id != "" else str(provinces[0].id), "gender":"m", "age":25, "portrait":0, "crest":0, "color":0, "martial":6, "diplomacy":6, "stewardship":6, "intrigue":6, "doctrine":"balanced"}

static func catalog(data) -> Array:
	var result: Array = []
	for province in data.provinces():
		result.append({"id":str(province.id), "name":str(province.name), "owner":int(province.owner)})
	return result

static func validate(profile: Dictionary, data) -> Dictionary:
	if profile.size() != FIELDS.size():
		return _failure("Der Hausentwurf ist unvollständig oder enthält unerlaubte Zusatzfelder.")
	for key in profile:
		if not key is String or not FIELDS.has(key):
			return _failure("Unerlaubtes Feld im Hausentwurf.")
	for key in ["ruler", "house", "land", "province", "gender", "doctrine"]:
		if not profile.get(key) is String:
			return _failure("Ungültiger Text im Hausentwurf: " + key)
		var value: String = profile[key]
		if value.length() > (80 if key == "province" else 48):
			return _failure("Ein Text im Hausentwurf ist zu lang.")
		for index in value.length():
			if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
				return _failure("Steuerzeichen sind im Hausentwurf nicht zulässig.")
	if profile.ruler.strip_edges().is_empty() or profile.house.strip_edges().is_empty():
		return _failure("Bitte einen Herrscher- und Hausnamen eingeben.")
	if not profile.gender in ["m", "f"] or not DOCTRINES.has(profile.doctrine):
		return _failure("Unbekanntes Geschlecht oder unbekannte Armeedoktrin.")
	var bounds := {"design_version":[VERSION,VERSION], "age":[16,90], "portrait":[0,PORTRAITS-1], "crest":[0,CRESTS-1], "color":[0,COLORS-1]}
	for key in STATS:
		bounds[key] = [3,20]
	var total := 0
	for key in bounds:
		var value = profile.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) < bounds[key][0] or float(value) > bounds[key][1]:
			return _failure("Ungültiger Zahlenwert im Hausentwurf: " + key)
		if STATS.has(key):
			total += int(value)
	if total > 44:
		return _failure("Die vier Charakterwerte dürfen zusammen höchstens 44 Punkte ergeben.")
	var found := false
	for province in data.provinces():
		if str(province.id) == profile.province:
			found = true
			break
	if not found:
		return _failure("Die gewählte Heimatregion ist unbekannt.")
	if JSON.stringify(profile).to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Der Hausentwurf ist zu groß.")
	var clean := profile.duplicate(true)
	for key in bounds:
		clean[key] = int(clean[key])
	for key in ["ruler", "house", "land"]:
		clean[key] = str(clean[key]).strip_edges()
	return {"ok":true, "profile":clean, "message":""}

static func _failure(message: String) -> Dictionary:
	return {"ok":false, "profile":{}, "message":message}
