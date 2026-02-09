extends Node2D

var hp: int = 500
var max_hp: int = 500
var speed: float = 30.0
var damage: int = 20
var xp_value: int = 20
var wave_level: int = 5

var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0

var pattern_timer: float = 0.0
var current_pattern: int = 0
var pattern_duration: float = 4.0
var attack_angle: float = 0.0
var burst_timer: float = 0.0
const PATTERNS = ["spiral", "ring", "aimed_burst", "rotating_streams"]

# Multiplayer puppet
var net_id: int = 0
var is_puppet: bool = false
var target_pos: Vector2 = Vector2.ZERO


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


func _process(delta):
	orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

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

	var target = _find_player()
	if target:
		var dist = global_position.distance_to(target.global_position)
		var dir = (target.global_position - global_position).normalized()
		if dist > 150:
			position += dir * speed * slow_factor * delta

	pattern_timer += delta
	burst_timer += delta
	_execute_pattern(delta)

	if pattern_timer >= pattern_duration:
		pattern_timer = 0.0
		current_pattern = (current_pattern + 1) % PATTERNS.size()
		burst_timer = 0.0

	queue_redraw()


func _execute_pattern(delta):
	match PATTERNS[current_pattern]:
		"spiral":
			attack_angle += delta * 3.0
			if burst_timer >= 0.1:
				burst_timer = 0.0
				_fire(Vector2.from_angle(attack_angle), 180.0)
				_fire(Vector2.from_angle(attack_angle + PI), 180.0)
		"ring":
			if burst_timer >= 1.2:
				burst_timer = 0.0
				var n = 12 + wave_level
				for i in range(n):
					_fire(Vector2.from_angle(TAU * i / n), 150.0)
		"aimed_burst":
			if burst_timer >= 0.4:
				burst_timer = 0.0
				var t = _find_player()
				if t:
					var dir = (t.global_position - global_position).normalized()
					for i in range(5):
						_fire(dir.rotated((i - 2) * 0.15), 200.0)
		"rotating_streams":
			attack_angle += delta * 2.0
			if burst_timer >= 0.15:
				burst_timer = 0.0
				for i in range(4):
					_fire(Vector2.from_angle(attack_angle + TAU * i / 4.0), 160.0)


func _fire(dir: Vector2, spd: float):
	var b = preload("res://scenes/enemy_bullet.tscn").instantiate()
	b.global_position = global_position + dir * 25
	b.direction = dir
	b.speed = spd
	b.damage = maxi(int(damage * 0.3), 3)
	get_tree().current_scene.game_world_2d.add_child(b)
	get_tree().current_scene.spawn_synced_enemy_bullet(b.global_position, b.direction)


func _find_player() -> Node2D:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null


func take_damage(amount: int):
	if is_puppet:
		return
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		_die()


func _die():
	for i in range(5):
		var gem = preload("res://scenes/xp_gem.tscn").instantiate()
		gem.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		gem.xp_value = maxi(xp_value / 5, 1)
		gem.gem_size = 2
		get_tree().current_scene.game_world_2d.add_child(gem)
	# Drop prestige orbs scaled for player count (so split is fair)
	var orb_count = 5 * NetworkManager.get_player_count()
	for i in range(orb_count):
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		orb.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		get_tree().current_scene.game_world_2d.add_child(orb)
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	# Boss always drops a heal
	var powerup = preload("res://scenes/powerup.tscn").instantiate()
	powerup.global_position = global_position
	powerup.powerup_type = "heal"
	get_tree().current_scene.game_world_2d.add_child(powerup)
	get_tree().current_scene.spawn_synced_powerup(powerup.global_position, powerup.powerup_type)
	get_tree().current_scene.on_boss_killed()
	queue_free()


func _draw():
	var body_color = Color(0.7, 0.1, 0.15)
	var size = 30.0

	if hit_flash_timer > 0:
		body_color = Color.WHITE
	elif burn_timer > 0:
		body_color = body_color.lerp(Color(1, 0.5, 0), 0.3)
	if slow_timer > 0:
		body_color = body_color.lerp(Color(0.5, 0.8, 1.0), 0.3)

	var pts = PackedVector2Array()
	for i in range(10):
		var ang = TAU * i / 10.0 + Time.get_ticks_msec() * 0.001
		var r = size if i % 2 == 0 else size * 0.7
		pts.append(Vector2.from_angle(ang) * r)
	draw_colored_polygon(pts, body_color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 0.3, 0.2), 2.0)

	var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.005) * 0.3
	draw_circle(Vector2.ZERO, size * 0.4 * pulse, Color(1, 0.2, 0.1, 0.6))
	draw_circle(Vector2.ZERO, size * 0.2, Color(1, 0.8, 0.3))

	for i in range(3):
		var ex = -8.0 + i * 8.0
		draw_circle(Vector2(ex, -8), 4, Color(1, 0.8, 0))
		draw_circle(Vector2(ex, -8), 2, Color(0.2, 0, 0))

	# Pattern progress arc
	var pc = Color.WHITE
	match PATTERNS[current_pattern]:
		"spiral": pc = Color(0.3, 1, 0.3)
		"ring": pc = Color(1, 0.3, 0.3)
		"aimed_burst": pc = Color(1, 1, 0.3)
		"rotating_streams": pc = Color(0.3, 0.3, 1)
	draw_arc(Vector2.ZERO, size + 5, 0, TAU * (1.0 - pattern_timer / pattern_duration), 24, pc, 2.0)

	# HP bar
	var bw = size * 2
	draw_rect(Rect2(-bw / 2, -size - 12, bw, 5), Color(0.3, 0, 0))
	draw_rect(Rect2(-bw / 2, -size - 12, bw * float(hp) / float(max_hp), 5), Color(0.9, 0.1, 0.1))

	# BOSS label
	draw_string(ThemeDB.fallback_font, Vector2(-16, -size - 16), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.3, 0.2))
