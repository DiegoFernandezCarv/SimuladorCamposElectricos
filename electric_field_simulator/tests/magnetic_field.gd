class_name MagneticFieldEngine
extends RefCounted

## Constante magnética: μ0 / 4π = 1e-7 T·m/A (valor exacto en el SI histórico,
## y aproximado a ~1e-10 relativo en el SI actual).
## Si prefieres, muévela a constants.gd junto a K y MICRO.
const MU0_OVER_4PI: float = 1.0e-7

## Campo magnético TOTAL en un punto: superposición de cualquier fuente que
## tenga field_at(point) -> Vector2 (MagneticPole, CurrentWire, ...).
## B_total = Σ Bᵢ
static func total_field(sources: Array, point: Vector2) -> Vector2:
	var b_total: Vector2 = Vector2.ZERO
	for source in sources:
		b_total += source.field_at(point)
	return b_total

## Igual que total_field, pero ignorando una fuente concreta (por identidad).
static func field_excluding(sources: Array, point: Vector2, excluded: Object) -> Vector2:
	var b_total: Vector2 = Vector2.ZERO
	for source in sources:
		if source == excluded:
			continue
		b_total += source.field_at(point)
	return b_total
