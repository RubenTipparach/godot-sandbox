extends Node3D

## Mushroom cloud explosion — rising fireball column + expanding cap + ground ring.
## Instantiate, add to tree, set global_position. Auto-frees after lifetime.

@export var explosion_scale: float = 1.0


func _ready():
	# 1) Rising column — narrow upward stream of fire particles
	var column = CPUParticles3D.new()
	column.position = Vector3(0, 10, 0)
	column.emitting = true
	column.one_shot = true
	column.explosiveness = 0.8
	column.amount = 40
	column.lifetime = 2.0
	column.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	column.emission_sphere_radius = 15.0 * explosion_scale
	column.direction = Vector3(0, 1, 0)
	column.spread = 15.0  # Narrow column
	column.initial_velocity_min = 100.0 * explosion_scale
	column.initial_velocity_max = 200.0 * explosion_scale
	column.gravity = Vector3(0, -10, 0)
	column.damping_min = 8.0
	column.damping_max = 20.0
	column.scale_amount_min = 15.0 * explosion_scale
	column.scale_amount_max = 30.0 * explosion_scale
	column.scale_amount_curve = _create_column_curve()
	var col_grad = Gradient.new()
	col_grad.add_point(0.0, Color(1.0, 1.0, 0.9, 1.0))
	col_grad.add_point(0.2, Color(1.0, 0.8, 0.3, 1.0))
	col_grad.add_point(0.5, Color(1.0, 0.4, 0.1, 0.9))
	col_grad.add_point(0.8, Color(0.4, 0.3, 0.2, 0.6))
	col_grad.add_point(1.0, Color(0.3, 0.3, 0.3, 0.0))
	column.color_ramp = col_grad
	column.mesh = _create_particle_mesh()
	add_child(column)

	# 2) Mushroom cap — delayed burst that expands outward at the top
	var cap = CPUParticles3D.new()
	cap.position = Vector3(0, 100 * explosion_scale, 0)
	cap.emitting = false  # Delayed start
	cap.one_shot = true
	cap.explosiveness = 0.9
	cap.amount = 60
	cap.lifetime = 2.5
	cap.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cap.emission_sphere_radius = 25.0 * explosion_scale
	cap.direction = Vector3(0, 0.3, 0)
	cap.spread = 180.0  # Expand outward in all directions
	cap.initial_velocity_min = 40.0 * explosion_scale
	cap.initial_velocity_max = 90.0 * explosion_scale
	cap.gravity = Vector3(0, -12, 0)
	cap.damping_min = 20.0
	cap.damping_max = 40.0
	cap.scale_amount_min = 25.0 * explosion_scale
	cap.scale_amount_max = 50.0 * explosion_scale
	cap.scale_amount_curve = _create_cap_curve()
	var cap_grad = Gradient.new()
	cap_grad.add_point(0.0, Color(1.0, 0.9, 0.5, 1.0))
	cap_grad.add_point(0.2, Color(1.0, 0.6, 0.2, 0.9))
	cap_grad.add_point(0.5, Color(0.6, 0.35, 0.15, 0.7))
	cap_grad.add_point(0.8, Color(0.4, 0.38, 0.35, 0.4))
	cap_grad.add_point(1.0, Color(0.3, 0.3, 0.3, 0.0))
	cap.color_ramp = cap_grad
	cap.mesh = _create_particle_mesh()
	add_child(cap)
	# Delay the cap by 0.3s so column rises first
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(cap): cap.emitting = true
	)

	# 3) Ground ring — fast horizontal burst at base
	var ring_burst = CPUParticles3D.new()
	ring_burst.position = Vector3(0, 3, 0)
	ring_burst.emitting = true
	ring_burst.one_shot = true
	ring_burst.explosiveness = 0.95
	ring_burst.amount = 24
	ring_burst.lifetime = 1.0
	ring_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	ring_burst.emission_ring_axis = Vector3(0, 1, 0)
	ring_burst.emission_ring_radius = 10.0 * explosion_scale
	ring_burst.emission_ring_inner_radius = 0.0
	ring_burst.emission_ring_height = 3.0
	ring_burst.direction = Vector3(0, 0.1, 0)
	ring_burst.spread = 180.0
	ring_burst.initial_velocity_min = 80.0 * explosion_scale
	ring_burst.initial_velocity_max = 160.0 * explosion_scale
	ring_burst.gravity = Vector3(0, 0, 0)
	ring_burst.damping_min = 25.0
	ring_burst.damping_max = 50.0
	ring_burst.scale_amount_min = 10.0 * explosion_scale
	ring_burst.scale_amount_max = 20.0 * explosion_scale
	var ring_grad = Gradient.new()
	ring_grad.add_point(0.0, Color(1.0, 0.9, 0.6, 0.9))
	ring_grad.add_point(0.3, Color(0.8, 0.5, 0.2, 0.7))
	ring_grad.add_point(0.7, Color(0.4, 0.35, 0.3, 0.3))
	ring_grad.add_point(1.0, Color(0.3, 0.3, 0.3, 0.0))
	ring_burst.color_ramp = ring_grad
	ring_burst.mesh = _create_particle_mesh()
	add_child(ring_burst)

	# 4) Flash light
	var flash = OmniLight3D.new()
	flash.position = Vector3(0, 30, 0)
	flash.light_energy = 40.0 * explosion_scale
	flash.omni_range = 250.0 * explosion_scale
	flash.light_color = Color(1.0, 0.6, 0.2)
	flash.shadow_enabled = false
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 1.0)
	tw.tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
	)

	# Auto-cleanup after everything finishes
	get_tree().create_timer(4.0).timeout.connect(queue_free)


func _create_particle_mesh() -> SphereMesh:
	var mesh = SphereMesh.new()
	mesh.radius = 5.0
	mesh.height = 10.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat
	return mesh


func _create_column_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.6, 0.7))
	curve.add_point(Vector2(1.0, 0.3))
	return curve


func _create_cap_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.6, 0.9))
	curve.add_point(Vector2(1.0, 0.5))
	return curve
