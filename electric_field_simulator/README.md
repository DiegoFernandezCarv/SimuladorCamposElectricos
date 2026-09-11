# ⚡ Electric Field Simulator

MVP inicial del simulador interactivo de campos eléctricos, siguiendo las Fases 1–5
del documento de planeación del proyecto.

## Cómo abrir el proyecto

1. Descarga Godot 4.3 o superior (gratis): https://godotengine.org/download
2. Abre Godot → **Import** → selecciona el archivo `project.godot` de esta carpeta.
3. Presiona el botón ▶ (Run Project) o `F5`. Se abrirá `scenes/Main.tscn`.

## Controles de la demo

- **Campo de texto** (debajo del panel): define la magnitud en µC de la
  próxima carga a colocar, o edita la magnitud de la carga seleccionada.
- **Click izquierdo en espacio vacío**: coloca una carga positiva.
- **Click derecho en espacio vacío**: coloca una carga negativa.
- **Click izquierdo sobre una carga existente**: la selecciona (se resalta
  con un anillo amarillo) — mantén presionado y arrastra para moverla.
- **Click derecho sobre una carga existente**: la borra.
- **Supr / Backspace**: borra la carga seleccionada.
- **Esc**: deselecciona.
- **Mover el mouse**: funciona como "punto de prueba" — el panel superior
  izquierdo muestra E, Ex, Ey, potencial V y la posición en metros.
- En Android, un toque coloca una carga positiva (soporte táctil básico).

## Correr las pruebas de validación (Fase 3)

1. Abre la escena `tests/TestRunner.tscn`.
2. Con esa escena activa en el editor, presiona `F6` ("Run Current Scene").
3. Revisa la pestaña **Output** (consola) de Godot: verás `[OK]` o `[FAIL]`
   para cada prueba (carga positiva/negativa, valor teórico, ley del inverso
   del cuadrado, cargas iguales/opuestas, superposición).

## Estructura del proyecto

```
electric_field_simulator/
├── project.godot
├── scenes/
│   └── Main.tscn              # Escena interactiva principal
├── scripts/
│   ├── main.gd                # Interfaz, input, dibujo (vectores, cargas, panel)
│   └── physics/
│       ├── constants.gd       # Constante de Coulomb, prefijos de unidades
│       ├── charge.gd          # Clase Charge: field_at(), potential_at()
│       └── electric_field.gd  # Superposición: total_field(), total_potential()
└── tests/
    ├── TestRunner.tscn
    └── test_field.gd          # Pruebas automáticas (Fase 3 del documento)
```

Nota: en Godot, cualquier script con `class_name` (como `Charge`,
`ElectricFieldEngine`, `PhysicsConstants`) queda disponible globalmente en
todo el proyecto sin necesidad de `preload`/`import`.

## Qué sigue (siguiendo el plan de trabajo del documento, sección 43)

Ya está resuelto: **Vector → Carga → Campo de una carga → Campo de múltiples
cargas → Validación → Interfaz básica → Vectores de campo → Selección/edición/
arrastre/borrado de cargas → Entrada de texto para el valor de la carga**.

Próximos pasos sugeridos, en orden:

1. **Líneas de campo** (sección 11): partir de un punto cerca de cada carga
   positiva y avanzar siguiendo la dirección de `ElectricFieldEngine.total_field()`
   paso a paso, deteniéndose al llegar a una carga negativa o salir del área.
2. **Mapa de intensidad** (sección 13): un `Sprite2D` con un `Shader` o una
   textura generada por código, coloreando según `|E(x,y)|` en una cuadrícula
   más fina.
4. **Gráficas** (sección 18): usar `Line2D` de Godot para dibujar E vs r,
   comprobando visualmente que decae como 1/r².
5. **Guardado/carga en JSON** (sección 27): Godot tiene `JSON.stringify()` /
   `JSON.parse_string()` nativos — es directo serializar el array de `Charge`.
6. **Carga de prueba con movimiento** (secciones 15-16): usar
   `ElectricFieldEngine.acceleration_on_charge()` + integración de Euler o
   Verlet en `_physics_process()`.
7. **Exportar a Android**: Proyecto → Exportar → agregar preset "Android"
   (requiere el SDK de Android + plantillas de exportación de Godot, que se
   descargan una sola vez desde el editor).

Dime cuál de estos pasos quieres que programemos primero y seguimos.
