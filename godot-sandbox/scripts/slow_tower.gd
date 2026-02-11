extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_slow
var max_hp: int = CFG.hp_slow
var manually_disabled: bool = false


func _ready():
	add_to_group("buildings")
	add_to_group("slows")


func get_building_name() -> String:
	return "Slow Tower"


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


func _process(_delta):
	var powered = is_powered()

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


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(3):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		alien.hp = 20
		alien.max_hp = 20
		alien.damage = 5
		alien.speed = 70.0
		alien.alien_type = "fast"
		get_tree().current_scene.aliens_node.add_child(alien)
