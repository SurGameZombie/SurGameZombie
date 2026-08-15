# Bitácora

Registro de qué se hizo, qué se decidió y por qué. Se actualiza cuando pasa algo que
alguien va a necesitar recordar en dos meses.

---

## Estado actual

**Setup terminado.** Los dos pueden clonar, editar, subir y bajar cambios.

**v0.1 está desbloqueada.** Las tres decisiones que faltaban para poder escribir el primer
código —modelo de autoridad, primera o tercera persona, idioma del código— están tomadas.
Cómo se resuelven v0.1 **y v0.2** —paso a paso, con las dependencias marcadas— está escrito
en `docs/netcode.md`.

**v0.2 está cerrada de verdad.** El 6/8/2026 se jugó el playtest de quince minutos sin
código a la vista y salió bien, así que el milestone cumple por fin su propio criterio de
terminado: no "los tests pasan" ni "está escrito", sino jugado de punta a punta. Red,
character controller, mundo, zombie, daño, caído, revivir y respawn están conectados **y
probados jugando**. Detalle en el Registro.

**Pendiente antes de escribir código:** tutorial oficial 3D de Godot, los dos.
Los `[DECIDIR]` que quedan abiertos en `docs/design.md` no bloquean v0.1.

---

## Infraestructura

| | |
|---|---|
| Organización GitHub | `SurGameZombie` |
| Repositorio | `SurGameZombie` (público, desde el 6/8/2026) |
| Ruta local | `C:\Proyectos\SurGameZombie` en ambas máquinas |
| Mail del proyecto | Gmail dedicado, con verificación en dos pasos |
| Roles | Ambos Owner de la organización y con permiso de escritura en el repo |

Las cuentas personales de GitHub son de cada uno, con su mail personal. El Gmail del
proyecto es solo para la organización y para futuras cuentas (itch.io, Steam, sitios de
assets), nunca para las cuentas personales.

## Software instalado (ambas máquinas)

- Git for Windows, con `git config --global user.name` y `user.email` configurados
- **Godot 4.7.1-stable, versión standard** (no .NET) — misma versión exacta en las dos
- VS Code + extensión `godot-tools`, configurado como editor externo de Godot
- Blender

## Configuración del proyecto Godot

- Renderer: **Forward+**
- Lenguaje: **GDScript** con static typing obligatorio
- El `project.godot` está en la raíz del repo, no en una subcarpeta

---

## Decisiones tomadas

### Engine: Godot 4.7, no Unreal ni Unity

Tres razones, en orden de peso:

1. **Compatibilidad con Claude Code.** Godot serializa todo en texto (`.tscn`, `.tres`,
   `.gd`), así que un agente puede leer y editar el proyecto entero. Unreal guarda el
   contenido del editor en `.uasset` binario, ilegible para un agente. Unity es texto
   (YAML) pero lleno de GUIDs y frágil de editar a mano.
2. **Hardware.** La máquina de desarrollo tiene una RX 6500 XT de 4 GB de VRAM. Unreal 5
   pide 6 GB como mínimo realista y 8 recomendado. Queda descartado por hardware, no solo
   por preferencia.
3. **Precedentes directos del género.** *Road to Vostok* (survival FPS realista, Early
   Access en Steam desde abril 2026) y *Nevoa* (survival horror 3D multijugador, Expresso
   Bits) están hechos en Godot.

**Trade-off aceptado:** Godot 3D se ve peor out of the box, no tiene terrain system oficial
(hay que usar Terrain3D), y el ecosistema de tutoriales de survival 3D es más chico. El
último 20% de pulido visual lo ponemos nosotros.

### Lenguaje: GDScript, no C#

Es el lenguaje de primera clase de Godot, no tiene paso de compilación (loop de feedback
más corto, que es lo que hace productivo a Claude Code), y toda la documentación y los
addons están en GDScript.

**Static typing obligatorio.** GDScript es dinámico por default y eso rompe la detección
de errores. Sin tipos, ni el editor ni Claude Code agarran nada hasta runtime.

### Red: listen server con autoridad dividida

Un jugador hostea y juega en el mismo proceso. 2-4 jugadores.

**Revisado el 1/8/2026.** La regla original decía "el host es autoridad sobre *todo* el
estado". Resultó demasiado absoluta: aplicada al movimiento del propio jugador obliga a
implementar client-side prediction —el cliente simula, guarda cada input y lo reaplica
cuando llega la corrección del host—, porque si no, cada paso se ve con un round-trip de
retraso. Es de las cosas más difíciles del netcode y no es por donde arranca un primer
juego.

El modelo definitivo afloja **solo** el movimiento:

- El cuerpo del propio jugador es autoridad del peer dueño → `is_multiplayer_authority()`
- Todo el resto (vida, daño, inventario, hambre, sed, stamina, zombies, loot, mundo) es
  autoridad del host → `multiplayer.is_server()`

Se puede aflojar ahí y en ningún otro lado porque no hay PvP ni anti-cheat que defender:
confiarle al cliente su propia posición cuesta cero. Lo que **no** se afloja es la
consecuencia de esa posición: si el disparo impacta, si el zombie lo alcanza o si llega a
agarrar el item lo sigue decidiendo el host. Detalle completo y el porqué en
`docs/netcode.md`, que es la fuente de verdad.

Retrofitear autoridad después sigue siendo una reescritura, por eso el reparto va definido
desde el commit uno.

**Plan de transporte:** ENet por IP ahora → netfox.noray para v1.0 (sin port forwarding) →
SteamMultiplayerPeer si alguna vez va a Steam. La creación del peer vive solo en
`scripts/net/network_manager.gd` para que cambiar sea un cambio de diez líneas.

### Scope de la v1

- 3 stats (vida, hambre, sed) + stamina. Temperatura, heridas y enfermedad quedan para v2.
- Un solo tipo de zombie.
- Un melee y un arma de fuego con munición escasa.
- **Mapa cerrado y denso, no mundo abierto.** Un mundo grande y vacío es más caro en red y
  menos divertido que un pueblo chico bien hecho.

### Character controller: propio, no `expressobits/character-controller`

Lo escribimos nosotros. El addon nos ahorra una tarde a cambio de no entender lo más básico
del juego, y escribirlo a mano es la mejor forma de entender Godot: `CharacterBody3D`,
`_physics_process`, `move_and_slide()` y el manejo de input son la base de todo lo que
viene después.

Es una decisión de aprendizaje, no técnica. El addon seguramente sea mejor código que el
que escribamos la primera vez. Pero el riesgo declarado de este proyecto es perder contacto
con el propio código (ver "Riesgos identificados"), y el controller del jugador es
justamente el archivo que no nos podemos permitir tratar como caja negra.

### Input map: movimiento por `physical_keycode`, atajos de UI por `keycode`

`keycode` sigue el **layout** del teclado; `physical_keycode` sigue la **posición física**
de la tecla. En un AZERTY francés, un WASD bindeado por `keycode` cae en cuatro teclas
desparramadas; bindeado por posición física, el francés aprieta las mismas cuatro teclas
que nosotros aunque le impriman ZQSD.

La convención, en `CLAUDE.md` → "Reglas de código":

- **Movimiento → `physical_keycode`.** La mano va a una posición, no a una letra.
- **Atajos de UI → `keycode`.** Que la tecla que dice I sea la que abre el inventario.

Hoy no cambia nada: las dos máquinas son QWERTY. Se decide igual porque cambiarlo después
es tocar cada binding a mano y nadie se acuerda de por qué estaba así.

