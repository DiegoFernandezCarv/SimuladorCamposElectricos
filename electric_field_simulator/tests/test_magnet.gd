class_name TestMagnet
extends RefCounted

## Pruebas del campo magnético (polos, hilos) y de los objetos rígidos.
## Se llaman desde tu runner:  TestMagnet.run_all()  -> true si TODAS pasan.

const TOLERANCE_PCT: float = 0.1   # el modelo de 2 polos difiere del dipolo ideal ~0.005 % a r = 100·L

static func run_all() -> bool:
	var results: Array = [
		test_single_pole(),
		test_dipole_on_axis(),
		test_dipole_equatorial(),
		test_axis_to_equator_ratio(),
		test_rotated_magnet(),
		test_translated_magnet(),
		test_magnet_has_no_net_pole(),
		test_magnetic_moment(),
		test_current_wire(),
		test_rigid_electric_dipole(),
		test_magnetic_lines(),
	]
	var all_ok: bool = not results.has(false)
	print("TestMagnet: ", "TODAS PASARON" if all_ok else "HAY FALLAS")
	return all_ok

## Un polo norte de 1 A·m a r = 2 m: B = 1e-7 · 1 / 4 = 2.5e-8 T, alejándose del polo.
static func test_single_pole() -> bool:
	var pole: MagneticPole = MagneticPole.new(Vector2.ZERO, 1.0)
	var b: Vector2 = pole.field_at(Vector2(2, 0))
	var ok: bool = _close(b.length(), 2.5e-8) and b.x > 0.0 and abs(b.y) < 1e-20
	_report("polo norte aislado (esperado 2.5e-8 T, obtenido %s T)" % str(b.length()), ok)
	return ok

## Imán L = 0.01 m, qm = 1 A·m (m = 0.01 A·m²). Sobre el eje a r = 1 m:
## B ≈ (μ0/4π)·2m/r³ = 2e-9 T, apuntando de S a N (+X).
static func test_dipole_on_axis() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2.ZERO, 0.01, 1.0)
	var b: Vector2 = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(1, 0))
	var expected: float = 2.0 * MagneticFieldEngine.MU0_OVER_4PI * 0.01 / 1.0
	var ok: bool = _close(b.x, expected) and abs(b.y) < 1e-15
	_report("dipolo sobre el eje (esperado %s T, obtenido %s T)" % [str(expected), str(b.x)], ok)
	return ok

## En el plano ecuatorial a r = 1 m: B ≈ (μ0/4π)·m/r³ = 1e-9 T, en sentido CONTRARIO al momento (-X).
static func test_dipole_equatorial() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2.ZERO, 0.01, 1.0)
	var b: Vector2 = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(0, 1))
	var expected: float = MagneticFieldEngine.MU0_OVER_4PI * 0.01 / 1.0
	var ok: bool = _close(b.length(), expected) and b.x < 0.0 and abs(b.y) < 1e-15
	_report("dipolo en el ecuador (esperado %s T, obtenido %s T)" % [str(expected), str(b.length())], ok)
	return ok

## Validación para la feria: lejos del imán, B_eje / B_ecuador = 2 a la misma distancia.
static func test_axis_to_equator_ratio() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2.ZERO, 0.01, 1.0)
	var b_axis: float = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(1, 0)).length()
	var b_eq: float = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(0, 1)).length()
	var ok: bool = _close(b_axis / b_eq, 2.0)
	_report("razón B_eje / B_ecuador = 2 (obtenido %s)" % str(b_axis / b_eq), ok)
	return ok

## Rotar el imán 90° debe dar el mismo campo sobre SU eje, ahora en +Y.
static func test_rotated_magnet() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2.ZERO, 0.01, 1.0)
	magnet.rotate_by(PI / 2.0)
	var b: Vector2 = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(0, 1))
	var expected: float = 2.0 * MagneticFieldEngine.MU0_OVER_4PI * 0.01
	var ok: bool = _close(b.y, expected) and abs(b.x) < 1e-12
	_report("imán rotado 90° (esperado By = %s T, obtenido %s T)" % [str(expected), str(b.y)], ok)
	return ok

## Mover el imán y el punto de medición la misma cantidad no cambia el campo.
static func test_translated_magnet() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2.ZERO, 0.4, 2.0, 0.7)
	var before: Vector2 = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(1.2, 0.5))
	var shift: Vector2 = Vector2(3.0, -2.0)
	magnet.translate_by(shift)
	var after: Vector2 = MagneticFieldEngine.total_field(magnet.world_poles(), Vector2(1.2, 0.5) + shift)
	var ok: bool = _close(after.x, before.x) and _close(after.y, before.y)
	_report("traslación rígida conserva el campo relativo", ok)
	return ok

