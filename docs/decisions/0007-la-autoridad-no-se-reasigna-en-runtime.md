# ADR-0007: La autoridad de red no se reasigna en runtime, ni siquiera con el jugador caído

**Fecha:** 2026-08-02
**Estado:** aceptada
**Fuente:** decisión tomada en la sesión del 2/8/2026, al resolver las consecuencias del
estado caído. Ver `docs/bitacora.md` → Registro 2/8/2026; `docs/netcode.md` → "El estado
caído no reasigna autoridad"; `.claude/rules/netcode.md`

## Contexto

ADR-0003 partió la autoridad en dos: el cuerpo del propio jugador es del peer dueño, todo
el resto del estado es del host. Esa decisión no dice qué pasa cuando el cuerpo del jugador
**deja de ser suyo de facto**.

El estado caído de v0.2 es el primer caso. Al caer, el jugador no puede moverse: queda en
el piso hasta que un compañero lo levanta o pasan 60 segundos y muere. La pregunta que abre
es directa: durante esos 60 segundos, ¿quién manda el cuerpo?

La respuesta importa más allá del caído. Es el primer caso de una familia —caído, muerto,
subido a un vehículo, agarrado por un zombie, cualquier estado donde el jugador pierde el
control de su propio cuerpo— y contestarla caso por caso significa que cada uno se decide
distinto y que en dos años nadie sabe cuál es la regla.

## Decisión

**La autoridad de red se asigna una sola vez, cuando el host instancia al jugador, y no se
toca nunca más.** El cuerpo del jugador es autoridad del peer dueño siempre: vivo, caído o
muerto.

Durante el caído, el reparto es:

| | Quién |
|---|---|
| Decidir que quedaste caído, el timer de 60 s, la muerte real y el respawn | Host |
| Que un compañero te levante | Host, por RPC del patrón 2, validando distancia |
| Dejar de moverte mientras estás caído | El cliente, respetando su propio flag |

El flag de caído vive en el nodo de stats, así que es estado del host y baja replicado como
la vida. El cliente lo lee y sale temprano de `_physics_process`, igual que ya sale cuando
no es la autoridad del nodo.

**Le confiamos al cliente que respete su propio flag.** Un cliente que lo ignore puede
caminar estando caído, y eso es todo lo que puede hacer: el host sigue decidiendo si lo
levantan, si muere y dónde respawnea. Es la misma decisión que ya se tomó en ADR-0003 al
confiarle su propia posición, aplicada a un caso nuevo.

Como regla operativa: **`set_multiplayer_authority()` se llama en un solo lugar del
proyecto** —el host, al instanciar al jugador— y en ningún otro.

## Alternativas descartadas

**Pasarle la autoridad del cuerpo al host mientras dura el caído, y devolvérsela al
levantarlo.** Es la opción "correcta" si uno mira solo el modelo de autoridad: mientras no
controlás tu cuerpo, no sos su dueño. Se descartó porque cambia la autoridad de un
`MultiplayerSynchronizer` **en caliente**, con el juego corriendo y el nodo replicando, que
es de las cosas que más bugs raros dan y peor se debuggean — y el costo se paga para
defenderse de algo que no existe. No hay PvP, no hay anti-cheat, son cuatro amigos. El
único ataque posible es caminar estando caído, en una partida privada, contra vos mismo.

**Decidirlo caso por caso a medida que aparezcan los estados** (caído, vehículos, agarrado).
Descartada por lo mismo que ADR-0003 no se decidió caso por caso: sin una regla escrita,
cada caso se resuelve distinto según quién lo escriba y qué día sea, y a los seis meses el
proyecto tiene tres modelos de autoridad conviviendo.

No hay registrada ninguna otra alternativa evaluada.

## Consecuencias

- **Regla general, no excepción del caído:** la autoridad no se reasigna en runtime, nunca.
  Está como regla dura en `.claude/rules/netcode.md`, así que aplica a los estados que
  todavía no existen (vehículos, agarrones) sin volver a discutirla.
- **Todo estado que quite el control del cuerpo se implementa igual:** flag en el nodo de
  stats (host) → replicado → el cliente lo respeta saliendo temprano de
  `_physics_process`. Es un molde, no una decisión nueva cada vez.
- **v0.2 gana un segundo RPC del patrón 2**, `request_revive`, con validación de distancia
  en el host contra las posiciones ya replicadas. `docs/netcode.md` decía que el primero
  aparecía con el daño; son dos.
- **Si el cliente está comprometido, el modelo no aguanta.** Es explícito y aceptado. Si
  algún día entra gente que no conocemos —PvP, público, competitivo— esta ADR se revisa
  junto con ADR-0003, porque las dos apoyan en la misma suposición.
