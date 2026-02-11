extends Node3D

var powerup_type: String = "magnet"
var bob_offset: float = 0.0
var lifetime: float = 60.0


func _ready():
	add_to_group("powerups")
	bob_offset = randf() * TAU


func _process(delta):
	bob_offset += delta * 2.5
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
