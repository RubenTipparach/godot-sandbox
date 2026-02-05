extends Node2D

var text: String = ""
var color: Color = Color.WHITE
var lifetime: float = 1.2
var velocity: Vector2 = Vector2(0, -40)


func _process(delta):
	position += velocity * delta
	velocity *= 0.95
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	queue_redraw()


func _draw():
	var alpha = clampf(lifetime / 0.5, 0.0, 1.0)
	var scale_factor = 1.0 + (1.2 - lifetime) * 0.15
	var font = ThemeDB.fallback_font
	var size = 18

	# Shadow
	draw_string(font, Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(0, 0, 0, alpha * 0.5))
	# Main text
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(color.r, color.g, color.b, alpha))
