extends Node3D

var hp: int = 30
var max_hp: int = 30
var speed: float = 60.0
var damage: int = 8
var xp_value: int = 1
var alien_type: String = "basic"
var prefer_buildings: bool = false
var move_direction: Vector3 = Vector3.ZERO
var attack_timer: float = 0.0
const ATTACK_INTERVAL = 1.0
const ATTACK_RANGE = 28.0
const SEPARATION_RADIUS = 25.0
const SEPARATION_FORCE = 0.6
const RESOURCE_AVOID_FORCE = 1.5

# Status effects
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var tower_slow: float = 0.0
var tower_slow_timer: float = 0.0
var acid_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0

# Stuck detection
var _stuck_check_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _unstuck_timer: float = 0.0
var _unstuck_dir: Vector3 = Vector3.ZERO

# Hit flash
var _sprite: AnimatedSprite3D
var _flash_mat: ShaderMaterial

# Multiplayer puppet
var net_id: int = 0
var is_puppet: bool = false
var target_pos: Vector3 = Vector3.ZERO


func _ready():
	add_to_group("aliens")
	_sprite = get_node_or_null("AnimatedSprite3D")
	if _sprite:
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = preload("res://resources/shaders/hit_flash.gdshader")
		_sprite.material_overlay = _flash_mat


func can_take_orbital_hit() -> bool:
	return orbital_cooldown <= 0.0


func apply_burn(dps: float, duration: float = 3.0):
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)


func apply_slow(amount: float, duration: float = 2.0):
	slow_factor = minf(slow_factor, 1.0 - amount)
	slow_timer = maxf(slow_timer, duration)


func apply_poison(dps: float, duration: float = 5.0):
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, duration)


func _process(delta):
	orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	if _flash_mat:
		_flash_mat.set_shader_parameter("flash_amount", 1.0 if hit_flash_timer > 0 else 0.0)
	acid_timer = maxf(0.0, acid_timer - delta)

	if is_puppet:
		if target_pos != Vector3.ZERO:
			global_position = global_position.lerp(target_pos, 10.0 * delta)
		return

	if burn_timer > 0:
		burn_timer -= delta
		hp -= int(burn_dps * delta)
		if hp <= 0:
			_die()
			return

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_factor = 1.0

	if poison_timer > 0:
		poison_timer -= delta
		hp -= int(poison_dps * delta)
		if hp <= 0:
			_die()
			return
		for other in get_tree().get_nodes_in_group("aliens"):
			if other == self or not is_instance_valid(other): continue
			if "poison_timer" in other and other.poison_timer <= 0:
				if global_position.distance_to(other.global_position) < SEPARATION_RADIUS * 1.2:
					other.apply_poison(poison_dps * 0.7, poison_timer * 0.5)

	# Tower slow decay
	if tower_slow_timer > 0:
		tower_slow_timer -= delta
		if tower_slow_timer <= 0:
			tower_slow = 0.0

	var total_slow = slow_factor * (1.0 - tower_slow)

	var target = _find_target()
	var in_attack_range = false
	if target:
		var dist = global_position.distance_to(target.global_position)
		in_attack_range = dist <= ATTACK_RANGE

	# Stuck detection (skip when attacking — alien is intentionally stationary)
	if not in_attack_range:
		_stuck_timer += delta
		if _stuck_timer >= 0.5:
			if _stuck_check_pos != Vector3.ZERO and global_position.distance_to(_stuck_check_pos) < 3.0:
				_unstuck_timer = randf_range(1.0, 2.0)
				var escape_angle = randf() * TAU
				_unstuck_dir = Vector3(cos(escape_angle), 0, sin(escape_angle))
			_stuck_check_pos = global_position
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
		_unstuck_timer = 0.0

	if _unstuck_timer > 0:
		_unstuck_timer -= delta
		position += _unstuck_dir * speed * total_slow * delta
		move_direction = _unstuck_dir
	elif target:
		var dir = (target.global_position - global_position).normalized()
		if not in_attack_range:
			var separation = _get_separation_force()
			var resource_avoid = _get_resource_avoidance()
			var move_dir = (dir + separation * SEPARATION_FORCE + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
			position += move_dir * speed * total_slow * delta
			move_direction = move_dir
			attack_timer = 0.0
		else:
			move_direction = dir
			attack_timer += delta
			if attack_timer >= ATTACK_INTERVAL:
				attack_timer = 0.0
				if target.has_method("take_damage"):
					target.take_damage(damage)


func _find_target() -> Node3D:
	var closest: Node3D = null
	var closest_dist = 99999.0
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var d = global_position.distance_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = p
	# When prefer_buildings is set, buildings get a distance advantage (appear 40% closer)
	var building_bias = 0.6 if prefer_buildings else 1.0
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b): continue
		var d = global_position.distance_to(b.global_position) * building_bias
		if d < closest_dist:
			closest_dist = d
			closest = b
	return closest


func _get_separation_force() -> Vector3:
	var separation = Vector3.ZERO
	for other in get_tree().get_nodes_in_group("aliens"):
		if other == self or not is_instance_valid(other):
			continue
		var diff = global_position - other.global_position
		var dist = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.1:
			separation += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return separation.normalized() if separation.length() > 0 else Vector3.ZERO


func _get_resource_avoidance() -> Vector3:
	var avoidance = Vector3.ZERO
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r): continue
		var diff = global_position - r.global_position
		var dist = diff.length()
		var r_size = (10.0 + r.amount * 0.5) if "amount" in r else 15.0
		var avoid_dist = r_size + 20.0
		if dist < avoid_dist and dist > 0.1:
			avoidance += diff.normalized() * (1.0 - dist / avoid_dist)
	return avoidance.normalized() if avoidance.length() > 0 else Vector3.ZERO


func take_damage(amount: int):
	if is_puppet:
		return
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		_die()


func _die():
	var death_pos = global_position
	var gem = preload("res://scenes/xp_gem.tscn").instantiate()
	gem.xp_value = xp_value
	get_tree().current_scene.game_world_2d.add_child(gem)
	gem.global_position = death_pos
	if randi() % 10 == 0:
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		orb.prestige_value = NetworkManager.get_player_count()
		get_tree().current_scene.game_world_2d.add_child(orb)
		orb.global_position = death_pos
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	_try_drop_heal()
	queue_free()


func _try_drop_heal():
	var player = _find_player()
	if not player:
		return
	var health_ratio = float(player.health) / float(player.max_health)
	var drop_chance = 0.02 + (1.0 - health_ratio) * 0.23
	if randf() < drop_chance:
		var powerup = preload("res://scenes/powerup.tscn").instantiate()
		powerup.powerup_type = "heal"
		get_tree().current_scene.game_world_2d.add_child(powerup)
		powerup.global_position = global_position
		get_tree().current_scene.spawn_synced_powerup(powerup.global_position, powerup.powerup_type)


func _find_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null
