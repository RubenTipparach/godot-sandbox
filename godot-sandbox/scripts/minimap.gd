extends Control

const MAP_SIZE = 2000.0
const MM_SIZE = 160.0
const SCALE = MM_SIZE / MAP_SIZE
const OFFSET = Vector2(MM_SIZE / 2.0, MM_SIZE / 2.0)

var wave_direction: float = 0.0
var show_wave_direction: bool = false


func set_wave_direction(angle: float):
	wave_direction = angle
	show_wave_direction = true


func _process(_delta):
	queue_redraw()


func _draw():
	# Background
	draw_rect(Rect2(0, 0, MM_SIZE, MM_SIZE), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(0, 0, MM_SIZE, MM_SIZE), Color(0.5, 0.5, 0.5, 0.3), false, 1.0)

	# Resources
	for r in get_tree().get_nodes_in_group("resources"):
		var pos = r.global_position * SCALE + OFFSET
		if not _in_bounds(pos): continue
		var c = Color(0.5, 0.5, 0.4) if r.resource_type == "iron" else Color(0.3, 0.5, 0.9)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), c)

	# Buildings
	var blink = fmod(Time.get_ticks_msec() / 1000.0 * 3.0, 1.0) < 0.5
	for b in get_tree().get_nodes_in_group("buildings"):
		var pos = b.global_position * SCALE + OFFSET
		if not _in_bounds(pos): continue

		var building_color = Color(1, 0.8, 0.2)  # Default powered color

		# Check if building needs power and doesn't have it
		if b.has_method("is_powered"):
			if not b.is_powered():
				# Blink between yellow/red for unpowered buildings
				building_color = Color(1.0, 0.9, 0.0) if blink else Color(0.4, 0.3, 0.1)

		# Special colors for power infrastructure
		if b.is_in_group("power_plants"):
			building_color = Color(0.3, 0.7, 1.0)  # Blue for power plants
		elif b.is_in_group("pylons"):
			if b.is_powered():
				building_color = Color(0.5, 0.8, 1.0)  # Light blue for powered pylons
			else:
				building_color = Color(0.5, 0.8, 1.0) if blink else Color(0.3, 0.4, 0.5)

		draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), building_color)

	# Aliens
	for a in get_tree().get_nodes_in_group("aliens"):
		var pos = a.global_position * SCALE + OFFSET
		if not _in_bounds(pos): continue
		var c = Color(1, 0.2, 0.1)
		if a.is_in_group("bosses"):
			c = Color(1, 0.1, 0.5)
			draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), c)
		else:
			draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), c)

	# XP gems
	for g in get_tree().get_nodes_in_group("xp_gems"):
		var pos = g.global_position * SCALE + OFFSET
		if not _in_bounds(pos): continue
		draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.3, 0.9, 0.4, 0.5))

	# Powerups
	for p in get_tree().get_nodes_in_group("powerups"):
		var pos = p.global_position * SCALE + OFFSET
		if not _in_bounds(pos): continue
		draw_circle(pos, 3, Color(1.0, 0.9, 0.3))

	# Player
	for p in get_tree().get_nodes_in_group("player"):
		var pos = p.global_position * SCALE + OFFSET
		draw_circle(pos, 3, Color(0.2, 1, 0.3))

	# Wave direction indicator
	if show_wave_direction:
		var center = OFFSET
		var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.3
		var arrow_color = Color(1.0, 0.2, 0.1, pulse)

		# Arrow on edge of minimap pointing inward
		var edge_dist = MM_SIZE / 2.0 - 8
		var arrow_pos = center + Vector2.from_angle(wave_direction) * edge_dist
		var arrow_size = 10.0

		# Triangle pointing toward center
		var inward_dir = (center - arrow_pos).normalized()
		var tip = arrow_pos + inward_dir * arrow_size
		var back_left = arrow_pos + Vector2.from_angle(wave_direction + PI / 2) * (arrow_size * 0.5)
		var back_right = arrow_pos + Vector2.from_angle(wave_direction - PI / 2) * (arrow_size * 0.5)

		draw_colored_polygon(PackedVector2Array([tip, back_left, back_right]), arrow_color)
		draw_polyline(PackedVector2Array([tip, back_left, back_right, tip]), Color(1.0, 0.5, 0.3, pulse), 1.5)


func _in_bounds(pos: Vector2) -> bool:
	return pos.x >= 0 and pos.x <= MM_SIZE and pos.y >= 0 and pos.y <= MM_SIZE
