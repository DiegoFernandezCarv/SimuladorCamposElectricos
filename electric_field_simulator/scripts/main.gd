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

enum Mode { PLACE, SELECT, PAN }
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
const TOP_BAR_HEIGHT: float = 54.0          # alto de la cinta superior estilo Word
const TOUCH_BUTTON_HEIGHT: float = 40.0     # tamaño accesible para botones táctiles
const SHAPE_POINTS: int = 16                # cargas puntuales por varilla o anillo
const SCROLLBAR_PX: float = 14.0            # grosor de las barras de desplazamiento
const H_SCROLL_AT_TOP: bool = false         # barra horizontal abajo (como Word y Excel)
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

# Optimización de la cuadrícula de flechas (caché de geometría)
var grid_dirty: bool = true
var cached_arrows: Array = []
var cached_mag_arrows: Array = []
var last_grid_step: int = GRID_STEP_PX

# Barra superior estilo cinta (Word Ribbon)
var top_bar: PanelContainer
var top_scroll: ScrollContainer
var ribbon_hbox: HBoxContainer
var object_menu_btn: Button
var object_menu_container: PanelContainer

var place_sign: float = 1.0                     # +1.0 o -1.0 para colocar cargas con un toque en móvil
var deselect_button: Button
var delete_button: Button
var mode_button: Button
var sign_button: Button
var layer_button: Button
var verify_button: Button
var ring_minus_button: Button
var ring_plus_button: Button
var experiment_button: Button
var object_menu: ObjectMenu
var h_scroll: HScrollBar
var v_scroll: VScrollBar
var scroll_rect: Rect2 = Rect2(-40.0, -40.0, 80.0, 80.0)   # mundo que cubren las barras (última actualización)
var syncing_scroll: bool = false                           # evita que fijar las barras mueva la cámara
var rotate_ccw_button: Button
var rotate_cw_button: Button

# Panel de verificación para calculadora
var verification_panel: PanelContainer
var verification_text_edit: TextEdit

# Gestor Académico de Experimentos (JSON / Portapapeles / Archivos)
var experiment_dialog: PanelContainer
var export_json_text: TextEdit
var import_json_text: TextEdit
var import_status_label: Label
var save_file_dialog: FileDialog
var load_file_dialog: FileDialog

# Soporte multitáctil para pellizco (zoom) y arrastre con dos dedos en móvil
var touch_fingers: Dictionary = {}
var initial_pinch_dist: float = 0.0
var initial_pinch_zoom: float = DEFAULT_PIXELS_PER_METER

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

	if not charge_value_input.text_changed.is_connected(_on_charge_value_changed):
		charge_value_input.text_changed.connect(_on_charge_value_changed)
	if not charge_value_input.text_submitted.is_connected(_on_charge_value_submitted):
		charge_value_input.text_submitted.connect(_on_charge_value_submitted)

	# Cinta superior horizontal estilo Word (Ribbon)
	top_bar = PanelContainer.new()
	var ribbon_style: StyleBoxFlat = StyleBoxFlat.new()
	ribbon_style.bg_color = Color(0.09, 0.11, 0.16, 0.96)
	ribbon_style.border_width_bottom = 2
	ribbon_style.border_color = Color(0.24, 0.35, 0.52, 0.8)
	ribbon_style.content_margin_top = 4
	ribbon_style.content_margin_bottom = 4
	ribbon_style.content_margin_left = 8
	ribbon_style.content_margin_right = 8
	top_bar.custom_minimum_size = Vector2(0.0, TOP_BAR_HEIGHT)
	top_bar.add_theme_stylebox_override("panel", ribbon_style)
	$UI.add_child(top_bar)

	top_scroll = ScrollContainer.new()
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_scroll)

	ribbon_hbox = HBoxContainer.new()
	ribbon_hbox.add_theme_constant_override("separation", 8)
	ribbon_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_scroll.add_child(ribbon_hbox)

	experiment_button = Button.new()
	experiment_button.text = "🎓 Experimentos (JSON)"
	experiment_button.focus_mode = Control.FOCUS_NONE
	experiment_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	experiment_button.pressed.connect(_toggle_experiment_dialog)
	ribbon_hbox.add_child(experiment_button)

	object_menu_btn = Button.new()
	object_menu_btn.text = "📦 Objetos [▼]"
	object_menu_btn.focus_mode = Control.FOCUS_NONE
	object_menu_btn.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	object_menu_btn.pressed.connect(_toggle_object_menu)
	ribbon_hbox.add_child(object_menu_btn)

	ribbon_hbox.add_child(_create_ribbon_separator())

	mode_button = Button.new()
	mode_button.focus_mode = Control.FOCUS_NONE
	mode_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	mode_button.pressed.connect(_toggle_mode)
	ribbon_hbox.add_child(mode_button)

	ribbon_hbox.add_child(_create_ribbon_separator())

	charge_value_label.owner = null
	charge_value_label.reparent(ribbon_hbox)
	charge_value_label.text = "q:"
	charge_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	charge_value_input.owner = null
	charge_value_input.reparent(ribbon_hbox)
	charge_value_input.custom_minimum_size = Vector2(75.0, TOUCH_BUTTON_HEIGHT)
	charge_value_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	sign_button = Button.new()
	sign_button.focus_mode = Control.FOCUS_NONE
	sign_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	sign_button.pressed.connect(_toggle_place_sign)
	ribbon_hbox.add_child(sign_button)
	_update_sign_button()

	ribbon_hbox.add_child(_create_ribbon_separator())

	layer_button = Button.new()
	layer_button.focus_mode = Control.FOCUS_NONE
	layer_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	layer_button.pressed.connect(_toggle_layer)
	ribbon_hbox.add_child(layer_button)

	ribbon_hbox.add_child(_create_ribbon_separator())

	delete_button = Button.new()
	delete_button.text = "🗑️ Borrar"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	delete_button.pressed.connect(_on_delete_pressed)
	ribbon_hbox.add_child(delete_button)

	deselect_button = Button.new()
	deselect_button.text = "✕ Deseleccionar"
	deselect_button.focus_mode = Control.FOCUS_NONE
	deselect_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	deselect_button.pressed.connect(_on_deselect_pressed)
	ribbon_hbox.add_child(deselect_button)

	rotate_ccw_button = Button.new()
	rotate_ccw_button.text = "↺ -15° (Q)"
	rotate_ccw_button.focus_mode = Control.FOCUS_NONE
	rotate_ccw_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	rotate_ccw_button.pressed.connect(_rotate_selected.bind(-ROTATE_STEP_DEG))
	ribbon_hbox.add_child(rotate_ccw_button)

	rotate_cw_button = Button.new()
	rotate_cw_button.text = "↻ +15° (E)"
	rotate_cw_button.focus_mode = Control.FOCUS_NONE
	rotate_cw_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	rotate_cw_button.pressed.connect(_rotate_selected.bind(ROTATE_STEP_DEG))
	ribbon_hbox.add_child(rotate_cw_button)

	ring_minus_button = Button.new()
	ring_minus_button.text = "🔘 Anillo −"
	ring_minus_button.focus_mode = Control.FOCUS_NONE
	ring_minus_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	ring_minus_button.pressed.connect(func(): _resize_selected_ring(-0.2))
	ribbon_hbox.add_child(ring_minus_button)

	ring_plus_button = Button.new()
	ring_plus_button.text = "🔘 Anillo +"
	ring_plus_button.focus_mode = Control.FOCUS_NONE
	ring_plus_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	ring_plus_button.pressed.connect(func(): _resize_selected_ring(0.2))
	ribbon_hbox.add_child(ring_plus_button)

	ribbon_hbox.add_child(_create_ribbon_separator())

	verify_button = Button.new()
	verify_button.text = "🔬 Verificación (V)"
	verify_button.focus_mode = Control.FOCUS_NONE
	verify_button.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	verify_button.pressed.connect(_toggle_verification)
	ribbon_hbox.add_child(verify_button)

	# Desplegable flotante de Objetos
	object_menu_container = PanelContainer.new()
	object_menu_container.visible = false
	var obj_style: StyleBoxFlat = StyleBoxFlat.new()
	obj_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	obj_style.border_width_left = 1
	obj_style.border_width_right = 1
	obj_style.border_width_bottom = 2
	obj_style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	obj_style.corner_radius_bottom_left = 6
	obj_style.corner_radius_bottom_right = 6
	obj_style.content_margin_left = 6
	obj_style.content_margin_right = 6
	obj_style.content_margin_top = 6
	obj_style.content_margin_bottom = 6
	object_menu_container.add_theme_stylebox_override("panel", obj_style)

	object_menu = ObjectMenu.new()
	object_menu.object_requested.connect(_on_object_requested)
	object_menu_container.add_child(object_menu)
	$UI.add_child(object_menu_container)

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

	_setup_verification_ui()
	_setup_experiment_dialog()
	_setup_file_dialogs()
	_layout_top_bar()
	_update_mode_button()
	_update_layer_button()
	_refresh_selection_ui()
	_recompute_field_grid()

	if get_viewport() != null:
		get_viewport().size_changed.connect(_mark_view_changed)
		get_viewport().size_changed.connect(_layout_top_bar)

