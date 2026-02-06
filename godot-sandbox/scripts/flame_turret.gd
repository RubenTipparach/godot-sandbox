extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_flame_turret
var max_hp: int = CFG.hp_flame_turret
var flame_timer: float = 0.0
var power_blink_timer: float = 0.0
var pulse_timer: float = 0.0


func _ready():
	add_to_group("buildings")
	add_to_group("flame_turrets")


func get_building_name() -> String:
	return "Flame Turret"


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
	pulse_timer += delta
	var powered = is_powered()

	if powered:
		flame_timer += delta
		if flame_timer >= CFG.flame_tick_interval:
			flame_timer -= CFG.flame_tick_interval
			_flame_attack()

	queue_redraw()


func _flame_attack():
	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien):
			continue
		if global_position.distance_to(alien.global_position) < CFG.flame_range:
			alien.take_damage(CFG.flame_damage)
			if alien.has_method("apply_burn"):
				alien.apply_burn(CFG.flame_burn_dps, CFG.flame_burn_duration)


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
	var pulse = 0.6 + sin(pulse_timer * 4.0) * 0.4 if powered else 0.3

	# Base platform
	draw_circle(Vector2.ZERO, 16, Color(0.5, 0.3, 0.2) if powered else Color(0.35, 0.25, 0.2))
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.6, 0.35, 0.15), 2.0)

	# Inner ring
	draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color(0.55, 0.3, 0.15), 1.0)

	# Flame nozzle (pointing up)
	draw_rect(Rect2(-4, -6, 8, 12), Color(0.4, 0.3, 0.25))
	draw_rect(Rect2(-6, -10, 12, 6), Color(0.45, 0.35, 0.25))

	# Flame effect when powered
	if powered:
		var flame_alpha = 0.5 * pulse
		# Flame cone radiating outward
		for i in range(8):
			var angle = TAU * i / 8.0
			var flame_len = CFG.flame_range * 0.3 * pulse
			var tip = Vector2.from_angle(angle) * flame_len
			var base_off = 8.0
			var left = Vector2.from_angle(angle - 0.3) * base_off
			var right = Vector2.from_angle(angle + 0.3) * base_off
			draw_colored_polygon(PackedVector2Array([left, tip, right]), Color(1.0, 0.5, 0.1, flame_alpha * 0.4))

		# Center glow
		draw_circle(Vector2.ZERO, 6, Color(1.0, 0.6, 0.1, 0.4 * pulse))

	# Range indicator
	draw_arc(Vector2.ZERO, CFG.flame_range, 0, TAU, 48, Color(1.0, 0.5, 0.1, 0.06), 1.5)

	# HP bar
	draw_rect(Rect2(-16, -24, 32, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-16, -24, 32.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_colored_polygon(PackedVector2Array([
			Vector2(2, -14), Vector2(-2, -6), Vector2(1, -6),
			Vector2(-3, 2), Vector2(1, -3), Vector2(-1, -3), Vector2(3, -14)
		]), warn_color)
