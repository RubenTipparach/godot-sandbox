extends Node2D

var xp_value: int = 1
var gem_size: int = 1
var bob_offset: float = 0.0


func _ready():
	add_to_group("xp_gems")
	bob_offset = randf() * TAU


func _process(delta):
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var dist = global_position.distance_to(p.global_position)

		# Check if player has magnet active - pull from entire map
		if p.magnet_timer > 0:
			var dir = (p.global_position - global_position).normalized()
			var pull_speed = 600.0 + (2000.0 - dist) * 0.3
			position += dir * pull_speed * delta
		elif dist < 120:
			# Normal magnetic pull when close
			var dir = (p.global_position - global_position).normalized()
			position += dir * 300.0 * (1.0 - dist / 120.0) * delta

	bob_offset += delta * 3.0
	queue_redraw()


func collect():
	queue_free()


func _draw():
	var colors = [Color(0.3, 0.9, 0.4), Color(0.3, 0.6, 1.0), Color(0.9, 0.3, 0.9)]
	var color = colors[clampi(gem_size - 1, 0, 2)]
	var sz = 3.0 + gem_size * 1.5
	var bob = sin(bob_offset) * 2.0

	var pts = PackedVector2Array([
		Vector2(0, -sz + bob),
		Vector2(sz * 0.6, bob),
		Vector2(0, sz + bob),
		Vector2(-sz * 0.6, bob),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color.lightened(0.4), 1.0)
	draw_circle(Vector2(0, bob), sz * 0.4, Color(color.r, color.g, color.b, 0.3))
