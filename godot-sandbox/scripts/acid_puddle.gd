extends Node3D

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
