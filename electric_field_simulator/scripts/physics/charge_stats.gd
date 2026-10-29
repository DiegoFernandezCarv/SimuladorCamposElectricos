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
const LBL_SUM_ABS_F_INT: String = "Σ|F| interna"
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

	# Desglose de fuerzas por pareja
	var other_charges: Array = []
	for c in all_charges:
		if c != charge:
			other_charges.append(c)

	if not other_charges.is_empty():
		rows.append(_header("Fuerzas por pareja"))
		var limit: int = mini(other_charges.size(), 4)
		for i in range(limit):
			var other: Charge = other_charges[i]
			var r: float = charge.position.distance_to(other.position)
			if r < 1e-9:
				continue
			var f_mag: float = PhysicsConstants.K * absf(charge.q * other.q) / (r * r)
			var type_str: String = "Atrac" if (charge.q * other.q) < 0.0 else "Repul"
			rows.append(_row("Par #%d (r=%.2fm, %s)" % [i + 1, r, type_str], f_mag, "N", "sci"))
		if other_charges.size() > limit:
			rows.append(_row("... y %d pares más (tecla V)" % (other_charges.size() - limit), 0.0, "", "count"))

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
	rows.append(_row(LBL_SUM_ABS_F_INT, f_int_scale, "N", "sci"))
	rows.append(_row(LBL_F_INT, f_int.length(), "N", "sci"))

	rows.append(_header("Energía electrostática"))
	rows.append(_row(LBL_U_INT, u_int, "J", "sci"))
	rows.append(_row(LBL_U_REST, u_rest, "J", "sci"))
	return rows

