extends Node2D
## Escena principal: permite colocar, seleccionar, mover, editar y borrar cargas,
## y visualiza el campo eléctrico en tiempo real.
##
## CONTROLES:
## - Click izquierdo en espacio vacío:  coloca una carga POSITIVA
## - Click derecho en espacio vacío:    coloca una carga NEGATIVA
## - Click izquierdo SOBRE una carga:   la selecciona (arrastra para moverla)
## - Click derecho SOBRE una carga:     la borra
## - Supr / Backspace:                  borra la carga seleccionada
## - Esc:                               deselecciona
## - Campo de texto:                    valor (µC) de la carga seleccionada,
##                                       o de la próxima carga si no hay selección
##
## PANELES:
## - Arriba a la izquierda: coordenadas del cursor (x, y) y ayuda de clics.
## - Arriba a la derecha:   "inspector" con las estadísticas de la carga
##                          seleccionada (campo, potencial y fuerza que le hacen
##                          las demás cargas). Solo aparece si hay una selección.

const PIXELS_PER_METER: float = 80.0
const ARROW_MAX_LENGTH: float = 55.0
const GRID_STEP_PX: int = 60
const MIN_CHARGE_UC: float = 0.01
const LINE_HEIGHT_PX: float = 22.0
const SELECT_RADIUS_PX: float = 18.0
const PANEL_MARGIN_PX: float = 10.0
const PANEL_PADDING_PX: float = 10.0
const PANEL_FONT_SIZE: int = 16
const LEFT_PANEL_WIDTH: float = 330.0
const LEFT_PANEL_HEIGHT: float = 182.0

@onready var charge_value_input: LineEdit = $UI/ChargeValueInput
@onready var charge_value_label: Label = $UI/ChargeValueLabel

var charges: Array = []              # Array de objetos Charge
var mouse_world_pos: Vector2 = Vector2.ZERO
var next_charge_uC: float = 1.0      # magnitud (µC) para la próxima carga a colocar
var selected_charge: Charge = null   # carga actualmente seleccionada (o null)
var dragging: bool = false
var field_lines: Array = []
var deselect_button: Button          # caché de líneas de campo (se recalcula solo cuando hace falta)

func _ready() -> void:
	# Dipolo de ejemplo para empezar a experimentar (sección 52, Experimento 2)
	charges.append(Charge.new(Vector2(-2, 0), PhysicsConstants.MICRO))
	charges.append(Charge.new(Vector2(2, 0), -PhysicsConstants.MICRO))
	_recompute_field_lines()

	charge_value_input.text = "%.2f" % next_charge_uC
	charge_value_input.text_changed.connect(_on_charge_value_changed)
	charge_value_input.text_submitted.connect(_on_charge_value_submitted)
	deselect_button = Button.new()
	deselect_button.text = "Deseleccionar (Esc)"
	deselect_button.disabled = true
	deselect_button.pressed.connect(_on_deselect_pressed)
	$UI.add_child(deselect_button)
	_layout_left_panel()

func _process(_delta: float) -> void:
	mouse_world_pos = screen_to_world(get_local_mouse_position())

	# Salvaguarda: si el botón se soltó fuera del área de dibujo (ej. sobre la UI),
	# el evento de "release" pudo no llegarnos, así que revisamos el estado real.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		_recompute_field_lines()

	if dragging and selected_charge != null:
		selected_charge.position = mouse_world_pos

	queue_redraw()

## Recalcula las líneas de campo. NO se llama en cada frame por rendimiento
## (16 líneas × N cargas × hasta 800 pasos): solo cuando se agrega o borra una
## carga, se suelta un arrastre o se confirma un valor numérico.
func _recompute_field_lines() -> void:
	var margin: float = 1.0  # metros de margen fuera de pantalla
	var top_left: Vector2 = screen_to_world(Vector2.ZERO) - Vector2(margin, margin)
	var bottom_right: Vector2 = screen_to_world(get_viewport_rect().size) + Vector2(margin, margin)
	var bounds: Rect2 = Rect2(top_left, bottom_right - top_left).abs()
	field_lines = FieldLineGenerator.generate_field_lines(charges, bounds)

## Se llama cada vez que el usuario escribe/borra un carácter en el campo de texto.
func _on_charge_value_changed(new_text: String) -> void:
	if not new_text.is_valid_float():
		return
	var value: float = new_text.to_float()
	if value < MIN_CHARGE_UC:
		return

	if selected_charge != null:
		var sign_val: float = 1.0 if selected_charge.q >= 0.0 else -1.0
		selected_charge.q = sign_val * value * PhysicsConstants.MICRO
	else:
		next_charge_uC = value

