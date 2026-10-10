extends Node2D
## Escena principal: permite colocar, seleccionar (una o varias), mover, editar y
## borrar cargas, y visualiza el campo eléctrico en tiempo real.
##
## MODOS (botón "Modo" o tecla M):
## - COLOCAR:      click izq en vacío = carga positiva, click der en vacío = negativa.
## - SELECCIONAR:  click izq en vacío y arrastrar = recuadro de selección.
##
## CONTROLES (en ambos modos):
## - Click izq SOBRE una carga:    la selecciona (arrastra para moverla; si ya
##                                  estaba en un grupo seleccionado, mueve todo el grupo)
## - Ctrl/Shift + click izq:       suma o quita esa carga de la selección
## - Ctrl/Shift + recuadro:        suma las cargas del recuadro a la selección
## - Ctrl + A:                     selecciona todas las cargas
## - Click izq en vacío (modo seleccionar, sin arrastrar): deselecciona
## - Click der SOBRE una carga:    la borra
## - Supr / Backspace:             borra las cargas seleccionadas
## - Esc o botón "Deseleccionar":  deselecciona
## - Rueda del mouse:              zoom (hacia la posición del cursor)
## - Botón central + arrastrar:    mueve la cámara
## - Espacio + click izq arrastrando, o flechas del teclado: también mueven la cámara
## - + / -:                        zoom desde el centro de la pantalla
## - Inicio (Home):                restablece zoom y cámara
## - Campo de texto:               magnitud (µC) de las cargas seleccionadas,
##                                  o de la próxima carga si no hay selección
##
## PANELES:
## - Arriba a la izquierda: coordenadas del cursor, ayuda, campo de valor y botones.
## - Arriba a la derecha:   "inspector" con las estadísticas de la selección
##                          (una carga: campo, potencial, fuerza y energía que le
##                          hacen las demás; varias: carga total, fuerza externa,
##                          comprobación de la 3ª ley y energías).

enum Mode { PLACE, SELECT }

const DEFAULT_PIXELS_PER_METER: float = 80.0
const MIN_PIXELS_PER_METER: float = 20.0
const MAX_PIXELS_PER_METER: float = 400.0
const ZOOM_STEP: float = 1.15
const LINES_REFRESH_DELAY_MS: int = 120  # espera tras el último cambio de vista antes de recalcular líneas
const KEY_PAN_SPEED_PX: float = 400.0    # velocidad de la cámara con las flechas (px/s)
const BG_GRID_TARGET_PX: float = 80.0    # separación aproximada entre líneas de la cuadrícula de fondo
const BOX_MIN_DRAG_PX: float = 5.0       # por debajo de esto, el "recuadro" cuenta como un simple clic
const ARROW_MAX_LENGTH: float = 55.0
const GRID_STEP_PX: int = 60
const MIN_CHARGE_UC: float = 0.01
const LINE_HEIGHT_PX: float = 22.0
const SELECT_RADIUS_PX: float = 18.0
const PANEL_MARGIN_PX: float = 10.0
const PANEL_PADDING_PX: float = 10.0
const PANEL_FONT_SIZE: int = 16
const LEFT_PANEL_WIDTH: float = 330.0
const LEFT_PANEL_HEIGHT: float = 218.0

@onready var charge_value_input: LineEdit = $UI/ChargeValueInput
@onready var charge_value_label: Label = $UI/ChargeValueLabel

var charges: Array = []              # Array de objetos Charge
var mouse_world_pos: Vector2 = Vector2.ZERO
var next_charge_uC: float = 1.0      # magnitud (µC) para la próxima carga a colocar
var mode: int = Mode.PLACE

# Selección (una o varias cargas)
var selected_charges: Array = []
var dragging: bool = false
var drag_anchor_world: Vector2 = Vector2.ZERO   # punto del mundo donde se inició el arrastre
var drag_start_positions: Array = []            # posición inicial de cada carga seleccionada
var box_selecting: bool = false
var box_start_screen: Vector2 = Vector2.ZERO
var box_additive: bool = false

var field_lines: Array = []          # caché de líneas de campo (se recalcula solo cuando hace falta)
var deselect_button: Button
var mode_button: Button

