extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_poison_turret
var max_hp: int = CFG.hp_poison_turret
var poison_tick_timer: float = 0.0
var power_blink_timer: float = 0.0
var manually_disabled: bool = false
var drip_timer: float = 0.0


func _ready():
	add_to_group("buildings")
	add_to_group("poison_turrets")


func get_building_name() -> String:
	return "Poison Turret"


func is_powered() -> bool:
	if manually_disabled:
		return false
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
		poison_tick_timer += delta
		if poison_tick_timer >= CFG.poison_tick_interval:
			poison_tick_timer -= CFG.poison_tick_interval
			_poison_attack()

	queue_redraw()


func _poison_attack():
	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien):
			continue
		if global_position.distance_to(alien.global_position) < CFG.poison_range:
			if alien.has_method("apply_poison"):
				alien.apply_poison(CFG.poison_dps, CFG.poison_duration)


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
		get_tree().current_scene.aliens_node.add_child(alien)


func _draw():
	var powered = is_powered()

	# Base circle
	draw_circle(Vector2.ZERO, 16, Color(0.25, 0.4, 0.2) if powered else Color(0.2, 0.25, 0.2))
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.3, 0.7, 0.15), 2.0)
	draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color(0.35, 0.6, 0.2), 1.0)

	# Poison vial
	draw_rect(Rect2(-4, -8, 8, 16), Color(0.3, 0.5, 0.2))
	draw_circle(Vector2(0, -10), 5, Color(0.4, 0.8, 0.2, 0.6) if powered else Color(0.3, 0.4, 0.2))

	# Drip effect
	if powered:
		var drip_phase = fmod(drip_timer * 1.5, 1.0)
		var drip_pos = Vector2(0, -5 + drip_phase * 8)
		draw_circle(drip_pos, 2.0, Color(0.3, 0.85, 0.15, 1.0 - drip_phase))

	# Range indicator
	draw_arc(Vector2.ZERO, CFG.poison_range, 0, TAU, 64, Color(0.3, 0.85, 0.15, 0.04), 1.0)

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
