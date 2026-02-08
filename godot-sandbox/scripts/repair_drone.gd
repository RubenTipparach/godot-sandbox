extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_repair_drone
var max_hp: int = CFG.hp_repair_drone
var repair_timer: float = 0.0
var power_blink_timer: float = 0.0
var manually_disabled: bool = false
var repair_targets: Array = []
var drone_angle: float = 0.0


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
	power_blink_timer += delta
	drone_angle += delta * 2.0
	var powered = is_powered()

	repair_targets.clear()
	if powered:
		repair_timer += delta
		if repair_timer >= CFG.repair_drone_tick_interval:
			repair_timer -= CFG.repair_drone_tick_interval
			_repair_nearby()

	queue_redraw()


func _repair_nearby():
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
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(2):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		alien.hp = 20
		alien.max_hp = 20
		alien.damage = 5
		alien.speed = 50.0
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var powered = is_powered()
	var rng = get_repair_range()

	# Base platform
	draw_rect(Rect2(-14, -4, 28, 12), Color(0.35, 0.35, 0.4) if powered else Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(-14, -4, 28, 12), Color(0.45, 0.45, 0.5), false, 1.5)

	# Drone body (hovering above platform)
	var hover_offset = sin(drone_angle) * 2.0
	var drone_pos = Vector2(0, -14 + hover_offset)

	draw_circle(drone_pos, 8, Color(0.4, 0.5, 0.4) if powered else Color(0.3, 0.35, 0.3))
	draw_arc(drone_pos, 8, 0, TAU, 16, Color(0.3, 0.8, 0.4) if powered else Color(0.3, 0.4, 0.3), 1.5)

	# Propeller arms
	if powered:
		var prop_angle = drone_angle * 5.0
		for i in range(4):
			var a = prop_angle + TAU * i / 4.0
			var arm_end = drone_pos + Vector2.from_angle(a) * 10
			draw_line(drone_pos, arm_end, Color(0.5, 0.5, 0.55), 1.5)
			draw_circle(arm_end, 2, Color(0.5, 0.6, 0.5, 0.5))
	else:
		# Static arms when unpowered
		for i in range(4):
			var a = TAU * i / 4.0 + PI / 4.0
			var arm_end = drone_pos + Vector2.from_angle(a) * 10
			draw_line(drone_pos, arm_end, Color(0.4, 0.4, 0.45), 1.5)

	# Repair beam effects
	if powered:
		for target in repair_targets:
			if is_instance_valid(target):
				var target_local = target.global_position - global_position
				var repair_color = Color(0.3, 1.0, 0.5)
				var flicker = 0.7 + sin(Time.get_ticks_msec() * 0.02) * 0.3
				draw_line(drone_pos, target_local, Color(repair_color.r, repair_color.g, repair_color.b, 0.3 * flicker), 3.0)
				draw_line(drone_pos, target_local, Color(1, 1, 1, 0.2 * flicker), 1.0)

	# Green glow when powered
	if powered:
		var glow = 0.1 + sin(drone_angle * 2.0) * 0.05
		draw_circle(drone_pos, 4, Color(0.3, 1.0, 0.4, glow))

	# Range indicator
	draw_arc(Vector2.ZERO, rng, 0, TAU, 64, Color(0.3, 1.0, 0.4, 0.04), 1.0)

	# HP bar
	draw_rect(Rect2(-14, -28, 28, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-14, -28, 28.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_polyline(PackedVector2Array([
			Vector2(1, -14), Vector2(-2, -7), Vector2(2, -6), Vector2(-1, 2)
		]), warn_color, 2.5)
