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
## - Mover el mouse:                    actúa como "punto de prueba" y muestra E, Ex, Ey, V

const PIXELS_PER_METER: float = 80.0
const ARROW_MAX_LENGTH: float = 55.0
const GRID_STEP_PX: int = 60
const MIN_CHARGE_UC: float = 0.01
const LINE_HEIGHT_PX: float = 22.0
const SELECT_RADIUS_PX: float = 18.0

@onready var charge_value_input: LineEdit = $UI/ChargeValueInput
@onready var charge_value_label: Label = $UI/ChargeValueLabel

var charges: Array = []              # Array de objetos Charge
var mouse_world_pos: Vector2 = Vector2.ZERO
var next_charge_uC: float = 1.0      # magnitud (µC) para la próxima carga a colocar
var selected_charge: Charge = null   # carga actualmente seleccionada (o null)
var dragging: bool = false

func _ready() -> void:
	# Dipolo de ejemplo para empezar a experimentar (sección 52, Experimento 2)
	charges.append(Charge.new(Vector2(-2, 0), PhysicsConstants.MICRO))
	charges.append(Charge.new(Vector2(2, 0), -PhysicsConstants.MICRO))

	charge_value_input.text = "%.2f" % next_charge_uC
	charge_value_input.text_changed.connect(_on_charge_value_changed)
	charge_value_input.text_submitted.connect(_on_charge_value_submitted)

func _process(_delta: float) -> void:
	mouse_world_pos = screen_to_world(get_local_mouse_position())

	# Salvaguarda: si el botón se soltó fuera del área de dibujo (ej. sobre la UI),
	# el evento de "release" pudo no llegarnos, así que revisamos el estado real.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false

	if dragging and selected_charge != null:
		selected_charge.position = mouse_world_pos

	queue_redraw()

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
						charges.append(Charge.new(world_pos, next_charge_uC * PhysicsConstants.MICRO))
						_deselect()
				MOUSE_BUTTON_RIGHT:
					var hit2: Charge = _find_charge_at_screen(screen_pos)
					if hit2 != null:
						_delete_charge(hit2)
					else:
						charges.append(Charge.new(world_pos, -next_charge_uC * PhysicsConstants.MICRO))
						_deselect()
			queue_redraw()
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				dragging = false

	elif event is InputEventScreenTouch and event.pressed:
		# Soporte táctil básico para Android (sección 29): un toque = carga positiva
		var world_pos: Vector2 = screen_to_world(event.position)
		charges.append(Charge.new(world_pos, next_charge_uC * PhysicsConstants.MICRO))
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

func _delete_charge(charge: Charge) -> void:
	charges.erase(charge)
	if selected_charge == charge:
		_deselect()

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
	_draw_field_grid()
	_draw_charges()
	_draw_info_panel()

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

## Panel de información del punto de prueba (sección 14 del documento)
func _draw_info_panel() -> void:
	var field: Vector2 = ElectricFieldEngine.total_field(charges, mouse_world_pos)
	var potential: float = ElectricFieldEngine.total_potential(charges, mouse_world_pos)

	var action_line: String
	if selected_charge != null:
		var value_uC: float = selected_charge.q / PhysicsConstants.MICRO
		action_line = "Seleccionada: %s   (arrastra para mover, Supr para borrar)" % _format_charge_label(value_uC)
	else:
		action_line = "Click izq: +%.2f µC      Click der: -%.2f µC" % [next_charge_uC, next_charge_uC]

	var lines: Array = [
		"E  = %s N/C" % _format_scientific(field.length()),
		"Ex = %s N/C" % _format_scientific(field.x),
		"Ey = %s N/C" % _format_scientific(field.y),
		"V  = %s V" % _format_scientific(potential),
		"x = %.2f m, y = %.2f m" % [mouse_world_pos.x, mouse_world_pos.y],
		"",
		action_line,
	]

	var box_height: float = LINE_HEIGHT_PX * lines.size() + 12.0
	draw_rect(Rect2(10, 10, 430, box_height), Color(0, 0, 0, 0.6))

	for i in range(lines.size()):
		var y_pos: float = 28.0 + i * LINE_HEIGHT_PX
		draw_string(ThemeDB.fallback_font, Vector2(20, y_pos), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

## Formatea el valor de una carga en µC con signo explícito, ej: "+1.50 µC"
func _format_charge_label(value_uC: float) -> String:
	if value_uC >= 0.0:
		return "+%.2f µC" % value_uC
	return "%.2f µC" % value_uC

## Notación científica manual (GDScript NO soporta el especificador %e de forma
## nativa; si se usa, TODO el string de formato falla silenciosamente).
func _format_scientific(value: float) -> String:
	if abs(value) < 1e-12:
		return "0.000e+00"
	var exponent: int = int(floor(log(abs(value)) / log(10.0)))
	var mantissa: float = value / pow(10.0, exponent)
	var sign_str: String = "+" if exponent >= 0 else "-"
	var exp_str: String = "%02d" % abs(exponent)
	return "%.3fe%s%s" % [mantissa, sign_str, exp_str]
