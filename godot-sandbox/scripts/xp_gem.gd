extends Node2D

var xp_value: int = 1
var gem_size: int = 1
var bob_offset: float = 0.0
var trail: Array = []
var lifetime: float = 15.0
const MAX_TRAIL = 6


func _ready():
	add_to_group("xp_gems")
	bob_offset = randf() * TAU


func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	var old_pos = global_position

	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		if not p.is_local: continue
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

	# Trail when moving toward player
	if global_position.distance_to(old_pos) > 1.0:
		trail.append({"pos": old_pos - global_position, "life": 0.25})
	for i in range(trail.size() - 1, -1, -1):
		trail[i]["life"] -= delta
		if trail[i]["life"] <= 0:
			trail.remove_at(i)
	while trail.size() > MAX_TRAIL:
		trail.remove_at(0)

	bob_offset += delta * 3.0
	queue_redraw()


func collect():
	queue_free()


func _draw():
	var colors = [Color(0.3, 0.9, 0.4), Color(0.3, 0.6, 1.0), Color(0.9, 0.3, 0.9)]
	var color = colors[clampi(gem_size - 1, 0, 2)]
	var sz = 3.0 + gem_size * 1.5
	var bob = sin(bob_offset) * 2.0

	# Draw trail
	for t in trail:
		var alpha = t["life"] / 0.25
		draw_circle(t["pos"], sz * 0.4 * alpha, Color(color.r, color.g, color.b, 0.3 * alpha))

	var pts = PackedVector2Array([
		Vector2(0, -sz + bob),
		Vector2(sz * 0.6, bob),
		Vector2(0, sz + bob),
		Vector2(-sz * 0.6, bob),
	])
	var fade = clampf(lifetime / 3.0, 0.0, 1.0)
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, fade))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.lightened(0.4).r, color.lightened(0.4).g, color.lightened(0.4).b, fade), 1.0)
	draw_circle(Vector2(0, bob), sz * 0.4, Color(color.r, color.g, color.b, 0.3 * fade))
