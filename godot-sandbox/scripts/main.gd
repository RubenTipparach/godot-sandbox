extends Node2D

const CFG = preload("res://resources/game_config.tres")

var wave_number: int = 0
var wave_timer: float = CFG.first_wave_delay
var wave_active: bool = false
var game_over: bool = false
var resource_regen_timer: float = CFG.resource_regen_interval
var powerup_timer: float = 10.0
var pending_upgrades: int = 0
var upgrade_cooldown: float = 0.0
var bosses_killed: int = 0
var starting_wave: int = 1
var next_wave_direction: float = 0.0  # Angle for next wave spawn

# Global power system
var total_power_gen: float = 0.0
var total_power_consumption: float = 0.0
var power_bank: float = 0.0
var max_power_bank: float = 0.0
var power_on: bool = true


func get_max_resources() -> int:
	# More rocks spawn as waves progress
	return CFG.base_max_resources + wave_number * CFG.resources_per_wave


func get_regen_interval() -> float:
	var base = CFG.resource_regen_interval
	if is_instance_valid(player_node):
		base /= player_node.get_rock_regen_multiplier()
	return base


func _update_power_system(delta):
	# Calculate generation (HQ=10, Power Plant=40)
	var hq_count = get_tree().get_nodes_in_group("hq").size()
	var all_plants = get_tree().get_nodes_in_group("power_plants").size()
	var plant_count = all_plants - hq_count  # HQ is also in power_plants group
	total_power_gen = hq_count * CFG.hq_power_gen + plant_count * CFG.power_plant_gen

	# Calculate consumption
	var turret_count = get_tree().get_nodes_in_group("turrets").size()
	var factory_count = get_tree().get_nodes_in_group("factories").size()
	var lightning_count = get_tree().get_nodes_in_group("lightnings").size()
	var slow_count = get_tree().get_nodes_in_group("slows").size()
	var pylon_count = get_tree().get_nodes_in_group("pylons").size()
	var flame_count = get_tree().get_nodes_in_group("flame_turrets").size()
	var acid_count = get_tree().get_nodes_in_group("acid_turrets").size()
	total_power_consumption = turret_count * CFG.power_turret + factory_count * CFG.power_factory + lightning_count * CFG.power_lightning + slow_count * CFG.power_slow + pylon_count * CFG.power_pylon + flame_count * CFG.power_flame_turret + acid_count * CFG.power_acid_turret

	# Calculate energy storage capacity (HQ = 200 base, each battery = 50)
	var battery_count = get_tree().get_nodes_in_group("batteries").size()
	max_power_bank = hq_count * CFG.hq_energy_storage + battery_count * CFG.battery_energy_storage

	if total_power_gen >= total_power_consumption:
		power_on = true
		# Store surplus in bank
		if max_power_bank > 0:
			power_bank = minf(power_bank + (total_power_gen - total_power_consumption) * delta, max_power_bank)
	else:
		if max_power_bank > 0 and power_bank > 0:
			# Drain bank to cover deficit
			power_bank -= (total_power_consumption - total_power_gen) * delta
			if power_bank <= 0:
				power_bank = 0.0
				power_on = false
			else:
				power_on = true
		else:
			power_on = false


func get_factory_rates() -> Dictionary:
	var iron_per_sec = 0.0
	var crystal_per_sec = 0.0
	for f in get_tree().get_nodes_in_group("factories"):
		if not is_instance_valid(f):
			continue
		if f.is_powered():
			var interval = CFG.factory_generate_interval / (1.0 + f.speed_bonus)
			iron_per_sec += float(CFG.factory_iron_per_cycle) / interval
			crystal_per_sec += float(CFG.factory_crystal_per_cycle) / interval
	return {"iron": iron_per_sec, "crystal": crystal_per_sec}


var player_node: Node2D
var buildings_node: Node2D
var aliens_node: Node2D
var resources_node: Node2D
var powerups_node: Node2D
var hud_node: CanvasLayer
var hq_node: Node2D


func _ready():
	_setup_inputs()
	_create_world()


