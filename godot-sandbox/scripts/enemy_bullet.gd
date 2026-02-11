extends Node3D

var direction: Vector3 = Vector3.RIGHT
var speed: float = 200.0
var damage: int = 5
var lifetime: float = 5.0
var visual_only: bool = false


func _process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	if not visual_only:
		for p in get_tree().get_nodes_in_group("player"):
			if not is_instance_valid(p): continue
			if global_position.distance_to(p.global_position) < 12:
				p.take_damage(damage)
				queue_free()
				return

		for b in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(b): continue
			if global_position.distance_to(b.global_position) < 20:
				if b.has_method("take_damage"):
					b.take_damage(damage)
				queue_free()
				return
