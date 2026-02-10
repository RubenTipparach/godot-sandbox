extends Node2D

var hp: int = 30
var max_hp: int = 30
var speed: float = 60.0
var damage: int = 8
var xp_value: int = 1
var alien_type: String = "basic"
var move_direction: Vector2 = Vector2.ZERO
var attack_timer: float = 0.0
const ATTACK_INTERVAL = 1.0
const ATTACK_RANGE = 28.0
const SEPARATION_RADIUS = 25.0  # Distance at which aliens start avoiding each other
const SEPARATION_FORCE = 0.6  # How strongly they push apart (0-1)
const RESOURCE_AVOID_FORCE = 1.5

# Status effects
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var tower_slow: float = 0.0  # From slow towers
var tower_slow_timer: float = 0.0
var acid_timer: float = 0.0  # Tint timer from acid puddles
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
		# Spread poison to nearby non-poisoned aliens
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

	# Stuck detection: check every 0.5s if we've barely moved
	_stuck_timer += delta
	if _stuck_timer >= 0.5:
		if _stuck_check_pos != Vector2.ZERO and global_position.distance_to(_stuck_check_pos) < 3.0:
			_unstuck_timer = randf_range(1.0, 2.0)
			# Pick a random perpendicular-ish direction to escape
			var escape_angle = randf() * TAU
			_unstuck_dir = Vector2.from_angle(escape_angle)
		_stuck_check_pos = global_position
		_stuck_timer = 0.0

	if _unstuck_timer > 0:
		_unstuck_timer -= delta
		position += _unstuck_dir * speed * total_slow * delta
		move_direction = _unstuck_dir
	else:
		var target = _find_target()
		if target:
			var dir = (target.global_position - global_position).normalized()
			var dist = global_position.distance_to(target.global_position)
			if dist > ATTACK_RANGE:
				# Add separation from other aliens + resource avoidance
				var separation = _get_separation_force()
				var resource_avoid = _get_resource_avoidance()
				var move_dir = (dir + separation * SEPARATION_FORCE + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
				position += move_dir * speed * total_slow * delta
				move_direction = move_dir
				attack_timer = 0.0
			else:
				attack_timer += delta
				if attack_timer >= ATTACK_INTERVAL:
					attack_timer = 0.0
					if target.has_method("take_damage"):
						target.take_damage(damage)

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
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b): continue
		var d = global_position.distance_to(b.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = b
	return closest


func _get_separation_force() -> Vector2:
	var separation = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("aliens"):
		if other == self or not is_instance_valid(other):
			continue
		var diff = global_position - other.global_position
		var dist = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.1:
			# Push away from nearby aliens, stronger when closer
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
	# 1 in 10 chance to drop a prestige orb (scaled for player count)
	if randi() % 10 == 0:
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		orb.global_position = global_position
		orb.prestige_value = NetworkManager.get_player_count()
		get_tree().current_scene.game_world_2d.add_child(orb)
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	# Health-based heal drop - lower health = higher chance
	_try_drop_heal()
	queue_free()


func _try_drop_heal():
	var player = _find_player()
	if not player:
		return
	var health_ratio = float(player.health) / float(player.max_health)
	# Base 2% chance, up to 25% when critical (<20% health)
	var drop_chance = 0.02 + (1.0 - health_ratio) * 0.23
	if randf() < drop_chance:
		var powerup = preload("res://scenes/powerup.tscn").instantiate()
		powerup.global_position = global_position
		powerup.powerup_type = "heal"
		get_tree().current_scene.game_world_2d.add_child(powerup)
		get_tree().current_scene.spawn_synced_powerup(powerup.global_position, powerup.powerup_type)


func _find_player() -> Node2D:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null


func _draw():
	var body_color = Color(0.9, 0.15, 0.1)
	var size = 10.0 + (float(max_hp) / 30.0) * 3.0

	if alien_type == "fast":
		body_color = Color(1.0, 0.5, 0.1)
		size *= 0.7

	if hit_flash_timer > 0:
		body_color = Color.WHITE
	else:
		if burn_timer > 0:
			body_color = body_color.lerp(Color(1.0, 0.35, 0.0), 0.6)
		if acid_timer > 0:
			body_color = body_color.lerp(Color(0.2, 0.9, 0.1), 0.5)
		if slow_timer > 0 or tower_slow > 0:
			body_color = body_color.lerp(Color(0.3, 0.6, 1.0), 0.5)
		if poison_timer > 0:
			body_color = body_color.lerp(Color(0.3, 0.8, 0.1), 0.5)

	var points = PackedVector2Array()
	for i in range(7):
		var angle = TAU * i / 7.0 - PI / 2
		var r = size if i % 2 == 0 else size * 0.55
		points.append(Vector2.from_angle(angle) * r)
	draw_colored_polygon(points, body_color)
	draw_polyline(points + PackedVector2Array([points[0]]), body_color.lightened(0.3), 1.5)

	draw_circle(Vector2.ZERO, size * 0.35, Color(1.0, 0.4, 0.2, 0.5))
	draw_circle(Vector2(-3, -2), 2.5, Color(1, 1, 0.2))
	draw_circle(Vector2(3, -2), 2.5, Color(1, 1, 0.2))
	draw_circle(Vector2(-3, -2), 1.0, Color(0.1, 0, 0))
	draw_circle(Vector2(3, -2), 1.0, Color(0.1, 0, 0))

	if burn_timer > 0:
		var t = Time.get_ticks_msec() * 0.01
		for j in range(3):
			draw_circle(Vector2(sin(t + j * 2.0) * 5, -abs(cos(t + j * 1.5)) * 8 - 5), 2.0, Color(1, 0.6, 0, 0.6))

	if slow_timer > 0 or tower_slow > 0:
		draw_arc(Vector2.ZERO, size + 3, 0, TAU, 12, Color(0.3, 0.6, 1.0, 0.5), 1.5)

	if acid_timer > 0:
		draw_arc(Vector2.ZERO, size + 2, 0, TAU, 12, Color(0.2, 0.9, 0.1, 0.4), 1.5)

	if poison_timer > 0:
		var t2 = Time.get_ticks_msec() * 0.008
		for j in range(4):
			draw_circle(Vector2(sin(t2 + j * 1.5) * 6, cos(t2 + j * 2.0) * 6), 1.5, Color(0.3, 0.85, 0.15, 0.5))

	if hp < max_hp:
		draw_rect(Rect2(-size, -size - 8, size * 2, 3), Color(0.3, 0, 0))
		draw_rect(Rect2(-size, -size - 8, size * 2.0 * float(hp) / float(max_hp), 3), Color(0.9, 0.1, 0.1))
