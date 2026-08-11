# Permisos curados de `.claude/settings.local.json`

> **Documento de trabajo de la Parte 3. Aplicado el 11/8/2026: 78 entradas → 27, más
> una agregada el mismo día → 28.**
> Se borra cuando se absorba en `ESTADO.md`.

El archivo está en `.gitignore:28`, o sea que **es por máquina**: esta curación vale para
la de Joaco y la de Mathi va a tener otra.

## Por qué había 78 entradas — la causa real

Vale más que la lista, porque es lo que evita que vuelvan a juntarse.

Leyendo el bundle de Claude Code (`~/.local/bin/claude`), la capa de permisos de
PowerShell hace esto: **spawnea un PowerShell de verdad para parsear el comando a AST**,
lo descompone en statements, y evalúa **cada statement por separado** contra las reglas.
Un `allow` con `*` solo puede matchear **un statement**, nunca la cadena entera.

De ahí sale todo lo demás. Las entradas históricas eran cadenas largas con `;` adentro —
`$godot = "..."; & $godot --headless ...; "EXIT=$LASTEXITCODE"`. Una regla así **no puede
matchear ningún statement individual**, porque ningún statement contiene los tres pedazos.
Solo servía por match exacto de la cadena completa. Por eso cada variación mínima
—agregar un `echo` al final, cambiar la escena— pedía aprobación de cero y sumaba una
entrada más.

**La forma que sí sirve es una regla por statement.** Es el cambio de fondo de esta
curación; la poda de las muertas es la consecuencia.

## La premisa de arranque estaba mal

El pedido original decía "rutas de scratchpad de sesiones que ya no existen". **Los
directorios sí existen** — hay 21, y los tres UUID que aparecían en los permisos están
entre ellos. Lo que las mataba es que cada entrada guardaba el comando entero con el UUID
adentro, y una sesión nueva estrena UUID: el string aprobado no se vuelve a emitir nunca.
El matcheo es contra el texto del comando, no contra el filesystem.

---

## Partición de las 78

| Grupo | Cuántas | Qué se hizo |
|---|---|---|
| **A.** Amplias, con `*` o sin argumento | 20 | quedaron 18 |
| **B.** Exactas con UUID de sesión | 18 | borradas |
| **C.** Exactas que apuntan a un `.gd` borrado | 3 | borradas |
| **D.** Exactas de un solo uso | 27 | borradas |
| **E.** Godot por PowerShell, mal formadas | 10 | reescritas como 5 por statement |

**78 → 27.** Serían 23 si godot-ai se fuera del proyecto —y siguen siendo 23 con la alta
de abajo, porque es de godot-ai. La partición de arriba es la foto de la curación; lo que
se agregó después va en "Altas posteriores".

### B, C y D — las 48 que se fueron

**B (18)** con UUID de sesión adentro; doce eran la misma llamada a `Start-Process` con
`-RedirectStandardOutput` a un archivo distinto. Entre ellas un
`Bash(rm -rf .../scratchpad/proj)`, que además convenía que no quedara de arrastre.

**C (3)** corrían un `.gd` que ya no está: `probe_typed.gd`, `probe_variant.gd`,
`smoke_check.gd`. Ninguno de los ocho scripts de andamio que aparecían existe hoy.

**D (27)** de un solo uso: 10 `awk`/`sed`/`grep -v` con el texto exacto de una salida
puntual, 5 `curl` de la instalación de gdUnit4 y de releases de Claude Code, 3 variantes
de `echo "EXIT=$?"`, 3 formas del conteo de líneas de `CLAUDE.md`, 2 `git log` con combo
exacto —una con el SHA `a3a1dc5` fijo—, y 4 chequeos de setup ya hechos.
`WebFetch(domain:expressobits.com)` también salió: fue un dominio de investigación de una
sesión, no una fuente del proyecto.

---

## E. Godot por PowerShell: 10 → 5, por statement y por script

```
PowerShell($godot = "C:\\Godot\\Godot_v4.7.1-stable_win64.exe")
PowerShell(& $godot --headless --path . --import*)
PowerShell(& $godot --headless --path . res://scenes/main/world.tscn*)
PowerShell(& $godot --headless --path . -s res://tools/bake_navmesh.gd*)
PowerShell(& $godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd*)
```

