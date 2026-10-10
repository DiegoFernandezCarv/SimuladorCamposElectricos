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

## Igual que total_field, pero IGNORANDO las cargas indicadas en `excluded`.
## Sirve para calcular el campo que "sienten" una o varias cargas debido a las
## DEMÁS (una carga no se ejerce fuerza a sí misma).
static func field_excluding(charges: Array, point: Vector2, excluded: Array) -> Vector2:
	var e_total: Vector2 = Vector2.ZERO
	for charge in charges:
		if excluded.has(charge):
			continue
		e_total += charge.field_at(point)
	return e_total

## Igual que total_potential, pero ignorando las cargas indicadas en `excluded`.
## IMPORTANTE: es necesario excluir la propia carga, porque potential_at devuelve
## infinito cuando el punto coincide con la posición de la carga.
static func potential_excluding(charges: Array, point: Vector2, excluded: Array) -> float:
	var v_total: float = 0.0
	for charge in charges:
		if excluded.has(charge):
			continue
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
