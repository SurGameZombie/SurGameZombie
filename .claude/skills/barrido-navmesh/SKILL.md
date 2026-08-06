---
name: barrido-navmesh
description: Verifica que el NavMesh horneado conecte todo el mapa — qué aberturas quedan navegables, qué zonas quedan como islas inalcanzables, y si un agente real las cruza. Usar después de tocar la geometría de yard.tscn, los parámetros de horneado (cell_size, cell_height, agent_radius), o NavigationObstacle3D / NavigationAgent3D.
---

# Barrido de conectividad del NavMesh

Existe porque este proyecto tuvo tres semanas los cuatro vanos de la oficina **tapiados
para el zombie** sin que nada lo detectara: el juego arrancaba, no había ni un error, y el
zombie se quedaba clavado contra un muro 19 segundos. Ver
`docs/decisions/0008-horneado-del-navmesh-y-cuerpo-caido.md`.

## Cuándo correrlo

- Cambió la geometría de `scenes/main/yard.tscn` (siempre, junto con el re-horneado)
- Cambió `cell_size`, `cell_height`, `agent_radius` o `agent_height` del NavMesh
- Cambió el `radius` o el `height` de un `NavigationObstacle3D`, o el `radius` de un
  `NavigationAgent3D`
- Apareció un zombie que no llega a algún lado y no se sabe por qué

## Las dos reglas que hacen que esto sirva

**1. La malla horneada se asigna ANTES de que la región entre al árbol.**

Es la trampa que invalidó una ronda entera de medición. Si se asigna
`region.navigation_mesh = nm` y **después** se llama `bake_navigation_mesh()`, el
NavigationServer se queda con el estado previo al horneado: seis variantes distintas
devuelven resultados idénticos y parece que ningún parámetro hace nada. Hornear en un
proceso, guardar, y consultar en otro.

**2. Control negativo obligatorio, siempre.**

Antes de creerle un resultado al barrido, hay que romperlo a propósito y confirmar que lo
reporta: tapiar una puerta que hoy está abierta, o subir `agent_radius` a 1,5. **Si el
barrido sigue diciendo que todo conecta, el barrido está roto y no se mira ningún otro
número.** Agarró errores en las tres veces que se corrió.

## Procedimiento

Los scripts van en la raíz del proyecto, se corren, y **se borran** (`rm` del `.gd` y del
`.gd.uid`). Las variantes horneadas van a `user://`, nunca al repo. Al terminar,
`git status` tiene que estar como antes.

### Paso 1 — Hornear variantes a `user://`

```gdscript
extends SceneTree
const OUT: String = "user://navprobe"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await _bake("actual", false)
	await _bake("NEG_tapiada", true)   # control negativo
	quit(0)

func _bake(nombre: String, tapiar: bool) -> void:
	var region: NavigationRegion3D = load("res://scenes/main/yard.tscn").instantiate()
	if tapiar:
		var m: CSGBox3D = CSGBox3D.new()
		m.position = Vector3(-20, 1.5, -11.8)   # puerta sur del galpón
		m.size = Vector3(2.0, 3.0, 0.4)
		m.use_collision = true
		region.add_child(m)
	var nm: NavigationMesh = region.navigation_mesh.duplicate() as NavigationMesh
	region.navigation_mesh = nm
	root.add_child(region)
	await process_frame
	await process_frame
	region.bake_navigation_mesh(false)
	ResourceSaver.save(nm, "%s/%s.tres" % [OUT, nombre])
	print("horneado %-14s polys=%d" % [nombre, nm.get_polygon_count()])
	region.free()
	await process_frame
```

### Paso 2 — Consultar, en proceso limpio y uno por variante

