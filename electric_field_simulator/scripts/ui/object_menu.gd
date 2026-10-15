class_name ObjectMenu
extends VBoxContainer

## Menú desplegable de objetos, tipo acordeón: un botón por categoría
## (Magnetismo, Electricidad) que al pulsarse muestra sus objetos. Solo una
## categoría queda abierta a la vez. La lista va dentro de un área con SCROLL
## cuyo alto máximo fija main.gd con set_max_height(), así nunca se sale de la
## pantalla. Los botones miden 44 px para uso táctil.
##
## Uso desde main.gd:
##     var menu := ObjectMenu.new()
##     $UI.add_child(menu)
##     menu.object_requested.connect(_on_object_requested)

signal object_requested(kind: String)

const BUTTON_HEIGHT_PX: float = 44.0
const ITEM_INDENT_PX: int = 14
const MIN_LIST_HEIGHT_PX: float = 88.0   # alto mínimo de la lista aunque la pantalla sea muy baja

var _bodies: Dictionary = {}    # id de categoría -> contenedor con sus objetos
var _headers: Dictionary = {}   # id de categoría -> Button de cabecera
var _labels: Dictionary = {}    # id de categoría -> nombre
var _tool_buttons: Dictionary = {}   # id de herramienta -> Button (se muestra "presionado" el activo)
var _toggle: Button
var _scroll: ScrollContainer
var _categories: VBoxContainer
var _max_height: float = 0.0    # alto máximo de TODO el menú (0 = sin límite)

func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_toggle = Button.new()
	_toggle.text = "Objetos  [+]"
	_toggle.focus_mode = Control.FOCUS_NONE   # así Espacio y las flechas no lo activan
	_toggle.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT_PX)
	_toggle.pressed.connect(_on_root_toggled)
	add_child(_toggle)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.visible = false
	add_child(_scroll)

	_categories = VBoxContainer.new()
	_categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_categories)

	for cat in ObjectCatalog.categories():
		var header: Button = Button.new()
		header.text = "+ " + String(cat["label"])
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.focus_mode = Control.FOCUS_NONE
		header.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT_PX)
		header.pressed.connect(_toggle_category.bind(String(cat["id"])))
		_categories.add_child(header)

		var body: VBoxContainer = VBoxContainer.new()
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", ITEM_INDENT_PX)
		margin.add_child(body)
		margin.visible = false
		_categories.add_child(margin)

		for item in cat["items"]:
			var b: Button = Button.new()
			b.text = String(item["label"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT_PX)
			if bool(item["available"]):
				b.pressed.connect(_on_item_pressed.bind(String(item["id"])))
				if bool(item.get("tool", false)):
					b.toggle_mode = true
					_tool_buttons[String(item["id"])] = b
			else:
				b.disabled = true
				b.text += "  (próximamente)"
			body.add_child(b)

		_bodies[cat["id"]] = margin
		_headers[cat["id"]] = header
		_labels[cat["id"]] = String(cat["label"])

	set_active_tool("")

## Fija el ancho del menú (el alto lo da su contenido, abierto o cerrado).
func set_width(width: float) -> void:
	custom_minimum_size.x = width
	_fit.call_deferred()

## Resalta la herramienta de colocación activa ("" = carga normal). main.gd la llama tras cada elección.
func set_active_tool(kind: String) -> void:
	var key: String = "normal_charge" if kind == "" else kind
	for id in _tool_buttons.keys():
		_tool_buttons[id].set_pressed_no_signal(id == key)

## Alto máximo de todo el menú (botón "Objetos" + lista). Si la lista no cabe, aparece scroll.
func set_max_height(height: float) -> void:
	_max_height = height
	_fit.call_deferred()

func _on_root_toggled() -> void:
	_set_open(not _scroll.visible)

func _set_open(open: bool) -> void:
	_scroll.visible = open
	_toggle.text = "Objetos  [%s]" % ("−" if open else "+")
	_fit.call_deferred()

func _toggle_category(cat_id: String) -> void:
	for id in _bodies.keys():
		var open: bool = (id == cat_id) and not _bodies[id].visible
		_bodies[id].visible = open
		_headers[id].text = ("− " if open else "+ ") + String(_labels[id])
	_fit.call_deferred()

func _on_item_pressed(kind: String) -> void:
	object_requested.emit(kind)
	for id in _bodies.keys():          # se cierra el desplegable tras elegir
		_bodies[id].visible = false
		_headers[id].text = "+ " + String(_labels[id])
	_set_open(false)

## Ajusta el alto de la lista: lo que pida el contenido, pero sin pasar del máximo.
## Un Control no se encoge solo al ocultar hijos, por eso se le devuelve su tamaño mínimo.
func _fit() -> void:
	if _scroll == null:
		return
	var content_h: float = _categories.get_combined_minimum_size().y
	var room: float = content_h
	if _max_height > 0.0:
		room = maxf(_max_height - BUTTON_HEIGHT_PX - 2.0, MIN_LIST_HEIGHT_PX)
	_scroll.custom_minimum_size.y = minf(content_h, room)
	reset_size()
