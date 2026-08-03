extends SceneTree

## Hornea el NavMesh del greybox sin abrir el editor y lo guarda en su .tres.
##
## Correrlo SIEMPRE después de tocar la geometría de yard.tscn. Si no, el
## NavMesh queda con la forma vieja: el zombie camina atravesando paredes que
## ahora existen, o se queda quieto porque su destino dejó de ser navegable.
## Es un bug que no se parece en nada a su causa.
##
## Cómo se corre: ver CLAUDE.md → Comandos.
## Sale con código 1 si algo falló, así que sirve para un hook.

const SCENE_PATH: String = "res://scenes/main/yard.tscn"
const OUTPUT_PATH: String = "res://scenes/main/yard_navmesh.tres"


func _initialize() -> void:
	var exit_code: int = await _bake()
	quit(exit_code)


## Devuelve el código de salida: 0 si horneó y guardó, 1 si algo falló.
func _bake() -> int:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		printerr("[bake] no se pudo cargar %s" % SCENE_PATH)
		return 1

	var region: NavigationRegion3D = scene.instantiate()
	root.add_child(region)
	# Dos frames para que los CSGBox3D terminen de construir su malla y su
	# colisión: el horneado sale a buscar geometría que todavía no existiría.
	await process_frame
	await process_frame

	if region.navigation_mesh == null:
		printerr("[bake] %s no tiene ningún NavigationMesh asignado" % SCENE_PATH)
		return 1

	region.bake_navigation_mesh(false)  # false = sincrónico, no en otro hilo
	return _save(region.navigation_mesh)


func _save(nav_mesh: NavigationMesh) -> int:
	var polygon_count: int = nav_mesh.get_polygon_count()
	if polygon_count == 0:
		printerr("[bake] no salió ni un polígono. ¿La geometría tiene use_collision?")
		return 1

	var error: Error = ResourceSaver.save(nav_mesh, OUTPUT_PATH)
	if error != OK:
		printerr("[bake] no se pudo guardar %s (error %d)" % [OUTPUT_PATH, error])
		return 1

	print("[bake] %s — %d vértices, %d polígonos" % [
		OUTPUT_PATH,
		nav_mesh.get_vertices().size(),
		polygon_count,
	])
	return 0
