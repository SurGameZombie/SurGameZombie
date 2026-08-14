# Mapa del sistema de trabajo

> **Documento de trabajo de la reestructuración. No es documentación final del proyecto.**
> Se absorbe en `ESTADO.md` cuando llegue esa parte, o se borra si deja de hacer falta.
> Hermano de `inventario-pares.md` (qué datos están duplicados) y `permisos-curados.md`
> (por qué el allowlist era como era).

Levantado el **13/8/2026**, desde el lado de Claude Code: qué se me carga, qué me llega,
qué ejecuta el harness sin pasar por mí, y qué de todo eso viaja entre las dos máquinas.

**Es descriptivo. No juzga, no propone y no marca problemas** — cuando algo está escrito
en un lugar y contradicho en otro, va anotado como está y sigue.

**Queda afuera:** el código de gameplay (`scripts/`, `scenes/` como lógica, `resources/`
como contenido). **Queda adentro** todo lo que condiciona cómo se trabaja, incluido
`tests/` como mecanismo de verificación y `tools/` como utilidad de proceso.

## Cómo leer cada dato

| Marca | Qué significa |
|---|---|
| **(leído)** | Está escrito en el archivo que se cita. Lo copié, no lo deduje |
| **(medido)** | Lo corrí o lo conté hoy, 13/8/2026, en esta máquina. Va con el número |
| **(inferido)** | Se deduce de algo que sí leí o medí, sin haberlo ejercido |
| **(no verificable desde acá)** | Lo digo porque me lo dijeron o porque falta la máquina/cuenta. Marcado como tal |

Todos los conteos de líneas y de tiempos son **medidos**, ninguno estimado.

---

# 1. Lo que se me carga, y cuándo

## 1.1 Residente: entra en cada arranque y no se va

Cinco archivos de prosa, más el índice de memoria. **(medido: `wc -l` y `wc -c`)**

| Archivo | Líneas | Bytes | Qué dispara la carga | ¿Viaja por git? | Quién lo mantiene |
|---|---:|---:|---|---|---|
| `~/.claude/CLAUDE.md` | 3 | 224 | Siempre, en todo proyecto de esta máquina | **No** — está en el home | Joaco |
| `CLAUDE.md` (raíz) | 225 | 10.654 | Siempre, al abrir sesión en este repo | Sí | Joaco + Claude Code |
| `.claude/rules/commits.md` | 116 | 4.965 | `paths: ["**"]` | Sí | Joaco + Claude Code |
| `.claude/rules/limites.md` | 43 | 1.802 | `paths: ["**"]` | Sí | Joaco + Claude Code |
| `.claude/rules/herramientas.md` | 57 | 2.535 | `paths: ["**"]` | Sí | Joaco + Claude Code |

**Total residente: 444 líneas / 20.180 bytes de prosa antes de que se escriba una sola
línea de código** (medido, sumando los cinco). Las líneas de frontmatter YAML de cada rule
están incluidas en ese conteo.

El `paths: ["**"]` de las tres rules es literal en el frontmatter **(leído)**: el scope es
todo el repo, así que en la práctica se comportan como una extensión de `CLAUDE.md`. Las
dos primeras lo dicen explícitamente en su propio cuerpo — `limites.md` abre con "estas
tres secciones vivían en `CLAUDE.md` y se movieron acá para bajarlo de 200 líneas"
**(leído)**, y `herramientas.md` con "el scope es todo el repo porque la decisión de sumar
una herramienta no nace tocando un archivo en particular" **(leído)**.

**El índice de memoria** también entra siempre: `~/.claude/projects/C--Proyectos-SurGameZombie/memory/MEMORY.md`,
6 líneas con 4 entradas **(medido)**. Los memos en sí —27 a 30 líneas cada uno— no se
cargan enteros; entran cuando algo los hace relevantes. **No viaja por git**: vive en el
home. Las cuatro entradas de hoy son: atribuir inferencias vs. decisiones; parar ante
avisos del sistema; qué se pagó de la deuda de red de v0.3; el cierre de la Parte 1 de la
reestructuración.

## 1.2 Path-scoped: entra solo al tocar ciertos archivos

| Rule | Líneas | `paths:` declarado |
|---|---:|---|
| `.claude/rules/gdscript.md` | 154 | `**/*.gd` |
| `.claude/rules/netcode.md` | 119 | `scripts/net/**` · `scripts/combat/**` · `scripts/survival/**` · `scripts/inventory/**` · `scripts/world/**` · `scripts/player/**` · `scripts/enemies/**` · `scripts/ui/**` · `scenes/**` |

**(leído del frontmatter de cada uno.)**

**Medido en esta misma sesión:** al leer `tests/consistencia_test.gd`, `gdscript.md` se
inyectó entero en el contexto. `netcode.md` **no apareció ni una vez** en toda la sesión,
porque el mapeo no tocó ningún archivo bajo `scripts/` ni bajo `scenes/`. Es la mecánica
funcionando como está declarada, verificada por observación y no por lectura.

Consecuencias que salen de los globs, no de ninguna prosa **(inferido de los `paths:`)**:

- `tools/bake_navmesh.gd` y las seis suites de `tests/` **sí** cargan `gdscript.md` (el
  glob es `**/*.gd`, sin restricción de carpeta) y **no** cargan `netcode.md`.
- `.claude/rules/netcode.md` cubre `scenes/**` entero, o sea también `yard.tscn` y
  `yard_navmesh.tres`, que no tienen script.
- `resources/**` no está en el scope de ninguna de las dos.

## 1.3 Bajo demanda: nombre y descripción ahora, cuerpo después

Los skills cargan **solo `name` + `description`** al arrancar; el cuerpo entra al
invocarlos **(leído: `plan.md` §5, "Solo se carga el nombre y la descripción al inicio")**.

- `barrido-navmesh` — 191 líneas, en el repo. Descripción de 3 renglones **(medido)**.
- `catalogo-claude` — 2.423 bytes, en el home de Joaco, no en el repo **(medido)**.

Lo mismo con los docs: `docs/` no se carga solo. `CLAUDE.md` manda leer `plan.md`,
`bitacora.md`, `proceso.md` e `investigacion-claude-code.md` **antes de** ciertos tipos de
cambio **(leído)**, pero esa lectura la tengo que hacer yo con la herramienta de lectura;
no hay nada que la ejecute.

## 1.4 Lo que no se carga solo, y hay que ir a buscar

**(inferido de todo lo anterior, contrastado contra el árbol de archivos.)**

- Los 8 ADRs de `docs/decisions/` (633 líneas en total, medido).
- `docs/design.md` (410), `docs/netcode.md` (592), `docs/bitacora.md` (778),
  `docs/plan.md` (339), `docs/proceso.md` (239),
  `docs/investigacion-claude-code.md` (149), `docs/retrospectiva-v0.2.md` (1.063).
- Los dos docs de `docs/reestructuracion/` (182 + 312).
- `resources/items/README.md` (36).
- El catálogo externo entero.

Suma de `docs/` sin `decisions/` ni `reestructuracion/`: **3.570 líneas** (medido). Es el
material que existe y que entra al contexto solo si alguien lo pide o si yo decido leerlo.

---

# 2. Los dos hooks

Están declarados en `.claude/settings.json`, que **sí viaja por git**, así que los dos
corren en las dos máquinas **(leído)**.

Los dos cuelgan del mismo evento y del mismo matcher: **`PostToolUse` con
`matcher: "Edit|Write"`** **(leído)**. Corren *después* de que la edición ya se escribió al
disco, no antes.

## 2.1 `consistencia.sh` — corre la suite de tests

| | |
|---|---|
| **Para qué existe** | Ejecutar, en vez de pedir, la regla "corré la suite después de tocar esto". Su propio encabezado lo dice: *"la regla en prosa se cumple hasta que alguien tiene apuro"* **(leído)** |
| **Qué lo dispara** | Un `Edit` o `Write` cuyo `file_path` machee `*/scripts/*.gd`, `*/resources/*.tres`, `*/scenes/*.tscn` o `*/project.godot` **(leído, línea 38)** |
| **Qué hace** | Busca Godot en tres lugares en orden —`PATH`, `$GODOT_BIN`, `C:\Godot\Godot_v4.7.1-stable_win64.exe`— y corre las 6 suites de `res://tests` **(leído)** |
| **Timeout** | 120 s, con `asyncRewake: true` y `statusMessage: "Comparando los pares duplicados…"` **(leído de settings.json)** |
| **Config** | `timeout: 120`, declarado en `.claude/settings.json` |

