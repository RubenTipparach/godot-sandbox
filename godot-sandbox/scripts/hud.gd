extends CanvasLayer

const CFG = preload("res://resources/game_config.tres")

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
var vote_status_label: Label
var _local_vote_key: String = ""

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
var build_bar_tooltip: PanelContainer
var build_bar_tooltip_name: Label
var build_bar_tooltip_iron: Label
var build_bar_tooltip_crystal: Label
var build_bar_tooltip_power: Label
var _hovered_build_icon = null
var build_bar_tooltip_desc: Label
var is_mobile: bool = false
var joystick: Control = null
var look_joystick: Control = null
var selected_building: Node3D = null
var build_confirm_panel: HBoxContainer = null
var confirm_btn: Button = null
var cancel_build_btn: Button = null

var lobby_panel: Control
var lobby_code_label: Label
var lobby_code_input: LineEdit
var lobby_status_label: Label
var lobby_start_btn: Button
var lobby_connect_btn: Button
var lobby_host_section: VBoxContainer
var lobby_client_section: VBoxContainer
var partner_panels: Array = []  # Array of {"panel": PanelContainer, "label": Label}

var lobby_name_input: LineEdit
var local_player_name: String = ""
var lobby_players_label: Label
var respawn_label: Label
var respawn_countdown: float = 0.0
var room_code_label: Label
var building_info_panel: PanelContainer = null
var building_info_label: Label = null
var recycle_btn: Button = null
var toggle_power_btn: Button = null
var hq_health_label: Label
var hq_bar_bg: ColorRect
var hq_bar_fill: ColorRect
var hq_panel: PanelContainer
var settings_panel: Control = null
var auto_fire_btn: Button = null
var auto_aim_btn: Button = null
var _settings_from_pause: bool = false  # Track where settings was opened from
var gameplay_hud: Control = null  # Container for all in-game HUD elements (hidden during menu)
var start_wave_btn: Button = null
var loading_panel: Control = null
var loading_bar_fill: ColorRect = null
var loading_label: Label = null
var _loading_step: int = -1
var debug_overlay: Label = null
var debug_btn: Button = null
var debug_layer: CanvasLayer = null
var disconnect_panel: Control = null

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
	"pickup_range": {"name": "Magnetic Field", "color": Color(1.0, 0.9, 0.3), "max": 5},
}

