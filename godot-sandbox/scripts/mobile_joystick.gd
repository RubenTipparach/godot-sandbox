extends Control

# Virtual joystick for mobile movement controls

var input_vector: Vector2 = Vector2.ZERO
var is_active: bool = false
var active_touch_index: int = -1
var thumb_offset: Vector2 = Vector2.ZERO

const OUTER_RADIUS = 70.0
const THUMB_RADIUS = 25.0
const DEADZONE = 0.1


func _ready():
	add_to_group("mobile_joystick")
	mouse_filter = Control.MOUSE_FILTER_STOP


func get_center_screen_pos() -> Vector2:
	return global_position + size / 2.0


func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index == -1:
			var center = get_center_screen_pos()
			if event.position.distance_to(center) <= OUTER_RADIUS * 1.5:
				active_touch_index = event.index
				is_active = true
				_update_from_screen_pos(event.position)
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == active_touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == active_touch_index and is_active:
			_update_from_screen_pos(event.position)
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent):
	# Consume emulated mouse events when joystick is active to prevent
	# them from propagating to the game (e.g. triggering building placement)
	if is_active:
		accept_event()


func _update_from_screen_pos(screen_pos: Vector2):
	var center = get_center_screen_pos()
	var diff = screen_pos - center
	if diff.length() > OUTER_RADIUS:
		diff = diff.normalized() * OUTER_RADIUS
	thumb_offset = diff
	if diff.length() > DEADZONE * OUTER_RADIUS:
		input_vector = (diff / OUTER_RADIUS).limit_length(1.0)
	else:
		input_vector = Vector2.ZERO
	queue_redraw()


func _reset():
	is_active = false
	active_touch_index = -1
	input_vector = Vector2.ZERO
	thumb_offset = Vector2.ZERO
	queue_redraw()


func _draw():
	var center = size / 2.0
	# Outer circle
	draw_circle(center, OUTER_RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(center, OUTER_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	# Inner thumb
	var thumb_pos = center + thumb_offset
	draw_circle(thumb_pos, THUMB_RADIUS, Color(1, 1, 1, 0.25))
	draw_arc(thumb_pos, THUMB_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
