extends CanvasLayer

signal upgrade_chosen(upgrade_key: String)
signal game_started(wave: int)

var iron_label: Label
var crystal_label: Label
var health_label: Label
var wave_label: Label
var timer_label: Label
var alien_count_label: Label
var level_label: Label
var alert_label: Label
var xp_bar_bg: ColorRect
var xp_bar_fill: ColorRect
var alert_timer: float = 0.0

var upgrade_panel: Control
var card_info: Array = []
var _upgrade_showing: bool = false

var death_panel: Control
var death_stats_label: Label
var prestige_label: Label
var start_buttons: Array = []

var start_menu: Control
var start_prestige_label: Label
var start_stats_label: Label
var start_wave_buttons: Array = []

var research_panel: Control
var research_prestige_label: Label

var pause_menu: Control
var _game_started: bool = false
var minimap_node: Control
var build_cost_labels: Array = []

const UPGRADE_DATA = {
	"chain_lightning": {"name": "Chain Lightning", "color": Color(0.3, 0.7, 1.0), "max": 5},
	"shotgun": {"name": "Shotgun Blast", "color": Color(1.0, 0.6, 0.2), "max": 5},
	"burning": {"name": "Inferno", "color": Color(1.0, 0.3, 0.0), "max": 5},
	"ice": {"name": "Frostbite", "color": Color(0.5, 0.85, 1.0), "max": 5},
	"damage_aura": {"name": "Death Aura", "color": Color(0.8, 0.2, 0.8), "max": 5},
	"orbital_lasers": {"name": "Orbital Lasers", "color": Color(1.0, 0.15, 0.1), "max": 5},
	"max_health": {"name": "Vitality", "color": Color(0.2, 0.9, 0.2), "max": 5},
	"move_speed": {"name": "Swift Boots", "color": Color(0.9, 0.9, 0.3), "max": 5},
	"attack_speed": {"name": "Rapid Fire", "color": Color(0.9, 0.5, 0.1), "max": 5},
	"mining_speed": {"name": "Laser Drill", "color": Color(1.0, 0.8, 0.3), "max": 5},
	"mining_heads": {"name": "Multi-Beam", "color": Color(0.4, 0.9, 1.0), "max": 4},
	"turret_damage": {"name": "Turret Upgrade", "color": Color(0.5, 0.5, 0.6), "max": 5},
	"turret_fire_rate": {"name": "Turret Overdrive", "color": Color(0.9, 0.5, 0.3), "max": 5},
	"factory_speed": {"name": "Factory Efficiency", "color": Color(0.8, 0.65, 0.3), "max": 5},
	"mining_range": {"name": "Extended Reach", "color": Color(0.6, 0.9, 0.5), "max": 5},
	"rock_regen": {"name": "Mineral Attractor", "color": Color(0.7, 0.6, 0.4), "max": 5},
	"health_regen": {"name": "Regeneration", "color": Color(0.3, 1.0, 0.5), "max": 5},
	"dodge": {"name": "Evasion", "color": Color(0.6, 0.8, 1.0), "max": 5},
	"armor": {"name": "Plating", "color": Color(0.5, 0.5, 0.6), "max": 5},
	"crit_chance": {"name": "Critical Hit", "color": Color(1.0, 0.4, 0.2), "max": 5},
}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Make tooltips appear instantly
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(10, 10)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.65)))
	root.add_child(panel)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	health_label = _lbl(vbox, 16, Color(0.4, 1.0, 0.4))
	iron_label = _lbl(vbox, 16, Color(0.8, 0.75, 0.65))
	crystal_label = _lbl(vbox, 16, Color(0.5, 0.7, 1.0))
	level_label = _lbl(vbox, 15, Color(0.9, 0.8, 0.3))

	xp_bar_bg = ColorRect.new()
	xp_bar_bg.custom_minimum_size = Vector2(170, 10)
	xp_bar_bg.color = Color(0.15, 0.15, 0.25)
	vbox.add_child(xp_bar_bg)
	xp_bar_fill = ColorRect.new()
	xp_bar_fill.color = Color(0.3, 0.8, 1.0)
	xp_bar_fill.position = Vector2.ZERO
	xp_bar_fill.size = Vector2(0, 10)
	xp_bar_bg.add_child(xp_bar_fill)

	wave_label = _lbl(vbox, 16, Color.WHITE)
	timer_label = _lbl(vbox, 18, Color(1.0, 0.4, 0.4))
	alien_count_label = _lbl(vbox, 14, Color(1.0, 0.5, 0.4))

	# Horizontal build bar at bottom center
	var build_bar = PanelContainer.new()
	build_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	build_bar.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.7)))
	build_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_bar.offset_top = -56; build_bar.offset_bottom = -10
	build_bar.offset_left = -180; build_bar.offset_right = 180
	root.add_child(build_bar)

	var build_hbox = HBoxContainer.new()
	build_hbox.add_theme_constant_override("separation", 4)
	build_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	build_bar.add_child(build_hbox)

	build_cost_labels.append(_build_icon(build_hbox, "turret", "1", "Turret"))
	build_cost_labels.append(_build_icon(build_hbox, "factory", "2", "Factory"))
	build_cost_labels.append(_build_icon(build_hbox, "wall", "3", "Wall"))
	build_cost_labels.append(_build_icon(build_hbox, "lightning", "4", "Lightning Tower"))
	build_cost_labels.append(_build_icon(build_hbox, "slow", "5", "Slow Tower"))
	build_cost_labels.append(_build_icon(build_hbox, "pylon", "6", "Pylon"))
	build_cost_labels.append(_build_icon(build_hbox, "power_plant", "7", "Power Plant"))

	alert_label = Label.new()
	alert_label.add_theme_font_size_override("font_size", 36)
	alert_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.offset_top = 100; alert_label.offset_left = -300; alert_label.offset_right = 300
	alert_label.visible = false
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alert_label)

	minimap_node = Control.new()
	minimap_node.set_script(preload("res://scripts/minimap.gd"))
	minimap_node.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_node.offset_left = -170; minimap_node.offset_top = 10; minimap_node.offset_right = -10; minimap_node.offset_bottom = 170
	minimap_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap_node)

	_build_upgrade_panel(root)
	_build_death_panel(root)
	_build_start_menu(root)
	_build_research_panel(root)
	_build_pause_menu(root)

	# Show start menu on launch
	start_menu.visible = true
	get_tree().paused = true
	_update_start_menu()


