extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_turret
var max_hp: int = CFG.hp_turret
var shoot_timer: float = 0.0
var target_angle: float = 0.0
var damage_bonus: int = 0
var fire_rate_bonus: float = 0.0
var power_blink_timer: float = 0.0
var manually_disabled: bool = false
var bullet_count: int = 1
var ice_rounds: bool = false
var fire_rounds: bool = false
var acid_damage_bonus: int = 0


func _ready():
	add_to_group("buildings")
	add_to_group("turrets")


func get_building_name() -> String:
	return "Turret"


func is_powered() -> bool:
	if manually_disabled:
		return false
	var main = get_tree().current_scene
	if main and "power_on" in main and not main.power_on:
		return false
	# Check if connected to a powered pylon or directly to a power plant
	for plant in get_tree().get_nodes_in_group("power_plants"):
		if is_instance_valid(plant) and global_position.distance_to(plant.global_position) < plant.POWER_RANGE:
			return true
	for pylon in get_tree().get_nodes_in_group("pylons"):
		if is_instance_valid(pylon) and global_position.distance_to(pylon.global_position) < pylon.POWER_RANGE:
			if pylon.is_powered():
				return true
	return false


func _process(delta):
	power_blink_timer += delta
	var powered = is_powered()

	if powered:
		shoot_timer += delta
		var shoot_interval = CFG.turret_shoot_interval / (1.0 + fire_rate_bonus)
		var target = _find_nearest_alien()
		if target:
			target_angle = (target.global_position - global_position).angle()
			if shoot_timer >= shoot_interval:
				shoot_timer = 0.0
				_shoot_at(target)

	queue_redraw()


func _find_nearest_alien() -> Node2D:
	var closest: Node2D = null
	var closest_dist = CFG.turret_range
	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien):
			continue
		var d = global_position.distance_to(alien.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = alien
	return closest


func _shoot_at(target: Node2D):
	var dir = (target.global_position - global_position).normalized()
	var count = bullet_count
	var spread = 0.0
	if count > 1:
		spread = 0.25 + count * 0.05

	for i in range(count):
		var bullet = preload("res://scenes/bullet.tscn").instantiate()
		var off = 0.0
		if count > 1:
			off = lerpf(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
		bullet.global_position = global_position + dir * 20
		bullet.direction = Vector2.from_angle(dir.angle() + off)
		bullet.damage = CFG.turret_base_damage + damage_bonus + acid_damage_bonus
		bullet.from_turret = true
		if ice_rounds:
			bullet.slow_amount = 0.3
		if fire_rounds:
			bullet.burn_dps = 6.0
		get_tree().current_scene.add_child(bullet)
		get_tree().current_scene.spawn_synced_bullet(bullet.global_position, bullet.direction, true, bullet.burn_dps, bullet.slow_amount)


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(3):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		alien.hp = 25
		alien.max_hp = 25
		alien.damage = 6
		alien.speed = 55.0
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var powered = is_powered()
	var base_color = Color(0.4, 0.4, 0.5) if powered else Color(0.3, 0.3, 0.35)

	# Base circle
	draw_circle(Vector2.ZERO, 16, base_color)
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.3, 0.3, 0.4), 2.0)

	# Inner ring
	draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color(0.35, 0.35, 0.42), 1.0)

	# Barrel
	var barrel_end = Vector2.from_angle(target_angle) * 24
	var barrel_start = Vector2.from_angle(target_angle) * 8
	draw_line(barrel_start, barrel_end, Color(0.25, 0.25, 0.3), 4.0)
	draw_circle(barrel_end, 3, Color(0.3, 0.3, 0.35))

	# Range indicator (very faint)
	draw_arc(Vector2.ZERO, CFG.turret_range, 0, TAU, 64, Color(0.5, 0.8, 1.0, 0.04), 1.0)

	# HP bar
	draw_rect(Rect2(-16, -24, 32, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-16, -24, 32.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		# Lightning bolt icon
		draw_polyline(PackedVector2Array([
			Vector2(1, -14), Vector2(-2, -7), Vector2(2, -6), Vector2(-1, 2)
		]), warn_color, 2.5)
