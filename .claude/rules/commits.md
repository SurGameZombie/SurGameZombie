---
paths:
  - "**"
---

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
```

**Tipos:** `feat`, `fix`, `refactor`, `docs`, `chore`, `test`.
**Scopes:** `net`, `player`, `enemy`, `inventory`, `survival`, `world`, `ui`.

La primera línea va en español y dice el **por qué**, no el qué. Nada de `cambios`, `fix`,
`wip`, `varios`.

## Los tres trailers que importan

| Trailer | Cuándo va |
|---|---|
| `Rejected:` | Se consideró otra forma y se descartó. Evita que alguien —o Claude Code— vuelva a entrar al mismo callejón sin salida |
| `Directive:` | Hay algo que quien toque esto en el futuro tiene que saber. Sobrevive a la conversación donde se decidió |
| `Not-tested:` | **El más importante.** Claude Code no puede correr el juego. Todo lo que quedó sin verificar va acá o se pierde |

`Not-tested:` es la fuente de la lista de deuda de verificación del proyecto:

```bash
git log --grep="Not-tested" --oneline
```

Cuando aparece un bug raro, ese es el primer lugar donde mirar.

## Si la decisión fue arquitectónica

Va también una ADR en `docs/decisions/`, con el formato de `docs/proceso.md` §2. Regla
práctica: si en dos meses alguien puede preguntar "¿por qué está hecho así?", va ADR.

**El Contexto y las Alternativas descartadas de una ADR las escriben ellos, no vos.** Son
justo las dos secciones que no están en el código, así que escribirlas de memoria es
inventarlas. Si algo no está registrado, va "no registrado".
