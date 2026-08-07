class_name ItemCatalog
extends Resource

## El índice de todos los items del juego. Es la única forma de ir de un item_id
## —que es lo que guarda cada stack y lo que viaja por red— a su ItemDefinition.
##
## Acá adentro no hay items: hay referencias a los .tres de resources/items/.
## Agregar un item toca dos archivos (el .tres nuevo y una línea de este); cambiar
## el peso de uno toca solo el suyo. Esa asimetría es a propósito y es la razón de
## que este archivo exista en vez de una base de datos con todo adentro: balancear
## es lo que se hace seguido y de a dos, y es lo que no tiene que dar conflicto.
##
## Se consume con un preload como const desde inventory.gd, no como autoload: es
## dato estático, idéntico en las tres máquinas y sin nada que replicar
## (.claude/rules/gdscript.md → pitfall 6).

## Los items del juego, uno por .tres. El orden no significa nada.
@export var items: Array[ItemDefinition] = []

## item_id -> ItemDefinition. Se arma una sola vez, la primera vez que alguien
## pregunta algo.
var _by_id: Dictionary = {}

## Si _by_id ya está armado. Va aparte de `_by_id.is_empty()` porque un catálogo
## vacío es un estado posible —y roto— y no queremos reintentar armarlo en cada
## consulta.
var _indexed: bool = false


## La definición de un item, o null si ese id no existe. La llaman inventory.gd,
## la UI y el host al validar un pedido.
func get_item(item_id: String) -> ItemDefinition:
	_ensure_index()
	return _by_id.get(item_id) as ItemDefinition


## Si el id existe. La llama el host ANTES de aceptar un pedido de un cliente: el
## item_id lo manda el cliente y puede ser inventado.
func has_item(item_id: String) -> bool:
	_ensure_index()
	return _by_id.has(item_id)


## Todos los ids del catálogo. La llaman el andamio de debug y los tests.
func ids() -> PackedStringArray:
	_ensure_index()
	var out: PackedStringArray = PackedStringArray()
	for key: String in _by_id.keys():
		out.append(key)
	return out


## Los problemas del catálogo, uno por elemento, o vacío si está sano.
##
## Es pública y separada de _ensure_index() para que se pueda testear el chequeo
## sin que el chequeo mate al test: _ensure_index() revienta con assert() cuando
## esto devuelve algo, y un assert no se puede atrapar desde gdUnit4.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for index: int in items.size():
		var definition: ItemDefinition = items[index]
		if definition == null:
			problems.append("la entrada %d está vacía" % index)
			continue
		if definition.id.is_empty():
			problems.append("la entrada %d (%s) no tiene id" % [index, definition.resource_path])
			continue
		if seen.has(definition.id):
			problems.append("item_id duplicado: '%s' en %s y en %s" % [
				definition.id,
				seen[definition.id],
				definition.resource_path,
			])
			continue
		seen[definition.id] = definition.resource_path
	return problems


# Arma el índice, reventando si el catálogo está roto.
#
# Revienta en vez de seguir a propósito: un id repetido o vacío no da un error en
# el momento, da el item equivocado tres sistemas más adelante, y ahí el síntoma
# ("agarré una venda y me apareció una linterna") no se parece en nada a la causa.
# Es la misma clase de bug que el proyecto ya se comió con el cell_height del
# NavMesh (docs/bitacora.md).
#
# push_error() va ADEMÁS del assert y no en su lugar: assert() se elimina en las
# builds de release, así que sin él un catálogo roto en una build exportada sería
# completamente silencioso.
func _ensure_index() -> void:
	if _indexed:
		return
	_indexed = true

	var problems: PackedStringArray = validate()
	if not problems.is_empty():
		var report: String = "[inventory] catálogo inválido:\n  " + "\n  ".join(problems)
		push_error(report)
		assert(false, report)

	for definition: ItemDefinition in items:
		if definition == null or definition.id.is_empty():
			continue
		# Ante un duplicado gana el primero. Da igual cuál gane —el assert de
		# arriba ya cortó en debug—: lo que importa es no dejar el índice a medias
		# en una build de release.
		if not _by_id.has(definition.id):
			_by_id[definition.id] = definition