const BUILD_DESCRIPTIONS = {
	"power_plant": "Generates power for nearby buildings",
	"pylon": "Extends power range to distant buildings",
	"factory": "Auto-generates iron and crystal",
	"turret": "Shoots at nearby enemies",
	"wall": "Blocks enemy movement, high HP",
	"lightning": "Chain lightning hits multiple targets",
	"slow": "Slows enemies in range",
	"battery": "Stores excess power for outages",
	"flame_turret": "Burns enemies, damage over time",
	"acid_turret": "Leaves acid puddles on the ground",
	"repair_drone": "Automatically repairs nearby buildings",
	"poison_turret": "Poisons enemies, spreads on contact",
}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Make tooltips appear instantly
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Debug layer (always on top of everything)
	debug_layer = CanvasLayer.new()
	debug_layer.layer = 100
	add_child(debug_layer)
	var debug_root = Control.new()
	debug_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_layer.add_child(debug_root)

	debug_btn = Button.new()
	debug_btn.text = "Debug"
	debug_btn.custom_minimum_size = Vector2(60, 24)
	debug_btn.add_theme_font_size_override("font_size", 11)
	debug_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	debug_btn.offset_left = -30; debug_btn.offset_right = 30
	debug_btn.offset_top = 4; debug_btn.offset_bottom = 28
	debug_btn.modulate.a = 0.5
	debug_btn.pressed.connect(_on_debug_overlay_toggle)
	debug_root.add_child(debug_btn)

	debug_overlay = Label.new()
	debug_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_overlay.offset_left = 10; debug_overlay.offset_top = 32
	debug_overlay.offset_right = 400; debug_overlay.offset_bottom = 300
	debug_overlay.add_theme_font_size_override("font_size", 12)
	debug_overlay.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4))
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.visible = CFG.debug_overlay_default
	var debug_bg = ColorRect.new()
	debug_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_bg.color = Color(0, 0, 0, 0.5)
	debug_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.add_child(debug_bg)
	debug_overlay.move_child(debug_bg, 0)
	debug_root.add_child(debug_overlay)

	# All in-game HUD elements go inside gameplay_hud (hidden during menu)
	gameplay_hud = Control.new()
	gameplay_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.visible = false
	root.add_child(gameplay_hud)

	# Left column for stacked panels
	var left_col = VBoxContainer.new()
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.position = Vector2(10, 10)
	left_col.add_theme_constant_override("separation", 6)
	gameplay_hud.add_child(left_col)

	# --- Player Panel: Health, XP, Level, Prestige ---
	var player_panel = PanelContainer.new()
	player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_panel.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.65)))
	left_col.add_child(player_panel)
	var player_vbox = VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 2)
	player_panel.add_child(player_vbox)

	health_label = _lbl(player_vbox, 16, Color(0.4, 1.0, 0.4))
	level_label = _lbl(player_vbox, 15, Color(0.9, 0.8, 0.3))

	xp_bar_bg = ColorRect.new()
	xp_bar_bg.custom_minimum_size = Vector2(170, 8)
	xp_bar_bg.color = Color(0.15, 0.15, 0.25)
	player_vbox.add_child(xp_bar_bg)
	xp_bar_fill = ColorRect.new()
	xp_bar_fill.color = Color(0.3, 0.8, 1.0)
	xp_bar_fill.position = Vector2.ZERO
	xp_bar_fill.size = Vector2(0, 8)
	xp_bar_bg.add_child(xp_bar_fill)

	prestige_hud_label = _lbl(player_vbox, 13, Color(1.0, 0.85, 0.3))

	# --- Resources Panel: Iron, Crystal, Energy ---
	var res_panel = PanelContainer.new()
	res_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	res_panel.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.65)))
	left_col.add_child(res_panel)
	var res_vbox = VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 2)
	res_panel.add_child(res_vbox)

	iron_label = _lbl(res_vbox, 15, Color(0.8, 0.75, 0.65))
	crystal_label = _lbl(res_vbox, 15, Color(0.5, 0.7, 1.0))
	power_label = _lbl(res_vbox, 14, Color(0.5, 0.8, 1.0))

	power_bar_bg = ColorRect.new()
	power_bar_bg.custom_minimum_size = Vector2(170, 8)
	power_bar_bg.color = Color(0.15, 0.15, 0.25)
	res_vbox.add_child(power_bar_bg)
	power_bar_fill = ColorRect.new()
	power_bar_fill.color = Color(0.3, 0.6, 1.0)
	power_bar_fill.position = Vector2.ZERO
	power_bar_fill.size = Vector2(0, 8)
	power_bar_bg.add_child(power_bar_fill)

	power_rate_label = _lbl(res_vbox, 11, Color(0.5, 0.7, 0.9))

	# --- Wave Panel: Wave, Timer, Alien count ---
	var wave_panel = PanelContainer.new()
	wave_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_panel.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.65)))
	left_col.add_child(wave_panel)
	var wave_vbox = VBoxContainer.new()
	wave_vbox.add_theme_constant_override("separation", 2)
	wave_panel.add_child(wave_vbox)

	wave_label = _lbl(wave_vbox, 16, Color.WHITE)
	timer_label = _lbl(wave_vbox, 17, Color(1.0, 0.4, 0.4))
	start_wave_btn = Button.new()
	start_wave_btn.text = "Start Wave"
	start_wave_btn.custom_minimum_size = Vector2(120, 28)
	start_wave_btn.add_theme_font_size_override("font_size", 13)
	start_wave_btn.visible = false
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	wave_vbox.add_child(start_wave_btn)
	alien_count_label = _lbl(wave_vbox, 13, Color(1.0, 0.5, 0.4))

	# --- HQ Health Panel ---
	hq_panel = PanelContainer.new()
	hq_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hq_panel.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.65)))
	left_col.add_child(hq_panel)
	var hq_vbox = VBoxContainer.new()
	hq_vbox.add_theme_constant_override("separation", 2)
	hq_panel.add_child(hq_vbox)

	hq_health_label = _lbl(hq_vbox, 15, Color(0.5, 0.8, 1.0))

	hq_bar_bg = ColorRect.new()
	hq_bar_bg.custom_minimum_size = Vector2(170, 8)
	hq_bar_bg.color = Color(0.15, 0.15, 0.25)
	hq_vbox.add_child(hq_bar_bg)
	hq_bar_fill = ColorRect.new()
	hq_bar_fill.color = Color(0.3, 0.8, 1.0)
	hq_bar_fill.position = Vector2.ZERO
	hq_bar_fill.size = Vector2(170, 8)
	hq_bar_bg.add_child(hq_bar_fill)

	# Horizontal build bar at bottom center
	var build_bar = PanelContainer.new()
	build_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	build_bar.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.7)))
	build_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_bar.offset_top = -56; build_bar.offset_bottom = -10
	build_bar.offset_left = -260; build_bar.offset_right = 260
	gameplay_hud.add_child(build_bar)

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
	build_cost_labels.append(_build_icon(build_hbox, "repair_drone", "Q", "Repair Drone"))
	build_cost_labels.append(_build_icon(build_hbox, "poison_turret", "E", "Poison Turret"))

	# Instant build bar tooltip (bypasses Godot's tooltip delay)
	build_bar_tooltip = PanelContainer.new()
	var tt_style = StyleBoxFlat.new()
	tt_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	tt_style.set_corner_radius_all(4)
	tt_style.content_margin_left = 8
	tt_style.content_margin_right = 8
	tt_style.content_margin_top = 4
	tt_style.content_margin_bottom = 4
	build_bar_tooltip.add_theme_stylebox_override("panel", tt_style)
	build_bar_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_bar_tooltip.visible = false
	var tt_vbox = VBoxContainer.new()
	tt_vbox.add_theme_constant_override("separation", 2)
	build_bar_tooltip.add_child(tt_vbox)
	var tt_hbox = HBoxContainer.new()
	tt_hbox.add_theme_constant_override("separation", 6)
	tt_vbox.add_child(tt_hbox)
	build_bar_tooltip_name = Label.new()
	build_bar_tooltip_name.add_theme_font_size_override("font_size", 14)
	build_bar_tooltip_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	tt_hbox.add_child(build_bar_tooltip_name)
	build_bar_tooltip_iron = Label.new()
	build_bar_tooltip_iron.add_theme_font_size_override("font_size", 14)
	tt_hbox.add_child(build_bar_tooltip_iron)
	build_bar_tooltip_crystal = Label.new()
	build_bar_tooltip_crystal.add_theme_font_size_override("font_size", 14)
	tt_hbox.add_child(build_bar_tooltip_crystal)
	build_bar_tooltip_power = Label.new()
	build_bar_tooltip_power.add_theme_font_size_override("font_size", 14)
	tt_hbox.add_child(build_bar_tooltip_power)
	build_bar_tooltip_desc = Label.new()
	build_bar_tooltip_desc.add_theme_font_size_override("font_size", 12)
	build_bar_tooltip_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	tt_vbox.add_child(build_bar_tooltip_desc)
	gameplay_hud.add_child(build_bar_tooltip)

	alert_label = Label.new()
	alert_label.add_theme_font_size_override("font_size", 36)
	alert_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.offset_top = 100; alert_label.offset_left = -300; alert_label.offset_right = 300
	alert_label.visible = false
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(alert_label)

	minimap_node = Control.new()
	minimap_node.set_script(preload("res://scripts/minimap.gd"))
	minimap_node.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_node.offset_left = -170; minimap_node.offset_top = 10; minimap_node.offset_right = -10; minimap_node.offset_bottom = 170
	minimap_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(minimap_node)

	# Partner health panels (MP only, top-right below minimap) - up to 3 partners
	var partner_vbox = VBoxContainer.new()
	partner_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	partner_vbox.offset_left = -170
	partner_vbox.offset_top = 175
	partner_vbox.offset_right = -10
	partner_vbox.add_theme_constant_override("separation", 4)
	partner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(partner_vbox)
	for i in range(3):
		var pp = PanelContainer.new()
		pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pp.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.65)))
		pp.visible = false
		partner_vbox.add_child(pp)
		var plbl = Label.new()
		plbl.add_theme_font_size_override("font_size", 14)
		plbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		pp.add_child(plbl)
		partner_panels.append({"panel": pp, "label": plbl})

	# Respawn countdown overlay (centered, large, hidden by default)
	respawn_label = Label.new()
	respawn_label.add_theme_font_size_override("font_size", 32)
	respawn_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_label.set_anchors_preset(Control.PRESET_CENTER)
	respawn_label.offset_top = -40
	respawn_label.offset_left = -200
	respawn_label.offset_right = 200
	respawn_label.visible = false
	respawn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(respawn_label)

	# Room code container (top-right, below minimap, above partner panels)
	var room_code_hbox = HBoxContainer.new()
	room_code_hbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	room_code_hbox.offset_left = -220
	room_code_hbox.offset_top = 172
	room_code_hbox.offset_right = -10
	room_code_hbox.alignment = BoxContainer.ALIGNMENT_END
	room_code_hbox.add_theme_constant_override("separation", 4)
	room_code_hbox.visible = false
	room_code_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(room_code_hbox)
	room_code_label = Label.new()
	room_code_label.add_theme_font_size_override("font_size", 13)
	room_code_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 0.7))
	room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_code_hbox.add_child(room_code_label)
	var copy_btn = Button.new()
	copy_btn.text = "Copy"
	copy_btn.custom_minimum_size = Vector2(50, 22)
	copy_btn.add_theme_font_size_override("font_size", 11)
	copy_btn.pressed.connect(_on_copy_room_code)
	room_code_hbox.add_child(copy_btn)

	_build_upgrade_panel(root)
	_build_death_panel(root)
	_build_start_menu(root)
	_build_research_panel(root)
	_build_pause_menu(root)
	_build_settings_panel(root)
	_build_lobby_panel(root)
	_build_building_tooltip(root)
	_build_building_info_panel(root)
	_build_loading_panel(root)
	_build_disconnect_panel(root)

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

		var vote_lbl = Label.new()
		vote_lbl.add_theme_font_size_override("font_size", 13)
		vote_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		vote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vote_lbl.visible = false
		vb.add_child(vote_lbl)

		var voters_lbl = Label.new()
		voters_lbl.add_theme_font_size_override("font_size", 11)
		voters_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		voters_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		voters_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		voters_lbl.visible = false
		vb.add_child(voters_lbl)

		card.gui_input.connect(_on_card_click.bind(i))
		card_info.append({"panel": card, "name_lbl": nl, "lvl_lbl": ll, "desc_lbl": dl, "vote_count_lbl": vote_lbl, "voters_lbl": voters_lbl, "key": ""})

	vote_status_label = Label.new()
	vote_status_label.add_theme_font_size_override("font_size", 16)
	vote_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vote_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vote_status_label.set_anchors_preset(Control.PRESET_CENTER)
	vote_status_label.offset_top = 160
	vote_status_label.offset_left = -250
	vote_status_label.offset_right = 250
	vote_status_label.visible = false
	vote_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_panel.add_child(vote_status_label)


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

	var coop_container = HBoxContainer.new()
	coop_container.set_anchors_preset(Control.PRESET_CENTER)
	coop_container.offset_top = 100
	coop_container.offset_left = -160
	coop_container.offset_right = 160
	coop_container.alignment = BoxContainer.ALIGNMENT_CENTER
	coop_container.add_theme_constant_override("separation", 20)
	start_menu.add_child(coop_container)

	var host_btn = Button.new()
	host_btn.text = "Host Co-op"
	host_btn.custom_minimum_size = Vector2(150, 45)
	host_btn.add_theme_font_size_override("font_size", 18)
	host_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	host_btn.pressed.connect(_on_host_coop_pressed)
	_style_button(host_btn, Color(0.15, 0.4, 0.2))
	coop_container.add_child(host_btn)

	var join_btn = Button.new()
	join_btn.text = "Join Co-op"
	join_btn.custom_minimum_size = Vector2(150, 45)
	join_btn.add_theme_font_size_override("font_size", 18)
	join_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	join_btn.pressed.connect(_on_join_coop_pressed)
	_style_button(join_btn, Color(0.15, 0.25, 0.45))
	coop_container.add_child(join_btn)

	var start_settings_btn = Button.new()
	start_settings_btn.text = "Settings"
	start_settings_btn.custom_minimum_size = Vector2(150, 45)
	start_settings_btn.add_theme_font_size_override("font_size", 18)
	start_settings_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	start_settings_btn.offset_top = -55
	start_settings_btn.offset_left = 10
	start_settings_btn.offset_right = 160
	start_settings_btn.offset_bottom = -10
	start_settings_btn.pressed.connect(_on_open_settings_from_menu)
	start_menu.add_child(start_settings_btn)

	var debug_toggle_btn = Button.new()
	debug_toggle_btn.text = "Debug"
	debug_toggle_btn.custom_minimum_size = Vector2(80, 30)
	debug_toggle_btn.add_theme_font_size_override("font_size", 12)
	debug_toggle_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	debug_toggle_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	debug_toggle_btn.offset_top = -40
	debug_toggle_btn.offset_left = -90
	debug_toggle_btn.offset_right = -10
	debug_toggle_btn.offset_bottom = -10
	debug_toggle_btn.pressed.connect(_on_debug_toggle)
	start_menu.add_child(debug_toggle_btn)

	var debug_panel = VBoxContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.set_anchors_preset(Control.PRESET_CENTER)
	debug_panel.offset_top = 100
	debug_panel.offset_left = -150
	debug_panel.offset_right = 150
	debug_panel.offset_bottom = 200
	debug_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	debug_panel.add_theme_constant_override("separation", 8)
	debug_panel.visible = false
	start_menu.add_child(debug_panel)

	var debug_prestige_row = HBoxContainer.new()
	debug_prestige_row.alignment = BoxContainer.ALIGNMENT_CENTER
	debug_prestige_row.add_theme_constant_override("separation", 10)
	debug_panel.add_child(debug_prestige_row)

	for amount in [1, 5, 20]:
		var btn = Button.new()
		btn.text = "+%d P" % amount
		btn.custom_minimum_size = Vector2(80, 36)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		btn.pressed.connect(_on_debug_prestige.bind(amount))
		debug_prestige_row.add_child(btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset Progress"
	reset_btn.custom_minimum_size = Vector2(200, 36)
	reset_btn.add_theme_font_size_override("font_size", 14)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	reset_btn.pressed.connect(_on_reset_progress)
	debug_panel.add_child(reset_btn)


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

	var settings_btn = Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(200, 50)
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.pressed.connect(_on_open_settings)
	vbox.add_child(settings_btn)


func _build_settings_panel(root: Control):
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(settings_panel)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.add_child(bg)

	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_top = -160
	title.offset_left = -200
	title.offset_right = 200
	settings_panel.add_child(title)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_top = -80
	vbox.offset_left = -120
	vbox.offset_right = 120
	vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 15)
	settings_panel.add_child(vbox)

	auto_fire_btn = Button.new()
	auto_fire_btn.text = "Auto Fire: ON"
	auto_fire_btn.custom_minimum_size = Vector2(240, 45)
	auto_fire_btn.add_theme_font_size_override("font_size", 18)
	auto_fire_btn.pressed.connect(_on_toggle_auto_fire)
	vbox.add_child(auto_fire_btn)

	auto_aim_btn = Button.new()
	auto_aim_btn.text = "Auto Aim: ON"
	auto_aim_btn.custom_minimum_size = Vector2(240, 45)
	auto_aim_btn.add_theme_font_size_override("font_size", 18)
	auto_aim_btn.pressed.connect(_on_toggle_auto_aim)
	vbox.add_child(auto_aim_btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(240, 50)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_on_settings_back)
	vbox.add_child(back_btn)


