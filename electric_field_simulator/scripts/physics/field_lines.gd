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
## Parámetros opcionales (para conductores a tierra y formas con muchas cargas):
##   emitters:  cargas de las que nacen las líneas. Si está vacío, todas las de `charges`.
##              (Así las cargas imagen, que son ficticias, ayudan a trazar pero no emiten.)
##   blockers:  objetos con contains(punto); la línea se corta al entrar en uno (conductores).
##   lines_for: Dictionary Charge -> nº de líneas que emite (por defecto LINES_PER_CHARGE; 0 = ninguna).
## Devuelve un Array de PackedVector2Array (cada una es una línea, en metros).
static func generate_field_lines(charges: Array, world_bounds: Rect2, line_scale: float = 1.0,
		emitters: Array = [], blockers: Array = [], lines_for: Dictionary = {}) -> Array:
	var lines: Array = []
	var source_list: Array = charges if emitters.is_empty() else emitters

	for charge in source_list:
		if charge.q <= 0.0:
			continue  # las líneas solo nacen en cargas positivas

		var count: int = int(lines_for.get(charge, LINES_PER_CHARGE))
		if count <= 0:
			continue
		# Con pocas líneas se gira medio paso para no salir justo sobre el eje de una varilla
		var phase: float = 0.0 if count == LINES_PER_CHARGE else 0.5

		for i in range(count):
			var angle: float = (i + phase) * TAU / count
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var start: Vector2 = charge.position + dir * START_RADIUS * line_scale
			var line: PackedVector2Array = _trace_line(charges, start, world_bounds, line_scale, blockers)
			if line.size() > 1:
				lines.append(line)

	return lines

## Traza una sola línea de campo a partir de un punto inicial, siguiendo
## la dirección del campo eléctrico en cada paso (sección 11).
static func _trace_line(charges: Array, start: Vector2, world_bounds: Rect2, line_scale: float = 1.0,
		blockers: Array = []) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(start)
	if _is_blocked(start, blockers):
		return points   # arranca dentro de un conductor: no hay línea

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
		if _is_blocked(pos, blockers):
			break   # llegó a la superficie de un conductor: la línea termina ahí
		points.append(pos)

		if not world_bounds.has_point(pos):
			break

		if _is_absorbed(charges, pos, line_scale):
			break

	return points

## True si el punto está dentro de alguno de los conductores.
static func _is_blocked(pos: Vector2, blockers: Array) -> bool:
	for blocker in blockers:
		if blocker.contains(pos):
			return true
	return false

## True si el punto está lo bastante cerca de una carga negativa como para
## considerar que la línea termina ahí.
static func _is_absorbed(charges: Array, pos: Vector2, line_scale: float = 1.0) -> bool:
	for charge in charges:
		if charge.q < 0.0 and pos.distance_to(charge.position) < ABSORB_RADIUS * line_scale:
			return true
	return false

# ---------------------------------------------------------------------------
# CAMPO MAGNÉTICO (imanes): mismo método que el eléctrico, con polos en lugar de
# cargas. Las líneas nacen en cada polo NORTE (strength > 0) y terminan al acercarse
# a un polo SUR, salir del área o agotar los pasos.
# ---------------------------------------------------------------------------

const MIN_B_FIELD: float = 1.0e-14   # (T) por debajo de esto no hay dirección clara; el B de un imán es ~1e-7 T

## poles: Array de MagneticPole. Devuelve Array de PackedVector2Array (en metros).
static func generate_magnetic_lines(poles: Array, world_bounds: Rect2, line_scale: float = 1.0) -> Array:
	var lines: Array = []
	for pole in poles:
		if pole.strength <= 0.0:
			continue
		for i in range(LINES_PER_CHARGE):
			var angle: float = i * TAU / LINES_PER_CHARGE
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var start: Vector2 = pole.position + dir * START_RADIUS * line_scale
			var line: PackedVector2Array = _trace_magnetic_line(poles, start, world_bounds, line_scale)
			if line.size() > 1:
				lines.append(line)
	return lines

static func _trace_magnetic_line(poles: Array, start: Vector2, world_bounds: Rect2, line_scale: float = 1.0) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(start)
	var pos: Vector2 = start
	for step in range(MAX_STEPS):
		var b: Vector2 = MagneticFieldEngine.total_field(poles, pos)
		var magnitude: float = b.length()
		if magnitude < MIN_B_FIELD:
			break
		pos += (b / magnitude) * STEP_SIZE * line_scale
		points.append(pos)
		if not world_bounds.has_point(pos):
			break
		if _is_absorbed_by_south(poles, pos, line_scale):
			break
	return points

static func _is_absorbed_by_south(poles: Array, pos: Vector2, line_scale: float = 1.0) -> bool:
	for pole in poles:
		if pole.strength < 0.0 and pos.distance_to(pole.position) < ABSORB_RADIUS * line_scale:
			return true
	return false