func _process(delta: float) -> void:
	mouse_world_pos = screen_to_world(get_local_mouse_position())

	# Salvaguardas: si un botón se soltó fuera del área de dibujo (ej. sobre la UI),
	# el evento de "release" pudo no llegarnos, así que revisamos el estado real.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		_recompute_field_lines()
		grid_dirty = true

	if rigid_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		rigid_dragging = false
		_recompute_field_lines()
		grid_dirty = true

	if conductor_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		conductor_dragging = false
		_recompute_field_lines()
		grid_dirty = true

	if mag_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mag_dragging = false
		grid_dirty = true

	if box_selecting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box_selection(get_local_mouse_position())

	if panning and not Input.is_mouse_button_pressed(pan_button):
		panning = false
		_mark_view_changed()

	# Flechas del teclado: mueven la cámara (velocidad constante en pantalla, sin importar el zoom)
	if charge_value_input != null and not charge_value_input.has_focus():
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
		grid_dirty = true
		_update_verification_text()

	# Arrastre de un objeto rígido (imán): se mueve entero, sin deformarse
	if rigid_dragging and selected_rigid != null:
		var rigid_shift: Vector2 = mouse_world_pos - rigid_drag_anchor
		selected_rigid.set_transform(rigid_drag_start_pos + rigid_shift, selected_rigid.rotation)
		grid_dirty = true

	# Arrastre de un conductor (plano o esfera)
	if conductor_dragging and selected_conductor != null:
		_set_conductor_pos(selected_conductor, conductor_drag_start_pos + (mouse_world_pos - conductor_drag_anchor))
		grid_dirty = true
		_update_verification_text()

	# Arrastre de un hilo o una brújula
	if mag_dragging and selected_mag != null:
		selected_mag.position = mag_drag_start_pos + (mouse_world_pos - mag_drag_anchor)
		grid_dirty = true

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

	# Recalcula la cuadrícula de flechas solo cuando sea necesario
	if grid_dirty:
		_recompute_field_grid()
		grid_dirty = false

	_update_scrollbars()
	queue_redraw()