```gdscript
extends SceneTree
## ++ <variante>
const SPAWN_ZOMBIE: Vector3 = Vector3(-16, 0.3, -19)

func _initialize() -> void:
	var v: String = OS.get_cmdline_user_args()[0]
	var region: NavigationRegion3D = load("res://scenes/main/yard.tscn").instantiate()
	# ANTES del add_child, y ya horneada. Ver "las dos reglas".
	var nm: NavigationMesh = load("user://navprobe/%s.tres" % v) as NavigationMesh
	region.navigation_mesh = nm
	root.add_child(region)
	# El RID del mapa NO es válido en el mismo frame del add_child.
	for i in 5: await physics_frame
	var map: RID = region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, nm.cell_size)
	NavigationServer3D.map_set_cell_height(map, nm.cell_height)
	for i in 30: await physics_frame
	NavigationServer3D.map_force_update(map)
	await physics_frame

	var origen: Vector3 = NavigationServer3D.map_get_closest_point(map, SPAWN_ZOMBIE)
	print("### %s (cell=%.2f polys=%d)" % [v, nm.cell_size, nm.get_polygon_count()])
	for zi in range(-29, 30):
		var linea: String = ""
		for xi in range(-29, 30):
			var p: Vector3 = Vector3(float(xi), 0.3, float(zi))
			var s: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
			if Vector2(s.x - p.x, s.z - p.z).length() >= 0.5 or absf(s.y - 0.3) > 0.15:
				linea += "."      # sin NavMesh
				continue
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, origen, p, true)
			var fin: Vector3 = path[path.size() - 1] if path.size() > 0 else Vector3(999, 0, 999)
			linea += "#" if Vector2(fin.x - p.x, fin.z - p.z).length() < 1.0 else "X"
		print("z=%4d %s" % [zi, linea])
	quit(0)
```

```powershell
& $godot --headless --path . -s res://_bake.gd
& $godot --headless --path . -s res://_query.gd ++ actual
& $godot --headless --path . -s res://_query.gd ++ NEG_tapiada
```

### Paso 3 — Leer el mapa

`#` alcanzable · `X` **hay NavMesh pero el zombie no llega** · `.` sin NavMesh.
Eje X de −29 a +29, eje Z de −29 (arriba) a +29 (abajo).

**Las `X` son el hallazgo.** Un bloque de `X` es un edificio o una zona que existe en el
mapa, por la que el jugador camina, y donde la IA no puede entrar. Las únicas `X`
aceptadas hoy son astillas de una celda adentro de la huella de cada contenedor —
artefacto de rasterización donde la cara de abajo del contenedor es coplanar con el piso,
e inalcanzables para el respawn porque habría que morir dentro de un sólido.

En el control negativo, la zona detrás de la puerta tapiada **tiene que** pasar a `X`.

## Medir un vano concreto

Para saber cuánta franja de NavMesh cruza una abertura, muestrear cada 5 cm a lo largo del
vano y contar la corrida continua con desvío < 0,05 m. Contrastar contra la fórmula:

```
franja = ancho − 2 × ceil(agent_radius / cell_size) × cell_size
```

**La fórmula solo es confiable con `cell_size ≤ 0,10`** (error de 0,05 m, que es el paso de
muestreo). A 0,15 el error es de una celda entera; a 0,25 predice 0,40 m donde hay 0,00.

## La prueba que de verdad cierra el asunto

El barrido dice que **existe camino**. No dice que el agente lo camine. Cuando el resultado
importe —un vano nuevo, un obstáculo nuevo— hay que correr además la prueba de aceptación:
instanciar `world.tscn`, poner el objetivo de un lado y el zombie del otro, dejar correr, y
**la señal de éxito es que baje la vida del objetivo**, no que haya path. Un zombie que
llega a 0,10 m y no muerde sigue siendo un zombie roto.

## Limpieza

```bash
rm -f _bake.gd _bake.gd.uid _query.gd _query.gd.uid
rm -rf "$APPDATA/Godot/app_userdata/SurGameZombie/navprobe"
git status --short   # tiene que estar como antes
```
