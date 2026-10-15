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
## CAPAS:
## - Tecla B o botón "Capa":       alterna entre campo ELÉCTRICO (cargas) y MAGNÉTICO (imanes).
##                                  La capa magnética dibuja flechas de B (verdes) y las
##                                  líneas de campo, que salen del polo N y entran al S.
##
## IMANES (objetos rígidos):
## - Botón "Agregar imán":         crea un imán en el centro de la vista y lo selecciona
## - Click izq SOBRE un imán:      lo selecciona (arrastra para moverlo)
## - Q / E:                        rota el imán seleccionado +15° / -15° (con Shift: 1°)
## - Botones "Rotar":              lo mismo, para pantalla táctil
## - Click der SOBRE un imán, o Supr: lo borra
##
## HILO Y BRÚJULA (Magnetismo): el hilo con corriente es perpendicular a la pantalla (punto = sale, cruz = entra);
## con él seleccionado, el campo de valor edita su CORRIENTE con signo (+ sale, - entra). La brújula alinea su
## aguja con el campo B local (imanes + hilos). Ambos se arrastran, y clic der. o Supr los borra.
##
## DESPLAZAMIENTO: barra vertical (derecha) y horizontal (arriba) arrastrables, como en Word/Paint.
##
## OBJETOS (botón \"Objetos\", desplegable con Magnetismo y Electricidad):
## - Varilla, varillas paralelas (+/-) y anillo: son HERRAMIENTAS de colocacion. Al elegirlas en el
##   menu quedan armadas (modo Colocar): clic izq. en vacio = con carga positiva, clic der. = negativa
##   (en las varillas paralelas invierte cual varilla es la positiva). La magnitud sale del campo de valor.
##   "Carga normal" (en el menu) vuelve a colocar cargas puntuales. Un clic sobre un punto selecciona el
##   grupo entero (para moverlo; Q/E lo gira; clic der. lo borra). Con el grupo seleccionado, el campo de
##   valor edita su CARGA TOTAL CON SIGNO (un valor negativo invierte todos sus puntos).
## - Plano conductor y esfera conductora (a tierra, método de imágenes): se seleccionan con un clic
##   sobre ellos o dentro del metal, se arrastran, el plano gira con Q/E. Las cargas
##   libres son atraídas por ellos y el campo dentro del metal es 0.
##
## PANELES:
## - Arriba a la izquierda: coordenadas del cursor, ayuda, campo de valor y botones.
## - Arriba a la derecha:   "inspector" con las estadísticas de la selección
##                          (una carga: campo, potencial, fuerza y energía que le
##                          hacen las demás; varias: carga total, fuerza externa,
##                          comprobación de la 3ª ley y energías).

enum Mode { PLACE, SELECT }
enum Layer { ELECTRIC, MAGNETIC }

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
const OBJECT_MENU_Y: float = 298.0          # el panel izquierdo termina donde termina el menú de objetos
const SHAPE_POINTS: int = 16                # cargas puntuales por varilla o anillo
const SCROLLBAR_PX: float = 14.0            # grosor de las barras de desplazamiento
const H_SCROLL_AT_TOP: bool = true          # true: barra horizontal arriba; false: abajo (como Word)
const SCROLL_EXTENT_M: float = 40.0         # el mundo desplazable mide al menos ±40 m
const SCROLL_MARGIN_M: float = 5.0          # margen alrededor del contenido
const SHAPE_LENGTH_M: float = 2.0
const PAIR_SEPARATION_M: float = 0.8
const RING_RADIUS_M: float = 1.0
const SPHERE_RADIUS_M: float = 1.0
const SHAPE_EMITTERS: int = 4               # puntos de una forma de los que nacen líneas de campo
const SHAPE_LINES_PER_EMITTER: int = 4      # (pocos, para que recalcular las líneas sea rápido)
const SHAPE_POINT_RADIUS_PX: float = 5.0
const TOOL_NAMES: Dictionary = {   # herramientas de colocacion (nombre corto para el panel)
	"rod": "Varilla",
	"rod_pair": "Varillas paralelas",
	"ring": "Anillo",
}
const PLANE_SPAWN_OFFSET: Vector2 = Vector2(-3.5, 0.0)
const SPHERE_SPAWN_OFFSET: Vector2 = Vector2(0.0, -2.5)
const B_ARROW_REFERENCE: float = 1.0e-8   # T: campo magnético mínimo que se dibuja (y unidad de la escala log)
const B_ARROW_GAIN: float = 6.0           # px por unidad de log(1 + B/referencia)
const MAGNET_LENGTH_M: float = 1.0          # largo del imán nuevo (m)
const MAGNET_POLE_AM: float = 5.0           # intensidad de cada polo (A·m); momento m = qm·L
const MAGNET_HALF_THICKNESS_PX: float = 9.0 # mitad del grosor de la barra al dibujarla
const RIGID_HIT_PX: float = 14.0            # tolerancia del clic sobre un objeto rígido
const WIRE_CURRENT_A: float = 5.0           # corriente de un hilo nuevo (A)
const WIRE_RADIUS_PX: float = 12.0          # radio con el que se dibuja (y se selecciona) el hilo
const COMPASS_RADIUS_PX: float = 24.0       # radio de la brújula en pantalla
const WIRE_LINE_FIRST_M: float = 0.4        # radio del primer círculo de campo alrededor de un hilo
const WIRE_LINE_RATIO: float = 1.6          # cada círculo es 1.6 veces mayor que el anterior
const COMPASS_SPAWN_OFFSET: Vector2 = Vector2(1.5, 0.0)
const ROTATE_STEP_DEG: float = 15.0
const ROTATE_FINE_DEG: float = 1.0          # con Shift

@onready var charge_value_input: LineEdit = $UI/ChargeValueInput
@onready var charge_value_label: Label = $UI/ChargeValueLabel

var charges: Array = []              # Array de objetos Charge
var mouse_world_pos: Vector2 = Vector2.ZERO
var next_charge_uC: float = 1.0      # magnitud (µC) para la próxima carga a colocar
var mode: int = Mode.PLACE
var layer: int = Layer.ELECTRIC

# Selección (una o varias cargas)
var selected_charges: Array = []
var dragging: bool = false
var drag_anchor_world: Vector2 = Vector2.ZERO   # punto del mundo donde se inició el arrastre
var drag_start_positions: Array = []            # posición inicial de cada carga seleccionada
var box_selecting: bool = false
var box_start_screen: Vector2 = Vector2.ZERO
var box_additive: bool = false

var field_lines: Array = []          # caché de líneas de campo (se recalcula solo cuando hace falta)
var magnetic_lines: Array = []       # caché de líneas de campo magnético (solo se calcula en la capa magnética)
var deselect_button: Button
var mode_button: Button
var layer_button: Button
var object_menu: ObjectMenu
var h_scroll: HScrollBar
var v_scroll: VScrollBar
var scroll_rect: Rect2 = Rect2(-40.0, -40.0, 80.0, 80.0)   # mundo que cubren las barras (última actualización)
var syncing_scroll: bool = false                           # evita que fijar las barras mueva la cámara
var rotate_ccw_button: Button
var rotate_cw_button: Button

