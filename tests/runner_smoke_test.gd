extends GdUnitTestSuite

## Suite mínima que no prueba nada del juego: prueba que el runner de gdUnit4
## arranca, descubre esta suite y reporta pass/fail desde línea de comandos.
##
## Existe porque hasta acá el proyecto no tenía tests headless, y "el comando de
## tests no corre" fue un pendiente durante dos milestones
## (docs/retrospectiva-v0.2.md → §2.3). Sin una suite trivial que pase, un fallo
## del primer test de verdad no distingue entre "el código está mal" y "el runner
## no arranca".
##
## Se puede borrar el día que haya suites de verdad que cumplan la misma función.
## El nombre va como *_test.gd y no test_*.gd a propósito: el McpTestSuite del MCP
## godot-ai descubre por el prefijo contrario (docs/plan.md → v0.3).


func test_el_runner_arranca_y_reporta() -> void:
	assert_int(2 + 2).is_equal(4)


func test_el_tipado_estatico_llega_a_los_asserts() -> void:
	var stacks: Array[String] = ["backpack", "water_bottle"]
	assert_array(stacks).has_size(2)
