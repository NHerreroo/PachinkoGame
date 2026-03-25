extends Node3D

@export var objeto_a_lanzar: PackedScene
@export var intervalo_lanzamiento: float = 5.0
@export var auto_lanzar: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if auto_lanzar:
		lanzar_automaticamente()

func lanzar_automaticamente() -> void:
	while true:
		await get_tree().create_timer(intervalo_lanzamiento).timeout
		lanzar_objeto()

func lanzar_objeto() -> void:
	# Verificar que la escena está asignada
	if objeto_a_lanzar == null:
		print("Error: No se ha asignado una escena para lanzar")
		return
	
	if not has_node("Marker3D"):
		print("Error: No se encuentra el nodo Marker3D")
		return
	
	var objeto = objeto_a_lanzar.instantiate()
	
	if objeto == null:
		print("Error: No se pudo instanciar la escena")
		return
	
	# Configurar posición
	objeto.global_position = $Marker3D.position
	
	# Añadir a la escena
	add_child(objeto)
	
	print("Objeto instanciado correctamente en: ", objeto.global_position)