**Ojo con el MCP:** `input_map_manage` **solo puede bindear por `keycode`.** No expone
`physical_keycode` ni `InputEventKey.location` (el que distingue Shift izquierdo de
derecho). Los bindings de movimiento hay que escribirlos a mano en `project.godot` o
cargarlos por el diálogo de Input Map del editor, tildando *Physical*.

### Assets: CC0 gratis, una sola familia visual

Kenney + KayKit como base, Quaternius para animaciones y personajes. La coherencia visual
importa más que la calidad individual de los modelos: mezclar packs de estilos distintos da
un asset flip.

### Tooling: MCP server `hi-godot/godot-ai`

Instalado y configurado (commit `37fc970`). El plugin vive en `addons/godot_ai/` y está
commiteado en el repo, así que las dos máquinas corren la misma versión.

Por qué este y no otro:

- Se autoconfigura con Claude Code desde el propio editor, sin editar configs a mano.
- Licencia MIT.
- Mantenimiento activo.
- Expone 43 tools contra el editor en vivo.

No es ninguno de los tres que evalúa `docs/plan.md` §5 (GDAI, Coding-Solo, alexmeckes):
esa lista quedó vieja porque el plan se escribió **antes** de compararlos de verdad.

Registra un autoload `_mcp_game_helper` en `project.godot`. Es esperado, no un accidente.

**Vision Routing queda apagado, y eso es una decisión, no un default que nadie miró.** Desde
la 3.1.2 el plugin trae `vision_routing.gd`: con eso habilitado, cada screenshot del editor
o del juego se manda a un proveedor externo —Groq, Google o xAI, con API key propia— y vuelve
como una descripción de texto en vez de la imagen. Viene apagado de fábrica y sin key no hace
nada, y el 6/8/2026 se decidió dejarlo así: las capturas de este proyecto no salen de la
máquina. Si alguna vez se prende, se anota acá con qué proveedor quedó configurado.

### Tooling: Context7 como MCP de documentación

Agregado el 2026-08-05, en `.mcp.json` en la raíz del repo.

El modo de falla número uno del proyecto es que el modelo escribe Godot 3 en vez de 4.7.
Declarar la versión arriba de todo en `CLAUDE.md` corta esa contaminación a la mitad;
Context7 ataca la otra mitad, metiéndole la doc real de 4.7 en contexto en vez de que la
escriba de memoria.

Gratis, free tier sin API key. **Es un MCP remoto:** las consultas de documentación salen
a un servidor de terceros. No es telemetría oculta —es cómo funciona— pero no es local.

Va en `.mcp.json` y no en configuración local **a propósito**, por el mismo motivo por el
que `addons/godot_ai/` está commiteado: las dos máquinas tienen que correr la misma
configuración de MCP (ADR-0006).

**Pide aprobación una vez por máquina**, la primera vez que arranca Claude Code después de
traerse el archivo. Es esperado, no un error: un MCP que viene de un archivo del repo no se
confía solo, porque ese archivo pudo haber llegado en un pull.

`godot-ai` **no** va en `.mcp.json`: su comando tiene rutas absolutas del home de cada
usuario, así que lo configura el propio plugin desde el editor. La simetría entre máquinas
de ese la da tener `addons/godot_ai/` commiteado, no este archivo.

---

## Problemas que ya nos pasaron

Documentados porque van a volver a pasar.

**El proyecto quedó anidado.** "Create New Project" en Godot crea una subcarpeta con el
nombre del proyecto, así que el `project.godot` terminó un nivel más abajo de la raíz del
repo. Se arregló re-clonando limpio y copiando a mano los archivos del proyecto (sin la
carpeta `.godot`, que se regenera sola).

→ **Regla permanente: nunca "Create New Project". Siempre "Import" apuntando al
`project.godot` del repo clonado.**

**Error 403 al hacer push.** Ser miembro de la organización no da permiso de escritura
sobre los repos. Se arregló dándole rol de administrador. Si vuelve a pasar y los permisos
están bien, la otra causa típica son credenciales viejas de GitHub guardadas en el
Administrador de credenciales de Windows.

**Push rechazado con "fetch first".** El remoto tenía commits que la copia local no tenía.
Se arregla con `git pull` antes del push.

→ **Regla permanente: `git pull` antes de empezar a trabajar, siempre, no solo cuando algo
falla.**

**"nothing to commit, working tree clean" con cambios hechos.** El archivo estaba editado
pero sin guardar. En VS Code, el puntito blanco en la pestaña significa sin guardar.

**gdUnit4 no se pudo instalar desde el AssetLib.** El botón *Download* quedaba
deshabilitado, con la versión colgada en `Version: Loading...` indefinidamente.
**El AssetLib sigue fallando y no lo investigamos más**, porque el rodeo funciona.

→ **Resuelto el 6/8/2026 salteándolo.** Se baja el zip del tag directo de GitHub
(`https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v6.2.0.zip`) y se copia
`addons/gdUnit4/` a mano. El zip del tag **no trae la carpeta `test/` del propio addon**
—el `.gitattributes` del repo la marca `export-ignore`—, así que lo que entra son 272
archivos y 1.1 MB, no el repo entero. Anda en 4.7.1-stable: verificado corriéndolo.

**Un autoload nuevo no existe para el editor abierto hasta reiniciarlo.** Agregar el
autoload deja `project.godot` correcto (`NetworkManager="*res://..."`, con el `*` de
singleton) y `autoload_manage list` lo muestra, pero cualquier script que lo nombre falla
con `Compile Error: Identifier not found: NetworkManager`. El editor registra los nombres
de autoload como identificadores globales **al arrancar**, y agregarlo en caliente no
vuelve a correr ese paso.

`filesystem_manage(op="scan")` **no alcanza**: reconstruye la tabla de `class_name`, no la
de autoloads (`global_classes_registered_delta: 0`).

→ **Regla permanente: después de agregar un autoload, reiniciar el editor.** Para
distinguir "el código está mal" de "el editor no lo ve", correrlo en un proceso limpio:
`& $godot --headless --path . --quit-after 60`. Si ahí arranca sin errores, el código está
bien. Ese comando ahora sirve porque ya existe `run/main_scene`; la advertencia de
`CLAUDE.md` sobre `--quit` era de cuando no estaba definida.

**El editor cachea escenas y `force_reload` del MCP no siempre las suelta.** Después de
editar `world.tscn` a mano en disco, el editor abierto seguía sirviendo el árbol viejo por
`scene_get_hierarchy`, incluso pidiendo `scene_open(force_reload = true)` y saltando a otra
escena y volviendo. El archivo en disco estaba bien.

Es el mismo problema que el autoload y que `project.godot`, con otra cara: **el editor
abierto es una copia en memoria, no una vista del disco.** El riesgo real no es la lectura
vieja sino que el editor guarde y pise el archivo.

→ **Regla permanente: si se editó un `.tscn` a mano con el editor abierto, reiniciarlo antes
de tocar esa escena en el editor.** Para verificar mientras tanto, correrlo en proceso
limpio: `& $godot --headless --path . res://ruta/a/escena.tscn --quit-after 90`. Eso lee de
disco y ejecuta los `_ready()`, así que sirve de smoke test real.

**Un `class_name` nuevo no existe para nadie hasta que se reimporta.** Al agregarle
`class_name Player` a `player.gd`, cualquier otro script que lo nombrara fallaba con
`Parse Error: Could not find type "Player" in the current scope`, aunque el archivo estaba
bien escrito. La tabla de clases globales se arma al escanear el filesystem, no al parsear.

→ **Regla permanente: después de agregar un `class_name`, correr
`& $godot --headless --path . --import` antes de correr nada más.** Es la misma familia que
el problema del autoload de acá abajo: el registro de nombres globales es un paso aparte del
parseo. La salida del import lo confirma —lista `Player` bajo `update_scripts_classes`—, así
que si el nombre no aparece ahí, no va a resolver.

