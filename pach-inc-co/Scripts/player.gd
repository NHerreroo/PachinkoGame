extends CharacterBody3D

# ─── SEÑALES ───────────────────────────────────────────
signal object_picked(object: Node3D)
signal object_dropped(object: Node3D, with_velocity: Vector3)
signal object_thrown(object: Node3D, force: float)
signal throw_charging(charge: float)

# ─── MOVIMIENTO ────────────────────────────────────────
const SPEED             := 5.0
const JUMP_VELOCITY     := 4.5
const MOUSE_SENSITIVITY := 0.002

# ─── SPRING ────────────────────────────────────────────
const SPRING_FREQUENCY_IDLE   := 8.0
const SPRING_FREQUENCY_MOVING := 22.0
const SPRING_DAMPING          := 0.75
const SPRING_FREQ_LERP_IN     := 12.0
const SPRING_FREQ_LERP_OUT    := 5.0

# ─── BOB / SWAY ────────────────────────────────────────
const BOB_AMOUNT     := 0.018
const BOB_SPEED      := 10.0
const SWAY_STRENGTH  := 0.04
const SWAY_RECOVERY  := 6.0

# ─── AGARRE ────────────────────────────────────────────
const GRAB_SNAP_DURATION  := 0.18
const GRAB_SNAP_SPEED     := 14.0
const GRAB_SCALE_PUNCH    := 1.08
const GRAB_SCALE_DURATION := 0.12

# ─── LANZAMIENTO CON CARGA ─────────────────────────────
const THROW_FORCE_MIN    := 8.0
const THROW_FORCE_MAX    := 22.0
const THROW_CHARGE_TIME  := 0.6
const THROW_ANGULAR_MULT := 4.0

# ─── CROSSHAIR ─────────────────────────────────────────
const CROSSHAIR_WIDTH_DEFAULT  := 2.0
const CROSSHAIR_WIDTH_PICKABLE := 4.0
const CROSSHAIR_LERP_SPEED     := 12.0

# ─── HIGHLIGHT ─────────────────────────────────────────
const HIGHLIGHT_LERP_IN  := 12.0
const HIGHLIGHT_LERP_OUT := 8.0

# ─── SUELTE ────────────────────────────────────────────
const DROP_ANGULAR_INHERIT := 0.5

# ─── NODOS ─────────────────────────────────────────────
@onready var camera    : Camera3D  = $Camera3D
@onready var raycast   : RayCast3D = $Camera3D/RayCast3D
@onready var hand      : Node3D    = $Camera3D/Hand
@onready var crosshair : Line2D    = $CanvasLayer/Control/Line2D

# ─── ESTADO INTERNO ────────────────────────────────────
var held_object               : RigidBody3D = null
var _original_collision_layer : int         = 0
var _original_collision_mask  : int         = 0
var _original_gravity_scale   : float       = 1.0

var _spring_velocity          : Vector3 = Vector3.ZERO
var _spring_frequency_current : float   = SPRING_FREQUENCY_IDLE

var _bob_phase     : float   = 0.0
var _sway_rotation : Vector3 = Vector3.ZERO

var _grab_timer    : float = 0.0
var _is_snapping   : bool  = false

var _scale_punch_timer : float   = 0.0
var _original_scale    : Vector3 = Vector3.ONE

var _throw_charge      : float = 0.0
var _is_charging_throw : bool  = false

var _highlighted_object : Node3D = null
var _highlight_strength : float  = 0.0

var _angular_from_sway : Vector3 = Vector3.ZERO


# ═══════════════════════════════════════════════════════
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ═══════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)
		_angular_from_sway.z = lerp(
			_angular_from_sway.z,
			-event.relative.x * MOUSE_SENSITIVITY * 3.0,
			0.3
		)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

	if event.is_action_pressed("Pick") and held_object != null:
		drop_object()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and held_object != null:
			_is_charging_throw = true
			_throw_charge = 0.0
		elif not event.pressed and _is_charging_throw:
			if held_object != null:
				throw_object()
			_is_charging_throw = false
			_throw_charge = 0.0


