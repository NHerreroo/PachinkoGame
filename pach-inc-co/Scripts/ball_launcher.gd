extends Node2D

# Referencia a la escena que queremos instanciar
@export var objeto_a_lanzar: PackedScene

# Velocidad base del lanzamiento
@export var velocidad_lanzamiento: float = 1500.0

# Variación de velocidad (más alto = más caos)
@export var variacion_velocidad: float = 300.0

# Variación de ángulo (en radianes, ~0.3 ≈ 17º)
@export var variacion_angulo: float = 0.3

# Gravedad (por si la usas en el objeto)
@export var gravedad: float = 980.0

# Referencia al objeto instanciado actualmente
var objeto_actual: RigidBody2D = null


func _ready():
	randomize()  # IMPORTANTE para aleatoriedad real
	
	await get_tree().create_timer(2).timeout
	
	for ball in Global.balls:
		lanzar_objeto()
		await get_tree().create_timer(0.2).timeout


func lanzar_objeto():
	# Verificar que tenemos una escena asignada
	if objeto_a_lanzar == null:
		print("Error: No se ha asignado una escena para lanzar")
		return
	
	# Instanciar el objeto
	objeto_actual = objeto_a_lanzar.instantiate()
	
	# Añadir el objeto a la escena
	add_child(objeto_actual)
	
	# Posicionar el objeto en la posición del nodo actual
	objeto_actual.global_position = global_position
	
	# Aplicar lanzamiento
	if objeto_actual is RigidBody2D:
		var velocidad_random = velocidad_lanzamiento + randf_range(-variacion_velocidad, variacion_velocidad)
		var angulo = randf_range(-variacion_angulo, variacion_angulo)
		
		var direccion = Vector2(0, -1).rotated(angulo)
		objeto_actual.apply_impulse(direccion * velocidad_random)
	
	else:
		print("Advertencia: El objeto no es RigidBody2D")