# Objetos rígidos (por ahora imanes). Su campo magnético se dibujará en el siguiente paso.
var rigid_objects: Array = []        # Array de RigidObject
var selected_rigid: RigidObject = null
var rigid_dragging: bool = false
var rigid_drag_anchor: Vector2 = Vector2.ZERO
var rigid_drag_start_pos: Vector2 = Vector2.ZERO

# Objetos eléctricos: conductores a tierra (ConductorPlane / ConductorSphere) y formas de cargas
var conductors: Array = []
var selected_conductor = null           # ConductorPlane, ConductorSphere o null
var conductor_dragging: bool = false
var conductor_drag_anchor: Vector2 = Vector2.ZERO
var conductor_drag_start_pos: Vector2 = Vector2.ZERO

# Objetos magnéticos sueltos: hilos con corriente (CurrentWire) y brújulas (MagneticCompass)
var magnetics: Array = []
var selected_mag = null                 # CurrentWire, MagneticCompass o null
var mag_dragging: bool = false
var mag_drag_anchor: Vector2 = Vector2.ZERO
var mag_drag_start_pos: Vector2 = Vector2.ZERO
var shape_groups: Array = []            # cada elemento: {"points": Array de Charge, "closed": bool}
var charge_group: Dictionary = {}       # Charge -> su grupo (solo las cargas que pertenecen a una forma)
var armed_tool: String = ""            # herramienta de colocacion: "" = carga normal, o "rod" / "rod_pair" / "ring"

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

	layer_button = Button.new()
	layer_button.focus_mode = Control.FOCUS_NONE
	layer_button.pressed.connect(_toggle_layer)
	$UI.add_child(layer_button)

	object_menu = ObjectMenu.new()
	object_menu.object_requested.connect(_on_object_requested)
	$UI.add_child(object_menu)

	h_scroll = HScrollBar.new()
	h_scroll.step = 0.0
	h_scroll.focus_mode = Control.FOCUS_NONE
	h_scroll.value_changed.connect(_on_h_scroll)
	$UI.add_child(h_scroll)

	v_scroll = VScrollBar.new()
	v_scroll.step = 0.0
	v_scroll.focus_mode = Control.FOCUS_NONE
	v_scroll.value_changed.connect(_on_v_scroll)
	$UI.add_child(v_scroll)

	rotate_ccw_button = Button.new()
	rotate_ccw_button.text = "Rotar +%d° (Q)" % int(ROTATE_STEP_DEG)
	rotate_ccw_button.focus_mode = Control.FOCUS_NONE
	rotate_ccw_button.pressed.connect(_rotate_selected.bind(ROTATE_STEP_DEG))
	$UI.add_child(rotate_ccw_button)

	rotate_cw_button = Button.new()
	rotate_cw_button.text = "Rotar -%d° (E)" % int(ROTATE_STEP_DEG)
	rotate_cw_button.focus_mode = Control.FOCUS_NONE
	rotate_cw_button.pressed.connect(_rotate_selected.bind(-ROTATE_STEP_DEG))
	$UI.add_child(rotate_cw_button)

	_layout_left_panel()
	_update_mode_button()
	_update_layer_button()
	_refresh_selection_ui()

	get_viewport().size_changed.connect(_mark_view_changed)
	get_viewport().size_changed.connect(_layout_left_panel)   # el menú de objetos se ajusta al alto de la ventana

func _process(delta: float) -> void:
	mouse_world_pos = screen_to_world(get_local_mouse_position())

	# Salvaguardas: si un botón se soltó fuera del área de dibujo (ej. sobre la UI),
	# el evento de "release" pudo no llegarnos, así que revisamos el estado real.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		_recompute_field_lines()

	if rigid_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		rigid_dragging = false
		_recompute_field_lines()

	if conductor_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		conductor_dragging = false
		_recompute_field_lines()

	if mag_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mag_dragging = false

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

	# Arrastre de un objeto rígido (imán): se mueve entero, sin deformarse
	if rigid_dragging and selected_rigid != null:
		var rigid_shift: Vector2 = mouse_world_pos - rigid_drag_anchor
		selected_rigid.set_transform(rigid_drag_start_pos + rigid_shift, selected_rigid.rotation)

	# Arrastre de un conductor (plano o esfera)
	if conductor_dragging and selected_conductor != null:
		_set_conductor_pos(selected_conductor, conductor_drag_start_pos + (mouse_world_pos - conductor_drag_anchor))

	# Arrastre de un hilo o una brújula
	if mag_dragging and selected_mag != null:
		selected_mag.position = mag_drag_start_pos + (mouse_world_pos - mag_drag_anchor)

	# Cada brújula gira su aguja hacia el campo B de ese punto
	for item in magnetics:
		if item is MagneticCompass:
			item.follow(_magnetic_field_at(item.position), delta)

	# Recalcula las líneas solo cuando la vista dejó de cambiar
	# (evita recalcular en cada paso de la rueda del mouse)
	if view_changed_at_ms >= 0 and not panning \
			and Time.get_ticks_msec() - view_changed_at_ms >= LINES_REFRESH_DELAY_MS:
		view_changed_at_ms = -1
		_recompute_field_lines()

	_update_scrollbars()
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
	# Solo se calcula la capa visible (ahorra trabajo); al cambiar de capa se recalcula
	if layer == Layer.ELECTRIC:
		# Fuentes = cargas libres + imágenes de los conductores; las líneas nacen solo de las cargas
		# libres y se cortan al llegar a un conductor.
		var sources: Array = InducedSystem.sources(charges, conductors)
		field_lines = FieldLineGenerator.generate_field_lines(sources, bounds, line_scale,
				_free_charges(), conductors, _lines_for())
	else:
		magnetic_lines = FieldLineGenerator.generate_magnetic_lines(_all_poles(), bounds, line_scale)

