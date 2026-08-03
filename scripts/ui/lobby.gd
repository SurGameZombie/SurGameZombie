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


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	# server_disconnected NO se escucha acá: cuando el host se cae ya estás en el
	# mundo y esta escena no existe. Lo maneja network_manager.gd, que sobrevive
	# a los cambios de escena.
	_status_label.text = "Sin conectar"
	# Volver al lobby después de una desconexión deja el mouse capturado por el
	# jugador que se acaba de destruir.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_host_pressed() -> void:
	var error: Error = NetworkManager.host_game()
	if error != OK:
		_status_label.text = "No se pudo hostear (error %d)" % error
		return
	_set_buttons_enabled(false)
	_status_label.text = "Hosteando…"
	# El host entra al mundo enseguida: no espera a nadie.
	get_tree().change_scene_to_file(NetworkManager.WORLD_SCENE)


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
	# Recién cuando el host aceptó la conexión entramos al mundo. Si entráramos
	# antes, un "Unirse" a una IP muerta te dejaría parado en un mundo vacío.
	get_tree().change_scene_to_file(NetworkManager.WORLD_SCENE)


func _on_connection_failed() -> void:
	_status_label.text = "Falló la conexión"
	_set_buttons_enabled(true)


func _set_buttons_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
	_ip_field.editable = enabled
