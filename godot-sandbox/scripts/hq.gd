extends Node2D

var hp: int = 200
var max_hp: int = 200
var pulse_timer: float = 0.0
const POWER_RANGE = 150.0  # HQ provides power like a power plant

signal destroyed


func _ready():
	add_to_group("buildings")
	add_to_group("hq")
	add_to_group("power_plants")  # HQ acts as a power source


func _process(delta):
	pulse_timer += delta
	queue_redraw()


func get_building_name() -> String:
	return "HQ"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		destroyed.emit()
		queue_free()


func _draw():
	var pulse = 0.6 + sin(pulse_timer * 2.0) * 0.4

	# Main HQ building - larger than other buildings
	draw_rect(Rect2(-30, -25, 60, 50), Color(0.35, 0.4, 0.5))
	draw_rect(Rect2(-30, -25, 60, 50), Color(0.25, 0.3, 0.4), false, 3.0)

	# Central command tower
	draw_rect(Rect2(-12, -40, 24, 18), Color(0.4, 0.45, 0.55))
	draw_rect(Rect2(-8, -48, 16, 10), Color(0.45, 0.5, 0.6))

	# Antenna
	draw_line(Vector2(0, -48), Vector2(0, -60), Color(0.5, 0.5, 0.55), 2.0)
	draw_circle(Vector2(0, -62), 4, Color(0.3, 0.8, 0.4, pulse))

	# Side structures
	draw_rect(Rect2(-28, -15, 16, 30), Color(0.38, 0.43, 0.52))
	draw_rect(Rect2(12, -15, 16, 30), Color(0.38, 0.43, 0.52))

	# Windows/lights
	for x in [-22, -18, 18, 22]:
		for y in [-8, 0, 8]:
			var light_color = Color(1.0, 0.95, 0.5, pulse) if fmod(pulse_timer + x + y, 2.0) < 1.5 else Color(0.3, 0.3, 0.35)
			draw_rect(Rect2(x - 2, y - 2, 4, 4), light_color)

	# Central emblem/power core
	draw_circle(Vector2(0, 0), 12, Color(0.2, 0.4, 0.6, 0.5))
	draw_circle(Vector2(0, 0), 8, Color(0.3, 0.6, 0.9, pulse))
	draw_circle(Vector2(0, 0), 4, Color(0.5, 0.8, 1.0))

	# "HQ" text marker
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(-8, -30), "HQ", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.9, 0.95, 1.0))

	# Power range disc (filled, semi-transparent blue)
	draw_circle(Vector2.ZERO, POWER_RANGE, Color(0.2, 0.5, 1.0, 0.06))
	draw_arc(Vector2.ZERO, POWER_RANGE, 0, TAU, 48, Color(0.3, 0.6, 1.0, 0.08), 1.5)

	# HP bar (larger for HQ)
	draw_rect(Rect2(-30, -70, 60, 5), Color(0.3, 0, 0))
	draw_rect(Rect2(-30, -70, 60.0 * hp / max_hp, 5), Color(0, 0.9, 0.2))

	# Warning border when low HP
	if hp < max_hp * 0.3:
		var warn_pulse = 0.5 + sin(pulse_timer * 6.0) * 0.5
		draw_rect(Rect2(-32, -27, 64, 54), Color(1.0, 0.2, 0.1, warn_pulse * 0.5), false, 3.0)
