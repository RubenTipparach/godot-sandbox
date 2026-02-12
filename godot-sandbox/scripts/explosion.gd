extends Node3D

## Regular fireball explosion — white/yellow/orange burst that fades to grey smoke.
## Instantiate, add to tree, set global_position. Auto-frees after lifetime.

@export var explosion_scale: float = 1.0  # Multiplier for particle size & light range

var _flash: OmniLight3D


func _ready():
	var particles = CPUParticles3D.new()
	particles.position = Vector3(0, 15, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 50
	particles.lifetime = 1.8
	# Shape: sphere burst
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 25.0 * explosion_scale
	# Movement
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0 * explosion_scale
	particles.initial_velocity_max = 150.0 * explosion_scale
	particles.gravity = Vector3(0, -30, 0)
	particles.damping_min = 15.0
	particles.damping_max = 40.0
	# Size
	particles.scale_amount_min = 15.0 * explosion_scale
	particles.scale_amount_max = 35.0 * explosion_scale
	particles.scale_amount_curve = _create_scale_curve()
	# Color: white-hot -> yellow -> orange fireball -> grey smoke
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.9, 1.0))
	gradient.add_point(0.15, Color(1.0, 0.9, 0.4, 1.0))
	gradient.add_point(0.35, Color(1.0, 0.5, 0.1, 0.9))
	gradient.add_point(0.6, Color(0.5, 0.3, 0.1, 0.7))
	gradient.add_point(0.8, Color(0.35, 0.33, 0.3, 0.5))
	gradient.add_point(1.0, Color(0.25, 0.25, 0.25, 0.0))
	particles.color_ramp = gradient
	# Material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = SphereMesh.new()
	particles.mesh.radius = 5.0
	particles.mesh.height = 10.0
	particles.mesh.radial_segments = 12
	particles.mesh.rings = 6
	particles.mesh.material = mat
	add_child(particles)
	# Flash light
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 20, 0)
	_flash.light_energy = 25.0 * explosion_scale
	_flash.omni_range = 200.0 * explosion_scale
	_flash.light_color = Color(1.0, 0.7, 0.3)
	_flash.shadow_enabled = false
	add_child(_flash)
	var tw = create_tween()
	tw.tween_property(_flash, "light_energy", 0.0, 0.8)
	tw.tween_callback(func():
		if is_instance_valid(_flash): _flash.queue_free()
	)
	# Auto-cleanup
	get_tree().create_timer(2.5).timeout.connect(queue_free)


func _create_scale_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.1, 1.0))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1.0, 0.4))
	return curve
