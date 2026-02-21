extends Node3D

var resource_type: String = "iron" # "iron" or "crystal"
var amount: int = 10
var max_amount: int = 10
var target_amount: int = 10  # The full 100% capacity of this deposit
var net_id: int = -1
var _prev_amount: int = -1  # Track amount changes for pop-in animation


func _ready():
	add_to_group("resources")
	if target_amount <= 0:
		target_amount = amount
	max_amount = target_amount


func mine(qty: int) -> Dictionary:
	var mined = mini(qty, amount)
	amount -= mined
	if amount <= 0:
		queue_free()
	return {"type": resource_type, "amount": mined}


func regen(qty: int):
	amount = mini(amount + qty, max_amount)


func regrow_toward_cap(cap_pct: float, regrow_pct: float):
	var cap = int(target_amount * cap_pct)
	max_amount = cap
	if amount < cap:
		var missing = cap - amount
		var restore = maxi(1, int(missing * regrow_pct))
		amount = mini(amount + restore, cap)


func did_amount_increase() -> bool:
	if _prev_amount < 0:
		_prev_amount = amount
		return true  # First frame = treat as pop-in
	var increased = amount > _prev_amount
	_prev_amount = amount
	return increased
