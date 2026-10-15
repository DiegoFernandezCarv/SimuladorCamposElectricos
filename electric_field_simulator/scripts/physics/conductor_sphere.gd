class_name ConductorSphere
extends RefCounted

## Esfera conductora a tierra (potencial 0), resuelta con el MÉTODO DE IMÁGENES.
## Una carga q a distancia d > R del centro tiene como imagen una carga
##     q' = -q·R/d   situada a R²/d del centro, sobre la recta centro-carga.
## Dentro de la esfera el campo es 0 (apantallamiento).
## En el plano de la pantalla se dibuja como un círculo: es el corte de la esfera.

const EPS: float = 1e-9

var center: Vector2
var radius: float

func _init(sphere_center: Vector2, sphere_radius: float) -> void:
	center = sphere_center
	radius = sphere_radius

## true si el punto está dentro de la esfera (o sobre su superficie).
func contains(p: Vector2) -> bool:
	return p.distance_to(center) <= radius + EPS

## Imagen de una carga. Devuelve null si la carga está dentro de la esfera.
func image_for(charge: Charge) -> Charge:
	var offset: Vector2 = charge.position - center
	var d: float = offset.length()
	if d <= radius + EPS:
		return null
	var image_q: float = -charge.q * radius / d
	var image_pos: Vector2 = center + offset * (radius * radius / (d * d))
	return Charge.new(image_pos, image_q)

func translate_by(delta: Vector2) -> void:
	center += delta