## Recalcula las líneas de campo. NO se llama en cada frame por rendimiento
## (16 líneas × N cargas × hasta 800 pasos): solo cuando se agrega o borra una
## carga, se suelta un arrastre, se confirma un valor numérico o cambia la vista.
func _recompute_field_lines() -> void:
	var view_size: Vector2 = _view_size()
	var top_left: Vector2 = screen_to_world(Vector2.ZERO)
	var bottom_right: Vector2 = screen_to_world(view_size)
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
			if object_menu_container != null and object_menu_container.visible:
				_toggle_object_menu(false)
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
					if event.shift_pressed and _selected_shape_group() != null:
						_resize_selected_ring(0.1)
					else:
						_zoom_at(screen_pos, ZOOM_STEP)
				MOUSE_BUTTON_WHEEL_DOWN:
					if event.shift_pressed and _selected_shape_group() != null:
						_resize_selected_ring(-0.1)
					else:
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
				grid_dirty = true

	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_fingers[event.index] = event.position
			if touch_fingers.size() == 2:
				var p_arr: Array = touch_fingers.values()
				initial_pinch_dist = (p_arr[0] as Vector2).distance_to(p_arr[1] as Vector2)
				initial_pinch_zoom = pixels_per_meter
		else:
			touch_fingers.erase(event.index)
			if touch_fingers.size() < 2:
				initial_pinch_dist = 0.0

	elif event is InputEventScreenDrag:
		touch_fingers[event.index] = event.position
		if touch_fingers.size() >= 2 and initial_pinch_dist > 10.0:
			var p_arr: Array = touch_fingers.values()
			var p0: Vector2 = p_arr[0]
			var p1: Vector2 = p_arr[1]
			var cur_dist: float = p0.distance_to(p1)
			var pinch_center: Vector2 = (p0 + p1) * 0.5
			var factor: float = cur_dist / initial_pinch_dist
			var target_zoom: float = clampf(initial_pinch_zoom * factor, MIN_PIXELS_PER_METER, MAX_PIXELS_PER_METER)
			var ratio: float = target_zoom / pixels_per_meter
			_zoom_at(pinch_center, ratio)
			camera_center += Vector2(-event.relative.x, event.relative.y) / pixels_per_meter * 0.5
			grid_dirty = true
			queue_redraw()
		elif panning:
			camera_center += Vector2(-event.relative.x, event.relative.y) / pixels_per_meter
			grid_dirty = true
			queue_redraw()

	elif event is InputEventMouseMotion and panning:
		# Arrastrar la cámara: el mundo sigue al mouse (por eso se invierte el movimiento)
		camera_center += Vector2(-event.relative.x, event.relative.y) / pixels_per_meter
		grid_dirty = true

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_DELETE, KEY_BACKSPACE:
				_on_delete_pressed()
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
			KEY_V:
				if not event.echo and not charge_value_input.has_focus():
					_toggle_verification()
			KEY_BRACKETLEFT:
				if not event.echo and not charge_value_input.has_focus():
					_resize_selected_ring(-0.1)
			KEY_BRACKETRIGHT:
				if not event.echo and not charge_value_input.has_focus():
					_resize_selected_ring(0.1)
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
	if mode == Mode.PAN:
		panning = true
		pan_button = MOUSE_BUTTON_LEFT
		return

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
		_place_at(world_pos, place_sign)
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
	_toggle_object_menu(false)
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
		"manage_experiments":
			_toggle_experiment_dialog(true)
		"save_json":
			_on_save_button_pressed()
		"load_json":
			_on_load_button_pressed()
		"clear_all":
			clear_all()
		"exp_dipole":
			load_experiment("dipole")
		"exp_equal_charges":
			load_experiment("equal_charges")
		"exp_faraday":
			load_experiment("faraday")
		"exp_plane_ground":
			load_experiment("plane_ground")
		"exp_parallel_plates":
			load_experiment("parallel_plates")
		"exp_wire_compasses":
			load_experiment("wire_compasses")
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
			_add_shape(ChargedShapes.make_rod(world_pos, SHAPE_LENGTH_M, 0.0, q, SHAPE_POINTS), false, false, "rod", 0.0, world_pos)
		"rod_pair":
			_add_shape(ChargedShapes.make_rod_pair(world_pos, SHAPE_LENGTH_M, PAIR_SEPARATION_M, 0.0, q, SHAPE_POINTS), false, false, "rod_pair", 0.0, world_pos)
		"ring":
			_add_shape(ChargedShapes.make_ring(world_pos, RING_RADIUS_M, q, SHAPE_POINTS), true, false, "ring", RING_RADIUS_M, world_pos)
		_:
			_add_charge(world_pos, q)
	_deselect()

## Agrega una forma (varilla, anillo...) como grupo de cargas. Con select = true la deja seleccionada.
func _add_shape(points: Array, closed: bool, select: bool = true, type: String = "", radius: float = 0.0, center: Vector2 = Vector2.ZERO) -> void:
	var group: Dictionary = {"points": points, "closed": closed, "type": type, "radius": radius, "center": center}
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
	var view: Vector2 = _view_size()
	var bar: float = SCROLLBAR_PX
	h_scroll.position = Vector2(0.0, view.y - bar)
	h_scroll.size = Vector2(view.x - bar, bar)
	v_scroll.position = Vector2(view.x - bar, TOP_BAR_HEIGHT)
	v_scroll.size = Vector2(bar, view.y - bar - TOP_BAR_HEIGHT)

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

## Sincroniza el campo de valor, su etiqueta y los botones con la selección actual.
func _refresh_selection_ui() -> void:
	var n: int = selected_charges.size()
	var has_selection: bool = (n > 0 or selected_rigid != null or selected_conductor != null or selected_mag != null)
	if deselect_button != null:
		deselect_button.disabled = not has_selection
	if delete_button != null:
		delete_button.disabled = not has_selection
	if rotate_ccw_button != null:
		rotate_ccw_button.disabled = not _can_rotate()
		rotate_cw_button.disabled = not _can_rotate()

	var shape_group = _selected_shape_group()
	var is_ring: bool = (shape_group != null and shape_group.get("type", "") == "ring")
	if ring_minus_button != null and ring_plus_button != null:
		ring_minus_button.disabled = not is_ring
		ring_plus_button.disabled = not is_ring
		if is_ring:
			var r_val: float = shape_group.get("radius", RING_RADIUS_M)
			ring_minus_button.text = "Radio − (%.1fm)" % r_val
			ring_plus_button.text = "Radio + (%.1fm)" % r_val
		else:
			ring_minus_button.text = "Radio Anillo −"
			ring_plus_button.text = "Radio Anillo +"

	if sign_button != null:
		sign_button.visible = (mode == Mode.PLACE)

	if charge_value_input != null:
		charge_value_input.placeholder_text = "1.0"
		if selected_mag is CurrentWire:
			charge_value_input.text = "%.2f" % selected_mag.current
			if charge_value_label != null:
				charge_value_label.text = "Corriente (A, + sale, − entra):"
		elif selected_mag != null:
			charge_value_input.text = ""
			if charge_value_label != null:
				charge_value_label.text = "Brújula (sin valor editable)"
		elif n == 0:
			charge_value_input.text = "%.2f" % next_charge_uC
			if charge_value_label != null:
				charge_value_label.text = "Valor de carga a colocar (µC):"
		elif not _selected_group().is_empty():
			charge_value_input.text = "%.2f" % (_group_total(_selected_group()) / PhysicsConstants.MICRO)
			if charge_value_label != null:
				charge_value_label.text = "Carga total (µC, + o −):"
		elif n == 1:
			charge_value_input.text = "%.2f" % (selected_charges[0].q / PhysicsConstants.MICRO)
			if charge_value_label != null:
				charge_value_label.text = "Carga (µC, + o −):"
		else:
			if charge_value_label != null:
				charge_value_label.text = "Magnitud de las %d cargas (µC):" % n
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

	_update_verification_text()

# ---------- Modos y Acciones Táctiles ----------

func _toggle_mode() -> void:
	if mode == Mode.PLACE:
		mode = Mode.SELECT
	elif mode == Mode.SELECT:
		mode = Mode.PAN
	else:
		mode = Mode.PLACE
	box_selecting = false
	panning = false
	_update_mode_button()
	_refresh_selection_ui()

func _update_mode_button() -> void:
	if mode_button == null:
		return
	match mode:
		Mode.PLACE:
			mode_button.text = "Modo: COLOCAR (M)"
		Mode.SELECT:
			mode_button.text = "Modo: SELECCIONAR (M)"
		Mode.PAN:
			mode_button.text = "Modo: MOVER CÁMARA 🖐️ (M)"

func _toggle_place_sign() -> void:
	place_sign = -1.0 if place_sign > 0.0 else 1.0
	_update_sign_button()

