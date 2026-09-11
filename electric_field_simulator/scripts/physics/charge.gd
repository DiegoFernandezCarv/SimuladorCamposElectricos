class_name Charge
extends RefCounted

## Posición en METROS (coordenadas del "mundo físico", no de pantalla)
var position: Vector2

## Valor de la carga en COULOMBS, con signo (positivo o negativo)
var q: float

func _init(pos: Vector2, charge_value: float) -> void:
	position = pos
	q = charge_value

## Campo eléctrico (vector) que ESTA carga produce en un punto dado.
## Implementa la sección 7 del documento: E = k(q/r²) * r_hat
func field_at(point: Vector2) -> Vector2:
	var delta: Vector2 = point - position
	var r: float = delta.length()

	# Manejo de errores (sección 39): evita división por cero
	if r < 1e-9:
		return Vector2.ZERO

	var r_hat: Vector2 = delta / r
	var magnitude: float = PhysicsConstants.K * q / (r * r)
	return r_hat * magnitude

## Potencial eléctrico que esta carga produce en un punto (sección 17): V = kq/r
func potential_at(point: Vector2) -> float:
	var r: float = point.distance_to(position)
	if r < 1e-9:
		return INF if q > 0.0 else -INF
	return PhysicsConstants.K * q / r