**Códigos de salida (leído del script, medido corriéndolo):**

| Situación | Salida | Medido hoy |
|---|---|---|
| El archivo no machea ninguno de los cuatro patrones | `exit 0`, en silencio | ✔ probado con `docs/plan.md` |
| La suite pasa | `exit 0`, borra el log temporal | ✔ probado con `scripts/player/player.gd` — **3.134 ms** |
| La suite falla | `exit 2` (bloqueante) + hasta 6 líneas de detalle a stderr | no ejercido hoy |
| No encuentra Godot | `exit 0` + `systemMessage` avisando que la suite **no** corrió | no ejercido hoy |

Dos detalles de implementación que el propio script explica **(leído)**:

- **No usa `jq`** —"no está instalado en estas máquinas"— sino dos `sed` sobre el JSON de
  stdin. El orden importa: primero desescapa `\\` y después convierte a `/`.
- **La salida de Godot va a un archivo, no a una variable.** Con el motivo medido escrito
  al lado: capturarla en `out=$(...)` lleva la misma corrida de **3,1 s a 14,6 s**.

## 2.2 `navmesh-recordatorio.sh` — recuerda, no hornea

| | |
|---|---|
| **Para qué existe** | Avisar que hay que rehornear el NavMesh y correr el barrido después de tocar la geometría del greybox |
| **Qué lo dispara** | `Edit`/`Write` sobre `*/scenes/main/yard.tscn` o `*/tools/bake_navmesh.gd` **(leído, línea 30)** |
| **Qué hace** | Imprime un JSON con `systemMessage` (a la pantalla) y `hookSpecificOutput.additionalContext` (a mí). No ejecuta Godot |
| **Timeout** | 15 s **(leído)** |
| **Salida** | `exit 0` siempre — medido en los dos caminos |

**Por qué recuerda en vez de hornear está escrito en el script (leído):** hornear
reescribiría `scenes/main/yard_navmesh.tres` —archivo versionado— como efecto colateral de
otra edición, y *"deja la sensación de que el asunto está cubierto cuando no lo está"*. El
`additionalContext` sale además del `systemMessage` a propósito: *"tiene que llegarle al
modelo, que es quien puede correr el skill, no solo a la pantalla"*.

El texto que me llega nombra el bug concreto contra el que existe: sellar **las dos**
puertas del galpón en el control negativo, porque con una sola el galpón sigue conectado
por la otra — *"el bug del commit `2519ff7`"* **(leído)**.

## 2.3 Qué no cubren

**(inferido de los patrones de cada `case`, contrastado con el árbol.)**

- **`consistencia.sh` no se dispara desde el lado "doc" de los pares que la suite compara.**
  `consistencia_test.gd` compara `docs/design.md` contra el código y
  `.claude/skills/barrido-navmesh/SKILL.md` contra `yard.tscn` — y ni `docs/*.md` ni
  `.claude/skills/**` están entre los cuatro patrones. Tocar `yard.tscn` sí la corre;
  tocar el `SKILL.md` que lo cita, no.
- **`tests/*.gd` y `tools/*.gd` no la disparan.** El patrón es `*/scripts/*.gd`.
- **`CLAUDE.md`, `.claude/rules/**` y `docs/**` no disparan ninguno de los dos.**
- **Solo cubren `Edit` y `Write`.** Una escritura por `Bash` (un `sed -i`, un `>`), por una
  tool de MCP (`script_patch`, `scene_save`, `settings_set` de godot-ai) o hecha a mano en
  el editor de Godot no pasa por `PostToolUse` y no dispara nada.
- **`consistencia.sh` corre la suite entera**, no solo `consistencia_test.gd`: el comando
  es `-a res://tests` **(leído, línea 62)**.
- **No hay ningún hook `PreToolUse`, `Stop`, `SessionStart` ni `PreCompact`.**
  `.claude/settings.json` declara únicamente el bloque `PostToolUse` **(leído)**.

---

# 3. Los docs de trabajo, uno por uno

## 3.1 De qué es fuente de verdad cada uno

| Doc | Líneas | Fuente de verdad de | Tiempo verbal |
|---|---:|---|---|
| `CLAUDE.md` | 225 | Estructura de carpetas, comandos, reglas de código, formato de respuesta | imperativo |
| `docs/design.md` | 410 | Qué es el juego, números **decididos**, huecos abiertos, milestones (tabla), reparto de trabajo | presente |
| `docs/netcode.md` | 592 | Autoridad de red, los tres patrones, qué entra al save, cómo se resuelve v0.1 y v0.2 | presente |
| `docs/plan.md` | 339 | Stack, milestones (prosa), assets, organización para Claude Code | presente/futuro |
| `docs/bitacora.md` | 778 | Estado actual, infraestructura, problemas ya resueltos, registro cronológico | pasado |
| `docs/proceso.md` | 239 | El **porqué** de commits, ADRs y diagnóstico | imperativo + explicación |
| `docs/investigacion-claude-code.md` | 149 | Modos de falla medidos de la IA en gamedev, los 10 pitfalls, los números de los estudios | pasado/dato |
| `docs/retrospectiva-v0.2.md` | 1.063 | Autoanálisis de v0.1+v0.2, fechado 5/8/2026 | pasado, congelado |
| `docs/decisions/*.md` (8) | 633 | Cada decisión arquitectónica, inmutable | pasado |
| `docs/reestructuracion/*.md` (2) | 494 | Trabajo en curso, se borran al absorberse | presente |

**(todas las líneas, medidas.)** La división de tres capas —guía activa / registro de
decisiones / trailers de commit— está declarada en `proceso.md` §2 **(leído)**.

## 3.2 `CLAUDE.md` — 225 líneas

Arranca con la versión de Godot como primer encabezado, y el propio archivo explica por
qué está ahí: *"declarar la versión explícitamente corta esa contaminación aproximadamente
a la mitad, y es la única medida con efecto medido"* **(leído)**.

