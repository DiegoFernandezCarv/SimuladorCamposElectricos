extends SceneTree

var main: Node = null
var step: int = 0

func _init() -> void:
	print("=== INICIANDO VALIDACIÓN DE NUEVA INTERFAZ CINTA (WORD) Y ARCHIVOS ===")
	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null:
		print("❌ Error: No se pudo cargar Main.tscn")
		quit(1)
		return
	main = scene.instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	step += 1
	if step == 2:
		_run_assertions()
		quit(0)
		return true
	return false

func _run_assertions() -> void:
	# 1. Verificar existencia de la cinta superior (Ribbon)
	var top_bar = main.get("top_bar")
	assert(top_bar != null, "top_bar no debe ser nulo")
	assert(top_bar is PanelContainer, "top_bar debe ser PanelContainer")
	assert(top_bar.custom_minimum_size.y >= 50.0, "top_bar debe tener al menos 50px de altura para móvil/PC")
	print("✅ 1. Cinta superior 'Ribbon' instanciada con altura: ", top_bar.custom_minimum_size.y)

	# 2. Verificar que los botones táctiles tienen altura >= 40px
	var buttons = [
		main.get("mode_button"),
		main.get("sign_button"),
		main.get("layer_button"),
		main.get("verify_button"),
		main.get("object_menu_btn"),
		main.get("experiment_button"),
		main.get("delete_button"),
		main.get("deselect_button")
	]
	for btn in buttons:
		assert(btn != null, "Botón no debe ser nulo")
		assert(btn.custom_minimum_size.y >= 40.0, "Botón %s debe tener min_height >= 40px para móvil" % btn.name)
	print("✅ 2. Todos los botones principales de la cinta cumplen con accesibilidad táctil (>=40px)")

	# 3. Verificar menú desplegable de objetos (Dropdown)
	var obj_container = main.get("object_menu_container")
	assert(obj_container != null, "object_menu_container no debe ser nulo")
	assert(obj_container is PanelContainer, "object_menu_container debe ser PanelContainer")
	assert(obj_container.visible == false, "El menú de objetos debe comenzar cerrado")
	main._toggle_object_menu()
	assert(obj_container.visible == true, "El menú de objetos debe abrirse al presionar el botón")
	main._toggle_object_menu(false)
	assert(obj_container.visible == false, "El menú de objetos debe cerrarse correctamente")
	print("✅ 3. Menú flotante de objetos funciona como Dropdown desplegable sin empujar la interfaz")

	# 4. Verificar configuración de FileDialogs y carpetas conocidas
	var save_fd = main.get("save_file_dialog")
	var load_fd = main.get("load_file_dialog")
	assert(save_fd != null and load_fd != null, "Los diálogos de archivo deben existir")
	main._configure_file_dialog(load_fd)

	var favs = load_fd.get_favorite_list()
	print("Favoritos configurados: ", favs)
	assert(favs.size() > 0, "Debe tener al menos una carpeta favorita configurada")
	var current_dir = load_fd.get_current_dir()
	print("Directorio inicial configurado: ", current_dir)
	assert(not current_dir.is_empty(), "El directorio inicial no debe estar vacío")
	print("✅ 4. FileDialog configurado con carpetas conocidas y favoritos estándar")

	# 5. Diálogo de Experimentos centrado y visible
	main._toggle_experiment_dialog(true)
	var exp_dlg = main.get("experiment_dialog")
	assert(exp_dlg != null and exp_dlg.visible == true, "El diálogo de experimentos debe estar visible")
	print("Posición de diálogo de experimentos: ", exp_dlg.position, " Tamaño: ", exp_dlg.size)
	assert(exp_dlg.position.y >= main.TOP_BAR_HEIGHT, "El diálogo no debe solapar la cinta superior")
	main._toggle_experiment_dialog(false)
	print("✅ 5. Diálogo de Experimentos centrado sin solapar elementos")

	print("\n🎉 TODAS LAS VALIDACIONES DE INTERFAZ Y DIÁLOGOS PASARON CON ÉXITO")
