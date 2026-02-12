extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_turret
var max_hp: int = CFG.hp_turret
var shoot_timer: float = 0.0
var target_angle: float = 0.0
var damage_bonus: int = 0
var fire_rate_bonus: float = 0.0
var manually_disabled: bool = false
var bullet_count: int = 1
var ice_rounds: bool = false
var fire_rounds: bool = false
var acid_damage_bonus: int = 0


func _ready():
	add_to_group("buildings")
	add_to_group("turrets")


func get_building_name() -> String:
	return "Turret"


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
		var shoot_interval = CFG.turret_shoot_interval / (1.0 + fire_rate_bonus)
		var target = _find_nearest_alien()
		if target:
			var dir = target.global_position - global_position
			target_angle = atan2(dir.z, dir.x)
			if shoot_timer >= shoot_interval:
				shoot_timer = 0.0
				_shoot_at(target)


func _find_nearest_alien() -> Node3D:
	var closest: Node3D = null
	var closest_dist = CFG.turret_range
	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien):
			continue
		var d = global_position.distance_to(alien.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = alien
	return closest


func _shoot_at(target: Node3D):
	var dir = (target.global_position - global_position).normalized()
	var count = bullet_count
	var spread = 0.0
	if count > 1:
		spread = 0.25 + count * 0.05

	for i in range(count):
		var bullet = preload("res://scenes/bullet.tscn").instantiate()
		var off = 0.0
		if count > 1:
			off = lerpf(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
		var spawn_pos = global_position + dir * 20
		var base_angle = atan2(dir.z, dir.x) + off
		bullet.direction = Vector3(cos(base_angle), 0, sin(base_angle))
		bullet.damage = CFG.turret_base_damage + damage_bonus + acid_damage_bonus
		bullet.from_turret = true
		if ice_rounds:
			bullet.slow_amount = 0.3
		if fire_rounds:
			bullet.burn_dps = 6.0
		get_tree().current_scene.game_world_2d.add_child(bullet)
		bullet.global_position = spawn_pos
		get_tree().current_scene.spawn_synced_bullet(bullet.global_position, bullet.direction, true, bullet.burn_dps, bullet.slow_amount)


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		SFXManager.play("explode_small")
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	if not is_inside_tree():
		return
	var spawn_pos = global_position
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(3):
		var alien = alien_scene.instantiate()
		alien.global_position = spawn_pos + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		alien.hp = 25
		alien.max_hp = 25
		alien.damage = 6
		alien.speed = 55.0
		get_tree().current_scene.aliens_node.add_child(alien)