# ═══════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_moving := input_dir != Vector2.ZERO and is_on_floor()

	_update_highlight(delta)
	_update_crosshair(delta)

	if held_object != null:
		var target_freq := SPRING_FREQUENCY_MOVING if is_moving else SPRING_FREQUENCY_IDLE
		var lerp_speed  := SPRING_FREQ_LERP_IN if is_moving else SPRING_FREQ_LERP_OUT
		_spring_frequency_current = lerp(_spring_frequency_current, target_freq, lerp_speed * delta)

	if is_moving:
		_bob_phase += BOB_SPEED * delta
	else:
		_bob_phase = lerp(_bob_phase, round(_bob_phase / PI) * PI, 8.0 * delta)

	var bob_offset := Vector3(
		sin(_bob_phase * 0.5) * BOB_AMOUNT * 0.5,
		sin(_bob_phase) * BOB_AMOUNT,
		0.0
	)

	if is_moving:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
		_sway_rotation = _sway_rotation.lerp(
			Vector3(-move_dir.z * SWAY_STRENGTH, 0.0, -move_dir.x * SWAY_STRENGTH),
			SWAY_RECOVERY * delta
		)
	else:
		_sway_rotation = _sway_rotation.lerp(Vector3.ZERO, SWAY_RECOVERY * delta)

	_angular_from_sway = _angular_from_sway.lerp(Vector3.ZERO, 3.0 * delta)

	if _is_charging_throw and held_object != null:
		_throw_charge = min(_throw_charge + delta / THROW_CHARGE_TIME, 1.0)
		emit_signal("throw_charging", _throw_charge)
		held_object.scale = _original_scale * (1.0 - _throw_charge * 0.06)

	if held_object != null:
		var target_pos := hand.global_position + bob_offset

		if _is_snapping:
			held_object.global_position = held_object.global_position.lerp(
				target_pos, GRAB_SNAP_SPEED * delta
			)
			_grab_timer -= delta
			if _grab_timer <= 0.0:
				_is_snapping = false
				_spring_velocity = Vector3.ZERO
		else:
			_apply_spring(held_object, target_pos, delta)

		var current_quat     := held_object.global_transform.basis.get_rotation_quaternion()
		var base_target_quat := hand.global_transform.basis.get_rotation_quaternion()
		var target_quat      := base_target_quat * Quaternion.from_euler(_sway_rotation)
		held_object.global_transform.basis = Basis(current_quat.slerp(target_quat, 12.0 * delta))

		if _scale_punch_timer > 0.0:
			_scale_punch_timer -= delta
			var t      = 1.0 - clamp(_scale_punch_timer / GRAB_SCALE_DURATION, 0.0, 1.0)
			var ease_t := 1.0 - pow(1.0 - t, 3.0)
			if not _is_charging_throw:
				held_object.scale = _original_scale * lerp(GRAB_SCALE_PUNCH, 1.0, ease_t)

	if held_object == null and raycast.is_colliding():
		var collider := raycast.get_collider()
		if collider.is_in_group("pickable") and Input.is_action_just_pressed("Pick"):
			pick_object(collider)

	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()


# ═══════════════════════════════════════════════════════
#  CROSSHAIR
# ═══════════════════════════════════════════════════════
func _update_crosshair(delta: float) -> void:
	var can_pick = (
		held_object == null
		and raycast.is_colliding()
		and raycast.get_collider().is_in_group("pickable")
	)
	var target_width := CROSSHAIR_WIDTH_PICKABLE if can_pick else CROSSHAIR_WIDTH_DEFAULT
	crosshair.width = lerp(crosshair.width, target_width, CROSSHAIR_LERP_SPEED * delta)


# ═══════════════════════════════════════════════════════
#  HIGHLIGHT
# ═══════════════════════════════════════════════════════
func _update_highlight(delta: float) -> void:
	var new_target : Node3D = null
	if raycast.is_colliding():
		var collider := raycast.get_collider()
		if collider.is_in_group("pickable") and held_object == null:
			new_target = collider

	if new_target != _highlighted_object:
		if _highlighted_object != null:
			_set_highlight_strength(_highlighted_object, 0.0)
		_highlighted_object = new_target
		_highlight_strength = 0.0

	if _highlighted_object != null:
		_highlight_strength = lerp(_highlight_strength, 1.0, HIGHLIGHT_LERP_IN * delta)
		_set_highlight_strength(_highlighted_object, _highlight_strength)
	elif _highlight_strength > 0.001:
		_highlight_strength = lerp(_highlight_strength, 0.0, HIGHLIGHT_LERP_OUT * delta)


