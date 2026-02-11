extends Node3D

var points: Array = []
var lifetime: float = 0.2


func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
