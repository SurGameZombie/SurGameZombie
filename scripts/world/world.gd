extends Node3D

## Escena de juego de v0.1. Todo lo que se decide acá corre en el host: quién
## existe, dónde aparece y cuándo se va (docs/netcode.md → "La regla").

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

## Radio del círculo donde aparecen los jugadores, para que no spawneen uno
## adentro del otro.
const SPAWN_RADIUS: float = 2.0

@onready var _players: Node3D = $Players


func _ready() -> void:
	if not multiplayer.is_server():
		# El cliente avisa que ya tiene esta escena cargada, y el host lo
		# spawnea recién ahí.
		#
		# Sin este aviso hay una carrera que en LAN se pierde casi siempre: el
		# host spawnearía al recibir peer_connected, pero del lado del cliente
		# change_scene_to_file() se difiere al final del frame. Con un RTT de
		# menos de 1 ms contra un frame de 16 ms, el paquete de spawn llega
		# antes de que exista el MultiplayerSpawner acá y se descarta. El
		# síntoma sería "a veces el otro jugador no aparece".
		notify_world_ready.rpc_id(1)
		return

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_spawn_player(multiplayer.get_unique_id())


## La llama un cliente cuando terminó de cargar esta escena. Corre en el host.
@rpc("any_peer", "reliable")
func notify_world_ready() -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(multiplayer.get_remote_sender_id())


func _spawn_player(peer_id: int) -> void:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	# El nombre del nodo ES el ID del peer: player.gd lo lee en _enter_tree()
	# para saber de quién es la autoridad. Tiene que estar puesto ANTES del
	# add_child(), porque _enter_tree() corre adentro de esa llamada.
	player.name = str(peer_id)
	player.position = _spawn_position(_players.get_child_count())
	# Solo agregarlo al árbol: el MultiplayerSpawner ve el hijo nuevo y lo
	# replica al resto. El host es el único que llega hasta acá.
	_players.add_child(player)
	print("[world] jugador spawneado para el peer %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var player: Node = _players.get_node_or_null(NodePath(str(peer_id)))
	if player == null:
		return
	# Borrarlo en el host alcanza: el Spawner replica el despawn. Sin esto queda
	# una cápsula fantasma parada para siempre en las otras máquinas.
	player.queue_free()
	print("[world] jugador borrado del peer %d" % peer_id)


func _spawn_position(index: int) -> Vector3:
	# Repartidos en círculo: con los 4 jugadores de docs/design.md quedan a 90°
	# uno del otro. El 0.1 de alto es para no arrancar clavado en el piso.
	var angle: float = TAU * float(index) / 4.0
	return Vector3(cos(angle) * SPAWN_RADIUS, 0.1, sin(angle) * SPAWN_RADIUS)
