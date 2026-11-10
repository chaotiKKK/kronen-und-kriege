extends RefCounted
## Ordnet einen geprüften Befehl ausschließlich dem serverseitigen Sitz zu.

const Protocol = preload("res://scripts/LanProtocol.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
var game
var peer_houses: Dictionary
var sequences: Dictionary = {}

func _init(world, seats: Dictionary) -> void:
	game = world
	peer_houses = seats.duplicate()

func execute(peer: int, sequence: int, command: Dictionary) -> Dictionary:
	if not peer_houses.has(peer):
		return Protocol.failure("Dieser Spieler besitzt keinen Sitz.", "no_seat")
	var previous: int = int(sequences.get(peer, 0))
	if sequence != previous + 1:
		return Protocol.failure("Veralteter oder doppelter Spielbefehl.", "sequence")
	sequences[peer] = sequence
	var validated: Dictionary = Protocol.validate_command(command)
	if not validated.ok:
		return validated
	var clean: Dictionary = validated.command
	if clean.id in ["set_speed", "continue_sandbox"] and peer != 1:
		return Protocol.failure("Diese gemeinsame Einstellung steuert der Gastgeber.", "host_only")
	var house: int = int(peer_houses[peer])
	var previous_player: int = int(game.player)
	if not game.select_player_context(house):
		return Protocol.failure("Das zugewiesene Haus ist nicht verfügbar.")
	var result: Dictionary
	if game.game_over and clean.id not in ["set_speed", "continue_sandbox"]:
		result = Protocol.failure("Dein Haus ist beendet. Du kannst die Partie weiter beobachten.", "house_over")
	elif clean.id == "apply_event" and int(clean.event_instance) != game.pending_event_instance():
		result = Protocol.failure("Dieses Ereignis ist nicht mehr aktuell.", "event_instance")
	else:
		var kernel = Kernel.new()
		kernel.bind_game(game)
		kernel.select_province(str(clean.selection))
		result = kernel.dispatch(clean)
	game.select_player_context(previous_player)
	return result

func snapshot_for_peer(peer: int) -> Dictionary:
	if not peer_houses.has(peer):
		return {}
	return game.snapshot_for_player(int(peer_houses[peer]))
