# Bitácora

Registro de qué se hizo, qué se decidió y por qué. Se actualiza cuando pasa algo que
alguien va a necesitar recordar en dos meses.

---

## Estado actual

**Setup terminado.** Los dos pueden clonar, editar, subir y bajar cambios.
**Pendiente antes de escribir código:** tutorial oficial 3D de Godot (los dos) y completar
los `[DECIDIR]` de `docs/design.md`.

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

### Red: listen server con autoridad total del host

Un jugador hostea y juega en el mismo proceso. 2-4 jugadores.

Regla que no se negocia: el host es autoridad sobre todo el estado, los clientes mandan
input. Retrofitear esto después es una reescritura, por eso va desde el commit uno.

**Plan de transporte:** ENet por IP ahora → netfox.noray para v1.0 (sin port forwarding) →
SteamMultiplayerPeer si alguna vez va a Steam. La creación del peer vive solo en
`scripts/net/network_manager.gd` para que cambiar sea un cambio de diez líneas.

### Scope de la v1

- 3 stats (vida, hambre, sed) + stamina. Temperatura, heridas y enfermedad quedan para v2.
- Un solo tipo de zombie.
- Un melee y un arma de fuego con munición escasa.
- **Mapa cerrado y denso, no mundo abierto.** Un mundo grande y vacío es más caro en red y
  menos divertido que un pueblo chico bien hecho.

### Assets: CC0 gratis, una sola familia visual

Kenney + KayKit como base, Quaternius para animaciones y personajes. La coherencia visual
importa más que la calidad individual de los modelos: mezclar packs de estilos distintos da
un asset flip.

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
- [ ] Completar los `[DECIDIR]` de `docs/design.md`: nombre, primera o tercera persona,
      ambientación, qué pasa al morir, condición de victoria, primeros 10 items
- [ ] Definir quién tiene el plan Pro de Claude
- [ ] Instalar gdUnit4 desde el AssetLib
- [ ] Instalar Claude Code y un MCP server de Godot
- [ ] Bajar los packs de assets y decidir la familia visual
- [ ] Dibujar el mapa en papel

---

## Registro

**[1/8/2026]** — Setup completo. Organización, repo, estructura de carpetas, `CLAUDE.md`,
rules y docs iniciales. Verificado el ida y vuelta de commits entre las dos máquinas.
