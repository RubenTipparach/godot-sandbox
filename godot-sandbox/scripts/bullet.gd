extends Node3D

const CFG = preload("res://resources/game_config.tres")

var direction: Vector3 = Vector3.RIGHT
var speed: float = CFG.bullet_speed
var damage: int = CFG.bullet_damage
var lifetime: float = CFG.bullet_lifetime
var from_turret: bool = false

# Upgrade properties
var chain_count: int = 0
var burn_dps: float = 0.0
var slow_amount: float = 0.0
var crit_chance: float = 0.0
var chain_damage_bonus: int = 0
var chain_retention: float = CFG.chain_base_retention
var visual_only: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail: GPUParticles3D = $Trail


func _ready():
	_update_color()

	if trail:
		trail.emitting = true


func _update_color():
	var color = Color(1, 0.9, 0.2)
	if from_turret:
		color = Color(0.3, 0.9, 1.0)
	if burn_dps > 0:
		color = Color(1.0, 0.5, 0.1)
	if slow_amount > 0:
		color = Color(0.4, 0.8, 1.0)

	if mesh and mesh.mesh:
		var mat = mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.emission = color
	if trail and trail.process_material:
		trail.process_material.color = Color(color.r, color.g, color.b, 0.5)


func _process(delta):
	position += direction * speed * delta
	rotation.y = atan2(-direction.x, -direction.z)
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	if not visual_only:
		for alien in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(alien): continue
			if global_position.distance_to(alien.global_position) < CFG.bullet_hit_radius:
				_on_hit(alien)
				queue_free()
				return


func _on_hit(alien: Node3D):
	var final_damage = damage
	var is_crit = randf() < crit_chance
	if is_crit:
		final_damage = damage * 2
	alien.take_damage(final_damage)
	_spawn_damage_number(alien.global_position, final_damage, is_crit)
	if burn_dps > 0 and alien.has_method("apply_burn"):
		alien.apply_burn(burn_dps)
	if slow_amount > 0 and alien.has_method("apply_slow"):
		alien.apply_slow(slow_amount)
	if chain_count > 0:
		_chain_lightning(alien)


func _spawn_damage_number(pos: Vector3, amount: int, is_crit: bool):
	var popup = preload("res://scenes/popup_text.tscn").instantiate()
	popup.global_position = pos + Vector3(randf_range(-10, 10), 15, 0)
	popup.text = str(amount)
	if is_crit:
		popup.text = str(amount) + "!"
		popup.color = Color(1.0, 0.8, 0.2)
	else:
		popup.color = Color(1.0, 1.0, 1.0)
	popup.velocity = Vector3(randf_range(-20, 20), 60, 0)
	popup.lifetime = 0.8
	get_tree().current_scene.game_world_2d.add_child(popup)


func _chain_lightning(start: Node3D):
	var prev_pos = start.global_position
	var hit = [start]
	var chain_positions = [start.global_position]

	for i in range(chain_count):
		var nearest: Node3D = null
		var nearest_dist = CFG.chain_range
		for alien in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(alien) or alien in hit:
				continue
			var d = prev_pos.distance_to(alien.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = alien
		if nearest:
			var chain_dmg = int(damage * chain_retention) + chain_damage_bonus
			nearest.take_damage(chain_dmg)
			if burn_dps > 0 and nearest.has_method("apply_burn"):
				nearest.apply_burn(burn_dps * 0.5)
			if slow_amount > 0 and nearest.has_method("apply_slow"):
				nearest.apply_slow(slow_amount * 0.5)
			hit.append(nearest)
			chain_positions.append(nearest.global_position)
			prev_pos = nearest.global_position
		else:
			break

	if chain_positions.size() > 1:
		var fx = Node3D.new()
		fx.set_script(preload("res://scripts/lightning_effect.gd"))
		fx.points = chain_positions
		get_tree().current_scene.game_world_2d.add_child(fx)
