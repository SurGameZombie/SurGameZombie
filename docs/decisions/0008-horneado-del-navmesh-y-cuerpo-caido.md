# ADR-0008: El NavMesh se hornea con `cell_size` 0,10 y un cuerpo caído tapa las puertas interiores

**Fecha:** 2026-08-05
**Estado:** aceptada
**Fuente:** tres rondas de medición con banco de pruebas con control negativo, 5/8/2026.
Ver `docs/bitacora.md` → Registro, y `.claude/skills/barrido-navmesh/`.

## Contexto

El greybox de v0.2 tiene dos edificios. El galpón, con vanos de 2,0 m, se podía navegar. La
oficina, con cuatro vanos de 1,4 m —dos exteriores y dos interiores—, **no**: el NavMesh
horneado no tenía ni un polígono cruzando ninguno de los cuatro, y el interior entero
quedaba como una isla desconectada de 90 celdas.

No se descubrió jugando. Se descubrió midiendo, y el síntoma real es peor que "el zombie no
entra": puesto a perseguir a alguien adentro de la oficina, el zombie **queda clavado contra
el muro exterior 1.134 frames de física seguidos** —unos 19 segundos— sin moverse un
centímetro. En un playtest eso no se lee como un problema del mapa, se lee como IA rota.

La causa está publicada en la documentación de Godot 4.7, en
`NavigationMesh.agent_radius`:

> *"The distance to erode/shrink the walkable area of the heightfield away from
> obstructions. **Note: While baking, this value will be rounded up to the nearest multiple
> of `cell_size`.**"*

De ahí sale la fórmula del ancho de franja navegable que sobrevive a un horneado:

```
franja = ancho_del_vano − 2 × ceil(agent_radius / cell_size) × cell_size
```

Con los parámetros que tenía el proyecto —`cell_size = 0,25` y `agent_radius` en su default
de 0,50— la erosión efectiva es 0,50 m por lado. Un vano de 2,0 m sobrevive con 1,0 m; uno
de 1,4 m debería quedar con 0,40 m y en la práctica queda con **cero**.

**Cuál es la parte que no se ve razonando:** la restricción de navegación no tiene nada que
ver con la de física. `docs/design.md` dimensionaba puertas e interiores contra el radio de
la cápsula del jugador —0,4 m, o sea 0,8 m de paso mínimo—, y ese número es correcto para
que el jugador pase. El horneado impone una segunda restricción, más alta, y nadie la había
escrito. Los vanos de 1,4 m estaban bien dimensionados contra la regla que existía.

### Cómo se midió

Importa registrarlo porque la primera ronda de medición fue inválida y no se notó hasta la
tercera. El banco original asignaba la malla a la región y **después** la horneaba in place:
el NavigationServer se quedaba con el estado previo al horneado, así que seis variantes muy
distintas devolvían resultados idénticos. Se detectó justamente por eso, porque un número
repetido a través de bakes distintos no es un resultado, es un banco roto.

El banco definitivo hornea en un proceso, guarda a `user://` y **consulta en un proceso
limpio**, con la malla ya horneada asignada antes de que la región entre al árbol. Y lleva
dos controles negativos que tienen que fallar: tapiar una puerta a propósito, y subir
`agent_radius` a 1,5. Si el banco no los reporta como cortados, no se mira ningún resultado.

La prueba de aceptación final **no** consulta el NavigationServer: instancia el zombie real
con su `NavigationAgent3D` y su avoidance, y la señal de éxito es que **le baje la vida al
objetivo**. Que exista camino y que el agente lo camine son dos cosas distintas.

### Valores medidos

| | |
|---|---|
| Vano de 1,4 m con `cell_size = 0,25` | **0,00 m de franja. Tapiado.** Zombie clavado 1.134 frames |
| Vano de 1,4 m con `cell_size = 0,10` | **0,45 m de franja.** Zombie muerde a los **1,83 s** |
| Vano mínimo que sobrevive con `cell_size = 0,10` | **1,2 m** (1,0 m queda tapiado) |
| Error de la fórmula contra lo medido | +0,05 m @ 0,10 · ±0,10 m @ 0,15 · −0,40/+0,25 m @ 0,25 |
| Horneado del yard 60 × 60 | 12 ms @ 0,25 → **80 ms @ 0,10** |
| Horneado de 250 × 250 sintético (690 muros) | 255 ms / 126 MB @ 0,25 → **1.796 ms / 415 MB @ 0,10** (línea base del proceso: 90 MB) |