func _set_highlight_strength(object: Node3D, strength: float) -> void:
	if object == null:
		return
	var mesh_instance := object.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = object as MeshInstance3D
	if mesh_instance and mesh_instance.material_overlay:
		mesh_instance.material_overlay.set_shader_parameter("outline_strength", strength)


# ═══════════════════════════════════════════════════════
#  SPRING
# ═══════════════════════════════════════════════════════
func _apply_spring(object: Node3D, target: Vector3, delta: float) -> void:
	var displacement  := object.global_position - target
	var spring_force  := -_spring_frequency_current * _spring_frequency_current * displacement
	var damping_force := -2.0 * SPRING_DAMPING * _spring_frequency_current * _spring_velocity
	_spring_velocity += (spring_force + damping_force) * delta
	object.global_position += _spring_velocity * delta


# ═══════════════════════════════════════════════════════
#  PICK
# ═══════════════════════════════════════════════════════
func pick_object(object: Node3D) -> void:
	if not object is RigidBody3D:
		push_warning("pick_object: el objeto debe ser RigidBody3D")
		return

	held_object = object as RigidBody3D

	_original_collision_layer = held_object.collision_layer
	_original_collision_mask  = held_object.collision_mask
	_original_gravity_scale   = held_object.gravity_scale
	_original_scale           = held_object.scale

	held_object.collision_layer = 0
	held_object.collision_mask  = 0
	held_object.freeze          = true
	held_object.gravity_scale   = 0.0

	_spring_velocity          = Vector3.ZERO
	_sway_rotation            = Vector3.ZERO
	_spring_frequency_current = SPRING_FREQUENCY_IDLE

	_is_snapping = true
	_grab_timer  = GRAB_SNAP_DURATION

	_scale_punch_timer = GRAB_SCALE_DURATION
	held_object.scale  = _original_scale * GRAB_SCALE_PUNCH

	_highlighted_object = null
	_highlight_strength = 0.0

	emit_signal("object_picked", held_object)


# ═══════════════════════════════════════════════════════
#  DROP
# ═══════════════════════════════════════════════════════
func drop_object() -> void:
	if held_object == null:
		return

	var dropped := held_object
	_restore_object_physics(dropped)
	dropped.linear_velocity  = _spring_velocity
	dropped.angular_velocity = _angular_from_sway * DROP_ANGULAR_INHERIT
	dropped.scale = _original_scale

	emit_signal("object_dropped", dropped, _spring_velocity)
	_reset_hold_state()


# ═══════════════════════════════════════════════════════
#  THROW
# ═══════════════════════════════════════════════════════
func throw_object() -> void:
	if held_object == null:
		return

	var thrown    := held_object
	var force     = lerp(THROW_FORCE_MIN, THROW_FORCE_MAX, _throw_charge)
	var direction := -camera.global_transform.basis.z

	_restore_object_physics(thrown)
	thrown.apply_central_impulse(direction * force)
	thrown.apply_torque_impulse(camera.global_transform.basis.x * force * THROW_ANGULAR_MULT)
	thrown.scale = _original_scale

	emit_signal("object_thrown", thrown, force)
	_reset_hold_state()


# ═══════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════
func _restore_object_physics(object: RigidBody3D) -> void:
	object.collision_layer = _original_collision_layer
	object.collision_mask  = _original_collision_mask
	object.gravity_scale   = _original_gravity_scale
	object.freeze          = false


func _reset_hold_state() -> void:
	held_object        = null
	_spring_velocity   = Vector3.ZERO
	_is_snapping       = false
	_grab_timer        = 0.0
	_scale_punch_timer = 0.0
	_throw_charge      = 0.0
	_is_charging_throw = false