La asignación de `$godot` es su propio statement y va como regla propia. Las otras cuatro
son los comandos de `CLAUDE.md` § Comandos. El `*` final absorbe la cola de **ese**
statement (`--ignoreHeadlessMode -a res://tests`, `--quit-after 90`,
`; "EXIT=$LASTEXITCODE"` queda afuera por ser otro statement, y el suyo ya está aprobado).

### Son dos scripts `-s`, no tres

El pedido nombró `tools/bake_navmesh.gd`, `GdUnitCmdTool.gd` y "el runner de la suite de
consistencia". **Los dos últimos son el mismo:** la suite no tiene runner propio, la corre
gdUnit4 (`consistencia.sh:62`, y la línea de `CLAUDE.md`).

### Los dos que el skill se escribe solo quedaron afuera

`barrido-navmesh` escribe `_bake.gd` y `_query.gd` en la raíz, los corre con `-s` y los
borra (`SKILL.md` 140-142 y 188). **No entraron al allowlist**, por el motivo que
justifica todo el ajuste: son archivos que el modelo acaba de escribir, con contenido
distinto en cada corrida. Aprobar `_bake.gd` por nombre no acota nada — es una etiqueta
fija sobre contenido arbitrario.

Criterio: **se aprueba de antemano el script que está en git; pide permiso el que no.**
Cuesta tres prompts por corrida del skill, que solo corre después de tocar `yard.tscn`.

---

## A. Las 18 que se quedan

Con `*` o sin argumento, así que matchean una familia entera:

```
WebSearch                                       PowerShell(git *)
WebFetch(domain:docs.godotengine.org)           PowerShell(Get-Content *)
WebFetch(domain:godotengine.org)                PowerShell(Get-Process *)
WebFetch(domain:github.com)                     Bash(git add *)
mcp__context7__resolve-library-id               Bash(git commit *)
mcp__context7__query-docs                       Bash(git checkout *)
Bash(/c/Godot/Godot_v4.7.1-stable_win64.exe *)  Bash(cd *)
Read(//c/Users/joaqu/.claude/**)                Bash(node *)
Read(//c/Users/joaqu/.local/bin/**)             Bash(xargs wc -l)
```

Más las cuatro de godot-ai (`editor_state`, `api_manage`, `input_map_manage`,
`project_manage`), que valen igual esté el MCP declarado donde esté: el permiso matchea
por nombre de tool, no por dónde se declara el servidor.

Salieron por redundantes `PowerShell(git add *)` y `PowerShell(git --no-pager log *)`:
`PowerShell(git *)` ya las cubre.

### El cambio de `Read`

`Read(//c/Users/joaqu/**)` —lectura de todo el perfil: `.ssh`, `.aws`, Documentos— bajó a
`Read(//c/Users/joaqu/.claude/**)`, que es lo único que se usó de verdad.

Efecto colateral: **`Read(//c/Users/joaqu/.local/bin/**)` pasó de redundante a
necesaria**, porque `.local/bin` no cuelga de `.claude/`. Ahí vive el `uvx.exe` que lanza
godot-ai y el binario de Claude Code que se auditó para escribir esto.

---

## Altas posteriores

### `mcp__godot-ai__session_manage` — 11/8/2026

```
mcp__godot-ai__session_manage
```

Es el diagnóstico de godot-ai: `op=list` devuelve las sesiones de editor conectadas con
su `godot_version`, `plugin_version`, escena abierta y `readiness`. Con `count=0` la
respuesta separa las dos fallas que desde afuera se ven igual —**el servidor MCP caído**
contra **el servidor sano pero sin editor abierto**— en una sola llamada. Sin esto, la
primera tool que se use falla con `PLUGIN_DISCONNECTED` y hay que salir a mirar `netstat`
y la lista de procesos para saber cuál de las dos es.

Entró la primera vez que se probó el MCP de punta a punta, que es justo el escenario donde
la distinción importa: el servidor estaba levantado con 8000 y 9500 escuchando, y lo único
que faltaba era abrir el editor.

**No se puede escribir el `op` en la regla.** Los permisos de MCP son por nombre de tool y
nada más; el parser del bundle rechaza los paréntesis con *"MCP rules do not support
patterns in parentheses"* y ofrece dos formas: el nombre pelado, o `mcp__<server>__*` para
todas las tools del servidor. Acá no cambia nada igual: `session_manage` expone `list` como
única op, así que el permiso por tool es tan angosto como uno por op.

