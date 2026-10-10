class_name TestChargeStats
extends RefCounted

## Pruebas de las estadísticas de carga seleccionada y de la exclusión de la
## propia carga. Se pueden llamar desde cualquier runner:  TestChargeStats.run_all()
## Devuelve true si TODAS pasan.

const TOLERANCE_PCT: float = 0.01  # error porcentual máximo permitido

static func run_all() -> bool:
	var results: Array = [
		test_force_between_opposite_charges(),
		test_newton_third_law(),
		test_own_charge_is_excluded(),
		test_group_summary(),
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
	var f_mag: float = _value(rows, "|F|")
	var fx: float = _value(rows, "Fx")
	var fy: float = _value(rows, "Fy")

	var ok: bool = _close(f_mag, expected) and fx > 0.0 and abs(fy) < 1e-12
	_report("fuerza entre cargas opuestas (esperado %s N, obtenido %s N)" % [str(expected), str(f_mag)], ok)
	return ok

## Tercera ley de Newton: la fuerza sobre A es igual y opuesta a la fuerza sobre B.
static func test_newton_third_law() -> bool:
	var a: Charge = Charge.new(Vector2(-1, 0.5), 2e-6)
	var b: Charge = Charge.new(Vector2(1.5, -0.7), -3e-6)
	var rows_a: Array = ChargeStats.rows_for([a], [a, b])
	var rows_b: Array = ChargeStats.rows_for([b], [a, b])

	var ok: bool = _close(_value(rows_a, "Fx"), -_value(rows_b, "Fx")) \
		and _close(_value(rows_a, "Fy"), -_value(rows_b, "Fy"))
	_report("tercera ley de Newton (F_A = -F_B)", ok)
	return ok

## Una carga sola no siente fuerza ni campo de sí misma, y el potencial NO es infinito.
static func test_own_charge_is_excluded() -> bool:
	var a: Charge = Charge.new(Vector2(1, 1), 1e-6)
	var rows: Array = ChargeStats.rows_for([a], [a])

	var ok: bool = _value(rows, "|E|") == 0.0 \
		and _value(rows, "|F|") == 0.0 \
		and _value(rows, "V") == 0.0 \
		and is_nan(_value(rows, "Ángulo de F (desde +X)"))
	_report("la carga ignora su propio campo y potencial", ok)
	return ok

static func test_group_summary() -> bool:
	var a: Charge = Charge.new(Vector2(0, 0), 1e-6)
	var b: Charge = Charge.new(Vector2(1, 0), -3e-6)
	var rows: Array = ChargeStats.rows_for([a, b], [a, b])

	var ok: bool = _close(_value(rows, "Cargas"), 2.0) and _close(_value(rows, "Carga total"), -2.0)
	_report("resumen de selección múltiple (2 cargas, total -2 µC)", ok)
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