func _setup_inputs():
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("build_power_plant", KEY_1)
	_add_key_action("build_pylon", KEY_2)
	_add_key_action("build_factory", KEY_3)
	_add_key_action("build_turret", KEY_4)
	_add_key_action("build_wall", KEY_5)
	_add_key_action("build_lightning", KEY_6)
	_add_key_action("build_slow", KEY_7)
	_add_key_action("build_battery", KEY_8)
	_add_key_action("build_flame_turret", KEY_9)
	_add_key_action("build_acid_turret", KEY_0)
	_add_key_action("pause", KEY_ESCAPE)
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)


func _create_world():
	resources_node = Node2D.new()
	resources_node.name = "Resources"
	add_child(resources_node)

	powerups_node = Node2D.new()
	powerups_node.name = "Powerups"
	add_child(powerups_node)

	buildings_node = Node2D.new()
	buildings_node.name = "Buildings"
	add_child(buildings_node)

	# Spawn HQ at center - if destroyed, game over
	hq_node = preload("res://scenes/hq.tscn").instantiate()
	hq_node.global_position = Vector2.ZERO
	hq_node.destroyed.connect(_on_hq_destroyed)
	buildings_node.add_child(hq_node)

	var player_scene = preload("res://scenes/player.tscn")
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	add_child(player_node)
	player_node.level_up.connect(_on_player_level_up)

	aliens_node = Node2D.new()
	aliens_node.name = "Aliens"
	add_child(aliens_node)

	var hud_scene = preload("res://scenes/hud.tscn")
	hud_node = hud_scene.instantiate()
	add_child(hud_node)
	hud_node.upgrade_chosen.connect(_on_upgrade_chosen)
	hud_node.game_started.connect(_on_game_started)

	_spawn_resources()


func _spawn_resources():
	var resource_scene = preload("res://scenes/resource_node.tscn")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(22):
		var res = resource_scene.instantiate()
		res.position = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80, 700)
		res.resource_type = "iron"
		res.amount = rng.randi_range(8, 20)
		resources_node.add_child(res)
	for i in range(14):
		var res = resource_scene.instantiate()
		res.position = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250, 900)
		res.resource_type = "crystal"
		res.amount = rng.randi_range(5, 15)
		resources_node.add_child(res)


func _process(delta):
	if game_over:
		return

	_update_power_system(delta)

	var alien_count = get_tree().get_nodes_in_group("aliens").size()

	# Wave logic: countdown only when no aliens
	if wave_active:
		if alien_count == 0:
			wave_active = false
			pending_upgrades += 1
	else:
		wave_timer -= delta
		if wave_timer <= 0:
			wave_number += 1
			_spawn_wave()
			wave_timer = CFG.wave_interval
			wave_active = true

	resource_regen_timer -= delta
	if resource_regen_timer <= 0:
		resource_regen_timer = get_regen_interval()
		_regenerate_resources()

	powerup_timer -= delta
	if powerup_timer <= 0:
		powerup_timer = CFG.powerup_spawn_interval
		_spawn_powerup()

	upgrade_cooldown = maxf(0.0, upgrade_cooldown - delta)
	if pending_upgrades > 0 and upgrade_cooldown <= 0:
		_try_show_upgrade()

	if is_instance_valid(hud_node):
		var rates = get_factory_rates()
		var projected_prestige = wave_number / 2 + bosses_killed * 3
		hud_node.update_hud(player_node, wave_timer, wave_number, wave_active, total_power_gen, total_power_consumption, power_on, rates, power_bank, max_power_bank, projected_prestige)

	queue_redraw()


func _regenerate_resources():
	var current = get_tree().get_nodes_in_group("resources").size()
	var max_res = get_max_resources()
	if current >= max_res:
		return
	var resource_scene = preload("res://scenes/resource_node.tscn")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	# Spawn more rocks per cycle as waves progress
	var spawn_count = mini(5 + wave_number / 2, max_res - current)
	for i in range(spawn_count):
		var res = resource_scene.instantiate()
		res.position = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(100, CFG.map_half_size * 0.85)
		res.resource_type = "iron" if rng.randf() < 0.6 else "crystal"
		res.amount = rng.randi_range(5 + wave_number, 15 + wave_number * 2)
		resources_node.add_child(res)


func _spawn_powerup():
	var current = get_tree().get_nodes_in_group("powerups").size()
	if current >= CFG.max_powerups:
		return
	var powerup = preload("res://scenes/powerup.tscn").instantiate()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	powerup.position = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(150, CFG.map_half_size * 0.8)
	var types = ["magnet", "weapon_scroll", "heal", "nuke", "mining_boost"]
	powerup.powerup_type = types[rng.randi() % types.size()]
	powerups_node.add_child(powerup)


