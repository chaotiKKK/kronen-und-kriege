extends Node
var checks := 0
var failures := 0
var host
var guest

func _ready() -> void:
	var session = load("res://scripts/LanSession.gd")
	host = session.new()
	guest = session.new()
	host.discovery_enabled = false
	guest.discovery_enabled = false
	add_child(host)
	add_child(guest)
	if not host.has_method("submit_design"):
		check(false, "Angenommene Hausentwürfe fehlen in der Lobby")
		finish()
		return
	var design = load("res://scripts/HouseDesign.gd")
	var data = load("res://scripts/GameRegionData.gd")
	var regions: Array = data.provinces()
	var home_a := ""
	var home_b := ""
	for region in regions:
		if int(region.owner) == 2 and home_a == "": home_a = region.id
		if int(region.owner) == 3 and home_b == "": home_b = region.id
	var port := 49000 + OS.get_process_id() % 700
	check(host.host("Designer", "Host", 0, port).ok, "Eigene Hostlobby")
	check(guest.join("127.0.0.1", "Gast", port).ok, "Gast verbindet")
	check(await until(func(): return guest.phase == "lobby" and host.players.size() == 2), "Zwei echte Teilnehmer")
	var a: Dictionary = design.defaults(data, home_a)
	a.house = "Haus Kupfer"
	a.ruler = "Ada"
	a.portrait = 17
	a.doctrine = "infantry"
	check(host.submit_design(a).ok, "Host nimmt eigenen Entwurf an")
	var stolen := a.duplicate(true)
	for region in regions:
		if int(region.owner) == 1:
			stolen.province = region.id
			break
	check(not host.submit_design(stolen).ok and host.players[1].design.province == home_a, "Entwurf stiehlt kein Startgebiet eines vorhandenen Menschenhauses")
	check(await until(func(): return not guest.players[1].get("design", {}).is_empty()), "Angenommener Hostentwurf wird verteilt")
	var b := a.duplicate(true)
	b.house = "Haus Silber"
	guest.submit_design(b)
	await get_tree().create_timer(0.1).timeout
	check(host.players[guest.local_peer_id].get("design", {}).is_empty(), "Doppelte Heimat wird nicht angenommen")
	b.province = home_b
	b.ruler = "Bea"
	b.doctrine = "cavalry"
	check(guest.submit_design(b).ok, "Gast sendet gültigen Entwurf")
	check(await until(func(): return host.players[guest.local_peer_id].get("design", {}).get("house", "") == "Haus Silber"), "Host nimmt Gastentwurf an")
	guest.set_ready(true)
	check(await until(func(): return host.players[guest.local_peer_id].ready), "Gast bereit")
	b.ruler = "Bea II"
	guest.submit_design(b)
	check(await until(func(): return host.players[guest.local_peer_id].get("design", {}).get("ruler", "") == "Bea II"), "Geänderter Entwurf bestätigt")
	check(not host.players[guest.local_peer_id].ready, "Änderung nimmt Bereitschaft zurück")
	guest.set_ready(true)
	check(await until(func(): return host.players[guest.local_peer_id].ready), "Gast erneut bereit")
	check(host.start_match().ok, "Eigene Häuser starten")
	check(await until(func(): return guest.phase == "playing"), "Gast erhält neue dynamische Haus-ID")
	check(host.game.houses.size() == 11 and host.game.human_houses == [9,10], "Neun NPC-Häuser und zwei neue Menschenhäuser")
	check(host.game.houses[9].name == "Haus Kupfer" and host.game.houses[10].ruler.name == "Bea II", "Beide Entwürfe tatsächlich angewandt")
	check(host.game.houses[9].ruler.portrait == 17 and host.game.houses[9].doctrine == "infantry" and host.game.houses[10].doctrine == "cavalry", "Porträt und Armeedoktrin übernommen")
	check(host.game.province(home_a).owner == 9 and host.game.province(home_b).owner == 10, "Eindeutige Heimatzuordnung")
	check(host.game.houses[9].gold == 150 and host.game.houses[10].gold == 150, "Gleiches Gründungsbudget")
	check(load("res://scripts/LanProtocol.gd").world_hash(host.game.snapshot()) == load("res://scripts/LanProtocol.gd").world_hash(guest.game.snapshot()), "Weltgleichheit trotz verschiedener Perspektiven")
	var replies: Array = []
	guest.command_finished.connect(func(result): replies.append(result))
	guest.submit({"id":"army","selection":home_b})
	check(await until(func(): return not guest.pending_command and host.game.houses[10].armies.size() == 1), "Echter Gast stellt eigene Feldarmee auf")
	# Ein älterer gespeicherter Stand kann mehrere bestehende Feldarmeen enthalten.
	host.game.houses[10].armies.append({"id":7,"province":home_b,"strength":212,"upkeep":1,"morale":100})
	host.revision += 1
	host._broadcast_snapshot()
	check(await until(func(): return guest.game.houses[10].armies.size() == 2), "Legacy-Mehrarmee-Zustand erreicht den Gast")
	var selection_gold := int(host.game.houses[10].gold)
	guest.submit({"id":"select_army","army":7})
	check(await until(func(): return not guest.pending_command and int(host.game.houses[10].armies[0].id) == 7), "Armeewahl durchläuft echte Hostautorität")
	check(guest.game.houses[10].armies[0].id == 7 and host.game.houses[10].gold == selection_gold and host.game.houses[10].armies[0].strength == 212, "Bestätigte Auswahl erhält Truppen und Ressourcen")
	guest.submit({"id":"select_army","army":1})
	check(await until(func(): return not guest.pending_command and int(host.game.houses[10].armies[0].id) == 1), "Gast kann vor dem Marsch sein ursprüngliches Heer wählen")
	var border := str(host.game.neighbours(home_b)[0])
	guest.submit({"id":"claim","selection":border})
	check(await until(func(): return not guest.pending_command and host.game.has_claim(border,10)), "Echter Gast erhält Anspruch auf angrenzendes Marschziel")
	guest.submit({"id":"march","selection":border})
	check(await until(func(): return not guest.pending_command and str(host.game.houses[10].armies[0].province) == border), "Marsch durchläuft echte Hostautorität")
	check(guest.game.houses[10].armies[0].province == border and host.game.houses[9].armies.is_empty(), "Gast-Snapshot zeigt Bewegung nur des eigenen Heeres")
	var acknowledgements := replies.size()
	guest.submit({"id":"siege","selection":border})
	check(await until(func(): return not guest.pending_command and replies.size() > acknowledgements), "Belagerung im Marschmonat wird beantwortet")
	check(not bool(replies[-1].ok) and int(host.game.province(border).siege) == 0, "Marsch und Belagerung teilen die monatliche Aktionsgrenze")
	var path := "user://designer-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(host.save_host(path).ok, "Eigene Häuser gespeichert")
	check(host.return_to_lobby().ok, "Wiederaufnahmelobby")
	check(await until(func(): return guest.phase == "lobby" and guest.is_resuming()), "Gast erhält dynamischen Fortsetzungskatalog")
	check(guest.house_catalog().size() == 11 and guest.local_house() == 10, "Eigene Haus-ID in Lobby erhalten")
	check(not host.submit_design(a).ok, "Designer bei Fortsetzung gesperrt")
	guest.set_ready(true)
	check(await until(func(): return host.players[guest.local_peer_id].ready), "Fortsetzung bereit")
	check(host.start_match().ok, "Eigene Häuser wiederaufgenommen")
	check(host.game.houses.size() == 11, "Fortsetzung gründet keine zusätzlichen Häuser")
	check(host.return_to_lobby().ok, "Lokale Ladeprüfung in Lobby")
	var source_bytes := FileAccess.get_file_as_bytes(path)
	var source: Dictionary = JSON.parse_string(source_bytes.get_string_from_utf8())
	check(int(source.state.schema_version)==load("res://scripts/SaveGame.gd").CURRENT_VERSION and int(source.state.schema_version)>=15, "Quelle ist die tatsächlich erzeugte aktuelle Designer-Testpartie, keine historische Originaldatei")
	# Explicitly controlled, derived compatibility fixture. It is not genuine
	# 1.8 provenance: the old regional family supports source schemas13/14.
	var old := source.duplicate(true)
	old.v = 2
	old.app = "1.8.0"
	old.fingerprint = "controlled-derived-regional-schema14"
	old.state.schema_version = 14
	var no_new_markers := true
	for house in old.state.houses:
		for fleet in house.fleets:
			if fleet.has("last_naval_month"):
				if int(fleet.last_naval_month)!=-1: no_new_markers = false
				else: fleet.erase("last_naval_month")
	var historical_ids: Array = []
	for id in old.state.lan_human_houses: historical_ids.append(int(id))
	check(no_new_markers and int(old.state.schema_version)==14 and old.state.houses.size()==11 and historical_ids==[9,10], "Kontrollierte abgeleitete Schema14-Quelle erhält elf echte Designerhäuser und die Menschen-IDs9/10")
	# Merely relabelling the current schema as an older app must still fail.
	var relabelled := source.duplicate(true)
	relabelled.v = 2
	relabelled.app = "1.8.0"
	relabelled.fingerprint = "controlled-relabelled-current"
	var bad_path := path+".relabelled-current-v2"
	var bad_raw := JSON.stringify(relabelled).to_utf8_buffer()
	var bad_file := FileAccess.open(bad_path,FileAccess.WRITE)
	bad_file.store_buffer(bad_raw)
	bad_file.close()
	var live: Dictionary = host.game.snapshot()
	check(not host.load_host_lobby(bad_path).ok and not host.save_host(bad_path).ok, "Nur umetikettierte Schema15-Datei wird beim lokalen Laden und direkten Überschreiben abgewiesen")
	check(FileAccess.get_file_as_bytes(bad_path)==bad_raw and not FileAccess.file_exists(bad_path+".pre-design-v2.bak") and host.game.snapshot()==live, "Abgewiesene Schema15-Umetikettierung erhält Originalbytes und lebende Welt ohne historisches Backup")
	var old_path := path + ".old-v2"
	var raw := JSON.stringify(old).to_utf8_buffer()
	var old_file := FileAccess.open(old_path, FileAccess.WRITE)
	old_file.store_buffer(raw)
	old_file.close()
	check(host.load_host_lobby(old_path).ok, "Kontrollierte abgeleitete lokale1.8-Schema14-Datei trotz neuem Drahtprotokoll ladbar")
	check(FileAccess.get_file_as_bytes(old_path)==raw and FileAccess.get_file_as_bytes(old_path + ".pre-design-v2.bak") == raw, "Kontrollierte Schema14-Testdatei bleibt original und wird bytegleich gesichert")
	check(host.game.houses.size() == 11 and host.game.human_houses == [9,10] and host.game.houses[9].name=="Haus Kupfer" and host.game.houses[10].ruler.name=="Bea II", "Lokales Laden erhält elf Häuser, beide Menschen-IDs und tatsächlich angenommene Entwürfe")
	check(FileAccess.get_file_as_bytes(path)==source_bytes, "Die zugrunde liegende aktuelle Designer-Speicherdatei wird nicht als Historie umgeschrieben")
	finish()

func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 6500
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await get_tree().create_timer(0.02).timeout
	return condition.call()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("LANDESIGNERTEST FAIL: " + message)

func finish() -> void:
	if host != null: host.close_session()
	if guest != null: guest.close_session()
	print("LANDESIGNERTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
