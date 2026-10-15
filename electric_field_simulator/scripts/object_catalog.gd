class_name ObjectCatalog
extends RefCounted

## Catálogo de objetos que se pueden agregar, agrupado por categoría.
## Es solo DATOS: el menú lo lee para dibujarse y main.gd decide qué hacer con cada id.
## "available": false muestra el objeto desactivado ("próximamente").
## "tool": true marca las herramientas de colocación: el menú resalta la que está activa.

const CAT_MAGNETISM: String = "magnetism"
const CAT_ELECTRIC: String = "electric"

static func categories() -> Array:
	return [
		{
			"id": CAT_MAGNETISM,
			"label": "Magnetismo",
			"items": [
				{"id": "magnet", "label": "Imán (dipolo)", "available": true},
				{"id": "wire", "label": "Hilo con corriente", "available": true},
				{"id": "compass", "label": "Brújula", "available": true},
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
	]
