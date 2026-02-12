extends Node3D

var xp_value: int = 1
var gem_size: int = 1
var bob_offset: float = 0.0
var chasing: bool = false


func _ready():
	add_to_group("xp_gems")
	bob_offset = randf() * TAU


func _process(delta):
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		if not p.is_local: continue
		var dist = global_position.distance_to(p.global_position)

		if p.magnet_timer > 0:
			chasing = true
			var dir = (p.global_position - global_position).normalized()
			var pull_speed = 600.0 + (2000.0 - dist) * 0.3
			position += dir * pull_speed * delta
		elif chasing:
			var dir = (p.global_position - global_position).normalized()
			var pull_speed = 400.0 + maxf(0, 300.0 - dist) * 2.0
			position += dir * pull_speed * delta
		elif dist < 120:
			chasing = true
			var dir = (p.global_position - global_position).normalized()
			position += dir * 300.0 * (1.0 - dist / 120.0) * delta

	bob_offset += delta * 3.0


func collect():
	queue_free()