func _update_sign_button() -> void:
	if sign_button == null:
		return
	if place_sign > 0.0:
		sign_button.text = "Carga a colocar: POSITIVA (+)"
	else:
		sign_button.text = "Carga a colocar: NEGATIVA (−)"

func _on_delete_pressed() -> void:
	if not selected_charges.is_empty():
		_delete_selected()
	elif selected_rigid != null:
		rigid_objects.erase(selected_rigid)
		selected_rigid = null
		rigid_dragging = false
		_recompute_field_lines()
		grid_dirty = true
		_refresh_selection_ui()
		queue_redraw()
	elif selected_conductor != null:
		conductors.erase(selected_conductor)
		selected_conductor = null
		conductor_dragging = false
		_recompute_field_lines()
		grid_dirty = true
		_refresh_selection_ui()
		queue_redraw()
	elif selected_mag != null:
		_delete_mag(selected_mag)
		grid_dirty = true
		queue_redraw()

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

func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1152.0, 648.0)

# ---------- Conversión de coordenadas: pantalla (px) <-> mundo físico (m) ----------
# Implementa la sección 9 del documento: screen_to_world() / world_to_screen()
func world_to_screen(world_pos: Vector2) -> Vector2:
	var center: Vector2 = _view_size() / 2.0
	var rel: Vector2 = world_pos - camera_center
	# El eje Y de pantalla crece hacia abajo; el eje Y físico crece hacia arriba
	return center + Vector2(rel.x, -rel.y) * pixels_per_meter

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var center: Vector2 = _view_size() / 2.0
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
	_draw_status_bar()
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

## Cuadrícula de flechas de B (dibujadas desde caché optimizado).
func _draw_magnetic_grid() -> void:
	for a in cached_mag_arrows:
		draw_line(a["origin"], a["end"], a["color"], 2.0)
		draw_line(a["end"], a["p1"], a["color"], 2.0)
		draw_line(a["end"], a["p2"], a["color"], 2.0)

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

## Cuadrícula de vectores de campo eléctrico (dibujadas desde caché optimizado).
func _draw_field_grid() -> void:
	for a in cached_arrows:
		draw_line(a["origin"], a["end"], a["color"], 2.0)
		draw_line(a["end"], a["p1"], a["color"], 2.0)
		draw_line(a["end"], a["p2"], a["color"], 2.0)

## Recalcula el arreglo en caché de flechas de campo eléctrico y magnético.
## Solo se ejecuta cuando grid_dirty es true o cambia la vista/fuentes.
func _recompute_field_grid() -> void:
	cached_arrows.clear()
	cached_mag_arrows.clear()
	var view_size: Vector2 = get_viewport_rect().size
	var is_moving: bool = dragging or panning or rigid_dragging or conductor_dragging or mag_dragging
	var step: float = float(GRID_STEP_PX * 2) if is_moving else float(GRID_STEP_PX)
	last_grid_step = int(step)

	if layer == Layer.ELECTRIC:
		var sources: Array = InducedSystem.sources(charges, conductors)
		if sources.is_empty():
			return
		var x: float = step / 2.0
		while x < view_size.x:
			var y: float = step / 2.0
			while y < view_size.y:
				var screen_point: Vector2 = Vector2(x, y)
				var world_point: Vector2 = screen_to_world(screen_point)
				if not InducedSystem.is_inside_any(world_point, conductors):
					var fld: Vector2 = ElectricFieldEngine.total_field(sources, world_point)
					var arrow: Variant = _make_arrow_geom(screen_point, fld, Color(0.3, 0.75, 1.0, 0.85), 1.0, 2.0)
					if arrow != null:
						cached_arrows.append(arrow)
				y += step
			x += step
	else:
		var poles: Array = _all_poles()
		if poles.is_empty() and not _has_wires():
			return
		var color: Color = Color(0.45, 1.0, 0.55, 0.85)
		var x: float = step / 2.0
		while x < view_size.x:
			var y: float = step / 2.0
			while y < view_size.y:
				var screen_point: Vector2 = Vector2(x, y)
				var b: Vector2 = _magnetic_field_with_poles(poles, screen_to_world(screen_point))
				var arrow: Variant = _make_arrow_geom(screen_point, b, color, B_ARROW_REFERENCE, B_ARROW_GAIN)
				if arrow != null:
					cached_mag_arrows.append(arrow)
				y += step
			x += step

## Precalcula la geometría de una flecha logarítmica para que el dibujado sea ultra-rápido.
func _make_arrow_geom(origin: Vector2, field: Vector2, color: Color, reference: float, gain: float) -> Variant:
	var magnitude: float = field.length()
	if magnitude < reference:
		return null
	var visual_length: float = clamp(log(1.0 + magnitude / reference) * gain, 4.0, ARROW_MAX_LENGTH)
	var direction: Vector2 = field.normalized()
	var screen_dir: Vector2 = Vector2(direction.x, -direction.y)
	var end_point: Vector2 = origin + screen_dir * visual_length
	var arrow_dir: Vector2 = (end_point - origin).normalized()
	var perp: Vector2 = Vector2(-arrow_dir.y, arrow_dir.x)
	var p1: Vector2 = end_point - arrow_dir * 7.0 + perp * 4.0
	var p2: Vector2 = end_point - arrow_dir * 7.0 - perp * 4.0
	return {"origin": origin, "end": end_point, "p1": p1, "p2": p2, "color": color}

# ---------- Paneles de información ----------

