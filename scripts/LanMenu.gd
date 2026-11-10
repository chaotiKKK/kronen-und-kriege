extends Control
## Deutsche, rollbare WLAN-Lobby. Die festen Aktionen bleiben erreichbar.

const Appearance = preload("res://scripts/ModernInterface.gd")
var main
var session
var card: PanelContainer
var scroll: ScrollContainer
var body: VBoxContainer
var nickname: LineEdit
var room_name: LineEdit
var address: LineEdit
var port_box: SpinBox
var house_picker: OptionButton
var status_label: Label
var players_label: Label
var address_label: Label
var rooms_box: VBoxContainer
var back_button: Button
var start_button: Button
var ready_button: Button
var host_button: Button
var join_button: Button
var resume_button: Button
var save_button: Button
var lobby_button: Button
var _updating := false
var _room_signature := ""

func install(owner, network) -> void:
	main = owner
	session = network
	name = "LanMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.025, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 20
	card.offset_top = 20
	card.offset_right = -20
	card.offset_bottom = -20
	card.add_theme_stylebox_override("panel", Appearance.surface(Appearance.PANEL, 16))
	add_child(card)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	card.add_child(layout)
	layout.add_child(main._label("Gemeinsam im WLAN", 26, Appearance.TEXT))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var intro: Label = main._label("Ein Gerät hostet. Zwei bis vier Spieler führen jeweils ein eigenes Haus. Alle Geräte benötigen dieselbe Spielversion und dieselben Daten.", 15)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	status_label = _text("")
	address_label = _text("")
	nickname = _field("Dein Spielername", "Spieler")
	room_name = _field("Name der Partie", "Banger Queens · Freunde")
	nickname.max_length = 32
	room_name.max_length = 48
	_text("Dein Haus")
	house_picker = OptionButton.new()
	house_picker.custom_minimum_size.y = 50
	house_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	house_picker.accessibility_name = "Eigenes Haus für die WLAN-Partie"
	for house in main.DataScript.houses():
		house_picker.add_item(str(house.name))
	house_picker.item_selected.connect(_choose_house)
	body.add_child(house_picker)
	_text("Spielport · auf allen Geräten gleich")
	port_box = SpinBox.new()
	port_box.min_value = 1024
	port_box.max_value = 65535
	port_box.value = session.game_port
	port_box.custom_minimum_size.y = 48
	body.add_child(port_box)
	host_button = main._button("Neue Partie hosten", host_game)
	body.add_child(host_button)
	resume_button = main._button("LAN-Spielstand laden und hosten", resume_game)
	body.add_child(resume_button)
	_text("Einer Partie beitreten")
	address = _field("IP-Adresse des Gastgebergeräts", "")
	address.placeholder_text = "Zum Beispiel 192.168.178.20"
	join_button = main._button("Über IP beitreten", join_game)
	body.add_child(join_button)
	body.add_child(main._button("Partien im WLAN suchen", session.search_rooms))
	rooms_box = VBoxContainer.new()
	rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rooms_box)
	players_label = _text("")
	ready_button = main._button("Bereit", _toggle_ready)
	body.add_child(ready_button)
	save_button = main._button("Gemeinsame Partie speichern", save_game)
	body.add_child(save_button)
	lobby_button = main._button("Mit aktuellem Spielstand zur Lobby", _return_to_lobby)
	body.add_child(lobby_button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	back_button = main._button("Zurück", hide_menu)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(back_button)
	start_button = main._button("Partie starten", start_game)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(start_button)
	session.lobby_changed.connect(refresh)
	session.status_changed.connect(refresh)
	session.game_started.connect(_started)
	visible = false
	refresh()

func _text(text: String) -> Label:
	var label: Label = main._label(text, 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(label)
	return label

func _field(label: String, value: String) -> LineEdit:
	_text(label)
	var field := LineEdit.new()
	field.text = value
	field.max_length = 64
	field.accessibility_name = label
	field.custom_minimum_size.y = 48
	field.add_theme_stylebox_override("normal", main._field_style())
	field.add_theme_stylebox_override("focus", Appearance.focus_surface())
	field.add_theme_font_size_override("font_size", 16)
	body.add_child(field)
	return field

func show_menu() -> void:
	visible = true
	move_to_front()
	main.kernel.push_modal("lan")
	refresh()
	if session.phase == "idle":
		session.search_rooms()

func hide_menu() -> void:
	if session.phase in ["idle", "connecting", "lobby", "disconnected"]:
		session.close_session("WLAN-Lobby verlassen.")
		if main.game != null and not main.game.human_houses.is_empty():
			main.game = null
			main.kernel.bind_game(null)
			main._show_start()
	visible = false
	main.kernel.pop_modal("lan")
	if session.phase == "playing":
		main.refresh()

func host_game() -> void:
	_present(session.host(room_name.text, nickname.text, house_picker.selected, int(port_box.value)))

func resume_game() -> void:
	var result: Dictionary = session.host(room_name.text, nickname.text, house_picker.selected, int(port_box.value))
	if result.ok:
		result = session.load_host_lobby()
	_present(result)

func join_game() -> void:
	_present(session.join(address.text.strip_edges(), nickname.text, int(port_box.value)))

func start_game() -> void:
	_present(session.start_match())

func save_game() -> void:
	_present(session.save_host())

func _return_to_lobby() -> void:
	_present(session.return_to_lobby())

func _choose_house(index: int) -> void:
	if not _updating and session.phase == "lobby":
		_present(session.choose_house(index))

func _toggle_ready() -> void:
	var own: Dictionary = session.players.get(session.local_peer_id, {})
	_present(session.set_ready(not bool(own.get("ready", false))))

func _present(result: Dictionary) -> void:
	if not result.get("message", "").is_empty():
		session.status = str(result.message)
	refresh()

func _started() -> void:
	visible = false
	main.kernel.pop_modal("lan")

func refresh() -> void:
	if session == null or status_label == null:
		return
	_updating = true
	status_label.text = session.status
	var lobby: bool = session.phase == "lobby"
	var inactive: bool = session.phase in ["idle", "disconnected"]
	host_button.disabled = not inactive
	resume_button.disabled = not inactive
	join_button.disabled = not inactive
	nickname.editable = inactive
	room_name.editable = inactive
	address.editable = inactive
	port_box.editable = inactive
	house_picker.disabled = not lobby and not inactive
	var local_house: int = session.local_house()
	if lobby and local_house >= 0 and local_house < house_picker.item_count:
		house_picker.select(local_house)
	for index in house_picker.item_count:
		var occupied := false
		for peer in session.players:
			if int(peer) != session.local_peer_id and int(session.players[peer].house) == index:
				occupied = true
		house_picker.set_item_disabled(index, occupied)
	var names: PackedStringArray = []
	var all_ready: bool = session.players.size() >= 2
	for peer in session.players:
		var player: Dictionary = session.players[peer]
		var index: int = int(player.house)
		var house_name := str(main.DataScript.houses()[index].name) if index >= 0 and index < house_picker.item_count else "Sitz wählen"
		names.append("%s · %s · %s" % [player.name, house_name, "bereit" if player.ready else "noch nicht bereit"])
		all_ready = all_ready and bool(player.ready)
	players_label.text = "Spieler: %d / 4\n%s" % [session.players.size(), "\n".join(names)] if not names.is_empty() else "Noch keiner Partie beigetreten."
	ready_button.visible = lobby and not session.is_host
	var own: Dictionary = session.players.get(session.local_peer_id, {})
	ready_button.text = "Bereitschaft zurücknehmen" if own.get("ready", false) else "Bereit"
	start_button.visible = session.is_host and lobby
	start_button.disabled = not (lobby and session.is_host and all_ready)
	save_button.visible = session.is_host and session.game != null
	lobby_button.visible = session.is_host and session.phase == "playing"
	back_button.text = "Zur Partie" if session.phase == "playing" else "Zurück"
	var addresses: PackedStringArray = []
	if session.is_host and session.phase != "idle":
		for ip in IP.get_local_addresses():
			if not ":" in ip and not ip.begins_with("127."):
				addresses.append(ip)
	address_label.text = "Gastgeber-IP: %s · Port %d" % [", ".join(addresses), session.game_port] if not addresses.is_empty() else "Im selben WLAN suchen oder die lokale IP des Gastgebers eingeben."
	refresh_rooms()
	_updating = false
	if main.game != null and session.phase != "idle" and main.hint_label != null:
		main.hint_label.text = "WLAN · " + session.status

func refresh_rooms() -> void:
	var signature := JSON.stringify(session.discovered_rooms)
	if signature == _room_signature:
		return
	_room_signature = signature
	for child in rooms_box.get_children():
		rooms_box.remove_child(child)
		child.queue_free()
	for room in session.discovered_rooms:
		var ip: String = str(room.get("address", ""))
		var port: int = int(room.get("port", 28741))
		var caption := "%s · %s" % [str(room.get("name", "WLAN-Partie")), ip]
		var button: Button = main._button(caption, func():
			address.text = ip
			port_box.value = port
			join_game())
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rooms_box.add_child(button)
		if main.has_meta("modern_interface"):
			main.get_meta("modern_interface")._scale_text(button)
