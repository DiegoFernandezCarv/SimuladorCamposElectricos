class_name TestConductors
extends RefCounted

## Pruebas de formas cargadas y conductores a tierra (método de imágenes).
## Se llama desde cualquier runner:  TestConductors.run_all()  -> true si TODAS pasan.

const TOLERANCE_PCT: float = 0.01   # error porcentual máximo permitido
const K: float = PhysicsConstants.K

static func run_all() -> bool:
	var results: Array = [
		test_rod_matches_line_charge(),
		test_ring_center_and_far_field(),
		test_rod_pair_is_neutral(),
		test_plane_image_and_field(),
		test_plane_rotated_image(),
		test_plane_potential_zero_and_shield(),
		test_plane_force_on_charge(),
		test_sphere_image(),
		test_sphere_potential_zero(),
		test_sphere_force_and_shield(),
	]
	var all_ok: bool = not results.has(false)
	print("TestConductors: ", "TODAS PASARON" if all_ok else "HAY FALLAS")
	return all_ok

## Varilla de 2 m con 2 µC. En la mediatriz a d = 0.5 m, la teoría del hilo finito da
## E = k·λ·L / (d·sqrt(d² + L²/4)), con λ = Q/L.
static func test_rod_matches_line_charge() -> bool:
	var rod: Array = ChargedShapes.make_rod(Vector2.ZERO, 2.0, 0.0, 2e-6, 100)
	var e: Vector2 = ElectricFieldEngine.total_field(rod, Vector2(0.0, 0.5))
	var lam: float = 2e-6 / 2.0
	var expected: float = K * lam * 2.0 / (0.5 * sqrt(0.5 * 0.5 + 1.0))
	var ok: bool = _close(e.y, expected) and abs(e.x) < 1e-6 * expected
	_report("varilla = hilo finito (esperado %s N/C, obtenido %s)" % [str(expected), str(e.y)], ok)
	return ok

## Anillo de 3 µC y R = 1 m: en el centro E = 0 por simetría, y lejos se ve como una carga puntual.
static func test_ring_center_and_far_field() -> bool:
	var ring: Array = ChargedShapes.make_ring(Vector2.ZERO, 1.0, 3e-6, 36)
	var e_center: Vector2 = ElectricFieldEngine.total_field(ring, Vector2.ZERO)
	var e_far: Vector2 = ElectricFieldEngine.total_field(ring, Vector2(200.0, 0.0))
	var expected_far: float = K * 3e-6 / (200.0 * 200.0)
	var ok: bool = e_center.length() < 1e-3 and _close(e_far.x, expected_far)
	_report("anillo: E(centro) = 0 y campo lejano de carga puntual", ok)
	return ok

## Las dos varillas paralelas suman carga neta cero (+Q y -Q).
static func test_rod_pair_is_neutral() -> bool:
	var pair: Array = ChargedShapes.make_rod_pair(Vector2.ZERO, 2.0, 0.5, 0.0, 1e-6, 20)
	var total: float = 0.0
	for c in pair:
		total += c.q
	var ok: bool = abs(total) < 1e-18 and pair.size() == 40
	_report("varillas paralelas: carga neta 0", ok)
	return ok

## Plano en x = 0 (lado libre +x), carga +1 µC en (1,0). Imagen: -1 µC en (-1,0).
## En (0.5, 0): E = -k·q/0.25 - k·q/2.25 (ambos términos apuntan a -x).
static func test_plane_image_and_field() -> bool:
	var plane: ConductorPlane = ConductorPlane.new(Vector2.ZERO, Vector2.RIGHT)
	var charge: Charge = Charge.new(Vector2(1.0, 0.0), 1e-6)
	var img: Charge = plane.image_for(charge)
	var e: Vector2 = InducedSystem.field_at([charge], [plane], Vector2(0.5, 0.0))
	var expected: float = -K * 1e-6 / 0.25 - K * 1e-6 / 2.25
	var ok: bool = img != null and img.position.is_equal_approx(Vector2(-1.0, 0.0)) \
		and _close(img.q, -1e-6) and _close(e.x, expected)
	_report("plano: imagen en (-1,0) con -q y campo en (0.5,0)", ok)
	return ok

## Plano horizontal en y = 2 (lado libre +y), carga en (0,5): imagen en (0,-1).
## Ojo: en Godot Vector2.UP es (0,-1); aquí se usa (0,1) porque el mundo físico crece hacia arriba.
static func test_plane_rotated_image() -> bool:
	var plane: ConductorPlane = ConductorPlane.new(Vector2(0.0, 2.0), Vector2(0.0, 1.0))
	var charge: Charge = Charge.new(Vector2(0.0, 5.0), 2e-6)
	var img: Charge = plane.image_for(charge)
	var ok: bool = img != null and img.position.is_equal_approx(Vector2(0.0, -1.0)) and _close(img.q, -2e-6)
	_report("plano horizontal: imagen en (0,-1)", ok)
	return ok

