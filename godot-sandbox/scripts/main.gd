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
var players: Dictionary = {}  # peer_id -> Node2D
var state_sync_timer: float = 0.0
const STATE_SYNC_INTERVAL: float = 0.05  # 20Hz
var next_net_id: int = 1
var alien_net_ids: Dictionary = {}  # net_id -> Node2D

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
	var drone_count = get_tree().get_nodes_in_group("repair_drones").size()
	total_power_consumption = turret_count * CFG.power_turret + factory_count * CFG.power_factory + lightning_count * CFG.power_lightning + slow_count * CFG.power_slow + pylon_count * CFG.power_pylon + flame_count * CFG.power_flame_turret + acid_count * CFG.power_acid_turret + drone_count * CFG.power_repair_drone

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
	_add_key_action("build_repair_drone", KEY_Q)
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
	player_node.peer_id = 1
	player_node.is_local = true
	add_child(player_node)
	player_node.level_up.connect(_on_player_level_up)
	players[1] = player_node

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

	var is_authority = not NetworkManager.is_multiplayer_active() or NetworkManager.is_host()

	if is_authority:
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

	# Network state sync
	if NetworkManager.is_multiplayer_active():
		state_sync_timer += delta
		if state_sync_timer >= STATE_SYNC_INTERVAL:
			state_sync_timer = 0.0
			if is_authority:
				_broadcast_state()
			else:
				_send_client_state()

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

	# Slower scaling: fewer enemies early on, scale for player count
	var mp_scale = 1.0 + (players.size() - 1) * 0.5
	var basic_count = int((2 + wave_number) * mp_scale)
	_spawn_aliens("basic", basic_count, rng, wave_dir)
	if wave_number >= CFG.alien_fast_start_wave:
		_spawn_aliens("fast", int(maxi(1, wave_number - 3) * mp_scale), rng, wave_dir)
	if wave_number >= CFG.alien_ranged_start_wave:
		_spawn_aliens("ranged", int(mini(wave_number - 5, CFG.alien_ranged_max_count) * mp_scale), rng, wave_dir)
	if wave_number >= CFG.boss_start_wave and wave_number % CFG.boss_wave_interval == 0:
		_spawn_boss(rng, wave_dir)
	if is_instance_valid(hud_node):
		hud_node.show_wave_alert(wave_number, wave_number >= CFG.boss_start_wave and wave_number % CFG.boss_wave_interval == 0)


func _get_player_centroid() -> Vector2:
	var total = Vector2.ZERO
	var count = 0
	for p in players.values():
		if is_instance_valid(p) and not p.is_dead:
			total += p.global_position
			count += 1
	if count == 0:
		return Vector2.ZERO
	return total / count


func _get_offscreen_spawn_pos(base_angle: float, rng: RandomNumberGenerator) -> Vector2:
	# Spawn far enough to be offscreen (at least 600 units from player centroid)
	var spread = rng.randf_range(-0.4, 0.4)  # ~45 degree spread
	var angle = base_angle + spread
	var dist = rng.randf_range(650, 850)
	var spawn_pos = _get_player_centroid() + Vector2.from_angle(angle) * dist
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
		alien.net_id = next_net_id
		next_net_id += 1
		aliens_node.add_child(alien)
		alien_net_ids[alien.net_id] = alien


func _spawn_boss(rng: RandomNumberGenerator, wave_dir: float):
	var boss = preload("res://scenes/boss_alien.tscn").instantiate()
	boss.position = _get_offscreen_spawn_pos(wave_dir, rng)
	boss.hp = CFG.boss_base_hp + wave_number * CFG.boss_hp_per_wave
	boss.max_hp = boss.hp
	boss.damage = CFG.boss_base_damage + wave_number * CFG.boss_damage_per_wave
	boss.speed = CFG.boss_speed
	boss.xp_value = CFG.boss_xp
	boss.wave_level = wave_number
	boss.net_id = next_net_id
	next_net_id += 1
	aliens_node.add_child(boss)
	alien_net_ids[boss.net_id] = boss


func _on_player_level_up():
	pending_upgrades += 1


func _try_show_upgrade():
	if is_instance_valid(hud_node) and not hud_node.is_upgrade_showing():
		hud_node.show_upgrade_selection(player_node.upgrades)
		if not NetworkManager.is_multiplayer_active():
			get_tree().paused = true