## Barra de estado flotante en la esquina inferior izquierda: coordenadas y ayuda contextual.
func _draw_status_bar() -> void:
	var font: Font = ThemeDB.fallback_font
	var n: int = selected_charges.size()
	var text: String = "x = %.2f m,  y = %.2f m" % [mouse_world_pos.x, mouse_world_pos.y]

	if selected_rigid != null:
		text += "  |  Imán: %s (Arrastrar · Q/E rotar · Borrar)" % selected_rigid.label
	elif selected_mag != null:
		text += "  |  %s (Arrastrar · Borrar)" % _mag_name(selected_mag)
	elif selected_conductor != null:
		text += "  |  %s (Arrastrar · Borrar)" % _conductor_name(selected_conductor)
	elif n == 1:
		text += "  |  Carga: %s (Arrastrar · Borrar)" % _format_charge_label(selected_charges[0].q / PhysicsConstants.MICRO)
	elif not _selected_group().is_empty():
		text += "  |  Forma: %d cargas (Arrastrar · Q/E rotar · Borrar)" % n
	elif n > 1:
		text += "  |  %d cargas seleccionadas (Arrastrar grupo · Borrar)" % n
	elif mode == Mode.PLACE and armed_tool != "":
		text += "  |  Herramienta: %s (Tocar para colocar)" % TOOL_NAMES.get(armed_tool, armed_tool)
	elif mode == Mode.PLACE:
		text += "  |  Tocar para colocar carga %s" % ("positiva (+)" if place_sign > 0 else "negativa (−)")
	elif mode == Mode.PAN:
		text += "  |  Modo Mover Cámara: arrastra con el dedo o mouse para desplazar"
	else:
		text += "  |  Arrastra para recuadro · Ctrl+A: todas"

	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var badge_w: float = text_w + 24.0
	var badge_h: float = 28.0
	var vp_size: Vector2 = _view_size()
	var pos_y: float = vp_size.y - SCROLLBAR_PX - badge_h - 8.0
	var pos_x: float = 12.0

	draw_rect(Rect2(pos_x, pos_y, badge_w, badge_h), Color(0.08, 0.10, 0.15, 0.88))
	draw_rect(Rect2(pos_x, pos_y, badge_w, badge_h), Color(0.28, 0.38, 0.55, 0.6), false, 1.0)
	draw_string(font, Vector2(pos_x + 12.0, pos_y + 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.95, 1.0))

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
## Si right_aligned es true, el panel se ancla a la esquina superior derecha (debajo de la barra superior).
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
		origin_x = _view_size().x - width - PANEL_MARGIN_PX - SCROLLBAR_PX

	var origin_y: float = TOP_BAR_HEIGHT + 10.0

	draw_rect(Rect2(origin_x, origin_y, width, height), Color(0.08, 0.10, 0.15, 0.92))
	draw_rect(Rect2(origin_x, origin_y, width, height), Color(0.30, 0.45, 0.70, 0.7), false, 1.5)

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var text_color: Color = Color(1.0, 0.85, 0.3) if entry["header"] else Color.WHITE
		var pos: Vector2 = Vector2(origin_x + PANEL_PADDING_PX, origin_y + 18.0 + i * LINE_HEIGHT_PX)
		draw_string(font, pos, entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, PANEL_FONT_SIZE, text_color)

## Acomoda la barra superior y los diálogos flotantes al tamaño de la ventana.
func _layout_top_bar() -> void:
	var vp_w: float = _view_size().x
	if top_bar != null:
		top_bar.position = Vector2(0.0, 0.0)
		top_bar.size = Vector2(vp_w, TOP_BAR_HEIGHT)

	if object_menu_container != null:
		object_menu_container.position = Vector2(10.0, TOP_BAR_HEIGHT + 2.0)
		object_menu_container.custom_minimum_size.x = 260.0
		if object_menu != null:
			object_menu.set_width(248.0)
			object_menu.set_max_height(_view_size().y - TOP_BAR_HEIGHT - 40.0)

	_layout_verification_panel()
	_layout_experiment_dialog()

func _create_ribbon_separator() -> VSeparator:
	var sep: VSeparator = VSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	sep.custom_minimum_size = Vector2(1.0, 26.0)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return sep

func _toggle_object_menu(force_state = null) -> void:
	if object_menu_container == null:
		return
	var next_state: bool = (not object_menu_container.visible) if (force_state == null) else bool(force_state)
	object_menu_container.visible = next_state
	if object_menu_btn != null:
		object_menu_btn.text = "📦 Objetos [▲]" if next_state else "📦 Objetos [▼]"
	if next_state:
		_layout_top_bar()

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

# ---------- Verificación para Calculadora (Feature A) ----------

## Inicializa la ventana flotante de verificación paso a paso para calculadora.
func _setup_verification_ui() -> void:
	verification_panel = PanelContainer.new()
	verification_panel.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	verification_panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	verification_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "🔬 Verificación Paso a Paso (Calculadora - Ley de Coulomb)"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var copy_btn: Button = Button.new()
	copy_btn.text = "📋 Copiar datos"
	copy_btn.custom_minimum_size = Vector2(120.0, 36.0)
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(_on_copy_verification_pressed)
	header_hbox.add_child(copy_btn)

	var close_btn: Button = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(40.0, 36.0)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): _toggle_verification(false))
	header_hbox.add_child(close_btn)

	verification_text_edit = TextEdit.new()
	verification_text_edit.editable = false
	verification_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	verification_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	verification_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(verification_text_edit)

	$UI.add_child(verification_panel)
	_layout_verification_panel()

## Posiciona y redimensiona el panel de verificación flotante.
func _layout_verification_panel() -> void:
	if verification_panel == null:
		return
	var vp_size: Vector2 = _view_size()
	var panel_w: float = clampf(vp_size.x - 40.0, 480.0, 840.0)
	var panel_h: float = clampf(vp_size.y - TOP_BAR_HEIGHT - 40.0, 360.0, 680.0)
	verification_panel.size = Vector2(panel_w, panel_h)
	verification_panel.position = Vector2(
		maxf(10.0, (vp_size.x - panel_w) / 2.0),
		maxf(TOP_BAR_HEIGHT + 10.0, (vp_size.y - panel_h) / 2.0)
	)

## Abre o cierra el panel de verificación para calculadora.
func _toggle_verification(force_state = null) -> void:
	if verification_panel == null:
		return
	var next_state: bool = (not verification_panel.visible) if (force_state == null) else bool(force_state)
	verification_panel.visible = next_state
	if next_state:
		_layout_verification_panel()
		_update_verification_text()

## Actualiza el texto de verificación si el panel está abierto.
func _update_verification_text() -> void:
	if verification_panel == null or not verification_panel.visible:
		return
	var sources: Array = InducedSystem.sources(charges, conductors)
	verification_text_edit.text = ChargeStats.verification_text(selected_charges, sources)

## Copia el informe de verificación al portapapeles del sistema operativo.
func _on_copy_verification_pressed() -> void:
	if verification_text_edit != null:
		DisplayServer.clipboard_set(verification_text_edit.text)

# ---------- Redimensionar formas (Anillo / Jaula de Faraday) ----------

## Si la selección contiene una sola forma, devuelve el diccionario del grupo; si no, null.
func _selected_shape_group() -> Variant:
	if selected_charges.size() < 2:
		return null
	var group: Variant = charge_group.get(selected_charges[0])
	if group == null:
		return null
	if group["points"].size() != selected_charges.size():
		return null
	for c in selected_charges:
		if not group["points"].has(c):
			return null
	return group

## Cambia el radio del anillo seleccionado uniformemente redistribuyendo sus cargas.
func _resize_selected_ring(delta_radius: float) -> void:
	var group: Variant = _selected_shape_group()
	if group == null or group.get("type", "") != "ring":
		return
	var pts: Array = group.get("points", [])
	if pts.is_empty():
		return
	var center_sum: Vector2 = Vector2.ZERO
	for p in pts:
		center_sum += p.position
	group["center"] = center_sum / float(pts.size())
	var current_r: float = group.get("radius", RING_RADIUS_M)
	var new_r: float = clampf(current_r + delta_radius, 0.3, 10.0)
	ChargedShapes.resize_ring(group, new_r)
	_recompute_field_lines()
	grid_dirty = true
	_update_verification_text()
	_refresh_selection_ui()
	queue_redraw()