**La fórmula es confiable con celda fina y engañosa con celda gruesa.** A `cell_size = 0,10`
el error contra lo medido es de 0,05 m constante, que es el paso de muestreo del barrido. A
0,25 se desvía hasta 0,40 m y en el caso que importa predice 0,40 donde hay 0,00. Dimensionar
contra la fórmula sin medir solo es seguro con celda fina.

### El cuerpo caído

Medido aparte, con un jugador caído real —su propio `NavigationObstacle3D` prendiéndose
solo— puesto en el vano, y el zombie real intentando cruzar:

| Radio del obstáculo | Pasa con el cuerpo pegado a la jamba | Pasa con el cuerpo centrado |
|---|---|---|
| 0,80 (el que tenía el proyecto) | 2,0 m | 3,0 m |
| 0,40 (el corregido acá) | 1,6 m | 2,4 m |

**En un vano de 1,4 m el cuerpo tapa con los dos radios**, así que la decisión de diseño de
abajo no depende de la corrección técnica. **El alcance importa y es fácil de generalizar
mal: esto vale para las puertas interiores de 1,4 m, no para los vanos de 2,0 m del galpón**,
donde un cuerpo pegado a la jamba deja pasar al zombie en 2,32 s.

Un dato que sale de la API y conviene tener escrito: `NavigationObstacle3D` con solo
`avoidance_enabled` **no toca el NavMesh ni el camino**, es dirección local. El zombie no
replanifica ni busca la otra puerta: sigue empujando contra el cuerpo hasta que el cuerpo se
va. No hay riesgo de que rodee por otro lado sin que nadie se lo pida.

## Decisión

**1. El NavMesh se hornea con `cell_size = 0,10`,** escrito en
`scenes/main/yard_navmesh.tres` al lado de `cell_height = 0,2`, con
`navigation/3d/default_cell_size` alineado en `project.godot`.

Se elige 0,10 y no 0,15 porque a 0,15 el error de medición es de una celda entera en las dos
direcciones y el `agent_radius` efectivo **sube** a 0,45–0,60 por el redondeo, o sea que el
zombie planificaría más lejos de las paredes que hoy. El costo del horneado a escala real
—1,8 s y 415 MB de pico— se pagó una vez y se midió; es una herramienta de línea de comandos
que corre cuando se toca la geometría, no algo del juego corriendo.

**2. El `NavigationObstacle3D` del jugador pasa de `radius = 0,80` a `0,40`.** Es un dato mal
puesto, no una decisión de diseño: la `CollisionShape3D` del jugador es 0,40, la del zombie
es 0,40 y su `NavigationAgent3D` también. El obstáculo era el único de los cuatro que no
coincidía, y medía el doble que el cuerpo que representa. El commit que lo introdujo
(`006029c`) no lo justifica en ningún trailer y `docs/bitacora.md` solo lo menciona
descriptivamente. La retrospectiva de v0.2 ya lo tenía fichado en §1.E3 como uno de los once
números que nadie decidió.

**3. Un cuerpo caído tapa entera una puerta interior de 1,4 m, caiga al costado o al centro.
Es intencional y no se ensancha ningún vano del mapa para evitarlo.**

