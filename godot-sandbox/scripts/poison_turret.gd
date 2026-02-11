extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_poison_turret
var max_hp: int = CFG.hp_poison_turret
var poison_tick_timer: float = 0.0
var manually_disabled: bool = false


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
	var powered = is_powered()

	if powered:
		poison_tick_timer += delta
		if poison_tick_timer >= CFG.poison_tick_interval:
			poison_tick_timer -= CFG.poison_tick_interval
			_poison_attack()


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
		alien.global_position = global_position + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		alien.hp = 25
		alien.max_hp = 25
		alien.damage = 6
		alien.speed = 55.0
		get_tree().current_scene.aliens_node.add_child(alien)
