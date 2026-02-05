extends Node2D

var points: Array = []
var lifetime: float = 0.2


func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	queue_redraw()


func _draw():
	if points.size() < 2:
		return
	var alpha = lifetime / 0.2
	var color = Color(0.3, 0.7, 1.0, alpha)
	var bright = Color(0.8, 0.95, 1.0, alpha)

	for i in range(points.size() - 1):
		var start = points[i] - global_position
		var end = points[i + 1] - global_position
		var prev = start
		for j in range(5):
			var t = float(j + 1) / 5.0
			var pt = start.lerp(end, t)
			if j < 4:
				var perp = (end - start).normalized().rotated(PI / 2)
				pt += perp * randf_range(-8, 8)
			draw_line(prev, pt, color, 2.0)
			draw_line(prev, pt, bright, 1.0)
			prev = pt