## No existen monopolos: la suma de intensidades de polo de un imán es 0.
static func test_magnet_has_no_net_pole() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2(1, 1), 0.3, 5.0, 1.1)
	var ok: bool = abs(magnet.net_pole_strength()) < 1e-12 and magnet.world_poles().size() == 2
	_report("el imán no tiene polo neto (2 polos, suma = 0)", ok)
	return ok

## m = qm · L, de S a N. Con L = 0.2, qm = 3, ángulo 90°: m = (0, 0.6).
static func test_magnetic_moment() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2(4, -1), 0.2, 3.0, PI / 2.0)
	var m: Vector2 = magnet.magnetic_moment()
	var ok: bool = _close(m.y, 0.6) and abs(m.x) < 1e-12
	_report("momento dipolar m = qm·L (esperado (0, 0.6), obtenido %s)" % str(m), ok)
	return ok

## Hilo de I = 10 A a r = 0.5 m: B = 2e-7 · 10 / 0.5 = 4e-6 T.
## Con I saliendo de la pantalla, en (0.5, 0) el campo apunta a +Y (antihorario).
static func test_current_wire() -> bool:
	var wire: CurrentWire = CurrentWire.new(Vector2.ZERO, 10.0)
	var b: Vector2 = wire.field_at(Vector2(0.5, 0))
	var ok: bool = _close(b.length(), 4.0e-6) and b.y > 0.0 and abs(b.x) < 1e-15
	_report("hilo con corriente (esperado 4e-6 T, obtenido %s T)" % str(b.length()), ok)
	return ok

## Un dipolo eléctrico rígido genera las mismas cargas que dos Charge sueltas,
## y al rotarlo 90° la carga positiva pasa de +X a +Y.
static func test_rigid_electric_dipole() -> bool:
	var obj: RigidObject = RigidObject.make_electric_dipole(Vector2.ZERO, 2.0, 1e-6)
	var charges: Array = obj.world_charges()
	var free: Array = [Charge.new(Vector2(1, 0), 1e-6), Charge.new(Vector2(-1, 0), -1e-6)]
	var e_obj: Vector2 = ElectricFieldEngine.total_field(charges, Vector2(0, 3))
	var e_free: Vector2 = ElectricFieldEngine.total_field(free, Vector2(0, 3))
	var same: bool = _close(e_obj.x, e_free.x) and _close(e_obj.y, e_free.y)

	obj.rotate_by(PI / 2.0)
	var pos_charge: Charge = charges[0]
	var rotated_ok: bool = pos_charge.position.distance_to(Vector2(0, 1)) < 1e-9 and abs(obj.net_charge()) < 1e-18

	var ok: bool = same and rotated_ok
	_report("dipolo eléctrico rígido (campo igual a cargas libres, rotación correcta)", ok)
	return ok

## Líneas de campo magnético: salen 16 del polo N, y la que sale hacia el polo S
## (ángulo 180°, a lo largo del eje) termina absorbida a menos de 0.12 m de él.
static func test_magnetic_lines() -> bool:
	var magnet: RigidObject = RigidObject.make_magnet(Vector2.ZERO, 1.0, 5.0)
	var bounds: Rect2 = Rect2(-20, -20, 40, 40)
	var lines: Array = FieldLineGenerator.generate_magnetic_lines(magnet.world_poles(), bounds)
	var ok: bool = lines.size() == FieldLineGenerator.LINES_PER_CHARGE
	if ok:
		var axis_line: PackedVector2Array = lines[FieldLineGenerator.LINES_PER_CHARGE / 2]
		var end: Vector2 = axis_line[axis_line.size() - 1]
		ok = end.distance_to(Vector2(-0.5, 0.0)) < FieldLineGenerator.ABSORB_RADIUS
	_report("líneas de campo magnético (16 desde el polo N, la del eje termina en el S)", ok)
	return ok

# ---------- utilidades ----------

## Error porcentual menor que la tolerancia (mismo criterio que test_stats.gd).
static func _close(obtained: float, expected: float) -> bool:
	if expected == 0.0:
		return abs(obtained) < 1e-12
	return abs(obtained - expected) / abs(expected) * 100.0 < TOLERANCE_PCT

static func _report(name: String, ok: bool) -> void:
	print("  [", "OK" if ok else "FALLA", "] ", name)