func _build_lobby_panel(root: Control):
	lobby_panel = Control.new()
	lobby_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_panel.visible = false
	lobby_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(lobby_panel)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.08, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_panel.add_child(bg)

	var title = Label.new()
	title.text = "CO-OP LOBBY"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 80
	title.offset_left = -200
	title.offset_right = 200
	lobby_panel.add_child(title)

	# Name input (shared by host and client)
	var name_row = HBoxContainer.new()
	name_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_row.offset_top = 135
	name_row.offset_left = -150
	name_row.offset_right = 150
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 8)
	lobby_panel.add_child(name_row)

	var name_title = Label.new()
	name_title.text = "Your Name:"
	name_title.add_theme_font_size_override("font_size", 16)
	name_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	name_row.add_child(name_title)

	lobby_name_input = LineEdit.new()
	lobby_name_input.max_length = 12
	lobby_name_input.placeholder_text = "Enter your name..."
	lobby_name_input.custom_minimum_size = Vector2(160, 36)
	lobby_name_input.add_theme_font_size_override("font_size", 18)
	if GameData.player_name != "":
		lobby_name_input.text = GameData.player_name
	name_row.add_child(lobby_name_input)
	lobby_name_input.focus_entered.connect(_on_lobby_input_focused.bind(lobby_name_input))
	lobby_name_input.focus_exited.connect(_on_lobby_input_unfocused)
	lobby_name_input.text_changed.connect(_on_lobby_name_changed)

	# Single centered VBoxContainer for all lobby content (auto-stacks, no overlaps)
	var lobby_center = VBoxContainer.new()
	lobby_center.set_anchors_preset(Control.PRESET_CENTER)
	lobby_center.offset_left = -200
	lobby_center.offset_right = 200
	lobby_center.offset_top = -180
	lobby_center.offset_bottom = 200
	lobby_center.add_theme_constant_override("separation", 10)
	lobby_center.alignment = BoxContainer.ALIGNMENT_CENTER
	lobby_panel.add_child(lobby_center)

	# Host section - shows room code
	lobby_host_section = VBoxContainer.new()
	lobby_host_section.add_theme_constant_override("separation", 8)
	lobby_host_section.visible = false
	lobby_center.add_child(lobby_host_section)

	var code_title = Label.new()
	code_title.text = "Room Code:"
	code_title.add_theme_font_size_override("font_size", 18)
	code_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	code_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_host_section.add_child(code_title)

	lobby_code_label = Label.new()
	lobby_code_label.text = "------"
	lobby_code_label.add_theme_font_size_override("font_size", 48)
	lobby_code_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lobby_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_host_section.add_child(lobby_code_label)

	var lobby_copy_btn = Button.new()
	lobby_copy_btn.text = "Copy Code"
	lobby_copy_btn.custom_minimum_size = Vector2(140, 32)
	lobby_copy_btn.add_theme_font_size_override("font_size", 14)
	lobby_copy_btn.pressed.connect(_on_copy_lobby_code)
	lobby_host_section.add_child(lobby_copy_btn)

	var share_hint = Label.new()
	share_hint.text = "Share this code with your friends"
	share_hint.add_theme_font_size_override("font_size", 14)
	share_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	share_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_host_section.add_child(share_hint)

	# Client section - code input
	lobby_client_section = VBoxContainer.new()
	lobby_client_section.add_theme_constant_override("separation", 14)
	lobby_client_section.visible = false
	lobby_center.add_child(lobby_client_section)

	var input_title = Label.new()
	input_title.text = "Enter Room Code:"
	input_title.add_theme_font_size_override("font_size", 18)
	input_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	input_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_client_section.add_child(input_title)

	lobby_code_input = LineEdit.new()
	lobby_code_input.max_length = 6
	lobby_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_code_input.placeholder_text = "ABC123"
	lobby_code_input.custom_minimum_size = Vector2(240, 50)
	lobby_code_input.add_theme_font_size_override("font_size", 32)
	lobby_client_section.add_child(lobby_code_input)
	lobby_code_input.focus_entered.connect(_on_lobby_input_focused.bind(lobby_code_input))
	lobby_code_input.focus_exited.connect(_on_lobby_input_unfocused)
	lobby_code_input.text_submitted.connect(_on_lobby_code_text_submitted)

	lobby_connect_btn = Button.new()
	lobby_connect_btn.text = "Connect"
	lobby_connect_btn.custom_minimum_size = Vector2(200, 45)
	lobby_connect_btn.add_theme_font_size_override("font_size", 18)
	lobby_connect_btn.pressed.connect(_on_lobby_connect_pressed)
	_style_button(lobby_connect_btn, Color(0.15, 0.25, 0.45))
	lobby_client_section.add_child(lobby_connect_btn)

	# Shared status + players (auto-stacked below whichever section is visible)
	lobby_status_label = Label.new()
	lobby_status_label.text = ""
	lobby_status_label.add_theme_font_size_override("font_size", 18)
	lobby_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_center.add_child(lobby_status_label)

	lobby_players_label = Label.new()
	lobby_players_label.add_theme_font_size_override("font_size", 15)
	lobby_players_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	lobby_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_center.add_child(lobby_players_label)

	# Start button (host only)
	lobby_start_btn = Button.new()
	lobby_start_btn.text = "Start Game"
	lobby_start_btn.custom_minimum_size = Vector2(200, 50)
	lobby_start_btn.add_theme_font_size_override("font_size", 22)
	lobby_start_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	lobby_start_btn.disabled = true
	lobby_start_btn.pressed.connect(_on_lobby_start_pressed)
	_style_button(lobby_start_btn, Color(0.15, 0.45, 0.2))
	lobby_center.add_child(lobby_start_btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(150, 45)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back_btn.offset_top = -60
	back_btn.offset_left = -75
	back_btn.offset_right = 75
	back_btn.offset_bottom = -15
	back_btn.pressed.connect(_on_lobby_back_pressed)
	_style_button(back_btn, Color(0.3, 0.2, 0.2))
	lobby_panel.add_child(back_btn)


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


func _build_building_info_panel(root: Control):
	building_info_panel = PanelContainer.new()
	building_info_panel.visible = false
	building_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.set_corner_radius_all(6)
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	building_info_panel.add_theme_stylebox_override("panel", style)
	root.add_child(building_info_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	building_info_panel.add_child(vbox)

	building_info_label = Label.new()
	building_info_label.add_theme_font_size_override("font_size", 13)
	building_info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(building_info_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	toggle_power_btn = Button.new()
	toggle_power_btn.text = "Disable"
	toggle_power_btn.custom_minimum_size = Vector2(80, 32)
	toggle_power_btn.add_theme_font_size_override("font_size", 14)
	toggle_power_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	toggle_power_btn.pressed.connect(_on_toggle_power_pressed)
	btn_row.add_child(toggle_power_btn)

	recycle_btn = Button.new()
	recycle_btn.text = "Recycle"
	recycle_btn.custom_minimum_size = Vector2(100, 32)
	recycle_btn.add_theme_font_size_override("font_size", 14)
	recycle_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	recycle_btn.pressed.connect(_on_recycle_pressed)
	btn_row.add_child(recycle_btn)


func _build_loading_panel(root: Control):
	loading_panel = Control.new()
	loading_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_panel.visible = false
	loading_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(loading_panel)

	# Dark background overlay
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.07, 0.06, 0.95)
	loading_panel.add_child(bg)

	# Centered container
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -150
	center.offset_right = 150
	center.offset_top = -40
	center.offset_bottom = 40
	center.add_theme_constant_override("separation", 12)
	loading_panel.add_child(center)

	loading_label = Label.new()
	loading_label.text = "Loading..."
	loading_label.add_theme_font_size_override("font_size", 18)
	loading_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(loading_label)

	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(300, 16)
	bar_bg.color = Color(0.15, 0.15, 0.2)
	center.add_child(bar_bg)

	loading_bar_fill = ColorRect.new()
	loading_bar_fill.color = Color(0.3, 0.7, 1.0)
	loading_bar_fill.position = Vector2.ZERO
	loading_bar_fill.size = Vector2(0, 16)
	bar_bg.add_child(loading_bar_fill)


func show_loading(text: String, progress: float):
	if loading_panel:
		loading_panel.visible = true
		loading_label.text = text
		loading_bar_fill.size.x = 300.0 * clampf(progress, 0.0, 1.0)


func hide_loading():
	if loading_panel:
		loading_panel.visible = false


func _build_disconnect_panel(root: Control):
	disconnect_panel = Control.new()
	disconnect_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	disconnect_panel.visible = false
	disconnect_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(disconnect_panel)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.02, 0.02, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	disconnect_panel.add_child(bg)

	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -180; center.offset_right = 180
	center.offset_top = -80; center.offset_bottom = 80
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	disconnect_panel.add_child(center)

	var title = Label.new()
	title.text = "Connection Lost"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var msg = Label.new()
	msg.text = "The host has disconnected."
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(msg)

	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(180, 45)
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.pressed.connect(func(): get_tree().reload_current_scene())
	center.add_child(quit_btn)


func show_disconnect_panel():
	if disconnect_panel:
		disconnect_panel.visible = true


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

	# Build confirm/cancel buttons (shown only in build mode, positioned relative to ghost)
	build_confirm_panel = HBoxContainer.new()
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
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	var green_style = StyleBoxFlat.new()
	green_style.bg_color = Color(0.15, 0.55, 0.2)
	green_style.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("normal", green_style)
	var green_hover = StyleBoxFlat.new()
	green_hover.bg_color = Color(0.2, 0.65, 0.25)
	green_hover.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("hover", green_hover)
	var green_pressed = StyleBoxFlat.new()
	green_pressed.bg_color = Color(0.1, 0.45, 0.15)
	green_pressed.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("pressed", green_pressed)
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
	if gameplay_hud:
		gameplay_hud.visible = true
	get_tree().paused = false
	game_started.emit(wave)


func _on_debug_toggle():
	var panel = start_menu.get_node("DebugPanel")
	panel.visible = not panel.visible


func _on_debug_overlay_toggle():
	debug_overlay.visible = not debug_overlay.visible
	WebDebug.set_visible(debug_overlay.visible)


func _update_debug_overlay():
	var lines: Array = []
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	lines.append("Aliens: %d" % get_tree().get_nodes_in_group("aliens").size())
	lines.append("Buildings: %d" % get_tree().get_nodes_in_group("buildings").size())
	lines.append("Resources: %d" % get_tree().get_nodes_in_group("resources").size())
	lines.append("Bullets: %d" % get_tree().get_nodes_in_group("bullets").size())
	var main = get_tree().current_scene
	if main:
		lines.append("Wave: %d | Active: %s" % [main.wave_number, str(main.wave_active)])
		lines.append("Power: %s | Gen: %.0f | Use: %.0f" % ["ON" if main.power_on else "OFF", main.total_power_gen, main.total_power_consumption])
		lines.append("Bank: %.0f / %.0f" % [main.power_bank, main.max_power_bank])
	if NetworkManager.is_multiplayer_active():
		lines.append("Network: Connected | Host: %s" % str(NetworkManager.is_host()))
		lines.append("Players: %d" % NetworkManager.get_player_count())
	else:
		lines.append("Network: Offline")
	debug_overlay.text = "\n".join(lines)


func _on_debug_prestige(amount: int):
	GameData.add_prestige(amount)
	_update_start_menu()


func _on_reset_progress():
	GameData.prestige_points = 0
	GameData.highest_wave = 0
	GameData.total_bosses_killed = 0
	GameData.total_runs = 0
	GameData.unlocked_start_waves = [1]
	GameData.player_name = ""
	for key in GameData.research.keys():
		GameData.research[key] = 0
	GameData.save_data()
	lobby_name_input.text = ""
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
	if main.has_method("_end_run"):
		main._end_run()


func _on_open_settings():
	_settings_from_pause = true
	pause_menu.visible = false
	settings_panel.visible = true
	_sync_settings_buttons()


func _on_open_settings_from_menu():
	_settings_from_pause = false
	start_menu.visible = false
	settings_panel.visible = true
	_sync_settings_buttons()


func _on_settings_back():
	settings_panel.visible = false
	if _settings_from_pause:
		pause_menu.visible = true
	else:
		start_menu.visible = true


func _on_toggle_auto_fire():
	var main = get_tree().current_scene
	var player = main.player_node if "player_node" in main else null
	if is_instance_valid(player):
		player.auto_fire = not player.auto_fire
	else:
		# Toggle a default that will be applied when player spawns
		auto_fire_btn.text = "Auto Fire: OFF" if auto_fire_btn.text == "Auto Fire: ON" else "Auto Fire: ON"
		return
	auto_fire_btn.text = "Auto Fire: ON" if player.auto_fire else "Auto Fire: OFF"


func _on_toggle_auto_aim():
	var main = get_tree().current_scene
	var player = main.player_node if "player_node" in main else null
	if is_instance_valid(player):
		player.auto_aim = not player.auto_aim
	else:
		auto_aim_btn.text = "Auto Aim: OFF" if auto_aim_btn.text == "Auto Aim: ON" else "Auto Aim: ON"
		return
	auto_aim_btn.text = "Auto Aim: ON" if player.auto_aim else "Auto Aim: OFF"


func _copy_to_clipboard(text: String):
	if OS.has_feature("web"):
		# Use temporary textarea + execCommand for maximum browser compatibility
		var safe = text.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("(function(){var t=document.createElement('textarea');t.value='%s';t.style.position='fixed';t.style.left='-9999px';document.body.appendChild(t);t.select();document.execCommand('copy');document.body.removeChild(t)})()" % safe)
	else:
		DisplayServer.clipboard_set(text)


func _on_copy_lobby_code():
	var code = lobby_code_label.text
	if code != "------" and code != "..." and code != "Copied!":
		_copy_to_clipboard(code)
		lobby_code_label.text = "Copied!"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(lobby_code_label):
				lobby_code_label.text = code
		)


func _on_copy_room_code():
	if NetworkManager.room_id != "":
		_copy_to_clipboard(NetworkManager.room_id)
		room_code_label.text = "Copied!"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(room_code_label) and NetworkManager.room_id != "":
				room_code_label.text = "Room: %s" % NetworkManager.room_id
		)


