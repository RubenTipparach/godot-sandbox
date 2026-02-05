extends Node2D

var hp: int = 60
var max_hp: int = 60
var zap_timer: float = 0.0
var zap_targets: Array = []
var power_blink_timer: float = 0.0
const ZAP_INTERVAL = 1.5
const RANGE = 180.0
const DAMAGE = 15


func _ready():
	add_to_group("buildings")
	add_to_group("lightnings")


func is_powered() -> bool:
	for plant in get_tree().get_nodes_in_group("power_plants"):
		if is_instance_valid(plant) and global_position.distance_to(plant.global_position) < plant.POWER_RANGE:
			return true
	for pylon in get_tree().get_nodes_in_group("pylons"):
		if is_instance_valid(pylon) and global_position.distance_to(pylon.global_position) < pylon.POWER_RANGE:
			if pylon.is_powered():
				return true
	return false


func _process(delta):
	power_blink_timer += delta
	zap_targets.clear()
	var powered = is_powered()

	if powered:
		zap_timer += delta
		if zap_timer >= ZAP_INTERVAL:
			zap_timer = 0.0
			_zap_enemies()

	queue_redraw()


func _zap_enemies():
	var aliens = get_tree().get_nodes_in_group("aliens")
	for alien in aliens:
		if not is_instance_valid(alien):
			continue
		if global_position.distance_to(alien.global_position) < RANGE:
			alien.take_damage(DAMAGE)
			zap_targets.append(alien.global_position - global_position)


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(3):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		alien.hp = 25
		alien.max_hp = 25
		alien.damage = 6
		alien.speed = 55.0
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var powered = is_powered()

	# Tower base
	draw_rect(Rect2(-12, -8, 24, 20), Color(0.3, 0.3, 0.4) if powered else Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(-8, -20, 16, 14), Color(0.35, 0.35, 0.45) if powered else Color(0.28, 0.28, 0.35))

	# Lightning orb at top
	if powered:
		var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.01) * 0.3
		draw_circle(Vector2(0, -24), 8, Color(0.3, 0.5, 1.0, 0.3 * pulse))
		draw_circle(Vector2(0, -24), 5, Color(0.5, 0.7, 1.0, pulse))
		draw_circle(Vector2(0, -24), 2, Color(1.0, 1.0, 1.0))
	else:
		draw_circle(Vector2(0, -24), 5, Color(0.3, 0.3, 0.4))

	# Range indicator
	draw_arc(Vector2.ZERO, RANGE, 0, TAU, 48, Color(0.3, 0.5, 1.0, 0.04), 1.0)

	# Zap lines
	for target in zap_targets:
		draw_line(Vector2(0, -24), target, Color(0.5, 0.8, 1.0, 0.8), 2.0)
		draw_line(Vector2(0, -24), target, Color(1.0, 1.0, 1.0, 0.5), 1.0)

	# HP bar
	draw_rect(Rect2(-12, -32, 24, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-12, -32, 24.0 * hp / max_hp, 3), Color(0, 0.8, 0))

	# No power warning
	if not powered:
		var blink = fmod(power_blink_timer * 3.0, 1.0) < 0.5
		var warn_color = Color(1.0, 0.9, 0.0) if blink else Color(0.1, 0.1, 0.1)
		draw_colored_polygon(PackedVector2Array([
			Vector2(2, -4), Vector2(-2, 4), Vector2(1, 4),
			Vector2(-3, 12), Vector2(1, 7), Vector2(-1, 7), Vector2(3, -4)
		]), warn_color)
