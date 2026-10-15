class_name CurrentWire
extends RefCounted

## Hilo recto e infinito con corriente, perpendicular a la pantalla (la pantalla es un corte 2D).
## Campo de Biot-Savart / Ampère:  B = μ0·I / (2π·r), tangente a círculos centrados en el hilo.
## current > 0: la corriente SALE de la pantalla (hacia quien mira) y B gira en sentido antihorario.
## current < 0: la corriente ENTRA a la pantalla y B gira en sentido horario.

const MU0: float = 4.0e-7 * PI          # permeabilidad del vacío (T·m/A)
const MIN_DISTANCE_M: float = 0.03      # cerca del hilo se limita r para que B no explote

var position: Vector2
var current: float                      # A, con signo

func _init(p: Vector2 = Vector2.ZERO, amps: float = 1.0) -> void:
	position = p
	current = amps

## Campo magnético (T) que produce este hilo en un punto del mundo (m).
func field_at(world_pos: Vector2) -> Vector2:
	var d: Vector2 = world_pos - position
	var dist: float = d.length()
	if dist < 1.0e-9:
		return Vector2.ZERO
	var magnitude: float = MU0 * current / (TAU * maxf(dist, MIN_DISTANCE_M))
	return Vector2(-d.y, d.x) / dist * magnitude

## B (T) a 1 m del hilo: útil para el inspector.
func field_at_one_meter() -> float:
	return MU0 * absf(current) / TAU
