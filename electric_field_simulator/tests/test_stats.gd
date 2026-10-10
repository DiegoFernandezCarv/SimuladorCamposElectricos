class_name TestChargeStats
extends RefCounted

## Pruebas de las estadísticas de carga seleccionada (una o varias) y de la exclusión
## de la propia carga. Se pueden llamar desde cualquier runner:  TestChargeStats.run_all()
## Devuelve true si TODAS pasan.

const TOLERANCE_PCT: float = 0.01  # error porcentual máximo permitido

static func run_all() -> bool:
	var results: Array = [
		test_force_between_opposite_charges(),
		test_newton_third_law(),
		test_own_charge_is_excluded(),
		test_group_summary(),
		test_single_energy(),
		test_group_external_force(),
		test_group_internal_force_is_zero(),
		test_group_internal_energy(),
		test_group_energy_with_rest(),
	]
	var all_ok: bool = not results.has(false)
	print("TestChargeStats: ", "TODAS PASARON" if all_ok else "HAY FALLAS")
	return all_ok

## +1 µC en (0,0) y -1 µC en (2,0): F = k·q²/r² = 2.247e-3 N, atractiva.
## La fuerza sobre la carga en el origen debe apuntar hacia +x (hacia la otra).
static func test_force_between_opposite_charges() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(2, 0), -1e-6)
	var rows: Array = ChargeStats.rows_for([a], [a, b])

	var expected: float = PhysicsConstants.K * 1e-6 * 1e-6 / (2.0 * 2.0)
	var f_mag: float = _value(rows, ChargeStats.LBL_FMAG)
	var fx: float = _value(rows, ChargeStats.LBL_FX)
	var fy: float = _value(rows, ChargeStats.LBL_FY)

	var ok: bool = _close(f_mag, expected) and fx > 0.0 and abs(fy) < 1e-12
	_report("fuerza entre cargas opuestas (esperado %s N, obtenido %s N)" % [str(expected), str(f_mag)], ok)
	return ok

## Tercera ley de Newton: la fuerza sobre A es igual y opuesta a la fuerza sobre B.
static func test_newton_third_law() -> bool:
	var a: Charge = Charge.new(Vector2(-1, 0.5), 2e-6)
	var b: Charge = Charge.new(Vector2(1.5, -0.7), -3e-6)
	var rows_a: Array = ChargeStats.rows_for([a], [a, b])
	var rows_b: Array = ChargeStats.rows_for([b], [a, b])

	var ok: bool = _close(_value(rows_a, ChargeStats.LBL_FX), -_value(rows_b, ChargeStats.LBL_FX)) \
		and _close(_value(rows_a, ChargeStats.LBL_FY), -_value(rows_b, ChargeStats.LBL_FY))
	_report("tercera ley de Newton (F_A = -F_B)", ok)
	return ok

## Una carga sola no siente fuerza ni campo de sí misma, y el potencial NO es infinito.
static func test_own_charge_is_excluded() -> bool:
	var a: Charge = Charge.new(Vector2(1, 1), 1e-6)
	var rows: Array = ChargeStats.rows_for([a], [a])

	var ok: bool = _value(rows, ChargeStats.LBL_EMAG) == 0.0 \
		and _value(rows, ChargeStats.LBL_FMAG) == 0.0 \
		and _value(rows, ChargeStats.LBL_V) == 0.0 \
		and _value(rows, ChargeStats.LBL_U) == 0.0 \
		and is_nan(_value(rows, ChargeStats.LBL_ANGLE))
	_report("la carga ignora su propio campo y potencial", ok)
	return ok

## Resumen de selección múltiple: con TODAS las cargas seleccionadas no hay fuerza externa.
static func test_group_summary() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(1, 0), -3e-6)
	var rows: Array = ChargeStats.rows_for([a, b], [a, b])

	var ok: bool = _close(_value(rows, ChargeStats.LBL_COUNT), 2.0) \
		and _close(_value(rows, ChargeStats.LBL_QTOTAL), -2.0) \
		and _value(rows, ChargeStats.LBL_FMAG) == 0.0
	_report("resumen de selección múltiple (2 cargas, total -2 µC, sin fuerza externa)", ok)
	return ok

