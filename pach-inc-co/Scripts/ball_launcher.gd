extends Node2D

# Referencia a la escena que queremos instanciar
@export var objeto_a_lanzar: PackedScene
# Velocidad inicial del lanzamiento
@export var velocidad_lanzamiento: float = 1500.0

# Gravedad que afectará al objeto
@export var gravedad: float = 980.0

# Referencia al objeto instanciado actualmente
var objeto_actual: RigidBody2D = null

func _ready():
	for ball in Global.balls:
		lanzar_objeto()
		await get_tree().create_timer(0.01).timeout
	pass

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
	
	# Aplicar velocidad vertical (hacia arriba)
	if objeto_actual is RigidBody2D:
		# Si es un RigidBody2D, aplicar impulso
		objeto_actual.apply_impulse(Vector2(0, -velocidad_lanzamiento))

	elif objeto_actual is RigidBody2D:
		# Si es un CharacterBody2D, establecer velocidad directamente
		objeto_actual.velocity = Vector2(0, -velocidad_lanzamiento)
	else:
		# Para otros nodos, puedes crear un script de movimiento personalizado
		print("Advertencia: El objeto no es RigidBody2D ni CharacterBody2D")