# ---------- Gestor Académico de Experimentos (JSON / Portapapeles / Archivos) ----------

func _setup_experiment_dialog() -> void:
	experiment_dialog = PanelContainer.new()
	experiment_dialog.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	style.border_color = Color(0.3, 0.6, 1.0, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	experiment_dialog.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	experiment_dialog.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Encabezado
	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "🎓 Gestor de Experimentos (Exportar / Importar JSON)"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(44.0, 38.0)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): _toggle_experiment_dialog(false))
	header_hbox.add_child(close_btn)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Herramienta académica para docentes y estudiantes: comparte simulaciones por WhatsApp, Teams o archivos."
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.modulate = Color(0.85, 0.9, 1.0, 0.85)
	vbox.add_child(desc_lbl)

	# Columnas: Izquierda = Exportar, Derecha = Importar
	var columns_hbox: HBoxContainer = HBoxContainer.new()
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(columns_hbox)

	# --- Columna Exportar ---
	var exp_vbox: VBoxContainer = VBoxContainer.new()
	exp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(exp_vbox)

	var exp_title: Label = Label.new()
	exp_title.text = "📤 Exportar Escenario Actual"
	exp_title.add_theme_font_size_override("font_size", 14)
	exp_vbox.add_child(exp_title)

	export_json_text = TextEdit.new()
	export_json_text.editable = false
	export_json_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	export_json_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	exp_vbox.add_child(export_json_text)

	var exp_btn_row: HBoxContainer = HBoxContainer.new()
	exp_btn_row.add_theme_constant_override("separation", 8)
	exp_vbox.add_child(exp_btn_row)

	var copy_btn: Button = Button.new()
	copy_btn.text = "📋 Copiar JSON"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(_on_copy_export_json_pressed)
	exp_btn_row.add_child(copy_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "💾 Guardar Archivo"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save_button_pressed)
	exp_btn_row.add_child(save_btn)

	# --- Columna Importar ---
	var imp_vbox: VBoxContainer = VBoxContainer.new()
	imp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	imp_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(imp_vbox)

	var imp_title: Label = Label.new()
	imp_title.text = "📥 Importar / Cargar Escenario"
	imp_title.add_theme_font_size_override("font_size", 14)
	imp_vbox.add_child(imp_title)

	import_json_text = TextEdit.new()
	import_json_text.placeholder_text = "Pega aquí el código JSON enviado por el profesor o compañero..."
	import_json_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	import_json_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	imp_vbox.add_child(import_json_text)

	var imp_btn_row: HBoxContainer = HBoxContainer.new()
	imp_btn_row.add_theme_constant_override("separation", 8)
	imp_vbox.add_child(imp_btn_row)

	var paste_btn: Button = Button.new()
	paste_btn.text = "📋 Pegar Portapapeles"
	paste_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paste_btn.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	paste_btn.focus_mode = Control.FOCUS_NONE
	paste_btn.pressed.connect(_on_paste_import_json_pressed)
	imp_btn_row.add_child(paste_btn)

	var open_btn: Button = Button.new()
	open_btn.text = "📂 Cargar Archivo"
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.pressed.connect(_on_load_button_pressed)
	imp_btn_row.add_child(open_btn)

	var apply_btn: Button = Button.new()
	apply_btn.text = "🚀 Cargar Escenario en Simulador"
	apply_btn.custom_minimum_size = Vector2(0.0, TOUCH_BUTTON_HEIGHT)
	apply_btn.focus_mode = Control.FOCUS_NONE
	apply_btn.pressed.connect(_apply_imported_json)
	imp_vbox.add_child(apply_btn)

	# Pie de página / Estado
	import_status_label = Label.new()
	import_status_label.text = "Listo para exportar o importar simulaciones."
	import_status_label.add_theme_font_size_override("font_size", 13)
	import_status_label.modulate = Color(0.5, 0.85, 1.0)
	vbox.add_child(import_status_label)

	$UI.add_child(experiment_dialog)
	_layout_experiment_dialog()

func _layout_experiment_dialog() -> void:
	if experiment_dialog == null:
		return
	var vp_size: Vector2 = _view_size()
	var panel_w: float = clampf(vp_size.x - 40.0, 520.0, 880.0)
	var panel_h: float = clampf(vp_size.y - TOP_BAR_HEIGHT - 40.0, 420.0, 680.0)
	experiment_dialog.size = Vector2(panel_w, panel_h)
	experiment_dialog.position = Vector2(
		maxf(10.0, (vp_size.x - panel_w) / 2.0),
		maxf(TOP_BAR_HEIGHT + 10.0, (vp_size.y - panel_h) / 2.0)
	)

func _toggle_experiment_dialog(force_state = null) -> void:
	if experiment_dialog == null:
		return
	var next_state: bool = (not experiment_dialog.visible) if (force_state == null) else bool(force_state)
	experiment_dialog.visible = next_state
	if next_state:
		if export_json_text != null:
			export_json_text.text = get_simulation_json_string()
		if import_status_label != null:
			import_status_label.text = "Listo para exportar o importar simulaciones."
			import_status_label.modulate = Color(0.5, 0.85, 1.0)
		_layout_experiment_dialog()

func _on_copy_export_json_pressed() -> void:
	if export_json_text != null:
		DisplayServer.clipboard_set(export_json_text.text)
		if import_status_label != null:
			import_status_label.text = "✅ JSON copiado al portapapeles. Listo para enviar por chat/correo."
			import_status_label.modulate = Color(0.4, 1.0, 0.5)

func _on_paste_import_json_pressed() -> void:
	var clip_text: String = DisplayServer.clipboard_get().strip_edges()
	if clip_text.is_empty():
		if import_status_label != null:
			import_status_label.text = "⚠️ El portapapeles está vacío o no contiene texto."
			import_status_label.modulate = Color.YELLOW
		return
	if import_json_text != null:
		import_json_text.text = clip_text
		if import_status_label != null:
			import_status_label.text = "📋 Texto pegado desde el portapapeles. Presiona 'Cargar Escenario'."
			import_status_label.modulate = Color(0.4, 0.85, 1.0)