func _on_start_wave_pressed():
	var main = get_tree().current_scene
	if "wave_timer" in main:
		main.wave_timer = 0.0
	if start_wave_btn:
		start_wave_btn.visible = false


func _sync_settings_buttons():
	var main = get_tree().current_scene
	var player = main.player_node if "player_node" in main else null
	if is_instance_valid(player) and is_instance_valid(auto_fire_btn):
		auto_fire_btn.text = "Auto Fire: ON" if player.auto_fire else "Auto Fire: OFF"
		auto_aim_btn.text = "Auto Aim: ON" if player.auto_aim else "Auto Aim: OFF"


func toggle_pause():
	if not _game_started or death_panel.visible or upgrade_panel.visible:
		return
	# If settings panel is open, go back instead of toggling pause
	if settings_panel.visible:
		_on_settings_back()
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


func show_death_screen(wave: int, bosses: int, prestige_earned: int = 0, prestige_total: int = 0):
	death_stats_label.text = "Survived %d waves | Bosses killed: %d" % [wave, bosses]
	if prestige_earned > 0:
		prestige_label.text = "Prestige Earned: +%d  (Total: %d)" % [prestige_earned, prestige_total]
	else:
		prestige_label.text = "Prestige Points: %d" % prestige_total
	death_panel.visible = true


