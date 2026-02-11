extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_factory
var max_hp: int = CFG.hp_factory
var generate_timer: float = 0.0
var speed_bonus: float = 0.0
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
	var powered = is_powered()

	if powered:
		var generate_interval = CFG.factory_generate_interval / (1.0 + speed_bonus)
		generate_timer += delta
		if generate_timer >= generate_interval:
			generate_timer -= generate_interval
			_generate_resources()


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
		alien.global_position = global_position + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		alien.hp = 30
		alien.max_hp = 30
		alien.damage = 7
		alien.speed = 50.0
		get_tree().current_scene.aliens_node.add_child(alien)