func _apply_imported_json() -> void:
	if import_json_text == null:
		return
	var text: String = import_json_text.text.strip_edges()
	if text.is_empty():
		if import_status_label != null:
			import_status_label.text = "⚠️ Por favor ingresa o pega el JSON primero."
			import_status_label.modulate = Color.YELLOW
		return
	var res: Dictionary = load_from_json_string(text)
	if res.get("success", false):
		if import_status_label != null:
			import_status_label.text = "✅ " + res.get("message", "Simulación cargada exitosamente.")
			import_status_label.modulate = Color(0.4, 1.0, 0.5)
	else:
		if import_status_label != null:
			import_status_label.text = "❌ " + res.get("error", "Error al procesar el JSON.")
			import_status_label.modulate = Color(1.0, 0.4, 0.4)

func _configure_file_dialog(fd: FileDialog) -> void:
	if fd == null:
		return
	var favs: PackedStringArray = []
	var docs: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var downs: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var desk: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var user_data: String = OS.get_user_data_dir()

	# Agregar carpetas conocidas a Favoritos
	if not downs.is_empty() and DirAccess.dir_exists_absolute(downs) and not favs.has(downs):
		favs.append(downs)
	if not docs.is_empty() and DirAccess.dir_exists_absolute(docs) and not favs.has(docs):
		favs.append(docs)
	if not desk.is_empty() and DirAccess.dir_exists_absolute(desk) and not favs.has(desk):
		favs.append(desk)
	if not user_data.is_empty() and DirAccess.dir_exists_absolute(user_data) and not favs.has(user_data):
		favs.append(user_data)

	# Rutas comunes en Android / móvil
	if OS.get_name() == "Android":
		var android_storage: String = "/storage/emulated/0/Download"
		if DirAccess.dir_exists_absolute(android_storage) and not favs.has(android_storage):
			favs.append(android_storage)
		var android_docs: String = "/storage/emulated/0/Documents"
		if DirAccess.dir_exists_absolute(android_docs) and not favs.has(android_docs):
			favs.append(android_docs)

	fd.set_favorite_list(favs)

	# Carpeta predeterminada: preferir Documentos o Descargas
	var target_dir: String = ""
	if not docs.is_empty() and DirAccess.dir_exists_absolute(docs):
		target_dir = docs
	elif not downs.is_empty() and DirAccess.dir_exists_absolute(downs):
		target_dir = downs
	elif not favs.is_empty():
		target_dir = favs[0]
	else:
		target_dir = user_data

	fd.current_dir = target_dir

func _setup_file_dialogs() -> void:
	save_file_dialog = FileDialog.new()
	save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_file_dialog.filters = PackedStringArray(["*.json ; Archivos de Simulación JSON"])
	save_file_dialog.file_selected.connect(_on_save_file_selected)
	_configure_file_dialog(save_file_dialog)
	$UI.add_child(save_file_dialog)

	load_file_dialog = FileDialog.new()
	load_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_file_dialog.filters = PackedStringArray(["*.json ; Archivos de Simulación JSON"])
	load_file_dialog.file_selected.connect(_on_load_file_selected)
	_configure_file_dialog(load_file_dialog)
	$UI.add_child(load_file_dialog)

func _on_save_button_pressed() -> void:
	if save_file_dialog != null:
		_configure_file_dialog(save_file_dialog)
		save_file_dialog.popup_centered(Vector2i(700, 520))
	else:
		save_to_json()

func _on_load_button_pressed() -> void:
	if load_file_dialog != null:
		_configure_file_dialog(load_file_dialog)
		load_file_dialog.popup_centered(Vector2i(700, 520))
	else:
		load_from_json()

func _on_save_file_selected(path: String) -> void:
	var ok: bool = save_to_json(path)
	if import_status_label != null:
		import_status_label.text = ("✅ Archivo guardado con éxito: %s" % path.get_file()) if ok else "❌ Error al guardar archivo."
		import_status_label.modulate = Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.4, 0.4)

func _on_load_file_selected(path: String) -> void:
	var ok: bool = load_from_json(path)
	if import_status_label != null:
		import_status_label.text = ("✅ Archivo cargado con éxito: %s" % path.get_file()) if ok else "❌ Error al cargar archivo."
		import_status_label.modulate = Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.4, 0.4)

# ---------- Guardar / Cargar JSON y Experimentos Predefinidos ----------

## Genera el texto JSON completo con todo el estado del escenario.
func get_simulation_json_string() -> String:
	var data: Dictionary = {
		"version": 1,
		"camera_center": [camera_center.x, camera_center.y],
		"pixels_per_meter": pixels_per_meter,
		"layer": layer,
		"charges": [],
		"shape_groups": [],
		"conductors": [],
		"rigid_objects": [],
		"wires": [],
		"compasses": []
	}

	var charge_to_idx: Dictionary = {}
	for i in range(charges.size()):
		var c: Charge = charges[i]
		charge_to_idx[c] = i
		data["charges"].append({
			"x": c.position.x,
			"y": c.position.y,
			"q": c.q
		})

	for g in shape_groups:
		var indices: Array = []
		for p in g.get("points", []):
			if charge_to_idx.has(p):
				indices.append(charge_to_idx[p])
		data["shape_groups"].append({
			"closed": g.get("closed", false),
			"type": g.get("type", ""),
			"radius": g.get("radius", 0.0),
			"center": [g.get("center", Vector2.ZERO).x, g.get("center", Vector2.ZERO).y],
			"indices": indices
		})

	for cond in conductors:
		if cond is ConductorPlane:
			data["conductors"].append({
				"kind": "plane",
				"point": [cond.point.x, cond.point.y],
				"normal": [cond.normal.x, cond.normal.y]
			})
		elif cond is ConductorSphere:
			data["conductors"].append({
				"kind": "sphere",
				"center": [cond.center.x, cond.center.y],
				"radius": cond.radius
			})

	for obj in rigid_objects:
		data["rigid_objects"].append({
			"x": obj.position.x,
			"y": obj.position.y,
			"rotation": obj.rotation,
			"label": obj.label
		})

	for item in magnetics:
		if item is CurrentWire:
			data["wires"].append({
				"x": item.position.x,
				"y": item.position.y,
				"current": item.current
			})
		elif item is MagneticCompass:
			data["compasses"].append({
				"x": item.position.x,
				"y": item.position.y
			})

	return JSON.stringify(data, "  ")

