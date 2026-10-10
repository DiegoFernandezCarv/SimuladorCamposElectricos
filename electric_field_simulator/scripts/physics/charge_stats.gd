class_name ChargeStats
extends RefCounted

## Construye las estadísticas de la(s) carga(s) seleccionada(s) como una lista
## de "filas". Cada fila es un Diccionario:
##     { "label": String, "value": float, "unit": String, "kind": String }
## donde "kind" indica cómo debe formatearla la interfaz:
##     "header" -> título de sección (no lleva valor)
##     "fixed"  -> número con 2 decimales          (posiciones)
##     "signed" -> número con 2 decimales y signo  (cargas en µC)
##     "count"  -> entero                          (cantidad de cargas)
##     "sci"    -> notación científica             (campos, potencial, fuerza, energía)
##     "angle"  -> grados con 1 decimal            (NAN = indefinido)
##
## Esta clase NO dibuja nada ni formatea texto: solo calcula. Por eso se puede
## probar de forma automática. Para agregar una magnitud nueva basta con añadir
## una fila aquí; la interfaz no necesita cambios.
##
## Los nombres de las filas están en constantes (LBL_*) para que las pruebas no
## dependan de textos escritos a mano: si una etiqueta cambia, cambia en un solo lugar.

const LBL_X: String = "x"
const LBL_Y: String = "y"
const LBL_Q: String = "q"
const LBL_EX: String = "Ex"
const LBL_EY: String = "Ey"
const LBL_EMAG: String = "|E|"
const LBL_V: String = "V"
const LBL_U: String = "U = qV"
const LBL_FX: String = "Fx"
const LBL_FY: String = "Fy"
const LBL_FMAG: String = "|F|"
const LBL_ANGLE: String = "Ángulo de F (desde +X)"
const LBL_COUNT: String = "Cargas"
const LBL_QTOTAL: String = "Carga total"
const LBL_F_INT: String = "|ΣF| interna"
const LBL_U_INT: String = "U interna"
const LBL_U_REST: String = "U con el resto"

static func rows_for(selected: Array, all_charges: Array) -> Array:
	if selected.is_empty():
		return []
	if selected.size() == 1:
		return _rows_for_single(selected[0], all_charges)
	return _rows_for_group(selected, all_charges)

## Una sola carga seleccionada: sus datos y lo que le hacen las DEMÁS cargas.
static func _rows_for_single(charge: Charge, all_charges: Array) -> Array:
	var others: Array = [charge]  # se excluye a sí misma
	var field: Vector2 = ElectricFieldEngine.field_excluding(all_charges, charge.position, others)
	var potential: float = ElectricFieldEngine.potential_excluding(all_charges, charge.position, others)
	var force: Vector2 = ElectricFieldEngine.force_on_charge(field, charge.q)

	var angle_deg: float = NAN
	if force.length_squared() > 0.0:
		angle_deg = rad_to_deg(atan2(force.y, force.x))

	var rows: Array = []
	rows.append(_header("Carga seleccionada"))
	rows.append(_row(LBL_X, charge.position.x, "m", "fixed"))
	rows.append(_row(LBL_Y, charge.position.y, "m", "fixed"))
	rows.append(_row(LBL_Q, charge.q / PhysicsConstants.MICRO, "µC", "signed"))

	rows.append(_header("Campo de las demás cargas"))
	rows.append(_row(LBL_EX, field.x, "N/C", "sci"))
	rows.append(_row(LBL_EY, field.y, "N/C", "sci"))
	rows.append(_row(LBL_EMAG, field.length(), "N/C", "sci"))
	rows.append(_row(LBL_V, potential, "V", "sci"))
	rows.append(_row(LBL_U, charge.q * potential, "J", "sci"))

	rows.append(_header("Fuerza neta sobre la carga"))
	rows.append(_row(LBL_FX, force.x, "N", "sci"))
	rows.append(_row(LBL_FY, force.y, "N", "sci"))
	rows.append(_row(LBL_FMAG, force.length(), "N", "sci"))
	rows.append(_row(LBL_ANGLE, angle_deg, "°", "angle"))
	return rows

