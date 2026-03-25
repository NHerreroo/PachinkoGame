extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const THROW_FORCE = 15.0  # Fuerza para lanzar objetos
const SMOOTH_FOLLOW_SPEED = 15.0  # Velocidad de suavizado para el objeto agarrado

# Referencia al nodo de la cámara
@onready var camera := $Camera3D
@onready var raycast := $Camera3D/RayCast3D
@onready var hand := $Camera3D/Handa

# Variable para almacenar el objeto que estamos sosteniendo
var held_object = null
# Almacenar la capa de colisión original del objeto
var original_collision_layer = 0
var original_collision_mask = 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotación horizontal (personaje)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Rotación vertical (cámara) con límites
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Soltar objeto con la tecla E (Pick action)
	if event.is_action_pressed("Pick") and held_object != null:
		drop_object()
	
	# Lanzar objeto con click izquierdo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and held_object != null:
		throw_object()

func _physics_process(delta: float) -> void:
	# Si estamos sosteniendo un objeto, actualizar su posición con suavizado
	if held_object != null:
		# Usar lerp para suavizar el movimiento del objeto hacia la posición de la mano
		var target_position = hand.global_position
		var target_rotation = hand.global_rotation
		
		# Aplicar interpolación lineal para posición y rotación
		held_object.global_position = held_object.global_position.lerp(target_position, SMOOTH_FOLLOW_SPEED * delta)
		
		# Para la rotación, necesitamos usar un enfoque diferente ya que no podemos lerp directamente
		# Usamos slerp (interpolación esférica) para rotaciones suaves
		var current_basis = held_object.global_transform.basis
		var target_basis = Basis().rotated(target_rotation.normalized(), target_rotation.length())
		# Alternativa más simple: usar quaternion para rotación suave
		var current_quat = held_object.global_transform.basis.get_rotation_quaternion()
		var target_quat = hand.global_transform.basis.get_rotation_quaternion()
		var new_quat = current_quat.slerp(target_quat, SMOOTH_FOLLOW_SPEED * delta)
		held_object.global_transform.basis = Basis(new_quat)
	
	# Detectar objeto para agarrar
	if held_object == null and raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider.is_in_group("pickable"):
			# Si presionamos "Pick" y no tenemos objeto, agarrarlo
			if Input.is_action_just_pressed("Pick"):
				pick_object(collider)
	
	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Movimiento
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()

func pick_object(object):
	held_object = object
	
	# Guardar las capas de colisión originales
	if held_object is CollisionObject3D:
		original_collision_layer = held_object.collision_layer
		original_collision_mask = held_object.collision_mask
		# Desactivar todas las colisiones
		held_object.collision_layer = 0
		held_object.collision_mask = 0
	
	# Opcional: desactivar la gravedad y física del objeto mientras se sostiene
	if held_object is RigidBody3D:
		held_object.set_gravity_scale(0)
		held_object.freeze = true

func drop_object():
	if held_object:
		# Restaurar las capas de colisión
		if held_object is CollisionObject3D:
			held_object.collision_layer = original_collision_layer
			held_object.collision_mask = original_collision_mask
		
		# Reactivar la física del objeto
		if held_object is RigidBody3D:
			held_object.set_gravity_scale(1)
			held_object.freeze = false
		
		held_object = null

func throw_object():
	if held_object:
		# Restaurar las capas de colisión antes de lanzar
		if held_object is CollisionObject3D:
			held_object.collision_layer = original_collision_layer
			held_object.collision_mask = original_collision_mask
		
		# Reactivar la física del objeto
		if held_object is RigidBody3D:
			held_object.set_gravity_scale(1)
			held_object.freeze = false
			
			# Calcular dirección de lanzamiento (hacia donde mira la cámara)
			var throw_direction = -camera.global_transform.basis.z
			
			# Aplicar fuerza al objeto
			held_object.apply_central_impulse(throw_direction * THROW_FORCE)
		
		held_object = null
