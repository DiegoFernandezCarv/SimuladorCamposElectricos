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
##     "sci"    -> notación científica             (campos, potencial, fuerza)
##     "angle"  -> grados con 1 decimal            (NAN = indefinido)
##
## Esta clase NO dibuja nada ni formatea texto: solo calcula. Por eso se puede
## probar de forma automática. Para agregar una magnitud nueva (energía, etc.)
## basta con añadir una fila aquí; la interfaz no necesita cambios.

static func rows_for(selected: Array, all_charges: Array) -> Array:
	if selected.is_empty():
		return []
	if selected.size() == 1:
		return _rows_for_single(selected[0], all_charges)
	return _rows_for_group(selected)

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
	rows.append(_row("x", charge.position.x, "m", "fixed"))
	rows.append(_row("y", charge.position.y, "m", "fixed"))
	rows.append(_row("q", charge.q / PhysicsConstants.MICRO, "µC", "signed"))

	rows.append(_header("Campo de las demás cargas"))
	rows.append(_row("Ex", field.x, "N/C", "sci"))
	rows.append(_row("Ey", field.y, "N/C", "sci"))
	rows.append(_row("|E|", field.length(), "N/C", "sci"))
	rows.append(_row("V", potential, "V", "sci"))

	rows.append(_header("Fuerza neta sobre la carga"))
	rows.append(_row("Fx", force.x, "N", "sci"))
	rows.append(_row("Fy", force.y, "N", "sci"))
	rows.append(_row("|F|", force.length(), "N", "sci"))
	rows.append(_row("Ángulo de F (desde +X)", angle_deg, "°", "angle"))
	return rows

## Varias cargas seleccionadas. Por ahora solo un resumen; aquí se ampliará
## con la fuerza neta externa, energía, etc. cuando exista la selección múltiple.
static func _rows_for_group(selected: Array) -> Array:
	var total_q: float = 0.0
	for charge in selected:
		total_q += charge.q

	var rows: Array = []
	rows.append(_header("Selección"))
	rows.append(_row("Cargas", float(selected.size()), "", "count"))
	rows.append(_row("Carga total", total_q / PhysicsConstants.MICRO, "µC", "signed"))
	return rows

static func _row(label: String, value: float, unit: String, kind: String) -> Dictionary:
	return {"label": label, "value": value, "unit": unit, "kind": kind}

static func _header(title: String) -> Dictionary:
	return {"label": title, "value": 0.0, "unit": "", "kind": "header"}
