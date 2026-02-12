extends Control

var build_type: String = ""
var hotkey: String = ""
var is_active: bool = false
var can_afford: bool = true
var display_name: String = ""
var iron_cost: int = 0
var crystal_cost: int = 0
var locked: bool = false
var is_hovered: bool = false

var _icon_textures: Dictionary = {}

func _get_icon_texture(path: String) -> Texture2D:
	if path not in _icon_textures:
		_icon_textures[path] = load(path)
	return _icon_textures[path]

signal pressed
signal hovered(icon)
signal unhovered


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(40, 40)
	mouse_entered.connect(func(): is_hovered = true; hovered.emit(self))
	mouse_exited.connect(func(): is_hovered = false; unhovered.emit())


func _gui_input(event):
	if locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _draw():
	# Background
	var bg_color: Color
	var border_color: Color
	var icon_alpha: float
	if locked:
		bg_color = Color(0.06, 0.06, 0.08, 0.9)
		border_color = Color(0.15, 0.15, 0.18)
		icon_alpha = 0.2
	elif is_active:
		bg_color = Color(0.2, 0.5, 0.3, 0.9)
		border_color = Color(0.3, 0.8, 0.4)
		icon_alpha = 1.0
	elif can_afford:
		bg_color = Color(0.15, 0.15, 0.2, 0.9)
		border_color = Color(0.4, 0.4, 0.5)
		icon_alpha = 1.0
	else:
		bg_color = Color(0.1, 0.1, 0.13, 0.9)
		border_color = Color(0.2, 0.2, 0.25)
		icon_alpha = 0.35
	if is_hovered and not locked:
		bg_color = bg_color.lightened(0.15)
		border_color = Color(0.7, 0.85, 1.0)
	draw_rect(Rect2(0, 0, 40, 40), bg_color)
	draw_rect(Rect2(0, 0, 40, 40), border_color, false, 2.0 if is_hovered else 1.0)

	var center = Vector2(20, 20)

	# Draw icon based on building type
	match build_type:
		"turret":
			# Circle with barrel
			draw_circle(center, 10, Color(0.4, 0.4, 0.5, icon_alpha))
			draw_circle(center, 6, Color(0.5, 0.5, 0.6, icon_alpha))
			draw_line(center, center + Vector2(12, 0), Color(0.3, 0.3, 0.35, icon_alpha), 3.0)
		"factory":
			var tex = _get_icon_texture("res://resources/sprites/factory icon.png")
			if tex:
				var tex_size = tex.get_size()
				var scale_f = min(32.0 / tex_size.x, 32.0 / tex_size.y)
				var draw_size = tex_size * scale_f
				var offset = (Vector2(40, 40) - draw_size) / 2.0
				draw_texture_rect(tex, Rect2(offset, draw_size), false, Color(1, 1, 1, icon_alpha))
		"wall":
			# Brick wall
			draw_rect(Rect2(8, 12, 24, 16), Color(0.45, 0.42, 0.38, icon_alpha))
			draw_line(Vector2(8, 20), Vector2(32, 20), Color(0.35, 0.32, 0.28, icon_alpha), 1.0)
			draw_line(Vector2(20, 12), Vector2(20, 20), Color(0.35, 0.32, 0.28, icon_alpha), 1.0)
		"lightning":
			# Tower with orb
			draw_rect(Rect2(14, 18, 12, 14), Color(0.35, 0.35, 0.45, icon_alpha))
			draw_rect(Rect2(16, 10, 8, 10), Color(0.4, 0.4, 0.5, icon_alpha))
			draw_circle(Vector2(20, 8), 5, Color(0.5, 0.7, 1.0, icon_alpha))
		"slow":
			# Ice crystal
			var pts = PackedVector2Array([
				center + Vector2(0, -12),
				center + Vector2(8, -2),
				center + Vector2(5, 4),
				center + Vector2(-5, 4),
				center + Vector2(-8, -2),
			])
			draw_colored_polygon(pts, Color(0.4, 0.7, 0.9, icon_alpha * 0.8))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.6, 0.85, 1.0, icon_alpha), 1.5)
		"pylon":
			# Pylon tower
			var pylon_pts = PackedVector2Array([
				center + Vector2(-5, 8),
				center + Vector2(-2, -10),
				center + Vector2(2, -10),
				center + Vector2(5, 8),
			])
			draw_colored_polygon(pylon_pts, Color(0.35, 0.35, 0.4, icon_alpha))
			draw_rect(Rect2(12, 6, 16, 4), Color(0.4, 0.6, 0.9, icon_alpha))
		"power_plant":
			# Power plant with reactor
			draw_rect(Rect2(8, 14, 24, 18), Color(0.45, 0.45, 0.5, icon_alpha))
			draw_circle(center + Vector2(0, -2), 6, Color(0.3, 0.6, 1.0, icon_alpha))
			draw_circle(center + Vector2(0, -2), 3, Color(0.5, 0.8, 1.0, icon_alpha))
		"battery":
			# Battery shape
			draw_rect(Rect2(12, 10, 16, 22), Color(0.4, 0.4, 0.45, icon_alpha))
			draw_rect(Rect2(16, 6, 8, 5), Color(0.5, 0.5, 0.55, icon_alpha))
			draw_rect(Rect2(14, 18, 12, 12), Color(0.3, 0.8, 0.4, icon_alpha * 0.7))
		"flame_turret":
			# Circle with flame
			draw_circle(center, 10, Color(0.5, 0.3, 0.2, icon_alpha))
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-4, 4),
				center + Vector2(-1, -6),
				center + Vector2(1, -2),
				center + Vector2(4, -8),
				center + Vector2(2, -1),
				center + Vector2(5, -4),
				center + Vector2(4, 4),
			]), Color(1.0, 0.5, 0.1, icon_alpha))
		"acid_turret":
			# Circle with green barrel and droplets
			draw_circle(center, 10, Color(0.3, 0.45, 0.3, icon_alpha))
			draw_line(center, center + Vector2(12, 0), Color(0.25, 0.4, 0.2, icon_alpha), 3.0)
			draw_circle(center + Vector2(14, 2), 2, Color(0.3, 0.9, 0.15, icon_alpha))
			draw_circle(center + Vector2(12, 6), 1.5, Color(0.3, 0.9, 0.15, icon_alpha))
		"repair_drone":
			# Drone with propellers
			draw_rect(Rect2(14, 22, 12, 6), Color(0.35, 0.35, 0.4, icon_alpha))
			draw_circle(center + Vector2(0, -2), 7, Color(0.4, 0.5, 0.4, icon_alpha))
			draw_arc(center + Vector2(0, -2), 7, 0, TAU, 12, Color(0.3, 0.8, 0.4, icon_alpha), 1.0)
			for pi in range(4):
				var pa = TAU * pi / 4.0 + PI / 4.0
				var arm_end = center + Vector2(0, -2) + Vector2.from_angle(pa) * 9
				draw_line(center + Vector2(0, -2), arm_end, Color(0.5, 0.6, 0.5, icon_alpha), 1.0)
				draw_circle(arm_end, 2, Color(0.3, 0.8, 0.4, icon_alpha * 0.6))
		"poison_turret":
			# Green vial with drip
			draw_circle(center, 10, Color(0.25, 0.4, 0.2, icon_alpha))
			draw_rect(Rect2(16, 12, 8, 16), Color(0.3, 0.5, 0.2, icon_alpha))
			draw_circle(center + Vector2(0, -6), 5, Color(0.4, 0.85, 0.2, icon_alpha))
			draw_circle(center + Vector2(0, 6), 2, Color(0.3, 0.85, 0.15, icon_alpha * 0.7))

	# Lock overlay when locked
	if locked:
		draw_rect(Rect2(0, 0, 40, 40), Color(0, 0, 0, 0.6))
		# Lock body
		draw_rect(Rect2(14, 20, 12, 10), Color(0.6, 0.5, 0.3))
		# Lock shackle
		draw_arc(Vector2(20, 20), 4, PI, TAU, 12, Color(0.5, 0.4, 0.25), 2.0)

	# Hotkey in corner
	var font = ThemeDB.fallback_font
	var hotkey_alpha = 0.25 if locked else (0.4 if not can_afford else 0.8)
	draw_string(font, Vector2(3, 12), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.9, hotkey_alpha))


func _process(_delta):
	queue_redraw()
