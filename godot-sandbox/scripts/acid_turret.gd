extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_acid_turret
var max_hp: int = CFG.hp_acid_turret
var shoot_timer: float = 0.0
var target_angle: float = 0.0
var power_blink_timer: float = 0.0
var drip_timer: float = 0.0


func _ready():
	add_to_group("buildings")
	add_to_group("acid_turrets")


func get_building_name() -> String:
	return "Acid Turret"


func is_powered() -> bool:
	var main = get_tree().current_scene
	if main and "power_on" in main and not main.power_on:
		return false
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
	drip_timer += delta
	var powered = is_powered()

	if powered:
		shoot_timer += delta
		var target = _find_nearest_alien()
		if target:
			target_angle = (target.global_position - global_position).angle()
			if shoot_timer >= CFG.acid_shoot_interval:
				shoot_timer = 0.0
				_shoot_acid(target)

	queue_redraw()


func _find_nearest_alien() -> Node2D:
	var closest: Node2D = null
	var closest_dist = CFG.acid_range
	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien):
			continue
		var d = global_position.distance_to(alien.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = alien
	return closest


func _shoot_acid(target: Node2D):
	# Deal direct damage
	target.take_damage(CFG.acid_bullet_damage)
	if "acid_timer" in target:
		target.acid_timer = 1.0

	# Spawn acid puddle at target position
	var puddle = preload("res://scenes/acid_puddle.tscn").instantiate()
	puddle.global_position = target.global_position
	get_tree().current_scene.add_child(puddle)


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
	var base_color = Color(0.3, 0.45, 0.3) if powered else Color(0.25, 0.3, 0.25)

	# Base circle
	draw_circle(Vector2.ZERO, 16, base_color)
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.2, 0.5, 0.2), 2.0)

	# Inner ring with green accent
	draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color(0.3, 0.6, 0.25), 1.0)

	# Barrel
	var barrel_end = Vector2.from_angle(target_angle) * 24
	var barrel_start = Vector2.from_angle(target_angle) * 8
	draw_line(barrel_start, barrel_end, Color(0.25, 0.4, 0.2), 4.0)
	draw_circle(barrel_end, 3, Color(0.3, 0.6, 0.15))

	# Acid drip effect on barrel tip
	if powered:
		var drip_phase = fmod(drip_timer * 2.0, 1.0)
		var drip_pos = barrel_end + Vector2(0, drip_phase * 6)
		var drip_alpha = 1.0 - drip_phase
		draw_circle(drip_pos, 2.0, Color(0.3, 0.9, 0.15, drip_alpha * 0.7))

	# Range indicator
	draw_arc(Vector2.ZERO, CFG.acid_range, 0, TAU, 64, Color(0.3, 0.9, 0.15, 0.04), 1.0)

	# HP bar
	draw_rect(Rect2(-16, -24, 32, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-16, -24, 32.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_polyline(PackedVector2Array([
			Vector2(1, -14), Vector2(-2, -7), Vector2(2, -6), Vector2(-1, 2)
		]), warn_color, 2.5)
