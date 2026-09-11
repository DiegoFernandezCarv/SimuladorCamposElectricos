class_name ElectricFieldEngine
extends RefCounted

## Campo eléctrico TOTAL en un punto: aplica el principio de superposición
## (sección 8 del documento): E_total = Σ Eᵢ
static func total_field(charges: Array, point: Vector2) -> Vector2:
	var e_total: Vector2 = Vector2.ZERO
	for charge in charges:
		e_total += charge.field_at(point)
	return e_total

## Potencial eléctrico total en un punto (sección 17): V_total = Σ kqᵢ/rᵢ
static func total_potential(charges: Array, point: Vector2) -> float:
	var v_total: float = 0.0
	for charge in charges:
		v_total += charge.potential_at(point)
	return v_total

## Fuerza sobre una carga de prueba q colocada en un campo E (sección 15): F = qE
static func force_on_charge(field: Vector2, test_q: float) -> Vector2:
	return field * test_q

## Aceleración de una carga de prueba de masa m (sección 15): a = qE/m
static func acceleration_on_charge(field: Vector2, test_q: float, mass: float) -> Vector2:
	if mass <= 0.0:
		return Vector2.ZERO
	return (field * test_q) / mass