func _on_upgrade_chosen(upgrade_key: String):
	if is_instance_valid(player_node):
		player_node.apply_upgrade(upgrade_key)
	pending_upgrades -= 1
	if not NetworkManager.is_multiplayer_active():
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

	# Apply building health research to HQ
	var health_bonus = GameData.get_research_bonus("building_health")
	if health_bonus > 0 and is_instance_valid(hq_node):
		var bonus_hp = int(hq_node.max_hp * health_bonus)
		hq_node.hp += bonus_hp
		hq_node.max_hp += bonus_hp

	# Start with HQ energy bank full
	power_bank = CFG.hq_energy_storage

	# Initialize first wave direction
	next_wave_direction = randf() * TAU
	if is_instance_valid(hud_node):
		hud_node.set_wave_direction(next_wave_direction)

	# Multiplayer setup
	if NetworkManager.is_multiplayer_active():
		var my_id = multiplayer.get_unique_id()
		player_node.peer_id = my_id
		players.erase(1)
		players[my_id] = player_node
		if NetworkManager.is_host():
			player_node.player_color = Color(0.2, 0.9, 0.3)  # Host green
			for pid in multiplayer.get_peers():
				_spawn_remote_player(pid, Color(0.4, 0.6, 1.0))  # Client blue
			_rpc_start_game.rpc(starting_wave)
		else:
			player_node.player_color = Color(0.4, 0.6, 1.0)  # Client blue
			_spawn_remote_player(1, Color(0.2, 0.9, 0.3))  # Host green


func _input(event):
	if event.is_action_pressed("pause"):
		if is_instance_valid(hud_node):
			hud_node.toggle_pause()


func on_player_died():
	# In MP, game continues unless all players are dead
	if NetworkManager.is_multiplayer_active():
		var all_dead = true
		for p in players.values():
			if is_instance_valid(p) and not p.is_dead:
				all_dead = false
				break
		if not all_dead:
			return
	game_over = true
	GameData.record_run(wave_number, bosses_killed)
	if is_instance_valid(hud_node):
		hud_node.show_death_screen(wave_number, bosses_killed, GameData.prestige_points)
	# Notify client of game over in MP
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
		_rpc_game_over.rpc(wave_number, bosses_killed)


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


func _spawn_remote_player(pid: int, color: Color):
	var player_scene = preload("res://scenes/player.tscn")
	var remote = player_scene.instantiate()
	remote.name = "Player_%d" % pid
	remote.peer_id = pid
	remote.is_local = false
	remote.player_color = color
	# Offset spawn so players don't overlap
	remote.position = Vector2(60, 0) if pid != 1 else Vector2(-60, 0)
	add_child(remote)
	players[pid] = remote


@rpc("authority", "call_remote", "reliable")
func _rpc_start_game(wave: int):
	# Client receives this from host to start the game
	if is_instance_valid(hud_node):
		hud_node.start_mp_game()
	get_tree().paused = false
	_on_game_started(wave)


func _broadcast_state():
	# Host sends full game state to client at 20Hz
	var player_states = []
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			player_states.append([pid, p.global_position.x, p.global_position.y, p.facing_angle, p.health, p.max_health, p.is_dead])

	# Clean dead aliens from tracking
	var dead_ids = []
	for nid in alien_net_ids:
		if not is_instance_valid(alien_net_ids[nid]):
			dead_ids.append(nid)
	for nid in dead_ids:
		alien_net_ids.erase(nid)

	# Enemy data: [net_id, type_id, pos_x, pos_y, hp, max_hp]
	var enemy_data = []
	for nid in alien_net_ids:
		var a = alien_net_ids[nid]
		var type_id = 0  # basic
		if a.is_in_group("bosses"):
			type_id = 3
		elif a.get_script() == preload("res://scripts/ranged_alien.gd"):
			type_id = 2
		elif "alien_type" in a and a.alien_type == "fast":
			type_id = 1
		enemy_data.append([nid, type_id, a.global_position.x, a.global_position.y, a.hp, a.max_hp])

	_receive_state.rpc([
		player_states,
		player_node.iron, player_node.crystal,
		wave_number, wave_timer, wave_active,
		power_bank, max_power_bank, power_on,
		total_power_gen, total_power_consumption,
		bosses_killed,
		enemy_data
	])


@rpc("authority", "call_remote", "unreliable")
func _receive_state(state: Array):
	# Client receives state from host
	var player_states: Array = state[0]
	var shared_iron: int = state[1]
	var shared_crystal: int = state[2]
	wave_number = state[3]
	wave_timer = state[4]
	wave_active = state[5]
	power_bank = state[6]
	max_power_bank = state[7]
	power_on = state[8]
	total_power_gen = state[9]
	total_power_consumption = state[10]
	bosses_killed = state[11]
	var enemy_data: Array = state[12] if state.size() > 12 else []

	# Sync shared resources to local player
	if is_instance_valid(player_node):
		player_node.iron = shared_iron
		player_node.crystal = shared_crystal

	# Update player positions
	var my_id = multiplayer.get_unique_id()
	for ps in player_states:
		var pid: int = ps[0]
		if pid == my_id:
			# Own player: sync HP from host, keep local position
			if is_instance_valid(player_node):
				player_node.health = ps[4]
				player_node.max_health = ps[5]
		else:
			# Remote player: update position and state
			if players.has(pid) and is_instance_valid(players[pid]):
				var rp = players[pid]
				rp.global_position = Vector2(ps[1], ps[2])
				rp.facing_angle = ps[3]
				rp.health = ps[4]
				rp.max_health = ps[5]
				rp.is_dead = ps[6]

	# Sync enemies
	_sync_enemies(enemy_data)