func _draw():
	var hs = CFG.map_half_size
	draw_rect(Rect2(-hs, -hs, hs * 2, hs * 2), Color(1, 0.3, 0.2, 0.3), false, 3.0)
	draw_rect(Rect2(-hs + 50, -hs + 50, (hs - 50) * 2, (hs - 50) * 2), Color(1, 0.3, 0.2, 0.08), false, 1.0)

	if not is_instance_valid(player_node):
		return
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var vp_size = get_viewport_rect().size / cam.zoom
	var center = cam.global_position
	var gs = 40.0
	var s = (center - vp_size / 2.0 - Vector2(gs, gs)).snapped(Vector2(gs, gs))
	var e = center + vp_size / 2.0 + Vector2(gs, gs)
	var gc = Color(1, 1, 1, 0.04)
	var x = s.x
	while x <= e.x:
		draw_line(Vector2(x, s.y), Vector2(x, e.y), gc)
		x += gs
	var y = s.y
	while y <= e.y:
		draw_line(Vector2(s.x, y), Vector2(e.x, y), gc)
		y += gs


func _spawn_wave():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Use the pre-determined direction for this wave
	var wave_dir = next_wave_direction

	# Pick direction for NEXT wave and tell HUD
	next_wave_direction = rng.randf() * TAU
	if is_instance_valid(hud_node):
		hud_node.set_wave_direction(next_wave_direction)

	# Slower scaling: fewer enemies early on
	var basic_count = 2 + wave_number
	_spawn_aliens("basic", basic_count, rng, wave_dir)
	if wave_number >= CFG.alien_fast_start_wave:
		_spawn_aliens("fast", maxi(1, wave_number - 3), rng, wave_dir)
	if wave_number >= CFG.alien_ranged_start_wave:
		_spawn_aliens("ranged", mini(wave_number - 5, CFG.alien_ranged_max_count), rng, wave_dir)
	if wave_number >= CFG.boss_start_wave and wave_number % CFG.boss_wave_interval == 0:
		_spawn_boss(rng, wave_dir)
	if is_instance_valid(hud_node):
		hud_node.show_wave_alert(wave_number, wave_number >= CFG.boss_start_wave and wave_number % CFG.boss_wave_interval == 0)


func _get_offscreen_spawn_pos(base_angle: float, rng: RandomNumberGenerator) -> Vector2:
	# Spawn far enough to be offscreen (at least 600 units from player)
	var spread = rng.randf_range(-0.4, 0.4)  # ~45 degree spread
	var angle = base_angle + spread
	var dist = rng.randf_range(650, 850)
	var spawn_pos = player_node.global_position + Vector2.from_angle(angle) * dist
	return spawn_pos.clamp(Vector2(-CFG.map_half_size, -CFG.map_half_size), Vector2(CFG.map_half_size, CFG.map_half_size))


func _spawn_aliens(type: String, count: int, rng: RandomNumberGenerator, wave_dir: float):
	for i in range(count):
		var spawn_pos = _get_offscreen_spawn_pos(wave_dir, rng)
		var alien: Node2D
		match type:
			"basic":
				alien = preload("res://scenes/alien.tscn").instantiate()
				alien.hp = CFG.alien_basic_base_hp + wave_number * CFG.alien_basic_hp_per_wave
				alien.max_hp = alien.hp
				alien.damage = CFG.alien_basic_base_damage + wave_number * CFG.alien_basic_damage_per_wave
				alien.speed = CFG.alien_basic_base_speed + wave_number * CFG.alien_basic_speed_per_wave
				alien.xp_value = CFG.alien_basic_xp
			"fast":
				alien = preload("res://scenes/alien.tscn").instantiate()
				alien.hp = CFG.alien_fast_base_hp + wave_number * CFG.alien_fast_hp_per_wave
				alien.max_hp = alien.hp
				alien.damage = CFG.alien_fast_base_damage + wave_number * CFG.alien_fast_damage_per_wave
				alien.speed = CFG.alien_fast_base_speed + wave_number * CFG.alien_fast_speed_per_wave
				alien.xp_value = CFG.alien_fast_xp
				alien.alien_type = "fast"
			"ranged":
				alien = preload("res://scenes/ranged_alien.tscn").instantiate()
				alien.hp = CFG.alien_ranged_base_hp + wave_number * CFG.alien_ranged_hp_per_wave
				alien.max_hp = alien.hp
				alien.damage = CFG.alien_ranged_base_damage + wave_number * CFG.alien_ranged_damage_per_wave
				alien.speed = CFG.alien_ranged_base_speed + wave_number * CFG.alien_ranged_speed_per_wave
				alien.xp_value = CFG.alien_ranged_xp
		alien.position = spawn_pos
		aliens_node.add_child(alien)


