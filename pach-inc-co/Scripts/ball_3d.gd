# PelotaMetal.gd (adjunto al RigidBody3D)
extends RigidBody3D

func _ready():
	
	mass = 1.4
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.1
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	
	
	contact_monitor = true
	max_contacts_reported = 4
	
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 0.5  # Fricción (0-1)
	physics_material.bounce = 0.6    # Rebote
	physics_material_override = physics_material

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("BallCounter"):
		Global.balls += 1
