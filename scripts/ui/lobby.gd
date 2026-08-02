extends Control

## Pantalla de arranque: hostear o unirse por IP. Es la main_scene del proyecto.
##
## Escucha las señales del MultiplayerAPI directamente, y eso no rompe la regla
## de que solo network_manager.gd conoce el transporte: MultiplayerAPI es igual
## para ENet, noray o Steam. Lo específico del transporte es ENetMultiplayerPeer,
## y eso se nombra solo allá.

# El % son "nombres únicos de escena" (Scene Unique Names): se marcan con el
# ícono de porcentaje en el editor y siguen funcionando aunque después movamos
# el nodo de contenedor. Un $ChildContainer/Otro/Label se rompe con eso.
@onready var _status_label: Label = %StatusLabel
@onready var _ip_field: LineEdit = %IpField
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton

var _role: String = ""


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	multiplayer.peer_connected.connect(_on_peer_changed)
	multiplayer.peer_disconnected.connect(_on_peer_changed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_status_label.text = "Sin conectar"


func _on_host_pressed() -> void:
	var error: Error = NetworkManager.host_game()
	if error != OK:
		_status_label.text = "No se pudo hostear (error %d)" % error
		return
	_role = "Hosteando"
	_set_buttons_enabled(false)
	_refresh_status()


func _on_join_pressed() -> void:
	var ip: String = _ip_field.text.strip_edges()
	if ip.is_empty():
		_status_label.text = "Falta la IP"
		return
	var error: Error = NetworkManager.join_game(ip)
	if error != OK:
		_status_label.text = "No se pudo crear el cliente (error %d)" % error
		return
	_set_buttons_enabled(false)
	_status_label.text = "Conectando a %s…" % ip


func _on_connected_to_server() -> void:
	_role = "Conectado"
	_refresh_status()


func _on_connection_failed() -> void:
	_role = ""
	_status_label.text = "Falló la conexión"
	_set_buttons_enabled(true)


func _on_server_disconnected() -> void:
	_role = ""
	_status_label.text = "El host cerró la partida"
	_set_buttons_enabled(true)


# peer_connected y peer_disconnected mandan el id del peer, pero acá alcanza con
# saber que algo cambió: el conteo sale de multiplayer.get_peers().
func _on_peer_changed(_id: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	if _role.is_empty():
		return
	_status_label.text = "%s — soy el peer %d, otros conectados: %d" % [
		_role,
		multiplayer.get_unique_id(),
		multiplayer.get_peers().size(),
	]


func _set_buttons_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
	_ip_field.editable = enabled
