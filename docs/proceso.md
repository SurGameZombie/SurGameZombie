# Proceso

Cómo commiteamos, cómo documentamos y cómo buscamos errores. Estas reglas no son
ceremonia: cada una existe para resolver un problema concreto de este proyecto.

---

## 1. Commits

### Cuándo commitear

**Después de cada cambio que funciona.** No al final del día, no cuando "ya está todo".

Un commit = **un cambio lógico**. Si estás por escribir "y" en el mensaje, son dos commits.

**Nunca commitear con el juego roto.** Un commit que no arranca rompe el `git bisect`
(hay que saltearlo con `git bisect skip` y se pierde precisión justo cuando más se
necesita).

### Por qué importa: `git bisect`

Cuando algo se rompe y no sabés cuándo, `git bisect` hace búsqueda binaria sobre el
historial. Con 100 commits encuentra el culpable en ~7 pasos en vez de 100.

```bash
git bisect start
git bisect bad HEAD              # ahora está roto
git bisect good <hash-que-andaba> # acá andaba
# Godot abre en un commit del medio. Probás. Decís:
git bisect good    # o git bisect bad
# repetir hasta que aísle el commit
git bisect reset   # volver al estado normal
```

Esto **solo funciona bien con commits atómicos.** Si un commit toca cinco cosas, bisect
te dice cuál commit rompió pero no cuál de los cinco cambios. Con commits atómicos,
muchas veces alcanza con revertir ese commit y listo.

### Formato del mensaje

```
tipo(scope): qué cambió, en una línea

Por qué se hizo, no qué se hizo. El diff ya dice qué.

Rejected: alternativa descartada | razón
Directive: instrucción para quien toque esto en el futuro
Tested: qué se verificó y cómo
Not-tested: qué NO se verificó y por qué
```

**Tipos:** `feat` (algo nuevo), `fix` (un arreglo), `refactor` (reestructurar sin
cambiar comportamiento), `docs`, `chore` (config y mantenimiento), `test`.

**Scopes:** `net`, `player`, `enemy`, `inventory`, `survival`, `world`, `ui`.

Ejemplo real:

```
feat(net): el host instancia los jugadores con MultiplayerSpawner

El cliente no puede instanciar porque no es autoridad del mundo. El spawner
replica cada instancia al resto y despues el host asigna la autoridad del
cuerpo al peer dueño.

Rejected: que cada cliente instancie su propio jugador | rompe la regla de
  autoridad y deja el mundo divergiendo entre maquinas
Directive: la camara se activa (current = true) solo en la instancia local.
  Si se toca esto, leer docs/netcode.md primero
Tested: dos instancias en LAN, se ven moverse en tiempo real
Not-tested: mas de dos clientes, reconexion despues de desconectar
```

### Por qué los trailers

El diff registra **qué** cambió y descarta todo lo demás: las alternativas
consideradas, las restricciones que forzaron la decisión, lo que quedó sin probar.
Eso se llama *decision shadow* y es lo que convierte código que funciona en código
que nadie entiende seis meses después.

Los tres trailers que más nos sirven:

| Trailer | Para qué |
|---|---|
| `Rejected:` | Evita que volvamos —o que Claude Code vuelva— a explorar un callejón sin salida que ya descartamos |
| `Directive:` | Mensaje permanente al futuro. Sobrevive a la conversación donde se decidió |
| `Not-tested:` | **El más importante acá.** Claude Code no puede correr el juego. Este trailer deja escrito qué quedó sin verificar en vez de que se pierda |

`Not-tested:` se puede consultar:

```bash
git log --grep="Not-tested" --oneline
```

Eso te da todo lo que **alguna vez** quedó sin verificar, incluido lo que después se
verificó: el grep no resta nada solo. Lo que resta es el trailer `Tested-later:`, que va
en el commit que paga la deuda y cita por hash al que la abrió. La mecánica exacta está en
`.claude/rules/commits.md`, que es la versión que gobierna.

Cuando aparece un bug raro, esa lista es el primer lugar donde mirar.

### Qué NO hacer

- No juntar varios cambios en un commit
- No commitear con el juego roto
- No usar mensajes como `cambios`, `fix`, `wip`, `varios`
- No describir el diff en la primera línea: el diff ya está ahí. Va el **por qué**
- **Claude Code no commitea por iniciativa propia.** El commit es el punto donde
  nosotros revisamos el diff, y automatizarlo elimina el único control de calidad que
  tenemos. Cuándo sí puede hacerlo y hasta dónde llega esa autorización lo fija
  `.claude/rules/commits.md`, que es la versión que gobierna: acá va el porqué y allá
  la regla, y no se repite en los dos lados

---

## 2. Documentación

Tres capas con propósitos distintos. Confundirlas es el error típico.

| Capa | Dónde | Qué es | Tiempo verbal |
|---|---|---|---|
| **Guía activa** | `CLAUDE.md`, `.claude/rules/` | Lo que **tiene que ser verdad** de acá en adelante | Futuro / imperativo |
| **Registro de decisiones** | `docs/decisions/` (ADRs) | Lo que **se decidió** y por qué, a nivel arquitectura | Pasado |
| **Decisiones de implementación** | Trailers en los commits | Por qué *esta función* está así | Pasado, atado al diff |