**Godot pisa los cambios que git hace en `project.godot`.** Si un `git pull` modifica
`project.godot` con el editor abierto, Godot detecta el cambio externo y pregunta qué
hacer. Hay que elegir **"Reload from disk"**.

Nunca **"Ignore external changes"**: eso deja al editor trabajando con la versión vieja en
memoria, y la primera vez que Godot guarde project settings reescribe el archivo con esa
versión y borra lo que bajó de git. Como `project.godot` lo tocan los dos (autoloads, input
map, capas de física), es la forma más fácil de pisarle el trabajo al otro.

→ **Regla permanente: si `project.godot` cambió por git, "Reload from disk". Lo más seguro
es cerrar el editor antes de hacer `git pull`.**

**Decenas de errores de "Unable to create shader cache directory" al correr dos
instancias.** Salen en el Debugger apenas arrancan las dos, con la forma
`Unable to create shader cache directory <AlgoShaderRD>/<hash> at user://shader_cache`
(`servers/rendering/renderer_rd/shader_rd.cpp:1053` y `:1063`). **Es inofensivo y no es
código nuestro.**

Las dos instancias comparten el mismo `user://` —sale del nombre del proyecto, no de la
instancia— y arrancan juntas, así que las dos intentan crear los mismos subdirectorios de
caché de shaders al mismo tiempo. Una gana el `make_dir` y la otra loguea el error. La que
pierde compila el shader igual: lo único que no hace es guardarlo en caché esa corrida.
No se corrompe nada.

Verificado reproduciéndolo, no razonándolo: con la caché tibia no aparece nunca, ni con
una instancia ni con dos. Borrando `user://shader_cache` y largando dos juntas, aparece.
La cantidad cambia en cada corrida (vimos 28 y 6) porque depende de cuántos shaders
alcance a inicializar la perdedora antes de que la otra termine de crear los directorios.

→ **No hay nada que arreglar.** Si molesta el ruido, correr una instancia sola una vez
antes del playtest deja la caché armada y los errores no vuelven a aparecer.

**Las cuatro reglas `ask` sobre `git commit` y `git push` no piden confirmación.** Se
escribieron el 13/8/2026 en `.claude/settings.json` —el archivo que viaja— justamente para
que la regla de `.claude/rules/commits.md` dejara de ser solo prosa. `0c5f9bf` las dejó
anotadas como no verificadas: *"no se vio el prompt todavía… Se ve en la primera sesión
nueva"*.

**Qué se probó, el 14/8/2026, en la primera sesión nueva desde entonces.** Se esperaba un
prompt de confirmación antes de cada commit. No apareció **ninguno**, en los dos caminos:

| Comando | Shell | Machea `ask` | Prompt |
|---|---|---|---|
| `git commit -F <archivo>` | Bash | `Bash(git commit *)` | no |
| `git commit --allow-empty -m …` | PowerShell | `PowerShell(git commit *)` | no |

El commit de prueba de PowerShell se deshizo con `git reset --hard`; no quedó en la
historia.

**Esto no es una config mal puesta de este lado: la doc oficial dice que no debería pasar.**
Consultada el 14/8/2026, con Claude Code **2.1.232** corriendo. Las cuatro citas, textuales:

| Dónde | Qué dice |
|---|---|
| `permission-modes` → *Auto mode* | *"Explicit ask rules still force a prompt."* |
| `permission-modes` → *Available modes* | *"These controls apply in every mode, including `bypassPermissions`: deny rules and explicit ask rules"* |
| `permissions` → *Manage permissions* | *"a matching ask rule prompts even when a more specific allow rule also matches the same call"* |
| `permissions` → *Sandboxing* | *"Content-scoped ask rules like `Bash(git push *)` still force a prompt"* |

La última cierra el caso: nuestras cuatro reglas son exactamente esa forma —`ask`
content-scoped sobre `git commit` y `git push`—, y la doc las nombra como las que siguen
prompteando incluso donde un `ask` de tool entero no lo haría.

Con eso quedaban descartadas las tres explicaciones que había del lado del proyecto: que un
cambio de permisos no tome efecto en caliente (las reglas estaban commiteadas antes de que
arrancara la sesión), que el `allow` de `settings.local.json` las tape (tercera cita), y el
modo de permisos (primera y segunda). La conclusión que se sacó fue **un gap entre lo
documentado y lo observado**, y sobre esa conclusión se escribió el hook.

### Esa conclusión estaba mal, y se cayó al verificarla

**Más tarde el mismo 14/8/2026, en una sesión recién abierta, las reglas `ask` dispararon.**
Se repitió el test de a un paso por vez, con Joaco mirando la pantalla en el momento exacto
y confirmando cada prompt con captura:

| # | Comando | Shell | Prompt | Qué citó el cuadro |
|---|---|---|---|---|
| 1 | `git commit --allow-empty -m "test: bash"` | Bash | **sí** | `Ask rule Bash(git commit *) overrides auto mode for this command.` |
| 2 | `git commit --allow-empty -m "test: powershell"` | PowerShell | **sí** | `Ask rule PowerShell(git commit *) overrides auto mode for this command.` |
| 3 | `git -c user.name=X commit --allow-empty -m "test: solo hook"` | Bash | **sí** | `Hook PreToolUse:Bash requires confirmation for this command`, con el mensaje literal de `commit-confirmacion.sh` |

Los tres commits de prueba se deshicieron con `git reset --hard 6cf1adb`; no quedaron en la
historia.

→ **No hay gap del producto.** La doc decía la verdad: las reglas `ask` content-scoped
fuerzan el prompt en modo auto, y lo hicieron. La entrada de arriba —y `a3e9871`, que la
commiteó— diagnosticaron mal un síntoma real.

→ **Lo que el hook aporta no es lo que decía su comentario.** En los tests 1 y 2 matchearon
la regla **y** el hook a la vez, y el prompt salió por la regla: la doc de `permissions` dice
*"a matching ask rule still prompts even when the hook returned `allow` or `ask`"*, así que
esos dos tests no probaban nada sobre el hook. El test 3 es el que lo aísla. La regla `ask`
es `Bash(git commit *)`, **prefijo literal**, y un `-c` antes del subcomando no lo matchea;
el regex del hook (`commit-confirmacion.sh:33`) sí, porque está escrito para tolerar tokens
intermedios. Ahí salió el prompt del hook, solo.

**O sea: el hook no es la mitigación de un gap del producto — es la cobertura de las
variantes que el prefijo literal de la regla `ask` no matchea.** `git -c … commit` es la que
está probada; cualquier otra forma con flags entre `git` y el subcomando cae en el mismo
hueco. Las dos capas se complementan y ninguna sobra: la regla cubre la forma canónica, el
hook cubre el resto.

### La correlación con la duración de la sesión, que queda anotada sin explicación

Las dos veces que la regla `ask` falló fue **esta mañana, en una sesión larga**. Las dos
veces que funcionó fue **más tarde, en una sesión recién abierta con `/clear`**. Es la
segunda vez que se repite el patrón.

**Es una correlación, no una causa probada.** No se corrió ningún experimento que aísle la
duración de la sesión como variable sola, y no se sabe qué otra cosa cambia entre una sesión
larga y una nueva. Queda escrito porque si el síntoma vuelve, esta es la primera hipótesis a
testear, y porque explicaría por qué la medición de la mañana era real y la conclusión que
se sacó de ella no.

