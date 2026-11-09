extends Node
## Verhindert Jahr null, doppelte Jahreswirkungen und Fristverlust beim Laden.
const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveScript = preload("res://scripts/SaveGame.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	seed(20261109)
	if OS.get_name() == "Windows":
		_check(OS.get_user_data_dir().replace("\\", "/").ends_with("/Godot/app_userdata/Kronen und Kriege"), "Umbenennung darf den bisherigen Save-Pfad nicht wechseln.")
	var g = GameScript.new(DataScript, 0)
	g.year = -1
	g.month = 12
	g._set_cooldown("calendar_probe", 2)
	g.advance_month()
	_check(g.year == 1 and g.month == 1, "Auf Dezember 1 v. Chr. muss Januar 1 n. Chr. folgen.")
	_check(g._cooldown_left("calendar_probe") == 1, "Frist über Jahresgrenze muss noch einen Monat laufen.")
	g.advance_month()
	_check(g._cooldown_left("calendar_probe") == 0, "Zweimonatsfrist endet im Februar 1 n. Chr.")
	if not g.has_method("calendar_index"):
		_check(false, "Game fehlt die gemeinsame Kalenderfunktion.")
		_finish()
		return
	var calendar = load("res://scripts/CampaignCalendar.gd")
	for row in [[-2000, 1, 0], [-1, 12, 23999], [1, 1, 24000], [2200, 12, 50399]]:
		_check(calendar.to_index(row[0], row[1]) == row[2], "Kalendergrenze stimmt nicht: %s" % str(row))
	for index in 50400:
		var date: Dictionary = calendar.from_index(index)
		if int(date.year) == 0 or calendar.to_index(int(date.year), int(date.month)) != index:
			_check(false, "Kalender-Roundtrip scheitert bei Monat %d." % index)
			break
	_check(calendar.to_index(0, 1) == -1 and calendar.to_index(1, 13) == -1, "Ungültiges Datum muss abgelehnt werden.")
	var snapshot: Dictionary = g.snapshot()
	_check(int(snapshot.month_index) == 24001, "Gespeicherter Index muss Februar 1 n. Chr. sein.")
	var restored = GameScript.new(DataScript, 0)
	_check(restored.restore(JSON.parse_string(JSON.stringify(snapshot))), "Kalenderstand nicht ladbar.")
	_check(SaveScript.diff(snapshot, restored.snapshot()).is_empty(), "Kalender-Roundtrip verändert Spielzustand.")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy["schema_version"] = 11
	legacy.erase("month_index")
	legacy.erase("calendar_version")
	legacy.erase("campaign_sandbox")
	legacy["year"] = 0
	legacy["month"] = 12
	legacy["cooldowns"] = {"calendar_probe": 24014}
	_check(restored.restore(legacy), "Altstand mit Jahr null wird nicht migriert.")
	_check(restored.year == 1 and restored.month == 12, "Altes Jahr null entspricht Jahr 1 n. Chr.")
	_check(restored._cooldown_left("calendar_probe") == 2, "Migration muss verbleibende Frist bewahren.")
	var broken: Dictionary = snapshot.duplicate(true)
	broken["month_index"] = 5
	_check(not SaveScript.validate(broken).is_empty(), "Widersprüchliche Kalenderdaten müssen abgewiesen werden.")
	g.year = 2200
	g.month = 12
	g.speed = 3
	g.advance_month()
	_check(g.year == 2200 and g.month == 12 and g.speed == 0, "Kampagnenende muss den Zeitlauf stoppen.")
	_check(bool(g.continue_sandbox()["ok"]), "Sandbox-Fortsetzung fehlt.")
	g.advance_month()
	_check(g.year == 2201 and g.month == 1, "Sandbox muss über 2200 hinauslaufen.")
	_check(bool(g.snapshot().campaign_sandbox), "Sandbox-Entscheidung muss gespeichert werden.")
	_finish()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("CAMPAIGNTEST FAIL: " + message)

func _finish() -> void:
	print("CAMPAIGNTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
