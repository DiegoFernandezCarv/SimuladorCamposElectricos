class_name InducedSystem
extends RefCounted

## Une las cargas del usuario con los conductores a tierra.
## Las cargas imagen son objetos Charge, así que ElectricFieldEngine funciona sin cambios:
##     ElectricFieldEngine.total_field(InducedSystem.sources(charges, conductors), punto)
##
## Límites del modelo (decirlo en la feria):
##  - Es exacto con UN conductor. Con varios solo se usan imágenes de primer orden
##    (las imágenes de las imágenes se ignoran), así que es aproximado.
##  - Una carga que esté dentro de un conductor se descarta: su campo queda apantallado.
##  - Los conductores están conectados a tierra (V = 0). No modela conductores aislados.

## Cargas reales (fuera de los conductores) + sus imágenes.
static func sources(charges: Array, conductors: Array) -> Array:
	var out: Array = []
	for c in charges:
		if not is_inside_any(c.position, conductors):
			out.append(c)
	for conductor in conductors:
		for c in charges:
			var img: Charge = conductor.image_for(c)
			if img != null:
				out.append(img)
	return out

## Campo total en un punto. Dentro de un conductor vale 0.
static func field_at(charges: Array, conductors: Array, p: Vector2) -> Vector2:
	if is_inside_any(p, conductors):
		return Vector2.ZERO
	return ElectricFieldEngine.total_field(sources(charges, conductors), p)

## Potencial total en un punto. Dentro (y sobre) un conductor a tierra vale 0.
static func potential_at(charges: Array, conductors: Array, p: Vector2) -> float:
	if is_inside_any(p, conductors):
		return 0.0
	return ElectricFieldEngine.total_potential(sources(charges, conductors), p)

## Campo que siente UNA carga real: el de todas las demás fuentes y el de sus
## imágenes, excluyendo solo su propio campo directo. Incluye la atracción hacia
## su propia imagen, que es justo la fuerza que ejerce el conductor.
static func field_on_charge(charge: Charge, charges: Array, conductors: Array) -> Vector2:
	var e: Vector2 = Vector2.ZERO
	for s in sources(charges, conductors):
		if s != charge:
			e += s.field_at(charge.position)
	return e

## Fuerza neta sobre una carga real (F = qE), con la contribución de los conductores.
static func force_on_charge(charge: Charge, charges: Array, conductors: Array) -> Vector2:
	return field_on_charge(charge, charges, conductors) * charge.q

## true si el punto está dentro (o sobre la superficie) de algún conductor.
static func is_inside_any(p: Vector2, conductors: Array) -> bool:
	for conductor in conductors:
		if conductor.contains(p):
			return true
	return false