**`exit 2` quedó descartado, y la razón importa.** Corta la llamada **antes** de que se
evalúen las reglas de permiso —*"A hook that exits with code 2 stops the tool call before
permission rules are evaluated"*—, que suena a la propiedad ideal, pero le devuelve el
mensaje **al modelo**: Joaco no ve ningún prompt. Eso es una pared, no una confirmación, y
dejaría el commit imposible en vez de pedido. El guardarraíl que hace falta acá no es
"nunca", es "no sin que lo pidan".

Es además lo que ya dicen `plan.md` §5 (*"si escribís 'siempre que X, hacé Y' en
`CLAUDE.md`, probablemente debería ser un hook"*) y las dos fuentes de
`critica-metodologia.md` §0: *"Put guardrails in hooks"* y *"cuando algo absolutamente no
debe pasar, una instrucción es la herramienta equivocada"*. Lo que hay que traerse de
`0c5f9bf` es **verificarlo en una sesión distinta de la que lo escriba**, que es el paso que
ese commit se salteó.

---

## Riesgos identificados

**Claude Code es más débil justo en 3D y en proyectos que dependen de assets.** Rinde bien
en sistemas, lógica y datos; se traba en game feel, balance y todo lo que requiera *ver* el
juego corriendo. Mitigación: MCP server para darle ojos, tests headless, y jugar el juego
nosotros cada milestone.

**El fallo característico documentado: "los tests pasan pero el juego es injugable."**
Los tests miden corrección, no diversión. Ninguna tarea se da por terminada porque los
tests estén verdes.

**El riesgo mayor para nosotros: descargar todo el trabajo cognitivo en la IA.** Hay casos
documentados de gente que abandonó su proyecto porque perdió el contacto con su propio
código y no lo podía arreglar. Estamos aprendiendo gamedev, así que:

→ **Regla permanente: leer el diff antes de commitear. Si un archivo resulta opaco, pedir
que lo expliquen antes de aceptarlo.**

**El multiplayer duplica el costo de cada feature.** Cada sistema tiene que contestar
"quién es dueño de este estado y cómo se replica". Es un impuesto sobre todo el proyecto,
no un feature que se agrega.

---

## Pendiente

- [ ] Tutorial oficial 3D de Godot, los dos por separado
- [ ] **Huecos de diseño abiertos.** Ninguno bloquea v0.1 ni v0.2:
      1. Si el inventario de v0.3 usa `expressobits/inventory-system` o se escribe. Se
         responde **en v0.3**, verificando si el addon replica en red solo o si hay que
         serializar a `PackedByteArray` igual
      2. **Vendas:** curar entra en **v0.4** (decidido el 6/8/2026, ver `docs/plan.md`),
         y con eso el límite de revivires. Sigue abierto si además la vida se regenera sola
      3. **Palanca:** no hay puertas ni contenedores trabados en el plan, así que no hay
         mecánica que la use
      4. **Qué entra al save**, tres cosas sin decidir (items tirados en el piso,
         inventario y stats de los jugadores, zombies). Se deciden **antes** de escribir
         el save de v0.5, no después: cada una impone requisitos aguas arriba. Lista en
         `docs/netcode.md` → "Qué entra al save"
- [ ] Definir quién tiene el plan Pro de Claude
- [x] **Asimetría de git entre shells — cerrada el 15/8/2026.** `PowerShell(git *)`
      salió del allow y la reemplazan `PowerShell(git add *)` y `PowerShell(git checkout *)`,
      las mismas dos entradas que ya tenía Bash. **El problema no era "amplio contra
      granular", que suena a prolijidad:** era que la blanket rule aprobaba sin prompt
      cualquier subcomando de git —`reset --hard`, `rebase`, `clean -fd`, `branch -D`—,
      mientras que por Bash esos mismos caían fuera de las tres entradas y preguntaban. El
      mismo comando destructivo tenía dos comportamientos según el shell que lo escribiera.
      `commit` y `push` ya estaban igualados en los dos shells por los cuatro `ask` de
      `.claude/settings.json`, así que nunca fueron el hueco. Encima de todo esto sigue
      estando lo que el harness fuerza a `ask` por su cuenta, que es otra capa y no se midió
      acá. **Las cuatro entradas viven en `.claude/settings.json`, que viaja con el repo:**
      salieron de `settings.local.json`, que está en `.gitignore` (línea 28) y por eso dejaba
      el criterio en una máquina sola. Ahora es el mismo en las dos y en la de Mathi cuando
      exista, sin repetir nada a mano. Viene de `docs/reestructuracion/permisos-curados.md`,
      absorbido en `docs/estado.md` y borrado el 14/8/2026; el original se recupera con
      `git log --diff-filter=D -- docs/reestructuracion/permisos-curados.md`
- [x] **Sumar un hook `PreToolUse` al guardarraíl del commit — escrito y verificado el
      14/8/2026, `.claude/hooks/commit-confirmacion.sh`. Cerrado.** Se verificó en una
      sesión distinta de la que lo escribió, que es el paso que `0c5f9bf` se salteó, y de a
      un paso por vez, con Joaco mirando la pantalla en el momento de cada llamada. Machea
      `git commit` y `git push` sobre `Bash` y `PowerShell`, y **devuelve
      `permissionDecision: "ask"` con código de salida 0**, no un código de salida
      bloqueante: pide confirmación, no bloquea. **No reemplaza a las cuatro reglas `ask` de
      `.claude/settings.json`: las complementa.** Las reglas sí disparan —el diagnóstico de
      "gap del producto" era falso, ver Problemas—, pero su patrón es un prefijo literal
      (`Bash(git commit *)`) que no matchea un `git -c … commit`. El hook sí. Evidencia en
      el transcript de la sesión, `toolu_01VkJpnp64acamGGnBNuuAeF` (regla, Bash),
      `toolu_016r9a6Pb9y3zRcjSsLWHBTU` (regla, PowerShell) y
      `toolu_01BwGw4h5hCjGWfYPa7BHpzp` (hook solo, Bash)
- [x] **Regla de preaprobación de tools de MCP — escrita el 15/8/2026 en
      `.claude/rules/herramientas.md`. Cerrada.** Antes de sumar una tool de MCP al
      allowlist, chequear si mezcla lectura y escritura sobre un archivo versionado crítico;
      si mezcla, excluirla o aceptar el riesgo por escrito. Viene de
      `docs/reestructuracion/permisos-curados.md`, absorbido en `docs/estado.md` y
      borrado el 14/8/2026; el original se recupera con
      `git log --diff-filter=D -- docs/reestructuracion/permisos-curados.md`
- [x] **Instalar gdUnit4 — hecho el 6/8/2026, v6.2.0**, bajando el `.zip` del tag de GitHub
      porque el AssetLib sigue fallando (ver "Problemas"). Falta un solo paso manual:
      **prenderlo en Project → Plugins desde el editor.** El runner de línea de comandos no
      lo necesita —ya corre—, pero el inspector de tests adentro del editor sí
- [ ] Bajar los packs de assets y decidir la familia visual. **Se puede hacer en paralelo
      desde v0.3**, en los ratos sin código: no bloquea hasta v0.6, pero llegar a v0.6 con
      la familia ya elegida convierte esa pasada de arte en aplicar decisiones, no tomarlas
- [ ] Dibujar el mapa en papel
- [ ] **Playtest de quince minutos sin código a la vista, por cada milestone.** Jugarlo,
      no revisarlo. Es la versión barata del "testigo independiente": el sesgo de
      autoevaluación no se corrige leyendo el propio diff.
      **v0.2: hecho el 6/8/2026, sin bugs nuevos.** Sigue abierto porque es por milestone:
      v0.3 tiene el suyo
- [ ] **Al tercer mes, revisar si la velocidad de avance cayó.** Está medido que con IA la
      velocidad sube fuerte el mes 1, la mitad el mes 2 y vuelve a cero el mes 3, mientras
      la complejidad queda +41% permanente (`docs/investigacion-claude-code.md`). Si lo
      sentimos, no es impresión: es el patrón. La contramedida es refactorizar a propósito,
      no acelerar

---

## Registro

**[12/8/2026]** — **La suite entera corrió también en la laptop, y ese dato no estaba en
este repo.** Las 6 suites y los 49 casos de gdUnit4 pasaron de punta a punta en las dos
máquinas, no solo en la PC. **Lo reportó Joaco en el chat de criterio, así que no hay
artefacto del repo que lo respalde:** hasta hoy figuraba solo en el catálogo
(`proyectos/surgamezombie/README.md` → "Cómo se verificó", que lo marca con su propio ⚠️ "no
sale del repo"). Acá adentro aparecía únicamente citado de paso en
`docs/reestructuracion/mapa-metodologia.md` §8.4, que es documento de trabajo y se borra
cuando la reestructuración cierre.

Mirado en frío, el historial **parece decir lo contrario**, y por eso conviene dejarlo
escrito: `a3a1dc5` —el commit que instaló gdUnit4— lleva `Not-tested: solo se corrió en
Windows`. No contradice nada; es del 6/8, cuando la suite eran los 2 casos del smoke test, y
las dos máquinas son Windows igual. El hueco real es otro: los tres trailers `Tested:` que
dicen "6 suites / 49 casos, código 0" **no dicen en qué máquina corrió**.

**Directiva, que es lo único que evita repetirlo: cuando una corrida valga en las dos
máquinas, que el trailer `Tested:` lo diga.** Un dato que solo vive en un chat se pierde al
cerrarlo, y el catálogo termina siendo el único lugar donde quedó, que es al revés de como
debería ser. **Y no es un playtest:** mide corrección, no cómo se juega. El playtest de
quince minutos de v0.3 sigue pendiente.

**[entre el 7 y el 10/8/2026]** — **La mentira 3 de F4 se jugó con dos instancias y el host
la rechazó.** Un cliente le mandó `apply_stack_added` al `InventorySync` de otro jugador por
el path directo y las 99 palancas no aparecieron del otro lado, así que la autoridad de ese
nodo quedó en el host: es exactamente lo que ese control existía para probar. **Fue un
playtest manual, no un test automatizado** —no hay nada en `tests/` que lo cubra, porque
hace falta un segundo peer de verdad—, y **no quedó anotada la fecha exacta ni hay commit
asociado**, de ahí el rango. Cierra esa parte del `Not-tested:` de `2d417f5` y nada más: el
snapshot al conectarse, el stream de deltas y el descarte por desincronización de `50d33d0`
siguen sin cruzar el cable, igual que las mentiras 1 y 2 de F4. Tampoco es el playtest de
quince minutos de v0.3, que sigue pendiente.

**[6/8/2026]** — **Se jugó el playtest de v0.2 y v0.2 quedó cerrada.** Quince minutos, los
dos, sin código a la vista, como manda la regla operativa 5 de
`docs/investigacion-claude-code.md`. **Salió bien: ningún bug nuevo.** Es la primera vez que
un milestone de este proyecto cumple su criterio de terminado real — v0.1 y v0.2 venían
declaradas "escritas y sin jugar" desde que se escribieron, y esa deuda queda saldada.

Lo único que se notó fue una ausencia, no una falla: **F3 no pausaba a los zombies.**
Buscado en el historial, F3 **nunca existió en el repo** — no hay commit que lo agregue ni
que lo saque, el `[input]` de `project.godot` tuvo siempre las mismas nueve acciones, y no
hay ni un `get_tree().paused` en `scripts/`. Lo que se recordaba era casi seguro la pausa
general: la del debugger de Godot, o la que el MCP usa al inspeccionar el árbol. Las dos
frenan todo, zombies incluidos, y desde el lado del que juega se ven igual que un atajo.
**Ahora sí existe como atajo real:** `debug_pause_zombies` en F3, que congela **solo** a los
zombies —apagando su `_physics_process`, no el árbol entero— y solo hace algo en el host,
que es donde vive la IA. Es andamio de debug: se borra junto con el overlay cuando entre el
HUD.

**[6/8/2026]** — **Tres decisiones que ya estaban tomadas y no estaban escritas.** Salen de
la retrospectiva §3.6, que las encontró como huecos sin anotar justo antes del playtest de
v0.2.

**El daño de mordida es provisorio y NO entra a `docs/design.md`.** Diez de daño contra 100
de vida con 1.5 s de cooldown son diez mordidas, ~13.5 s de contacto continuo para tirar a
alguien: eso es cuánto perdona el enemigo, que es balance central, y salió de que 10 es un
número redondo. Queda marcado en el `@export` de `zombie.gd`, pegado al número, y no en el
doc de diseño **a propósito**: ningún número de gameplay entra a `design.md` en el mismo
commit que lo implementa, porque ahí adentro se lee igual que los que decidieron ellos
(retrospectiva §1.E1). Entra el día que se juegue y salga del playtest.

**La curación entra en v0.4, y eso significa que en v0.3 nadie muere de verdad todavía.**
El límite de revivires depende de que exista curación —la regla es "cae, lo levantan, y
vuelve a caer **sin haberse curado en el medio** dentro de los 10 minutos: la segunda caída
mata directo"—, y la curación se puso en v0.4 para reusar el sistema de usar un item que
restaura una stat que ese milestone construye igual para hambre y sed, en vez de escribirlo
dos veces. **El costo está aceptado a propósito, no es un descuido:** durante todo v0.3 un
dúo se sigue reanimando indefinidamente y la muerte real no llega nunca, así que el
milestone del inventario se juega sabiendo que nadie muere. `docs/design.md` prometía el
item médico para v0.3 y quedó corregido.

**[5/8/2026]** — **Paso 6 de v0.2: caído, revivir y respawn.** Con esto v0.2 queda escrita
entera y solo falta el playtest de dos instancias. Entró en cuatro commits, uno por pedazo,
y cada uno se verificó con un smoke test headless descartable antes de pasar al siguiente.

**El zombie pasó de 2.5 a 3.7 m/s**, del playtest de la sesión anterior: a 2.5 se sentía
inofensivo. **4.0 es techo duro** —la velocidad de caminata del jugador— porque todo el
diseño del enemigo se apoya en que uno solo no alcanza a alguien que se mueve. El porqué
completo está en `docs/design.md` → "Velocidad del zombie: 3.7 m/s".

**El hallazgo que más va a servir después: `@rpc("authority")` significa "solo la autoridad
de ESTE nodo", no "solo el host".** Verificado en la doc de 4.7 vía Context7
(`MultiplayerApi.RPCMode`). El respawn necesita que el host mueva el cuerpo de un cliente, y
la primera idea —declarar la RPC en `player.gd` con `"authority"`— hace exactamente lo
contrario de lo que parece: la autoridad de ese nodo es el **cliente dueño**, así que el
host habría quedado afuera y la RPC no se podría llamar nunca.

La solución dejó **un tercer patrón de red** en `docs/netcode.md`, que hasta ahora tenía dos:
la RPC vive en `world.gd` —cuya autoridad no se reasigna nunca— y llama a un método normal
del jugador local. El host **no escribe** la posición de un cuerpo ajeno: se la ordena al
dueño, que se mueve a sí mismo y replica hacia afuera como siempre. Si el host la escribiera
directo, el `MultiplayerSynchronizer` del dueño se la pisaría en el tick siguiente.

**El NavMesh horneado queda 0.3 m por encima del piso** (vértices en `y = 0.3`, cara de
arriba del `Floor` en `y = 0.0`). Dos consecuencias que no se veían razonándolo:

- El chequeo de `MAX_RESPAWN_SNAP` que este proyecto tenía escrito **no habría funcionado**:
  comparaba distancia en 3D, que con ese offset nunca baja de 0.3 m ni parado en medio del
  patio, así que el respaldo habría disparado siempre. Ahora se mide **solo en horizontal**.
- Del lado bueno, el offset garantiza que el punto snapeado cae **por encima** de la
  superficie caminable y nunca adentro: no hay forma de respawnear enterrado. Medido: se
  aparece en `y = 0.300` y un segundo después el cuerpo está en `y = 0.0001` apoyado.

**Revivir terminó siendo dos RPCs, no uno.** `docs/netcode.md` suponía un `request_revive`
de un disparo, pero se decidió que sea **mantener** la tecla, y mantener es un estado que
dura. Como mandar estado por RPC cada frame está prohibido, se mandan los dos **bordes**
—empecé, solté— y el host lleva el progreso, que baja replicado en el nodo de stats **del
caído**: por eso el caído ve que lo están levantando.

**Todas las condiciones de revivir viven en una sola función del host, `_can_revive()`.** Es
a propósito y mirando a v0.4: cuando revivir requiera una venda, se agrega una condición ahí
adentro y no se toca una línea del cliente, porque el cliente no conoce ninguna regla — solo
pide. El host revalida entero cada frame, y eso cubre alejarse, que al que levanta lo tiren y
que se desconecte a mitad de camino sin escribir un caso especial para cada uno.

**Ni el timer del caído ni los revivires en curso se guardan en un diccionario de
`world.gd`.** El countdown vive adentro del nodo de stats de cada jugador y los revivires se
recorren iterando los hijos vivos de `Players`. Los dos por la misma razón: al desconectarse
un peer su jugador se libera, y un diccionario quedaría apuntando a un nodo que ya no
existe. Probado: caer, desconectarse antes de que venza el timer, y confirmar que el host no
imprime la muerte ni tira `previously freed instance`.

**Detalle de GDScript que costó dos corridas:** los lambdas **capturan las locales por
valor**. Escribirle a una variable local desde adentro de un `func()` no sale del lambda —
hay que usar una variable del script. Pasó en un test, no en código del juego, pero es el
tipo de cosa que se ve como "el valor no se actualiza" y no como lo que es.

**Lo que salió del playtest de dos instancias**, que era lo único que los smoke tests no
podían cubrir:

- **El progreso de revivir se ve bien en la pantalla del caído.** Confirmado, la
  replicación del `revive_progress` anda.
- **`REVIVE_DURATION` pasa de 3 a 10 segundos.** Tres se sentían demasiado cortos: no
  llegaban a poner en riesgo al que levanta, que es el punto entero de que sea mantener la
  tecla. A 10 s, contra un zombie a 3.7 m/s, alcanza para que uno que estaba a 37 m llegue.
- **El zombie se trababa contra el cuerpo del caído.** Se resolvió con avoidance, no
  ignorándolo — ver la entrada de abajo.
- **El timer de 60 s seguía bajando durante el revivir, y estaba mal.** Ahora se congela
  mientras alguien mantiene la tecla y vuelve a correr si suelta. Es lo que hace que
  quedarte con un segundo todavía tenga salida, en vez de castigar al que salva por haber
  tardado en llegar. Detalle en `docs/netcode.md` → "Paso 6".

**El cuerpo del caído estorba, pero no traba.** La primera versión hacía que el zombie
ignorara al caído como objetivo, y eso alcanzaba para que cambiara de presa pero no para que
pudiera pasar: seguía empujando contra la cápsula. La decisión fue que **lo rodee**, porque
un cuerpo tirado que se atraviesa como un fantasma se ve peor que uno que estorba.

Se hizo **sin tocar capas de colisión**: un `NavigationObstacle3D` en la escena del jugador
—radio 0.8, apagado— que se prende solo mientras está caído, y `avoidance_enabled` en el
`NavigationAgent3D` del zombie. **El NavMesh rodea lo que estaba horneado; el avoidance
rodea lo que apareció después.** El obstáculo se prende y se apaga desde `_process()` **sin
gate de autoridad**, y eso no es un descuido: el que necesita el obstáculo prendido es el
host, y en la máquina del host el cuerpo de un cliente caído es una instancia que no es
autoridad suya. Como `is_downed` baja replicado, las tres máquinas llegan a lo mismo.

**Lo que cambia en el código al prender avoidance, y no es opcional:** el agente deja de
devolver la velocidad en el acto. Se le pasa la que uno **quiere** con `set_velocity()` y él
contesta la esquivada por la señal `velocity_computed`, más tarde en el mismo frame — o sea
que `move_and_slide()` pasa a llamarse desde el handler, no desde `_physics_process()`.

**Y la trampa que trae: `velocity_computed` se emite TODOS los frames** mientras avoidance
esté prendido, hayas pedido algo o no. Sin una bandera que diga "este frame pedí moverme",
el handler llamaría `move_and_slide()` también en el cliente —donde el `_physics_process`
está apagado a propósito— y en los frames en que el zombie decidió quedarse quieto.

**Lo que queda sin verificar:** que el zombie efectivamente rodee, que es lo que se prueba a
continuación. Los otros números de revivir —2 m de rango, 30 de vida— siguen siendo valores
de arranque.

**[2/8/2026]** — **Primer código del proyecto.** Entraron el esqueleto de red
(`network_manager.gd` como autoload + `lobby.tscn`), el input map, el character controller
en primera persona y `world.tscn`, y después se conectaron entre sí. **v0.1 queda cerrada a
falta del playtest de dos instancias.**

Lo que hay que recordar de acá:

**v0.1 sí tiene un RPC, y `docs/netcode.md` decía que no.** Ya está corregido allá con el
porqué completo. En resumen: el host spawnearía al cliente al recibir `peer_connected`,
pero del lado del cliente `change_scene_to_file()` se difiere al final del frame, y **en LAN
el RTT es menor a 1 ms contra un frame de 16 ms**. El paquete de spawn llegaba antes de que
existiera el `MultiplayerSpawner` del otro lado. Se resolvió con un handshake: el cliente
manda `notify_world_ready.rpc_id(1)` y el host spawnea al recibirlo.

**Es el primer caso del patrón general:** cargar una escena no es instantáneo, así que nada
que dependa de que el otro lado tenga un nodo se puede mandar junto con la conexión.

**La autoridad de red no se replica: se deduce del nombre del nodo.** El host nombra a cada
jugador con el ID de su peer, el nombre viaja con el spawn y cada máquina hace
`set_multiplayer_authority(name.to_int())` en su `_enter_tree()`. Va en `_enter_tree()` y no
en `_ready()` porque el `MultiplayerSynchronizer` ya necesita saber quién manda al entrar al
árbol.

**Sobre el `recursive = true` que veníamos marcando como trampa:** en v0.1 es lo correcto,
porque el Synchronizer necesita la misma autoridad que la raíz. Muerde en v0.2, cuando entre
el nodo de stats. Queda comentado en `player.gd`, en la línea donde va a doler.

**El manejo de `server_disconnected` vive en el autoload, no en el lobby.** Cuando el host
se cae, el cliente está en el mundo y `lobby.gd` no está en el árbol. El autoload sobrevive
a los cambios de escena, y esa es la razón de que sea autoload.

**Un efecto útil de `multiplayer.is_server()`:** sin ningún `MultiplayerPeer` asignado
devuelve `true` y `get_unique_id()` devuelve 1. O sea que `world.tscn` corrida sola con F6
spawnea un jugador y se puede probar en single player sin tocar nada.

**Decisiones de game feel que salieron de jugarlo, no de razonarlo:** movimiento
instantáneo sin inercia, gravedad realista de 9.8, y **control en el aire de 0.25** —el
primer playtest mostró que con control total el salto se sentía a volar. Los tres números
están en `docs/design.md`.

**[1/8/2026]** — Setup completo. Organización, repo, estructura de carpetas, `CLAUDE.md`,
rules y docs iniciales. Verificado el ida y vuelta de commits entre las dos máquinas.

**[1/8/2026]** — Auditoría de los docs y corrección de inconsistencias. Lo importante:
la regla de autoridad de red pasó a **autoridad dividida** (ver "Decisiones tomadas"),
se fijó **primera persona**, y se definió el **idioma del código** (inglés para
identificadores, español para comentarios y docs). Además: se resolvió un conflicto de
merge que había quedado commiteado en `docs/design.md`, se crearon `scripts/player/`,
`scripts/enemies/` y `scripts/ui/`, se amplió el scope de `.claude/rules/netcode.md` a
`scenes/**` y a esas carpetas, se agregaron `export_presets.cfg` y `*.tmp` al `.gitignore`,
y se arreglaron los comandos de `CLAUDE.md` (Godot no está en el PATH: el ejecutable está
en `C:\Godot\Godot_v4.7.1-stable_win64.exe`).

**[1/8/2026]** — Tres decisiones más, todas para desbloquear v0.1: **character controller
propio** (ver arriba), **escala y números base** del jugador y el mundo (en
`docs/design.md`), y **`project.godot` pasa a tener un solo dueño, Mathi** (en el reparto
de trabajo de `docs/design.md`). Con esto v0.1 no tiene ninguna decisión pendiente.

**[2/8/2026]** — Sesión de proceso, sin código. Entraron `docs/proceso.md` (commits,
documentación, diagnóstico de errores) y `docs/investigacion-claude-code.md` (modos de
falla medidos de la IA en gamedev), y el resto de los docs se alineó con ellos.

**El reparto de trabajo por carpetas queda sin efecto** y revierte lo decidido el
1/8/2026: los dos trabajamos en todo, **`project.godot` incluido**, y ya no tiene dueño.
Lo reemplaza avisarse antes de arrancar diciendo sobre qué archivos, nunca dos personas
sobre el mismo archivo a la vez, y `git pull` siempre antes de empezar. `plan.md` §5 quedó
con la nota de revisión encima del párrafo viejo, igual que §2 con la regla de autoridad.

Se escribieron las **seis primeras ADRs** en `docs/decisions/`, reconstruidas desde esta
bitácora y desde `plan.md`: engine, lenguaje, autoridad de red, plan de transporte,
character controller y MCP. Donde el porqué no estaba registrado, quedó escrito que no lo
está, en vez de inventarlo.

En `CLAUDE.md`: el formato de las respuestas pasó a ser explícito (qué cambié / probá vos
/ decidí vos, y qué no escribir nunca), y la versión de Godot quedó fijada arriba de todo.
Para no pasar las 200 líneas se movieron tres secciones a `.claude/rules/limites.md`.
Rules nuevas: `commits.md` y `limites.md`, las dos con scope a todo el repo.
`.claude/rules/gdscript.md` sumó el checklist de los 10 pitfalls, y `docs/netcode.md` la
advertencia de que el `MultiplayerSynchronizer` **no** sincroniza el inventario solo
(v0.3: hay que serializar a `PackedByteArray` a mano).

**Un dato que se verificó corriendo Godot 4.7.1**, porque circula mal en todos lados: la
firma vieja `connect("pressed", self, "_on_x")` no "compila y no hace nada". Con tipado
estático es error de parseo y el script no carga; solo sobre un `Variant` llega a runtime
y deja la señal muerta en silencio. El static typing obligatorio previene el caso malo.

**[2/8/2026]** — Auditoría del plan y decisiones de scope del mapa. Sin código.

**v0.1 es una caja con piso y paredes**, no "una manzana": `plan.md` §3 decía una cosa y
`design.md`, `netcode.md` y el propio `plan.md` §6 decían otra. Gana la caja porque v0.1 es
el filtro y un filtro tiene que costar horas — un mapa hecho a mano arrastra ambientación,
packs y familia visual, y entonces deja de medir el esqueleto de red.

**El mapa pasa a tener progresión propia** (`plan.md` §3 → "Progresión del mapa"): greybox
primero, arte al final. Caja en v0.1, greybox mínimo en v0.2 para que el NavMesh tenga qué
navegar, el greybox crece en v0.3-v0.5, y la pasada de arte recién en v1.0. **Consecuencia:
la familia visual no bloquea nada hasta v1.0.** Tamaño del mapa de v1.0: **250 × 250 m**,
valor de arranque a tunear, en `design.md`.

**"Qué pasa al morir" se partió en dos decisiones:** respawn y revivir bloquean v0.2; qué
pasa con el inventario al morir bloquea v0.3, porque hasta v0.3 no hay inventario que
perder. Antes era un solo `[DECIDIR]` atado a v0.2 y no se podía cerrar.

**El addon de inventario de expressobits queda registrado como pregunta abierta**, no como
decisión tomada: `plan.md` afirmaba que es multiplayer-friendly y `netcode.md` advierte que
el `MultiplayerSynchronizer` no replica estructuras anidadas. Se decide en v0.3 verificando
si el addon replica solo o si hay que serializar a `PackedByteArray` igual.

Además se arreglaron cuatro desalineaciones entre docs: el encabezado de `plan.md` §2 y el
ejemplo de rule de §5 seguían diciendo "autoridad total del host"; la estructura de carpetas
estaba escrita tres veces y ninguna coincidía —ahora la única versión está en `CLAUDE.md` y
`plan.md` apunta ahí—; `plan.md` §5 describía el loop de verificación como cerrado cuando
gdUnit4 no está instalado; y las referencias de tono de `plan.md` no incluían DayZ ni Road
to Vostok.

**[2/8/2026]** — **Se cerraron todos los huecos de diseño menos uno.** Está todo en
`docs/design.md`; acá va solo lo que tiene consecuencia sobre el plan.

**Nombre: SurGameZombie**, provisorio. **Ambientación: un complejo industrial** —fábrica,
depósitos, oficinas, playa de camiones—, elegida contra el tamaño del mapa: 250 × 250 m
son unas 2 × 2 manzanas y un pueblo no entra. **No hay condición de victoria:**
supervivencia infinita.

**Muerte, en dos etapas.** En v0.2 quedás **caído**, no muerto: un compañero puede
levantarte y si nadie llega en 60 segundos morís de verdad y respawneás cerca. En v0.3 la
muerte real deja el inventario en una **bolsa** que solo saquean jugadores, que no
despawnea por tiempo y desaparece al quedar vacía.

**El mundo persiste** —los contenedores vaciados siguen vacíos, el mapa no se resetea—, y
eso **convierte el guardado de v0.5 en obligatorio**: sin guardado, la persistencia dura
lo que dura la sesión del host.

**Inventario limitado por peso**, no por slots ni por grid. Se descartó el grid tipo
Tarkov: duplica el trabajo de UI y empeora la serialización de red, porque cada item pasa
a guardar posición y rotación además de cantidad. Migrar después es reescribir la UI de
inventario entera.

**Los primeros 10 items:** bate, pistola 9mm, munición 9mm, botella de agua, lata de
comida, barra de cereal, vendas, linterna, mochila, palanca. Un solo melee y una sola arma
de fuego, consistente con v0.5. **Escopeta y fusil quedan para v0.6 en adelante**, porque
con tres armas de fuego en diez items el combate deja de ser escaso.

**Queda un solo hueco:** si el inventario de v0.3 usa el addon de expressobits o se
escribe. **v0.2 no tiene ninguna decisión de diseño pendiente.**

**[2/8/2026]** — Consecuencias de las decisiones de diseño de arriba, resueltas una por
una. Sin código. Lo que tiene efecto de acá en adelante:

**El estado caído no reasigna autoridad de red.** El cuerpo del jugador sigue siendo del
peer dueño incluso caído: el host decide que caíste, el cliente lee el flag y deja de leer
input. Le confiamos al cliente que respete su propio flag. *Rejected: pasarle la autoridad
del cuerpo al host mientras dura el caído | toca el `MultiplayerSynchronizer` en caliente,
que da bugs difíciles, y del otro lado no hay PvP que defender.* En `docs/netcode.md` y en
`.claude/rules/netcode.md`. **Regla general que sale de acá: la autoridad no se reasigna en
runtime, nunca.**

**El patrón del modificador, con nombre porque se va a repetir:** el host calcula el
modificador de velocidad y lo replica, el cliente lo multiplica al moverse, el cliente
nunca lo calcula. Ya aplica a la stamina (v0.4); el sobrepeso (v0.3) es el segundo caso y
heridas y temperatura entrarían igual.

**El save vive en la máquina de quien hostea: si hostea el otro, es otro mundo.** Aceptado
por simple. Si molesta, la solución es que hostee siempre el mismo, no sincronizar saves.
Consecuencia que hay que aplicar dos milestones antes de que se note: **los contenedores
llevan un ID persistente propio (`@export var container_id: String`), no `NodePath`**,
porque el save de v0.5 los busca por ese ID y mover o renombrar un nodo cambia su ruta.
Anotado en v0.3 y en v0.5.

**Slots de equipo: mochila y arma en mano, solo esos dos.** No contradice el inventario
por peso: el peso limita qué cargás, los slots definen qué tenés puesto. **Capacidad: 25 kg
sin mochila, 40 con.** Al pasarte caminás más lento y no podés correr — sin bloqueo duro.
Valores de arranque.

**Tabla item → mecánica → milestone** en `docs/design.md`. Lo que deja claro: **en v0.3 los
diez items entran, pero solo la mochila hace algo.** Vendas, linterna y palanca son items
inertes ahí y es a propósito — v0.3 prueba el inventario, no las mecánicas. Aparecieron dos
huecos de diseño nuevos, los dos sin bloquear nada: cuándo curan las vendas (depende de si
la vida se regenera sola, que no está decidido) y qué abre la palanca (no hay mecánica de
acceso trabado en el plan).

**v1.0 se partió en dos.** Tenía arte, sonido, lobby, menús y mapa final juntos: más
trabajo que v0.1 a v0.5 sumadas, y un milestone que no se puede terminar no ordena nada.
Queda **v0.6 "Se ve"** (pasada de arte, familia visual, iluminación, post-processing, SFX)
y **v1.0 "Se juega con amigos"** (noray, lobby, menús, nombre definitivo, balance final).
La pasada de arte va sola porque es el único bloque que no toca sistemas: mezclada con
netcode, es lo primero que se recorta cuando aparece un bug. **La familia visual y los SFX
se pueden ir haciendo en paralelo desde v0.3**, aunque no bloqueen hasta v0.6.

Efecto colateral de partir v1.0: la entrada anterior decía "escopeta y fusil quedan para
v0.6 en adelante", escrito cuando v0.6 no era un milestone definido. Ahora v0.6 es la
pasada de arte, así que en `docs/design.md` quedó como **"fuera de la v1"**, que era la
intención. `docs/decisions/0004-plan-de-transporte.md` dice "Ahora → v0.5" por el mismo
motivo; **no se toca, las ADRs son inmutables** (`docs/proceso.md` §2). Se lee bien igual:
ENet sigue hasta que entre noray en v1.0.

**[2/8/2026]** — Cierre de la misma sesión: **v0.2 queda planificada de punta a punta** y
se escribió **ADR-0007**. Sin código.

**ADR-0007: la autoridad de red no se reasigna en runtime, nunca.** Generaliza lo del
estado caído: `set_multiplayer_authority()` se llama en un solo lugar del proyecto —el
host, al instanciar al jugador— y en ninguno más. Aplica de antemano a los estados que
todavía no existen (vehículos, que un zombie te agarre): flag en el nodo de stats del host,
replicado, y el cliente lo respeta saliendo temprano de `_physics_process`. Es un molde, no
una decisión nueva cada vez. Queda atada a ADR-0003: las dos apoyan en que no hay nada que
defender, y si algún día lo hay, se revisan juntas.

**`docs/netcode.md` → "Cómo se resuelve v0.2"**, con el mismo formato que la de v0.1 y las
dependencias marcadas. Lo que sale de ahí y no era evidente:

- **v0.2 tiene dos RPCs del patrón 2, no uno.** El daño y `request_revive`. La validación
  de distancia para levantar a alguien la hace el host contra las posiciones ya replicadas,
  nunca contra una distancia que mande el cliente. El timer de 60 s también corre en el
  host: en cada cliente, dos latencias distintas llegan a cero en momentos distintos.
- **El NavMesh va antes que el zombie, no con el zombie.** Parece cosa de la IA, pero el
  respawn "cerca de donde caíste" necesita validar que el punto sea navegable, así que
  bloquea también el último paso del milestone. Dejarlo para cuando toque la IA traba el
  final de v0.2 por algo que se podía hacer primero.
- **El segundo `MultiplayerSynchronizer` es donde muerde la trampa de
  `set_multiplayer_authority(id, recursive = true)`.** En v0.1 no se nota porque no hay
  stats; en v0.2 la vida termina siendo del cliente y el host no puede aplicar daño.

**Verificado por MCP contra el editor 4.7.1-stable**, porque estaba escrito de memoria y es
justo el tipo de API que se alucina: `NavigationServer3D.map_get_closest_point(map: RID,
to_point: Vector3) -> Vector3` existe con esa firma exacta, igual que
`World3D.get_navigation_map() -> RID`, `map_get_random_point()` y `map_force_update()`.
**Lo importante es lo que la firma implica:** devuelve `Vector3`, no `bool`, así que **no
falla nunca** — siempre da el punto más cercano del NavMesh, esté a 10 cm o a 40 m.
Validar "es navegable" es comparar la distancia contra el punto pedido. Sin eso, morir
arriba de un techo te respawnea del otro lado del mapa. Eso último es inferencia de la
firma, **no verificado corriendo**: cuando se implemente, probarlo muriendo a propósito en
un lugar sin NavMesh.

**La bolsa de muerte es una entidad de red, no un item, y es la pieza más cara de v0.3.**
En el diseño ocupa dos renglones y arrastra: `MultiplayerSpawner`, un inventario entero
serializado (el mismo problema del `PackedByteArray`), RPC del patrón 2 para sacar cosas,
chequeo de vacío en el host cada vez que alguien saca algo, e ID persistente porque **entra
al save de v0.5**: una bolsa que nadie vació tiene que seguir ahí después de cerrar el
juego. Si en v0.3 se hace como algo que vive solo en memoria, v0.5 la reescribe entera.

**`docs/netcode.md` estrena "Qué entra al save"**, lista viva: contenedores, bolsas de
muerte y hora del día. Quedaron tres cosas **sin registrar** que hay que decidir antes de
escribir el save, no después: si los items tirados en el piso sobreviven al cierre, si el
inventario y las stats de cada jugador persisten entre sesiones —y qué pasa con el de
alguien que no está conectado cuando el host guarda—, y si los zombies entran o no.