func _unhandled_input(event: InputEvent):
	if not _game_started or get_tree().paused:
		return

	# Mobile touch input
	if is_mobile and event is InputEventScreenTouch and event.pressed:
		var player = _get_player()
		if not player:
			return
		if player.is_in_build_mode():
			# Tap sets the pending build position on mobile
			var world_pos = _screen_to_world(event.position)
			if world_pos != null:
				player.pending_build_world_pos = world_pos.snapped(Vector3(40, 0, 40))
		else:
			# Check for building selection (recycle / tooltip)
			_handle_building_tap(event.position)

	# Desktop mouse click for building selection when not in build mode
	if not is_mobile and event is InputEventMouseButton and event.pressed:
		var player = _get_player()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if player and not player.is_in_build_mode():
				_handle_building_tap(event.position)


func _screen_to_world(screen_pos: Vector2):
	var main = get_tree().current_scene
	if not "camera_3d" in main or not is_instance_valid(main.camera_3d):
		return null
	var cam = main.camera_3d
	var from = cam.project_ray_origin(screen_pos)
	var dir = cam.project_ray_normal(screen_pos)
	if dir.y != 0:
		var t = -from.y / dir.y
		if t > 0:
			var hit = from + dir * t
			return Vector3(hit.x, 0, hit.z)
	return null


func _world_to_screen(world_pos: Vector3) -> Vector2:
	var main = get_tree().current_scene
	if "camera_3d" in main and is_instance_valid(main.camera_3d):
		return main.camera_3d.unproject_position(world_pos)
	return Vector2.ZERO


