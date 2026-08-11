extends GdUnitTestSuite

## Los pares de datos que viven escritos en dos lugares del repo y que hoy nada
## compara. Estos cuatro no salieron de una lista teórica: los cuatro ya se
## rompieron al menos una vez.
##
## No prueban comportamiento. Prueban que dos archivos no se hayan
## desincronizado, que es otra clase de bug —silencioso, sin error en pantalla, y
## con el síntoma a varios saltos de la causa— y la que más caro salió en este
## proyecto (ADR-0008, retrospectiva B12, el falso verde de `2519ff7`).
##
## **Lee todo como TEXTO con FileAccess, no instanciando las escenas.** Es a
## propósito: instanciar `player.tscn` compararía lo que Godot ya resolvió en
## memoria, y lo que hay que vigilar es lo que está escrito en el archivo que se
## revisa en el diff.
##
## **Un ancla que no aparece es una FALLA, no un salto silencioso.** Si alguien
## renombra una constante o mueve una fila de tabla, esta suite tiene que ponerse
## roja en vez de quedarse verde comparando cero cosas. Es el criterio de
## `item_catalog_test.gd`, y es la razón de que cada test junte problemas en una
## lista y cierre con `assert_str(...).is_empty()` en vez de con asserts sueltos:
## un assert suelto sobre un array vacío pasa.
##
## **gdUnit4 corta la suite en el primer caso que falla**, así que una corrida roja
## muestra UN par desincronizado aunque haya dos. Medido: con un par roto el runner
## reporta 48 de 49 casos y sale con código 100 (en verde, 49 y código 0). Arreglar
## el que reporta y volver a correr hasta que dé verde, sin asumir que era el único.

const WORLD_GD: String = "res://scripts/world/world.gd"
const WORLD_TSCN: String = "res://scenes/main/world.tscn"
const YARD_TSCN: String = "res://scenes/main/yard.tscn"
const PLAYER_TSCN: String = "res://scenes/player/player.tscn"
const ZOMBIE_TSCN: String = "res://scenes/enemies/zombie.tscn"
const PLAYER_STATS_GD: String = "res://scripts/player/player_stats.gd"
const DESIGN_MD: String = "res://docs/design.md"
const SKILL_MD: String = "res://.claude/skills/barrido-navmesh/SKILL.md"

## Los tipos de bloque de un `.tscn` cuyo `radius` describe la MISMA cápsula: la
## de colisión, la que se ve, y la que usa la navegación. Un `radius` de
## cualquier otro tipo no entra acá — el día que una escena tenga un
## `SphereShape3D` de trigger, su radio no tiene por qué coincidir con nada.
const RADIUS_TYPES: Array[String] = [
	"CapsuleShape3D",
	"CapsuleMesh",
	"NavigationAgent3D",
	"NavigationObstacle3D",
]


# --- 1. Par C3: las escenas spawneables ------------------------------------

# `world.gd` preloadea las escenas y `world.tscn` declara cuáles puede replicar
# el MultiplayerSpawner. Si divergen, el host instancia bien y el Spawner
# DESCARTA la réplica: el síntoma es "a veces el otro jugador no aparece", que es
# exactamente el que docs/netcode.md ya documenta atribuido a la carrera del
# spawn de v0.1. O sea que romper esto manda a debuggear al lugar equivocado.
#
# Se ancla en el nombre de la constante (`*_SCENE`) y no en cualquier preload:
# así el chequeo sigue significando "las escenas que el spawner replica" incluso
# si algún día world.gd preloadea algo que no se spawnea.
func test_las_escenas_spawneables_coinciden_con_los_preload_de_world() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var script_text: String = _read(WORLD_GD)
	var scene_text: String = _read(WORLD_TSCN)
	if script_text.is_empty() or scene_text.is_empty():
		problems.append("no se pudo leer %s o %s" % [WORLD_GD, WORLD_TSCN])

	var preloaded: Array[String] = _capture_all(
		script_text, "const\\s+\\w+_SCENE\\s*:\\s*PackedScene\\s*=\\s*preload\\(\"([^\"]+)\"\\)"
	)
	var registered: Array[String] = _spawnable_scenes(scene_text)

	if preloaded.is_empty():
		problems.append("ancla perdida: ningún `const *_SCENE: PackedScene = preload(...)` en world.gd")
	if registered.is_empty():
		problems.append("ancla perdida: ningún `_spawnable_scenes` en world.tscn")

	preloaded.sort()
	registered.sort()
	if not preloaded.is_empty() and not registered.is_empty() and preloaded != registered:
		problems.append("world.gd preloadea %s y world.tscn replica %s" % [preloaded, registered])

	assert_str("\n".join(problems)).is_empty()


# --- 2. Par A2: el radio de la cápsula --------------------------------------

