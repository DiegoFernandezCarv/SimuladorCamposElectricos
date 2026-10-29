class_name ObjectCatalog
extends RefCounted

## Catálogo de objetos que se pueden agregar, agrupado por categoría.
## Es solo DATOS: el menú lo lee para dibujarse y main.gd decide qué hacer con cada id.
## "available": false muestra el objeto desactivado ("próximamente").
## "tool": true marca las herramientas de colocación: el menú resalta la que está activa.

const CAT_MAGNETISM: String = "magnetism"
const CAT_ELECTRIC: String = "electric"
const CAT_FILE: String = "file"
const CAT_EXPERIMENTS: String = "experiments"

static func categories() -> Array:
	return [
		{
			"id": CAT_FILE,
			"label": "Archivo (JSON)",
			"items": [
				{"id": "manage_experiments", "label": "🎓 Importar / Exportar JSON", "available": true},
				{"id": "save_json", "label": "Guardar simulación (JSON)", "available": true},
				{"id": "load_json", "label": "Cargar simulación (JSON)", "available": true},
				{"id": "clear_all", "label": "Limpiar todo el escenario", "available": true},
			],
		},
		{
			"id": CAT_EXPERIMENTS,
			"label": "Experimentos predefinidos",
			"items": [
				{"id": "exp_dipole", "label": "1. Dipolo eléctrico (±1 µC)", "available": true},
				{"id": "exp_equal_charges", "label": "2. Dos cargas iguales (+1 µC)", "available": true},
				{"id": "exp_faraday", "label": "3. Jaula de Faraday (Anillo)", "available": true},
				{"id": "exp_plane_ground", "label": "4. Plano a tierra y carga", "available": true},
				{"id": "exp_parallel_plates", "label": "5. Varillas paralelas (Capacitor)", "available": true},
				{"id": "exp_wire_compasses", "label": "6. Hilo con corriente y brújulas", "available": true},
			],
		},
		{
			"id": CAT_ELECTRIC,
			"label": "Electricidad",
			"items": [
				{"id": "normal_charge", "label": "Carga normal (puntual)", "available": true, "tool": true},
				{"id": "rod", "label": "Varilla cargada", "available": true, "tool": true},
				{"id": "rod_pair", "label": "Varillas paralelas (+/−)", "available": true, "tool": true},
				{"id": "ring", "label": "Anillo cargado", "available": true, "tool": true},
				{"id": "conductor_plane", "label": "Plano conductor a tierra", "available": true},
				{"id": "conductor_sphere", "label": "Esfera conductora a tierra", "available": true},
			],
		},
		{
			"id": CAT_MAGNETISM,
			"label": "Magnetismo",
			"items": [
				{"id": "magnet", "label": "Imán (dipolo)", "available": true},
				{"id": "wire", "label": "Hilo con corriente", "available": true},
				{"id": "compass", "label": "Brújula", "available": true},
			],
		},
	]
