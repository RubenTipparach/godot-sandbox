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
var power_label: Label
var power_bar_bg: ColorRect
var power_bar_fill: ColorRect
var power_rate_label: Label
var prestige_hud_label: Label
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
var building_tooltip: PanelContainer
var building_tooltip_label: Label
var is_mobile: bool = false
var joystick: Control = null
var look_joystick: Control = null
var selected_building: Node2D = null
var build_confirm_panel: HBoxContainer = null
var confirm_btn: Button = null
var cancel_build_btn: Button = null

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
	power_label = _lbl(vbox, 15, Color(0.5, 0.8, 1.0))

	power_bar_bg = ColorRect.new()
	power_bar_bg.custom_minimum_size = Vector2(170, 10)
	power_bar_bg.color = Color(0.15, 0.15, 0.25)
	vbox.add_child(power_bar_bg)
	power_bar_fill = ColorRect.new()
	power_bar_fill.color = Color(0.3, 0.6, 1.0)
	power_bar_fill.position = Vector2.ZERO
	power_bar_fill.size = Vector2(0, 10)
	power_bar_bg.add_child(power_bar_fill)

	power_rate_label = _lbl(vbox, 12, Color(0.5, 0.7, 0.9))
	prestige_hud_label = _lbl(vbox, 14, Color(1.0, 0.85, 0.3))

	# Horizontal build bar at bottom center
	var build_bar = PanelContainer.new()
	build_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	build_bar.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.7)))
	build_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_bar.offset_top = -56; build_bar.offset_bottom = -10
	build_bar.offset_left = -240; build_bar.offset_right = 240
	root.add_child(build_bar)

	var build_hbox = HBoxContainer.new()
	build_hbox.add_theme_constant_override("separation", 4)
	build_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	build_bar.add_child(build_hbox)

	build_cost_labels.append(_build_icon(build_hbox, "power_plant", "1", "Power Plant"))
	build_cost_labels.append(_build_icon(build_hbox, "pylon", "2", "Pylon"))
	build_cost_labels.append(_build_icon(build_hbox, "factory", "3", "Factory"))
	build_cost_labels.append(_build_icon(build_hbox, "turret", "4", "Turret"))
	build_cost_labels.append(_build_icon(build_hbox, "wall", "5", "Wall"))
	build_cost_labels.append(_build_icon(build_hbox, "lightning", "6", "Lightning Tower"))
	build_cost_labels.append(_build_icon(build_hbox, "slow", "7", "Slow Tower"))
	build_cost_labels.append(_build_icon(build_hbox, "battery", "8", "Battery"))
	build_cost_labels.append(_build_icon(build_hbox, "flame_turret", "9", "Flame Turret"))
	build_cost_labels.append(_build_icon(build_hbox, "acid_turret", "0", "Acid Turret"))

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
	_build_building_tooltip(root)

	# Detect mobile and add virtual controls
	is_mobile = _detect_mobile()
	if is_mobile:
		_build_mobile_controls(root)

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

	var menu_btn = Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.set_anchors_preset(Control.PRESET_CENTER)
	menu_btn.offset_top = -25
	menu_btn.offset_left = -100
	menu_btn.offset_right = 100
	menu_btn.offset_bottom = 25
	menu_btn.pressed.connect(_on_death_return_to_menu)
	death_panel.add_child(menu_btn)


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

	var debug_container = HBoxContainer.new()
	debug_container.set_anchors_preset(Control.PRESET_CENTER)
	debug_container.offset_top = 100
	debug_container.offset_left = -150
	debug_container.offset_right = 150
	debug_container.offset_bottom = 140
	debug_container.alignment = BoxContainer.ALIGNMENT_CENTER
	debug_container.add_theme_constant_override("separation", 10)
	start_menu.add_child(debug_container)

	for amount in [1, 5, 20]:
		var btn = Button.new()
		btn.text = "+%d P" % amount
		btn.custom_minimum_size = Vector2(80, 36)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		btn.pressed.connect(_on_debug_prestige.bind(amount))
		debug_container.add_child(btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset Progress"
	reset_btn.custom_minimum_size = Vector2(200, 36)
	reset_btn.add_theme_font_size_override("font_size", 14)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	reset_btn.set_anchors_preset(Control.PRESET_CENTER)
	reset_btn.offset_top = 150
	reset_btn.offset_left = -100
	reset_btn.offset_right = 100
	reset_btn.offset_bottom = 186
	reset_btn.pressed.connect(_on_reset_progress)
	start_menu.add_child(reset_btn)


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


func _build_building_tooltip(root: Control):
	building_tooltip = PanelContainer.new()
	building_tooltip.visible = false
	building_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	building_tooltip.add_theme_stylebox_override("panel", style)
	root.add_child(building_tooltip)

	building_tooltip_label = Label.new()
	building_tooltip_label.add_theme_font_size_override("font_size", 14)
	building_tooltip_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	building_tooltip.add_child(building_tooltip_label)


func _detect_mobile() -> bool:
	if OS.has_feature("mobile"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("(navigator.maxTouchPoints > 0) || ('ontouchstart' in window) || window.matchMedia('(pointer: coarse)').matches")
		return result == true
	return false


func _build_mobile_controls(root: Control):
	# Left joystick - movement
	joystick = Control.new()
	joystick.set_script(preload("res://scripts/mobile_joystick.gd"))
	joystick.joystick_type = "move"
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 20
	joystick.offset_top = -180
	joystick.offset_right = 180
	joystick.offset_bottom = -20
	root.add_child(joystick)

	# Right joystick - rotation/facing
	look_joystick = Control.new()
	look_joystick.set_script(preload("res://scripts/mobile_joystick.gd"))
	look_joystick.joystick_type = "look"
	look_joystick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	look_joystick.offset_left = -180
	look_joystick.offset_top = -180
	look_joystick.offset_right = -20
	look_joystick.offset_bottom = -20
	root.add_child(look_joystick)

	# Build confirm/cancel buttons (shown only in build mode)
	build_confirm_panel = HBoxContainer.new()
	build_confirm_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_confirm_panel.offset_top = -110
	build_confirm_panel.offset_bottom = -62
	build_confirm_panel.offset_left = -130
	build_confirm_panel.offset_right = 130
	build_confirm_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	build_confirm_panel.add_theme_constant_override("separation", 20)
	build_confirm_panel.visible = false
	root.add_child(build_confirm_panel)

	cancel_build_btn = Button.new()
	cancel_build_btn.text = "Cancel"
	cancel_build_btn.custom_minimum_size = Vector2(110, 44)
	cancel_build_btn.add_theme_font_size_override("font_size", 18)
	cancel_build_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	cancel_build_btn.pressed.connect(_on_cancel_build_pressed)
	build_confirm_panel.add_child(cancel_build_btn)

	confirm_btn = Button.new()
	confirm_btn.text = "Place"
	confirm_btn.custom_minimum_size = Vector2(110, 44)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	confirm_btn.pressed.connect(_on_confirm_build_pressed)
	build_confirm_panel.add_child(confirm_btn)


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


func _on_debug_prestige(amount: int):
	GameData.add_prestige(amount)
	_update_start_menu()


func _on_reset_progress():
	GameData.prestige_points = 0
	GameData.highest_wave = 0
	GameData.total_bosses_killed = 0
	GameData.total_runs = 0
	GameData.unlocked_start_waves = [1]
	for key in GameData.research.keys():
		GameData.research[key] = 0
	GameData.save_data()
	_update_start_menu()


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


func _on_death_return_to_menu():
	death_panel.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func show_death_screen(wave: int, bosses: int, prestige: int):
	death_stats_label.text = "Survived %d waves | Bosses killed: %d" % [wave, bosses]
	prestige_label.text = "Prestige Points: %d" % prestige
	death_panel.visible = true


func _unhandled_input(event: InputEvent):
	if not is_mobile or not _game_started or get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed:
		var player = _get_player()
		if not player:
			return
		if player.is_in_build_mode():
			# Tap sets the pending build position on mobile
			var world_pos = _screen_to_world(event.position)
			if world_pos != null:
				player.pending_build_world_pos = world_pos.snapped(Vector2(40, 40))
		else:
			# Check for building selection (tooltip)
			_handle_mobile_building_tap(event.position)


func _screen_to_world(screen_pos: Vector2):
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return null
	var vp_size = get_viewport().get_visible_rect().size
	return cam.global_position + (screen_pos - vp_size / 2.0) / cam.zoom


func _handle_mobile_building_tap(screen_pos: Vector2):
	var world_pos = _screen_to_world(screen_pos)
	if world_pos == null:
		selected_building = null
		return

	var closest_building: Node2D = null
	var closest_dist = 50.0  # Larger detection radius for touch

	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		var dist = world_pos.distance_to(b.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_building = b

	selected_building = closest_building


func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		return players[0]
	return null


func _on_confirm_build_pressed():
	var player = _get_player()
	if player:
		player.confirm_build()


func _on_cancel_build_pressed():
	var player = _get_player()
	if player:
		player.cancel_build_mode()


func _process(delta):
	if alert_timer > 0:
		alert_timer -= delta
		alert_label.modulate.a = clampf(alert_timer / 1.5, 0.0, 1.0)
		if alert_timer <= 0:
			alert_label.visible = false

	# Toggle mobile build confirm buttons
	if is_mobile and build_confirm_panel:
		var player = _get_player()
		var in_build = player != null and player.is_in_build_mode()
		build_confirm_panel.visible = in_build
		if in_build and player:
			var valid = player.can_place_at(player.pending_build_world_pos) and player.can_afford(player.build_mode)
			confirm_btn.disabled = not valid

	# Update building tooltip
	_update_building_tooltip()


func _update_building_tooltip():
	if not _game_started or get_tree().paused:
		building_tooltip.visible = false
		return

	var cam = get_viewport().get_camera_2d()
	if not cam:
		building_tooltip.visible = false
		return

	if is_mobile:
		_update_building_tooltip_mobile(cam)
	else:
		_update_building_tooltip_desktop(cam)


func _update_building_tooltip_desktop(cam: Camera2D):
	var mouse_screen = get_viewport().get_mouse_position()
	var vp_size = get_viewport().get_visible_rect().size
	var mouse_world = cam.get_global_transform().affine_inverse() * mouse_screen + cam.global_position - vp_size / 2.0 / cam.zoom

	# Find building under mouse
	var closest_building: Node2D = null
	var closest_dist = 40.0

	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		var dist = mouse_world.distance_to(b.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_building = b

	if closest_building and closest_building.has_method("get_building_name"):
		building_tooltip_label.text = closest_building.get_building_name()
		building_tooltip.visible = true
		building_tooltip.position = mouse_screen + Vector2(15, 15)
	else:
		building_tooltip.visible = false


func _update_building_tooltip_mobile(cam: Camera2D):
	var player = _get_player()
	var vp_size = get_viewport().get_visible_rect().size

	# Show build-type tooltip while in build mode
	if player and player.is_in_build_mode():
		var info = _get_build_type_info(player.build_mode)
		if info != "":
			building_tooltip_label.text = info
			building_tooltip.visible = true
			# Position above the confirm panel, centered
			building_tooltip.position = Vector2(vp_size.x / 2.0 - 60, vp_size.y - 160)
			var ts = building_tooltip.size
			building_tooltip.position.x = clampf(vp_size.x / 2.0 - ts.x / 2.0, 5, vp_size.x - ts.x - 5)
		return

	if selected_building == null or not is_instance_valid(selected_building):
		selected_building = null
		building_tooltip.visible = false
		return

	var screen_pos = (selected_building.global_position - cam.global_position) * cam.zoom + vp_size / 2.0
	building_tooltip_label.text = _get_building_info_text(selected_building)
	building_tooltip.visible = true
	building_tooltip.position = screen_pos + Vector2(15, -60)
	# Clamp tooltip to screen
	var ts = building_tooltip.size
	building_tooltip.position.x = clampf(building_tooltip.position.x, 5, vp_size.x - ts.x - 5)
	building_tooltip.position.y = clampf(building_tooltip.position.y, 5, vp_size.y - ts.y - 5)


func _get_building_info_text(b: Node2D) -> String:
	if not b.has_method("get_building_name"):
		return ""
	var name = b.get_building_name()
	var lines = [name]
	if "hp" in b and "max_hp" in b:
		lines.append("HP: %d/%d" % [b.hp, b.max_hp])
	if b.has_method("is_powered"):
		lines.append("Power: " + ("ON" if b.is_powered() else "OFF"))
	match name:
		"Turret":
			var dmg = 8 + (b.damage_bonus if "damage_bonus" in b else 0)
			lines.append("DMG: %d | Range: 250" % dmg)
		"Factory":
			lines.append("Produces Iron & Crystal")
		"Lightning Tower":
			lines.append("DMG: 15 | Range: 180")
		"Slow Tower":
			lines.append("Slow: 50% | Range: 150")
		"Pylon":
			lines.append("Power Range: 150")
		"Power Plant":
			lines.append("Power Range: 120")
		"HQ":
			lines.append("Power Range: 150")
		"Wall":
			lines.append("Blocks enemies")
		"Battery":
			lines.append("Stores 50 power")
		"Flame Turret":
			lines.append("AoE fire DMG | Range: 120")
		"Acid Turret":
			lines.append("Acid + puddles | Range: 200")
	return "\n".join(lines)


func _get_build_type_info(build_type: String) -> String:
	var player = _get_player()
	var cost_text = ""
	if player:
		var cost = player.get_building_cost(build_type)
		cost_text = "Cost: %dI + %dC" % [cost["iron"], cost["crystal"]]
	match build_type:
		"turret":
			return "Turret\nDMG: 8 | Range: 250\nRequires power\n" + cost_text
		"factory":
			return "Factory\nProduces Iron & Crystal\nRequires power\n" + cost_text
		"wall":
			return "Wall\nHP: 150 | Blocks enemies\n" + cost_text
		"lightning":
			return "Lightning Tower\nDMG: 15 | Range: 180\nRequires power\n" + cost_text
		"slow":
			return "Slow Tower\nSlow: 50% | Range: 150\nRequires power\n" + cost_text
		"pylon":
			return "Pylon\nExtends power | Range: 150\nRequires power chain\n" + cost_text
		"power_plant":
			return "Power Plant\nProvides power | Range: 120\n" + cost_text
		"battery":
			return "Battery\nStores 50 power\n" + cost_text
		"flame_turret":
			return "Flame Turret\nAoE fire DMG | Range: 120\nBurns enemies | Requires power\n" + cost_text
		"acid_turret":
			return "Acid Turret\nShoots acid + puddles | Range: 200\nRequires power\n" + cost_text
	return build_type + "\n" + cost_text


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


func update_hud(player: Node2D, wave_timer: float, wave_number: int, wave_active: bool = false, power_gen: float = 0.0, power_cons: float = 0.0, _power_on: bool = true, rates: Dictionary = {}, power_bank: float = 0.0, max_power_bank: float = 0.0, prestige_earned: int = 0):
	if not is_instance_valid(player):
		return
	health_label.text = "HP: %d / %d" % [player.health, player.max_health]

	var iron_rate = rates.get("iron", 0.0)
	var crystal_rate = rates.get("crystal", 0.0)
	if iron_rate > 0:
		iron_label.text = "Iron: %d  +%.1f/s" % [player.iron, iron_rate]
	else:
		iron_label.text = "Iron: %d" % player.iron
	if crystal_rate > 0:
		crystal_label.text = "Crystal: %d  +%.1f/s" % [player.crystal, crystal_rate]
	else:
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

	# Energy display
	power_label.text = "Energy: %d / %d" % [int(power_bank), int(max_power_bank)]
	if power_gen >= power_cons:
		power_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		power_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	# Energy bar
	power_bar_bg.visible = true
	power_rate_label.visible = true
	if max_power_bank > 0:
		power_bar_fill.size.x = 170.0 * clampf(power_bank / max_power_bank, 0.0, 1.0)
	else:
		power_bar_fill.size.x = 0.0
	var net = power_gen - power_cons
	if net >= 0:
		power_bar_fill.color = Color(0.3, 0.6, 1.0)
		power_rate_label.text = "+%.0f/s" % net
		power_rate_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		power_bar_fill.color = Color(1.0, 0.4, 0.2)
		power_rate_label.text = "%.0f/s" % net
		power_rate_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	# Prestige earned this run
	prestige_hud_label.text = "Prestige: +%d" % prestige_earned

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

		# Check research locks
		match build_type:
			"lightning":
				info["icon"].locked = GameData.get_research_bonus("unlock_lightning") < 1.0
			"slow":
				info["icon"].locked = GameData.get_research_bonus("turret_ice") < 1.0
			"flame_turret":
				info["icon"].locked = GameData.get_research_bonus("turret_fire") < 1.0
			"acid_turret":
				info["icon"].locked = GameData.get_research_bonus("turret_acid") < 1.0
			_:
				info["icon"].locked = false


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