func _on_charge_value_submitted(_new_text: String) -> void:
	charge_value_input.release_focus()
	_recompute_field_lines()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var screen_pos: Vector2 = get_local_mouse_position()
		var world_pos: Vector2 = screen_to_world(screen_pos)

		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					var hit: Charge = _find_charge_at_screen(screen_pos)
					if hit != null:
						_select_charge(hit)
						dragging = true
					else:
						_add_charge(world_pos, next_charge_uC * PhysicsConstants.MICRO)
						_deselect()
				MOUSE_BUTTON_RIGHT:
					var hit2: Charge = _find_charge_at_screen(screen_pos)
					if hit2 != null:
						_delete_charge(hit2)
					else:
						_add_charge(world_pos, -next_charge_uC * PhysicsConstants.MICRO)
						_deselect()
			queue_redraw()
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and dragging:
				dragging = false
				_recompute_field_lines()

	elif event is InputEventScreenTouch and event.pressed:
		# Soporte táctil básico para Android (sección 29): un toque = carga positiva
		var world_pos: Vector2 = screen_to_world(event.position)
		_add_charge(world_pos, next_charge_uC * PhysicsConstants.MICRO)
		_deselect()
		queue_redraw()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if selected_charge != null and not charge_value_input.has_focus():
				_delete_charge(selected_charge)
				queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			_deselect()
			queue_redraw()

## Busca la carga más cercana a una posición de pantalla, dentro del radio de selección.
func _find_charge_at_screen(screen_pos: Vector2) -> Charge:
	for charge in charges:
		var charge_screen: Vector2 = world_to_screen(charge.position)
		if charge_screen.distance_to(screen_pos) <= SELECT_RADIUS_PX:
			return charge
	return null

## Agrega una carga y refresca las líneas de campo. Todas las altas pasan por aquí
## para no olvidar el recálculo en ningún camino.
func _add_charge(world_pos: Vector2, charge_value: float) -> void:
	charges.append(Charge.new(world_pos, charge_value))
	_recompute_field_lines()

func _select_charge(charge: Charge) -> void:
	selected_charge = charge
	var value_uC: float = abs(charge.q) / PhysicsConstants.MICRO
	charge_value_input.text = "%.2f" % value_uC
	charge_value_label.text = "Editando carga seleccionada (µC):"

func _deselect() -> void:
	selected_charge = null
	dragging = false
	charge_value_input.text = "%.2f" % next_charge_uC
	charge_value_label.text = "Valor de carga a colocar (µC):"
	if deselect_button != null:
		deselect_button.disabled = true
		
## Borra una carga y refresca las líneas de campo. Todas las bajas pasan por aquí
## (clic derecho y tecla Supr/Backspace), así el recálculo no se puede olvidar.
func _delete_charge(charge: Charge) -> void:
	charges.erase(charge)
	if selected_charge == charge:
		_deselect()
	_recompute_field_lines()

# ---------- Conversión de coordenadas: pantalla (px) <-> mundo físico (m) ----------
# Implementa la sección 9 del documento: screen_to_world() / world_to_screen()
func world_to_screen(world_pos: Vector2) -> Vector2:
	var center: Vector2 = get_viewport_rect().size / 2.0
	# El eje Y de pantalla crece hacia abajo; el eje Y físico crece hacia arriba
	return center + Vector2(world_pos.x, -world_pos.y) * PIXELS_PER_METER

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var center: Vector2 = get_viewport_rect().size / 2.0
	var diff: Vector2 = screen_pos - center
	return Vector2(diff.x, -diff.y) / PIXELS_PER_METER

# ---------- Dibujo ----------
func _draw() -> void:
	_draw_field_lines()
	_draw_field_grid()
	_draw_charges()
	_draw_cursor_panel()
	_draw_inspector_panel()

## Líneas de campo pre-calculadas (sección 11)
func _draw_field_lines() -> void:
	var color: Color = Color(1.0, 0.85, 0.2, 0.55)
	for line in field_lines:
		var screen_points: PackedVector2Array = PackedVector2Array()
		for world_point in line:
			screen_points.append(world_to_screen(world_point))
		if screen_points.size() > 1:
			draw_polyline(screen_points, color, 1.5, true)