# Las tres —cuatro en el jugador— representaciones de la misma cápsula tienen que
# medir lo mismo. Ya se rompió: el NavigationObstacle3D del jugador estuvo en
# 0.80 mientras las otras estaban en 0.40, o sea que el obstáculo medía el doble
# que el cuerpo que representa (ADR-0008, decisión 2).
#
# No se compara contra un número fijo a propósito. El 0.4 es un valor de arranque
# y lo van a tunear; lo que no puede pasar es que lo cambien en un bloque y no en
# los otros.
func test_todos_los_radios_de_una_escena_describen_la_misma_capsula() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for path: String in [PLAYER_TSCN, ZOMBIE_TSCN]:
		var text: String = _read(path)
		if text.is_empty():
			problems.append("no se pudo leer %s" % path)
			continue

		var radii: Array = _radii(text)
		# Con menos de dos no hay nada que comparar y el test pasaría sin mirar
		# nada, que es justo el falso verde contra el que existe esta suite.
		if radii.size() < 2:
			problems.append("ancla perdida: %s declara %d radius de %s, hacen falta 2" % [
				path, radii.size(), RADIUS_TYPES,
			])
			continue

		var first: float = radii[0][1]
		for entry: Array in radii:
			if not is_equal_approx(entry[1] as float, first):
				problems.append("%s: %s tiene radius %s y %s tiene %s" % [
					path, radii[0][0], first, entry[0], entry[1],
				])

	assert_str("\n".join(problems)).is_empty()


# --- 3. Par A12: la vida ----------------------------------------------------

# docs/design.md fija "30 de 100" y el código lo implementa en dos archivos
# distintos. Ya se rompió de la peor forma posible: el comentario de max_health
# nació afirmando que design.md no fijaba ningún número de vida, en el mismo
# commit en que design.md empezó a fijarlo (retrospectiva B12).
#
# Se ancla en la FRASE de la fila de la tabla y no en un conteo de "100" o "30":
# design.md menciona esos números en otras cuatro líneas de prosa histórica —la
# sesión de 30-60 minutos, "levantarse con 30 de vida"— y contar los encontraría.
func test_la_vida_de_design_md_coincide_con_la_del_codigo() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var row: RegExMatch = _search(
		_read(DESIGN_MD), "\\|\\s*Vida con la que te levantan\\s*\\|\\s*(\\d+)\\s+de\\s+(\\d+)\\s*\\|"
	)
	if row == null:
		problems.append("ancla perdida: la fila `| Vida con la que te levantan | X de Y |` en design.md")
		assert_str("\n".join(problems)).is_empty()
		return

	_compare_number(
		problems, row.get_string(1).to_float(), "REVIVE_HEALTH de world.gd",
		_read(WORLD_GD), "const\\s+REVIVE_HEALTH\\s*:\\s*float\\s*=\\s*([0-9.]+)"
	)
	_compare_number(
		problems, row.get_string(2).to_float(), "max_health de player_stats.gd",
		_read(PLAYER_STATS_GD), "@export\\s+var\\s+max_health\\s*:\\s*float\\s*=\\s*([0-9.]+)"
	)

	assert_str("\n".join(problems)).is_empty()


# --- 4. Par C5: las coordenadas del skill -----------------------------------

# El control negativo de barrido-navmesh sella dos puertas escribiendo sus
# coordenadas A MANO. Si una puerta se mueve en yard.tscn, el sellado deja de
# sellar y el barrido da verde sin haber controlado nada. No es hipotético: es
# literalmente el bug de `2519ff7`, con otra causa.
#
# **Solo X y Z.** Las Y nunca coincidieron y no tienen por qué: el skill usa 1.5
# (medio del cubo que sella) y 0.3 (altura del NavMesh); yard.tscn usa 4.2 (centro
# del dintel) y world.tscn 0.1 (offset para no arrancar clavado en el piso).
# Los `size` tampoco se comparan: el sellado mide 3.0 de alto y el dintel 3.6.
func test_las_coordenadas_del_skill_siguen_apuntando_al_mapa_real() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var skill: String = _read(SKILL_MD)
	var yard: String = _read(YARD_TSCN)
	var world: String = _read(WORLD_TSCN)

	_compare_xz(problems, "puerta sur del galpón",
		_vector3(skill, "sur\\.position\\s*=\\s*Vector3\\(([^)]+)\\)"),
		_node_origin(yard, "WarehouseDoorSouthLintel"))
	_compare_xz(problems, "puerta este del galpón",
		_vector3(skill, "este\\.position\\s*=\\s*Vector3\\(([^)]+)\\)"),
		_node_origin(yard, "WarehouseDoorEastLintel"))
	_compare_xz(problems, "spawn del zombie",
		_vector3(skill, "SPAWN_ZOMBIE\\s*:\\s*Vector3\\s*=\\s*Vector3\\(([^)]+)\\)"),
		_node_origin(world, "ZombieSpawn"))

	assert_str("\n".join(problems)).is_empty()