func _send_client_state():
	# Client sends their position/angle to host
	if is_instance_valid(player_node):
		_receive_client_state.rpc_id(1,
			player_node.global_position.x,
			player_node.global_position.y,
			player_node.facing_angle)


@rpc("any_peer", "call_remote", "unreliable")
func _receive_client_state(pos_x: float, pos_y: float, angle: float):
	# Host receives client position
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id) and is_instance_valid(players[sender_id]):
		players[sender_id].global_position = Vector2(pos_x, pos_y)
		players[sender_id].facing_angle = angle


@rpc("authority", "call_remote", "reliable")
func _rpc_game_over(wave: int, bosses: int):
	# Client receives game over from host
	game_over = true
	GameData.record_run(wave, bosses)
	if is_instance_valid(hud_node):
		hud_node.show_death_screen(wave, bosses, GameData.prestige_points)


@rpc("any_peer", "call_remote", "reliable")
func _request_build(type: String, pos_x: float, pos_y: float):
	# Host handles client build request
	var sender_id = multiplayer.get_remote_sender_id()
	if not players.has(sender_id) or not is_instance_valid(players[sender_id]):
		return
	var requester = players[sender_id]
	var bp = Vector2(pos_x, pos_y)
	# Range check from requester's position
	if requester.global_position.distance_to(bp) > CFG.build_range:
		return
	# Use host's shared resources to place building
	if is_instance_valid(player_node) and player_node._try_build_at(type, bp):
		pass  # _try_build_at already broadcasts via _sync_building_placed


@rpc("authority", "call_remote", "reliable")
func _sync_building_placed(type: String, pos_x: float, pos_y: float):
	# Client creates building locally (no cost deduction)
	var bp = Vector2(pos_x, pos_y)
	var building: Node2D
	match type:
		"turret": building = preload("res://scenes/turret.tscn").instantiate()
		"factory": building = preload("res://scenes/factory.tscn").instantiate()
		"wall": building = preload("res://scenes/wall.tscn").instantiate()
		"lightning": building = preload("res://scenes/lightning_tower.tscn").instantiate()
		"slow": building = preload("res://scenes/slow_tower.tscn").instantiate()
		"pylon": building = preload("res://scenes/pylon.tscn").instantiate()
		"power_plant": building = preload("res://scenes/power_plant.tscn").instantiate()
		"battery": building = preload("res://scenes/battery.tscn").instantiate()
		"flame_turret": building = preload("res://scenes/flame_turret.tscn").instantiate()
		"acid_turret": building = preload("res://scenes/acid_turret.tscn").instantiate()
		"repair_drone": building = preload("res://scenes/repair_drone.tscn").instantiate()
	if building:
		building.global_position = bp
		buildings_node.add_child(building)
		var health_bonus = GameData.get_research_bonus("building_health")
		if health_bonus > 0 and "hp" in building and "max_hp" in building:
			var bonus_hp = int(building.max_hp * health_bonus)
			building.hp += bonus_hp
			building.max_hp += bonus_hp


func _sync_enemies(enemy_data: Array):
	# Client-side: sync puppet enemies from host broadcast
	var live_ids = {}
	for ed in enemy_data:
		var nid: int = ed[0]
		var type_id: int = ed[1]
		var pos = Vector2(ed[2], ed[3])
		var enemy_hp: int = ed[4]
		var enemy_max_hp: int = ed[5]
		live_ids[nid] = true

		if alien_net_ids.has(nid) and is_instance_valid(alien_net_ids[nid]):
			# Update existing puppet
			var a = alien_net_ids[nid]
			a.target_pos = pos
			a.hp = enemy_hp
			a.max_hp = enemy_max_hp
		else:
			# Spawn new puppet
			var alien: Node2D
			match type_id:
				2:
					alien = preload("res://scenes/ranged_alien.tscn").instantiate()
				3:
					alien = preload("res://scenes/boss_alien.tscn").instantiate()
				_:
					alien = preload("res://scenes/alien.tscn").instantiate()
					if type_id == 1:
						alien.alien_type = "fast"
			alien.net_id = nid
			alien.is_puppet = true
			alien.hp = enemy_hp
			alien.max_hp = enemy_max_hp
			alien.global_position = pos
			alien.target_pos = pos
			aliens_node.add_child(alien)
			alien_net_ids[nid] = alien

	# Remove puppets that no longer exist on host
	var to_remove = []
	for nid in alien_net_ids:
		if not live_ids.has(nid):
			var a = alien_net_ids[nid]
			if is_instance_valid(a):
				# Spawn XP gem visual on death
				var gem = preload("res://scenes/xp_gem.tscn").instantiate()
				gem.global_position = a.global_position
				gem.xp_value = a.xp_value
				add_child(gem)
				a.queue_free()
			to_remove.append(nid)
	for nid in to_remove:
		alien_net_ids.erase(nid)
