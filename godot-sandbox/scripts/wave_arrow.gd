extends Control

var direction: float = 0.0
var visible_arrow: bool = false


func set_direction(angle: float):
	direction = angle
	visible_arrow = true
	queue_redraw()


func hide_arrow():
	visible_arrow = false
	queue_redraw()


func _draw():
	if not visible_arrow:
		return

	# Draw large red arrow pointing toward wave spawn direction
	var arrow_dist = 280.0
	var arrow_size = 40.0
	var center = Vector2.ZERO

	var tip = center + Vector2.from_angle(direction) * arrow_dist
	var back_left = tip - Vector2.from_angle(direction) * arrow_size + Vector2.from_angle(direction + PI / 2) * (arrow_size * 0.5)
	var back_right = tip - Vector2.from_angle(direction) * arrow_size + Vector2.from_angle(direction - PI / 2) * (arrow_size * 0.5)
	var back_center = tip - Vector2.from_angle(direction) * (arrow_size * 0.6)

	# Pulsing effect
	var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.3

	# Arrow body (triangle)
	var pts = PackedVector2Array([tip, back_left, back_center, back_right])
	draw_colored_polygon(pts, Color(1.0, 0.15, 0.1, 0.7 * pulse))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.4, 0.3, 0.9 * pulse), 2.0)

	# Warning text
	var font = ThemeDB.fallback_font
	var text_pos = center + Vector2.from_angle(direction) * (arrow_dist - 70)
	draw_string(font, text_pos + Vector2(-40, 5), "NEXT WAVE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.3, 0.2, pulse))


func _process(_delta):
	if visible_arrow:
		queue_redraw()
