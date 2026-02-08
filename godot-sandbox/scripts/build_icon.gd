extends Control

var build_type: String = ""
var hotkey: String = ""
var is_active: bool = false
var can_afford: bool = true
var display_name: String = ""
var iron_cost: int = 0
var crystal_cost: int = 0
var locked: bool = false

signal pressed


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(40, 40)
	tooltip_text = " "


func _make_custom_tooltip(_for_text: String) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	# Building name
	var name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	hbox.add_child(name_label)

	# Get player resources for affordability coloring
	var player_iron := 999999
	var player_crystal := 999999
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.is_local:
			player_iron = p.iron
			player_crystal = p.crystal
			break

	# Iron cost
	if iron_cost > 0:
		var iron_label = Label.new()
		iron_label.text = "%dI" % iron_cost
		iron_label.add_theme_font_size_override("font_size", 14)
		var iron_color = Color(0.9, 0.75, 0.4) if player_iron >= iron_cost else Color(1.0, 0.3, 0.3)
		iron_label.add_theme_color_override("font_color", iron_color)
		hbox.add_child(iron_label)

	# Crystal cost
	if crystal_cost > 0:
		var crystal_label = Label.new()
		crystal_label.text = "%dC" % crystal_cost
		crystal_label.add_theme_font_size_override("font_size", 14)
		var crystal_color = Color(0.4, 0.7, 1.0) if player_crystal >= crystal_cost else Color(1.0, 0.3, 0.3)
		crystal_label.add_theme_color_override("font_color", crystal_color)
		hbox.add_child(crystal_label)

	return panel


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
	draw_rect(Rect2(0, 0, 40, 40), bg_color)
	draw_rect(Rect2(0, 0, 40, 40), border_color, false, 1.0)

	var center = Vector2(20, 20)

	# Draw icon based on building type
	match build_type:
		"turret":
			# Circle with barrel
			draw_circle(center, 10, Color(0.4, 0.4, 0.5, icon_alpha))
			draw_circle(center, 6, Color(0.5, 0.5, 0.6, icon_alpha))
			draw_line(center, center + Vector2(12, 0), Color(0.3, 0.3, 0.35, icon_alpha), 3.0)
		"factory":
			# Square with chimney
			draw_rect(Rect2(10, 14, 20, 18), Color(0.8, 0.6, 0.2, icon_alpha))
			draw_rect(Rect2(16, 6, 8, 10), Color(0.6, 0.4, 0.15, icon_alpha))
			draw_circle(Vector2(20, 4), 3, Color(0.5, 0.5, 0.5, icon_alpha * 0.5))
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