func _handle_building_tap(screen_pos: Vector2):
	var world_pos = _screen_to_world(screen_pos)
	if world_pos == null:
		selected_building = null
		return

	var closest_building: Node3D = null
	var closest_dist = 50.0  # Larger detection radius for touch

	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		var dist = world_pos.distance_to(b.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_building = b

	selected_building = closest_building


func _get_player() -> Node3D:
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


func _on_recycle_pressed():
	var player = _get_player()
	if player and selected_building and is_instance_valid(selected_building):
		var pos = selected_building.global_position
		var value = player.get_recycle_value(selected_building)
		get_tree().current_scene.recycle_building(selected_building)
		_spawn_recycle_popup(pos, value)
		selected_building = null
		building_info_panel.visible = false


func _on_toggle_power_pressed():
	if not selected_building or not is_instance_valid(selected_building):
		return
	if "manually_disabled" not in selected_building:
		return
	selected_building.manually_disabled = not selected_building.manually_disabled
	if NetworkManager.is_multiplayer_active():
		get_tree().current_scene.sync_building_toggle(selected_building)


func _spawn_recycle_popup(pos: Vector3, value: Dictionary):
	var popup = preload("res://scenes/popup_text.tscn").instantiate()
	popup.global_position = pos + Vector3(0, 30, 0)
	popup.text = "+%dI +%dC" % [value["iron"], value["crystal"]]
	popup.color = Color(1.0, 0.6, 0.2)
	get_tree().current_scene.game_world_2d.add_child(popup)


func _update_building_info_panel():
	if not _game_started or get_tree().paused:
		if building_info_panel:
			building_info_panel.visible = false
		return

	var player = _get_player()
	if not player:
		if building_info_panel:
			building_info_panel.visible = false
		return

	if player.is_in_build_mode():
		if building_info_panel:
			building_info_panel.visible = false
		return

	if selected_building == null or not is_instance_valid(selected_building):
		selected_building = null
		if building_info_panel:
			building_info_panel.visible = false
		return

	var screen_pos = _world_to_screen(selected_building.global_position)
	if screen_pos == Vector2.ZERO:
		if building_info_panel:
			building_info_panel.visible = false
		return

	# Build info text
	var bname = selected_building.get_building_name() if selected_building.has_method("get_building_name") else "Building"
	var info = bname
	if "hp" in selected_building and "max_hp" in selected_building:
		info += "\nHP: %d/%d" % [selected_building.hp, selected_building.max_hp]
	# Power status
	if selected_building.has_method("is_powered"):
		if "manually_disabled" in selected_building and selected_building.manually_disabled:
			info += "\nPower: Disabled"
		elif selected_building.is_powered():
			info += "\nPower: On"
		else:
			info += "\nPower: Off"
	# Power consumption/generation
	var power_info = _get_building_power_info(bname)
	if power_info != "":
		info += "\nEnergy: " + power_info
	building_info_label.text = info

	# Toggle power button: only for buildings with manually_disabled
	var has_toggle = "manually_disabled" in selected_building
	toggle_power_btn.visible = has_toggle
	if has_toggle:
		toggle_power_btn.text = "Enable" if selected_building.manually_disabled else "Disable"

	# Recycle button: hide for HQ, show refund for others
	var is_hq = selected_building.is_in_group("hq")
	recycle_btn.visible = not is_hq
	if not is_hq:
		var value = player.get_recycle_value(selected_building)
		recycle_btn.text = "Recycle (+%dI +%dC)" % [value["iron"], value["crystal"]]

	building_info_panel.reset_size()
	building_info_panel.visible = true
	var panel_size = building_info_panel.get_combined_minimum_size()
	building_info_panel.position = Vector2(screen_pos.x - panel_size.x / 2.0, screen_pos.y - panel_size.y - 40)
	var vp_size = get_viewport().get_visible_rect().size
	building_info_panel.position.x = clampf(building_info_panel.position.x, 5, vp_size.x - panel_size.x - 5)
	building_info_panel.position.y = clampf(building_info_panel.position.y, 5, vp_size.y - panel_size.y - 5)


func _process(delta):
	if alert_timer > 0:
		alert_timer -= delta
		alert_label.modulate.a = clampf(alert_timer / 1.5, 0.0, 1.0)
		if alert_timer <= 0:
			alert_label.visible = false

	# Toggle mobile build confirm buttons and position relative to ghost preview
	if is_mobile and build_confirm_panel:
		var player = _get_player()
		var in_build = player != null and player.is_in_build_mode()
		build_confirm_panel.visible = in_build
		if in_build and player:
			var valid = player.can_place_at(player.pending_build_world_pos) and player.can_afford(player.build_mode)
			confirm_btn.disabled = not valid
			if player.pending_build_world_pos != Vector3.ZERO:
				var screen_pos = _world_to_screen(player.pending_build_world_pos)
				var vp_size = get_viewport().get_visible_rect().size
				var panel_w = build_confirm_panel.size.x
				var panel_h = build_confirm_panel.size.y
				build_confirm_panel.position = Vector2(screen_pos.x - panel_w / 2.0, screen_pos.y + 40)
				build_confirm_panel.position.x = clampf(build_confirm_panel.position.x, 5, vp_size.x - panel_w - 5)
				build_confirm_panel.position.y = clampf(build_confirm_panel.position.y, 5, vp_size.y - panel_h - 5)

	# Update building info panel
	_update_building_info_panel()

	# Update building tooltip
	_update_building_tooltip()

	# Update debug overlay
	if debug_overlay.visible:
		_update_debug_overlay()


func _update_building_tooltip():
	if not _game_started or get_tree().paused:
		building_tooltip.visible = false
		return

	# Hide tooltip when building info panel is showing
	if building_info_panel and building_info_panel.visible:
		building_tooltip.visible = false
		return

	if is_mobile:
		_update_building_tooltip_mobile()
	else:
		_update_building_tooltip_desktop()


func _update_building_tooltip_desktop():
	var mouse_screen = get_viewport().get_mouse_position()
	var mouse_world = _screen_to_world(mouse_screen)
	if mouse_world == null:
		building_tooltip.visible = false
		return

	# Find building under mouse
	var closest_building: Node3D = null
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


func _update_building_tooltip_mobile():
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

	var screen_pos = _world_to_screen(selected_building.global_position)
	building_tooltip_label.text = _get_building_info_text(selected_building)
	building_tooltip.visible = true
	building_tooltip.position = screen_pos + Vector2(15, -60)
	# Clamp tooltip to screen
	var ts = building_tooltip.size
	building_tooltip.position.x = clampf(building_tooltip.position.x, 5, vp_size.x - ts.x - 5)
	building_tooltip.position.y = clampf(building_tooltip.position.y, 5, vp_size.y - ts.y - 5)


func _get_building_info_text(b: Node3D) -> String:
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
		"Repair Drone":
			lines.append("Repairs buildings | Range: 150")
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
		"repair_drone":
			return "Repair Drone\nRepairs nearby buildings\nRequires power\n" + cost_text
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
	icon.hovered.connect(_on_build_icon_hovered)
	icon.unhovered.connect(_on_build_icon_unhovered)
	parent.add_child(icon)

	return {"icon": icon, "type": build_type, "name": display_name}


func _get_power_info(build_type: String) -> String:
	match build_type:
		"power_plant": return "+%.0f" % CFG.power_plant_gen
		"turret": return "-%.0f" % CFG.power_turret
		"factory": return "-%.0f" % CFG.power_factory
		"lightning": return "-%.0f" % CFG.power_lightning
		"slow": return "-%.0f" % CFG.power_slow
		"pylon": return "-%.0f" % CFG.power_pylon
		"flame_turret": return "-%.0f" % CFG.power_flame_turret
		"acid_turret": return "-%.0f" % CFG.power_acid_turret
		"repair_drone": return "-%.0f" % CFG.power_repair_drone
		"poison_turret": return "-%.0f" % CFG.power_poison_turret
	return ""


func _get_building_power_info(bname: String) -> String:
	match bname:
		"Power Plant": return "+%.0f" % CFG.power_plant_gen
		"HQ": return "+%.0f" % CFG.hq_power_gen
		"Turret": return "-%.0f" % CFG.power_turret
		"Factory": return "-%.0f" % CFG.power_factory
		"Lightning Tower": return "-%.0f" % CFG.power_lightning
		"Slow Tower": return "-%.0f" % CFG.power_slow
		"Pylon": return "-%.0f" % CFG.power_pylon
		"Flame Turret": return "-%.0f" % CFG.power_flame_turret
		"Acid Turret": return "-%.0f" % CFG.power_acid_turret
		"Repair Drone": return "-%.0f" % CFG.power_repair_drone
		"Poison Turret": return "-%.0f" % CFG.power_poison_turret
	return ""


func _on_build_icon_hovered(icon) -> void:
	_hovered_build_icon = icon
	if not is_instance_valid(build_bar_tooltip):
		return
	build_bar_tooltip_name.text = icon.display_name
	build_bar_tooltip_desc.text = BUILD_DESCRIPTIONS.get(icon.build_type, "")

	# Get player resources for affordability coloring
	var player_iron := 999999
	var player_crystal := 999999
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.is_local:
			player_iron = p.iron
			player_crystal = p.crystal
			break

	if icon.iron_cost > 0:
		build_bar_tooltip_iron.text = "%dI" % icon.iron_cost
		build_bar_tooltip_iron.add_theme_color_override("font_color",
			Color(0.9, 0.75, 0.4) if player_iron >= icon.iron_cost else Color(1.0, 0.3, 0.3))
		build_bar_tooltip_iron.visible = true
	else:
		build_bar_tooltip_iron.visible = false

	if icon.crystal_cost > 0:
		build_bar_tooltip_crystal.text = "%dC" % icon.crystal_cost
		build_bar_tooltip_crystal.add_theme_color_override("font_color",
			Color(0.4, 0.7, 1.0) if player_crystal >= icon.crystal_cost else Color(1.0, 0.3, 0.3))
		build_bar_tooltip_crystal.visible = true
	else:
		build_bar_tooltip_crystal.visible = false

	var power_text = _get_power_info(icon.build_type)
	if power_text != "":
		build_bar_tooltip_power.text = power_text + "E"
		build_bar_tooltip_power.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		build_bar_tooltip_power.visible = true
	else:
		build_bar_tooltip_power.visible = false

	# Position above the icon
	var icon_rect = icon.get_global_rect()
	build_bar_tooltip.reset_size()
	build_bar_tooltip.visible = true
	var tt_size = build_bar_tooltip.get_combined_minimum_size()
	build_bar_tooltip.global_position = Vector2(
		icon_rect.position.x + icon_rect.size.x / 2.0 - tt_size.x / 2.0,
		icon_rect.position.y - tt_size.y - 4)


func _on_build_icon_unhovered() -> void:
	_hovered_build_icon = null
	if is_instance_valid(build_bar_tooltip):
		build_bar_tooltip.visible = false


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


func _style_button(btn: Button, color: Color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12; normal.content_margin_right = 12
	normal.content_margin_top = 8; normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style = normal.duplicate()
	pressed_style.bg_color = color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	var disabled_style = normal.duplicate()
	disabled_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	btn.add_theme_stylebox_override("disabled", disabled_style)


func update_hud(player: Node3D, wave_timer: float, wave_number: int, wave_active: bool = false, power_gen: float = 0.0, power_cons: float = 0.0, _power_on: bool = true, rates: Dictionary = {}, power_bank: float = 0.0, max_power_bank: float = 0.0, prestige_earned: int = 0):
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
		if start_wave_btn:
			start_wave_btn.visible = false
	else:
		var m = int(wave_timer) / 60
		var sec = int(wave_timer) % 60
		timer_label.text = "Next wave: %d:%02d" % [m, sec]
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		if start_wave_btn:
			var main = get_tree().current_scene
			start_wave_btn.visible = "is_first_wave" in main and main.is_first_wave

	if player.xp_to_next > 0:
		xp_bar_fill.size.x = 170.0 * float(player.xp) / float(player.xp_to_next)
	else:
		xp_bar_fill.size.x = 170.0

	var ac = get_tree().get_nodes_in_group("aliens").size()
	alien_count_label.text = "Aliens: %d" % ac
	alien_count_label.visible = ac > 0

	# HQ health display
	var hq_nodes = get_tree().get_nodes_in_group("hq")
	if hq_nodes.size() > 0 and is_instance_valid(hq_nodes[0]):
		var hq = hq_nodes[0]
		hq_panel.visible = true
		hq_health_label.text = "HQ: %d / %d" % [hq.hp, hq.max_hp]
		var hp_ratio = float(hq.hp) / float(hq.max_hp)
		hq_bar_fill.size.x = 170.0 * hp_ratio
		if hp_ratio < 0.25:
			# Critical - fast flash red
			var flash = 0.5 + sin(Time.get_ticks_msec() * 0.01) * 0.5
			hq_bar_fill.color = Color(1.0, 0.1, 0.1)
			hq_health_label.add_theme_color_override("font_color", Color(1.0, 0.2 + flash * 0.3, 0.2))
		elif hp_ratio < 0.5:
			# Warning - slow flash orange
			var flash = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.5
			hq_bar_fill.color = Color(1.0, 0.5, 0.1)
			hq_health_label.add_theme_color_override("font_color", Color(1.0, 0.6 + flash * 0.2, 0.2))
		else:
			hq_bar_fill.color = Color(0.3, 0.8, 1.0)
			hq_health_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	else:
		hq_panel.visible = false

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
	prestige_hud_label.text = "Prestige: %d" % prestige_earned

	# Partner health in MP (up to 3 other players)
	if NetworkManager.is_multiplayer_active():
		var partners: Array = []
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p != player:
				partners.append(p)
		for i in range(partner_panels.size()):
			if i < partners.size():
				var partner = partners[i]
				var pi = partner_panels[i]
				pi["panel"].visible = true
				var display_name = partner.player_name if partner.player_name != "" else ("Host" if partner.peer_id == 1 else "P%d" % partner.peer_id)
				if partner.is_dead:
					pi["label"].text = "%s: DEAD" % display_name
					pi["label"].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				else:
					pi["label"].text = "%s HP: %d/%d" % [display_name, partner.health, partner.max_health]
					pi["label"].add_theme_color_override("font_color", partner.player_color)
			else:
				partner_panels[i]["panel"].visible = false
	else:
		for pi in partner_panels:
			pi["panel"].visible = false

	# Respawn countdown
	if player.is_dead and respawn_countdown > 0 and NetworkManager.is_multiplayer_active():
		respawn_label.text = "Respawning in %d..." % ceili(respawn_countdown)
		respawn_label.visible = true
	else:
		respawn_label.visible = false

	# Room code display in MP
	if NetworkManager.is_multiplayer_active() and NetworkManager.room_id != "":
		room_code_label.text = "Room: %s" % NetworkManager.room_id
		room_code_label.get_parent().visible = true
	else:
		room_code_label.get_parent().visible = false

	# Update building costs dynamically
	_update_build_costs(player)


func _update_build_costs(player: Node3D):
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
			"battery":
				info["icon"].locked = GameData.get_research_bonus("unlock_battery") < 1.0
			"repair_drone":
				info["icon"].locked = GameData.get_research_bonus("unlock_repair_drone") < 1.0
			"poison_turret":
				info["icon"].locked = GameData.get_research_bonus("turret_poison") < 1.0
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
	var p = _get_player()
	if p:
		p.cancel_build_mode()
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
		"pickup_range": return "+15 pickup range (+%dpx total)" % (lv * 15)
	return ""


func _on_card_click(event: InputEvent, idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var key = card_info[idx]["key"]
		if key == "":
			return
		if NetworkManager.is_multiplayer_active():
			_local_vote_key = key
			# Highlight the selected card
			for i in range(card_info.size()):
				var ci = card_info[i]
				if not ci["panel"].visible:
					continue
				var data = UPGRADE_DATA.get(ci["key"], {})
				var base_color = data.get("color", Color(0.4, 0.4, 0.5))
				if ci["key"] == key:
					ci["panel"].add_theme_stylebox_override("panel", _make_card_style(Color(1.0, 0.9, 0.3)))
				else:
					ci["panel"].add_theme_stylebox_override("panel", _make_card_style(base_color.lerp(Color.WHITE, 0.2)))
			upgrade_chosen.emit(key)
		else:
			upgrade_panel.visible = false
			_upgrade_showing = false
			upgrade_chosen.emit(key)


# --- Co-op Lobby ---

func start_mp_game():
	_disconnect_network_signals()
	lobby_panel.visible = false
	_game_started = true
	if gameplay_hud:
		gameplay_hud.visible = true


func _on_host_coop_pressed():
	start_menu.visible = false
	lobby_panel.visible = true
	lobby_host_section.visible = true
	lobby_client_section.visible = false
	lobby_start_btn.visible = true
	lobby_start_btn.disabled = true
	if lobby_name_input.text.strip_edges() == "":
		lobby_name_input.grab_focus()
	lobby_code_label.text = "..."
	lobby_status_label.text = "Creating room..."
	lobby_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_connect_network_signals()
	var code = await NetworkManager.create_room()
	if code == "":
		lobby_status_label.text = "Failed to create room - check console (F12)"
		lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	else:
		lobby_code_label.text = code
		lobby_status_label.text = "Waiting for players..."


func _on_join_coop_pressed():
	start_menu.visible = false
	lobby_panel.visible = true
	lobby_host_section.visible = false
	lobby_client_section.visible = true
	lobby_start_btn.visible = false
	lobby_code_input.text = ""
	lobby_status_label.text = ""
	lobby_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_connect_network_signals()
	if lobby_name_input.text.strip_edges() == "":
		lobby_name_input.grab_focus()
	else:
		lobby_code_input.grab_focus()


func _on_lobby_name_changed(new_text: String):
	var pname = new_text.strip_edges()
	if pname == "":
		return
	local_player_name = pname
	GameData.player_name = pname
	if NetworkManager.is_multiplayer_active():
		get_tree().current_scene.send_player_name(pname)


func _on_lobby_input_focused(line_edit: LineEdit):
	if is_mobile and OS.has_feature("web"):
		DisplayServer.virtual_keyboard_show(line_edit.text)


func _on_lobby_input_unfocused():
	if is_mobile and OS.has_feature("web"):
		DisplayServer.virtual_keyboard_hide()


func _on_lobby_code_text_submitted(_text: String):
	if is_mobile and OS.has_feature("web"):
		DisplayServer.virtual_keyboard_hide()
	_on_lobby_connect_pressed()


func _on_lobby_connect_pressed():
	var code = lobby_code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		lobby_status_label.text = "Code too short"
		lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		return
	lobby_connect_btn.disabled = true
	lobby_status_label.text = "Connecting..."
	lobby_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	NetworkManager.join_room(code)


func _on_lobby_start_pressed():
	local_player_name = lobby_name_input.text.strip_edges()
	if local_player_name == "":
		local_player_name = "Host"
	GameData.player_name = local_player_name
	GameData.save_data()
	_disconnect_network_signals()
	lobby_panel.visible = false
	_game_started = true
	if gameplay_hud:
		gameplay_hud.visible = true
	get_tree().paused = false
	game_started.emit(1)  # MP games start at wave 1


func _on_lobby_back_pressed():
	NetworkManager.disconnect_peer()
	_disconnect_network_signals()
	lobby_panel.visible = false
	lobby_connect_btn.disabled = false
	start_menu.visible = true
	_update_start_menu()


func _connect_network_signals():
	if not NetworkManager.connection_established.is_connected(_on_network_connected):
		NetworkManager.connection_established.connect(_on_network_connected)
	if not NetworkManager.connection_failed.is_connected(_on_network_failed):
		NetworkManager.connection_failed.connect(_on_network_failed)
	if not NetworkManager.peer_connected.is_connected(_on_network_peer_connected):
		NetworkManager.peer_connected.connect(_on_network_peer_connected)
	if not NetworkManager.peer_disconnected.is_connected(_on_network_peer_disconnected):
		NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)


func _disconnect_network_signals():
	if NetworkManager.connection_established.is_connected(_on_network_connected):
		NetworkManager.connection_established.disconnect(_on_network_connected)
	if NetworkManager.connection_failed.is_connected(_on_network_failed):
		NetworkManager.connection_failed.disconnect(_on_network_failed)
	if NetworkManager.peer_connected.is_connected(_on_network_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_network_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_network_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_network_peer_disconnected)


func _on_network_connected():
	lobby_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	var count = NetworkManager.get_player_count()
	if NetworkManager.role == NetworkManager.NetRole.HOST:
		lobby_status_label.text = "%d player(s) connected" % count
		lobby_start_btn.disabled = false
	else:
		lobby_status_label.text = "Connected! (%d players) Waiting for host..." % count
	# Send name to host and persist
	var pname = lobby_name_input.text.strip_edges()
	if pname == "":
		pname = "Player"
	local_player_name = pname
	GameData.player_name = pname
	GameData.save_data()
	get_tree().current_scene.send_player_name(pname)


func _on_network_peer_connected(_id: int):
	if lobby_panel.visible:
		var count = NetworkManager.get_player_count()
		if NetworkManager.role == NetworkManager.NetRole.HOST:
			lobby_status_label.text = "%d player(s) connected" % count
			lobby_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		else:
			lobby_status_label.text = "Connected! (%d players) Waiting for host..." % count


func _on_network_failed(reason: String):
	lobby_status_label.text = "Failed: " + reason
	lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	lobby_connect_btn.disabled = false


func _on_network_peer_disconnected(_id: int):
	if lobby_panel.visible:
		var count = NetworkManager.get_player_count()
		if count <= 1:
			lobby_status_label.text = "All players disconnected"
			lobby_start_btn.disabled = true
		else:
			lobby_status_label.text = "%d player(s) connected" % count
		lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))