func _build_upgrade_panel(root: Control):
	upgrade_panel = Control.new()
	upgrade_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_panel.visible = false
	upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(upgrade_panel)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_panel.add_child(bg)

	var title = Label.new()
	title.text = "CHOOSE AN UPGRADE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 120; title.offset_left = -200; title.offset_right = 200
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_panel.add_child(title)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.offset_left = -370; hbox.offset_right = 370
	hbox.offset_top = -80; hbox.offset_bottom = 130
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_panel.add_child(hbox)

	for i in range(3):
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(220, 200)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.process_mode = Node.PROCESS_MODE_ALWAYS
		card.add_theme_stylebox_override("panel", _make_card_style(Color(0.4, 0.4, 0.5)))
		hbox.add_child(card)

		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(vb)

		var nl = Label.new()
		nl.add_theme_font_size_override("font_size", 20)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nl)

		var ll = Label.new()
		ll.add_theme_font_size_override("font_size", 14)
		ll.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ll)

		var dl = Label.new()
		dl.add_theme_font_size_override("font_size", 14)
		dl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(dl)

		card.gui_input.connect(_on_card_click.bind(i))
		card_info.append({"panel": card, "name_lbl": nl, "lvl_lbl": ll, "desc_lbl": dl, "key": ""})


func _build_death_panel(root: Control):
	death_panel = Control.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false
	death_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(death_panel)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	death_panel.add_child(bg)

	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.2, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 80
	title.offset_left = -300
	title.offset_right = 300
	death_panel.add_child(title)

	death_stats_label = Label.new()
	death_stats_label.add_theme_font_size_override("font_size", 20)
	death_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	death_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_stats_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_stats_label.offset_top = 150
	death_stats_label.offset_left = -300
	death_stats_label.offset_right = 300
	death_panel.add_child(death_stats_label)

	prestige_label = Label.new()
	prestige_label.add_theme_font_size_override("font_size", 24)
	prestige_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	prestige_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prestige_label.offset_top = 200
	prestige_label.offset_left = -300
	prestige_label.offset_right = 300
	death_panel.add_child(prestige_label)

	var start_title = Label.new()
	start_title.text = "Choose Starting Wave"
	start_title.add_theme_font_size_override("font_size", 22)
	start_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	start_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_title.set_anchors_preset(Control.PRESET_CENTER)
	start_title.offset_top = -120
	start_title.offset_left = -200
	start_title.offset_right = 200
	death_panel.add_child(start_title)

	var btn_container = HBoxContainer.new()
	btn_container.set_anchors_preset(Control.PRESET_CENTER)
	btn_container.offset_top = -70
	btn_container.offset_left = -300
	btn_container.offset_right = 300
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 15)
	death_panel.add_child(btn_container)

	for wave in [1, 5, 10, 15, 20]:
		var btn = Button.new()
		btn.text = "Wave %d" % wave
		btn.custom_minimum_size = Vector2(100, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_start_wave_pressed.bind(wave))
		btn_container.add_child(btn)
		start_buttons.append({"button": btn, "wave": wave})


