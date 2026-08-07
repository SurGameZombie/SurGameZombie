extends GdUnitTestSuite

## Tests del nodo Inventory. Corren sin peer de red y sin escena, porque
## inventory.gd no tiene una línea de red: es la razón por la que la replicación
## vive en inventory_sync.gd y no acá adentro.
##
## Los números vienen de los .tres reales de resources/items/, no de fixtures
## inventadas. Eso los ata al balance: si alguien cambia un peso, el test que
## falla dice exactamente cuál. Es a propósito — son PROVISORIOS y van a cambiar,
## y queremos enterarnos.

## crowbar pesa 2.0 kg y no stackea: 12 entran en 25 kg (24.0) y el 13 no (26.0).
const CROWBAR: String = "crowbar"
const CROWBAR_WEIGHT: float = 2.0

## water_bottle pesa 1.0 kg: 25 entran EXACTO en 25 kg. Es el caso que prueba que
## el margen de coma flotante de WEIGHT_EPSILON no se coma la última unidad.
const WATER: String = "water_bottle"

## ammo_9mm pesa 0.012 kg y stackea de a 30.
const AMMO: String = "ammo_9mm"
const AMMO_STACK: int = 30


# --- capacidad y peso ------------------------------------------------------

func test_arranca_vacio_y_sin_peso() -> void:
	var inventory: Inventory = _inventory()
	assert_bool(inventory.is_empty()).is_true()
	assert_float(inventory.get_weight()).is_equal(0.0)


func test_el_peso_sale_del_catalogo_por_la_cantidad() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(CROWBAR, 3)
	assert_float(inventory.get_weight()).is_equal_approx(3.0 * CROWBAR_WEIGHT, 0.0001)


# El caso del filo: 25 botellas de 1 kg en 25 kg de capacidad tienen que entrar
# las 25. Sin WEIGHT_EPSILON, la última se cae por error de coma flotante.
func test_entra_justo_lo_que_llena_la_capacidad_exacta() -> void:
	var inventory: Inventory = _inventory()
	var leftover: int = inventory.add(WATER, 25)
	assert_int(leftover).is_equal(0)
	assert_int(inventory.amount_of(WATER)).is_equal(25)
	assert_float(inventory.get_weight()).is_equal_approx(25.0, 0.0001)


func test_add_devuelve_el_sobrante_cuando_no_entra_por_peso() -> void:
	var inventory: Inventory = _inventory()
	# 20 palancas son 40 kg contra 25 de capacidad: entran 12.
	var leftover: int = inventory.add(CROWBAR, 20)
	assert_int(leftover).is_equal(8)
	assert_int(inventory.amount_of(CROWBAR)).is_equal(12)
	assert_float(inventory.get_weight()).is_equal_approx(24.0, 0.0001)


func test_add_no_mete_nada_con_un_item_id_inventado() -> void:
	var inventory: Inventory = _inventory()
	var leftover: int = inventory.add("no_existe", 5)
	assert_int(leftover).is_equal(5)
	assert_bool(inventory.is_empty()).is_true()


func test_has_space_for_es_todo_o_nada() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(CROWBAR, 12)
	assert_bool(inventory.has_space_for(CROWBAR, 1)).is_false()
	assert_bool(inventory.has_space_for(AMMO, 30)).is_true()


func test_la_mochila_sube_la_capacidad_y_la_vuelve_a_bajar() -> void:
	var inventory: Inventory = _inventory()
	inventory.apply_backpack_capacity()
	assert_float(inventory.capacity).is_equal(40.0)
	# Con 40 kg entran 20 palancas donde antes entraban 12.
	assert_int(inventory.add(CROWBAR, 20)).is_equal(0)

	# Desequiparla NO tira nada: docs/design.md dice que el sobrepeso te frena, no
	# que te bloquee. Quedás en 40 kg con capacidad para 25.
	inventory.reset_capacity()
	assert_float(inventory.capacity).is_equal(25.0)
	assert_float(inventory.get_weight()).is_equal_approx(40.0, 0.0001)
	assert_int(inventory.amount_of(CROWBAR)).is_equal(20)


# El setter de capacity tiene que emitir sí o sí, incluso asignando la propiedad
# directo. Si no emitiera, la UI y los clientes se quedarían con el número viejo
# sin que nada avise.
func test_asignar_capacity_emite_la_senal_y_no_recursa() -> void:
	var inventory: Inventory = _inventory()
	var seen: Array[float] = []
	inventory.capacity_changed.connect(func(value: float) -> void: seen.append(value))

	inventory.capacity = 40.0
	inventory.capacity = 40.0  # mismo valor: no tiene que emitir de nuevo
	inventory.capacity = 10.0

	assert_array(seen).is_equal([40.0, 10.0] as Array[float])


# --- stacking --------------------------------------------------------------

func test_completa_el_stack_a_medio_llenar_antes_de_abrir_uno_nuevo() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 10)
	assert_int(inventory.stacks.size()).is_equal(1)

	inventory.add(AMMO, 5)
	assert_int(inventory.stacks.size()).is_equal(1)
	assert_int(inventory.stacks[0].amount).is_equal(15)


func test_abre_un_stack_nuevo_al_pasarse_de_max_stack() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 45)
	assert_int(inventory.stacks.size()).is_equal(2)
	assert_int(inventory.stacks[0].amount).is_equal(AMMO_STACK)
	assert_int(inventory.stacks[1].amount).is_equal(15)
	assert_int(inventory.amount_of(AMMO)).is_equal(45)


