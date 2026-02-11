extends Node3D

var resource_type: String = "iron" # "iron" or "crystal"
var amount: int = 10
var net_id: int = -1


func _ready():
	add_to_group("resources")


func mine(qty: int) -> Dictionary:
	var mined = mini(qty, amount)
	amount -= mined
	if amount <= 0:
		queue_free()
	return {"type": resource_type, "amount": mined}
