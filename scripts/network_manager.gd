extends Node

signal status_changed(text: String)
signal connection_changed(connected: bool)
signal peer_joined(peer_id: int)

const PORT := 24567
const MAX_CLIENTS := 1

var is_host := false
var connected := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game() -> Error:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status_changed.emit("Не удалось создать сервер: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	connected = false
	status_changed.emit("Хост запущен. IP: %s  Порт: %d" % [get_local_ipv4(), PORT])
	connection_changed.emit(false)
	return OK

func join_game(address: String) -> Error:
	stop()
	var ip := address.strip_edges()
	if ip.is_empty():
		status_changed.emit("Введите IP хоста")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_changed.emit("Ошибка подключения: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	connected = false
	status_changed.emit("Подключение к %s:%d..." % [ip, PORT])
	return OK

func stop() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	connected = false
	connection_changed.emit(false)

func get_local_ipv4() -> String:
	for address in IP.get_local_addresses():
		if address.contains(":"):
			continue
		if address.begins_with("127."):
			continue
		if address.begins_with("169.254."):
			continue
		return address
	return "127.0.0.1"

func _on_peer_connected(peer_id: int) -> void:
	connected = true
	status_changed.emit("Второй игрок подключён")
	connection_changed.emit(true)
	peer_joined.emit(peer_id)

func _on_peer_disconnected(_peer_id: int) -> void:
	connected = false
	status_changed.emit("Второй игрок отключился")
	connection_changed.emit(false)

func _on_connected_to_server() -> void:
	connected = true
	status_changed.emit("Подключено к хосту")
	connection_changed.emit(true)

func _on_connection_failed() -> void:
	connected = false
	status_changed.emit("Не удалось подключиться")
	connection_changed.emit(false)

func _on_server_disconnected() -> void:
	connected = false
	status_changed.emit("Соединение с хостом потеряно")
	connection_changed.emit(false)