## V = 0 sobre el plano, y E = 0 dentro del metal (apantallamiento).
static func test_plane_potential_zero_and_shield() -> bool:
	var plane: ConductorPlane = ConductorPlane.new(Vector2.ZERO, Vector2.RIGHT)
	var charge: Charge = Charge.new(Vector2(1.0, 0.0), 1e-6)
	# Un poco dentro del lado libre, casi sobre la superficie: V ~ 0 respecto a kq/r (~9000 V).
	var v_surface: float = ElectricFieldEngine.total_potential(InducedSystem.sources([charge], [plane]), Vector2(0.0, 0.7))
	var e_inside: Vector2 = InducedSystem.field_at([charge], [plane], Vector2(-0.5, 0.3))
	var ok: bool = abs(v_surface) < 1e-6 and e_inside == Vector2.ZERO
	_report("plano: V = 0 sobre la superficie y E = 0 dentro del metal", ok)
	return ok

## La carga es atraída por su imagen: F = k·q² / (2d)² = 2.247e-3 N hacia el plano (d = 1 m).
static func test_plane_force_on_charge() -> bool:
	var plane: ConductorPlane = ConductorPlane.new(Vector2.ZERO, Vector2.RIGHT)
	var charge: Charge = Charge.new(Vector2(1.0, 0.0), 1e-6)
	var f: Vector2 = InducedSystem.force_on_charge(charge, [charge], [plane])
	var expected: float = K * 1e-6 * 1e-6 / 4.0
	var ok: bool = _close(f.x, -expected) and abs(f.y) < 1e-12
	_report("plano: fuerza de atracción a su imagen (esperado %s N)" % str(expected), ok)
	return ok

## Esfera R = 1 en el origen, carga q en (3,0): q' = -q/3 en (1/3, 0).
static func test_sphere_image() -> bool:
	var sphere: ConductorSphere = ConductorSphere.new(Vector2.ZERO, 1.0)
	var charge: Charge = Charge.new(Vector2(3.0, 0.0), 1e-6)
	var img: Charge = sphere.image_for(charge)
	var ok: bool = img != null and img.position.is_equal_approx(Vector2(1.0 / 3.0, 0.0)) \
		and _close(img.q, -1e-6 / 3.0)
	_report("esfera: q' = -qR/d en R²/d", ok)
	return ok

## V = 0 sobre toda la superficie (se prueba en 3 ángulos). Escala natural: kq/R ≈ 9000 V.
## Vector2 usa float de 32 bits, así que se tolera 1e-5 de esa escala (~0.09 V), no 1e-6 V.
static func test_sphere_potential_zero() -> bool:
	var sphere: ConductorSphere = ConductorSphere.new(Vector2.ZERO, 1.0)
	var charge: Charge = Charge.new(Vector2(3.0, 0.0), 1e-6)
	var srcs: Array = InducedSystem.sources([charge], [sphere])
	var ok: bool = true
	for deg in [0.0, 60.0, 150.0]:
		var p: Vector2 = Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))
		ok = ok and abs(ElectricFieldEngine.total_potential(srcs, p)) < 1e-5 * (K * 1e-6 / 1.0)
	_report("esfera: V = 0 en la superficie (0°, 60°, 150°)", ok)
	return ok

## Fuerza sobre q por la esfera: F = k·q·q' / (d - R²/d)² (atracción) y E = 0 dentro.
static func test_sphere_force_and_shield() -> bool:
	var sphere: ConductorSphere = ConductorSphere.new(Vector2.ZERO, 1.0)
	var charge: Charge = Charge.new(Vector2(3.0, 0.0), 1e-6)
	var f: Vector2 = InducedSystem.force_on_charge(charge, [charge], [sphere])
	var d_img: float = 3.0 - 1.0 / 3.0
	var expected: float = K * 1e-6 * (-1e-6 / 3.0) / (d_img * d_img)   # negativo: hacia la esfera
	var e_in: Vector2 = InducedSystem.field_at([charge], [sphere], Vector2(0.2, 0.1))
	var ok: bool = _close(f.x, expected) and e_in == Vector2.ZERO
	_report("esfera: fuerza de atracción (esperado %s N) y E = 0 dentro" % str(expected), ok)
	return ok

# ---------- utilidades ----------
static func _close(obtained: float, expected: float) -> bool:
	if expected == 0.0:
		return abs(obtained) < 1e-12
	return abs(obtained - expected) / abs(expected) * 100.0 < TOLERANCE_PCT

static func _report(name: String, ok: bool) -> void:
	print("  [", "OK" if ok else "FALLA", "] ", name)
