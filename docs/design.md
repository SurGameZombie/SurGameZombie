# Diseño

## Qué es

Survival co-op en primera persona para 2-4 jugadores. Un jugador hostea y juega en el
mismo proceso; el resto se conecta.

El loop central: explorar → lootear → consumir → sobrevivir un poco más. Los zombies
son la presión, la escasez es la dificultad.

Referencias de tono: SurrounDead, DayZ, Road to Vostok. Realismo por escasez y
consecuencia, no por cantidad de sistemas.

## Qué NO es

- No es mundo abierto. Un mapa cerrado y denso, de sesión de 30-60 minutos.
- No es un shooter. El combate es escaso, torpe y peligroso.
- No es PvP. Solo cooperativo contra el entorno.
- No tiene personalización de personaje en la v1.
- No tiene base building en la v1.
- No tiene crafteo profundo en la v1.

## Sistemas de la v1

**Stats:** vida, hambre, sed, stamina. Nada más.
Temperatura, heridas y enfermedad quedan para después, si el loop base funciona.

**Enemigo:** un solo tipo de zombie. Lento, peligroso en grupo, ruidoso al detectarte.

**Inventario:** limitado por peso o por slots (decidir). Los items ocupan espacio real,
llevar munición cuesta.

**Armas:** un melee y una de fuego. La munición es rara. Disparar atrae zombies.

**Muerte:** [DECIDIR] ¿respawn con pérdida de inventario? ¿el mapa se resetea?
¿los otros jugadores pueden revivirte?

## Escala y números base

**Valores de arranque, para tunear.** Están acá para que nada se escriba con números
inventados, no porque estén balanceados: el ajuste fino sale de jugarlo.

| | |
|---|---|
| Escala del mundo | 1 unidad de Godot = 1 metro |
| Altura del jugador | 1.8 m |
| Velocidad de caminata | 4 m/s |
| Velocidad de corrida | 7 m/s |

La escala en metros no es cosmética: hace que las físicas de Godot (gravedad, masas,
fricción) den valores realistas sin tener que compensar, y es la referencia contra la que
se ajusta la escala de los assets al importarlos.

Dos notas de implementación, para la v0.1:

- **1.8 m es la altura del cuerpo**, no la de la cámara. En primera persona la cámara va a
  la altura de los ojos, un poco más abajo (~1.6-1.7 m). Si se pone a 1.8 se siente como
  flotar.
- Referencias del mundo real, para tunear contra algo: una persona camina a ~1.4 m/s,
  trota a ~3 m/s y esprinta a ~8 m/s. O sea que estos valores de arranque son más rápidos
  que la vida real, que es lo normal en juegos porque la velocidad realista se siente
  lentísima. Si el juego tiene que sentirse pesado y torpe, es de acá de donde hay que
  bajar.

## Huecos por completar

- [ ] Nombre del juego
- [ ] Ambientación concreta: ¿dónde pasa? ¿un pueblo, un complejo industrial, un barrio?
- [ ] Qué pasa al morir
- [ ] Condición de victoria de una sesión (¿hay una? ¿es supervivencia infinita?)
- [ ] Lista de los primeros 10 items

## Milestones

Cada uno tiene que ser jugable de punta a punta antes de pasar al siguiente.

| | Qué tiene que funcionar |
|---|---|
| **v0.1** | Dos cápsulas sincronizadas moviéndose en una caja. Host + 1 cliente por IP en LAN. Nada más. |
| **v0.2** | Un zombie que persigue por NavMesh y pega. Vida del jugador, muerte, respawn. |
| **v0.3** | Inventario replicado, ~10 items, contenedores registrables, pickup y drop. |
| **v0.4** | Hambre y sed drenando, consumibles, muerte por inanición, stamina al correr. |
| **v0.5** | Melee + arma de fuego con munición escasa. Spawn de zombies. Día/noche. Guardado. |
| **v1.0** | Conexión sin port forwarding, lobby, menús, sonido, mapa para una sesión real. |

**v0.1 es el filtro.** Si en dos semanas eso no está andando limpio, falta base:
conviene hacer un juego más chico primero antes de volver a este.

## Reparto de trabajo

- **Mathi** — netcode y sistemas (`scripts/`)
- **Joaquin** — mundo, contenido y assets (`scenes/`, `assets/`, `resources/`)

**`project.godot` es de Mathi.** Es el archivo que los dos necesitan tocar (autoloads,
input map, capas de física) y el que peor mergea, así que tiene un solo dueño. Si Joaquin
necesita cambiar algo ahí, avisa antes.

Regla: nunca editar la misma escena al mismo tiempo. Avisar antes de tocar `scenes/main/`.
