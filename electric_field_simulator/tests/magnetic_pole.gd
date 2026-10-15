class_name MagneticPole
extends RefCounted

## Posición en METROS (coordenadas del mundo físico)
var position: Vector2

## Intensidad del polo en A·m, con signo: positivo = polo NORTE, negativo = polo SUR.
var strength: float

func _init(pos: Vector2, pole_strength: float) -> void:
	position = pos
	strength = pole_strength

## Campo magnético que ESTE polo produce en un punto.
## Modelo de polos: B = (μ0/4π) · qm / r² · r_hat  (matemáticamente igual a Coulomb).
## Fuera de un imán real coincide con el campo del dipolo; dentro NO es fiel.
func field_at(point: Vector2) -> Vector2:
	var delta: Vector2 = point - position
	var r: float = delta.length()
	if r < 1e-9:
		return Vector2.ZERO
	var r_hat: Vector2 = delta / r
	return r_hat * (MagneticFieldEngine.MU0_OVER_4PI * strength / (r * r))