> **[Pendiente de ustedes]** El porqué de diseño de esta decisión no está registrado en
> ningún lado y escribirlo de memoria sería inventarlo (`docs/proceso.md` §2 → "La
> advertencia sobre ADRs generadas por IA"). Va acá cuando lo escriban.

**4. El zombie no ataca a un jugador caído, ni siquiera trabado contra él en una puerta.**
Ya estaba implementado con dos guardas independientes —`zombie.gd::_nearest_player()` lo
saltea como objetivo y `player_stats.gd::take_damage()` sale temprano si `is_downed`— y
`docs/design.md` ya lo dice. Se registra acá como **decisión explícita y no como omisión**,
porque la combinación con el punto 3 crea una situación nueva: un zombie parado
indefinidamente sobre un cuerpo que no puede atacar. Verificado midiendo: en 24 corridas con
el zombie empujando contra el cuerpo hasta 15 s seguidos, la vida del caído no bajó nunca.

## Alternativas descartadas

**Bajar solo `agent_radius`, sin tocar `cell_size`.** Es un no-op y fue la primera propuesta.
Por el redondeo hacia arriba, `agent_radius` de 0,50 · 0,40 · 0,35 con `cell_size = 0,25`
producen **la misma malla, byte por byte** (285 polígonos las tres). Medido.

**`cell_size = 0,15`.** Abre los vanos, pero el error de medición es de ±0,10 m —una celda
entera— y el `agent_radius` efectivo sube a 0,45 o 0,60 según el valor pedido. Se descarta
por precisión, no por costo.

**`edge_max_error`.** Era la hipótesis principal del escalón a celda gruesa y quedó
descartada limpiamente: un rango de 6× (0,5 · 1,3 · 3,0) no mueve el resultado en ninguna de
las dos celdas. No es una palanca para esto, aunque sí cambia la densidad de la malla.

**`affect_navigation_mesh` / `carve_navigation_mesh` para que el cuerpo caído recorte el
NavMesh.** Verificado en la doc de 4.7: los dos son **de tiempo de horneado**, no de runtime.
Usarlos para un cuerpo que cae y se levanta obliga a re-hornear cada vez: 80 ms en el yard de
hoy —un tirón de casi cinco frames— y **1,8 s en el mapa final**, justo en el momento en que
alguien acaba de caer con un zombie encima. Descartado por costo.

**Ensanchar los vanos interiores hasta que un cuerpo nunca tape.** Habría que llevarlos a
2,4 m (con el radio corregido) o a 3,0 m (con el de hoy). Un vano interior de 2,4 m no es una
puerta, es una abertura de galpón. Se descarta a favor de la decisión 3.

**Ensanchar solo hasta el punto medio, 1,6 m**, donde el cuerpo tapa únicamente si cae
centrado. Descartado: obliga a retocar los cuatro vanos de la oficina y todo lo que se
construya después, a cambio de un caso que depende del azar de dónde cayó el cuerpo.

## Consecuencias

**Se vuelve fácil:**

- La oficina entra al juego. Los cuatro vanos pasan a ABIERTO y el zombie persigue adentro.
- Todo el resto del mapa mejora de arrastre: la puerta sur del galpón pasa de 0,90 a 1,05 m
  de franja, el corredor oeste de 0,65 a 0,75.
- **Un cuerpo caído en una puerta interior pasa a ser una decisión táctica**: bloquea al
  zombie y bloquea al que viene a levantarte, porque el rescatista también mide 0,8 m y
  1,4 − 0,8 = 0,6 m de paso.

**Se vuelve difícil, o hay que tenerlo presente:**

- **`docs/design.md` gana una segunda restricción de dimensionado**: 0,8 m de física y
  **1,4 m de navegación**, y manda la segunda. El piso duro medido es 1,2 m; se construye
  contra 1,4 para no quedar al filo.
- El `.tres` horneado pasa de 285 a ~410 polígonos y el horneado de 12 a 80 ms.
- **A escala final el horneado son 1,8 s y 415 MB de pico**, medidos sobre un sintético de
  690 muros. Es un piso: el mapa real va a tener más geometría. Conviene re-medirlo cuando el
  greybox crezca, no asumirlo.
- **`NavigationObstacle3D.height` queda en 1,8** —el obstáculo del caído sigue siendo tan
  alto como una persona parada— y eso **no se corrige acá a propósito**: es exactamente el
  campo que va a tocar el trabajo del salto del zombie sobre un cuerpo (`docs/plan.md`,
  v0.5 y v0.6), y cambiarlo ahora invalidaría el comportamiento que se acaba de medir.
- **Todo cambio de geometría, de parámetros de horneado o de `NavigationObstacle3D` /
  `NavigationAgent3D` obliga a correr el barrido de conectividad** (`.claude/skills/`). Este
  bug existió tres semanas sin que nada lo detectara.
- `_respawn_point()` necesitó un chequeo de alcanzabilidad propio, porque
  `map_get_closest_point()` ignora la conectividad y aceptaba puntos dentro de islas.
  `map_get_closest_point_owner()` y `region_owns_point()` no sirven: la isla pertenece a la
  misma región que el patio. Solo distingue pedir un camino y mirar dónde termina, a 26 µs
  la consulta.
