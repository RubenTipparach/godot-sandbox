extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_pylon
var max_hp: int = CFG.hp_pylon
var POWER_RANGE: float = CFG.power_range_pylon


func _ready():
	add_to_group("buildings")
	add_to_group("pylons")


func get_building_name() -> String:
	return "Pylon"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		SFXManager.play("explode_small")
		queue_free()


func is_powered() -> bool:
	var main = get_tree().current_scene
	if main and "power_on" in main and not main.power_on:
		return false
	return _trace_power_to_plant([self])


func _trace_power_to_plant(visited: Array) -> bool:
	for plant in get_tree().get_nodes_in_group("power_plants"):
		if not is_instance_valid(plant):
			continue
		if global_position.distance_to(plant.global_position) < POWER_RANGE + plant.POWER_RANGE:
			return true

	for pylon in get_tree().get_nodes_in_group("pylons"):
		if not is_instance_valid(pylon) or pylon in visited:
			continue
		if global_position.distance_to(pylon.global_position) < POWER_RANGE * 2:
			visited.append(pylon)
			if pylon._trace_power_to_plant(visited):
				return true

	return false


func get_connected_buildings() -> Array:
	var buildings = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b == self:
			continue
		if b.is_in_group("pylons") or b.is_in_group("power_plants"):
			continue
		if global_position.distance_to(b.global_position) < POWER_RANGE:
			buildings.append(b)
	return buildings
