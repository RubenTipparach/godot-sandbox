extends Node3D

var points: Array = []
var lifetime: float = 0.5


func _ready():
	add_to_group("chain_fx")


func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
