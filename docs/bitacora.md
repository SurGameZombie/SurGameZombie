# Bitácora

Registro de qué se hizo, qué se decidió y por qué. Se actualiza cuando pasa algo que
alguien va a necesitar recordar en dos meses.

---

## Estado actual

**Setup terminado.** Los dos pueden clonar, editar, subir y bajar cambios.

**v0.1 está desbloqueada.** Las tres decisiones que faltaban para poder escribir el primer
código —modelo de autoridad, primera o tercera persona, idioma del código— están tomadas.
Cómo se resuelve v0.1 concretamente está escrito en `docs/netcode.md`.

**Pendiente antes de escribir código:** tutorial oficial 3D de Godot, los dos.
Los `[DECIDIR]` que quedan abiertos en `docs/design.md` no bloquean v0.1.

---

## Infraestructura

| | |
|---|---|
| Organización GitHub | `SurGameZombie` |
| Repositorio | `SurGameZombie` (privado) |
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
**Sin resolver.** Consecuencia: no hay tests headless todavía, así que el comando de tests
de `CLAUDE.md` no corre.

→ Alternativa a probar: bajar el release directo de GitHub y descomprimir `addons/gdUnit4/`
a mano en el repo, salteando el AssetLib.

**Godot pisa los cambios que git hace en `project.godot`.** Si un `git pull` modifica
`project.godot` con el editor abierto, Godot detecta el cambio externo y pregunta qué
hacer. Hay que elegir **"Reload from disk"**.

Nunca **"Ignore external changes"**: eso deja al editor trabajando con la versión vieja en
memoria, y la primera vez que Godot guarde project settings reescribe el archivo con esa
versión y borra lo que bajó de git. Como `project.godot` lo tocan los dos (autoloads, input
map, capas de física), es la forma más fácil de pisarle el trabajo al otro.

→ **Regla permanente: si `project.godot` cambió por git, "Reload from disk". Lo más seguro
es cerrar el editor antes de hacer `git pull`.**

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
- [ ] Completar los `[DECIDIR]` de `docs/design.md`: nombre, ambientación, qué pasa al
      morir, condición de victoria, primeros 10 items. **"Qué pasa al morir" bloquea v0.2**,
      el resto puede esperar
- [ ] Definir quién tiene el plan Pro de Claude
- [ ] Instalar gdUnit4 — el AssetLib falla (ver "Problemas"). Probar el `.zip` de GitHub
- [ ] Bajar los packs de assets y decidir la familia visual
- [ ] Dibujar el mapa en papel

---

## Registro

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
