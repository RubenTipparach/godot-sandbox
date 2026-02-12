extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_repair_drone
var max_hp: int = CFG.hp_repair_drone
var repair_timer: float = 0.0
var manually_disabled: bool = false
var repair_targets: Array = []


func _ready():
	add_to_group("buildings")
	add_to_group("repair_drones")


func get_building_name() -> String:
	return "Repair Drone"


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


func get_repair_range() -> float:
	return CFG.repair_drone_range + GameData.get_research_bonus("repair_drone_range")


func get_repair_rate() -> int:
	return int(CFG.repair_drone_repair_rate + GameData.get_research_bonus("repair_drone_speed"))


func _process(delta):
	var powered = is_powered()

	if powered:
		repair_timer += delta
		if repair_timer >= CFG.repair_drone_tick_interval:
			repair_timer -= CFG.repair_drone_tick_interval
			_repair_nearby()
	else:
		repair_targets.clear()


func _repair_nearby():
	repair_targets.clear()
	var buildings = get_tree().get_nodes_in_group("buildings")
	var sorted_buildings: Array = []
	var rng = get_repair_range()
	for b in buildings:
		if b == self:
			continue
		if not is_instance_valid(b):
			continue
		if not ("hp" in b and "max_hp" in b):
			continue
		if b.hp >= b.max_hp:
			continue
		var d = global_position.distance_to(b.global_position)
		if d < rng:
			sorted_buildings.append({"node": b, "dist": d})
	sorted_buildings.sort_custom(func(a, b2): return a["dist"] < b2["dist"])

	var heal = get_repair_rate()
	for i in range(mini(1, sorted_buildings.size())):
		var b = sorted_buildings[i]["node"]
		repair_targets.append(b)
		b.hp = mini(b.hp + heal, b.max_hp)


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var die_pos = global_position
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(2):
		var alien = alien_scene.instantiate()
		alien.hp = 20
		alien.max_hp = 20
		alien.damage = 5
		alien.speed = 50.0
		get_tree().current_scene.aliens_node.add_child(alien)
		alien.global_position = die_pos + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
