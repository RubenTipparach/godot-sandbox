extends Node3D

var text: String = ""
var color: Color = Color.WHITE
var lifetime: float = 1.2
var velocity: Vector3 = Vector3(0, 40, 0)


func _process(delta):
	position += velocity * delta
	velocity *= 0.95
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