func test_un_item_no_stackeable_ocupa_un_stack_por_unidad() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(CROWBAR, 3)
	assert_int(inventory.stacks.size()).is_equal(3)


# --- sacar -----------------------------------------------------------------

func test_remove_devuelve_lo_que_falto_sacar() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 10)
	var missing: int = inventory.remove(AMMO, 25)
	assert_int(missing).is_equal(15)
	assert_int(inventory.amount_of(AMMO)).is_equal(0)
	assert_bool(inventory.is_empty()).is_true()


func test_remove_saca_del_stack_mas_nuevo_primero() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 45)  # [30, 15]
	assert_int(inventory.remove(AMMO, 10)).is_equal(0)
	assert_int(inventory.stacks.size()).is_equal(2)
	assert_int(inventory.stacks[0].amount).is_equal(AMMO_STACK)
	assert_int(inventory.stacks[1].amount).is_equal(5)


func test_un_stack_que_llega_a_cero_desaparece_de_la_lista() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 45)
	assert_int(inventory.remove(AMMO, 15)).is_equal(0)
	assert_int(inventory.stacks.size()).is_equal(1)
	assert_int(inventory.stacks[0].amount).is_equal(AMMO_STACK)


func test_clear_deja_el_inventario_vacio() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 45)
	inventory.add(CROWBAR, 2)
	inventory.clear()
	assert_bool(inventory.is_empty()).is_true()
	assert_float(inventory.get_weight()).is_equal(0.0)


# --- señales de replicación ------------------------------------------------

# Son las tres que inventory_sync.gd convierte en deltas. Si dejan de emitirse en
# el momento correcto, la réplica se rompe sin un solo error en pantalla.
func test_emite_stack_added_updated_y_removed_en_ese_orden() -> void:
	var inventory: Inventory = _inventory()
	var log: Array[String] = []
	inventory.stack_added.connect(func(i: int) -> void: log.append("added:%d" % i))
	inventory.stack_updated.connect(func(i: int) -> void: log.append("updated:%d" % i))
	inventory.stack_removed.connect(func(i: int) -> void: log.append("removed:%d" % i))

	inventory.add(AMMO, 10)   # abre el stack 0
	inventory.add(AMMO, 5)    # completa el stack 0
	inventory.remove(AMMO, 15)  # lo vacía

	assert_array(log).is_equal(["added:0", "updated:0", "removed:0"] as Array[String])


func test_item_added_e_item_removed_informan_lo_que_de_verdad_entro() -> void:
	var inventory: Inventory = _inventory()
	var added: Array = []
	var removed: Array = []
	inventory.item_added.connect(func(id: String, n: int) -> void: added.append([id, n]))
	inventory.item_removed.connect(func(id: String, n: int) -> void: removed.append([id, n]))

	inventory.add(CROWBAR, 20)  # entran 12 de 20
	inventory.remove(CROWBAR, 50)  # salen 12 de 50

	assert_array(added).is_equal([[CROWBAR, 12]])
	assert_array(removed).is_equal([[CROWBAR, 12]])


# --- serialización ---------------------------------------------------------

func test_serialize_y_deserialize_dan_la_vuelta_completa() -> void:
	var origin: Inventory = _inventory()
	origin.apply_backpack_capacity()
	origin.add(AMMO, 45)
	origin.add(CROWBAR, 2)

	var copy: Inventory = _inventory()
	copy.deserialize(origin.serialize())

	assert_float(copy.capacity).is_equal(origin.capacity)
	assert_int(copy.stacks.size()).is_equal(origin.stacks.size())
	assert_int(copy.amount_of(AMMO)).is_equal(45)
	assert_int(copy.amount_of(CROWBAR)).is_equal(2)
	assert_float(copy.get_weight()).is_equal_approx(origin.get_weight(), 0.0001)


# Lo que va por la red tienen que ser primitivas y nada más: los argumentos de un
# @rpc no serializan Objects. Si alguna vez alguien mete el ItemStack adentro del
# Dictionary, esto lo agarra acá y no con un RPC que se descarta en silencio.
func test_serialize_no_devuelve_ningun_objeto() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 45)

	var data: Dictionary = inventory.serialize()
	var entries: Array = data["stacks"]
	for entry: Array in entries:
		assert_int(typeof(entry[0])).is_equal(TYPE_STRING)
		assert_int(typeof(entry[1])).is_equal(TYPE_INT)
	assert_int(typeof(data["capacity"])).is_equal(TYPE_FLOAT)


func test_deserialize_emite_contents_changed() -> void:
	var inventory: Inventory = _inventory()
	var repaints: Array[int] = []
	inventory.contents_changed.connect(func() -> void: repaints.append(1))

	inventory.deserialize({"stacks": [[AMMO, 7]], "capacity": 25.0})

	assert_int(repaints.size()).is_equal(1)
	assert_int(inventory.amount_of(AMMO)).is_equal(7)


func test_deserialize_ignora_un_snapshot_incompleto() -> void:
	var inventory: Inventory = _inventory()
	inventory.add(AMMO, 5)
	# El push_error del inventario es esperado acá: se está probando justo eso.
	assert_error(func() -> void: inventory.deserialize({"stacks": []})) \
		.is_push_error("[inventory] snapshot inválido: { \"stacks\": [] }")
	assert_int(inventory.amount_of(AMMO)).is_equal(5)


func _inventory() -> Inventory:
	# auto_free porque Inventory es un Node y estos tests no lo meten al árbol.
	# Sin esto gdUnit4 reporta orphans, que es su forma de decir "acá hay una fuga".
	return auto_free(Inventory.new()) as Inventory
