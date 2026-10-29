class_name ChargedShapes
extends RefCounted

## Formas con carga repartida, hechas de cargas puntuales (objetos Charge).
## Como devuelven Charge normales, el motor eléctrico, las líneas de campo y el
## inspector funcionan igual que con cargas sueltas. Cada forma es un conjunto
## de cargas con posiciones fijas; para moverla, mueve todas el mismo delta.
##
## Modelo: el plano de la pantalla es un corte de un mundo 3D con ley 1/r².
## Una varilla es entonces un hilo cargado en 3D visto desde el plano que lo contiene.

const MIN_POINTS: int = 2

## Varilla cargada uniforme: n cargas iguales (método del punto medio).
## center en m, length en m, angle_rad respecto a +X, total_q en C.
static func make_rod(center: Vector2, length: float, angle_rad: float, total_q: float, n: int = 40) -> Array:
	var out: Array = []
	var count: int = maxi(n, MIN_POINTS)
	var axis: Vector2 = Vector2.RIGHT.rotated(angle_rad)
	for i in range(count):
		var s: float = -length / 2.0 + (float(i) + 0.5) * length / float(count)
		out.append(Charge.new(center + axis * s, total_q / float(count)))
	return out

## Anillo cargado uniforme en el plano: n cargas iguales sobre la circunferencia.
static func make_ring(center: Vector2, radius: float, total_q: float, n: int = 36) -> Array:
	var out: Array = []
	var count: int = maxi(n, MIN_POINTS)
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		out.append(Charge.new(center + Vector2(cos(a), sin(a)) * radius, total_q / float(count)))
	return out

## Dos varillas paralelas con cargas +Q y -Q (versión "capacitor" del corte).
## separation es la distancia entre varillas; el eje de la pareja forma angle_rad con +X.
static func make_rod_pair(center: Vector2, length: float, separation: float, angle_rad: float, total_q: float, n: int = 40) -> Array:
	var normal: Vector2 = Vector2.RIGHT.rotated(angle_rad + PI / 2.0)
	var out: Array = []
	out.append_array(make_rod(center + normal * separation / 2.0, length, angle_rad, total_q, n))
	out.append_array(make_rod(center - normal * separation / 2.0, length, angle_rad, -total_q, n))
	return out

## Mueve todas las cargas de una forma.
static func translate(shape: Array, delta: Vector2) -> void:
	for c in shape:
		c.position += delta

## Gira todas las cargas de una forma alrededor de un pivote (ángulo en radianes).
static func rotate_about(shape: Array, pivot: Vector2, angle_rad: float) -> void:
	for c in shape:
		c.position = pivot + (c.position - pivot).rotated(angle_rad)

## Redimensiona un anillo uniformemente manteniendo su centro y redistribuyendo sus cargas.
static func resize_ring(group: Dictionary, new_radius: float) -> void:
	if not group.has("points") or group["points"].is_empty():
		return
	new_radius = clampf(new_radius, 0.2, 20.0)
	var pts: Array = group["points"]
	var count: int = pts.size()
	var center: Vector2 = group.get("center", Vector2.ZERO)
	if not group.has("center"):
		var sum: Vector2 = Vector2.ZERO
		for p in pts:
			sum += p.position
		center = sum / float(count)
		group["center"] = center

	group["radius"] = new_radius
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		pts[i].position = center + Vector2(cos(a), sin(a)) * new_radius
