extends Node2D

var prestige_value: int = 1
var bob_offset: float = 0.0
var pulse_timer: float = 0.0
var trail: Array = []
const MAX_TRAIL = 6


func _ready():
	add_to_group("prestige_orbs")
	bob_offset = randf() * TAU


func _process(delta):
	pulse_timer += delta
	var old_pos = global_position

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

	# Trail when moving toward player
	if global_position.distance_to(old_pos) > 1.0:
		trail.append({"pos": old_pos - global_position, "life": 0.3})
	for i in range(trail.size() - 1, -1, -1):
		trail[i]["life"] -= delta
		if trail[i]["life"] <= 0:
			trail.remove_at(i)
	while trail.size() > MAX_TRAIL:
		trail.remove_at(0)

	bob_offset += delta * 2.5
	queue_redraw()


func collect():
	queue_free()


func _draw():
	var bob = sin(bob_offset) * 2.0
	var pulse = 0.7 + sin(pulse_timer * 4.0) * 0.3
	var sz = 5.0

	# Draw trail
	for t in trail:
		var alpha = t["life"] / 0.3
		draw_circle(t["pos"], sz * 0.5 * alpha, Color(1.0, 0.9, 0.3, 0.3 * alpha))

	# Outer glow
	draw_circle(Vector2(0, bob), sz + 4, Color(1.0, 0.9, 0.2, 0.12 * pulse))
	draw_circle(Vector2(0, bob), sz + 2, Color(1.0, 0.85, 0.3, 0.2 * pulse))

	# Main orb
	draw_circle(Vector2(0, bob), sz, Color(1.0, 0.85, 0.3, pulse))

	# Inner bright core
	draw_circle(Vector2(0, bob), sz * 0.5, Color(1.0, 0.95, 0.6, 0.9))

	# Highlight
	draw_circle(Vector2(-sz * 0.2, bob - sz * 0.2), sz * 0.2, Color(1.0, 1.0, 0.9, 0.6))