func update_lobby_player_list(names: Dictionary):
	var lines: Array = []
	for pid in names:
		lines.append(names[pid])
	if lines.size() > 0:
		lobby_players_label.text = "Players: " + ", ".join(lines)
	else:
		lobby_players_label.text = ""


# --- Upgrade Voting ---

func show_vote_selection(keys: Array, current_upgrades: Dictionary, votes: Dictionary, _all_players: Dictionary, _names: Dictionary):
	var p = _get_player()
	if p:
		p.cancel_build_mode()
	_local_vote_key = ""

	for i in range(3):
		if i < keys.size():
			var key = keys[i]
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

	update_vote_display(votes, _all_players, _names)

	upgrade_panel.visible = true
	_upgrade_showing = true
	vote_status_label.text = "Vote for an upgrade (must be unanimous)"
	vote_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vote_status_label.visible = true


func update_vote_display(votes: Dictionary, _all_players: Dictionary, names: Dictionary):
	if not _upgrade_showing:
		return
	var total_players = _all_players.size()
	for i in range(3):
		var ci = card_info[i]
		if not ci["panel"].visible:
			continue
		var key = ci["key"]
		var voter_names: Array = []
		var vote_count = 0
		for pid in votes:
			if votes[pid] == key:
				vote_count += 1
				var pname = names.get(pid, "P%d" % pid)
				voter_names.append(pname)

		ci["vote_count_lbl"].visible = true
		ci["vote_count_lbl"].text = "%d/%d votes" % [vote_count, total_players]
		ci["voters_lbl"].visible = voter_names.size() > 0
		ci["voters_lbl"].text = ", ".join(voter_names)


func hide_vote_panel(_chosen_key: String):
	upgrade_panel.visible = false
	_upgrade_showing = false
	_local_vote_key = ""
	vote_status_label.visible = false
	for ci in card_info:
		ci["vote_count_lbl"].visible = false
		ci["voters_lbl"].visible = false


