extends Node3D

var text: String = ""
var color: Color = Color.WHITE
var lifetime: float = 1.2
var velocity: Vector3 = Vector3(0, 40, 0)
var _label: Label3D


func _ready():
	_label = Label3D.new()
	_label.text = text
	_label.modulate = color
	_label.font_size = 48
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.15
	add_child(_label)


func _process(delta):
	position += velocity * delta
	velocity *= 0.95
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	# Fade out near end of life
	var alpha = clampf(lifetime / 0.4, 0.0, 1.0)
	_label.modulate = Color(color.r, color.g, color.b, alpha)
