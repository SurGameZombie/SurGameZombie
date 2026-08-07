extends GdUnitTestSuite

## Tests del catálogo de items. Corren sin peer de red y sin escena: ItemCatalog
## e ItemDefinition son Resources puros, que es exactamente la "lógica pura" que
## docs/plan.md §5 dice que hay que testear.

const CATALOG_PATH: String = "res://resources/item_catalog.tres"

## Los diez de docs/design.md → "Los primeros 10 items".
const EXPECTED_ITEM_COUNT: int = 10


func test_el_catalogo_del_juego_carga_los_diez_items() -> void:
	var catalog: ItemCatalog = load(CATALOG_PATH) as ItemCatalog
	assert_object(catalog).is_not_null()
	assert_int(catalog.items.size()).is_equal(EXPECTED_ITEM_COUNT)


# El catálogo de verdad tiene que estar sano. Este test es el que va a fallar el
# día que alguien agregue un item con un id que ya existía, que es el caso que
# _ensure_index() revienta en runtime.
func test_el_catalogo_del_juego_es_valido() -> void:
	var catalog: ItemCatalog = load(CATALOG_PATH) as ItemCatalog
	var problems: PackedStringArray = catalog.validate()
	assert_str("\n".join(problems)).is_empty()


func test_get_item_devuelve_la_definicion_por_id() -> void:
	var catalog: ItemCatalog = load(CATALOG_PATH) as ItemCatalog
	var backpack: ItemDefinition = catalog.get_item("backpack")
	assert_object(backpack).is_not_null()
	assert_str(backpack.id).is_equal("backpack")
	assert_float(backpack.weight).is_greater(0.0)


# El id lo manda el cliente por RPC, así que "no existe" es un caso normal y no
# un error: el host tiene que poder preguntar sin que explote nada.
func test_get_item_devuelve_null_con_un_id_inventado() -> void:
	var catalog: ItemCatalog = load(CATALOG_PATH) as ItemCatalog
	assert_object(catalog.get_item("no_existe_este_item")).is_null()
	assert_bool(catalog.has_item("no_existe_este_item")).is_false()
	assert_bool(catalog.has_item("backpack")).is_true()


func test_validate_detecta_un_id_duplicado() -> void:
	var catalog: ItemCatalog = ItemCatalog.new()
	catalog.items = [
		_definition("bandages", 0.1),
		_definition("bandages", 0.2),
	]

	var problems: PackedStringArray = catalog.validate()
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("duplicado")
	assert_str(problems[0]).contains("bandages")


func test_validate_detecta_un_id_vacio() -> void:
	var catalog: ItemCatalog = ItemCatalog.new()
	catalog.items = [_definition("", 1.0)]

	var problems: PackedStringArray = catalog.validate()
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("no tiene id")


func test_validate_detecta_una_entrada_vacia() -> void:
	var catalog: ItemCatalog = ItemCatalog.new()
	catalog.items = [null]

	var problems: PackedStringArray = catalog.validate()
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("vacía")


# stack_size() existe para que un item con stackable en false y max_stack en 30
# —un dato contradictorio, y perfectamente escribible en un .tres— no meta 30
# unidades en un stack que no debería stackear.
func test_stack_size_ignora_max_stack_si_el_item_no_es_stackeable() -> void:
	var definition: ItemDefinition = _definition("test", 1.0)
	definition.stackable = false
	definition.max_stack = 30
	assert_int(definition.stack_size()).is_equal(1)

	definition.stackable = true
	assert_int(definition.stack_size()).is_equal(30)


func _definition(id: String, weight: float) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.id = id
	definition.weight = weight
	return definition
