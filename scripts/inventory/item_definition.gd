class_name ItemDefinition
extends Resource

## Qué es un item. Un archivo .tres por item en resources/items/, nunca
## hardcodeado en GDScript (CLAUDE.md → "Datos como Resources").
##
## Un archivo por item y no una base de datos única a propósito: cambiarle el peso
## a un item tiene que tocar un solo archivo, para que dos personas puedan
## balancear al mismo tiempo sin pisarse. El addon de expressobits guarda todos los
## items adentro de un InventoryDatabase único y ese es justo su problema.
##
## Esto es SOLO la definición: qué es un item en abstracto. Cuántos tenés encima
## es ItemStack, y dónde están es Inventory.

## Identificador estable. Es lo que viaja por red, lo que guarda cada stack y lo
## que va a entrar al save de v0.5, así que NO se cambia nunca después de creado:
## renombrarlo convierte toda referencia vieja en un item que no existe.
##
## En inglés, como todo identificador del proyecto (CLAUDE.md → "Reglas de
## código"). El nombre en castellano va en display_name.
@export var id: String = ""

## Cómo se llama en pantalla. Este sí se puede cambiar cuando quieran: no lo
## referencia nadie.
@export var display_name: String = ""

## Cuánto pesa UNA unidad, en kg. El inventario lo multiplica por la cantidad.
##
## PROVISORIO: los diez pesos de v0.3 son placeholders razonables, no balance.
## Ninguno salió de jugarlo y ninguno está en docs/design.md — ahí adentro se
## leerían igual que los números que sí decidieron ellos
## (docs/retrospectiva-v0.2.md → §1.E1). Balancearlos es de Mathi.
@export var weight: float = 0.0

## Ícono para la UI. Queda null en toda la v0.3: los assets entran en v0.6 y
## elegirlos no es nuestro (.claude/rules/limites.md → "Lo que no es tuyo"). La UI
## del milestone muestra display_name.
@export var icon: Texture2D

## Si varias unidades comparten un stack. En false, cada unidad ocupa su propio
## stack aunque haya otra igual al lado.
##
## No es una propiedad de conveniencia: decide si tener 30 balas es una línea en
## la UI o treinta.
@export var stackable: bool = false

## Cuántas unidades entran en un stack. Se ignora si stackable es false — usar
## stack_size(), que ya resuelve esa combinación.
##
## PROVISORIO, por la misma razón que weight.
@export var max_stack: int = 1


## Cuántas unidades entran de verdad en un stack de este item. La llama
## inventory.gd cada vez que reparte una cantidad entre stacks.
##
## Existe para que nadie tenga que acordarse de mirar stackable antes de mirar
## max_stack: un item con stackable en false y max_stack en 30 es un dato
## contradictorio, y esta función elige cuál de los dos manda.
func stack_size() -> int:
	if not stackable:
		return 1
	return maxi(1, max_stack)