# --- helpers ----------------------------------------------------------------

# El archivo como texto, o "" si no se pudo abrir. Quien llama reporta el
# problema: acá no se puede, porque devolver "" ya es la señal.
func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


# El primer match de un patrón, o null.
func _search(text: String, pattern: String) -> RegExMatch:
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		return null
	return regex.search(text)


# Todas las capturas del grupo 1, en orden de aparición.
func _capture_all(text: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		return out
	for found: RegExMatch in regex.search_all(text):
		out.append(found.get_string(1))
	return out


# Las rutas de todos los PackedStringArray de _spawnable_scenes del .tscn. Va en
# dos pasos porque el array puede tener más de una entrada.
func _spawnable_scenes(text: String) -> Array[String]:
	var out: Array[String] = []
	for array: String in _capture_all(
		text, "_spawnable_scenes\\s*=\\s*PackedStringArray\\(([^)]*)\\)"
	):
		out.append_array(_capture_all(array, "\"([^\"]+)\""))
	return out


# Pares [etiqueta, valor] de cada `radius` declarado adentro de un bloque de los
# tipos de RADIUS_TYPES. Recorre por líneas y no con una regex sobre todo el
# texto porque un `radius` suelto no dice de qué bloque es, y el mensaje de error
# sin el bloque no sirve para nada.
func _radii(text: String) -> Array:
	var out: Array = []
	var value: RegEx = RegEx.new()
	value.compile("^radius\\s*=\\s*([0-9.eE+-]+)$")
	var current_type: String = ""
	var current_label: String = ""
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("["):
			current_type = _attribute(stripped, "type")
			current_label = _attribute(stripped, "id")
			if current_label.is_empty():
				current_label = _attribute(stripped, "name")
			continue
		if not RADIUS_TYPES.has(current_type):
			continue
		var found: RegExMatch = value.search(stripped)
		if found != null:
			out.append([current_label, found.get_string(1).to_float()])
	return out


# El valor de un atributo `clave="valor"` del encabezado de un bloque.
func _attribute(header: String, key: String) -> String:
	var found: RegExMatch = _search(header, "%s=\"([^\"]+)\"" % key)
	return found.get_string(1) if found != null else ""


# El bloque de un nodo del .tscn: desde su encabezado hasta el que le sigue.
func _node_block(text: String, node_name: String) -> String:
	var start: int = text.find("[node name=\"%s\"" % node_name)
	if start < 0:
		return ""
	var end: int = text.find("\n[", start + 1)
	return text.substr(start) if end < 0 else text.substr(start, end - start)


# El origen del transform de un nodo —los últimos tres números del Transform3D—,
# o vacío si el nodo o su transform no están.
func _node_origin(text: String, node_name: String) -> Array[float]:
	var block: String = _node_block(text, node_name)
	if block.is_empty():
		return [] as Array[float]
	var numbers: Array[float] = _vector3(block, "transform\\s*=\\s*Transform3D\\(([^)]+)\\)", 12)
	if numbers.size() != 12:
		return [] as Array[float]
	return [numbers[9], numbers[10], numbers[11]] as Array[float]


# Los números de adentro de un Vector3(...) o Transform3D(...), o vacío si el
# patrón no aparece o no trae la cantidad esperada.
func _vector3(text: String, pattern: String, expected: int = 3) -> Array[float]:
	var found: RegExMatch = _search(text, pattern)
	if found == null:
		return [] as Array[float]
	var out: Array[float] = []
	for part: String in found.get_string(1).split(","):
		out.append(part.strip_edges().to_float())
	return out if out.size() == expected else [] as Array[float]


# Compara un número del doc contra el que declara el código.
func _compare_number(
	problems: PackedStringArray, expected: float, label: String, text: String, pattern: String
) -> void:
	var found: RegExMatch = _search(text, pattern)
	if found == null:
		problems.append("ancla perdida: %s (patrón `%s`)" % [label, pattern])
		return
	var actual: float = found.get_string(1).to_float()
	if not is_equal_approx(actual, expected):
		problems.append("design.md dice %s y %s vale %s" % [expected, label, actual])


# Compara solo X y Z de dos posiciones. El porqué de excluir Y está arriba, en el
# test que la llama.
func _compare_xz(
	problems: PackedStringArray, label: String, skill: Array[float], scene: Array[float]
) -> void:
	if skill.is_empty():
		problems.append("ancla perdida en SKILL.md: %s" % label)
		return
	if scene.is_empty():
		problems.append("ancla perdida en la escena: %s" % label)
		return
	if not is_equal_approx(skill[0], scene[0]) or not is_equal_approx(skill[2], scene[2]):
		problems.append("%s: el skill usa x=%s z=%s y la escena está en x=%s z=%s" % [
			label, skill[0], skill[2], scene[0], scene[2],
		])
