extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_factory
var max_hp: int = CFG.hp_factory
var generate_timer: float = 0.0
var speed_bonus: float = 0.0
var power_blink_timer: float = 0.0
var manually_disabled: bool = false


func _ready():
	add_to_group("buildings")
	add_to_group("factories")


func get_building_name() -> String:
	return "Factory"


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
	var powered = is_powered()

	if powered:
		var generate_interval = CFG.factory_generate_interval / (1.0 + speed_bonus)
		generate_timer += delta
		if generate_timer >= generate_interval:
			generate_timer -= generate_interval
			_generate_resources()
	queue_redraw()


func _generate_resources():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].iron += CFG.factory_iron_per_cycle
		players[0].crystal += CFG.factory_crystal_per_cycle


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(4):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		alien.hp = 30
		alien.max_hp = 30
		alien.damage = 7
		alien.speed = 50.0
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var powered = is_powered()
	var body_color = Color(0.8, 0.6, 0.2) if powered else Color(0.5, 0.4, 0.25)

	# Factory body
	draw_rect(Rect2(-20, -20, 40, 40), body_color)
	draw_rect(Rect2(-20, -20, 40, 40), Color(0.6, 0.4, 0.1), false, 2.0)

	# Chimney
	draw_rect(Rect2(-5, -32, 10, 14), Color(0.55, 0.38, 0.15))

	# Smoke puffs (animated by timer) - only when powered
	if powered:
		var smoke_offset = fmod(generate_timer * 8.0, 12.0)
		draw_circle(Vector2(0, -34 - smoke_offset), 3.0, Color(0.5, 0.5, 0.5, 0.3))
		draw_circle(Vector2(2, -38 - smoke_offset), 2.0, Color(0.5, 0.5, 0.5, 0.2))

	# Gear icon
	draw_circle(Vector2.ZERO, 8, Color(0.45, 0.32, 0.12))
	draw_circle(Vector2.ZERO, 4, Color(0.85, 0.65, 0.25) if powered else Color(0.5, 0.4, 0.2))

	# Generation progress bar
	if powered:
		var generate_interval = CFG.factory_generate_interval / (1.0 + speed_bonus)
		var progress = generate_timer / generate_interval
		draw_rect(Rect2(-20, 24, 40, 4), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-20, 24, 40 * progress, 4), Color(0.2, 0.8, 0.8))

	# HP bar
	draw_rect(Rect2(-20, -38, 40, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-20, -38, 40.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_polyline(PackedVector2Array([
			Vector2(1, -8), Vector2(-2, -1), Vector2(2, 0), Vector2(-1, 8)
		]), warn_color, 2.5)
