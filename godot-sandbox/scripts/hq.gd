extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_hq
var max_hp: int = CFG.hp_hq
var POWER_RANGE: float = CFG.power_range_hq

signal destroyed


func _ready():
	add_to_group("buildings")
	add_to_group("hq")
	add_to_group("power_plants")


func get_building_name() -> String:
	return "HQ"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		SFXManager.play("explode_small")
		destroyed.emit()
		queue_free()