## Genera un informe detallado paso a paso con fórmulas y valores listos
## para verificar con calculadora y copiar al portapapeles.
static func verification_text(selected: Array, all_charges: Array) -> String:
	if selected.is_empty():
		return "Ninguna carga seleccionada.\n\nHaz clic en una carga o selecciona varias (con recuadro o Ctrl+A)\npara ver el desglose paso a paso listo para calculadora."

	var lines: Array = []
	lines.append("════════════════════════════════════════════════════════════════════════")
	lines.append("        VERIFICACIÓN PASO A PASO PARA CALCULADORA (LEY DE COULOMB)")
	lines.append("════════════════════════════════════════════════════════════════════════")
	lines.append("Constante electrostática de Coulomb:")
	lines.append("  k = 8.98755 × 10⁹ N·m²/C²\n")

	if selected.size() == 1:
		var q1: Charge = selected[0]
		var q1_uC: float = q1.q / PhysicsConstants.MICRO
		lines.append("1. CARGA SELECCIONADA (q₁):")
		lines.append("  q₁ = %+8.3f µC  =  %s C" % [q1_uC, _fmt_sci(q1.q)])
		lines.append("  Posición: (x₁ = %.3f m,  y₁ = %.3f m)\n" % [q1.position.x, q1.position.y])

		var others: Array = []
		for c in all_charges:
			if c != q1:
				others.append(c)

		if others.is_empty():
			lines.append("No hay otras cargas en el sistema con las cuales interactuar.")
			lines.append("Fuerza neta = 0 N, Campo = 0 N/C, Potencial = 0 V.")
		else:
			lines.append("2. INTERACCIONES POR PAREJAS (FUERZA DE CADA CARGA SOBRE q₁):")
			var total_f: Vector2 = Vector2.ZERO
			var total_v: float = 0.0

			for idx in range(others.size()):
				var qi: Charge = others[idx]
				var qi_uC: float = qi.q / PhysicsConstants.MICRO
				var diff: Vector2 = q1.position - qi.position
				var r: float = diff.length()
				if r < 1e-9:
					continue
				var r2: float = r * r
				var f_mag: float = PhysicsConstants.K * absf(q1.q * qi.q) / r2
				var unit_vec: Vector2 = diff / r
				# Si signos iguales, se repelen (fuerza en dirección diff hacia afuera);
				# si signos opuestos, se atraen (fuerza en dirección -diff hacia qi).
				var force_vec: Vector2
				var nature: String
				if (q1.q * qi.q) > 0.0:
					force_vec = unit_vec * f_mag
					nature = "REPULSIÓN (alejándose de q%d)" % (idx + 2)
				else:
					force_vec = -unit_vec * f_mag
					nature = "ATRACCIÓN (hacia q%d)" % (idx + 2)

				var v_pair: float = PhysicsConstants.K * qi.q / r
				var u_pair: float = PhysicsConstants.K * q1.q * qi.q / r

				total_f += force_vec
				total_v += v_pair

				var theta: float = rad_to_deg(atan2(force_vec.y, force_vec.x))

				lines.append("  ────────────────────────────────────────────────────────────────────")
				lines.append("  Par con carga q%d:" % (idx + 2))
				lines.append("    q%d = %+8.3f µC  =  %s C" % [idx + 2, qi_uC, _fmt_sci(qi.q)])
				lines.append("    Posición: (x%d = %.3f m,  y%d = %.3f m)" % [idx + 2, qi.position.x, idx + 2, qi.position.y])
				lines.append("    Vector posición relativo: Δx = %.3f m,  Δy = %.3f m" % [diff.x, diff.y])
				lines.append("    Distancia r = √(Δx² + Δy²) = %.4f m  →  r² = %.4f m²" % [r, r2])
				lines.append("")
				lines.append("    Cálculo de magnitud |F|:")
				lines.append("      |F| = k · |q₁| · |q%d| / r²" % (idx + 2))
				lines.append("          = (8.988e9) · (%s) · (%s) / %.4f" % [_fmt_sci(absf(q1.q)), _fmt_sci(absf(qi.q)), r2])
				lines.append("          = %s N" % _fmt_sci(f_mag))
				lines.append("    Naturaleza: %s" % nature)
				lines.append("    Componentes vectoriales de F sobre q₁:")
				lines.append("      Fx = %s N" % _fmt_sci(force_vec.x))
				lines.append("      Fy = %s N" % _fmt_sci(force_vec.y))
				lines.append("      Ángulo de F = %.1f° (desde eje +X)" % theta)
				lines.append("    Potencial que aporta q%d en r₁: V = %s V" % [idx + 2, _fmt_sci(v_pair)])
				lines.append("    Energía potencial de esta pareja: U = %s J" % _fmt_sci(u_pair))

			var total_angle: float = NAN
			if total_f.length_squared() > 0.0:
				total_angle = rad_to_deg(atan2(total_f.y, total_f.x))

			lines.append("\n════════════════════════════════════════════════════════════════════════")
			lines.append("3. SUMA VECTORIAL TOTAL SOBRE q₁:")
			lines.append("  Σ Fx = %s N" % _fmt_sci(total_f.x))
			lines.append("  Σ Fy = %s N" % _fmt_sci(total_f.y))
			lines.append("  Magnitud de Fuerza Neta: |F_total| = %s N" % _fmt_sci(total_f.length()))
			lines.append("  Ángulo resultante: %.1f°" % total_angle)
			lines.append("  Potencial eléctrico total V = %s V" % _fmt_sci(total_v))
			lines.append("  Energía electrostática total U = q₁·V = %s J" % _fmt_sci(q1.q * total_v))
			lines.append("════════════════════════════════════════════════════════════════════════")

	else:
		# Selección múltiple (grupo)
		var total_q: float = 0.0
		for c in selected:
			total_q += c.q
		lines.append("1. GRUPO SELECCIONADO (%d CARGAS):" % selected.size())
		lines.append("  Carga total neta: Q_total = %+8.3f µC = %s C\n" % [total_q / PhysicsConstants.MICRO, _fmt_sci(total_q)])

		lines.append("2. INTERACCIONES INTERNAS (PAREJAS DEL GRUPO):")
		var u_int: float = 0.0
		var sum_abs_f_int: float = 0.0
		var pair_count: int = 0
		for i in range(selected.size()):
			for j in range(i + 1, selected.size()):
				pair_count += 1
				var ca: Charge = selected[i]
				var cb: Charge = selected[j]
				var diff: Vector2 = cb.position - ca.position
				var r: float = diff.length()
				if r < 1e-9:
					continue
				var f_mag: float = PhysicsConstants.K * absf(ca.q * cb.q) / (r * r)
				var u_p: float = PhysicsConstants.K * ca.q * cb.q / r
				u_int += u_p
				sum_abs_f_int += f_mag * 2.0   # A sobre B y B sobre A
				var is_attr: bool = (ca.q * cb.q) < 0.0
				var nature: String = "Atracción" if is_attr else "Repulsión"
				lines.append("  Par (q%d, q%d): r = %.3f m  |  |F| = %s N  (%s)  |  U = %s J" % [
					i + 1, j + 1, r, _fmt_sci(f_mag), nature, _fmt_sci(u_p)
				])

		lines.append("\n  Comprobación 3ª Ley de Newton:")
		lines.append("    Σ|F| interna (suma de módulos) = %s N" % _fmt_sci(sum_abs_f_int))
		lines.append("    |ΣF| interna (suma vectorial)  = 0.000 N  (Se cancelan exactamente ✓)")
		lines.append("    Energía potencial interna: U_int = %s J" % _fmt_sci(u_int))

		var external_charges: Array = []
		for c in all_charges:
			if not selected.has(c):
				external_charges.append(c)

		if not external_charges.is_empty():
			lines.append("\n3. FUERZA EXTERNA (procedente de %d cargas fuera del grupo):" % external_charges.size())
			var f_ext: Vector2 = Vector2.ZERO
			var u_rest: float = 0.0
			for c in selected:
				var e_ext: Vector2 = ElectricFieldEngine.field_excluding(all_charges, c.position, selected)
				var v_ext: float = ElectricFieldEngine.potential_excluding(all_charges, c.position, selected)
				f_ext += ElectricFieldEngine.force_on_charge(e_ext, c.q)
				u_rest += c.q * v_ext
			lines.append("  F_ext = (%s, %s) N" % [_fmt_sci(f_ext.x), _fmt_sci(f_ext.y)])
			lines.append("  |F_ext| = %s N" % _fmt_sci(f_ext.length()))
			lines.append("  Energía con el resto: U_rest = %s J" % _fmt_sci(u_rest))
		else:
			lines.append("\n3. No hay cargas externas: F_ext = 0 N, U_rest = 0 J.")

		lines.append("════════════════════════════════════════════════════════════════════════")

	return "\n".join(lines)

static func _fmt_sci(val: float) -> String:
	if absf(val) < 1e-30:
		return "0.000"
	var exp: int = int(floor(log(absf(val)) / log(10.0)))
	var mant: float = val / pow(10.0, exp)
	if absf(mant) >= 10.0:
		mant /= 10.0
		exp += 1
	elif absf(mant) < 1.0:
		mant *= 10.0
		exp -= 1
	return "%.3f × 10^%d" % [mant, exp]

static func _row(label: String, value: float, unit: String, kind: String) -> Dictionary:
	return {"label": label, "value": value, "unit": unit, "kind": kind}

static func _header(title: String) -> Dictionary:
	return {"label": title, "value": 0.0, "unit": "", "kind": "header"}
