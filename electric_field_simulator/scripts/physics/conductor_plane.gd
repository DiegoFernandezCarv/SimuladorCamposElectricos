class_name ConductorPlane
extends RefCounted

## Plano conductor a tierra (potencial 0), resuelto con el MÉTODO DE IMÁGENES.
## Cada carga q del lado libre induce cargas en el metal; su efecto fuera del
## conductor es idéntico al de una carga imagen -q en el punto espejo.
## El conductor ocupa el semiespacio opuesto a la normal; el campo ahí es 0.

const EPS: float = 1e-9

## Un punto cualquiera del plano (m).
var point: Vector2
## Vector unitario que apunta hacia el lado LIBRE (donde están las cargas).
var normal: Vector2

func _init(plane_point: Vector2, free_side_normal: Vector2) -> void:
	point = plane_point
	normal = free_side_normal.normalized()

## Distancia con signo al plano: positiva en el lado libre, negativa dentro del metal.
func signed_distance(p: Vector2) -> float:
	return (p - point).dot(normal)

## true si el punto está dentro del conductor (o sobre su superficie).
func contains(p: Vector2) -> bool:
	return signed_distance(p) <= EPS

## Imagen de una carga: signo opuesto, posición espejo.
## Devuelve null si la carga está dentro del conductor.
func image_for(charge: Charge) -> Charge:
	var d: float = signed_distance(charge.position)
	if d <= EPS:
		return null
	return Charge.new(charge.position - normal * (2.0 * d), -charge.q)

func translate_by(delta: Vector2) -> void:
	point += delta

## Gira el plano alrededor de un pivote (radianes).
func rotate_about(pivot: Vector2, angle_rad: float) -> void:
	point = pivot + (point - pivot).rotated(angle_rad)
	normal = normal.rotated(angle_rad)
