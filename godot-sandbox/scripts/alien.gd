extends Node2D

var hp: int = 30
var max_hp: int = 30
var speed: float = 60.0
var damage: int = 8
var xp_value: int = 1
var alien_type: String = "basic"
var attack_timer: float = 0.0
const ATTACK_INTERVAL = 1.0
const ATTACK_RANGE = 28.0
const SEPARATION_RADIUS = 25.0  # Distance at which aliens start avoiding each other
const SEPARATION_FORCE = 0.6  # How strongly they push apart (0-1)

# Status effects
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var tower_slow: float = 0.0  # From slow towers
var tower_slow_timer: float = 0.0


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


func _process(delta):
	orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

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

	# Tower slow decay
	if tower_slow_timer > 0:
		tower_slow_timer -= delta
		if tower_slow_timer <= 0:
			tower_slow = 0.0

	var total_slow = slow_factor * (1.0 - tower_slow)

	var target = _find_target()
	if target:
		var dir = (target.global_position - global_position).normalized()
		var dist = global_position.distance_to(target.global_position)
		if dist > ATTACK_RANGE:
			# Add separation from other aliens
			var separation = _get_separation_force()
			var move_dir = (dir + separation * SEPARATION_FORCE).normalized()
			position += move_dir * speed * total_slow * delta
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


func take_damage(amount: int):
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		_die()


func _die():
	var gem = preload("res://scenes/xp_gem.tscn").instantiate()
	gem.global_position = global_position
	gem.xp_value = xp_value
	get_tree().current_scene.add_child(gem)
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
		get_tree().current_scene.add_child(powerup)


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
	elif burn_timer > 0:
		body_color = body_color.lerp(Color(1, 0.5, 0), 0.5)
	if slow_timer > 0 and hit_flash_timer <= 0:
		body_color = body_color.lerp(Color(0.5, 0.8, 1.0), 0.4)

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

	if slow_timer > 0:
		draw_arc(Vector2.ZERO, size + 3, 0, TAU, 12, Color(0.5, 0.8, 1.0, 0.5), 1.5)

	if hp < max_hp:
		draw_rect(Rect2(-size, -size - 8, size * 2, 3), Color(0.3, 0, 0))
		draw_rect(Rect2(-size, -size - 8, size * 2.0 * float(hp) / float(max_hp), 3), Color(0.9, 0.1, 0.1))
