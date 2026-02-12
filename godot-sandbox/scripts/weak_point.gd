extends Node3D

var hp: int = 300
var max_hp: int = 300
var boss_ref: Node3D = null
var wp_index: int = 0
var hit_flash_timer: float = 0.0
var orbit_angle: float = 0.0
var orbit_distance: float = 40.0


func _ready():
	add_to_group("aliens")
	add_to_group("weak_points")


func _process(delta):
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	if is_instance_valid(boss_ref):
		orbit_angle += delta * 0.8
		var offset = Vector3(cos(orbit_angle) * orbit_distance, 0, sin(orbit_angle) * orbit_distance)
		global_position = boss_ref.global_position + offset


func take_damage(amount: int):
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		if is_instance_valid(boss_ref) and boss_ref.has_method("on_weak_point_destroyed"):
			boss_ref.on_weak_point_destroyed(wp_index)
		queue_free()


func apply_burn(_dps: float, _duration: float = 3.0):
	pass

func apply_slow(_amount: float, _duration: float = 2.0):
	pass

func apply_poison(_dps: float, _duration: float = 5.0):
	pass

func can_take_orbital_hit() -> bool:
	return true
