class_name RigidObject
extends RefCounted

## Objeto rígido ESTÁTICO (Feature C): un grupo de fuentes (cargas y/o polos
## magnéticos) cuyas posiciones relativas al centro nunca cambian. Se mueve y
## rota como una sola pieza. Un imán es un objeto con dos polos.
##
## Los objetos Charge / MagneticPole internos se crean UNA vez y solo se
## actualiza su posición, así su identidad se mantiene (necesario para que
## field_excluding / el inspector reconozcan "la propia carga").

enum PartType { CHARGE, POLE }

## Centro del objeto en METROS y ángulo en RADIANES (antihorario desde +X, y hacia arriba).
var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var label: String = ""

## Cada parte: {"type": PartType, "offset": Vector2 (local, metros), "value": float}
## value = q en C (CHARGE) o intensidad en A·m (POLE).
var parts: Array = []

var _charges: Array = []
var _poles: Array = []

# ---------- construcción ----------

func add_part(type: PartType, local_offset: Vector2, value: float) -> void:
	parts.append({"type": type, "offset": local_offset, "value": value})
	var world_pos: Vector2 = position + local_offset.rotated(rotation)
	if type == PartType.CHARGE:
		_charges.append(Charge.new(world_pos, value))
	else:
		_poles.append(MagneticPole.new(world_pos, value))

## Imán de dos polos. Eje de S a N a lo largo de +X local:
## polo N en +length/2, polo S en -length/2.
static func make_magnet(center: Vector2, length: float, pole_strength: float, angle: float = 0.0) -> RigidObject:
	var obj: RigidObject = RigidObject.new()
	obj.label = "Imán"
	obj.position = center
	obj.rotation = angle
	obj.add_part(PartType.POLE, Vector2(length * 0.5, 0.0), abs(pole_strength))   # N
	obj.add_part(PartType.POLE, Vector2(-length * 0.5, 0.0), -abs(pole_strength)) # S
	return obj

## Dipolo eléctrico rígido: +q en +separation/2, -q en -separation/2.
static func make_electric_dipole(center: Vector2, separation: float, q: float, angle: float = 0.0) -> RigidObject:
	var obj: RigidObject = RigidObject.new()
	obj.label = "Dipolo eléctrico"
	obj.position = center
	obj.rotation = angle
	obj.add_part(PartType.CHARGE, Vector2(separation * 0.5, 0.0), abs(q))
	obj.add_part(PartType.CHARGE, Vector2(-separation * 0.5, 0.0), -abs(q))
	return obj

## Varilla con carga total repartida en n cargas puntuales iguales.
static func make_charged_rod(center: Vector2, length: float, total_q: float, n: int, angle: float = 0.0) -> RigidObject:
	var obj: RigidObject = RigidObject.new()
	obj.label = "Varilla cargada"
	obj.position = center
	obj.rotation = angle
	n = maxi(n, 2)
	for i in range(n):
		var t: float = float(i) / float(n - 1)          # 0 .. 1
		obj.add_part(PartType.CHARGE, Vector2((t - 0.5) * length, 0.0), total_q / float(n))
	return obj

# ---------- movimiento (mover y rotar como grupo) ----------

func set_transform(new_position: Vector2, new_rotation: float) -> void:
	position = new_position
	rotation = new_rotation
	_sync()

func translate_by(delta: Vector2) -> void:
	set_transform(position + delta, rotation)

## Rota alrededor del propio centro.
func rotate_by(angle: float) -> void:
	set_transform(position, rotation + angle)

## Rota alrededor de un pivote externo (útil cuando se mueve un grupo seleccionado).
func rotate_about(pivot: Vector2, angle: float) -> void:
	set_transform(pivot + (position - pivot).rotated(angle), rotation + angle)

func _sync() -> void:
	var charge_i: int = 0
	var pole_i: int = 0
	for part in parts:
		var world_pos: Vector2 = position + part["offset"].rotated(rotation)
		if part["type"] == PartType.CHARGE:
			_charges[charge_i].position = world_pos
			charge_i += 1
		else:
			_poles[pole_i].position = world_pos
			pole_i += 1

# ---------- fuentes en coordenadas del mundo ----------

## Cargas del objeto (mismas instancias siempre). Se pueden concatenar con las
## cargas libres para usar ElectricFieldEngine sin cambios.
func world_charges() -> Array:
	return _charges

## Polos magnéticos del objeto (mismas instancias siempre).
func world_poles() -> Array:
	return _poles

# ---------- magnitudes útiles (para validar y para el inspector) ----------

func net_charge() -> float:
	var total: float = 0.0
	for c in _charges:
		total += c.q
	return total

## Suma de intensidades de polo. Para un imán real SIEMPRE debe ser 0
## (no existen monopolos magnéticos).
func net_pole_strength() -> float:
	var total: float = 0.0
	for p in _poles:
		total += p.strength
	return total

## Momento dipolar magnético m = Σ qm_i · r_i (vector, en A·m²), medido
## respecto al centro. Para un imán de longitud L: |m| = qm · L, de S a N.
func magnetic_moment() -> Vector2:
	var m: Vector2 = Vector2.ZERO
	for p in _poles:
		m += (p.position - position) * p.strength
	return m

## Radio que envuelve a todas las partes (para detectar clics sobre el objeto).
func bounding_radius() -> float:
	var r: float = 0.0
	for part in parts:
		r = maxf(r, part["offset"].length())
	return r

func hit_test(world_point: Vector2, tolerance: float) -> bool:
	return world_point.distance_to(position) <= bounding_radius() + tolerance
