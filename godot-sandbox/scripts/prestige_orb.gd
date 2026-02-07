extends Node2D

var prestige_value: int = 1
var bob_offset: float = 0.0
var pulse_timer: float = 0.0


func _ready():
	add_to_group("prestige_orbs")
	bob_offset = randf() * TAU


func _process(delta):
	pulse_timer += delta

	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var dist = global_position.distance_to(p.global_position)

		# Magnet pull when close
		if p.magnet_timer > 0:
			var dir = (p.global_position - global_position).normalized()
			var pull_speed = 600.0 + (2000.0 - dist) * 0.3
			position += dir * pull_speed * delta
		elif dist < 120:
			var dir = (p.global_position - global_position).normalized()
			position += dir * 300.0 * (1.0 - dist / 120.0) * delta

	bob_offset += delta * 2.5
	queue_redraw()


func collect():
	queue_free()


func _draw():
	var bob = sin(bob_offset) * 2.0
	var pulse = 0.7 + sin(pulse_timer * 4.0) * 0.3
	var sz = 5.0

	# Outer glow
	draw_circle(Vector2(0, bob), sz + 3, Color(1.0, 0.85, 0.3, 0.15 * pulse))

	# Main star shape
	var pts = PackedVector2Array()
	for i in range(8):
		var angle = TAU * i / 8.0 - PI / 2
		var r = sz if i % 2 == 0 else sz * 0.5
		pts.append(Vector2.from_angle(angle) * r + Vector2(0, bob))
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, pulse))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.95, 0.6), 1.0)

	# Inner core
	draw_circle(Vector2(0, bob), sz * 0.35, Color(1.0, 1.0, 0.8, 0.7))
