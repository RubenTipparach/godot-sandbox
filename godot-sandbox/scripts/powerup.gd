extends Node2D

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
	queue_redraw()


func _draw():
	var bob = sin(bob_offset) * 3.0
	var color: Color
	var icon_draw: Callable

	match powerup_type:
		"magnet":
			color = Color(0.3, 1.0, 0.5)
			icon_draw = _draw_magnet
		"weapon_scroll":
			color = Color(1.0, 0.8, 0.2)
			icon_draw = _draw_scroll
		"heal":
			color = Color(1.0, 0.3, 0.4)
			icon_draw = _draw_heal
		"nuke":
			color = Color(1.0, 0.5, 0.1)
			icon_draw = _draw_nuke
		"mining_boost":
			color = Color(1.0, 0.8, 0.3)
			icon_draw = _draw_mining_boost
		_:
			color = Color(0.5, 0.5, 0.5)
			icon_draw = _draw_magnet

	# Outer glow
	var glow_alpha = 0.15 + sin(bob_offset * 1.5) * 0.1
	draw_circle(Vector2(0, bob), 18, Color(color.r, color.g, color.b, glow_alpha))

	# Main circle
	draw_circle(Vector2(0, bob), 12, color.darkened(0.3))
	draw_arc(Vector2(0, bob), 12, 0, TAU, 24, color, 2.0)

	# Icon
	icon_draw.call(bob)

	# Lifetime indicator (fades as it expires)
	if lifetime < 15:
		var fade = lifetime / 15.0
		modulate.a = 0.5 + fade * 0.5


func _draw_magnet(bob: float):
	# U-shape magnet
	draw_arc(Vector2(0, bob + 2), 6, PI, TAU, 12, Color.WHITE, 2.0)
	draw_line(Vector2(-6, bob + 2), Vector2(-6, bob - 4), Color(1, 0.2, 0.2), 2.0)
	draw_line(Vector2(6, bob + 2), Vector2(6, bob - 4), Color(0.2, 0.2, 1.0), 2.0)


func _draw_scroll(bob: float):
	# Scroll shape
	draw_rect(Rect2(-5, bob - 6, 10, 12), Color(0.9, 0.85, 0.7))
	draw_line(Vector2(-3, bob - 3), Vector2(3, bob - 3), Color(0.3, 0.3, 0.3), 1.0)
	draw_line(Vector2(-3, bob), Vector2(3, bob), Color(0.3, 0.3, 0.3), 1.0)
	draw_line(Vector2(-3, bob + 3), Vector2(2, bob + 3), Color(0.3, 0.3, 0.3), 1.0)


func _draw_heal(bob: float):
	# Cross/plus
	draw_rect(Rect2(-2, bob - 6, 4, 12), Color.WHITE)
	draw_rect(Rect2(-6, bob - 2, 12, 4), Color.WHITE)


func _draw_nuke(bob: float):
	# Radiation symbol (simplified)
	draw_circle(Vector2(0, bob), 3, Color(0.1, 0.1, 0.1))
	for i in range(3):
		var angle = TAU * i / 3.0 - PI / 2
		var pt = Vector2.from_angle(angle) * 6
		draw_circle(Vector2(pt.x, pt.y + bob), 3, Color.WHITE)


func _draw_mining_boost(bob: float):
	# Pickaxe icon
	draw_line(Vector2(-5, bob + 5), Vector2(5, bob - 5), Color(0.6, 0.4, 0.2), 2.0)
	draw_line(Vector2(3, bob - 5), Vector2(5, bob - 3), Color(0.7, 0.7, 0.8), 2.0)
	draw_line(Vector2(5, bob - 5), Vector2(3, bob - 3), Color(0.7, 0.7, 0.8), 2.0)