func _build_start_menu(root: Control):
	start_menu = Control.new()
	start_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_menu.visible = false
	start_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(start_menu)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.08, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	start_menu.add_child(bg)

	var title = Label.new()
	title.text = "MINING DEFENSE"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 60
	title.offset_left = -300
	title.offset_right = 300
	start_menu.add_child(title)

	start_stats_label = Label.new()
	start_stats_label.add_theme_font_size_override("font_size", 16)
	start_stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	start_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_stats_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	start_stats_label.offset_top = 130
	start_stats_label.offset_left = -300
	start_stats_label.offset_right = 300
	start_menu.add_child(start_stats_label)

	start_prestige_label = Label.new()
	start_prestige_label.add_theme_font_size_override("font_size", 24)
	start_prestige_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	start_prestige_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_prestige_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	start_prestige_label.offset_top = 160
	start_prestige_label.offset_left = -300
	start_prestige_label.offset_right = 300
	start_menu.add_child(start_prestige_label)

	var wave_title = Label.new()
	wave_title.text = "Select Starting Wave"
	wave_title.add_theme_font_size_override("font_size", 22)
	wave_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title.set_anchors_preset(Control.PRESET_CENTER)
	wave_title.offset_top = -100
	wave_title.offset_left = -200
	wave_title.offset_right = 200
	start_menu.add_child(wave_title)

	var wave_container = HBoxContainer.new()
	wave_container.set_anchors_preset(Control.PRESET_CENTER)
	wave_container.offset_top = -50
	wave_container.offset_left = -300
	wave_container.offset_right = 300
	wave_container.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_container.add_theme_constant_override("separation", 15)
	start_menu.add_child(wave_container)

	for wave in [1, 5, 10, 15, 20]:
		var btn = Button.new()
		btn.text = "Wave %d" % wave
		btn.custom_minimum_size = Vector2(100, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_start_menu_wave_pressed.bind(wave))
		wave_container.add_child(btn)
		start_wave_buttons.append({"button": btn, "wave": wave})

	var research_btn = Button.new()
	research_btn.text = "Research Tree"
	research_btn.custom_minimum_size = Vector2(200, 50)
	research_btn.add_theme_font_size_override("font_size", 20)
	research_btn.set_anchors_preset(Control.PRESET_CENTER)
	research_btn.offset_top = 40
	research_btn.offset_left = -100
	research_btn.offset_right = 100
	research_btn.offset_bottom = 90
	research_btn.pressed.connect(_on_research_btn_pressed)
	start_menu.add_child(research_btn)