## Se llama cada vez que el usuario escribe/borra un caracter en el campo de texto.
## - Forma completa seleccionada: el valor es su CARGA TOTAL CON SIGNO (negativo = invierte todos los puntos).
## - Una carga seleccionada: el valor es su carga CON SIGNO.
## - Varias cargas sueltas: se aplica la magnitud a todas (cada una conserva su signo).
## - Sin seleccion: magnitud de la proxima carga a colocar (el signo lo da el boton del mouse).
func _on_charge_value_changed(new_text: String) -> void:
	if not new_text.is_valid_float():
		return
	var value: float = new_text.to_float()
	if absf(value) < MIN_CHARGE_UC:
		return

	# Un hilo seleccionado: el valor es su CORRIENTE con signo (+ sale de la pantalla, - entra)
	if selected_mag != null:
		if selected_mag is CurrentWire:
			selected_mag.current = value
		return

	var group: Array = _selected_group()
	if not group.is_empty():
		var current: float = _group_total(group)
		if current != 0.0:
			var factor: float = value * PhysicsConstants.MICRO / current
			for c in group:
				c.q *= factor
			_mark_view_changed()   # las lineas se recalculan solas poco despues de dejar de escribir
		return

	if selected_charges.size() == 1:
		selected_charges[0].q = value * PhysicsConstants.MICRO
		_mark_view_changed()
	elif selected_charges.size() > 1:
		for charge in selected_charges:
			var sign_val: float = 1.0 if charge.q >= 0.0 else -1.0
			charge.q = sign_val * absf(value) * PhysicsConstants.MICRO
		_mark_view_changed()
	else:
		next_charge_uC = absf(value)

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
				if rigid_dragging:
					rigid_dragging = false
					_recompute_field_lines()
				if conductor_dragging:
					conductor_dragging = false
					_recompute_field_lines()
				mag_dragging = false
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
				elif selected_rigid != null and not charge_value_input.has_focus():
					_delete_rigid(selected_rigid)
				elif selected_conductor != null and not charge_value_input.has_focus():
					_delete_conductor(selected_conductor)
				elif selected_mag != null and not charge_value_input.has_focus():
					_delete_mag(selected_mag)
			KEY_ESCAPE:
				_deselect()
			KEY_A:
				if event.is_command_or_control_pressed() and not event.echo:
					_select_all()
			KEY_M:
				if not event.echo:
					_toggle_mode()
			KEY_B:
				if not event.echo and not charge_value_input.has_focus():
					_toggle_layer()
			KEY_Q:
				if not event.echo and not charge_value_input.has_focus():
					_rotate_selected(ROTATE_FINE_DEG if event.shift_pressed else ROTATE_STEP_DEG)
			KEY_E:
				if not event.echo and not charge_value_input.has_focus():
					_rotate_selected(-ROTATE_FINE_DEG if event.shift_pressed else -ROTATE_STEP_DEG)
			KEY_HOME:
				_reset_view()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_at(get_viewport_rect().size / 2.0, ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_at(get_viewport_rect().size / 2.0, 1.0 / ZOOM_STEP)

## Clic izquierdo (sin Espacio). `additive` = Ctrl/Shift presionado.
func _on_left_pressed(screen_pos: Vector2, world_pos: Vector2, additive: bool) -> void:
	var hit: Charge = _find_charge_at_screen(screen_pos)
	var rigid_hit: RigidObject = _find_rigid_at_screen(screen_pos)
	var mag_hit = _find_mag_at_screen(screen_pos)

	if hit != null:
		if additive:
			_toggle_in_selection(hit)   # sumar/quitar de la selección, sin arrastrar
			return
		# Si la carga ya está en la selección se conserva el grupo (para moverlo entero)
		if not selected_charges.has(hit):
			_set_selection(_group_of(hit))   # si es parte de una forma, se selecciona la forma entera
		_begin_drag(world_pos)
	elif rigid_hit != null:
		if additive:
			return   # Ctrl/Shift sobre un imán: no se mezcla con la selección de cargas
		_select_rigid(rigid_hit)
		_begin_rigid_drag(world_pos)
	elif mag_hit != null:
		if additive:
			return
		_select_mag(mag_hit)
		_begin_mag_drag(world_pos)
	elif _find_conductor_at(world_pos) != null:
		if additive:
			return
		_select_conductor(_find_conductor_at(world_pos))
		_begin_conductor_drag(world_pos)
	elif mode == Mode.PLACE:
		_place_at(world_pos, 1.0)
	else:
		# Modo seleccionar: empieza un recuadro (si no se arrastra, es un clic en vacío)
		box_selecting = true
		box_start_screen = screen_pos
		box_additive = additive

## Clic derecho: borra la carga bajo el cursor; en modo colocar y sobre vacío, coloca una negativa.
func _on_right_pressed(screen_pos: Vector2, world_pos: Vector2) -> void:
	var hit: Charge = _find_charge_at_screen(screen_pos)
	var rigid_hit: RigidObject = _find_rigid_at_screen(screen_pos)
	var mag_hit = _find_mag_at_screen(screen_pos)
	if hit != null:
		_delete_charge(hit)
	elif rigid_hit != null:
		_delete_rigid(rigid_hit)
	elif mag_hit != null:
		_delete_mag(mag_hit)
	elif _find_conductor_at(world_pos) != null:
		_delete_conductor(_find_conductor_at(world_pos))
	elif mode == Mode.PLACE:
		_place_at(world_pos, -1.0)

## Busca la carga más cercana a una posición de pantalla, dentro del radio de selección.
func _find_charge_at_screen(screen_pos: Vector2) -> Charge:
	for charge in charges:
		var charge_screen: Vector2 = world_to_screen(charge.position)
		if charge_screen.distance_to(screen_pos) <= SELECT_RADIUS_PX:
			return charge
	return null

# ---------- Objetos rígidos (imanes) ----------

## Busca el objeto rígido bajo el cursor. Cada polo se une al centro con un
## segmento (la "barra" del imán): si el clic queda cerca de alguno, es un acierto.
func _find_rigid_at_screen(screen_pos: Vector2) -> RigidObject:
	for i in range(rigid_objects.size() - 1, -1, -1):   # el último dibujado queda encima
		var obj: RigidObject = rigid_objects[i]
		var center: Vector2 = world_to_screen(obj.position)
		for pole in obj.world_poles():
			var tip: Vector2 = world_to_screen(pole.position)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(screen_pos, center, tip)
			if closest.distance_to(screen_pos) <= RIGID_HIT_PX:
				return obj
	return null

## Crea un imán en el centro de la vista (desplazado un poco si ya hay otros) y lo selecciona.
func _add_magnet() -> void:
	var offset: Vector2 = Vector2(0.4, -0.4) * float(rigid_objects.size() % 5)
	var obj: RigidObject = RigidObject.make_magnet(camera_center + offset, MAGNET_LENGTH_M, MAGNET_POLE_AM)
	rigid_objects.append(obj)
	_recompute_field_lines()
	_select_rigid(obj)

func _select_rigid(obj: RigidObject) -> void:
	selected_mag = null
	mag_dragging = false
	selected_conductor = null
	conductor_dragging = false
	selected_charges.clear()
	dragging = false
	box_selecting = false
	selected_rigid = obj
	_refresh_selection_ui()

func _delete_rigid(obj: RigidObject) -> void:
	rigid_objects.erase(obj)
	_recompute_field_lines()
	if selected_rigid == obj:
		selected_rigid = null
		rigid_dragging = false
		_refresh_selection_ui()

func _begin_rigid_drag(world_pos: Vector2) -> void:
	rigid_dragging = true
	rigid_drag_anchor = world_pos
	rigid_drag_start_pos = selected_rigid.position

## Rota la selección `deg` grados (positivo = antihorario): un imán sobre su centro,
## un plano conductor sobre su punto, o un grupo de cargas sobre su centroide.
func _rotate_selected(deg: float) -> void:
	var angle: float = deg_to_rad(deg)
	if selected_rigid != null:
		selected_rigid.rotate_by(angle)
	elif selected_conductor is ConductorPlane:
		selected_conductor.rotate_about(selected_conductor.point, angle)
	elif selected_charges.size() > 1:
		var centroid: Vector2 = Vector2.ZERO
		for c in selected_charges:
			centroid += c.position
		centroid /= float(selected_charges.size())
		ChargedShapes.rotate_about(selected_charges, centroid, angle)
	else:
		return
	_recompute_field_lines()
	queue_redraw()

# ---------- Objetos eléctricos (formas de cargas y conductores a tierra) ----------

## Atiende al menu desplegable "Objetos". Varilla, varillas y anillo (y "Carga normal") solo cambian
## la HERRAMIENTA de colocacion; el imán y los conductores se agregan al centro de la vista.
func _on_object_requested(kind: String) -> void:
	var spawn: Vector2 = camera_center + Vector2(0.4, -0.4) * float((shape_groups.size() + conductors.size()) % 5)
	match kind:
		"normal_charge":
			_arm_tool("")
		"rod", "rod_pair", "ring":
			_arm_tool(kind)
		"magnet":
			_add_magnet()
		"wire":
			_add_wire()
		"compass":
			_add_compass()
		"conductor_plane":
			_add_conductor(ConductorPlane.new(spawn + PLANE_SPAWN_OFFSET, Vector2.RIGHT))
		"conductor_sphere":
			_add_conductor(ConductorSphere.new(spawn + SPHERE_SPAWN_OFFSET, SPHERE_RADIUS_M))
	if object_menu != null:
		object_menu.set_active_tool(armed_tool)

## Arma una herramienta de colocacion ("" = carga normal). Pasa a modo Colocar y quita la
## seleccion, asi el campo de valor vuelve a ser "valor de carga a colocar".
func _arm_tool(tool_id: String) -> void:
	armed_tool = tool_id
	mode = Mode.PLACE
	_update_mode_button()
	_deselect()

## Coloca en `world_pos` lo que diga la herramienta armada. sign_val: +1 (clic izq.) o -1 (clic der.).
func _place_at(world_pos: Vector2, sign_val: float) -> void:
	var q: float = sign_val * next_charge_uC * PhysicsConstants.MICRO
	match armed_tool:
		"rod":
			_add_shape(ChargedShapes.make_rod(world_pos, SHAPE_LENGTH_M, 0.0, q, SHAPE_POINTS), false, false)
		"rod_pair":
			_add_shape(ChargedShapes.make_rod_pair(world_pos, SHAPE_LENGTH_M, PAIR_SEPARATION_M, 0.0, q, SHAPE_POINTS), false, false)
		"ring":
			_add_shape(ChargedShapes.make_ring(world_pos, RING_RADIUS_M, q, SHAPE_POINTS), true, false)
		_:
			_add_charge(world_pos, q)
	_deselect()

## Agrega una forma (varilla, anillo...) como grupo de cargas. Con select = true la deja seleccionada.
func _add_shape(points: Array, closed: bool, select: bool = true) -> void:
	var group: Dictionary = {"points": points, "closed": closed}
	shape_groups.append(group)
	for c in points:
		charges.append(c)
		charge_group[c] = group
	_recompute_field_lines()
	if select:
		_set_selection(points)

## Las cargas de la misma forma que `charge` (o solo ella si no es parte de una forma).
func _group_of(charge: Charge) -> Array:
	var group: Variant = charge_group.get(charge)
	if group == null:
		return [charge]
	return group["points"]

## Saca una carga de su forma (al borrarla). Si la forma queda con 1 punto, deja de ser forma.
func _forget_charge(charge: Charge) -> void:
	var group: Variant = charge_group.get(charge)
	if group == null:
		return
	group["points"].erase(charge)
	charge_group.erase(charge)
	if group["points"].size() <= 1:
		for rest in group["points"]:
			charge_group.erase(rest)
		shape_groups.erase(group)

## Si la selección es exactamente UNA forma completa (varilla, anillo...), devuelve sus cargas;
## en cualquier otro caso devuelve un arreglo vacío.
func _selected_group() -> Array:
	if selected_charges.size() < 2:
		return []
	var group: Array = _group_of(selected_charges[0])
	if group.size() != selected_charges.size():
		return []
	for c in selected_charges:
		if not group.has(c):
			return []
	return group

## Carga total CON SIGNO de una forma, en coulombs. Una forma de un solo signo: la suma de sus puntos.
## Una mixta (varillas paralelas): la carga de UNA varilla, con el signo del primer punto
## (la varilla "de referencia"), asi un valor negativo en el campo invierte el par.
func _group_total(group: Array) -> float:
	var positive: float = 0.0
	var negative: float = 0.0
	for c in group:
		if c.q > 0.0:
			positive += c.q
		else:
			negative -= c.q
	var magnitude: float = maxf(positive, negative)
	var reference_is_negative: bool = not group.is_empty() and group[0].q < 0.0
	return -magnitude if reference_is_negative else magnitude

## Cargas que no están dentro de un conductor (solo ellas emiten líneas de campo).
func _free_charges() -> Array:
	var out: Array = []
	for c in charges:
		if not InducedSystem.is_inside_any(c.position, conductors):
			out.append(c)
	return out

## Cuántas líneas emite cada punto de una forma. Se reparten entre pocos puntos
## (SHAPE_EMITTERS) para que recalcular las líneas sea rápido.
func _lines_for() -> Dictionary:
	var result: Dictionary = {}
	for group in shape_groups:
		var positives: Array = []
		for c in group["points"]:
			if c.q > 0.0:
				positives.append(c)
		var n: int = positives.size()
		if n == 0:
			continue
		var chosen: Dictionary = {}
		for k in range(SHAPE_EMITTERS):
			# Abierta (varilla): de extremo a extremo, simétrica. Cerrada (anillo): uniforme.
			var idx: int = int(round(float(k) * float(n if group["closed"] else n - 1) / float(SHAPE_EMITTERS if group["closed"] else SHAPE_EMITTERS - 1)))
			chosen[clampi(idx, 0, n - 1)] = true
		for i in range(n):
			result[positives[i]] = SHAPE_LINES_PER_EMITTER if chosen.has(i) else 0
	return result

func _add_conductor(conductor) -> void:
	conductors.append(conductor)
	_recompute_field_lines()
	_select_conductor(conductor)

func _select_conductor(conductor) -> void:
	selected_mag = null
	mag_dragging = false
	selected_charges.clear()
	dragging = false
	box_selecting = false
	selected_rigid = null
	rigid_dragging = false
	selected_conductor = conductor
	_refresh_selection_ui()

func _delete_conductor(conductor) -> void:
	conductors.erase(conductor)
	if selected_conductor == conductor:
		selected_conductor = null
		conductor_dragging = false
		_refresh_selection_ui()
	_recompute_field_lines()

func _begin_conductor_drag(world_pos: Vector2) -> void:
	conductor_dragging = true
	conductor_drag_anchor = world_pos
	conductor_drag_start_pos = _conductor_pos(selected_conductor)

func _conductor_pos(conductor) -> Vector2:
	return conductor.point if conductor is ConductorPlane else conductor.center

func _set_conductor_pos(conductor, pos: Vector2) -> void:
	conductor.translate_by(pos - _conductor_pos(conductor))

func _conductor_name(conductor) -> String:
	return "Plano conductor a tierra" if conductor is ConductorPlane else "Esfera conductora a tierra"

## Conductor bajo un punto del mundo: dentro del metal, o a pocos píxeles de su superficie.
func _find_conductor_at(world_pos: Vector2):
	var tolerance_m: float = RIGID_HIT_PX / pixels_per_meter
	for i in range(conductors.size() - 1, -1, -1):
		var c = conductors[i]
		if c.contains(world_pos):
			return c
		if c is ConductorPlane and absf(c.signed_distance(world_pos)) <= tolerance_m:
			return c
		if c is ConductorSphere and world_pos.distance_to(c.center) <= c.radius + tolerance_m:
			return c
	return null

## Se puede girar con Q/E: un imán, un plano conductor o un grupo de cargas.
func _can_rotate() -> bool:
	return selected_rigid != null or selected_conductor is ConductorPlane or selected_charges.size() > 1

## Dibuja los conductores: el metal en gris azulado semitransparente y su superficie.
func _draw_conductors() -> void:
	if conductors.is_empty():
		return
	var view_size: Vector2 = get_viewport_rect().size
	var reach: float = view_size.length() / pixels_per_meter * 2.0   # largo suficiente para cruzar la pantalla
	var font: Font = ThemeDB.fallback_font
	var fill: Color = Color(0.62, 0.70, 0.82, 0.28)
	for c in conductors:
		var is_selected: bool = (c == selected_conductor)
		var outline: Color = Color.YELLOW if is_selected else Color(0.82, 0.9, 1.0, 0.9)
		var width: float = 3.0 if is_selected else 2.0
		if c is ConductorPlane:
			var tangent: Vector2 = Vector2(-c.normal.y, c.normal.x)
			var mid: float = (camera_center - c.point).dot(tangent)   # tramo de la recta que está en pantalla
			var a: Vector2 = c.point + tangent * (mid - reach)
			var b: Vector2 = c.point + tangent * (mid + reach)
			var depth: Vector2 = -c.normal * reach                    # el metal está del lado opuesto a la normal
			draw_colored_polygon(PackedVector2Array([world_to_screen(a), world_to_screen(b),
					world_to_screen(b + depth), world_to_screen(a + depth)]), fill)
			draw_line(world_to_screen(a), world_to_screen(b), outline, width)
			var label_at: Vector2 = world_to_screen(c.point + tangent * mid - c.normal * (24.0 / pixels_per_meter))
			draw_string(font, label_at + Vector2(8.0, 0.0), "conductor a tierra (V = 0)",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
		else:
			var center: Vector2 = world_to_screen(c.center)
			var r: float = c.radius * pixels_per_meter
			draw_circle(center, r, fill)
			draw_arc(center, r, 0.0, TAU, 64, outline, width)
			draw_string(font, center + Vector2(-r, 5.0), "conductor a tierra", HORIZONTAL_ALIGNMENT_CENTER,
					r * 2.0, 13, Color(1, 1, 1, 0.75))

## Inspector del conductor seleccionado: geometría, potencial y carga inducida total.
func _draw_conductor_inspector() -> void:
	var c = selected_conductor
	var entries: Array = []
	entries.append({"text": _conductor_name(c), "header": true})
	if c is ConductorPlane:
		entries.append({"text": "Punto: (%.2f, %.2f) m" % [c.point.x, c.point.y], "header": false})
		entries.append({"text": "Normal (lado libre) = %.1f °" % rad_to_deg(c.normal.angle()), "header": false})
	else:
		entries.append({"text": "Centro: (%.2f, %.2f) m" % [c.center.x, c.center.y], "header": false})
		entries.append({"text": "Radio R = %.2f m" % c.radius, "header": false})
	entries.append({"text": "Potencial V = 0 V (a tierra)", "header": false})
	var induced: float = 0.0
	for ch in charges:
		var img: Charge = c.image_for(ch)
		if img != null:
			induced += img.q
	entries.append({"text": "Carga inducida = %+.3f µC" % (induced / PhysicsConstants.MICRO), "header": false})
	_draw_panel(entries, true)

# ---------- Hilos con corriente y brújulas ----------

func _has_wires() -> bool:
	for item in magnetics:
		if item is CurrentWire:
			return true
	return false

## Campo B total (T) en un punto: polos de los imanes + hilos con corriente.
func _magnetic_field_at(world_pos: Vector2) -> Vector2:
	return _magnetic_field_with_poles(_all_poles(), world_pos)

func _magnetic_field_with_poles(poles: Array, world_pos: Vector2) -> Vector2:
	var b: Vector2 = Vector2.ZERO
	if not poles.is_empty():
		b = MagneticFieldEngine.total_field(poles, world_pos)
	for item in magnetics:
		if item is CurrentWire:
			b += item.field_at(world_pos)
	return b

func _mag_name(item) -> String:
	return "Hilo con corriente" if item is CurrentWire else "Brújula"

func _add_wire() -> void:
	var offset: Vector2 = Vector2(0.4, -0.4) * float(magnetics.size() % 5)
	var wire: CurrentWire = CurrentWire.new(camera_center + offset, WIRE_CURRENT_A)
	magnetics.append(wire)
	_select_mag(wire)

func _add_compass() -> void:
	var offset: Vector2 = Vector2(0.4, -0.4) * float(magnetics.size() % 5)
	var compass: MagneticCompass = MagneticCompass.new(camera_center + COMPASS_SPAWN_OFFSET + offset)
	compass.snap(_magnetic_field_at(compass.position))
	magnetics.append(compass)
	_select_mag(compass)

func _select_mag(item) -> void:
	selected_charges.clear()
	dragging = false
	box_selecting = false
	selected_rigid = null
	rigid_dragging = false
	selected_conductor = null
	conductor_dragging = false
	selected_mag = item
	mag_dragging = false
	_refresh_selection_ui()

func _delete_mag(item) -> void:
	magnetics.erase(item)
	if selected_mag == item:
		selected_mag = null
		mag_dragging = false
		_refresh_selection_ui()

func _begin_mag_drag(world_pos: Vector2) -> void:
	mag_dragging = true
	mag_drag_anchor = world_pos
	mag_drag_start_pos = selected_mag.position

## Hilo o brújula bajo el cursor (el último dibujado queda encima).
func _find_mag_at_screen(screen_pos: Vector2):
	for i in range(magnetics.size() - 1, -1, -1):
		var item = magnetics[i]
		var reach: float = (WIRE_RADIUS_PX + 4.0) if item is CurrentWire else COMPASS_RADIUS_PX
		if world_to_screen(item.position).distance_to(screen_pos) <= reach:
			return item
	return null

## Círculos de campo alrededor de cada hilo, con flechas que indican el sentido de B.
func _draw_wire_lines() -> void:
	var color: Color = Color(0.45, 1.0, 0.55, 0.6)
	var view_size: Vector2 = get_viewport_rect().size
	for item in magnetics:
		if not (item is CurrentWire) or absf(item.current) < 1.0e-12:
			continue
		var c: Vector2 = world_to_screen(item.position)
		var limit_px: float = c.distance_to(view_size / 2.0) + view_size.length()
		var turn: float = 1.0 if item.current > 0.0 else -1.0   # +1 antihorario (sale), -1 horario (entra)
		var r_m: float = WIRE_LINE_FIRST_M
		while r_m * pixels_per_meter < limit_px:
			var r_px: float = r_m * pixels_per_meter
			if r_px >= WIRE_RADIUS_PX + 6.0:
				draw_arc(c, r_px, 0.0, TAU, clampi(int(r_px / 4.0), 48, 256), color, 1.5, true)
				for k in range(4):
					var theta: float = float(k) * PI / 2.0 + PI / 4.0
					var tip: Vector2 = c + Vector2(cos(theta), -sin(theta)) * r_px
					var dir: Vector2 = Vector2(-sin(theta), -cos(theta)) * turn   # tangente en pantalla
					var perp: Vector2 = Vector2(-dir.y, dir.x)
					draw_line(tip, tip - dir * 9.0 + perp * 4.5, color, 1.5)
					draw_line(tip, tip - dir * 9.0 - perp * 4.5, color, 1.5)
			r_m *= WIRE_LINE_RATIO

## Dibuja hilos (punto = sale, cruz = entra) y brújulas (aguja roja = norte, apunta a B).
func _draw_magnetic_items() -> void:
	var font: Font = ThemeDB.fallback_font
	for item in magnetics:
		var is_selected: bool = (item == selected_mag)
		var c: Vector2 = world_to_screen(item.position)
		var outline: Color = Color.YELLOW if is_selected else Color(1, 1, 1, 0.85)
		var width: float = 3.0 if is_selected else 1.5
		if item is CurrentWire:
			draw_circle(c, WIRE_RADIUS_PX, Color(0.80, 0.50, 0.18))
			draw_arc(c, WIRE_RADIUS_PX, 0.0, TAU, 24, outline, width)
			if item.current >= 0.0:
				draw_circle(c, 3.5, Color.WHITE)
			else:
				draw_line(c + Vector2(-5.0, -5.0), c + Vector2(5.0, 5.0), Color.WHITE, 2.0)
				draw_line(c + Vector2(-5.0, 5.0), c + Vector2(5.0, -5.0), Color.WHITE, 2.0)
			draw_string(font, c + Vector2(-26.0, -WIRE_RADIUS_PX - 8.0), "I = %+.2f A" % item.current,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		else:
			var r: float = COMPASS_RADIUS_PX
			draw_circle(c, r, Color(0.10, 0.10, 0.14, 0.9))
			draw_arc(c, r, 0.0, TAU, 32, outline, width)
			var dir: Vector2 = Vector2(cos(item.angle), -sin(item.angle))   # al revés en Y: pantalla
			var side: Vector2 = dir.orthogonal() * (r * 0.2)
			var north_color: Color = Color.CRIMSON if item.has_field else Color(0.5, 0.5, 0.5)
			var south_color: Color = Color.ROYAL_BLUE if item.has_field else Color(0.35, 0.35, 0.35)
			draw_colored_polygon(PackedVector2Array([c + dir * r * 0.85, c + side, c - side]), north_color)
			draw_colored_polygon(PackedVector2Array([c - dir * r * 0.85, c + side, c - side]), south_color)
			draw_circle(c, 2.5, Color.WHITE)
			draw_string(font, c + Vector2(-r, -r - 6.0), "Brújula", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 13, Color(1, 1, 1, 0.8))

## Inspector del hilo o la brújula seleccionados.
func _draw_mag_inspector() -> void:
	var item = selected_mag
	var entries: Array = []
	entries.append({"text": _mag_name(item), "header": true})
	entries.append({"text": "x = %.2f m" % item.position.x, "header": false})
	entries.append({"text": "y = %.2f m" % item.position.y, "header": false})
	if item is CurrentWire:
		entries.append({"text": "Corriente I = %+.2f A" % item.current, "header": false})
		entries.append({"text": "Sentido: " + ("sale de la pantalla (punto)" if item.current >= 0.0 else "entra a la pantalla (cruz)"), "header": false})
		entries.append({"text": "B a 1 m = %s T" % _format_physics(item.field_at_one_meter()), "header": false})
	else:
		var b: Vector2 = _magnetic_field_at(item.position)
		entries.append({"text": "|B| = %s T" % _format_physics(b.length()), "header": false})
		if item.has_field:
			entries.append({"text": "Dirección de B = %.1f °" % rad_to_deg(b.angle()), "header": false})
		else:
			entries.append({"text": "Sin campo magnético aquí", "header": false})
	_draw_panel(entries, true)

# ---------- Barras de desplazamiento (como Word / Paint) ----------

## Zona del mundo que cubren las barras: al menos ±SCROLL_EXTENT_M, más todo lo que haya
## puesto (con margen) y siempre la vista actual, para que la barra nunca quede fuera de rango.
func _scroll_world_rect(view_m: Vector2) -> Rect2:
	var rect: Rect2 = Rect2(-SCROLL_EXTENT_M, -SCROLL_EXTENT_M, SCROLL_EXTENT_M * 2.0, SCROLL_EXTENT_M * 2.0)
	for c in charges:
		rect = rect.expand(c.position)
	for obj in rigid_objects:
		rect = rect.expand(obj.position)
	for c in conductors:
		rect = rect.expand(_conductor_pos(c))
	for m in magnetics:
		rect = rect.expand(m.position)
	rect = rect.grow(SCROLL_MARGIN_M)
	return rect.merge(Rect2(camera_center - view_m / 2.0, view_m))

## Coloca las barras en los bordes y sincroniza su posición y tamaño del "pulgar" con la cámara.
func _update_scrollbars() -> void:
	if h_scroll == null or v_scroll == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var bar: float = SCROLLBAR_PX
	var top_edge: float = bar if H_SCROLL_AT_TOP else 0.0
	h_scroll.position = Vector2(0.0, 0.0 if H_SCROLL_AT_TOP else view.y - bar)
	h_scroll.size = Vector2(view.x - bar, bar)
	v_scroll.position = Vector2(view.x - bar, top_edge)
	v_scroll.size = Vector2(bar, view.y - bar)

	var view_m: Vector2 = view / pixels_per_meter
	scroll_rect = _scroll_world_rect(view_m)
	syncing_scroll = true
	h_scroll.min_value = scroll_rect.position.x
	h_scroll.max_value = scroll_rect.end.x
	h_scroll.page = view_m.x
	h_scroll.set_value_no_signal(camera_center.x - view_m.x / 2.0)
	# En pantalla Y crece hacia abajo y en el mundo hacia arriba: el valor 0 de la barra es el borde SUPERIOR
	v_scroll.min_value = 0.0
	v_scroll.max_value = scroll_rect.size.y
	v_scroll.page = view_m.y
	v_scroll.set_value_no_signal(scroll_rect.end.y - (camera_center.y + view_m.y / 2.0))
	syncing_scroll = false

func _on_h_scroll(value: float) -> void:
	if syncing_scroll:
		return
	camera_center.x = value + get_viewport_rect().size.x / pixels_per_meter / 2.0
	_mark_view_changed()

func _on_v_scroll(value: float) -> void:
	if syncing_scroll:
		return
	camera_center.y = scroll_rect.end.y - value - get_viewport_rect().size.y / pixels_per_meter / 2.0
	_mark_view_changed()

## Alto del panel izquierdo: llega hasta donde termina el menú de objetos (abierto o cerrado).
func _left_panel_height() -> float:
	return OBJECT_MENU_Y + object_menu.get_combined_minimum_size().y

# ---------- Capas (eléctrica / magnética) ----------

func _toggle_layer() -> void:
	layer = Layer.MAGNETIC if layer == Layer.ELECTRIC else Layer.ELECTRIC
	_update_layer_button()
	_recompute_field_lines()   # la capa que se muestra ahora puede tener sus líneas desactualizadas

func _update_layer_button() -> void:
	if layer_button == null:
		return
	if layer == Layer.ELECTRIC:
		layer_button.text = "Capa: ELÉCTRICA  (B para cambiar)"
	else:
		layer_button.text = "Capa: MAGNÉTICA  (B para cambiar)"

## Todos los polos magnéticos de todos los objetos rígidos.
func _all_poles() -> Array:
	var poles: Array = []
	for obj in rigid_objects:
		poles.append_array(obj.world_poles())
	return poles

# ---------- Cargas y selección ----------

## Agrega una carga y refresca las líneas de campo. Todas las altas pasan por aquí
## para no olvidar el recálculo en ningún camino.
func _add_charge(world_pos: Vector2, charge_value: float) -> void:
	charges.append(Charge.new(world_pos, charge_value))
	_recompute_field_lines()

## Borra una carga y refresca las líneas de campo. Todas las bajas pasan por aquí.
func _delete_charge(charge: Charge) -> void:
	var was_selected: bool = false
	for c in _group_of(charge).duplicate():     # si es parte de una forma, se borra la forma entera
		charges.erase(c)
		if selected_charges.has(c):
			selected_charges.erase(c)
			was_selected = true
		_forget_charge(c)
	if was_selected:
		dragging = false
		_refresh_selection_ui()
	_recompute_field_lines()

## Borra todas las cargas seleccionadas (Supr / Backspace).
func _delete_selected() -> void:
	for charge in selected_charges.duplicate():
		charges.erase(charge)
		_forget_charge(charge)
	_deselect()
	_recompute_field_lines()

func _set_selection(list: Array) -> void:
	selected_mag = null
	mag_dragging = false
	selected_rigid = null
	rigid_dragging = false
	selected_conductor = null
	conductor_dragging = false
	selected_charges = list.duplicate()
	dragging = false
	_refresh_selection_ui()

func _toggle_in_selection(charge: Charge) -> void:
	selected_mag = null
	mag_dragging = false
	selected_rigid = null
	rigid_dragging = false
	selected_conductor = null
	conductor_dragging = false
	if selected_charges.has(charge):
		selected_charges.erase(charge)
	else:
		selected_charges.append(charge)
	dragging = false
	_refresh_selection_ui()

func _select_all() -> void:
	_set_selection(charges)

func _deselect() -> void:
	selected_mag = null
	mag_dragging = false
	selected_rigid = null
	rigid_dragging = false
	selected_conductor = null
	conductor_dragging = false
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
		deselect_button.disabled = (n == 0 and selected_rigid == null and selected_conductor == null and selected_mag == null)
	if rotate_ccw_button != null:
		rotate_ccw_button.disabled = not _can_rotate()
		rotate_cw_button.disabled = not _can_rotate()

	charge_value_input.placeholder_text = "1.0"
	if selected_mag is CurrentWire:
		charge_value_input.text = "%.2f" % selected_mag.current
		charge_value_label.text = "Corriente (A, + sale, − entra):"
	elif selected_mag != null:
		charge_value_input.text = ""
		charge_value_label.text = "Brújula (sin valor editable)"
	elif n == 0:
		charge_value_input.text = "%.2f" % next_charge_uC
		charge_value_label.text = "Valor de carga a colocar (µC):"
	elif not _selected_group().is_empty():
		charge_value_input.text = "%.2f" % (_group_total(_selected_group()) / PhysicsConstants.MICRO)
		charge_value_label.text = "Carga total (µC, + o −):"
	elif n == 1:
		charge_value_input.text = "%.2f" % (selected_charges[0].q / PhysicsConstants.MICRO)
		charge_value_label.text = "Carga (µC, + o −):"
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
	_draw_conductors()
	if layer == Layer.ELECTRIC:
		_draw_field_lines()
		_draw_field_grid()
	else:
		_draw_magnetic_lines()
		_draw_magnetic_grid()
	_draw_rigid_objects()
	_draw_magnetic_items()
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
	draw_string(font, Vector2(view_size.x - 280.0 - SCROLLBAR_PX, view_size.y - 28.0),
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
		if charge_group.has(charge):
			# Punto de una forma (varilla, anillo): se dibuja pequeño y sin etiqueta
			draw_circle(pos, SHAPE_POINT_RADIUS_PX, color)
			if selected_charges.has(charge):
				draw_arc(pos, SHAPE_POINT_RADIUS_PX + 3.0, 0.0, TAU, 16, Color.YELLOW, 2.0)
			continue
		draw_circle(pos, 12.0, color)

		if selected_charges.has(charge):
			draw_arc(pos, 18.0, 0.0, TAU, 32, Color.YELLOW, 3.0)

		var value_uC: float = charge.q / PhysicsConstants.MICRO
		var label: String = _format_charge_label(value_uC)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-26, -22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

## Líneas de campo magnético pre-calculadas: salen del polo N y entran al S.
func _draw_magnetic_lines() -> void:
	_draw_wire_lines()
	var color: Color = Color(0.45, 1.0, 0.55, 0.6)
	for line in magnetic_lines:
		var screen_points: PackedVector2Array = PackedVector2Array()
		for world_point in line:
			screen_points.append(world_to_screen(world_point))
		if screen_points.size() > 1:
			draw_polyline(screen_points, color, 1.5, true)

## Cuadrícula de flechas de B (mismo esquema que la eléctrica, escala logarítmica).
func _draw_magnetic_grid() -> void:
	var poles: Array = _all_poles()
	if poles.is_empty() and not _has_wires():
		return
	var view_size: Vector2 = get_viewport_rect().size
	var color: Color = Color(0.45, 1.0, 0.55, 0.85)
	var x: float = GRID_STEP_PX / 2.0
	while x < view_size.x:
		var y: float = GRID_STEP_PX / 2.0
		while y < view_size.y:
			var screen_point: Vector2 = Vector2(x, y)
			var b: Vector2 = _magnetic_field_with_poles(poles, screen_to_world(screen_point))
			_draw_arrow(screen_point, b, color, B_ARROW_REFERENCE, B_ARROW_GAIN)
			y += GRID_STEP_PX
		x += GRID_STEP_PX

## Dibuja los objetos rígidos. Cada polo es una mitad de la barra (centro -> polo):
## rojo = norte, azul = sur, con su letra. El seleccionado lleva borde amarillo.
func _draw_rigid_objects() -> void:
	var font: Font = ThemeDB.fallback_font
	for obj in rigid_objects:
		var center: Vector2 = world_to_screen(obj.position)
		var is_selected: bool = (obj == selected_rigid)
		for pole in obj.world_poles():
			var tip: Vector2 = world_to_screen(pole.position)
			var dir: Vector2 = tip - center
			if dir.length() < 1.0:
				continue
			var dir_n: Vector2 = dir.normalized()
			var side: Vector2 = dir_n.orthogonal() * MAGNET_HALF_THICKNESS_PX
			var is_north: bool = pole.strength > 0.0
			var color: Color = Color.CRIMSON if is_north else Color.ROYAL_BLUE

			var quad: PackedVector2Array = PackedVector2Array([center + side, tip + side, tip - side, center - side])
			draw_colored_polygon(quad, color)

			var outline: PackedVector2Array = quad.duplicate()
			outline.append(center + side)
			draw_polyline(outline, Color.YELLOW if is_selected else Color(1, 1, 1, 0.8), 3.0 if is_selected else 1.5)

			var label_pos: Vector2 = tip - dir_n * (MAGNET_HALF_THICKNESS_PX * 1.6) + Vector2(-8.0, 6.0)
			draw_string(font, label_pos, "N" if is_north else "S", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 16, Color.WHITE)

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
	var sources: Array = InducedSystem.sources(charges, conductors)   # cargas libres + imágenes
	var x: float = GRID_STEP_PX / 2.0
	while x < view_size.x:
		var y: float = GRID_STEP_PX / 2.0
		while y < view_size.y:
			var screen_point: Vector2 = Vector2(x, y)
			var world_point: Vector2 = screen_to_world(screen_point)
			if not InducedSystem.is_inside_any(world_point, conductors):   # dentro del metal E = 0
				_draw_arrow(screen_point, ElectricFieldEngine.total_field(sources, world_point))
			y += GRID_STEP_PX
		x += GRID_STEP_PX

## Dibuja una flecha con longitud comprimida logarítmicamente (sección 10: "escala
## visual" para que el campo no explote visualmente cerca de una carga)
func _draw_arrow(origin: Vector2, field: Vector2, color: Color = Color(0.3, 0.75, 1.0, 0.85),
		reference: float = 1.0, gain: float = 2.0) -> void:
	var magnitude: float = field.length()
	if magnitude < reference:
		return

	var visual_length: float = clamp(log(1.0 + magnitude / reference) * gain, 4.0, ARROW_MAX_LENGTH)
	var direction: Vector2 = field.normalized()
	var screen_dir: Vector2 = Vector2(direction.x, -direction.y)  # invertir Y para pantalla
	var end_point: Vector2 = origin + screen_dir * visual_length

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
	if selected_rigid != null:
		lines.append("Seleccionado: %s" % selected_rigid.label)
		lines.append("Arrastrar · Q/E rotar · Supr borrar")
	elif selected_mag != null:
		lines.append("Seleccionado: %s" % _mag_name(selected_mag))
		lines.append("Arrastrar · Supr borrar" + (" · valor = corriente" if selected_mag is CurrentWire else ""))
	elif selected_conductor != null:
		lines.append("Seleccionado: %s" % _conductor_name(selected_conductor))
		lines.append("Arrastrar · Q/E rotar · Supr borrar" if selected_conductor is ConductorPlane else "Arrastrar · Supr borrar")
	elif n == 1:
		var value_uC: float = selected_charges[0].q / PhysicsConstants.MICRO
		lines.append("Seleccionada: %s" % _format_charge_label(value_uC))
		lines.append("Arrastra: mover   ·   Supr: borrar")
	elif not _selected_group().is_empty():
		lines.append("Forma seleccionada: %d cargas" % n)
		lines.append("Arrastrar · Q/E rotar · Supr borrar")
	elif n > 1:
		lines.append("Seleccionadas: %d cargas" % n)
		lines.append("Arrastra: mover grupo  ·  Supr: borrar")
	elif mode == Mode.PLACE and armed_tool != "":
		lines.append("Herramienta: %s" % TOOL_NAMES[armed_tool])
		lines.append("Izq: +%.2f µC  ·  Der: -%.2f µC" % [next_charge_uC, next_charge_uC])
	elif mode == Mode.PLACE:
		lines.append("Click izq: +%.2f µC" % next_charge_uC)
		lines.append("Click der: -%.2f µC" % next_charge_uC)
	else:
		lines.append("Arrastra en vacío: recuadro")
		lines.append("Ctrl+clic: sumar  ·  Ctrl+A: todas")

	draw_rect(Rect2(PANEL_MARGIN_PX, PANEL_MARGIN_PX, LEFT_PANEL_WIDTH, _left_panel_height()), Color(0, 0, 0, 0.6))

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
	if selected_rigid != null:
		_draw_rigid_inspector()
		return
	if selected_conductor != null:
		_draw_conductor_inspector()
		return
	if selected_mag != null:
		_draw_mag_inspector()
		return
	if selected_charges.is_empty():
		return

	# Con conductores, las imágenes cuentan como cargas externas: así la fuerza incluye su atracción.
	var rows: Array = ChargeStats.rows_for(selected_charges, InducedSystem.sources(charges, conductors))
	var entries: Array = []
	for row in rows:
		if row["kind"] == "header":
			entries.append({"text": row["label"], "header": true})
		else:
			entries.append({"text": _format_row(row), "header": false})
	_draw_panel(entries, true)

## Inspector del objeto rígido seleccionado (imán): posición, orientación y momento dipolar.
func _draw_rigid_inspector() -> void:
	var obj: RigidObject = selected_rigid
	var poles: Array = obj.world_poles()
	var entries: Array = []
	entries.append({"text": obj.label, "header": true})
	entries.append({"text": "x = %.2f m" % obj.position.x, "header": false})
	entries.append({"text": "y = %.2f m" % obj.position.y, "header": false})
	entries.append({"text": "Ángulo del eje S→N = %.1f °" % rad_to_deg(wrapf(obj.rotation, -PI, PI)), "header": false})
	if poles.size() == 2:
		entries.append({"text": "Largo L = %.2f m" % (obj.bounding_radius() * 2.0), "header": false})
		entries.append({"text": "Polo qm = %s A·m" % _format_physics(absf(poles[0].strength)), "header": false})
	entries.append({"text": "Momento m = %s A·m²" % _format_physics(obj.magnetic_moment().length()), "header": false})
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
		origin_x = get_viewport_rect().size.x - width - PANEL_MARGIN_PX - SCROLLBAR_PX

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
	layer_button.position = Vector2(x, 226.0)
	layer_button.size = Vector2(w, 28.0)
	var half: float = (w - 8.0) / 2.0
	rotate_ccw_button.position = Vector2(x, 262.0)
	rotate_ccw_button.size = Vector2(half, 28.0)
	rotate_cw_button.position = Vector2(x + half + 8.0, 262.0)
	rotate_cw_button.size = Vector2(half, 28.0)
	object_menu.position = Vector2(x, OBJECT_MENU_Y)
	object_menu.set_width(w)
	# El menú no puede pasar del borde inferior de la ventana: si no cabe, hace scroll por dentro
	object_menu.set_max_height(get_viewport_rect().size.y - OBJECT_MENU_Y - PANEL_MARGIN_PX * 2.0)

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
