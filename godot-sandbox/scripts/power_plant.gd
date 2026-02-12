extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_power_plant
var max_hp: int = CFG.hp_power_plant
var POWER_RANGE: float = CFG.power_range_plant


func _ready():
	add_to_group("buildings")
	add_to_group("power_plants")


func get_building_name() -> String:
	return "Power Plant"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var die_pos = global_position
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(4):
		var alien = alien_scene.instantiate()
		alien.hp = 35
		alien.max_hp = 35
		alien.damage = 8
		alien.speed = 45.0
		get_tree().current_scene.aliens_node.add_child(alien)
		alien.global_position = die_pos + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
