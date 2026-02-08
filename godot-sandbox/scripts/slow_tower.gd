extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_slow
var max_hp: int = CFG.hp_slow
var pulse_timer: float = 0.0
var power_blink_timer: float = 0.0


func _ready():
	add_to_group("buildings")
	add_to_group("slows")


func get_building_name() -> String:
	return "Slow Tower"


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
	pulse_timer += delta
	power_blink_timer += delta
	var powered = is_powered()

	# Apply slow to nearby enemies only when powered
	if powered:
		for alien in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(alien):
				continue
			if global_position.distance_to(alien.global_position) < CFG.slow_range:
				if alien.has_method("apply_slow"):
					alien.apply_slow(CFG.slow_amount, 0.2)
				else:
					alien.tower_slow = CFG.slow_amount
					alien.tower_slow_timer = 0.2

	queue_redraw()


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
		alien.hp = 20
		alien.max_hp = 20
		alien.damage = 5
		alien.speed = 70.0
		alien.alien_type = "fast"
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var powered = is_powered()

	# Crystal base
	draw_rect(Rect2(-10, 0, 20, 12), Color(0.3, 0.35, 0.4) if powered else Color(0.25, 0.28, 0.32))

	# Ice crystal
	var pts = PackedVector2Array()
	pts.append(Vector2(0, -22))
	pts.append(Vector2(10, -5))
	pts.append(Vector2(6, 0))
	pts.append(Vector2(-6, 0))
	pts.append(Vector2(-10, -5))

	var pulse = 0.6 + sin(pulse_timer * 3.0) * 0.4 if powered else 0.3
	var crystal_color = Color(0.4, 0.7, 0.9, 0.7 * pulse) if powered else Color(0.3, 0.4, 0.5, 0.4)
	draw_colored_polygon(pts, crystal_color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.6, 0.85, 1.0) if powered else Color(0.4, 0.5, 0.6), 1.5)

	# Inner glow
	if powered:
		draw_circle(Vector2(0, -10), 4, Color(0.8, 0.95, 1.0, 0.5 * pulse))
	else:
		draw_circle(Vector2(0, -10), 4, Color(0.4, 0.45, 0.5, 0.3))

	# Range indicator
	draw_arc(Vector2.ZERO, CFG.slow_range, 0, TAU, 48, Color(0.4, 0.7, 1.0, 0.06), 1.5)

	# HP bar
	draw_rect(Rect2(-10, -28, 20, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-10, -28, 20.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_polyline(PackedVector2Array([
			Vector2(1, -4), Vector2(-2, 3), Vector2(2, 4), Vector2(-1, 12)
		]), warn_color, 2.5)
