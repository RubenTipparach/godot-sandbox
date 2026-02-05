extends Node2D

var hp: int = 40
var max_hp: int = 40
const POWER_RANGE = 150.0  # Range to connect to other pylons/buildings


func _ready():
	add_to_group("buildings")
	add_to_group("pylons")


func _process(_delta):
	queue_redraw()


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		# Pylons don't spawn aliens when destroyed
		queue_free()


func is_powered() -> bool:
	# Check if connected to a power plant (directly or through other pylons)
	return _trace_power_to_plant([self])


func _trace_power_to_plant(visited: Array) -> bool:
	# Check direct connection to power plant
	for plant in get_tree().get_nodes_in_group("power_plants"):
		if not is_instance_valid(plant):
			continue
		if global_position.distance_to(plant.global_position) < POWER_RANGE + plant.POWER_RANGE:
			return true

	# Check connection through other pylons
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


func _draw():
	var powered = is_powered()
	var base_color = Color(0.3, 0.6, 0.9) if powered else Color(0.5, 0.4, 0.3)

	# Pylon base
	draw_rect(Rect2(-8, 4, 16, 8), Color(0.4, 0.4, 0.45))

	# Pylon tower
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 4),
		Vector2(-3, -18),
		Vector2(3, -18),
		Vector2(6, 4),
	]), Color(0.35, 0.35, 0.4))

	# Top connector
	draw_rect(Rect2(-10, -20, 20, 4), base_color)

	# Power glow if powered
	if powered:
		var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.3
		draw_circle(Vector2(0, -18), 5, Color(0.3, 0.7, 1.0, pulse))

		# Draw connection lines to nearby powered pylons
		for pylon in get_tree().get_nodes_in_group("pylons"):
			if not is_instance_valid(pylon) or pylon == self:
				continue
			var dist = global_position.distance_to(pylon.global_position)
			if dist < POWER_RANGE * 2 and pylon.is_powered():
				var dir = (pylon.global_position - global_position)
				draw_line(Vector2(0, -18), dir.normalized() * minf(dist, 30), Color(0.3, 0.7, 1.0, 0.3), 1.5)

	# Range indicator (faint)
	draw_arc(Vector2.ZERO, POWER_RANGE, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.05), 1.0)

	# HP bar
	draw_rect(Rect2(-10, -26, 20, 2), Color(0.3, 0, 0))
	draw_rect(Rect2(-10, -26, 20.0 * hp / max_hp, 2), Color(0, 0.8, 0))
