extends Node2D

var resource_type: String = "iron" # "iron" or "crystal"
var amount: int = 10
var net_id: int = -1


func _ready():
	add_to_group("resources")
	queue_redraw()


func mine(qty: int) -> Dictionary:
	var mined = mini(qty, amount)
	amount -= mined
	if amount <= 0:
		queue_free()
	else:
		queue_redraw()
	return {"type": resource_type, "amount": mined}


func _draw():
	var size: float = 10.0 + amount * 0.5

	if resource_type == "iron":
		# Gray hexagon
		var color = Color(0.6, 0.55, 0.5)
		var points = PackedVector2Array()
		for i in range(6):
			points.append(Vector2.from_angle(TAU * i / 6.0) * size)
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0.4, 0.35, 0.3), 1.5)
		# Inner detail
		var inner = PackedVector2Array()
		for i in range(6):
			inner.append(Vector2.from_angle(TAU * i / 6.0 + 0.5) * size * 0.5)
		draw_polyline(inner + PackedVector2Array([inner[0]]), Color(0.45, 0.4, 0.35), 1.0)
	else:
		# Blue diamond
		var color = Color(0.3, 0.5, 0.9)
		var points = PackedVector2Array([
			Vector2(0, -size),
			Vector2(size * 0.7, 0),
			Vector2(0, size),
			Vector2(-size * 0.7, 0)
		])
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0.5, 0.7, 1.0), 1.5)
		# Shine
		draw_line(Vector2(-size * 0.2, -size * 0.4), Vector2(size * 0.1, -size * 0.1), Color(0.7, 0.85, 1.0, 0.6), 1.5)

	# Amount indicator dots
	var dots = mini(amount / 3, 5)
	for i in range(dots):
		draw_circle(Vector2(-6 + i * 3, size + 6), 1.5, Color(1, 1, 1, 0.5))
