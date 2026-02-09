extends Node2D

const CFG = preload("res://resources/game_config.tres")

var selected_building: Node2D = null


func _process(_delta):
	queue_redraw()


func _draw():
	var hs = CFG.map_half_size
	draw_rect(Rect2(-hs, -hs, hs * 2, hs * 2), Color(1, 0.3, 0.2, 0.3), false, 3.0)
	draw_rect(Rect2(-hs + 50, -hs + 50, (hs - 50) * 2, (hs - 50) * 2), Color(1, 0.3, 0.2, 0.08), false, 1.0)

	if is_instance_valid(selected_building):
		var bpos = selected_building.global_position
		var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.3
		draw_arc(bpos, 22, 0, TAU, 32, Color(0.3, 0.8, 1.0, pulse), 1.5)
		draw_arc(bpos, 24, 0, TAU, 32, Color(0.3, 0.8, 1.0, pulse * 0.4), 1.0)