## Varias cargas seleccionadas (un "grupo"):
##  - Fuerza EXTERNA: la que ejercen sobre el grupo las cargas NO seleccionadas.
##      F_ext = Σ qᵢ · E_ext(rᵢ)   (E_ext excluye a todo el grupo)
##  - Fuerza INTERNA: la que se hacen entre sí las cargas del grupo. Por la 3ª ley de
##    Newton las fuerzas por pares se cancelan, así que la suma debe ser 0 (autoprueba).
##  - Energía interna: U_int = Σ_{i<j} k·qᵢ·qⱼ / rᵢⱼ   (cada pareja una sola vez).
##  - Energía con el resto: U_rest = Σ qᵢ · V_ext(rᵢ).
static func _rows_for_group(selected: Array, all_charges: Array) -> Array:
	var total_q: float = 0.0
	var f_ext: Vector2 = Vector2.ZERO
	var f_int: Vector2 = Vector2.ZERO
	var f_int_scale: float = 0.0   # suma de |F| internas: sirve de referencia para el "cero numérico"
	var u_rest: float = 0.0

	for charge in selected:
		total_q += charge.q

		# Efecto de las cargas que NO están en el grupo
		var e_ext: Vector2 = ElectricFieldEngine.field_excluding(all_charges, charge.position, selected)
		var v_ext: float = ElectricFieldEngine.potential_excluding(all_charges, charge.position, selected)
		f_ext += ElectricFieldEngine.force_on_charge(e_ext, charge.q)
		u_rest += charge.q * v_ext

		# Efecto de las demás cargas DEL grupo (se excluye a sí misma)
		var e_int: Vector2 = ElectricFieldEngine.field_excluding(selected, charge.position, [charge])
		var f: Vector2 = ElectricFieldEngine.force_on_charge(e_int, charge.q)
		f_int += f
		f_int_scale += f.length()

	# Los restos de redondeo (~1e-19 N) no son físicos: si la suma es despreciable
	# frente a las fuerzas que se cancelan, se muestra como 0 exacto.
	if f_int.length() <= 1e-5 * f_int_scale:
		f_int = Vector2.ZERO

	var u_int: float = 0.0
	for i in range(selected.size()):
		for j in range(i + 1, selected.size()):
			var r: float = selected[i].position.distance_to(selected[j].position)
			if r < 1e-9:
				continue  # misma posición: se omite para no dividir entre cero
			u_int += PhysicsConstants.K * selected[i].q * selected[j].q / r

	var angle_deg: float = NAN
	if f_ext.length_squared() > 0.0:
		angle_deg = rad_to_deg(atan2(f_ext.y, f_ext.x))

	var rows: Array = []
	rows.append(_header("Selección"))
	rows.append(_row(LBL_COUNT, float(selected.size()), "", "count"))
	rows.append(_row(LBL_QTOTAL, total_q / PhysicsConstants.MICRO, "µC", "signed"))

	rows.append(_header("Fuerza externa sobre el grupo"))
	rows.append(_row(LBL_FX, f_ext.x, "N", "sci"))
	rows.append(_row(LBL_FY, f_ext.y, "N", "sci"))
	rows.append(_row(LBL_FMAG, f_ext.length(), "N", "sci"))
	rows.append(_row(LBL_ANGLE, angle_deg, "°", "angle"))

	rows.append(_header("Comprobación (3ª ley de Newton)"))
	rows.append(_row(LBL_F_INT, f_int.length(), "N", "sci"))

	rows.append(_header("Energía electrostática"))
	rows.append(_row(LBL_U_INT, u_int, "J", "sci"))
	rows.append(_row(LBL_U_REST, u_rest, "J", "sci"))
	return rows

static func _row(label: String, value: float, unit: String, kind: String) -> Dictionary:
	return {"label": label, "value": value, "unit": unit, "kind": kind}

static func _header(title: String) -> Dictionary:
	return {"label": title, "value": 0.0, "unit": "", "kind": "header"}