# Cámara
var pixels_per_meter: float = DEFAULT_PIXELS_PER_METER
var camera_center: Vector2 = Vector2.ZERO   # punto del mundo (m) que queda en el centro de la pantalla
var panning: bool = false
var pan_button: int = MOUSE_BUTTON_MIDDLE   # botón con el que se inició el arrastre de cámara
var view_changed_at_ms: int = -1            # -1 = nada pendiente

func _ready() -> void:
	# Dipolo de ejemplo para empezar a experimentar (sección 52, Experimento 2)
	charges.append(Charge.new(Vector2(-2, 0), PhysicsConstants.MICRO))
	charges.append(Charge.new(Vector2(2, 0), -PhysicsConstants.MICRO))
	_recompute_field_lines()

	charge_value_input.text_changed.connect(_on_charge_value_changed)
	charge_value_input.text_submitted.connect(_on_charge_value_submitted)

	# FOCUS_NONE: así Espacio y las flechas no "activan" los botones por accidente
	mode_button = Button.new()
	mode_button.focus_mode = Control.FOCUS_NONE
	mode_button.pressed.connect(_toggle_mode)
	$UI.add_child(mode_button)

	deselect_button = Button.new()
	deselect_button.text = "Deseleccionar (Esc)"
	deselect_button.focus_mode = Control.FOCUS_NONE
	deselect_button.pressed.connect(_on_deselect_pressed)
	$UI.add_child(deselect_button)

	_layout_left_panel()
	_update_mode_button()
	_refresh_selection_ui()

	get_viewport().size_changed.connect(_mark_view_changed)

func _process(delta: float) -> void:
	mouse_world_pos = screen_to_world(get_local_mouse_position())

	# Salvaguardas: si un botón se soltó fuera del área de dibujo (ej. sobre la UI),
	# el evento de "release" pudo no llegarnos, así que revisamos el estado real.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		_recompute_field_lines()

	if box_selecting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box_selection(get_local_mouse_position())

	if panning and not Input.is_mouse_button_pressed(pan_button):
		panning = false
		_mark_view_changed()

	# Flechas del teclado: mueven la cámara (velocidad constante en pantalla, sin importar el zoom)
	if not charge_value_input.has_focus():
		var move: Vector2 = Vector2(
				Input.get_axis("ui_left", "ui_right"),
				Input.get_axis("ui_down", "ui_up"))
		if move != Vector2.ZERO:
			camera_center += move * (KEY_PAN_SPEED_PX / pixels_per_meter) * delta
			_mark_view_changed()

	# Arrastre de la selección (una carga o todo el grupo): conserva las posiciones relativas
	if dragging and not selected_charges.is_empty():
		var shift: Vector2 = mouse_world_pos - drag_anchor_world
		for i in range(selected_charges.size()):
			selected_charges[i].position = drag_start_positions[i] + shift

	# Recalcula las líneas solo cuando la vista dejó de cambiar
	# (evita recalcular en cada paso de la rueda del mouse)
	if view_changed_at_ms >= 0 and not panning \
			and Time.get_ticks_msec() - view_changed_at_ms >= LINES_REFRESH_DELAY_MS:
		view_changed_at_ms = -1
		_recompute_field_lines()

	queue_redraw()

## Recalcula las líneas de campo. NO se llama en cada frame por rendimiento
## (16 líneas × N cargas × hasta 800 pasos): solo cuando se agrega o borra una
## carga, se suelta un arrastre, se confirma un valor numérico o cambia la vista.
func _recompute_field_lines() -> void:
	var top_left: Vector2 = screen_to_world(Vector2.ZERO)
	var bottom_right: Vector2 = screen_to_world(get_viewport_rect().size)
	var view: Rect2 = Rect2(top_left, bottom_right - top_left).abs()
	# Se traza en un área mayor que la visible para que las líneas de cargas
	# que quedan justo fuera de pantalla sigan entrando a la vista.
	var bounds: Rect2 = view.grow(maxf(view.size.x, view.size.y) * 0.5)
	# 1.0 con el zoom por defecto; el paso y los radios de las líneas se escalan con el zoom
	var line_scale: float = DEFAULT_PIXELS_PER_METER / pixels_per_meter
	field_lines = FieldLineGenerator.generate_field_lines(charges, bounds, line_scale)

