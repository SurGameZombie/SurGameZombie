class_name ItemStack
extends Resource

## Un montón de un item adentro de un inventario: qué es y cuánto hay.
##
## Sin posición ni rotación, a propósito: el inventario es por peso, no por grilla
## (docs/design.md → "Inventario: limitado por peso"). Sin durabilidad ni
## propiedades por instancia tampoco: en v0.3 los diez items son inertes y
## CLAUDE.md prohíbe abstracciones "por si acaso". Cuando la durabilidad haga
## falta, entra acá.
##
## **Esto no viaja por red.** Los argumentos de un @rpc no serializan Objects, y un
## Resource es un Object. Lo que viaja es lo que devuelve Inventory.serialize(),
## que aplana estos stacks a primitivas.

## El id de un ItemDefinition del catálogo. String y no una referencia al Resource
## por lo mismo de arriba: esto sí tiene que poder aplanarse a algo que cruce la
## red y entre al save de v0.5.
var item_id: String = ""

## Cuántas unidades. Nunca negativo y nunca cero en un stack vivo: inventory.gd
## borra el stack cuando llega a cero, en vez de dejar stacks vacíos dando vueltas.
var amount: int = 0


func _init(p_item_id: String = "", p_amount: int = 0) -> void:
	item_id = p_item_id
	amount = p_amount
