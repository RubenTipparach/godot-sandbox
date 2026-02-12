extends Node3D

var hp: int = 500
var max_hp: int = 500
var speed: float = 30.0
var damage: int = 20
var xp_value: int = 20
var wave_level: int = 5
var move_direction: Vector3 = Vector3.ZERO

var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0

# Stuck detection
var _stuck_check_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _unstuck_timer: float = 0.0
var _unstuck_dir: Vector3 = Vector3.ZERO

var pattern_timer: float = 0.0
var current_pattern: int = 0
var pattern_duration: float = 4.0
var attack_angle: float = 0.0
var burst_timer: float = 0.0
const PATTERNS = ["spiral", "ring", "aimed_burst", "rotating_streams"]
const RESOURCE_AVOID_FORCE = 1.5

# Multiplayer puppet
var net_id: int = 0
var is_puppet: bool = false
var target_pos: Vector3 = Vector3.ZERO


func _ready():
	add_to_group("aliens")
	add_to_group("bosses")


func can_take_orbital_hit() -> bool:
	return orbital_cooldown <= 0.0


func apply_burn(dps: float, duration: float = 3.0):
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)


func apply_slow(amount: float, duration: float = 2.0):
	slow_factor = minf(slow_factor, 1.0 - clampf(amount, 0.0, 0.5))
	slow_timer = maxf(slow_timer, duration * 0.5)


func apply_poison(dps: float, duration: float = 5.0):
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, duration * 0.5)


func _process(delta):
	orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

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

	if poison_timer > 0:
		poison_timer -= delta
		hp -= int(poison_dps * delta)
		if hp <= 0:
			_die()
			return

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_factor = 1.0

	# Stuck detection
	_stuck_timer += delta
	if _stuck_timer >= 0.5:
		if _stuck_check_pos != Vector3.ZERO and global_position.distance_to(_stuck_check_pos) < 3.0:
			_unstuck_timer = randf_range(1.0, 2.0)
			var escape_angle = randf() * TAU
			_unstuck_dir = Vector3(cos(escape_angle), 0, sin(escape_angle))
		_stuck_check_pos = global_position
		_stuck_timer = 0.0

	if _unstuck_timer > 0:
		_unstuck_timer -= delta
		position += _unstuck_dir * speed * slow_factor * delta
		move_direction = _unstuck_dir
	else:
		var target = _find_player()
		if target:
			var dist = global_position.distance_to(target.global_position)
			var dir = (target.global_position - global_position).normalized()
			if dist > 150:
				var resource_avoid = _get_resource_avoidance()
				var move_dir = (dir + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
				position += move_dir * speed * slow_factor * delta
				move_direction = move_dir

	pattern_timer += delta
	burst_timer += delta
	_execute_pattern(delta)

	if pattern_timer >= pattern_duration:
		pattern_timer = 0.0
		current_pattern = (current_pattern + 1) % PATTERNS.size()
		burst_timer = 0.0


func _execute_pattern(delta):
	match PATTERNS[current_pattern]:
		"spiral":
			attack_angle += delta * 3.0
			if burst_timer >= 0.1:
				burst_timer = 0.0
				_fire(Vector3(cos(attack_angle), 0, sin(attack_angle)), 180.0)
				_fire(Vector3(cos(attack_angle + PI), 0, sin(attack_angle + PI)), 180.0)
		"ring":
			if burst_timer >= 1.2:
				burst_timer = 0.0
				var n = 12 + wave_level
				for i in range(n):
					var a = TAU * i / n
					_fire(Vector3(cos(a), 0, sin(a)), 150.0)
		"aimed_burst":
			if burst_timer >= 0.4:
				burst_timer = 0.0
				var t = _find_player()
				if t:
					var dir = (t.global_position - global_position).normalized()
					var base_angle = atan2(dir.z, dir.x)
					for i in range(5):
						var a = base_angle + (i - 2) * 0.15
						_fire(Vector3(cos(a), 0, sin(a)), 200.0)
		"rotating_streams":
			attack_angle += delta * 2.0
			if burst_timer >= 0.15:
				burst_timer = 0.0
				for i in range(4):
					var a = attack_angle + TAU * i / 4.0
					_fire(Vector3(cos(a), 0, sin(a)), 160.0)


func _fire(dir: Vector3, spd: float):
	var b = preload("res://scenes/enemy_bullet.tscn").instantiate()
	var spawn_pos = global_position + dir * 25
	b.direction = dir
	b.speed = spd
	b.damage = maxi(int(damage * 0.3), 3)
	get_tree().current_scene.game_world_2d.add_child(b)
	b.global_position = spawn_pos
	get_tree().current_scene.spawn_synced_enemy_bullet(b.global_position, b.direction)


func _find_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null


func _get_resource_avoidance() -> Vector3:
	var avoidance = Vector3.ZERO
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r): continue
		var diff = global_position - r.global_position
		var dist = diff.length()
		var r_size = (10.0 + r.amount * 0.5) if "amount" in r else 15.0
		var avoid_dist = r_size + 25.0
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
	for i in range(5):
		var gem = preload("res://scenes/xp_gem.tscn").instantiate()
		gem.xp_value = maxi(xp_value / 5, 1)
		gem.gem_size = 2
		get_tree().current_scene.game_world_2d.add_child(gem)
		gem.global_position = death_pos + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
	var orb_count = 5 * NetworkManager.get_player_count()
	for i in range(orb_count):
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		get_tree().current_scene.game_world_2d.add_child(orb)
		orb.global_position = death_pos + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	var powerup = preload("res://scenes/powerup.tscn").instantiate()
	powerup.powerup_type = "heal"
	get_tree().current_scene.game_world_2d.add_child(powerup)
	powerup.global_position = death_pos
	get_tree().current_scene.spawn_synced_powerup(powerup.global_position, powerup.powerup_type)
	get_tree().current_scene.on_boss_killed()
	queue_free()
