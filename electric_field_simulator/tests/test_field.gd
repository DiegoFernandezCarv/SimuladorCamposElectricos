extends Node
## Ejecuta las pruebas de validación descritas en las secciones 20-24 del documento.
##
## CÓMO CORRERLAS:
## 1. Crea una escena nueva (Scene > New Scene > Other Node > Node).
## 2. Adjúntale este script.
## 3. Guárdala como tests/TestRunner.tscn
## 4. Ábrela y presiona F6 ("Run Current Scene"). Verás los resultados en la consola (Output).

const TOLERANCE: float = 0.01  # 1% de error aceptado

var passed: int = 0
var failed: int = 0

func _ready() -> void:
	print("=== VALIDACIÓN DEL MOTOR FÍSICO ===\n")
	test_single_positive_charge()
	test_single_negative_charge()
	test_theoretical_value()
	test_distance_scaling()
	test_equal_charges_center()
	test_opposite_charges_center()
	test_superposition()
	print("\n=== RESULTADO: %d aprobadas, %d fallidas ===" % [passed, failed])

func _check(test_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[OK]   %s  -> %s" % [test_name, detail])
	else:
		failed += 1
		print("[FAIL] %s  -> %s" % [test_name, detail])

## Prueba 1 (sección 21): el campo de una carga positiva debe alejarse de ella
func test_single_positive_charge() -> void:
	var q: Charge = Charge.new(Vector2.ZERO, PhysicsConstants.MICRO)
	var field: Vector2 = q.field_at(Vector2(1, 0))
	_check("test_single_positive_charge", field.x > 0.0, "Ex = %.2f (debe ser > 0)" % field.x)

## Prueba 2 (sección 21): el campo de una carga negativa debe apuntar hacia ella
func test_single_negative_charge() -> void:
	var q: Charge = Charge.new(Vector2.ZERO, -PhysicsConstants.MICRO)
	var field: Vector2 = q.field_at(Vector2(1, 0))
	_check("test_single_negative_charge", field.x < 0.0, "Ex = %.2f (debe ser < 0)" % field.x)

## Validación mediante cálculo manual (sección 20): q=1µC, r=1m -> E ≈ 8987.55 N/C
func test_theoretical_value() -> void:
	var q: Charge = Charge.new(Vector2.ZERO, PhysicsConstants.MICRO)
	var field: Vector2 = q.field_at(Vector2(1, 0))
	var theoretical: float = PhysicsConstants.K * PhysicsConstants.MICRO / (1.0 * 1.0)
	var error: float = abs(field.length() - theoretical) / theoretical
	_check(
		"test_theoretical_value", error < TOLERANCE,
		"Teórico=%.2f Simulado=%.2f Error=%.4f%%" % [theoretical, field.length(), error * 100.0]
	)

## Validación de la ley del inverso del cuadrado (sección 22): E(2r) = E(r)/4
func test_distance_scaling() -> void:
	var q: Charge = Charge.new(Vector2.ZERO, PhysicsConstants.MICRO)
	var e1: float = q.field_at(Vector2(1, 0)).length()
	var e2: float = q.field_at(Vector2(2, 0)).length()
	var ratio: float = e2 / e1
	_check("test_distance_scaling", abs(ratio - 0.25) < TOLERANCE, "E(2r)/E(r) = %.4f (esperado 0.25)" % ratio)

## Prueba 3 (sección 21): dos cargas iguales -> campo cero en el punto central
func test_equal_charges_center() -> void:
	var charges: Array = [
		Charge.new(Vector2(-1, 0), PhysicsConstants.MICRO),
		Charge.new(Vector2(1, 0), PhysicsConstants.MICRO),
	]
	var field: Vector2 = ElectricFieldEngine.total_field(charges, Vector2.ZERO)
	_check("test_equal_charges_center", field.length() < 1e-3, "|E_total| = %.6f (debe ser ≈0)" % field.length())

## Prueba 4 (sección 21): cargas opuestas -> campo distinto de cero, apunta de + a -
func test_opposite_charges_center() -> void:
	var charges: Array = [
		Charge.new(Vector2(-1, 0), PhysicsConstants.MICRO),
		Charge.new(Vector2(1, 0), -PhysicsConstants.MICRO),
	]
	var field: Vector2 = ElectricFieldEngine.total_field(charges, Vector2.ZERO)
	_check(
		"test_opposite_charges_center",
		field.x > 0.0 and field.length() > 1e3,
		"Ex = %.2f, |E| = %.2f" % [field.x, field.length()]
	)

## Comprueba que la superposición (sección 8) sea una simple suma vectorial
func test_superposition() -> void:
	var c1: Charge = Charge.new(Vector2(-1, 0), PhysicsConstants.MICRO)
	var c2: Charge = Charge.new(Vector2(1, 0), 2.0 * PhysicsConstants.MICRO)
	var point: Vector2 = Vector2(0, 1)
	var manual_sum: Vector2 = c1.field_at(point) + c2.field_at(point)
	var engine_sum: Vector2 = ElectricFieldEngine.total_field([c1, c2], point)
	_check(
		"test_superposition",
		manual_sum.distance_to(engine_sum) < 1e-6,
		"Suma manual vs motor: distancia = %.9f" % manual_sum.distance_to(engine_sum)
	)
