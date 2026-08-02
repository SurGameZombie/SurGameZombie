extends Node

## Autoload. Es el ÚNICO archivo del proyecto que nombra un transporte concreto.
## Migrar a noray o a Steam tiene que ser un cambio acá adentro y en ningún otro
## lado (docs/netcode.md → "Transporte: plan de migración").
##
## No guarda estado de juego a propósito: un autoload existe igual en el host y
## en cada cliente y no se replica solo (.claude/rules/gdscript.md → pitfall 6).

const DEFAULT_PORT: int = 7777

## Host + 3 clientes = los 4 jugadores de docs/design.md.
const MAX_CLIENTS: int = 3


func _ready() -> void:
	# Las cinco señales del MultiplayerAPI. peer_connected y peer_disconnected
	# disparan en TODOS los peers; las otras tres solo en el cliente.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Levanta la partida en este proceso. La llama el lobby al apretar Hostear.
func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		push_error("[net] no se pudo hostear en el puerto %d (error %d)" % [port, error])
		return error
	# Recién acá se asigna: un peer que falló al crearse deja el MultiplayerAPI
	# en un estado roto que después revienta lejos de la causa.
	multiplayer.multiplayer_peer = peer
	print("[net] hosteando en el puerto %d — soy el peer %d" % [port, multiplayer.get_unique_id()])
	return OK


## Se conecta a un host por IP. La llama el lobby al apretar Unirse.
## OJO: devolver OK significa que se creó el socket, NO que haya conectado.
## Eso lo dicen después connected_to_server o connection_failed.
func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip, port)
	if error != OK:
		push_error("[net] no se pudo crear el cliente para %s:%d (error %d)" % [ip, port, error])
		return error
	multiplayer.multiplayer_peer = peer
	print("[net] conectando a %s:%d…" % [ip, port])
	return OK


func _on_peer_connected(id: int) -> void:
	print("[net] peer conectado: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	print("[net] peer desconectado: %d" % id)


func _on_connected_to_server() -> void:
	print("[net] conectado al host — soy el peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	print("[net] falló la conexión")


func _on_server_disconnected() -> void:
	print("[net] el host cerró la partida")
