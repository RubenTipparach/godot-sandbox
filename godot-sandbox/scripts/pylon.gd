extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_pylon
var max_hp: int = CFG.hp_pylon
var power_blink_timer: float = 0.0
var POWER_RANGE: float = CFG.power_range_pylon


func _ready():
	add_to_group("buildings")
	add_to_group("pylons")


func get_building_name() -> String:
	return "Pylon"


func _process(delta):
	power_blink_timer += delta
	queue_redraw()


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		# Pylons don't spawn aliens when destroyed
		queue_free()


func is_powered() -> bool:
	var main = get_tree().current_scene
	if main and "power_on" in main and not main.power_on:
		return false
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
	var base_color = Color(0.3, 0.6, 0.9) if powered else Color(0.35, 0.3, 0.25)
	var tower_color = Color(0.35, 0.35, 0.4) if powered else Color(0.28, 0.28, 0.32)

	# Draw power wires FIRST (behind the pylon)
	var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.3
	var wire_color = Color(0.3, 0.7, 1.0, 0.6) if powered else Color(0.4, 0.35, 0.3, 0.3)

	# Wires to other pylons
	for pylon in get_tree().get_nodes_in_group("pylons"):
		if not is_instance_valid(pylon) or pylon == self:
			continue
		var dist = global_position.distance_to(pylon.global_position)
		if dist < POWER_RANGE * 2:
			var target = pylon.global_position - global_position
			# Draw wire with slight sag
			var mid = target / 2.0 + Vector2(0, dist * 0.08)
			_draw_wire(Vector2(0, -18), mid, target + Vector2(0, -18), wire_color if powered and pylon.is_powered() else Color(0.4, 0.35, 0.3, 0.3))

	# Wires to power plants
	for plant in get_tree().get_nodes_in_group("power_plants"):
		if not is_instance_valid(plant):
			continue
		var dist = global_position.distance_to(plant.global_position)
		if dist < POWER_RANGE + plant.POWER_RANGE:
			var target = plant.global_position - global_position
			var mid = target / 2.0 + Vector2(0, dist * 0.08)
			_draw_wire(Vector2(0, -18), mid, target + Vector2(0, -8), Color(0.3, 0.7, 1.0, 0.7))

	# Pylon base
	draw_rect(Rect2(-8, 4, 16, 8), Color(0.4, 0.4, 0.45) if powered else Color(0.32, 0.32, 0.36))

	# Pylon tower
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 4),
		Vector2(-3, -18),
		Vector2(3, -18),
		Vector2(6, 4),
	]), tower_color)

	# Top connector
	draw_rect(Rect2(-10, -20, 20, 4), base_color)

	# Power glow if powered
	if powered:
		draw_circle(Vector2(0, -18), 5, Color(0.3, 0.7, 1.0, pulse))
	else:
		draw_circle(Vector2(0, -18), 4, Color(0.3, 0.3, 0.35))
		# Blinking power warning
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_polyline(PackedVector2Array([
			Vector2(1, -10), Vector2(-1.5, -5), Vector2(1.5, -4), Vector2(-1, 2)
		]), warn_color, 2.0)

	# Power range disc (only when powered)
	if powered:
		draw_circle(Vector2.ZERO, POWER_RANGE, Color(0.2, 0.5, 1.0, 0.05))
	draw_arc(Vector2.ZERO, POWER_RANGE, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.05), 1.0)

	# HP bar
	draw_rect(Rect2(-10, -26, 20, 2), Color(0.3, 0, 0))
	draw_rect(Rect2(-10, -26, 20.0 * hp / max_hp, 2), Color(0, 0.8, 0))


func _draw_wire(start: Vector2, mid: Vector2, end: Vector2, color: Color):
	# Draw a sagging wire using quadratic bezier approximation
	var points = PackedVector2Array()
	for i in range(9):
		var t = i / 8.0
		var p = start.lerp(mid, t).lerp(mid.lerp(end, t), t)
		points.append(p)
	draw_polyline(points, color, 1.5)