func _build_research_panel(root: Control):
	research_panel = Control.new()
	research_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	research_panel.visible = false
	research_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(research_panel)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12, 0.98)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	research_panel.add_child(bg)

	var title = Label.new()
	title.text = "UPGRADES TREE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_top = 15
	title.offset_left = 20
	research_panel.add_child(title)

	research_prestige_label = Label.new()
	research_prestige_label.add_theme_font_size_override("font_size", 20)
	research_prestige_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	research_prestige_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	research_prestige_label.offset_top = 50
	research_prestige_label.offset_left = 20
	research_panel.add_child(research_prestige_label)

	# Tech tree visual control
	var tech_tree = Control.new()
	tech_tree.set_script(preload("res://scripts/tech_tree.gd"))
	tech_tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_tree.offset_top = 80
	tech_tree.offset_bottom = -60
	tech_tree.offset_left = 50
	tech_tree.offset_right = -50
	tech_tree.node_purchased.connect(_on_tech_node_purchased)
	research_panel.add_child(tech_tree)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(150, 45)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back_btn.offset_top = -50
	back_btn.offset_left = -75
	back_btn.offset_right = 75
	back_btn.offset_bottom = -10
	back_btn.pressed.connect(_on_research_back)
	research_panel.add_child(back_btn)


func _build_pause_menu(root: Control):
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_menu)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(bg)

	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_top = -120
	title.offset_left = -150
	title.offset_right = 150
	pause_menu.add_child(title)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_top = -40
	vbox.offset_left = -100
	vbox.offset_right = 100
	vbox.offset_bottom = 120
	vbox.add_theme_constant_override("separation", 15)
	pause_menu.add_child(vbox)

	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 50)
	resume_btn.add_theme_font_size_override("font_size", 20)
	resume_btn.pressed.connect(_on_pause_resume)
	vbox.add_child(resume_btn)

	var restart_btn = Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.pressed.connect(_on_pause_restart)
	vbox.add_child(restart_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.pressed.connect(_on_pause_quit)
	vbox.add_child(quit_btn)

	var prestige_btn = Button.new()
	prestige_btn.text = "End Run & Prestige"
	prestige_btn.custom_minimum_size = Vector2(200, 50)
	prestige_btn.add_theme_font_size_override("font_size", 18)
	prestige_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	prestige_btn.pressed.connect(_on_pause_prestige)
	vbox.add_child(prestige_btn)


func _update_start_menu():
	start_prestige_label.text = "Prestige Points: %d" % GameData.prestige_points
	start_stats_label.text = "Highest Wave: %d | Total Runs: %d | Bosses Killed: %d" % [GameData.highest_wave, GameData.total_runs, GameData.total_bosses_killed]
	var unlocked = GameData.get_available_start_waves()
	for info in start_wave_buttons:
		info["button"].disabled = not (info["wave"] in unlocked)


func _update_research_panel():
	research_prestige_label.text = "@ %d" % GameData.prestige_points


func _on_tech_node_purchased(_key: String):
	_update_research_panel()


func _on_start_menu_wave_pressed(wave: int):
	start_menu.visible = false
	_game_started = true
	get_tree().paused = false
	game_started.emit(wave)


func _on_research_btn_pressed():
	start_menu.visible = false
	research_panel.visible = true
	_update_research_panel()


func _on_research_back():
	research_panel.visible = false
	start_menu.visible = true
	_update_start_menu()


func _on_pause_resume():
	pause_menu.visible = false
	get_tree().paused = false


func _on_pause_restart():
	pause_menu.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_pause_quit():
	pause_menu.visible = false
	get_tree().reload_current_scene()


func _on_pause_prestige():
	pause_menu.visible = false
	# Record the run and show death screen for prestige access
	var main = get_tree().current_scene
	if main.has_method("on_player_died"):
		main.game_over = true
		GameData.record_run(main.wave_number, main.bosses_killed)
		show_death_screen(main.wave_number, main.bosses_killed, GameData.prestige_points)


func toggle_pause():
	if not _game_started or death_panel.visible or upgrade_panel.visible:
		return
	if pause_menu.visible:
		pause_menu.visible = false
		get_tree().paused = false
	else:
		pause_menu.visible = true
		get_tree().paused = true


func set_wave_direction(angle: float):
	if is_instance_valid(minimap_node):
		minimap_node.set_wave_direction(angle)


func _on_start_wave_pressed(wave: int):
	death_panel.visible = false
	get_tree().current_scene.restart_game(wave)


func _update_death_buttons():
	var unlocked = GameData.get_available_start_waves()
	for info in start_buttons:
		info["button"].disabled = not (info["wave"] in unlocked)
	prestige_label.text = "Prestige Points: %d" % GameData.prestige_points


func show_death_screen(wave: int, bosses: int, prestige: int):
	death_stats_label.text = "Survived %d waves | Bosses killed: %d" % [wave, bosses]
	prestige_label.text = "Prestige Points: %d" % prestige
	_update_death_buttons()
	death_panel.visible = true


func _process(delta):
	if alert_timer > 0:
		alert_timer -= delta
		alert_label.modulate.a = clampf(alert_timer / 1.5, 0.0, 1.0)
		if alert_timer <= 0:
			alert_label.visible = false


func _lbl(parent: Node, sz: int, col: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _build_cost_line(parent: Node, prefix: String, iron: int, crystal: int) -> Dictionary:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	parent.add_child(hb)
	var p = Label.new()
	p.text = prefix
	p.add_theme_font_size_override("font_size", 13)
	p.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hb.add_child(p)
	var iron_lbl = Label.new()
	iron_lbl.text = "%dI" % iron
	iron_lbl.add_theme_font_size_override("font_size", 13)
	iron_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	hb.add_child(iron_lbl)
	var plus = Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 13)
	plus.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hb.add_child(plus)
	var crystal_lbl = Label.new()
	crystal_lbl.text = "%dC" % crystal
	crystal_lbl.add_theme_font_size_override("font_size", 13)
	crystal_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	hb.add_child(crystal_lbl)
	return {"iron": iron_lbl, "crystal": crystal_lbl}


func _build_icon(parent: Node, build_type: String, hotkey: String, display_name: String) -> Dictionary:
	var icon = Control.new()
	icon.set_script(preload("res://scripts/build_icon.gd"))
	icon.build_type = build_type
	icon.hotkey = hotkey
	icon.display_name = display_name
	icon.pressed.connect(_on_build_btn_pressed.bind(build_type))
	parent.add_child(icon)

	return {"icon": icon, "type": build_type, "name": display_name}


func _on_build_btn_pressed(build_type: String):
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		var player = players[0]
		if player.build_mode == build_type:
			player.cancel_build_mode()
		else:
			player.enter_build_mode(build_type)


func _make_style(bg: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(4)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 8; s.content_margin_bottom = 8
	return s


func _make_card_style(border_col: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 15; s.content_margin_right = 15
	s.content_margin_top = 15; s.content_margin_bottom = 15
	return s


func update_hud(player: Node2D, wave_timer: float, wave_number: int, wave_active: bool = false):
	if not is_instance_valid(player):
		return
	health_label.text = "HP: %d / %d" % [player.health, player.max_health]
	iron_label.text = "Iron: %d" % player.iron
	crystal_label.text = "Crystal: %d" % player.crystal
	level_label.text = "Lv %d" % player.level
	wave_label.text = "Wave: %d" % wave_number

	if wave_active:
		timer_label.text = "WAVE IN PROGRESS"
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		var m = int(wave_timer) / 60
		var sec = int(wave_timer) % 60
		timer_label.text = "Next wave: %d:%02d" % [m, sec]
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	if player.xp_to_next > 0:
		xp_bar_fill.size.x = 170.0 * float(player.xp) / float(player.xp_to_next)
	else:
		xp_bar_fill.size.x = 170.0

	var ac = get_tree().get_nodes_in_group("aliens").size()
	alien_count_label.text = "Aliens: %d" % ac
	alien_count_label.visible = ac > 0

	# Update building costs dynamically
	_update_build_costs(player)


func _update_build_costs(player: Node2D):
	if not player.has_method("get_building_cost"):
		return
	for info in build_cost_labels:
		var build_type = info["type"]
		var cost = player.get_building_cost(build_type)
		var can_afford = player.iron >= cost["iron"] and player.crystal >= cost["crystal"]
		var is_active = player.build_mode == build_type

		# Update costs for tooltip
		info["icon"].iron_cost = cost["iron"]
		info["icon"].crystal_cost = cost["crystal"]

		# Update icon state for visual feedback
		info["icon"].can_afford = can_afford
		info["icon"].is_active = is_active


func show_wave_alert(wave: int, is_boss: bool = false):
	if is_boss:
		alert_label.text = "WAVE %d - BOSS INCOMING!" % wave
		alert_label.add_theme_color_override("font_color", Color(1, 0.1, 0.05))
	else:
		alert_label.text = "WAVE %d INCOMING!" % wave
		alert_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	alert_label.visible = true
	alert_timer = 3.0
	alert_label.modulate.a = 1.0


func show_game_over(wave: int):
	alert_label.text = "GAME OVER\nSurvived %d waves" % wave
	alert_label.add_theme_color_override("font_color", Color(1, 0.3, 0.1))
	alert_label.visible = true
	alert_label.modulate.a = 1.0
	alert_timer = 10.0


func is_upgrade_showing() -> bool:
	return _upgrade_showing


func show_upgrade_selection(current_upgrades: Dictionary):
	var available: Array = []
	for key in UPGRADE_DATA:
		if current_upgrades.get(key, 0) < UPGRADE_DATA[key]["max"]:
			available.append(key)
	if available.size() == 0:
		return
	available.shuffle()
	var picks = available.slice(0, mini(3, available.size()))

	for i in range(3):
		if i < picks.size():
			var key = picks[i]
			var data = UPGRADE_DATA[key]
			var cur = current_upgrades.get(key, 0)
			var ci = card_info[i]
			ci["key"] = key
			ci["panel"].visible = true
			ci["name_lbl"].text = data["name"]
			ci["name_lbl"].add_theme_color_override("font_color", data["color"])
			ci["lvl_lbl"].text = "Lv %d -> %d" % [cur, cur + 1]
			ci["desc_lbl"].text = _desc(key, cur + 1)
			ci["panel"].add_theme_stylebox_override("panel", _make_card_style(data["color"].lerp(Color.WHITE, 0.2)))
		else:
			card_info[i]["panel"].visible = false

	upgrade_panel.visible = true
	_upgrade_showing = true


func _desc(key: String, lv: int) -> String:
	match key:
		"chain_lightning": return "Shots chain to %d nearby enemies" % lv
		"shotgun": return "Fire %d projectiles in a spread" % (2 + lv)
		"burning": return "Ignite enemies for %d DPS" % (lv * 4)
		"ice": return "Slow enemies by %d%%" % (lv * 15)
		"damage_aura": return "Deal %d DPS in %dpx radius" % [lv * 8, 60 + lv * 30]
		"orbital_lasers": return "%d laser orbs orbit you" % lv
		"max_health": return "+25 Max HP (+%d total)" % (lv * 25)
		"move_speed": return "+15%% speed (+%d%% total)" % (lv * 15)
		"attack_speed": return "+20%% fire rate (+%d%% total)" % (lv * 20)
		"mining_speed": return "+30%% mining speed, +%d yield" % lv
		"mining_heads": return "Mine %d rocks simultaneously" % (lv + 1)
		"turret_damage": return "Turrets deal +%d damage" % (lv * 3)
		"turret_fire_rate": return "Turrets fire %d%% faster" % (lv * 20)
		"factory_speed": return "Factories produce %d%% faster" % (lv * 25)
		"mining_range": return "+25px mining range (+%dpx total)" % (lv * 25)
		"rock_regen": return "+40%% rock spawn rate (+%d%% total)" % (lv * 40)
		"health_regen": return "Heal %d HP per second" % (lv * 2)
		"dodge": return "%d%% chance to dodge attacks" % (lv * 8)
		"armor": return "Reduce damage by %d" % (lv * 2)
		"crit_chance": return "%d%% chance for 2x damage" % (lv * 10)
	return ""


func _on_card_click(event: InputEvent, idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var key = card_info[idx]["key"]
		if key != "":
			upgrade_panel.visible = false
			_upgrade_showing = false
			upgrade_chosen.emit(key)
