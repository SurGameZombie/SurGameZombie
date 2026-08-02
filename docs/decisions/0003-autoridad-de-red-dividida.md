# ADR-0003: La autoridad de red se parte en dos — movimiento del cliente, resto del host

**Fecha:** 2026-08-01
**Estado:** aceptada
**Fuente:** `docs/bitacora.md` → "Red: listen server con autoridad dividida" (revisada el
1/8/2026); `docs/plan.md` §2; `docs/netcode.md`

## Contexto

El juego es un listen server: un jugador corre el juego **y** la lógica de servidor en el
mismo proceso, y los otros 1-3 se conectan como clientes. No hay servidor dedicado.

La regla original, escrita en `docs/plan.md` §2, era absoluta:

> El host es autoridad sobre todo el estado del juego. Los clientes mandan *input*. El
> host simula y replica *estado*.

**Revisada el 1/8/2026.** Resultó demasiado absoluta. Aplicada al movimiento del propio
jugador obliga a implementar *client-side prediction* —el cliente simula, guarda cada
input y lo reaplica cuando llega la corrección del host—, porque si no, cada paso se ve
con un round-trip de retraso. Es de las cosas más difíciles del netcode y no es por donde
arranca un primer juego.

Dos restricciones más pesaban:

- **No hay PvP ni anti-cheat que defender.** Son cuatro amigos.
- **Retrofitear autoridad después es una reescritura completa**, no un refactor. Por eso
  el reparto tenía que quedar definido desde el commit uno.

## Decisión

La autoridad se parte en dos, y de qué lado cae cada cosa no se decide caso por caso:

> **El cuerpo del propio jugador es autoridad del peer dueño → `is_multiplayer_authority()`.
> Todo el resto del estado es autoridad del host → `multiplayer.is_server()`.**

El cliente mueve su propia cápsula y el `MultiplayerSynchronizer` la replica. Vida, daño,
inventario, hambre, sed, stamina, zombies, loot y mundo los resuelve el host: el cliente
pide por RPC.

La excepción tiene un límite explícito: el cliente es autoridad de *dónde está*, no de
*qué implica* estar ahí. Si el disparo impacta, si el zombie lo alcanza o si llega a
agarrar el item lo sigue decidiendo el host.

La fuente de verdad es `docs/netcode.md`. La restricción operativa vive además en
`.claude/rules/netcode.md`, path-scoped.

## Alternativas descartadas

**Autoridad total del host, incluido el movimiento** (la regla original de `plan.md` §2).
Exige client-side prediction para que el movimiento no se sienta horrible, y eso es
demasiado para un primer juego. Descartada, no borrada: el párrafo original sigue en
`plan.md` §2 con la nota de revisión, porque sigue explicando bien **por qué** hace falta
una única fuente de verdad.

**Aflojar la autoridad en algo más que el movimiento.** Descartada porque sin una única
fuente de verdad el estado diverge entre máquinas y aparecen bugs imposibles de reproducir.
Se puede aflojar en el movimiento y en ningún otro lado porque confiarle al cliente su
propia posición cuesta cero cuando no hay nada que defender.

No hay registrada ninguna otra alternativa evaluada.

## Consecuencias

- **El jugador tiene la autoridad partida adentro.** La escena del jugador no tiene un solo
  dueño: en la práctica son dos `MultiplayerSynchronizer` en la misma escena con
  autoridades distintas —uno sobre el transform (peer dueño), otro sobre las stats (host).
- **`set_multiplayer_authority()` se vuelve una trampa.** Su firma es
  `set_multiplayer_authority(id: int, recursive: bool = true)`: llamarla en la raíz del
  jugador se la aplica también al nodo de stats y lleva silenciosamente vida y hambre al
  cliente. Hay que reasignar explícitamente o pasar `recursive = false`.
- El movimiento se siente bien desde el día uno, sin escribir prediction.
- Todo el código de red del proyecto entra en uno de dos patrones (ver `docs/netcode.md`).
  Si algo no encaja en ninguno, es señal de parar y preguntar.
- **Si algún día el movimiento pasa a importar** —PvP, competitivo, gente que no
  conocemos— esta decisión se revisa.
