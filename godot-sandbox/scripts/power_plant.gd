extends Node2D

var hp: int = 100
var max_hp: int = 100
var pulse_timer: float = 0.0
const POWER_RANGE = 120.0  # Range to power nearby pylons/buildings directly


func _ready():
	add_to_group("buildings")
	add_to_group("power_plants")


func get_building_name() -> String:
	return "Power Plant"


func _process(delta):
	pulse_timer += delta
	queue_redraw()


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_spawn_aliens_on_death()
		queue_free()


func _spawn_aliens_on_death():
	var alien_scene = preload("res://scenes/alien.tscn")
	for i in range(4):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		alien.hp = 35
		alien.max_hp = 35
		alien.damage = 8
		alien.speed = 45.0
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var pulse = 0.6 + sin(pulse_timer * 3.0) * 0.4

	# Main building body
	draw_rect(Rect2(-22, -15, 44, 30), Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(-22, -15, 44, 30), Color(0.35, 0.35, 0.4), false, 2.0)

	# Reactor core housing
	draw_rect(Rect2(-12, -20, 24, 8), Color(0.4, 0.4, 0.45))

	# Reactor core (glowing)
	draw_circle(Vector2(0, -8), 10, Color(0.2, 0.5, 0.9, 0.3))
	draw_circle(Vector2(0, -8), 7, Color(0.3, 0.6, 1.0, pulse))
	draw_circle(Vector2(0, -8), 4, Color(0.5, 0.8, 1.0))

	# Power coils on sides
	for x in [-16, 16]:
		draw_rect(Rect2(x - 4, -10, 8, 20), Color(0.5, 0.45, 0.35))
		var coil_glow = Color(1.0, 0.8, 0.3, pulse * 0.5)
		draw_line(Vector2(x, -8), Vector2(x, 8), coil_glow, 3.0)

	# Exhaust vents
	draw_rect(Rect2(-18, 15, 10, 5), Color(0.3, 0.3, 0.35))
	draw_rect(Rect2(8, 15, 10, 5), Color(0.3, 0.3, 0.35))

	# Steam/energy particles
	var t = pulse_timer * 2.0
	for i in range(3):
		var offset = fmod(t + i * 1.5, 4.0)
		var alpha = 1.0 - offset / 4.0
		draw_circle(Vector2(-13, 18 + offset * 3), 2.0, Color(0.7, 0.7, 0.8, alpha * 0.3))
		draw_circle(Vector2(13, 18 + offset * 3), 2.0, Color(0.7, 0.7, 0.8, alpha * 0.3))

	# Power range indicator
	draw_arc(Vector2.ZERO, POWER_RANGE, 0, TAU, 48, Color(0.3, 0.6, 1.0, 0.08), 1.5)

	# HP bar
	draw_rect(Rect2(-22, -28, 44, 4), Color(0.3, 0, 0))
	draw_rect(Rect2(-22, -28, 44.0 * hp / max_hp, 4), Color(0, 0.8, 0))
