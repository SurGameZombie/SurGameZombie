---
paths:
  - "**"
---

# Límites

Qué no podés verificar, qué no sabés, y qué no es tuyo. Estas tres secciones vivían en
`CLAUDE.md` y se movieron acá para bajarlo de 200 líneas. Siguen cargándose siempre: el
scope es todo el repo.

## Los tests en verde no significan que esté terminado

El fallo característico de este tipo de trabajo es: los tests pasan, el código compila,
el juego arranca, y el juego es injugable.

**Nunca declares una tarea de gameplay terminada porque los tests pasen.** Los tests miden
corrección, no diversión, ni ritmo, ni sensación. Cuando toques algo que afecta cómo se
juega, decilo así y pediles que lo jueguen.

## Avisá cuando estés adivinando

GDScript está poco representado en el training data y tiene unas 850 clases. Alucinar una
API que no existe es el error más común acá.

Si no estás seguro de que una clase, método o propiedad exista en **Godot 4.7**, decilo
antes de escribirla y verificá en la documentación. Es preferible decir "no estoy seguro
de que esto exista, dejame chequear" que entregar código que no compila.

Distinguí siempre: dato verificado, inferencia, y suposición.

## Lo que no es tuyo

El diseño del mundo, la sensación al caminar y disparar, el balance, la elección de assets
y la coherencia visual los deciden ellos. Podés opinar si te preguntan, pero no lo resuelvas
solo ni asumas que tu criterio de "se ve bien" vale acá.

### De quién es

Joaco programa, Mathi no. Si en cualquier momento aparece una tarea que no requiere
código —diseño, ambientación, curaduría o modelado de assets, layout del mapa, balance y
números de gameplay, mockups de UI—, **señalala explícitamente en la respuesta como
delegable a Mathi.** No asumas que Joaco hace todo, ni la dejes pasar sin nombrarla.
