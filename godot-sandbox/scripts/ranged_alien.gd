extends Node2D

var hp: int = 20
var max_hp: int = 20
var speed: float = 50.0
var damage: int = 5
var xp_value: int = 2
var move_direction: Vector2 = Vector2.ZERO
var shoot_timer: float = 0.0
const SHOOT_INTERVAL = 2.0
const PREFERRED_DIST = 180.0
const ATTACK_RANGE = 300.0
const SEPARATION_RADIUS = 30.0
const SEPARATION_FORCE = 0.5
const RESOURCE_AVOID_FORCE = 1.5

var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var acid_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0

# Stuck detection
var _stuck_check_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _unstuck_timer: float = 0.0
var _unstuck_dir: Vector2 = Vector2.ZERO

# Multiplayer puppet
var net_id: int = 0
var is_puppet: bool = false
var target_pos: Vector2 = Vector2.ZERO


func _ready():
	add_to_group("aliens")


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
	acid_timer = maxf(0.0, acid_timer - delta)

	if is_puppet:
		if target_pos != Vector2.ZERO:
			global_position = global_position.lerp(target_pos, 10.0 * delta)
		queue_redraw()
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
		for other in get_tree().get_nodes_in_group("aliens"):
			if other == self or not is_instance_valid(other): continue
			if "poison_timer" in other and other.poison_timer <= 0:
				if global_position.distance_to(other.global_position) < SEPARATION_RADIUS * 1.2:
					other.apply_poison(poison_dps * 0.7, poison_timer * 0.5)

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_factor = 1.0

	# Stuck detection
	_stuck_timer += delta
	if _stuck_timer >= 0.5:
		if _stuck_check_pos != Vector2.ZERO and global_position.distance_to(_stuck_check_pos) < 3.0:
			_unstuck_timer = randf_range(1.0, 2.0)
			_unstuck_dir = Vector2.from_angle(randf() * TAU)
		_stuck_check_pos = global_position
		_stuck_timer = 0.0

	if _unstuck_timer > 0:
		_unstuck_timer -= delta
		position += _unstuck_dir * speed * slow_factor * delta
		move_direction = _unstuck_dir
	else:
		var target = _find_target()
		if target:
			var dist = global_position.distance_to(target.global_position)
			var dir = (target.global_position - global_position).normalized()
			var separation = _get_separation_force()
			var resource_avoid = _get_resource_avoidance()

			if dist > PREFERRED_DIST + 30:
				var move_dir = (dir + separation * SEPARATION_FORCE + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
				position += move_dir * speed * slow_factor * delta
				move_direction = move_dir
			elif dist < PREFERRED_DIST - 30:
				var move_dir = (-dir + separation * SEPARATION_FORCE + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
				position += move_dir * speed * slow_factor * delta * 0.5
				move_direction = move_dir
			elif (separation + resource_avoid).length() > 0.1:
				var move_dir = (separation + resource_avoid).normalized()
				position += move_dir * speed * slow_factor * delta * 0.3
				move_direction = move_dir

			shoot_timer += delta
			if shoot_timer >= SHOOT_INTERVAL and dist < ATTACK_RANGE:
				shoot_timer = 0.0
				_shoot_at(target)

	queue_redraw()


func _find_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist = 99999.0
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var d = global_position.distance_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = p
	return closest


func _get_separation_force() -> Vector2:
	var separation = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("aliens"):
		if other == self or not is_instance_valid(other):
			continue
		var diff = global_position - other.global_position
		var dist = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.1:
			separation += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return separation.normalized() if separation.length() > 0 else Vector2.ZERO


func _get_resource_avoidance() -> Vector2:
	var avoidance = Vector2.ZERO
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r): continue
		var diff = global_position - r.global_position
		var dist = diff.length()
		var r_size = (10.0 + r.amount * 0.5) if "amount" in r else 15.0
		var avoid_dist = r_size + 20.0
		if dist < avoid_dist and dist > 0.1:
			avoidance += diff.normalized() * (1.0 - dist / avoid_dist)
	return avoidance.normalized() if avoidance.length() > 0 else Vector2.ZERO


func _shoot_at(target: Node2D):
	var b = preload("res://scenes/enemy_bullet.tscn").instantiate()
	var dir = (target.global_position - global_position).normalized()
	b.global_position = global_position + dir * 15
	b.direction = dir
	b.damage = damage
	get_tree().current_scene.game_world_2d.add_child(b)
	get_tree().current_scene.spawn_synced_enemy_bullet(b.global_position, b.direction)


func take_damage(amount: int):
	if is_puppet:
		return
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		_die()


func _die():
	var gem = preload("res://scenes/xp_gem.tscn").instantiate()
	gem.global_position = global_position
	gem.xp_value = xp_value
	get_tree().current_scene.game_world_2d.add_child(gem)
	# 1 in 10 chance to drop a prestige orb
	if randi() % 10 == 0:
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		orb.global_position = global_position
		get_tree().current_scene.game_world_2d.add_child(orb)
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	# Health-based heal drop
	_try_drop_heal()
	queue_free()


func _try_drop_heal():
	var player = _find_target()
	if not player or not player.is_in_group("player"):
		return
	var health_ratio = float(player.health) / float(player.max_health)
	var drop_chance = 0.02 + (1.0 - health_ratio) * 0.23
	if randf() < drop_chance:
		var powerup = preload("res://scenes/powerup.tscn").instantiate()
		powerup.global_position = global_position
		powerup.powerup_type = "heal"
		get_tree().current_scene.game_world_2d.add_child(powerup)
		get_tree().current_scene.spawn_synced_powerup(powerup.global_position, powerup.powerup_type)


func _draw():
	var body_color = Color(0.6, 0.2, 0.8)
	var size = 12.0

	if hit_flash_timer > 0:
		body_color = Color.WHITE
	elif burn_timer > 0:
		body_color = body_color.lerp(Color(1, 0.5, 0), 0.4)
	if slow_timer > 0 and hit_flash_timer <= 0:
		body_color = body_color.lerp(Color(0.5, 0.8, 1.0), 0.4)
	if acid_timer > 0 and hit_flash_timer <= 0:
		body_color = body_color.lerp(Color(0.2, 0.9, 0.1), 0.5)
	if poison_timer > 0 and hit_flash_timer <= 0:
		body_color = body_color.lerp(Color(0.3, 0.8, 0.1), 0.5)

	var pts = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.8, -size * 0.3),
		Vector2(size * 0.5, size * 0.7),
		Vector2(-size * 0.5, size * 0.7),
		Vector2(-size * 0.8, -size * 0.3),
	])
	draw_colored_polygon(pts, body_color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), body_color.lightened(0.3), 1.5)

	draw_circle(Vector2(0, -2), 4, Color(1, 0.3, 1))
	draw_circle(Vector2(0, -2), 2, Color(0.2, 0, 0.2))

	if acid_timer > 0:
		draw_arc(Vector2.ZERO, size + 2, 0, TAU, 12, Color(0.2, 0.9, 0.1, 0.4), 1.5)

	if hp < max_hp:
		draw_rect(Rect2(-size, -size - 8, size * 2, 3), Color(0.3, 0, 0))
		draw_rect(Rect2(-size, -size - 8, size * 2.0 * float(hp) / float(max_hp), 3), Color(0.6, 0.2, 0.8))
