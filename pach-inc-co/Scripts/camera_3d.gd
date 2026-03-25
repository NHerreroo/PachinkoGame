extends Camera3D

# ─── SEÑALES ───────────────────────────────────────────
signal camera_moved(delta_x: float, delta_y: float)
signal mouse_mode_changed(mode: int)

# ─── CONFIGURACIÓN ─────────────────────────────────────
const MOUSE_SENSITIVITY := 0.002

# ─── SWAY ─────────────────────────────────────────────
const SWAY_STRENGTH  := 0.04
const SWAY_RECOVERY  := 6.0

# ─── REFERENCIAS ──────────────────────────────────────
@onready var hand := $Hand
@onready var raycast := $RayCast3D

# ─── ESTADO INTERNO ───────────────────────────────────
var angular_from_sway : Vector3 = Vector3.ZERO
var sway_rotation : Vector3 = Vector3.ZERO
var is_moving : bool = false


# ═══════════════════════════════════════════════════════
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ═══════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var parent := get_parent()
		if parent:
			parent.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		rotation.x = clamp(rotation.x, -PI / 2.0, PI / 2.0)
		
		angular_from_sway.z = lerp(
			angular_from_sway.z,
			-event.relative.x * MOUSE_SENSITIVITY * 3.0,
			0.3
		)
		
		emit_signal("camera_moved", event.relative.x, event.relative.y)

	if event.is_action_pressed("ui_cancel"):
		var new_mode = Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(new_mode)
		emit_signal("mouse_mode_changed", new_mode)


# ═══════════════════════════════════════════════════════
func _process(delta: float) -> void:
	# Actualizar sway
	if is_moving:
		# El sway se actualiza desde el controlador principal
		pass
	else:
		sway_rotation = sway_rotation.lerp(Vector3.ZERO, SWAY_RECOVERY * delta)
	
	angular_from_sway = angular_from_sway.lerp(Vector3.ZERO, 3.0 * delta)


# ═══════════════════════════════════════════════════════
func update_sway(move_direction: Vector3, delta: float) -> void:
	"""
	Actualiza el sway de la cámara basado en la dirección de movimiento.
	move_direction: Vector3 normalizado con la dirección de movimiento local
	"""
	if move_direction != Vector3.ZERO:
		sway_rotation = sway_rotation.lerp(
			Vector3(-move_direction.z * SWAY_STRENGTH, 0.0, -move_direction.x * SWAY_STRENGTH),
			SWAY_RECOVERY * delta
		)
		is_moving = true
	else:
		is_moving = false


# ═══════════════════════════════════════════════════════
func get_sway_rotation() -> Vector3:
	return sway_rotation


# ═══════════════════════════════════════════════════════
func get_angular_velocity() -> Vector3:
	return angular_from_sway


# ═══════════════════════════════════════════════════════
func is_pickable_in_range() -> bool:
	return raycast.is_colliding() and raycast.get_collider().is_in_group("pickable")


# ═══════════════════════════════════════════════════════
func get_pickable_object():
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider.is_in_group("pickable"):
			return collider
	return null


# ═══════════════════════════════════════════════════════
func get_hand_position() -> Vector3:
	return hand.global_position


# ═══════════════════════════════════════════════════════
func get_hand_rotation() -> Basis:
	return hand.global_transform.basis


# ═══════════════════════════════════════════════════════
func get_forward_direction() -> Vector3:
	return -global_transform.basis.z
