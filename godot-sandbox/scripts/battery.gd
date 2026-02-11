extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_battery
var max_hp: int = CFG.hp_battery


func _ready():
	add_to_group("buildings")
	add_to_group("batteries")


func get_building_name() -> String:
	return "Battery"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(2):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		alien.hp = 20
		alien.max_hp = 20
		alien.damage = 5
		alien.speed = 50.0
		get_tree().current_scene.aliens_node.add_child(alien)