## Energía de una carga: U = q·V. Con +1 µC en (0,0) y -1 µC en (2,0):
## V sobre la positiva = k·(-1e-6)/2, así que U = -k·q²/r = -4.494e-3 J.
static func test_single_energy() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(2, 0), -1e-6)
	var rows: Array = ChargeStats.rows_for([a], [a, b])

	var expected: float = -PhysicsConstants.K * 1e-6 * 1e-6 / 2.0
	var got: float = _value(rows, ChargeStats.LBL_U)
	var ok: bool = _close(got, expected)
	_report("energía de una carga U = qV (esperado %s J, obtenido %s J)" % [str(expected), str(got)], ok)
	return ok

## Grupo {A(+1 µC en 0), B(-1 µC en 2)} y una carga externa C(+2 µC en 5), todo sobre el eje x.
##   A es repelida por C (hacia -x):  -k·qA·qC/5²
##   B es atraída por C (hacia +x):   +k·|qB|·qC/3²
## Fx = k·qC·1e-6·(1/9 - 1/25).  Las fuerzas entre A y B son internas y no cuentan.
static func test_group_external_force() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(2, 0), -1e-6)
	var c: Charge = Charge.new(Vector2(5, 0), 2e-6)
	var rows: Array = ChargeStats.rows_for([a, b], [a, b, c])

	var expected_fx: float = PhysicsConstants.K * 2e-6 * 1e-6 * (1.0 / 9.0 - 1.0 / 25.0)
	var got_fx: float = _value(rows, ChargeStats.LBL_FX)
	var ok: bool = _close(got_fx, expected_fx) and abs(_value(rows, ChargeStats.LBL_FY)) < 1e-12
	_report("fuerza externa sobre un grupo (esperado %s N, obtenido %s N)" % [str(expected_fx), str(got_fx)], ok)
	return ok

## Las fuerzas internas de un grupo se cancelan por pares (3ª ley): la suma debe ser 0.
static func test_group_internal_force_is_zero() -> bool:
	var a: Charge = Charge.new(Vector2(-1, 0.5), 2e-6)
	var b: Charge = Charge.new(Vector2(1.5, -0.7), -3e-6)
	var c: Charge = Charge.new(Vector2(0.3, 2.0), 1e-6)
	var d: Charge = Charge.new(Vector2(4, 4), 5e-6)   # externa: no debe afectar la suma interna
	var rows: Array = ChargeStats.rows_for([a, b, c], [a, b, c, d])

	var got: float = _value(rows, ChargeStats.LBL_F_INT)
	var ok: bool = got == 0.0
	_report("suma de fuerzas internas = 0 (obtenido %s N)" % str(got), ok)
	return ok

## Energía interna de {+1 µC en 0, -1 µC en 2}: U = k·q1·q2/r = -k·1e-12/2 = -4.494e-3 J.
static func test_group_internal_energy() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(2, 0), -1e-6)
	var rows: Array = ChargeStats.rows_for([a, b], [a, b])

	var expected: float = -PhysicsConstants.K * 1e-12 / 2.0
	var got: float = _value(rows, ChargeStats.LBL_U_INT)
	var ok: bool = _close(got, expected)
	_report("energía interna de un grupo (esperado %s J, obtenido %s J)" % [str(expected), str(got)], ok)
	return ok

## Energía del grupo {A(+1 µC en 0), B(-1 µC en 2)} con la carga externa C(+2 µC en 5):
## U_rest = k·qC·(qA/5 + qB/3) = k·2e-6·1e-6·(1/5 - 1/3).
static func test_group_energy_with_rest() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(2, 0), -1e-6)
	var c: Charge = Charge.new(Vector2(5, 0), 2e-6)
	var rows: Array = ChargeStats.rows_for([a, b], [a, b, c])

	var expected: float = PhysicsConstants.K * 2e-6 * 1e-6 * (1.0 / 5.0 - 1.0 / 3.0)
	var got: float = _value(rows, ChargeStats.LBL_U_REST)
	var ok: bool = _close(got, expected)
	_report("energía del grupo con el resto (esperado %s J, obtenido %s J)" % [str(expected), str(got)], ok)
	return ok

# ---------- utilidades ----------
static func _value(rows: Array, label: String) -> float:
	for row in rows:
		if row["label"] == label:
			return row["value"]
	push_error("Fila no encontrada: " + label)
	return NAN

## Error porcentual (sección 23 del documento) menor que la tolerancia.
static func _close(obtained: float, expected: float) -> bool:
	if expected == 0.0:
		return abs(obtained) < 1e-12
	return abs(obtained - expected) / abs(expected) * 100.0 < TOLERANCE_PCT

static func _report(name: String, ok: bool) -> void:
	print("  [", "OK" if ok else "FALLA", "] ", name)