## Carga un escenario a partir de un texto JSON. Devuelve un Dictionary con el resultado.
func load_from_json_string(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	var err = json.parse(text)
	if err != OK:
		return {"success": false, "error": "Error al parsear JSON: %s (línea %d)" % [json.get_error_message(), json.get_error_line()]}

	if not (json.data is Dictionary):
		return {"success": false, "error": "El JSON debe contener un objeto raíz {}"}

	var data: Dictionary = json.data
	clear_all()

	if data.has("camera_center") and data["camera_center"] is Array and data["camera_center"].size() >= 2:
		camera_center = Vector2(float(data["camera_center"][0]), float(data["camera_center"][1]))
	if data.has("pixels_per_meter"):
		pixels_per_meter = float(data["pixels_per_meter"])
	if data.has("layer"):
		layer = int(data["layer"])
		_update_layer_button()

	var loaded_charges: Array = []
	for cd in data.get("charges", []):
		var c: Charge = Charge.new(Vector2(float(cd["x"]), float(cd["y"])), float(cd["q"]))
		charges.append(c)
		loaded_charges.append(c)

	for gd in data.get("shape_groups", []):
		var pts: Array = []
		for idx in gd.get("indices", []):
			var i_int: int = int(idx)
			if i_int >= 0 and i_int < loaded_charges.size():
				pts.append(loaded_charges[i_int])
		var c_arr = gd.get("center", [0.0, 0.0])
		var center_vec: Vector2 = Vector2(float(c_arr[0]), float(c_arr[1]))
		_add_shape(pts, gd.get("closed", false), false, gd.get("type", ""), float(gd.get("radius", 0.0)), center_vec)

	for cond in data.get("conductors", []):
		if cond.get("kind") == "plane":
			var pt = Vector2(float(cond["point"][0]), float(cond["point"][1]))
			var nrm = Vector2(float(cond["normal"][0]), float(cond["normal"][1]))
			_add_conductor(ConductorPlane.new(pt, nrm))
		elif cond.get("kind") == "sphere":
			var c = Vector2(float(cond["center"][0]), float(cond["center"][1]))
			_add_conductor(ConductorSphere.new(c, float(cond["radius"])))

	for rd in data.get("rigid_objects", []):
		var obj: RigidObject = RigidObject.make_magnet(Vector2(float(rd["x"]), float(rd["y"])), MAGNET_LENGTH_M, MAGNET_POLE_AM, float(rd.get("rotation", 0.0)))
		rigid_objects.append(obj)

	for wd in data.get("wires", []):
		var wire: CurrentWire = CurrentWire.new(Vector2(float(wd["x"]), float(wd["y"])), float(wd["current"]))
		magnetics.append(wire)

	for comp in data.get("compasses", []):
		var compass: MagneticCompass = MagneticCompass.new(Vector2(float(comp["x"]), float(comp["y"])))
		magnetics.append(compass)

	_recompute_field_lines()
	grid_dirty = true
	_refresh_selection_ui()
	queue_redraw()

	var summary: String = "Cargadas: %d cargas" % loaded_charges.size()
	if not conductors.is_empty():
		summary += ", %d conductor(es)" % conductors.size()
	if not rigid_objects.is_empty():
		summary += ", %d imán(es)" % rigid_objects.size()
	if not magnetics.is_empty():
		summary += ", %d objeto(s) magnético(s)" % magnetics.size()
	return {"success": true, "message": summary}

## Guarda todo el estado del escenario en formato JSON en un archivo.
func save_to_json(path: String = "user://simulation.json") -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(get_simulation_json_string())
	file.close()
	print("Simulación guardada con éxito en: ", path)
	return true

## Carga un escenario previamente guardado en formato JSON desde un archivo.
func load_from_json(path: String = "user://simulation.json") -> bool:
	if not FileAccess.file_exists(path):
		print("El archivo no existe: ", path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()

	var res: Dictionary = load_from_json_string(text)
	return res.get("success", false)

## Limpia todas las cargas, formas, conductores y objetos de la escena.
func clear_all() -> void:
	_deselect()
	charges.clear()
	shape_groups.clear()
	charge_group.clear()
	conductors.clear()
	rigid_objects.clear()
	magnetics.clear()
	selected_rigid = null
	selected_conductor = null
	selected_mag = null
	_recompute_field_lines()
	grid_dirty = true
	_refresh_selection_ui()
	queue_redraw()

## Carga experimentos físicos predefinidos listos para demostración.
func load_experiment(name: String) -> void:
	clear_all()
	camera_center = Vector2.ZERO
	pixels_per_meter = DEFAULT_PIXELS_PER_METER
	layer = Layer.ELECTRIC

	match name:
		"dipole":
			# 1. Dipolo eléctrico (±1 µC a 4 m)
			var q1: Charge = Charge.new(Vector2(-2.0, 0.0), PhysicsConstants.MICRO)
			var q2: Charge = Charge.new(Vector2(2.0, 0.0), -PhysicsConstants.MICRO)
			charges.append(q1)
			charges.append(q2)
			_set_selection([q1])

		"equal_charges":
			# 2. Dos cargas iguales (+1 µC a 4 m)
			var q1: Charge = Charge.new(Vector2(-2.0, 0.0), PhysicsConstants.MICRO)
			var q2: Charge = Charge.new(Vector2(2.0, 0.0), PhysicsConstants.MICRO)
			charges.append(q1)
			charges.append(q2)
			_set_selection([q1])

		"faraday":
			# 3. Jaula de Faraday: anillo de radio 1.5 m con +8 µC, y carga de prueba en el centro con E=0
			var ring_pts: Array = ChargedShapes.make_ring(Vector2.ZERO, 1.5, 8.0 * PhysicsConstants.MICRO, SHAPE_POINTS)
			_add_shape(ring_pts, true, false, "ring", 1.5, Vector2.ZERO)
			var test_q: Charge = Charge.new(Vector2.ZERO, 0.1 * PhysicsConstants.MICRO)
			charges.append(test_q)
			_set_selection([test_q])

		"plane_ground":
			# 4. Plano a tierra y carga de +2 µC
			_add_conductor(ConductorPlane.new(Vector2.ZERO, Vector2.RIGHT))
			var q: Charge = Charge.new(Vector2(2.0, 0.0), 2.0 * PhysicsConstants.MICRO)
			charges.append(q)
			_set_selection([q])

		"parallel_plates":
			# 5. Varillas paralelas (+/-)
			var plates: Array = ChargedShapes.make_rod_pair(Vector2.ZERO, SHAPE_LENGTH_M, PAIR_SEPARATION_M, 0.0, 4.0 * PhysicsConstants.MICRO, SHAPE_POINTS)
			_add_shape(plates, false, true, "rod_pair", 0.0, Vector2.ZERO)

		"wire_compasses":
			# 6. Hilo con corriente y brújulas alrededor
			layer = Layer.MAGNETIC
			var wire: CurrentWire = CurrentWire.new(Vector2.ZERO, WIRE_CURRENT_A)
			magnetics.append(wire)
			for i in range(4):
				var angle: float = TAU * float(i) / 4.0
				var pos: Vector2 = Vector2(cos(angle), sin(angle)) * 1.2
				magnetics.append(MagneticCompass.new(pos))
			_select_mag(wire)

	_update_layer_button()
	_recompute_field_lines()
	grid_dirty = true
	_refresh_selection_ui()
	queue_redraw()