func _draw_charges() -> void:
	for charge in charges:
		var pos: Vector2 = world_to_screen(charge.position)
		var color: Color = Color.CRIMSON if charge.q > 0.0 else Color.ROYAL_BLUE
		draw_circle(pos, 12.0, color)

		if charge == selected_charge:
			draw_arc(pos, 18.0, 0.0, TAU, 32, Color.YELLOW, 3.0)

		var value_uC: float = charge.q / PhysicsConstants.MICRO
		var label: String = _format_charge_label(value_uC)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-26, -22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

## Cuadrícula de vectores de campo (sección 12 del documento)
func _draw_field_grid() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var x: float = GRID_STEP_PX / 2.0
	while x < view_size.x:
		var y: float = GRID_STEP_PX / 2.0
		while y < view_size.y:
			var screen_point: Vector2 = Vector2(x, y)
			var world_point: Vector2 = screen_to_world(screen_point)
			var field: Vector2 = ElectricFieldEngine.total_field(charges, world_point)
			_draw_arrow(screen_point, field)
			y += GRID_STEP_PX
		x += GRID_STEP_PX

## Dibuja una flecha con longitud comprimida logarítmicamente (sección 10: "escala
## visual" para que el campo no explote visualmente cerca de una carga)
func _draw_arrow(origin: Vector2, field: Vector2) -> void:
	var magnitude: float = field.length()
	if magnitude < 1.0:
		return

	var visual_length: float = clamp(log(1.0 + magnitude) * 2.0, 4.0, ARROW_MAX_LENGTH)
	var direction: Vector2 = field.normalized()
	var screen_dir: Vector2 = Vector2(direction.x, -direction.y)  # invertir Y para pantalla
	var end_point: Vector2 = origin + screen_dir * visual_length
	var color: Color = Color(0.3, 0.75, 1.0, 0.85)

	draw_line(origin, end_point, color, 2.0)
	var arrow_dir: Vector2 = (end_point - origin).normalized()
	var perp: Vector2 = Vector2(-arrow_dir.y, arrow_dir.x)
	draw_line(end_point, end_point - arrow_dir * 7.0 + perp * 4.0, color, 2.0)
	draw_line(end_point, end_point - arrow_dir * 7.0 - perp * 4.0, color, 2.0)

# ---------- Paneles de información ----------

## Panel mínimo (arriba a la izquierda): coordenadas del cursor y ayuda de clics.
## Ya no muestra E, Ex, Ey ni V del cursor: cambiaban en cada movimiento del mouse y
## no se podían leer. Esos datos ahora salen en el inspector de la carga seleccionada.
func _draw_cursor_panel() -> void:
	var font: Font = ThemeDB.fallback_font
	var lines: Array = []
	lines.append("x = %.2f m,   y = %.2f m" % [mouse_world_pos.x, mouse_world_pos.y])
	if selected_charge != null:
		var value_uC: float = selected_charge.q / PhysicsConstants.MICRO
		lines.append("Seleccionada: %s" % _format_charge_label(value_uC))
		lines.append("Arrastra: mover   ·   Supr: borrar")
	else:
		lines.append("Click izq: +%.2f µC" % next_charge_uC)
		lines.append("Click der: -%.2f µC" % next_charge_uC)

	draw_rect(Rect2(PANEL_MARGIN_PX, PANEL_MARGIN_PX, LEFT_PANEL_WIDTH, LEFT_PANEL_HEIGHT), Color(0, 0, 0, 0.6))

	for i in range(lines.size()):
		var pos: Vector2 = Vector2(PANEL_MARGIN_PX + PANEL_PADDING_PX, PANEL_MARGIN_PX + 18.0 + i * LINE_HEIGHT_PX)
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, PANEL_FONT_SIZE, Color.WHITE)

	# Línea separadora entre la información y los controles
	var sep_y: float = 84.0
	draw_line(Vector2(PANEL_MARGIN_PX + PANEL_PADDING_PX, sep_y),
			Vector2(PANEL_MARGIN_PX + LEFT_PANEL_WIDTH - PANEL_PADDING_PX, sep_y),
			Color(1, 1, 1, 0.25), 1.0)

## Inspector (arriba a la derecha): estadísticas de la carga seleccionada.
## Las filas las calcula ChargeStats; aquí solo se formatean y se dibujan, así que
## para agregar una magnitud nueva basta con añadirla en charge_stats.gd.
func _draw_inspector_panel() -> void:
	if selected_charge == null:
		return

	var rows: Array = ChargeStats.rows_for([selected_charge], charges)
	var entries: Array = []
	for row in rows:
		if row["kind"] == "header":
			entries.append({"text": row["label"], "header": true})
		else:
			entries.append({"text": _format_row(row), "header": false})
	_draw_panel(entries, true)

