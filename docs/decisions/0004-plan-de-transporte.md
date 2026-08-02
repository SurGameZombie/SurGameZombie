# ADR-0004: El transporte de red se elige por etapa, no de una vez

**Fecha:** 2026-08-01
**Estado:** aceptada
**Fuente:** `docs/plan.md` §2 → "Conectividad: tres opciones, en este orden";
`docs/bitacora.md` → "Plan de transporte"; `docs/netcode.md` → "Transporte: plan de
migración"

## Contexto

Hay tres formas de conectar a los jugadores y cada una resuelve un problema distinto a un
costo distinto:

| Opción | Qué resuelve | Costo |
|---|---|---|
| `ENetMultiplayerPeer` (built-in) | Conexión directa por IP. Anda en LAN sin configurar nada. Por internet el host tiene que abrir puerto en el router | $0, cero dependencias |
| `netfox.noray` | NAT punchthrough + fallback a relay. Los amigos se conectan con un código, sin tocar el router | $0, open source |
| `SteamMultiplayerPeer` (expressobits) + GodotSteam | Steam maneja NAT, lobbies e invitaciones por el overlay | USD 100 por App ID, recuperable a los USD 1.000 de revenue |

Ninguna de las tres es la respuesta para siempre, y hoy no hay información suficiente para
saber si el juego va a terminar en Steam.

## Decisión

**Elegimos un transporte para ahora y aislamos el cambio.**

| Etapa | Transporte | Por qué ahí |
|---|---|---|
| Ahora → v0.5 | `ENetMultiplayerPeer` | Alcanza para testear entre nosotros dos en LAN |
| v1.0 | `netfox.noray` | Cuando entren amigos que no van a hacer port forwarding |
| Si alguna vez va a Steam | `SteamMultiplayerPeer` | Solo si el juego apunta a Steam |

**La creación del peer vive solo en `scripts/net/network_manager.gd`.** El resto del
código nunca sabe qué transporte se usa. Cambiar de uno a otro tiene que ser un cambio de
diez líneas en un archivo, no un refactor.

## Alternativas descartadas

**Elegir un transporte definitivo desde el principio.** Descartada explícitamente: "no
elijas una para siempre, elegí una para *ahora* y aislá el cambio".

**Arrancar directo con `netfox.noray`.** La instancia pública de prueba
(`tomfol.io:8890`) no tiene garantía de uptime y no es para producción. No hace falta
mientras los únicos que testean son los dos, en LAN.

**Arrancar directo con Steam.** Cuesta USD 100 por App ID y solo tiene sentido si el juego
apunta a Steam, cosa que hoy no está decidida. (Para desarrollo existe el App ID 480 de
Spacewar, gratis; no está registrado que se haya evaluado usarlo antes de v1.0.)

## Consecuencias

- Hasta v1.0, jugar por internet exige que el host abra un puerto en el router. Entre
  nosotros dos y en LAN, no.
- `scripts/net/network_manager.gd` queda como archivo con una responsabilidad
  arquitectónica explícita: es el único que puede nombrar un tipo de peer. Cualquier otro
  archivo que mencione ENet, noray o Steam es un bug de diseño.
- El plugin de expressobits está pensado justamente para esto: se swappea
  `ENetMultiplayerPeer` por `SteamMultiplayerPeer` y el código de alto nivel queda igual.
- La migración a noray queda como trabajo pendiente de v1.0, con su propio costo. No es
  gratis, es diferido.
