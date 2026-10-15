class_name MagneticCompass
extends RefCounted

## Brújula: una aguja pequeña que se alinea con el campo magnético local B.
## La punta NORTE (roja) apunta en la dirección de B. Si B es casi cero no hay dirección.

const MIN_FIELD_T: float = 1.0e-12      # por debajo de esto se considera que no hay campo
const FOLLOW_RATE: float = 10.0         # qué tan rápido gira la aguja hacia el campo (1/s)

var position: Vector2
var angle: float = PI / 2.0             # ángulo de la aguja en el mundo (rad, 0 = +X); por defecto hacia arriba
var has_field: bool = false

func _init(p: Vector2 = Vector2.ZERO) -> void:
	position = p

## Gira la aguja hacia B con un poco de inercia visual (delta en segundos).
func follow(b: Vector2, delta: float) -> void:
	has_field = b.length() > MIN_FIELD_T
	if has_field:
		angle = lerp_angle(angle, b.angle(), 1.0 - exp(-FOLLOW_RATE * delta))

## Pone la aguja de golpe en la dirección de B (sin animación).
func snap(b: Vector2) -> void:
	has_field = b.length() > MIN_FIELD_T
	if has_field:
		angle = b.angle()
