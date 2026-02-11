extends Node

## Autoload that creates a debug overlay on web builds.
## Runs BEFORE main.gd, so it catches errors even if main.gd fails to load.

var _label: Label
var _log_lines: PackedStringArray = []
var _check_timer: float = 0.0
var _checked_main: bool = false
var _checked_hud: bool = false

func _ready():
	if not OS.has_feature("web"):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer = CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.size = Vector2(700, 500)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.YELLOW)
	_label.text = ""
	_label.visible = false
	layer.add_child(_label)
	log_msg("=== Web Debug Overlay ===")
	log_msg("OS: %s" % OS.get_name())
	log_msg("Touch: %s" % DisplayServer.is_touchscreen_available())
	log_msg("GPU: %s" % RenderingServer.get_video_adapter_name())
	log_msg("Video API: %s" % RenderingServer.get_video_adapter_api_version())
	var renderer = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "default"))
	log_msg("Renderer cfg: %s" % renderer)
	log_msg("Viewport: %s" % str(get_viewport().size))
	log_msg("Waiting for main scene...")


func _process(delta):
	if not OS.has_feature("web"):
		return
	_check_timer += delta
	# After 2 seconds, check if the main scene loaded
	if not _checked_main and _check_timer > 2.0:
		_checked_main = true
		var main = get_tree().current_scene
		if main:
			log_msg("Main scene: %s (%s)" % [main.name, main.get_class()])
			log_msg("Children: %d" % main.get_child_count())
			# Check if tree is paused (HUD pauses on start menu)
			log_msg("Tree paused: %s" % str(get_tree().paused))
		else:
			log_msg("ERROR: No main scene loaded after 2s!")

	# After 5 seconds, check if HUD is visible
	if not _checked_hud and _check_timer > 5.0:
		_checked_hud = true
		var main = get_tree().current_scene
		if main:
			var child_names = []
			for c in main.get_children():
				child_names.append(c.name)
			log_msg("Main children: %s" % str(child_names))
		else:
			log_msg("ERROR: Still no main scene at 5s!")


func set_visible(vis: bool):
	if _label:
		_label.visible = vis


func log_msg(msg: String):
	print("[WebDebug] ", msg)
	# Also push to browser console via JavaScript
	if OS.has_feature("web"):
		var safe = msg.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ")
		JavaScriptBridge.eval("console.log('[GodotDebug] %s')" % safe)
	_log_lines.append(msg)
	if _label:
		_label.text = "\n".join(_log_lines)
