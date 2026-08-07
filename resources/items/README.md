# Items

Un archivo `.tres` por item. Los diez de v0.3 salen de `docs/design.md` → "Los primeros
10 items".

## Los pesos y los `max_stack` NO están decididos

Son **placeholders razonables, no balance**. Ninguno salió de jugarlo, y por eso ninguno
está en `docs/design.md`: ahí adentro se leerían igual que los números que sí decidieron
ustedes (`docs/retrospectiva-v0.2.md` → §1.E1). Entran a ese doc el día que salgan de un
playtest.

**Balancearlos es de Mathi** (`.claude/rules/limites.md` → "Lo que no es tuyo").

Los únicos números de este sistema que ya son decisión suya son los de capacidad —25 kg
sin mochila, 40 con— y esos sí están en `docs/design.md`.

## Esta advertencia vive en tres lugares, y uno se borra solo

| Dónde | Sobrevive a |
|---|---|
| Este README | Todo |
| El comentario `##` de `weight` en `scripts/inventory/item_definition.gd` | Todo. Además Godot lo muestra como tooltip en el Inspector, que es donde se edita |
| El comentario `;` adentro de cada `.tres` | **Se borra** la primera vez que alguien guarde ese archivo desde el Inspector de Godot |

Lo tercero está medido, no supuesto: el parser de `.tres` acepta comentarios `;` y los
lee sin problema, pero cuando Godot reescribe el archivo los descarta. En la misma pasada
descarta también las propiedades cuyo valor es igual al default del script, así que un
`.tres` guardado desde el editor puede quedar sin las líneas `stackable` y `max_stack`.
No es pérdida de datos —el default es ese— pero explica por qué el diff de git puede
mostrar líneas que desaparecen sin que nadie las haya tocado.

## Agregar un item

1. Crear el `.tres` acá, copiando cualquiera de los existentes.
2. **Agregarlo a `resources/item_catalog.tres`.** Sin eso el item no existe para el juego:
   el catálogo es la única forma de ir de un `item_id` a su definición.
3. Correr los tests. `tests/item_catalog_test.gd` revienta si el `id` está repetido o vacío.

El `id` **no se cambia nunca** después de creado: es lo que viaja por red, lo que guarda
cada stack y lo que va a entrar al save de v0.5.
