# Commits

Reglas operativas. El porqué de cada una está en `docs/proceso.md` §1 — leerlo antes de
escribir cualquier mensaje de commit.

## Claude Code no commitea por iniciativa propia

El commit es el punto donde ellos revisan el diff. Automatizarlo elimina el único control
de calidad del proyecto.

**El default es preparar el mensaje y parar ahí.** Terminar una tarea no habilita a
commitearla. Ni "ya que estamos", ni porque el cambio sea chico, ni porque los tests pasen,
ni porque el commit anterior lo hayan pedido.

**Ejecutar `git commit` solo cuando lo piden explícitamente en ese momento** —"commiteá
esto", "hacelo vos", "el commit hacelo vos". La autorización vale para ese pedido y se
termina ahí: no se hereda a la tarea siguiente ni a la próxima sesión.

Si en ese mismo pedido hay más de un cambio lógico, la autorización cubre todos los commits
que hagan falta para separarlos bien. **Un commit = un cambio lógico** sigue mandando; que
lo hayan pedido no es excusa para meter todo junto.

### Un commit aprobado y sin pushear es un estado inválido

Después de que Joaco aprueba un commit, **se le pregunta si se pushea.** Si se está armando
una tanda de varios commits a propósito, se pregunta al cerrar la tanda.

El repo es el único canal entre las dos máquinas y entre Joaco y Mathi: lo que no se
pushea, para el resto del sistema no existe.

## Un commit = un cambio lógico

Si el mensaje necesita un "y", son dos commits.

**Nunca commitear con el juego roto.** Un commit que no arranca rompe el `git bisect`, que
es la única herramienta que encuentra bugs de runtime en el historial.

## Formato del mensaje

```
tipo(scope): qué cambió, en una línea

Por qué se hizo, no qué se hizo. El diff ya dice qué.

Rejected: alternativa descartada | razón
Directive: instrucción para quien toque esto en el futuro
Tested: qué se verificó y cómo
Not-tested: qué NO se verificó y por qué
Tested-later: <hash> — cómo y cuándo se verificó lo que ese commit dejó abierto
```

**Tipos:** `feat`, `fix`, `refactor`, `docs`, `chore`, `test`.
**Scopes:** `net`, `player`, `enemy`, `inventory`, `survival`, `world`, `ui`.

La primera línea va en español y dice el **por qué**, no el qué. Nada de `cambios`, `fix`,
`wip`, `varios`.

## Los trailers que importan

| Trailer | Cuándo va |
|---|---|
| `Rejected:` | Se consideró otra forma y se descartó. Evita que alguien —o Claude Code— vuelva a entrar al mismo callejón sin salida |
| `Directive:` | Hay algo que quien toque esto en el futuro tiene que saber. Sobrevive a la conversación donde se decidió |
| `Not-tested:` | **El más importante.** Claude Code no puede correr el juego. Todo lo que quedó sin verificar va acá o se pierde |
| `Tested-later:` | Este commit paga una deuda que abrió un `Not-tested:` anterior. Es lo único que **resta** de la lista de deuda |

`Not-tested:` es la fuente de la lista de deuda de verificación del proyecto:

```bash
git log --grep="^Not-tested:" --oneline
```

Cuando aparece un bug raro, ese es el primer lugar donde mirar.

### `Not-tested:` no se completa con excusas

Va **solo cuando había algo ejecutable que no se ejerció.** Si el commit no cambia
comportamiento en runtime —docs, prosa, config inerte—, el trailer se omite entero. Nada de
`Not-tested: nada que testear, es prosa` ni sus variantes: eso mete ruido en la única señal
mecánica de deuda que tiene el proyecto, y ya se coló varias veces.

Un commit de docs que igual deja algo sin verificar sí lo escribe. Lo que sobra es la
excusa, no la deuda real.

### `Tested-later:` es lo único que resta

```
Tested-later: <hash o hashes del commit que abrió la deuda> — cómo y cuándo se verificó
```

Va en el commit que **paga** la deuda, y apunta hacia atrás por hash. **El commit viejo no
se toca:** su `Not-tested:` original queda como está, porque era verdad cuando se escribió y
reescribir el historial invalida los hashes que lo citan.

Si lo que pagó la deuda fue un playtest y no un cambio de código, el trailer va en el commit
que lo **registra** —el de la entrada en `docs/bitacora.md`—, que es el único que hay.

Sin esto, `git log --grep="^Not-tested:"` es append-only —nunca se resta nada—, así que una
lista de deuda armada con ese comando miente desde el día uno: incluye lo que ya se pagó.

**La deuda abierta son los `Not-tested:` cuyo hash no aparece citado en ningún
`Tested-later:` posterior.**

```bash
git log --grep="^Not-tested:" --oneline    # todo lo que alguna vez quedó sin verificar
git log --grep="^Tested-later:" --oneline  # lo que ya se pagó, con el hash de la deuda
```

Un `Tested-later:` no tiene que cerrar todo el `Not-tested:` del commit que cita: si paga
una parte, dice cuál. Lo que no puede es dar por verificado algo que no se ejerció.

## Si la decisión fue arquitectónica

Va también una ADR en `docs/decisions/`, con el formato de `docs/proceso.md` §2. Regla
práctica: si en dos meses alguien puede preguntar "¿por qué está hecho así?", va ADR.

**El Contexto y las Alternativas descartadas de una ADR las escriben ellos, no vos.** Son
justo las dos secciones que no están en el código, así que escribirlas de memoria es
inventarlas. Si algo no está registrado, va "no registrado".