La diferencia entre las dos primeras: un ADR dice *"elegimos autoridad dividida
porque la prediction era demasiado"*. Una rule dice *"todo cambio de estado que no
sea el movimiento propio corre en el host"*. El primero explica, el segundo restringe.

### ADRs: cuándo escribir uno

**Cuando la decisión afecta cómo se conectan los sistemas, no cómo funciona uno.**

Regla práctica: si dentro de dos meses alguien puede preguntar *"¿por qué está hecho
así?"*, va ADR. Si la respuesta es *"porque sí, es la forma obvia"*, no va.

Formato (cuatro secciones, cortas):

```markdown
# ADR-000X: Título en una línea

**Fecha:** YYYY-MM-DD
**Estado:** aceptada | reemplazada por ADR-000Y

## Contexto
Qué fuerzas estaban en juego. Qué nos obligaba a decidir algo.

## Decisión
Qué se decidió, en voz activa. "Usamos X." No "se debería usar X."

## Alternativas descartadas
Qué más se consideró y por qué se descartó cada una.

## Consecuencias
Qué se vuelve fácil y qué se vuelve difícil por haber elegido esto.
```

**La sección de alternativas descartadas es la que más vale.** El "por qué no" es más
útil que el "por qué": el "por qué" muchas veces se puede reconstruir leyendo el
código, el "por qué no" nunca.

### Política de ADRs

- **Antes** de cualquier decisión arquitectónica, revisar `docs/decisions/`
- La ADR se propone **antes** de implementar, no después
- Cuando una decisión reemplaza a otra, marcar la vieja como *reemplazada*, no
  borrarla. El historial de decisiones equivocadas también es información
- Una ADR es inmutable una vez aceptada. Si cambia, se escribe una nueva

### La advertencia sobre ADRs generadas por IA

Un agente que escanea el código y genera ADRs **captura correctamente qué se decidió,
pero puede fabricar el porqué.** El "Contexto" y las "Alternativas descartadas" son
justamente las secciones que no están en el código, así que si el agente las escribe
solo, las está inventando.

**Regla:** las secciones de Contexto y Alternativas las revisamos nosotros siempre. Si
no nos acordamos por qué fue, se escribe "no registrado" en vez de inventar.

### El límite honesto

Cargar una ADR en el contexto **no es lo mismo que hacerla cumplir.** Una ADR es
información que el modelo puede pesar, descartar o recordar mal, compitiendo con todo
lo demás en la ventana.

Por eso las reglas duras van en `.claude/rules/` con path scope: se cargan
automáticamente cuando se tocan esos archivos. Las ADRs explican; las rules restringen.
Si algo es realmente no negociable, va en las dos.

---

## 3. Cómo buscamos errores

Tres herramientas, tres trabajos distintos.

| Herramienta | Contesta |
|---|---|
| `git log -S "texto"` | ¿Cuándo apareció esta línea? |
| `git blame archivo` | ¿Quién tocó esto último? |
| `git bisect` | ¿Qué commit rompió el **comportamiento**? |

`log` y `blame` miran código. **`bisect` mira comportamiento en runtime**, que es donde
viven casi todos los bugs de Godot. Cuando algo "antes andaba", bisect es la primera
herramienta, no la última.

### El registro de problemas

Todo bug que tarde **más de 30 minutos** en resolverse va a `docs/bitacora.md`, sección
"Problemas que ya nos pasaron", con tres líneas:

1. **Síntoma** — qué se veía
2. **Causa** — qué era en realidad
3. **Arreglo** — qué se hizo, y si aplica, la regla permanente que sale de ahí

Esto no es burocracia: es lo que evita gastar los mismos 30 minutos dos veces, y es lo
que Claude Code lee para no proponer una solución que ya sabemos que no funciona.

### Orden para diagnosticar

1. ¿El error está en el panel **Debugger** de Godot? Empezar por ahí, no por el código
2. ¿"Antes andaba"? → `git bisect`
3. ¿Es de red? → correr dos instancias y comparar. Casi siempre es autoridad mal
   asignada o un check de `is_multiplayer_authority()` que falta
4. ¿Está en la lista de `Not-tested:` de algún commit? → `git log --grep="Not-tested"`,
   descontando los que ya tengan un `Tested-later:` que los cite
5. ¿Ya nos pasó? → `docs/bitacora.md`

---

## 4. Checklist antes de cada commit

- [ ] El juego arranca y la cosa nueva funciona
- [ ] Leí el diff completo
- [ ] Entiendo cada línea; si no, pregunté antes de commitear
- [ ] Es **un solo** cambio lógico
- [ ] La primera línea del mensaje dice el **por qué**, no el qué
- [ ] Si descarté una alternativa, está en `Rejected:`
- [ ] Si algo quedó sin probar, está en `Not-tested:`
- [ ] Si fue una decisión arquitectónica, hay una ADR en `docs/decisions/`