func _spawn_boss(rng: RandomNumberGenerator, wave_dir: float):
	var boss = preload("res://scenes/boss_alien.tscn").instantiate()
	boss.position = _get_offscreen_spawn_pos(wave_dir, rng)
	boss.hp = CFG.boss_base_hp + wave_number * CFG.boss_hp_per_wave
	boss.max_hp = boss.hp
	boss.damage = CFG.boss_base_damage + wave_number * CFG.boss_damage_per_wave
	boss.speed = CFG.boss_speed
	boss.xp_value = CFG.boss_xp
	boss.wave_level = wave_number
	aliens_node.add_child(boss)


func _on_player_level_up():
	pending_upgrades += 1


func _try_show_upgrade():
	if is_instance_valid(hud_node) and not hud_node.is_upgrade_showing():
		hud_node.show_upgrade_selection(player_node.upgrades)
		get_tree().paused = true


func _on_upgrade_chosen(upgrade_key: String):
	if is_instance_valid(player_node):
		player_node.apply_upgrade(upgrade_key)
	pending_upgrades -= 1
	get_tree().paused = false
	upgrade_cooldown = 0.4


func _on_game_started(start_wave: int):
	starting_wave = start_wave
	# Apply research bonuses
	if is_instance_valid(player_node):
		player_node.iron += int(GameData.get_research_bonus("starting_iron"))
		player_node.crystal += int(GameData.get_research_bonus("starting_crystal"))
		player_node.max_health += int(GameData.get_research_bonus("max_health"))
		player_node.health = player_node.max_health
		player_node.research_move_speed = GameData.get_research_bonus("move_speed")
		player_node.research_damage = int(GameData.get_research_bonus("base_damage"))
		player_node.research_mining_speed = GameData.get_research_bonus("mining_speed")
		player_node.research_xp_gain = GameData.get_research_bonus("xp_gain")
	# Start at selected wave
	if starting_wave > 1:
		wave_number = starting_wave - 1
		wave_timer = 5.0  # Short delay before first wave

	# Start with HQ energy bank full
	power_bank = CFG.hq_energy_storage

	# Initialize first wave direction
	next_wave_direction = randf() * TAU
	if is_instance_valid(hud_node):
		hud_node.set_wave_direction(next_wave_direction)


func _input(event):
	if event.is_action_pressed("pause"):
		if is_instance_valid(hud_node):
			hud_node.toggle_pause()


func on_player_died():
	game_over = true
	GameData.record_run(wave_number, bosses_killed)
	if is_instance_valid(hud_node):
		hud_node.show_death_screen(wave_number, bosses_killed, GameData.prestige_points)


func _on_hq_destroyed():
	# HQ destruction also kills the player
	if is_instance_valid(player_node) and not player_node.is_dead:
		player_node.health = 0
		player_node.is_dead = true
		# Create death particles on the player
		for i in range(20):
			var angle = randf() * TAU
			var speed = randf_range(80, 200)
			player_node.death_particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2.from_angle(angle) * speed,
				"life": randf_range(0.8, 1.5),
				"color": [Color(0.2, 0.9, 0.3), Color(1.0, 0.8, 0.2), Color(1.0, 0.4, 0.1)][randi() % 3],
				"size": randf_range(3, 8)
			})
	on_player_died()


func on_boss_killed():
	bosses_killed += 1


func restart_game(start_wave: int = 1):
	starting_wave = start_wave
	get_tree().reload_current_scene()


func _add_key_action(action_name: String, keycode: int):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)


func _add_mouse_action(action_name: String, button: MouseButton):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)
