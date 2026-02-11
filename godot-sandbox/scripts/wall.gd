extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_wall
var max_hp: int = CFG.hp_wall


func _ready():
	add_to_group("buildings")
	add_to_group("walls")
	if GameData.get_research_bonus("unlock_wall") >= 1.0:
		hp *= 2
		max_hp *= 2
	var wall_bonus = int(GameData.get_research_bonus("wall_health"))
	hp += wall_bonus
	max_hp += wall_bonus


func get_building_name() -> String:
	return "Wall"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		queue_free()
