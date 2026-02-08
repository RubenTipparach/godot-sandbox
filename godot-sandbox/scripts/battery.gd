extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_battery
var max_hp: int = CFG.hp_battery
var pulse_timer: float = 0.0


func _ready():
	add_to_group("buildings")
	add_to_group("batteries")


func get_building_name() -> String:
	return "Battery"


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
	for i in range(2):
		var alien = alien_scene.instantiate()
		alien.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		alien.hp = 20
		alien.max_hp = 20
		alien.damage = 5
		alien.speed = 50.0
		get_tree().current_scene.get_node("Aliens").add_child(alien)


func _draw():
	var main = get_tree().current_scene
	var charge = 0.0
	if main and "power_bank" in main and "max_power_bank" in main and main.max_power_bank > 0:
		charge = main.power_bank / main.max_power_bank

	# Battery body
	draw_rect(Rect2(-14, -18, 28, 36), Color(0.4, 0.4, 0.45))
	draw_rect(Rect2(-14, -18, 28, 36), Color(0.3, 0.3, 0.35), false, 2.0)

	# Battery terminal (top nub)
	draw_rect(Rect2(-6, -22, 12, 6), Color(0.5, 0.5, 0.55))

	# Charge fill (from bottom up)
	var fill_height = 28.0 * charge
	var fill_color: Color
	if charge > 0.5:
		fill_color = Color(0.3, 0.8, 0.4, 0.7)
	elif charge > 0.2:
		fill_color = Color(0.9, 0.7, 0.2, 0.7)
	else:
		fill_color = Color(0.9, 0.3, 0.2, 0.7)
	if fill_height > 0:
		draw_rect(Rect2(-10, 14 - fill_height, 20, fill_height), fill_color)

	# Charge level lines
	for i in range(3):
		var y = -10.0 + i * 10.0
		draw_line(Vector2(-10, y), Vector2(10, y), Color(0.3, 0.3, 0.35, 0.5), 1.0)

	# Lightning bolt icon when charged
	if charge > 0.1:
		var bolt_alpha = 0.5 + sin(pulse_timer * 3.0) * 0.3
		var bolt_color = Color(1.0, 0.9, 0.3, bolt_alpha)
		draw_polyline(PackedVector2Array([
			Vector2(0, -8), Vector2(3, -1), Vector2(-3, 1), Vector2(0, 8)
		]), bolt_color, 2.5)

	# HP bar
	draw_rect(Rect2(-14, -28, 28, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-14, -28, 28.0 * hp / max_hp, 3), Color(0, 0.8, 0))
