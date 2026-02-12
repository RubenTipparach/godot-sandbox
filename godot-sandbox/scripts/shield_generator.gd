extends Node3D

var hp: int = 200
var max_hp: int = 200
var spider_boss_ref: Node3D = null
var hit_flash_timer: float = 0.0
var net_id: int = 0


func _ready():
	add_to_group("shield_generators")
	add_to_group("aliens")


func _process(delta):
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)


func take_damage(amount: int):
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		if is_instance_valid(spider_boss_ref):
			spider_boss_ref.on_generator_destroyed()
		var gem = preload("res://scenes/xp_gem.tscn").instantiate()
		gem.xp_value = 5
		gem.gem_size = 2
		get_tree().current_scene.game_world_2d.add_child(gem)
		gem.global_position = global_position
		queue_free()


func apply_burn(_dps: float, _duration: float = 3.0):
	pass

func apply_slow(_amount: float, _duration: float = 2.0):
	pass

func apply_poison(_dps: float, _duration: float = 5.0):
	pass

func can_take_orbital_hit() -> bool:
	return true