## Se llama cada vez que el usuario escribe/borra un carácter en el campo de texto.
## Con varias cargas seleccionadas, la magnitud se aplica a todas (cada una conserva su signo).
func _on_charge_value_changed(new_text: String) -> void:
	if not new_text.is_valid_float():
		return
	var value: float = new_text.to_float()
	if value < MIN_CHARGE_UC:
		return

	if not selected_charges.is_empty():
		for charge in selected_charges:
			var sign_val: float = 1.0 if charge.q >= 0.0 else -1.0
			charge.q = sign_val * value * PhysicsConstants.MICRO
	else:
		next_charge_uC = value

func _on_charge_value_submitted(_new_text: String) -> void:
	charge_value_input.release_focus()
	_recompute_field_lines()

# ---------- Entrada ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var screen_pos: Vector2 = get_local_mouse_position()
		var world_pos: Vector2 = screen_to_world(screen_pos)

		if event.pressed:
			var additive: bool = event.is_command_or_control_pressed() or event.shift_pressed
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if Input.is_key_pressed(KEY_SPACE):
						# Espacio + clic izquierdo: arrastrar la cámara (sin botón central)
						panning = true
						pan_button = MOUSE_BUTTON_LEFT
					else:
						_on_left_pressed(screen_pos, world_pos, additive)
				MOUSE_BUTTON_RIGHT:
					_on_right_pressed(screen_pos, world_pos)
				MOUSE_BUTTON_MIDDLE:
					panning = true
					pan_button = MOUSE_BUTTON_MIDDLE
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_at(screen_pos, ZOOM_STEP)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_at(screen_pos, 1.0 / ZOOM_STEP)
			queue_redraw()
		else:
			if event.button_index == pan_button and panning:
				panning = false
				_mark_view_changed()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if dragging:
					dragging = false
					_recompute_field_lines()
				if box_selecting:
					_finish_box_selection(screen_pos)

	elif event is InputEventMouseMotion and panning:
		# Arrastrar la cámara: el mundo sigue al mouse (por eso se invierte el movimiento)
		camera_center += Vector2(-event.relative.x, event.relative.y) / pixels_per_meter

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_DELETE, KEY_BACKSPACE:
				if not selected_charges.is_empty() and not charge_value_input.has_focus():
					_delete_selected()
			KEY_ESCAPE:
				_deselect()
			KEY_A:
				if event.is_command_or_control_pressed() and not event.echo:
					_select_all()
			KEY_M:
				if not event.echo:
					_toggle_mode()
			KEY_HOME:
				_reset_view()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_at(get_viewport_rect().size / 2.0, ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_at(get_viewport_rect().size / 2.0, 1.0 / ZOOM_STEP)

## Clic izquierdo (sin Espacio). `additive` = Ctrl/Shift presionado.
func _on_left_pressed(screen_pos: Vector2, world_pos: Vector2, additive: bool) -> void:
	var hit: Charge = _find_charge_at_screen(screen_pos)

	if hit != null:
		if additive:
			_toggle_in_selection(hit)   # sumar/quitar de la selección, sin arrastrar
			return
		# Si la carga ya está en la selección se conserva el grupo (para moverlo entero)
		if not selected_charges.has(hit):
			_set_selection([hit])
		_begin_drag(world_pos)
	elif mode == Mode.PLACE:
		_add_charge(world_pos, next_charge_uC * PhysicsConstants.MICRO)
		_deselect()
	else:
		# Modo seleccionar: empieza un recuadro (si no se arrastra, es un clic en vacío)
		box_selecting = true
		box_start_screen = screen_pos
		box_additive = additive

## Clic derecho: borra la carga bajo el cursor; en modo colocar y sobre vacío, coloca una negativa.
func _on_right_pressed(screen_pos: Vector2, world_pos: Vector2) -> void:
	var hit: Charge = _find_charge_at_screen(screen_pos)
	if hit != null:
		_delete_charge(hit)
	elif mode == Mode.PLACE:
		_add_charge(world_pos, -next_charge_uC * PhysicsConstants.MICRO)
		_deselect()

## Busca la carga más cercana a una posición de pantalla, dentro del radio de selección.
func _find_charge_at_screen(screen_pos: Vector2) -> Charge:
	for charge in charges:
		var charge_screen: Vector2 = world_to_screen(charge.position)
		if charge_screen.distance_to(screen_pos) <= SELECT_RADIUS_PX:
			return charge
	return null

# ---------- Cargas y selección ----------

## Agrega una carga y refresca las líneas de campo. Todas las altas pasan por aquí
## para no olvidar el recálculo en ningún camino.
func _add_charge(world_pos: Vector2, charge_value: float) -> void:
	charges.append(Charge.new(world_pos, charge_value))
	_recompute_field_lines()

## Borra una carga y refresca las líneas de campo. Todas las bajas pasan por aquí.
func _delete_charge(charge: Charge) -> void:
	charges.erase(charge)
	if selected_charges.has(charge):
		selected_charges.erase(charge)
		dragging = false
		_refresh_selection_ui()
	_recompute_field_lines()

## Borra todas las cargas seleccionadas (Supr / Backspace).
func _delete_selected() -> void:
	for charge in selected_charges.duplicate():
		charges.erase(charge)
	_deselect()
	_recompute_field_lines()

func _set_selection(list: Array) -> void:
	selected_charges = list.duplicate()
	dragging = false
	_refresh_selection_ui()

func _toggle_in_selection(charge: Charge) -> void:
	if selected_charges.has(charge):
		selected_charges.erase(charge)
	else:
		selected_charges.append(charge)
	dragging = false
	_refresh_selection_ui()

func _select_all() -> void:
	_set_selection(charges)

func _deselect() -> void:
	selected_charges.clear()
	dragging = false
	box_selecting = false
	_refresh_selection_ui()

func _on_deselect_pressed() -> void:
	charge_value_input.release_focus()
	_deselect()
	queue_redraw()

## Inicia el arrastre de la selección guardando la posición de cada carga.
func _begin_drag(world_pos: Vector2) -> void:
	dragging = true
	drag_anchor_world = world_pos
	drag_start_positions.clear()
	for charge in selected_charges:
		drag_start_positions.append(charge.position)

## Termina el recuadro de selección: selecciona las cargas que quedaron dentro.
func _finish_box_selection(end_screen: Vector2) -> void:
	if not box_selecting:
		return
	box_selecting = false

	var rect: Rect2 = Rect2(box_start_screen, end_screen - box_start_screen).abs()
	if rect.size.x < BOX_MIN_DRAG_PX and rect.size.y < BOX_MIN_DRAG_PX:
		# Fue un clic en espacio vacío: deselecciona (salvo que sea aditivo)
		if not box_additive:
			_deselect()
		return

	var result: Array = selected_charges.duplicate() if box_additive else []
	for charge in charges:
		if rect.has_point(world_to_screen(charge.position)) and not result.has(charge):
			result.append(charge)
	_set_selection(result)

## Sincroniza el campo de valor, su etiqueta y el botón "Deseleccionar" con la selección actual.
func _refresh_selection_ui() -> void:
	var n: int = selected_charges.size()
	if deselect_button != null:
		deselect_button.disabled = (n == 0)

	charge_value_input.placeholder_text = "1.0"
	if n == 0:
		charge_value_input.text = "%.2f" % next_charge_uC
		charge_value_label.text = "Valor de carga a colocar (µC):"
	elif n == 1:
		var value_uC: float = absf(selected_charges[0].q) / PhysicsConstants.MICRO
		charge_value_input.text = "%.2f" % value_uC
		charge_value_label.text = "Editando carga seleccionada (µC):"
	else:
		charge_value_label.text = "Magnitud de las %d cargas (µC):" % n
		# Si todas tienen la misma magnitud se muestra; si no, el campo queda vacío
		var first: float = absf(selected_charges[0].q)
		var same: bool = true
		for charge in selected_charges:
			if absf(absf(charge.q) - first) > first * 1e-9:
				same = false
				break
		if same:
			charge_value_input.text = "%.2f" % (first / PhysicsConstants.MICRO)
		else:
			charge_value_input.text = ""
			charge_value_input.placeholder_text = "varios"

# ---------- Modos ----------

func _toggle_mode() -> void:
	mode = Mode.SELECT if mode == Mode.PLACE else Mode.PLACE
	box_selecting = false
	_update_mode_button()

func _update_mode_button() -> void:
	if mode_button == null:
		return
	if mode == Mode.PLACE:
		mode_button.text = "Modo: COLOCAR  (M para cambiar)"
	else:
		mode_button.text = "Modo: SELECCIONAR  (M para cambiar)"

# ---------- Zoom y cámara ----------

## Zoom manteniendo fijo el punto del mundo que está bajo `screen_pos`.
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var world_before: Vector2 = screen_to_world(screen_pos)
	pixels_per_meter = clampf(pixels_per_meter * factor, MIN_PIXELS_PER_METER, MAX_PIXELS_PER_METER)
	var world_after: Vector2 = screen_to_world(screen_pos)
	camera_center += world_before - world_after
	_mark_view_changed()

func _reset_view() -> void:
	pixels_per_meter = DEFAULT_PIXELS_PER_METER
	camera_center = Vector2.ZERO
	_mark_view_changed()

## Marca que la vista cambió; _process recalcula las líneas cuando deja de cambiar.
func _mark_view_changed() -> void:
	view_changed_at_ms = Time.get_ticks_msec()

# ---------- Conversión de coordenadas: pantalla (px) <-> mundo físico (m) ----------
# Implementa la sección 9 del documento: screen_to_world() / world_to_screen()
func world_to_screen(world_pos: Vector2) -> Vector2:
	var center: Vector2 = get_viewport_rect().size / 2.0
	var rel: Vector2 = world_pos - camera_center
	# El eje Y de pantalla crece hacia abajo; el eje Y físico crece hacia arriba
	return center + Vector2(rel.x, -rel.y) * pixels_per_meter

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var center: Vector2 = get_viewport_rect().size / 2.0
	var diff: Vector2 = screen_pos - center
	return Vector2(diff.x, -diff.y) / pixels_per_meter + camera_center

# ---------- Dibujo ----------
func _draw() -> void:
	_draw_background_grid()
	_draw_field_lines()
	_draw_field_grid()
	_draw_charges()
	_draw_selection_box()
	_draw_cursor_panel()
	_draw_inspector_panel()

## Paso "redondo" (1, 2 o 5 × 10^n) lo más cercano al valor pedido.
func _nice_step(raw: float) -> float:
	var base: float = pow(10.0, floor(log(raw) / log(10.0)))
	var m: float = raw / base
	if m < 1.5:
		return base
	elif m < 3.5:
		return 2.0 * base
	elif m < 7.5:
		return 5.0 * base
	return 10.0 * base

func _grid_color(index: int) -> Color:
	if index == 0:
		return Color(1, 1, 1, 0.35)     # ejes x = 0 / y = 0
	if index % 5 == 0:
		return Color(1, 1, 1, 0.14)     # línea principal (cada 5 cuadros)
	return Color(1, 1, 1, 0.06)         # línea secundaria

func _grid_width(index: int) -> float:
	return 2.0 if index == 0 else 1.0

## Cuadrícula de fondo en METROS. Se adapta al zoom: el cuadro mide 1, 2 o 5 × 10^n m,
## de modo que siempre quede a unos 80 px de separación en pantalla.
func _draw_background_grid() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = screen_to_world(Vector2.ZERO)
	var bottom_right: Vector2 = screen_to_world(view_size)
	var step: float = _nice_step(BG_GRID_TARGET_PX / pixels_per_meter)
	var decimals: int = maxi(0, -int(floor(log(step) / log(10.0))))
	var font: Font = ThemeDB.fallback_font
	var label_color: Color = Color(1, 1, 1, 0.45)

	# Líneas verticales (x constante)
	var i: int = int(ceil(top_left.x / step))
	while i * step <= bottom_right.x:
		var sx: float = world_to_screen(Vector2(i * step, 0.0)).x
		draw_line(Vector2(sx, 0.0), Vector2(sx, view_size.y), _grid_color(i), _grid_width(i))
		if i % 5 == 0 and i != 0:
			draw_string(font, Vector2(sx + 4.0, view_size.y - 8.0),
					String.num(i * step, decimals) + " m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		i += 1

	# Líneas horizontales (y constante). En pantalla el y físico más alto está arriba.
	var j: int = int(ceil(bottom_right.y / step))
	while j * step <= top_left.y:
		var sy: float = world_to_screen(Vector2(0.0, j * step)).y
		draw_line(Vector2(0.0, sy), Vector2(view_size.x, sy), _grid_color(j), _grid_width(j))
		if j % 5 == 0 and j != 0:
			draw_string(font, Vector2(6.0, sy - 4.0),
					String.num(j * step, decimals) + " m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		j += 1

	# Indicador de escala (abajo a la derecha)
	draw_string(font, Vector2(view_size.x - 280.0, view_size.y - 28.0),
			"Cuadro = %s m   ·   Zoom: %d px/m" % [String.num(step, decimals), int(pixels_per_meter)],
			HORIZONTAL_ALIGNMENT_RIGHT, 270.0, 14, label_color)

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

		if selected_charges.has(charge):
			draw_arc(pos, 18.0, 0.0, TAU, 32, Color.YELLOW, 3.0)

		var value_uC: float = charge.q / PhysicsConstants.MICRO
		var label: String = _format_charge_label(value_uC)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-26, -22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

## Recuadro de selección mientras se arrastra en modo seleccionar.
func _draw_selection_box() -> void:
	if not box_selecting:
		return
	var rect: Rect2 = Rect2(box_start_screen, get_local_mouse_position() - box_start_screen).abs()
	draw_rect(rect, Color(1.0, 0.9, 0.2, 0.12), true)
	draw_rect(rect, Color(1.0, 0.9, 0.2, 0.9), false, 1.5)

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

## Panel izquierdo: coordenadas del cursor y ayuda según el modo y la selección.
## (Los controles —campo de valor y botones— son nodos de UI colocados encima.)
func _draw_cursor_panel() -> void:
	var font: Font = ThemeDB.fallback_font
	var n: int = selected_charges.size()
	var lines: Array = []
	lines.append("x = %.2f m,   y = %.2f m" % [mouse_world_pos.x, mouse_world_pos.y])
	if n == 1:
		var value_uC: float = selected_charges[0].q / PhysicsConstants.MICRO
		lines.append("Seleccionada: %s" % _format_charge_label(value_uC))
		lines.append("Arrastra: mover   ·   Supr: borrar")
	elif n > 1:
		lines.append("Seleccionadas: %d cargas" % n)
		lines.append("Arrastra: mover grupo  ·  Supr: borrar")
	elif mode == Mode.PLACE:
		lines.append("Click izq: +%.2f µC" % next_charge_uC)
		lines.append("Click der: -%.2f µC" % next_charge_uC)
	else:
		lines.append("Arrastra en vacío: recuadro")
		lines.append("Ctrl+clic: sumar  ·  Ctrl+A: todas")

	draw_rect(Rect2(PANEL_MARGIN_PX, PANEL_MARGIN_PX, LEFT_PANEL_WIDTH, LEFT_PANEL_HEIGHT), Color(0, 0, 0, 0.6))

	for i in range(lines.size()):
		var pos: Vector2 = Vector2(PANEL_MARGIN_PX + PANEL_PADDING_PX, PANEL_MARGIN_PX + 18.0 + i * LINE_HEIGHT_PX)
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, PANEL_FONT_SIZE, Color.WHITE)

	# Línea separadora entre la información y los controles
	var sep_y: float = 84.0
	draw_line(Vector2(PANEL_MARGIN_PX + PANEL_PADDING_PX, sep_y),
			Vector2(PANEL_MARGIN_PX + LEFT_PANEL_WIDTH - PANEL_PADDING_PX, sep_y),
			Color(1, 1, 1, 0.25), 1.0)

## Inspector (arriba a la derecha): estadísticas de la selección.
## Las filas las calcula ChargeStats; aquí solo se formatean y se dibujan, así que
## para agregar una magnitud nueva basta con añadirla en charge_stats.gd.
func _draw_inspector_panel() -> void:
	if selected_charges.is_empty():
		return

	var rows: Array = ChargeStats.rows_for(selected_charges, charges)
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

## Acomoda etiqueta, campo de texto y botones DENTRO del panel izquierdo.
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
	mode_button.position = Vector2(x, 190.0)
	mode_button.size = Vector2(w, 28.0)

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
