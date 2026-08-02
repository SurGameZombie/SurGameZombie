# ADR-0001: Usamos Godot 4.7 como engine

**Fecha:** 2026-08-01
**Estado:** aceptada
**Fuente:** `docs/bitacora.md` → "Engine: Godot 4.7, no Unreal ni Unity"; `docs/plan.md` §1

## Contexto

Dos personas que saben programar, con cero experiencia en gamedev, haciendo un hobby sin
plazo. La herramienta principal de trabajo es Claude Code. La referencia visual y tonal es
*SurrounDead*, que está hecho en Unreal Engine 5.

Tres fuerzas empujaban la decisión:

1. **Un agente solo puede leer y editar lo que esté en texto.** En un engine que guarda el
   contenido del editor en binario, todo lo que no sea código fuente es una caja negra que
   Claude Code no puede leer, ni verificar, ni diffear.
2. **El hardware.** La máquina de desarrollo tiene una RX 6500 XT de 4 GB de VRAM.
3. **El multiplayer.** Co-op de 2-4 jugadores con un listen server.

## Decisión

Usamos **Godot 4.7** (4.7.1-stable), la versión standard, no la .NET.

Razones en orden de peso, según quedó registrado:

1. **Compatibilidad con Claude Code.** Godot serializa todo en texto (`.tscn`, `.tres`,
   `.gd`): el proyecto entero es legible, editable y diffeable por un agente.
2. **Hardware.** UE5 pide 6 GB de VRAM como mínimo realista y 8 recomendado. Con 4 GB
   queda descartado por hardware, no solo por preferencia.
3. **Precedentes directos del género.** *Road to Vostok* (survival FPS realista, Early
   Access en Steam desde abril 2026) y *Nevoa* (survival horror 3D multijugador, Expresso
   Bits) están hechos en Godot.

Además: el high-level multiplayer de Godot (`MultiplayerSpawner`,
`MultiplayerSynchronizer`, `@rpc`) está diseñado exactamente para listen server con pocos
peers, así que no hace falta librería de terceros para arrancar; el editor corre en
cualquier máquina; y es MIT, gratis, sin royalties.

## Alternativas descartadas

**Unreal Engine 5.** Guarda Blueprints, materiales, niveles y UI en `.uasset` binario:
Claude Code podría escribir C++ y nada más. Todo lo hecho en el editor sería invisible
para el agente y para el diff de git. Además pide más VRAM de la que hay en la máquina de
desarrollo, y cobra 5% de royalties después del primer millón.

**Unity.** El formato es texto (YAML, `Force Text` es default desde ~2020), pero está
lleno de GUIDs y `fileID`s: frágil de editar a mano. En `docs/plan.md` figura además
"Unity tiene su historial", sin más detalle registrado.

## Consecuencias

Se vuelve fácil:

- El proyecto entero se puede generar, revisar y diffear como texto. Esto es lo que
  habilita definir los items como `.tres` (ver `CLAUDE.md` → "Datos como Resources"), que
  es el mayor multiplicador de productividad del proyecto.
- El editor arranca en segundos y no necesita GPU moderna.

Se vuelve difícil:

- **Godot 3D se ve peor out of the box.** No hay Lumen ni Nanite: iluminación,
  post-processing y foliage van a mano. El último 20% de pulido visual lo ponemos nosotros.
- **No hay terrain system oficial.** Si hace falta, es Terrain3D, un addon más que mantener.
- **El ecosistema de tutoriales de survival 3D es más chico.** Más veces va a haber que
  leer el código fuente del addon en vez de encontrar la respuesta googleando.
- **Godot 3D está menos probado en mundos grandes.** Las paredes de performance aparecen
  antes que en Unreal.