Es **la única versión** de dos cosas, y lo dice: el árbol de carpetas (*"`docs/plan.md` §5
apunta acá, no la repite"*) y los comandos de línea de comandos. Contiene también las
reglas de código (static typing, idioma, input map), la política de datos como `.tres`, el
bloque citado de autoridad de red con puntero a `netcode.md`, el formato de las respuestas
en tres partes, y la lista de "qué NO hacer".

Su propia sección de mantenimiento fija dos umbrales **(leído)**: avisar si algo quedó
desactualizado respecto del código, y parar el proyecto si se está corrigiendo más del 30%
de lo que escribo.

`plan.md` §5 cita la recomendación de Anthropic de mantenerlo **bajo 200 líneas**
**(leído)**; hoy está en 225 **(medido)**. El inventario de pares ya registra ese desfase
como el par E7 **(leído)**.

## 3.3 `docs/design.md` — 410 líneas

Qué es el juego. Se diferencia de `plan.md` en que **plan.md decide el stack y design.md
decide el juego**. Secciones: Qué es · Ambientación · Qué NO es · Sistemas de la v1 ·
Escala y números base · Los primeros 10 items · Huecos por completar · Milestones ·
Reparto de trabajo **(leído)**.

Es fuente de verdad de dos cosas de proceso, no de diseño:

- **Los "Huecos por completar"**, con checkbox: hoy hay 2 abiertos (inventario propio vs.
  addon; dos jugadores levantando al mismo caído) y 3 cerrados con fecha **(medido
  contando los `- [ ]` y `- [x]`)**.
- **El reparto de trabajo.** Dice literalmente *"Los dos trabajamos en todo el proyecto. No
  hay carpetas con dueño fijo, incluido `project.godot`"*, y lo reemplaza por tres reglas:
  avisarse antes de arrancar diciendo sobre qué archivos, nunca dos personas sobre el mismo
  archivo, `git pull` siempre antes de empezar. Última revisión anotada: 2/8/2026 **(leído)**.

`plan.md` §5 tiene un bloque marcado como revisado que apunta acá para el reparto
**(leído)**.

## 3.4 `docs/netcode.md` — 592 líneas

La regla de autoridad, con su porqué. Se diferencia de `.claude/rules/netcode.md` en que la
rule restringe y este explica; la retrospectiva §2.9 anota que hoy las dos tienen las mismas
tablas **(leído)**.

Además de la regla, es el único lugar donde viven: los tres patrones de red con código, la
advertencia de que el `MultiplayerSynchronizer` **no** sincroniza el inventario solo, la
lista viva "Qué entra al save", el presupuesto de la bolsa de muerte, el plan de migración
de transporte, y los dos planes paso a paso "Cómo se resuelve v0.1" y "Cómo se resuelve
v0.2" **(leído de los encabezados)**.

Tiene **tres correcciones marcadas en el propio texto** —el RPC de v0.1, la distancia
horizontal del respawn, revivir en dos RPCs—, escritas dejando ver qué decía antes. La
retrospectiva §1.C2 las nombra como el patrón a repetir **(leído)**.

## 3.5 `docs/plan.md` — 339 líneas

El documento fundacional: decisión de stack, arquitectura de red, scope de la v1, assets
gratis, organización del proyecto para Claude Code, semana 1, riesgos. Es el más viejo y el
que tiene **dos bloques marcados como revisados que apuntan a otro doc** **(leído)**:

- §2, la regla de autoridad total del host → apunta a `netcode.md`.
- §5, el reparto de trabajo por carpetas → apunta a `design.md`.

Y un tercer bloque de estado, en §5, sobre gdUnit4: *"Estado real al 6/8/2026: esta mitad
del loop está abierta pero recién estrenada"*, con el texto anterior citado entre paréntesis
**(leído)**.

**§5 es la parte que condiciona cómo se trabaja**: explica cómo se reparten las
instrucciones entre `CLAUDE.md`, rules path-scoped, skills y hooks, y contiene la frase que
los dos hooks citan como origen — *"si escribís 'siempre que X, hacé Y' en `CLAUDE.md`,
probablemente debería ser un hook"* **(leído)**.

## 3.6 `docs/bitacora.md` — 778 líneas

Cinco bloques **(leído de los encabezados)**: Estado actual · Infraestructura y software ·
Decisiones tomadas · **Problemas que ya nos pasaron** · Riesgos identificados · Pendiente ·
Registro cronológico.

Se diferencia de los ADRs en que la bitácora es narrativa y mutable, y los ADRs son
inmutables. `proceso.md` §3 le asigna un rol operativo concreto: *"Todo bug que tarde más de
30 minutos en resolverse va a `docs/bitacora.md`, sección Problemas que ya nos pasaron, con
tres líneas: síntoma, causa, arreglo"* **(leído)**.

Hoy esa sección tiene **9 problemas resueltos** y la de Pendiente **8 ítems, 1 tildado**
**(medido)**. El Registro va del 1/8 al 10/8/2026 en orden inverso.

## 3.7 `docs/proceso.md` — 239 líneas

Cuatro secciones: Commits · Documentación · Cómo buscamos errores · Checklist antes de cada
commit **(leído)**.

Es **el porqué** de lo que `.claude/rules/commits.md` ordena, y las dos primeras líneas del
archivo de rules mandan leerlo antes de escribir cualquier mensaje de commit **(leído)**.
Desde el commit `b1a6ec5` la relación está declarada en los dos lados: §1 dice *"la
mecánica exacta está en `.claude/rules/commits.md`, que es la versión que gobierna"*
**(leído)**.

Contiene además tres cosas que no están en ningún otro lado: el formato de las cuatro
secciones de una ADR, la advertencia sobre ADRs generadas por IA (*"el Contexto y las
Alternativas las revisamos nosotros siempre"*), y el **orden para diagnosticar** de 5 pasos.

## 3.8 `docs/investigacion-claude-code.md` — 149 líneas

Datos externos, no decisiones del proyecto. Cuatro bloques: modos de falla documentados ·
los 10 pitfalls de GDScript · la tabla de números de 5 estudios · lo que funciona · el hueco
del multiplayer de Godot · **7 reglas operativas** **(leído)**.

`CLAUDE.md` lo cita como la razón de que la versión de Godot esté arriba de todo, y
`gdscript.md` como el origen del checklist de 10 puntos **(leído)**. Sus reglas operativas
3 y 5 —cortar la sesión a los 40 minutos, playtest de 15 minutos por milestone— no tienen
mecanismo que las dispare; el playtest está además como ítem en la lista de Pendiente de
`bitacora.md` **(leído)**.

## 3.9 `docs/retrospectiva-v0.2.md` — 1.063 líneas

El doc más largo del repo **(medido)**. Fechado 2026-08-05, escrito sobre 37 commits, 8
scripts y 7 ADRs, antes de arrancar v0.3. Es autoanálisis de Claude Code sobre su propio
trabajo, con las afirmaciones marcadas una por una como **verificado / inferido /
suposición** **(leído)**, y con una advertencia final de que *"lo escribió el mismo que
cometió los errores que enumera"*.

Cinco secciones: 1 autoanálisis (8 errores detectados, 14 no detectados, 8 aciertos, 5
patrones, 3 categorías de números asumidos) · 2 lo que falló en el proceso (10 ítems) · 3
estado real (deuda de verificación, deuda técnica, andamios de debug, inconsistencias,
huecos) · 4 lo aprendido y no escrito · 5 qué cambiaría para v0.3.

**Está parcialmente saldada dentro de sí misma**: §2.1 tiene agregado *"Resuelto el
10/8/2026, ver commit `b1a6ec5`"* **(leído)**. Sus §3.2, §3.4 y §3.6 son listas que
`inventario-pares.md` cita como uno de los lados de varios pares duplicados (F1, F2, F3).

## 3.10 Los ocho ADRs

633 líneas en total **(medido)**. Formato uniforme: Fecha · Estado · Fuente · Contexto ·
Decisión · Alternativas descartadas · Consecuencias **(leído)**.

| ADR | Fecha | Qué fija | Líneas |
|---|---|---|---:|
| 0001 engine-godot | 1/8 | Godot 4.7.1 standard, con las 3 razones en orden de peso | 68 |
| 0002 lenguaje-gdscript | 1/8 | GDScript + static typing obligatorio | 54 |
| 0003 autoridad-de-red-dividida | 1/8 | Cuerpo del jugador al peer, resto al host | 76 |
| 0004 plan-de-transporte | 1/8 | ENet → noray → Steam, aislado en un archivo | 60 |
| 0005 character-controller-propio | 1/8 | Escribirlo a mano; **decisión de aprendizaje, no técnica** | 48 |
| 0006 mcp-godot-ai | 1/8 | `hi-godot/godot-ai`, y que los tres candidatos de `plan.md` nunca se evaluaron | 57 |
| 0007 la-autoridad-no-se-reasigna-en-runtime | 2/8 | Regla general que generaliza el caso del caído | 80 |
| 0008 horneado-del-navmesh-y-cuerpo-caido | 5/8 | `cell_size` 0,10, radio del obstáculo 0,40, y que un cuerpo tapa una puerta | 190 |

Tres cosas que salen de leerlos como grupo:

- **Seis de los ocho se escribieron después de decidir**, no antes; la retrospectiva §2.6
  lo registra y nombra a 0007 como la única excepción **(leído)**. 0008 es posterior a esa
  retrospectiva, que lo había pedido en §5.4.
- **0008 tiene un bloque abierto marcado `[Pendiente de ustedes]`** en su decisión 3: el
  porqué de diseño no está registrado y el ADR dice explícitamente que escribirlo de memoria
  sería inventarlo **(leído)**.
- **Son inmutables por política**, y eso produce una divergencia declarada y aceptada: ENet
  dura "hasta v0.5" en 0004 y "hasta v0.6" en `plan.md` y `netcode.md`.
  `inventario-pares.md` la lista en "Lo que NO hay que arreglar" **(leído)**.

## 3.11 `docs/reestructuracion/inventario-pares.md` — 182 líneas

Salida del barrido completo de los **109 archivos versionados fuera de `addons/`**, hecho
el 10/8/2026 **(leído)**. Define "par sin comparador" como *"un hecho que tiene que decir lo
mismo en dos o más lugares del repo y hoy nada verifica"*.

Deja **53 pares abiertos** en seis familias —A números de gameplay, B duplicaciones internas
del código, C rutas y nombres, D versiones y rutas de herramientas, E prosa duplicada entre
`docs/` y `.claude/rules/`, F estado del proyecto duplicado entre docs— con dos marcas: 💥
"ya rompió algo acá" y 🔒 "comparable automáticamente con el molde de
`consistencia_test.gd`" **(leído)**.

Cierra con tres listas operativas: lo que **no** hay que arreglar (2 ítems), lo cerrado en la
Parte 1 (8 ítems con su commit), y los candidatos a la tanda 2 (5 ítems ordenados por qué
rompe silencioso).

## 3.12 `docs/reestructuracion/permisos-curados.md` — 312 líneas

La curación de `.claude/settings.local.json` del 11/8/2026: **78 entradas → 27**, y hoy 26
**(leído)**. Vale más el porqué que la lista, y el doc lo dice: la capa de permisos de
PowerShell descompone el comando en statements y evalúa cada uno por separado, así que un
`allow` con `*` **nunca puede matchear una cadena con `;` adentro** — de ahí salían las 78.

Contiene además cuatro cosas que condicionan cómo se trabaja hoy:

- La tabla de **lo que el harness protege sin que nadie configure nada** (7 situaciones que
  fuerzan `ask`, incluidas las combinaciones peligrosas con git).
- **Dos decisiones abiertas** (la asimetría de git entre shells; que `Bash(git commit *)` y
  `PowerShell(git *)` preaprueban el `git commit`) y **una resuelta** (`project_manage` e
  `input_map_manage` fuera del allowlist).
- El relato medido de lo que pasó el 2/8: `bind_event` creó las seis acciones de movimiento
  por `keycode` en vez de `physical_keycode`, y el arreglo terminó siendo editar
  `project.godot` a mano.
- **Una regla hacia adelante**: antes de sumar una tool de MCP al allowlist, chequear si
  mezcla lectura y escritura sobre un archivo versionado crítico.

## 3.13 Los dos README

- **`README.md` de la raíz: 1 línea**, `# SurGameZombie` **(medido)**.
- **`resources/items/README.md`: 36 líneas.** Es el único README con contenido operativo:
  fija que los pesos y `max_stack` son placeholders y no balance, que **balancearlos es de
  Mathi**, el procedimiento de 3 pasos para agregar un item, y una tabla medida de dónde
  sobrevive esa advertencia — con el dato de que **el comentario `;` adentro de un `.tres`
  se borra la primera vez que alguien guarda el archivo desde el Inspector de Godot**
  **(leído)**.

---

# 4. `tests/` y gdUnit4

## 4.1 `tests/consistencia_test.gd` — qué pares compara

318 líneas, 4 casos **(medido)**. No prueba comportamiento: prueba que dos archivos no se
hayan desincronizado **(leído del docstring)**.

| # | Par | Lado A | Lado B | Qué rompe si divergen |
|---|---|---|---|---|
| 1 | **C3** escenas spawneables | `world.gd`, cada `const *_SCENE: PackedScene = preload(...)` | `world.tscn`, los `_spawnable_scenes` del MultiplayerSpawner | El host instancia bien y el Spawner descarta la réplica |
| 2 | **A2** radio de cápsula | dentro de `player.tscn` | dentro de `zombie.tscn` | El obstáculo mide distinto que el cuerpo que representa |
| 3 | **A12** la vida | fila `\| Vida con la que te levantan \| X de Y \|` de `design.md` | `REVIVE_HEALTH` de `world.gd` y `max_health` de `player_stats.gd` | El doc de diseño y el código dicen números distintos |
| 4 | **C5** coordenadas del skill | `SKILL.md`: `sur.position`, `este.position`, `SPAWN_ZOMBIE` | `yard.tscn`: `WarehouseDoorSouthLintel`, `WarehouseDoorEastLintel`; `world.tscn`: `ZombieSpawn` | El control negativo del barrido deja de sellar y da verde sin controlar nada |

**(todo leído del archivo.)**

Cuatro decisiones de implementación que el propio archivo justifica **(leído)**:

- **Lee todo como texto con `FileAccess`, no instanciando escenas**, para comparar lo que
  está escrito en el archivo que se revisa en el diff, no lo que Godot ya resolvió en memoria.
- **Un ancla que no aparece es una falla, no un salto silencioso.** Si alguien renombra una
  constante, la suite se pone roja en vez de quedarse verde comparando cero cosas.
- Cada test junta problemas en una lista y cierra con `assert_str(...).is_empty()`, porque
  *"un assert suelto sobre un array vacío pasa"*.
- **Del par C5 compara solo X y Z.** Las Y nunca coincidieron y no tienen por qué: el skill
  usa 1.5 y 0.3, `yard.tscn` 4.2 y `world.tscn` 0.1.
- `RADIUS_TYPES` está acotado a 4 tipos (`CapsuleShape3D`, `CapsuleMesh`,
  `NavigationAgent3D`, `NavigationObstacle3D`) para que un `SphereShape3D` de trigger no
  entre a la comparación.

El docstring anota además un comportamiento medido del runner: **gdUnit4 corta la suite en
el primer caso que falla**, así que una corrida roja muestra un par desincronizado aunque
haya dos — *"con un par roto el runner reporta 48 de 49 casos y sale con código 100"*
**(leído)**.

## 4.2 Cómo se invoca

**Tres caminos, y solo uno es automático (leído + medido):**

1. **A mano**, con la línea de `CLAUDE.md`:
   `& $godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests`
2. **Por el hook** `consistencia.sh`, que corre exactamente ese comando (línea 62) cuando se
   edita un `.gd` de `scripts/`, un `.tres` de `resources/`, un `.tscn` de `scenes/` o
   `project.godot`.
3. **Desde el inspector de tests del editor** — no disponible hoy: `project.godot`
   `[editor_plugins] enabled` lista únicamente `res://addons/godot_ai/plugin.cfg`
   **(medido)**, y `bitacora.md` tiene ese paso como el único manual pendiente de la
   instalación **(leído)**.

**Sin `--ignoreHeadlessMode` sale con código 103 y no corre nada** **(leído de `CLAUDE.md`)**.

## 4.3 Las seis suites, medidas hoy

| Suite | Casos | Qué cubre |
|---|---:|---|
| `consistencia_test.gd` | 4 | Los cuatro pares de arriba |
| `inventory_test.gd` | 21 | Matemática del inventario, incluida `serialize`/`deserialize` |
| `inventory_requests_test.gd` | 8 | Las reglas con las que el host acepta o rechaza un pedido |
| `inventory_authority_test.gd` | 6 | Autoridad sobre el inventario |
| `item_catalog_test.gd` | 8 | Ids duplicados, vacíos y conteo del catálogo |
| `runner_smoke_test.gd` | 2 | Que el runner arranca, reporta, y que el tipado llega a los asserts |

**Corrida completa de hoy, 13/8/2026 (medido):** 6 suites, **49 casos, 0 fallas, 0
huérfanos, exit code 0**. Tiempo de reloj de punta a punta: **2.711 ms**; el runner reporta
**661 ms** de ejecución de tests. El resto es arranque de Godot.

Los reportes van a `reports/`, ignorado por git: **20 carpetas presentes, la última
`report_51`** **(medido)** — o sea que el runner viene numerando corridas desde hace rato y
conserva solo las últimas.

## 4.4 El rol de gdUnit4 en el flujo de verificación

**Cierra la mitad automática de un loop que `plan.md` §5 describe partido en dos (leído):**
tests headless para leer pass/fail estructurado, y un MCP server para ver el editor en vivo.

Lo que **no** cubre está escrito en tres lugares distintos **(leído)**:

- `.claude/rules/limites.md`: *"Nunca declares una tarea de gameplay terminada porque los
  tests pasen. Los tests miden corrección, no diversión, ni ritmo, ni sensación."*
- `CLAUDE.md` → Qué NO hacer: *"No dar por terminada una tarea porque los tests pasen."*
- `investigacion-claude-code.md`: el caso documentado del agente que veía verde y
  commiteaba mientras el juego hacía cero daño en 60 segundos.

La regla operativa que lo complementa es el **playtest de quince minutos sin código a la
vista por milestone** (regla 5 de `investigacion-claude-code.md`), que hoy figura como ítem
abierto en `bitacora.md` con v0.2 tildado el 6/8 y v0.3 pendiente **(leído)**.

**La convención de nombres es una restricción real, no estilo:** las suites van
`*_test.gd`, **nunca** `test_*.gd`, porque el `McpTestSuite` que trae godot-ai descubre por
el prefijo contrario y reportaría cada suite de gdUnit4 como error **(leído de `plan.md`,
marcado ahí como medido con los dos instalados)**. Los 6 archivos de `tests/` cumplen la
convención **(medido)**.

## 4.5 `tools/bake_navmesh.gd`

67 líneas. No es parte del juego: se corre con `-s` desde línea de comandos **(leído)**.

- Hornea `scenes/main/yard.tscn` y guarda en `scenes/main/yard_navmesh.tres`.
- **Sale con código 1 si algo falló**, y el propio docstring dice que es para poder colgarlo
  de un hook **(leído)**. Hoy el hook que existe recuerda correrlo, no lo corre.
- Tiene tres ramas de `return 1` que la retrospectiva §3.1 lista como nunca ejercidas
  **(leído)**.
- **Tira siempre un WARNING esperado** de parseo de mallas CSG, y el docstring avisa que
  *"cualquier OTRO warning sí hay que mirarlo"*. La retrospectiva A7 registra que ese ruido
  ya tapó un warning real durante dos commits **(leído)**.

---

# 5. La convención de commits

## 5.1 Dónde está documentada — y qué está en más de un lugar

| Pieza | `.claude/rules/commits.md` | `docs/proceso.md` §1 | `CLAUDE.md` | `investigacion-claude-code.md` |
|---|---|---|---|---|
| "Claude Code no commitea por iniciativa propia" | **regla completa** | puntero explícito | "No commitear sin que lo revisemos" | puntero (regla operativa 4) |
| Formato del mensaje | ✔ | ✔ **duplicado literal** | — | — |
| Tipos y scopes | ✔ | ✔ **duplicado literal** | — | — |
| `Rejected:` / `Directive:` / `Not-tested:` | tabla propia | tabla propia | — | — |
| `Tested-later:` | **único lugar con la mecánica** | menciona y apunta a la rule | — | — |
| Un commit = un cambio lógico | ✔ | ✔ | — | — |
| `git bisect` y por qué importa | menciona | **explicación completa** | — | — |
| Checklist de 8 puntos previo al commit | — | **único lugar** | — | — |

**(todo leído.)** La relación está declarada en los dos lados: `commits.md` abre con *"el
porqué de cada una está en `docs/proceso.md` §1"* y `proceso.md` §1 cierra con *"la mecánica
exacta está en `.claude/rules/commits.md`, que es la versión que gobierna"*. El commit
`b1a6ec5` (10/8) es el que dejó la regla del "no commitea solo" en un solo lugar y puso
punteros en los otros dos **(leído del subject y de la retrospectiva §2.1)**.

Lo que sigue escrito dos veces textualmente: el bloque de formato del mensaje, la lista de
tipos y la de scopes. `inventario-pares.md` no lo tiene fichado como par propio; la familia
E cubre los otros casos de duplicación entre `docs/` y `rules/`.

## 5.2 Los cinco trailers

| Trailer | Qué significa | Dónde está definido |
|---|---|---|
| `Rejected:` | Alternativa considerada y descartada, con la razón. Evita volver al mismo callejón | rule + proceso |
| `Directive:` | Instrucción permanente para quien toque esto después. Sobrevive a la conversación | rule + proceso |
| `Tested:` | Qué se verificó y cómo | proceso (en el bloque de formato); la rule lo lista en el formato pero no le dedica fila en su tabla |
| `Not-tested:` | Qué NO se verificó y por qué. **La rule lo llama "el más importante"** porque Claude Code no puede correr el juego | rule + proceso |
| `Tested-later:` | Va en el commit que **paga** una deuda y cita por hash al que la abrió. Es lo único que resta de la lista | **solo `.claude/rules/commits.md`** |

**(leído.)**

Tres reglas alrededor de `Not-tested:` que solo están en la rule **(leído)**:

- **Va solo cuando había algo ejecutable que no se ejerció.** Si el commit no cambia
  comportamiento en runtime, el trailer se omite entero. Nada de `Not-tested: nada que
  testear, es prosa`.
- **El commit viejo no se toca**: su `Not-tested:` original queda como estaba, porque
  reescribir el historial invalida los hashes que lo citan.
- **La deuda abierta son los `Not-tested:` cuyo hash no aparece citado en ningún
  `Tested-later:` posterior.**

## 5.3 Lo que se puede medir del historial hoy

**(medido, 13/8/2026, sobre `main`.)**

| Dato | Valor |
|---|---|
| Commits totales | **73** |
| Rango de fechas | 1/8/2026 → 12/8/2026 |
| Commits con `Directive:` | 53 |
| Commits con `Not-tested:` | 50 |
| Commits con `Tested:` | 44 |
| Commits con `Rejected:` | 40 |
| Commits con `Tested-later:` | **2** |
| Hashes distintos citados en un `Tested-later:` | **1** (`2d417f5`) |

O sea que la resta que la rule define existe pero recién arrancó: los dos `Tested-later:`
son de los commits `73918fc` y `cb6fd7c`, ambos del 11/8, y el primero es el que **introdujo
el trailer** — el segundo es el único que paga deuda hasta hoy **(medido + leído de los
subjects)**. Ese pago es además explícitamente parcial: el trailer dice que cubre solo la
mentira 3 de F4 y que fue un playtest manual entre el 7 y el 10/8, sin commit asociado
**(leído)**.

**Autores del historial (medido):** `Joaquin` 53 · `JoaquinLaptop` 16 · `Mathias` 2 ·
`surgamezombie-ui` 1 (el commit inicial, desde la web de GitHub). Los dos primeros son las
dos máquinas de Joaco; el primer commit desde la laptop es del 3/8/2026.

---

# 6. Configuración: qué viaja y qué no

| Archivo | ¿Git? | Qué define | Quién lo mantiene |
|---|---|---|---|
| `.mcp.json` | **Sí** (7 líneas) | Un solo server: `context7`, tipo `http`, `https://mcp.context7.com/mcp` | El repo |
| `.claude/settings.json` | **Sí** (46 líneas) | `additionalDirectories` al catálogo · 15 reglas `deny` sobre el catálogo · los 2 hooks | El repo |
| `.claude/settings.local.json` | **No** — `.gitignore:28` | 26 entradas `allow` · `enableAllProjectMcpServers: true` · `enabledMcpjsonServers: ["context7"]` | Cada máquina |
| Bloque de este proyecto en `~/.claude.json` | **No** | El MCP `godot-ai` entero · `hasTrustDialogAccepted: true` · `disabledMcpServers` · métricas de la última sesión | Cada máquina |
| `~/.claude/settings.json` | **No** | `defaultMode: "auto"` · `model: "opus"` · tema · notificaciones · `enabledPlugins: {}` | Joaco |
| `~/.claude/CLAUDE.md` | **No** (3 líneas) | La regla de no tocar nada de otro proyecto sin avisar | Joaco |
| `.gitignore` | **Sí** (43 líneas) | Ver abajo | El repo |
| `.editorconfig` | **Sí** (4 líneas) | `charset = utf-8`, nada más | El repo |
| `.gitattributes` | **Sí** (2 líneas) | `* text=auto eol=lf` | El repo |
| `.vscode/settings.json` | **No** — `.gitignore:43` | La ruta de Godot para `godot-tools` | Cada máquina |

**(todo leído; los conteos, medidos.)**

## 6.1 `.claude/settings.json` — lo que viaja

Dos bloques **(leído)**:

- **`permissions.additionalDirectories`**: `C:\ClaudeMCPsPlugingsSkillsETC`. Es lo que hace
  que el catálogo sea legible desde este proyecto.
- **`permissions.deny`**: 15 reglas, todas de la forma `Edit(//c/ClaudeMCPsPlugingsSkillsETC/...)`,
  que cubren los `.md` de la raíz, `.claude/**`, y las carpetas `skills`, `plugins`, `mcp`,
  `connectors`, `hooks`, `comandos`, `otros`, `comparativas`, `propio`, `investigacion`,
  `plantillas` y `proyectos/webpersonal`. **El único lugar del catálogo que no queda
  denegado es `proyectos/surgamezombie/`** (inferido de la lista: no hay regla que lo
  incluya), que es exactamente donde `.claude/rules/herramientas.md` dice que va la decisión
  de este proyecto **(leído)**.
- **`hooks.PostToolUse`**: los dos ya descritos.

## 6.2 `.claude/settings.local.json` — lo que no viaja

26 entradas de `allow` **(medido contando el array)**. La composición, del doc de la
curación **(leído)**: 3 web (`WebSearch` + 2 dominios de Godot + github), 2 de Context7,
3 de godot-ai (`editor_state`, `api_manage`, `session_manage` — las tres solo leen), 5 de
Godot por PowerShell escritas **una por statement**, 3 de PowerShell general (`git *`,
`Get-Content *`, `Get-Process *`), 6 de Bash, y 2 de `Read` acotadas a `~/.claude/**` y
`~/.local/bin/**`.

El `.gitignore` explica por qué se ignora, y por qué no alcanza con el gitignore global de
una máquina: *"en la otra el archivo no está ignorado y un `git add` amplio se lo lleva"*
**(leído)**.

## 6.3 El bloque de este proyecto en `~/.claude.json`

Clave `C:/Proyectos/SurGameZombie` **(medido)**. Lo que contiene y condiciona el trabajo:

- **`mcpServers.godot-ai`** — tipo `stdio`. El comando es `pythonw.exe` lanzando un
  `subprocess.call` que a su vez corre `~/.local/bin/uvx.exe --from godot-ai==3.1.2 godot-ai
  attach --port 8000 --ws-port 9500`. **Rutas absolutas del home**, que es la razón escrita
  en `bitacora.md` de por qué no está en `.mcp.json` **(leído)**.
- `hasTrustDialogAccepted: true`, `hasCompletedProjectOnboarding: true`.
- `disabledMcpServers: ["claude.ai Notion", "claude.ai Gmail"]` — dos connectors apagados
  para este proyecto.
- `allowedTools: []` — vacío; los permisos viven en `settings.local.json`.
- `loggedAuthoredArtifactPaths: [".claude/skills/barrido-navmesh/SKILL.md"]`.
- Métricas de la última sesión (costo, duración, tokens por modelo). No condicionan nada.

`mcpServers` global, fuera de todo proyecto: **vacío** **(medido)**.

## 6.4 `.gitignore` — qué excluye a propósito

43 líneas, **7 bloques con comentario que explica el porqué** **(leído)**:

| Qué | Por qué, según el archivo |
|---|---|
| `.godot/`, `/android/`, `*.tmp` | Caché de import, se regenera |
| `/build/`, `*.exe`, `*.pck`, `*.zip` | Exportaciones |
| `export_presets.cfg` | Guarda rutas locales y, si algún día firman builds, credenciales |
| `/reports/` | Los escribe el runner en cada corrida, numerados, crecen sin límite y solo le sirven a quien los corrió |
| `.claude/settings.local.json` | Rutas absolutas del home y la lista de comandos que **esa máquina** aceptó — "al revés que `.claude/settings.json`, que sí va al repo porque define los hooks para los dos" |
| `para-mathi/` | "Material para Mathi. Es de la máquina de cada uno, no del proyecto" |
| `.DS_Store`, `Thumbs.db`, `.vscode/` | Sistema y editor |

Los dos bloques del medio —`settings.local.json` y `para-mathi/`— llevan además la misma
nota: la exclusión existía solo en un archivo local de la PC de escritorio, así que en
cualquier clon nuevo la carpeta aparecía como una más **(leído)**. `para-mathi/` entró al
`.gitignore` el 12/8/2026, en el commit `2461fbf` **(medido)**.

---

# 7. MCPs, skills y plugins

## 7.1 `godot-ai` — MCP del editor

| | |
|---|---|
| **Qué es** | `hi-godot/godot-ai`, **43 tools** contra el editor en vivo. Plugin en `addons/godot_ai/`, commiteado |
| **Dónde se declara** | En `~/.claude.json`, por proyecto. **No en `.mcp.json`, y es a propósito**: su comando lleva rutas absolutas del home **(leído: `bitacora.md`, ADR-0006)** |
| **Versión** | `godot-ai==3.1.2` fijada en el comando **(medido)**. El plugin se autoactualiza — `inventario-pares.md` D2 anota que ese par se desincroniza solo |
| **¿Viaja?** | El **plugin** sí (está en el repo). La **configuración del server** no. Los **permisos** sí viajarían si no fuera que `settings.local.json` está ignorado — o sea que tampoco |
| **Permisos hoy** | 3 tools preaprobadas, las tres de solo lectura: `editor_state`, `api_manage`, `session_manage`. `project_manage` e `input_map_manage` salieron el 11/8 **(leído: `permisos-curados.md`)** |
| **Efecto en el repo** | Registra el autoload `_mcp_game_helper` en `project.godot` **(medido)**, y es el único plugin en `[editor_plugins] enabled` |

**Medido hoy: en esta sesión no hay ni una tool `mcp__godot-ai__*` expuesta.** El server
solo publica tools cuando hay un editor de Godot conectado; sin editor abierto, no aparece
nada. Es la distinción que `session_manage` existe para separar, según `permisos-curados.md`
**(leído)**.

Dos cosas anotadas fuera del repo que lo condicionan: **escucha en el puerto 8000**, el
mismo que usa otro proyecto de Joaco, con la salida anotada en el 8899; y **Vision Routing
queda apagado por decisión**, tomada el 6/8/2026 — con eso prendido, cada screenshot saldría
a un proveedor externo **(leído: catálogo y `bitacora.md`)**.

## 7.2 Context7 — MCP de documentación

- Declarado en **`.mcp.json`, que viaja por git** — a propósito, por el mismo motivo que
  `addons/godot_ai/` está commiteado: que las dos máquinas corran la misma configuración
  **(leído: `bitacora.md`)**.
- **Es remoto**: las consultas salen a un servidor de terceros. La bitácora lo marca
  explícitamente — *"no es telemetría oculta, es cómo funciona, pero no es local"*.
- **Pide aprobación una vez por máquina**, la primera vez que arranca Claude Code después de
  traerse el archivo. Está anotado como esperado, no como error.
- Habilitado en `settings.local.json` por dos vías a la vez: `enableAllProjectMcpServers:
  true` y `enabledMcpjsonServers: ["context7"]` **(medido)**.
- **Para qué está**: ataca la mitad del problema de version drift que declarar la versión en
  `CLAUDE.md` no cubre. La retrospectiva C3 registra que en 37 commits no se alucinó ninguna
  API **(leído)**.

En esta sesión sus dos tools están disponibles como diferidas: `resolve-library-id` y
`query-docs` **(medido)**.

## 7.3 `barrido-navmesh` — skill del repo

191 líneas, en `.claude/skills/barrido-navmesh/SKILL.md`, **viaja por git** **(medido)**.

**Para qué existe**, textual: *"este proyecto tuvo tres semanas los cuatro vanos de la
oficina tapiados para el zombie sin que nada lo detectara: el juego arrancaba, no había ni
un error, y el zombie se quedaba clavado contra un muro 19 segundos"* **(leído)**.

**Cuándo se activa (leído):** cambió la geometría de `yard.tscn`; cambió `cell_size`,
`cell_height`, `agent_radius` o `agent_height`; cambió el `radius`/`height` de un
`NavigationObstacle3D` o `NavigationAgent3D`; apareció un zombie que no llega a algún lado.
La invocación es del modelo o de Joaco — **el hook la recuerda, no la dispara**.

**Estructura:** dos reglas que lo hacen servir (asignar la malla antes de que la región
entre al árbol; **control negativo obligatorio, siempre**) · procedimiento en 3 pasos con
dos scripts descartables `_bake.gd` y `_query.gd` · cómo leer el mapa de 59×59 caracteres
(`#` alcanzable, `X` hay NavMesh pero no llega, `.` sin NavMesh) · la fórmula del ancho de
franja · la prueba de aceptación · la limpieza, que termina en `git status --short` teniendo
que estar como antes.

**Está acoplado al mapa por coordenadas escritas a mano**, y eso es lo que
`consistencia_test.gd` vigila en su cuarto caso **(leído de los dos archivos)**. El propio
skill tiene registrada su corrección del 6/8: decía "tapiar una puerta" y su ejemplo tapiaba
solo la sur, lo que dio un falso verde.

Los dos scripts que escribe **quedaron fuera del allowlist a propósito** —"son archivos que
el modelo acaba de escribir, con contenido distinto en cada corrida"—, así que correr el
skill cuesta tres prompts de permiso **(leído: `permisos-curados.md`)**.

## 7.4 `catalogo-claude` — skill de usuario

Vive en `~/.claude/skills/catalogo-claude/SKILL.md`, **no en el repo**, así que **no viaja**
y en la otra máquina hay que instalarla aparte **(medido: no existe en el repo)**.

Qué dice, resumido de la lectura completa **(leído)**:

- **Qué es el catálogo**: la decisión ya tomada sobre cada skill, plugin, MCP, connector,
  hook y comando — qué es, si vale la pena, por qué, contra qué compite y qué la haría
  cambiar de veredicto. Incluye lo descartado.
- **Si no puede leer la ruta**, decírselo a Joaco en vez de rodearlo: falta
  `additionalDirectories` en el `settings.json` del proyecto.
- **Orden de búsqueda**: `INDICE.md` → `VEREDICTOS.md` → la ficha puntual →
  `comparativas/` si hay más de una opción.
- **Cuatro reglas al usarlo**: nada `peligroso` se instala sin avisar con el riesgo concreto;
  verificar autor/repo exacto, nunca solo el nombre; tratar los `⚠️ datos vencidos` como
  histórico; y *"un veredicto del catálogo es un antecedente, no una orden"*.
- **Para anotar**: escribir **únicamente** dentro de `proyectos/<slug>/`, con el motivo y,
  si es diferido, el gatillo concreto; commitear y pushear solo los archivos propios, nunca
  `--force`.
- **Lo que nunca se hace**: editar fuera de `proyectos/<slug>/`, tocar la carpeta de otro
  proyecto, o pegar texto crudo de un README ajeno.

Su descripción está escrita para **no** dispararse sola: *"Usar SOLO cuando se pida
explícitamente… No usar para preguntas generales sobre skills, plugins o MCPs"* **(leído)**.

`.claude/rules/herramientas.md`, que sí está en el repo y carga siempre, cubre el mismo
terreno desde adentro del proyecto **(leído)**.

## 7.5 Plugins: ninguno

**(medido)** `~/.claude/plugins/installed_plugins.json` lista dos plugins —`frontend-design`
y `claude-md-management`, ambos del marketplace `anthropics/claude-plugins-official`— y los
dos están instalados con `scope: "project"` y `projectPath: "C:\WebPersonal"`. **Ninguno
está instalado para SurGameZombie.** `~/.claude/settings.json` tiene `enabledPlugins: {}`.

## 7.6 Skills que aparecen y no son del proyecto

En el listado de esta sesión aparecen además skills que trae el harness —`dataviz`,
`artifact-design`, `artifact-diagramming`, `artifact-capabilities`, `update-config`,
`keybindings-help`, `code-review`, `simplify`, `fewer-permission-prompts`, `loop`,
`schedule`, `claude-api`, `claude-in-chrome`, `run`, `init`, `security-review`
**(medido)**. No están en el repo, no viajan con él, y no las mantiene el proyecto. Se
nombran acá solo porque comparten el mismo listado que las dos propias.

---

# 8. Lo de afuera del proyecto que lo condiciona

## 8.1 El catálogo, `C:\ClaudeMCPsPlugingsSkillsETC`

**Es otro repo de git**, `Mosland/ClaudeMCPsPlugingsSkillsETC`, en rama `main`
**(medido)**. No es una carpeta suelta: se clona y se pushea aparte.

**Tamaño (leído del `INDICE.md`, actualizado el 12/8/2026): 66 fichas y 3 comparativas.**
Distribución de archivos hoy **(medido)**: 19 en `mcp/`, 19 en `skills/`, 10 en `plugins/`,
16 en `otros/`, 3 en `comparativas/`, 2 en `connectors/`, y `hooks/` y `comandos/` vacías.

Cuatro archivos de raíz: `INDICE.md` (índice maestro por tipo), `VEREDICTOS.md` (corte por
decisión), `PENDIENTES.md` (*"datos que se afirmaron con más seguridad de la real"*) y
`CLAUDE.md` (las reglas de trabajo del catálogo). Los seis veredictos posibles son `vale`,
`condicional`, `no-vale`, `peligroso`, `no-existe`, `sin-evaluar`, más la marca 💸 de
descartado por costo **(leído)**.

**Cómo entra a este proyecto:** por `additionalDirectories` en `.claude/settings.json`, que
sí viaja. **Con qué permiso:** solo lectura en todo salvo `proyectos/surgamezombie/`.
**Cuándo se lee:** `.claude/rules/herramientas.md` lo hace obligatorio *antes* de sumar
cualquier MCP, skill, plugin, connector o hook, con el orden `INDICE.md` → `VEREDICTOS.md`
→ ficha → `comparativas/` **(leído)**.

**Lo que este proyecto escribió ahí**: `proyectos/surgamezombie/README.md`, 11.903 bytes,
última actualización 12/8/2026 **(medido)**. Contiene la tabla de lo instalado (godot-ai,
Context7, `barrido-navmesh`, gdUnit4), lo diferido con gatillo (`blender-mcp`, cuando haya
`.glb` que normalizar), lo sin evaluar (`expressobits/inventory-system`), lo descartado
(generación de assets por IA, agent-browser), y una sección "Cómo se verificó" que marca la
procedencia de cada afirmación **(leído)**.

`.claude/rules/herramientas.md` deja registrado el caso que originó esa disciplina: la ficha
de gdUnit4 lo tuvo como diferido **seis días después de que ya estaba instalado y
corriendo**, porque la nota se transcribió de una fuente vieja sin contrastarla contra el
repo **(leído)**.

## 8.2 La carpeta de Mathi

**`para-mathi/` no existe en esta máquina** **(medido: no está en el árbol)**. Está en el
`.gitignore` desde el 12/8/2026 **(medido: commit `2461fbf`)**, con el motivo escrito:
*"Material para Mathi. Es de la máquina de cada uno, no del proyecto"* **(leído)**.

**`contexto-claude-mathi.md`: no lo encontré.** Busqué por nombre en `C:\Proyectos` y en
`C:\Users\joaqu` hasta 3 niveles y no aparece **(medido)**. **No puedo verificar si existe
en la otra máquina** — el archivo estaría por definición fuera de git.

Lo que sí está escrito sobre el reparto con Mathi, y condiciona cada respuesta
**(leído)**: `CLAUDE.md` dice *"Joaco programa y Mathi no: toda tarea que no requiera código
va marcada como delegable a Mathi"*, y `.claude/rules/limites.md` → "De quién es" enumera
qué entra en esa categoría: diseño, ambientación, curaduría o modelado de assets, layout del
mapa, balance y números de gameplay, mockups de UI. `resources/items/README.md` es hoy el
único archivo del repo que aplica la regla nombrando a Mathi explícitamente **(medido)**.

En el historial, `Mathias` tiene **2 commits, los dos del 1/8/2026, los dos con el mismo
subject** (`docs: agrego mi nombre al reparto de trabajo`) **(medido)**.

## 8.3 La segunda máquina

**Confirmada por el historial (medido):** los autores `Joaquin` (53 commits) y
`JoaquinLaptop` (16) comparten el mismo mail. El primer commit desde la laptop es del
3/8/2026.

`bitacora.md` fija que la ruta local es `C:\Proyectos\SurGameZombie` **en ambas máquinas**,
y que las dos tienen Godot 4.7.1-stable standard, VS Code con `godot-tools`, y Blender
**(leído)**.

**Qué viaja y qué no, resumido de la sección 6:**

| Viaja | No viaja |
|---|---|
| `CLAUDE.md`, las 5 rules, `.claude/skills/barrido-navmesh/` | `.claude/settings.local.json` (permisos) |
| `.claude/settings.json` (hooks + additionalDirectories + deny) | El bloque de `~/.claude.json` (config del MCP godot-ai) |
| `.mcp.json` (Context7) | `~/.claude/settings.json` y `~/.claude/CLAUDE.md` |
| `addons/godot_ai/` y `addons/gdUnit4/` | La skill de usuario `catalogo-claude` |
| Todo `docs/`, `tests/`, `tools/` | La memoria de `~/.claude/projects/…/memory/` |
| | `para-mathi/`, `.vscode/`, `reports/` |

El README del catálogo lo dice desde el otro lado **(leído)**: *"Nada de lo que se instale
con `claude mcp add` o `/plugin install` viaja solo entre la PC y la laptop… Lo que sí viaja
es la decisión de qué instalar y cuándo — por eso está anotada acá"*.

`inventario-pares.md` D4 registra la consecuencia concreta: la ruta
`C:\Godot\Godot_v4.7.1-stable_win64.exe` está copiada a mano en varios lugares y *"este par
está roto por diseño en la máquina de Mathi"* **(leído)**.

## 8.4 El chat de criterio

**Lo único que puedo verificar desde acá es que existe y que ya produjo un dato que entró a
un repo.** `proyectos/surgamezombie/README.md` del catálogo tiene una fila cuya procedencia
dice: *"⚠️ No sale del repo. Lo confirmó Joaco en un chat de criterio, el 2026-08-12"*, sobre
si la suite se corrió de punta a punta en las dos máquinas **(leído)**.

Ese mismo doc saca de ahí una directiva: *"cuando una corrida valga en las dos máquinas, que
el trailer `Tested:` lo diga. Un dato que solo vive en un chat se pierde cuando se cierra el
chat"* **(leído)**.

**Que ese chat corra en otra cuenta y con otro presupuesto me lo dijeron en el pedido; no
lo puedo verificar desde acá** — no hay nada en el repo, en el catálogo ni en la config
local que lo registre. Lo que sí es verificable es la consecuencia: **lo que se decide ahí
llega a este proyecto solo si alguien lo transcribe.** No hay canal automático.

---

# 9. El ciclo, tal como lo veo desde acá

## 9.1 Qué me llega al arrancar, y en qué orden

**(medido sobre esta sesión.)**

1. El prompt del harness: entorno, plataforma, shell, directorio de trabajo, scratchpad, y
   el directorio adicional del catálogo.
2. `~/.claude/CLAUDE.md` (3 líneas) y `CLAUDE.md` (225).
3. Las tres rules de scope `**`: `commits.md`, `limites.md`, `herramientas.md` (216 líneas).
4. `MEMORY.md`, el índice de 4 memorias.
5. El listado de skills disponibles: solo nombre y descripción.
6. El listado de tools, con la mayoría **diferidas** — se cargan sus esquemas cuando hacen
   falta. Las de Context7 están ahí; las de godot-ai **no aparecen** en esta sesión.
7. Un snapshot de `git status` y los últimos commits, con la aclaración de que es una foto
   y no se actualiza durante la conversación.
8. El pedido de Joaco.

Durante la sesión se suman: `gdscript.md` al tocar cualquier `.gd`, `netcode.md` al tocar
`scripts/<subsistema>/` o `scenes/`, el cuerpo de un skill al invocarlo, y el
`additionalContext` de `navmesh-recordatorio.sh` cuando corresponda.

## 9.2 Qué produzco

- **Ediciones de archivo**, que disparan los hooks.
- **Comandos**, que pasan por la capa de permisos: los 26 `allow` de
  `settings.local.json`, más las reglas del harness que fuerzan `ask` sin que nadie las
  configure **(leído: `permisos-curados.md`)**.
- **Una respuesta con el formato de tres partes** que fija `CLAUDE.md`: *Qué cambié* / *Probá
  vos* / *Decidí vos*, con las que no aplican omitidas enteras y objetivo de largo de media
  pantalla **(leído)**.
- **Un mensaje de commit preparado**, cuando la tarea lo pide. No el commit.
- **Docs**, cuando el cambio es de proceso: entradas de `bitacora.md`, ADRs, o documentos de
  trabajo como este.

## 9.3 Qué se aprueba, qué se commitea, qué se pushea

**El corte está en el commit, y es explícito (leído):**

> `.claude/rules/commits.md`: *"El default es preparar el mensaje y parar ahí. Terminar una
> tarea no habilita a commitearla. Ni 'ya que estamos', ni porque el cambio sea chico, ni
> porque los tests pasen, ni porque el commit anterior lo hayan pedido."*

La autorización es **por pedido y no se hereda**: vale para ese pedido, no para la tarea
siguiente ni para la próxima sesión. Si en ese mismo pedido hay más de un cambio lógico, la
autorización cubre todos los commits que hagan falta para separarlos bien.

`proceso.md` §1 da el porqué: *"el commit es el punto donde nosotros revisamos el diff, y
automatizarlo elimina el único control de calidad que tenemos"*. Y el checklist de 8 puntos
de §4 es lo que se supone que se pasa antes de cada uno.

**Dos cosas medidas sobre esa frontera:**

- `settings.local.json` tiene `Bash(git commit *)` y `PowerShell(git *)` preaprobados, así
  que **el prompt del sistema no aparece**; la regla es de comportamiento. Está anotado como
  decisión abierta n.º 2 en `permisos-curados.md` **(leído)**.
- **`push` no está preaprobado por ninguna regla de Bash**, pero `PowerShell(git *)` lo
  cubre. `permisos-curados.md` lo registra como la asimetría de la decisión abierta n.º 1
  **(leído)**.

No encontré ninguna regla escrita que fije cuándo se pushea. La única que toca el tema es
`bitacora.md` → *"`git pull` antes de empezar a trabajar, siempre"*, y la de `design.md` →
Reparto de trabajo, que dice lo mismo **(leído)**.

## 9.4 En qué momentos se pierde contexto

**Los que están documentados en el repo (leído):**

| Momento | Dónde está escrito |
|---|---|
| **A los ~40 minutos** de un refactor largo — "pierde el track de qué archivos ya editó" | `investigacion-claude-code.md`, regla operativa 3 |
| **Entre features**, donde la regla pide `/clear` | ídem |
| Cuando la sesión se hace larga, `CLAUDE.md` me pide **avisarlo y sugerir cortar** | `CLAUDE.md` → Tareas chicas |
| **Alrededor de las 30.000 líneas** de repo, donde grep devuelve miles de falsos positivos | `investigacion-claude-code.md` |

La retrospectiva §2.10 registra que nada obliga a cortar a los 40 minutos, y que el paso 6
de v0.2 fue cuatro commits de gameplay, un playtest, un fix y dos commits de documentación,
todo el mismo día **(leído)**.

**Los que se ven desde acá y no están escritos en ningún doc (inferido):**

- **Entre sesión y sesión.** Lo único que sobrevive automáticamente es lo que está en
  archivos: el repo, los 4 memos de `~/.claude/projects/…/memory/`, y el índice `MEMORY.md`.
  Todo lo demás de una conversación se pierde al cerrarla.
- **Al compactar dentro de una sesión larga.** El resumen conserva lo esencial, no el
  detalle de qué archivos se tocaron.
- **Entre las dos máquinas.** La memoria vive en el home, así que lo que se aprendió
  trabajando en la PC no está disponible en la laptop, y al revés.
- **Entre el chat de criterio y este proyecto.** Ver 8.4: el único canal es la transcripción
  a mano.
- **El snapshot de `git status` que me llega al arrancar es una foto** y el propio harness
  avisa que no se actualiza durante la conversación.

**Y los mecanismos que existen precisamente para que algo sobreviva a esa pérdida
(leído):** los trailers `Not-tested:` y `Directive:`, que la rule describe como el lugar
donde queda lo que si no se pierde; las entradas de `bitacora.md` → Problemas; los ADRs; y
las cuatro memorias del proyecto.

---

## Apéndice: qué se leyó y qué se corrió para escribir esto

**Leído entero:** `CLAUDE.md`, `~/.claude/CLAUDE.md`, las 5 rules, los 2 hooks,
`.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`, `.gitignore`,
`.editorconfig`, `.gitattributes`, `.vscode/settings.json`, `tests/consistencia_test.gd`,
`tools/bake_navmesh.gd`, `.claude/skills/barrido-navmesh/SKILL.md`,
`~/.claude/skills/catalogo-claude/SKILL.md`, `docs/proceso.md`,
`docs/investigacion-claude-code.md`, `docs/plan.md`, `docs/bitacora.md`,
`docs/retrospectiva-v0.2.md`, los 8 ADRs, los 2 docs de `docs/reestructuracion/`,
`resources/items/README.md`, `README.md`, y del catálogo: `README.md`,
`proyectos/surgamezombie/README.md` y los encabezados de `INDICE.md`, `VEREDICTOS.md` y
`PENDIENTES.md`.

**Leído parcial:** `docs/design.md` (encabezados + "Huecos", "Milestones", "Reparto de
trabajo") y `docs/netcode.md` (encabezados + "La regla"), por quedar su cuerpo del lado del
gameplay que este mapa excluye.

**Corrido hoy, 13/8/2026:**

- La suite completa de gdUnit4 → 6 suites, 49 casos, exit 0, 2.711 ms.
- `consistencia.sh` con un `file_path` que no machea → exit 0 instantáneo.
- `consistencia.sh` con `scripts/player/player.gd` → exit 0, 3.134 ms.
- `navmesh-recordatorio.sh` con un `.gd` cualquiera → exit 0, silencioso.
- `navmesh-recordatorio.sh` con `scenes/main/yard.tscn` → exit 0, JSON con los dos campos.
- `wc -l` / `wc -c` sobre todos los archivos citados con número.
- `git rev-list`, `git log --grep` por cada trailer, y `git log --format=%an` para los
  autores.
- Lectura del bloque de este proyecto en `~/.claude.json` y de
  `~/.claude/plugins/installed_plugins.json`.

**No verificado:** si `contexto-claude-mathi.md` existe en la máquina de Mathi o en la
laptop; si `para-mathi/` existe en la otra máquina; en qué cuenta y con qué presupuesto
corre el chat de criterio; y el camino de fallo de los dos hooks (`exit 2` de
`consistencia.sh` y la rama de "no encuentro Godot"), que hoy no se ejercieron.
