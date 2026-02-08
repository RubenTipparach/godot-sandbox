extends Node2D

const CFG = preload("res://resources/game_config.tres")

var lifetime: float = CFG.acid_puddle_duration
var tick_timer: float = 0.0
var radius: float = CFG.acid_puddle_radius


func _ready():
	add_to_group("acid_puddles")


func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	tick_timer += delta
	if tick_timer >= CFG.acid_puddle_tick:
		tick_timer -= CFG.acid_puddle_tick
		for alien in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(alien):
				continue
			if global_position.distance_to(alien.global_position) < radius:
				alien.take_damage(CFG.acid_puddle_dps)
				if "acid_timer" in alien:
					alien.acid_timer = 1.0

	queue_redraw()


func _draw():
	var fade = clampf(lifetime / 1.0, 0.0, 1.0)  # Fade out in last second
	var base_alpha = 0.35 * fade

	# Main puddle
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.7, 0.1, base_alpha * 0.5))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(0.3, 0.85, 0.15, base_alpha * 0.7))

	# Bubbles
	var t = Time.get_ticks_msec() * 0.003
	for i in range(5):
		var angle = t + i * TAU / 5.0
		var dist = radius * 0.4 + sin(t * 2.0 + i) * radius * 0.2
		var bpos = Vector2.from_angle(angle) * dist
		var bsize = 3.0 + sin(t * 3.0 + i * 1.5) * 1.5
		draw_circle(bpos, bsize, Color(0.4, 0.95, 0.2, base_alpha))

	# Edge ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.3, 0.9, 0.15, base_alpha * 0.6), 2.0)