Que la alternativa sea `mcp__godot-ai__*` vale tenerlo presente para la decisión 3 de
abajo: hoy hay cinco entradas de godot-ai sobre las 43 tools que publica el servidor.

---

## Lo que el harness ya protege sin que nosotros hagamos nada

Del mismo análisis del bundle. Estas capas corren **además** de las reglas, y varias
tocan cosas que sí hacemos acá:

| Situación | Qué hace |
|---|---|
| El parseo del comando falla (timeout, `pwsh` caído, comando muy largo) | `ask` — "malformed syntax that cannot be parsed". Falla cerrado |
| Operador de background job `&` | `ask` — "spawns a child PowerShell process" |
| `cd`/`Set-Location` compuesto **+ git** | `ask` — "to prevent bare repository attacks" |
| Escritura a rutas internas de git (`HEAD`, `objects/`, `refs/`, `hooks/`) + git | `ask` — "could plant a malicious hook that git then executes" |
| Rutas UNC (`\\host\share`) | `ask` — pueden disparar tráfico de red |
| Rutas de provider no-filesystem (`env::`, `hklm::`, `hkcu::`, `registry::`…) | `ask` |
| `using` / `#Requires` | `ask` — pueden cargar código externo |

O sea que `PowerShell(git *)`, que es la regla más ancha del archivo, **igual pide
permiso** en las combinaciones peligrosas con git. La decisión 2 de abajo sigue valiendo,
pero es menos grave de lo que parecía.

`pwsh` (PowerShell 7) no está instalado en esta máquina; el detector cae a
`fell_back_to_powershell_5` y usa el `powershell.exe` 5.1 que sí está. El parser funciona
igual.

---

## Dos decisiones que siguen abiertas

1. **Asimetría de git entre shells.** `PowerShell(git *)` aprueba todo git —incluido
   `push --force` y `reset --hard`—, mientras que Bash tiene tres entradas granulares.
   Conviene elegir un criterio y aplicarlo a los dos lados.

2. **`Bash(git commit *)` y `PowerShell(git *)` pre-aprueban el `git commit`.** No
   contradice `.claude/rules/commits.md` —esa regla es de comportamiento y la sigo
   igual—, pero el permiso saca el prompt del sistema, que era la última red si la regla
   fallara.

3. **Dos de las cinco de godot-ai ya aprueban escrituras, sin que se haya decidido.**
   Como la regla no puede acotar el `op`, aprobar el nombre aprueba todas las ops del
   tool. `editor_state`, `api_manage` y `session_manage` solo leen. Las otras dos no:
   `project_manage` incluye `settings_set` —escribe `project.godot` y lo persiste— y
   `stop`; `input_map_manage` incluye `add_action`, `bind_event` y `remove_action`, que
   también escriben `project.godot`. O sea que el input map, que `CLAUDE.md` fija por
   `physical_keycode` para movimiento y `keycode` para atajos, hoy se puede reescribir
   sin prompt.

   Sí queda el diff: `project.godot` está versionado, así que un cambio se ve en
   `git status`. Eso lo vuelve visible, no bloqueado.

   La decisión de fondo es dónde va la línea. Si es "lectura sin prompt, escritura con
   prompt", estas dos entradas están del lado equivocado y la única forma de arreglarlo
   es sacarlas —no hay manera de aprobar `settings_get` y no `settings_set`—. Si la
   línea es "que quede en el diff", están bien y conviene escribirlo para no volver a
   discutirlo. Lo que no sirve es el estado actual, que es el resultado de que las tools
   agrupen ops de lectura y de escritura bajo un nombre, no de una elección nuestra.

   El mismo razonamiento decide `mcp__godot-ai__*`: de las 43 tools del servidor, las 38
   que faltan son casi todas de escritura (`script_patch`, `node_manage`, `scene_save`,
   `resource_manage`). El wildcard es la versión maximal de la segunda línea.

## Lo que esta curación NO arregla

`D4` del inventario: la ruta `C:\Godot\Godot_v4.7.1-stable_win64.exe` sigue copiada a
mano — ahora en dos entradas en vez de en veintidós, pero sigue. Poner Godot en el PATH
—lo que `CLAUDE.md` ya recomienda— dejaría los permisos como
`PowerShell(godot --headless --path . -s res://tools/bake_navmesh.gd*)` y cerraría D4 y
esto de una.
