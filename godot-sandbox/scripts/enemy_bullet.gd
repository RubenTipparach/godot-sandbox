extends Node2D

var direction: Vector2 = Vector2.RIGHT
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

	queue_redraw()


func _draw():
	draw_circle(Vector2.ZERO, 3.0, Color(0.8, 0.2, 1.0))
	draw_circle(Vector2.ZERO, 1.5, Color(1, 0.6, 1.0, 0.7))
	draw_line(Vector2.ZERO, -direction * 5.0, Color(0.8, 0.2, 1.0, 0.3), 2.0)