## Dibuja un panel de texto semitransparente que se ajusta al ancho del contenido.
## `entries`: Array de Diccionarios {"text": String, "header": bool}.
## Si right_aligned es true, el panel se ancla a la esquina superior derecha.
func _draw_panel(entries: Array, right_aligned: bool) -> void:
	var font: Font = ThemeDB.fallback_font

	var text_width: float = 0.0
	for e in entries:
		var w: float = font.get_string_size(e["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, PANEL_FONT_SIZE).x
		text_width = maxf(text_width, w)

	var width: float = text_width + PANEL_PADDING_PX * 2.0
	var height: float = LINE_HEIGHT_PX * entries.size() + 12.0
	var origin_x: float = PANEL_MARGIN_PX
	if right_aligned:
		origin_x = get_viewport_rect().size.x - width - PANEL_MARGIN_PX

	draw_rect(Rect2(origin_x, PANEL_MARGIN_PX, width, height), Color(0, 0, 0, 0.6))

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var text_color: Color = Color(1.0, 0.85, 0.3) if entry["header"] else Color.WHITE
		var pos: Vector2 = Vector2(origin_x + PANEL_PADDING_PX, PANEL_MARGIN_PX + 18.0 + i * LINE_HEIGHT_PX)
		draw_string(font, pos, entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, PANEL_FONT_SIZE, text_color)

# ---------- Formato de texto ----------

## Convierte una fila de ChargeStats en texto, ej: "|E| = 1.308 × 10^3 N/C"
func _format_row(row: Dictionary) -> String:
	var value: float = row["value"]
	var unit: String = row["unit"]
	var text: String

	match row["kind"]:
		"fixed":
			text = "%.2f" % value
		"signed":
			text = ("+" if value >= 0.0 else "") + ("%.2f" % value)
		"count":
			text = "%d" % int(value)
		"angle":
			text = "-" if is_nan(value) else ("%.1f" % value)
		_:
			text = _format_physics(value)

	var suffix: String = ""
	if unit != "" and text != "-":
		suffix = " " + unit
	return "%s = %s%s" % [row["label"], text, suffix]

## Formatea el valor de una carga en µC con signo explícito, ej: "+1.50 µC"
func _format_charge_label(value_uC: float) -> String:
	if value_uC >= 0.0:
		return "+%.2f µC" % value_uC
	return "%.2f µC" % value_uC

## Notación científica "de física": 1.308 × 10^3  (GDScript NO soporta el
## especificador %e; si se usa, el formato falla). Se usa ^ en vez de superíndices
## porque la fuente por defecto de Godot no dibuja todos los superíndices.
func _format_physics(value: float) -> String:
	if is_nan(value):
		return "-"
	if is_inf(value):
		return "inf" if value > 0.0 else "-inf"
	if absf(value) < 1e-30:
		return "0"

	var exponent: int = int(floor(log(absf(value)) / log(10.0)))
	var mantissa: float = value / pow(10.0, exponent)

	# log() puede fallar por redondeo (p. ej. 1000 da 2.9999999999999996): se corrige.
	if absf(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	elif absf(mantissa) < 1.0:
		mantissa *= 10.0
		exponent -= 1

	# Si al redondear a 3 decimales llega a 10.000, se pasa a la siguiente potencia.
	if roundf(absf(mantissa) * 1000.0) / 1000.0 >= 10.0:
		mantissa /= 10.0
		exponent += 1

	return "%.3f × 10^%d" % [mantissa, exponent]
	
## Acomoda etiqueta, campo de texto y botón DENTRO del panel izquierdo.
## Las posiciones se fijan aquí (no en Main.tscn) para que queden alineadas
## con el rectángulo que dibuja _draw_cursor_panel().
func _layout_left_panel() -> void:
	var x: float = PANEL_MARGIN_PX + PANEL_PADDING_PX
	var w: float = LEFT_PANEL_WIDTH - PANEL_PADDING_PX * 2.0
	charge_value_label.position = Vector2(x, 92.0)
	charge_value_label.size = Vector2(w, 24.0)
	charge_value_input.position = Vector2(x, 118.0)
	charge_value_input.size = Vector2(w, 28.0)
	deselect_button.position = Vector2(x, 154.0)
	deselect_button.size = Vector2(w, 28.0)

func _on_deselect_pressed() -> void:
	charge_value_input.release_focus()
	_deselect()
	queue_redraw()
