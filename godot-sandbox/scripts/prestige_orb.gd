extends Node3D

var prestige_value: int = 1
var bob_offset: float = 0.0
var lifetime: float = 20.0


func _ready():
	add_to_group("prestige_orbs")
	bob_offset = randf() * TAU


func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		if not p.is_local: continue
		var dist = global_position.distance_to(p.global_position)

		if p.magnet_timer > 0:
			var dir = (p.global_position - global_position).normalized()
			var pull_speed = 600.0 + (2000.0 - dist) * 0.3
			position += dir * pull_speed * delta
		elif dist < 120:
			var dir = (p.global_position - global_position).normalized()
			position += dir * 300.0 * (1.0 - dist / 120.0) * delta

	bob_offset += delta * 2.5


func collect():
	queue_free()
