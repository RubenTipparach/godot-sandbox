extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_lightning
var max_hp: int = CFG.hp_lightning
var zap_timer: float = 0.0
var zap_targets: Array = []
var manually_disabled: bool = false


func _ready():
	add_to_group("buildings")
	add_to_group("lightnings")


func get_building_name() -> String:
	return "Lightning Tower"


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
	zap_targets.clear()
	var powered = is_powered()

	if powered:
		zap_timer += delta
		if zap_timer >= CFG.lightning_zap_interval:
			zap_timer = 0.0
			_zap_enemies()


func _zap_enemies():
	var aliens = get_tree().get_nodes_in_group("aliens")
	for alien in aliens:
		if not is_instance_valid(alien):
			continue
		if global_position.distance_to(alien.global_position) < CFG.lightning_range:
			alien.take_damage(CFG.lightning_damage)
			zap_targets.append(alien.global_position - global_position)


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(3):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		alien.hp = 25
		alien.max_hp = 25
		alien.damage = 6
		alien.speed = 55.0
		get_tree().current_scene.aliens_node.add_child(alien)
