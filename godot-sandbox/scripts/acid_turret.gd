extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_acid_turret
var max_hp: int = CFG.hp_acid_turret
var shoot_timer: float = 0.0
var target_angle: float = 0.0
var manually_disabled: bool = false


func _ready():
	add_to_group("buildings")
	add_to_group("acid_turrets")


func get_building_name() -> String:
	return "Acid Turret"


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
		shoot_timer += delta
		var target = _find_nearest_alien()
		if target:
			var dir = target.global_position - global_position
			target_angle = atan2(dir.z, dir.x)
			if shoot_timer >= CFG.acid_shoot_interval:
				shoot_timer = 0.0
				_shoot_acid(target)


func _find_nearest_alien() -> Node3D:
	var closest: Node3D = null
	var closest_dist = CFG.acid_range
	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien):
			continue
		var d = global_position.distance_to(alien.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = alien
	return closest


func _shoot_acid(target: Node3D):
	target.take_damage(CFG.acid_bullet_damage)
	if "acid_timer" in target:
		target.acid_timer = 1.0

	var puddle = preload("res://scenes/acid_puddle.tscn").instantiate()
	var puddle_pos = target.global_position
	get_tree().current_scene.game_world_2d.add_child(puddle)
	puddle.global_position = puddle_pos


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var die_pos = global_position
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(3):
		var alien = alien_scene.instantiate()
		alien.hp = 25
		alien.max_hp = 25
		alien.damage = 6
		alien.speed = 55.0
		get_tree().current_scene.aliens_node.add_child(alien)
		alien.global_position = die_pos + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
