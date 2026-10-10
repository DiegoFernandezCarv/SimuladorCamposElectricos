class_name FieldLineGenerator
extends RefCounted

## Genera y traza líneas de campo eléctrico (sección 11 del documento).
## Las líneas nacen en cada carga POSITIVA (una física real: el campo
## eléctrico "sale" de las cargas positivas) y terminan al:
##   - acercarse a una carga negativa (son "absorbidas"),
##   - salir del área visible de la simulación,
##   - o alcanzar el número máximo de pasos (evita loops infinitos cuando
##     solo hay cargas positivas y la línea nunca encuentra un sumidero).
##
## ZOOM: las distancias de abajo son las que se usan con el zoom por defecto.
## `line_scale` (= zoom por defecto / zoom actual) las escala para que, en
## pantalla, el paso y los radios midan siempre lo mismo en píxeles.

const LINES_PER_CHARGE: int = 16   # cuántas líneas salen de cada carga positiva
const START_RADIUS: float = 0.08   # (m) distancia inicial desde la carga
const STEP_SIZE: float = 0.06      # (m) paso de integración, sección 11: r(n+1) = r(n) + h*Ê
const MAX_STEPS: int = 800         # límite de seguridad por línea
const ABSORB_RADIUS: float = 0.12  # (m) distancia a una carga negativa para "terminar" ahí

## Genera todas las líneas de campo para el conjunto de cargas actual.
## world_bounds: Rect2 en metros (coordenadas del mundo físico) que define
## el área donde se trazan; las líneas se cortan al salirse de este rectángulo.
## line_scale: factor de escala por zoom (1.0 con el zoom por defecto).
## Devuelve un Array de PackedVector2Array (cada una es una línea, en metros).
static func generate_field_lines(charges: Array, world_bounds: Rect2, line_scale: float = 1.0) -> Array:
	var lines: Array = []

	for charge in charges:
		if charge.q <= 0.0:
			continue  # las líneas solo nacen en cargas positivas

		for i in range(LINES_PER_CHARGE):
			var angle: float = i * TAU / LINES_PER_CHARGE
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var start: Vector2 = charge.position + dir * START_RADIUS * line_scale
			var line: PackedVector2Array = _trace_line(charges, start, world_bounds, line_scale)
			if line.size() > 1:
				lines.append(line)

	return lines

## Traza una sola línea de campo a partir de un punto inicial, siguiendo
## la dirección del campo eléctrico en cada paso (sección 11).
static func _trace_line(charges: Array, start: Vector2, world_bounds: Rect2, line_scale: float = 1.0) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(start)

	var pos: Vector2 = start

	for step in range(MAX_STEPS):
		var field: Vector2 = ElectricFieldEngine.total_field(charges, pos)
		var magnitude: float = field.length()

		# Campo prácticamente nulo (ej. punto de equilibrio entre cargas iguales,
		# sección 21 Prueba 3): no hay dirección clara, se detiene la línea.
		if magnitude < 1e-6:
			break

		var direction: Vector2 = field / magnitude
		pos += direction * STEP_SIZE * line_scale
		points.append(pos)

		if not world_bounds.has_point(pos):
			break

		if _is_absorbed(charges, pos, line_scale):
			break

	return points

## True si el punto está lo bastante cerca de una carga negativa como para
## considerar que la línea termina ahí.
static func _is_absorbed(charges: Array, pos: Vector2, line_scale: float = 1.0) -> bool:
	for charge in charges:
		if charge.q < 0.0 and pos.distance_to(charge.position) < ABSORB_RADIUS * line_scale:
			return true
	return false
