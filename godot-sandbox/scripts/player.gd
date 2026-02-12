extends Node3D

signal level_up

const CFG = preload("res://resources/game_config.tres")

var health: int = CFG.player_health
var max_health: int = CFG.player_health
var iron: int = 0
var crystal: int = 0
var shoot_timer: float = 0.0
var facing_angle: float = 0.0
var invuln_timer: float = 0.0
var auto_mine_timer: float = 0.0
var mine_targets: Array = []
var remote_mine_positions: Array = []  # For remote players: [[x,z],[x,z],...] from host sync
var repair_targets: Array = []
var auto_repair_timer: float = 0.0
var is_dead: bool = false
var hit_flash_timer: float = 0.0
var death_particles: Array = []

var xp: int = 0
var level: int = 0
var xp_to_next: int = CFG.base_xp_to_level

var magnet_timer: float = 0.0
var mining_boost_timer: float = 0.0

# Build mode for RTS-style placement
var build_mode: String = ""  # Empty = not building, otherwise building type
var build_mode_cooldown: float = 0.0  # Prevents immediate placement after clicking build icon
var is_mobile: bool = false
var auto_fire: bool = true   # When false, hold mouse/click to fire
var auto_aim: bool = true    # When true, auto-aim at nearest enemy
var pending_build_world_pos: Vector3 = Vector3.ZERO  # Mobile: ghost position set by tap

var upgrades = {
	"chain_lightning": 0,
	"shotgun": 0,
	"burning": 0,
	"ice": 0,
	"damage_aura": 0,
	"orbital_lasers": 0,
	"max_health": 0,
	"move_speed": 0,
	"attack_speed": 0,
	"mining_speed": 0,
	"mining_heads": 0,
	"turret_damage": 0,
	"turret_fire_rate": 0,
	"factory_speed": 0,
	"mining_range": 0,
	"rock_regen": 0,
	"health_regen": 0,
	"dodge": 0,
	"armor": 0,
	"crit_chance": 0,
	"pickup_range": 0,
	"shoot_range": 0,
}


var aura_timer: float = 0.0
var orbital_angle: float = 0.0
var regen_timer: float = 0.0
var nuke_radius: float = 0.0       # Current expanding radius (0 = inactive)
var nuke_origin: Vector3 = Vector3.ZERO
var nuke_hit_ids: Dictionary = {}   # Track aliens already hit by this nuke

# Research bonuses (set by main.gd on game start)
var research_move_speed: float = 0.0
var research_damage: int = 0
var research_mining_speed: float = 0.0
var research_xp_gain: float = 0.0

# Multiplayer
var peer_id: int = 1
var is_local: bool = true
var player_color: Color = Color(0.2, 0.9, 0.3)
var player_name: String = ""
var _remote_target_pos: Vector3 = Vector3.ZERO


func _ready():
	add_to_group("player")


func enter_build_mode(building_type: String):
	build_mode = building_type
	build_mode_cooldown = 0.15  # Brief cooldown to prevent immediate placement from the same click
	if is_mobile:
		pending_build_world_pos = global_position.snapped(Vector3(40, 0, 40))


func cancel_build_mode():
	build_mode = ""
	build_mode_cooldown = 0.0


func _toggle_build_mode(type: String):
	if build_mode == type:
		cancel_build_mode()
	else:
		enter_build_mode(type)


func is_in_build_mode() -> bool:
	return build_mode != ""


func get_mine_interval() -> float:
	return CFG.mine_interval / (1.0 + upgrades["mining_speed"] * CFG.mining_speed_per_level + research_mining_speed)


func get_mine_heads() -> int:
	return 1 + upgrades["mining_heads"]


func get_mine_range() -> float:
	return CFG.mine_range + upgrades["mining_range"] * CFG.mining_range_per_level + GameData.get_research_bonus("mining_range")


func get_rock_regen_multiplier() -> float:
	return 1.0 + upgrades["rock_regen"] * CFG.rock_regen_per_level


func get_gem_range() -> float:
	# Magnet pulls gems via xp_gem.gd, collection only happens at close range
	return CFG.gem_collect_range + upgrades["pickup_range"] * CFG.pickup_range_per_level + GameData.get_research_bonus("pickup_range")


func _process(delta):
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	_build_error_cooldown = maxf(0.0, _build_error_cooldown - delta)

	if is_dead:
		_process_death(delta)
		return

	if not is_local:
		# Interpolate remote player position
		if _remote_target_pos != Vector3.ZERO:
			global_position = global_position.lerp(_remote_target_pos, minf(delta * 15.0, 1.0))
		invuln_timer = maxf(0.0, invuln_timer - delta)
		# Animate orbital lasers visually for remote players
		if upgrades["orbital_lasers"] > 0:
			orbital_angle += delta * (2.5 + upgrades["orbital_lasers"] * 0.5)
		return

	var input = Vector3.ZERO
	var joystick_node = null
	var look_joystick_node = null
	var joysticks = get_tree().get_nodes_in_group("mobile_joystick")
	for j in joysticks:
		if j.joystick_type == "move":
			joystick_node = j
		elif j.joystick_type == "look":
			look_joystick_node = j
	if joysticks.size() > 0:
		is_mobile = true

	if joystick_node and joystick_node.input_vector != Vector2.ZERO:
		input = Vector3(joystick_node.input_vector.x, 0, joystick_node.input_vector.y)
	else:
		if Input.is_action_pressed("move_up"): input.z -= 1
		if Input.is_action_pressed("move_down"): input.z += 1
		if Input.is_action_pressed("move_left"): input.x -= 1
		if Input.is_action_pressed("move_right"): input.x += 1
	if input != Vector3.ZERO:
		position += input.normalized() * CFG.player_speed * (1.0 + upgrades["move_speed"] * CFG.move_speed_per_level + research_move_speed) * delta
	position.x = clampf(position.x, -CFG.map_half_size, CFG.map_half_size)
	position.z = clampf(position.z, -CFG.map_half_size, CFG.map_half_size)

	if is_mobile or auto_aim:
		if look_joystick_node and look_joystick_node.input_vector != Vector2.ZERO:
			facing_angle = atan2(look_joystick_node.input_vector.y, look_joystick_node.input_vector.x)
		else:
			var nearest_alien = _find_nearest_alien()
			if nearest_alien:
				var dir = nearest_alien.global_position - global_position
				facing_angle = atan2(dir.z, dir.x)
			elif not is_mobile:
				var mw = get_tree().current_scene.mouse_world_2d
				var dir = mw - global_position
				facing_angle = atan2(dir.z, dir.x)
	else:
		var mw = get_tree().current_scene.mouse_world_2d
		var dir = mw - global_position
		facing_angle = atan2(dir.z, dir.x)
	shoot_timer = maxf(0.0, shoot_timer - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	magnet_timer = maxf(0.0, magnet_timer - delta)
	mining_boost_timer = maxf(0.0, mining_boost_timer - delta)

	var manual_shooting = not auto_fire and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and build_mode == ""
	var can_fire = auto_fire or manual_shooting
	if shoot_timer <= 0 and can_fire and _find_nearest_alien() != null:
		_shoot()
		shoot_timer = CFG.shoot_cooldown / (1.0 + upgrades["attack_speed"] * CFG.attack_speed_per_level)

	auto_mine_timer += delta
	if auto_mine_timer >= get_mine_interval():
		auto_mine_timer = 0.0
		var mine_amount = 2 + upgrades["mining_speed"]
		var yield_bonus = GameData.get_research_bonus("mining_yield")
		if yield_bonus > 0:
			mine_amount = int(mine_amount * (1.0 + yield_bonus))
		if mining_boost_timer > 0:
			mine_amount *= CFG.mining_boost_multiplier
		_mine_nearby(mine_amount)

	# Repair beams
	if GameData.get_research_bonus("unlock_repair") >= 1.0:
		auto_repair_timer += delta
		if auto_repair_timer >= get_mine_interval():
			auto_repair_timer = 0.0
			_repair_nearby()
	else:
		repair_targets.clear()

	# Hotkey building (select build mode, click to place)
	if Input.is_action_just_pressed("build_power_plant"):
		_toggle_build_mode("power_plant")
	if Input.is_action_just_pressed("build_pylon"):
		_toggle_build_mode("pylon")
	if Input.is_action_just_pressed("build_factory"):
		_toggle_build_mode("factory")
	if Input.is_action_just_pressed("build_turret"):
		_toggle_build_mode("turret")
	if Input.is_action_just_pressed("build_wall"):
		_toggle_build_mode("wall")
	if Input.is_action_just_pressed("build_lightning"):
		if GameData.get_research_bonus("unlock_lightning") >= 1.0:
			_toggle_build_mode("lightning")
	if Input.is_action_just_pressed("build_slow"):
		if GameData.get_research_bonus("turret_ice") >= 1.0:
			_toggle_build_mode("slow")
	if Input.is_action_just_pressed("build_battery"):
		if GameData.get_research_bonus("unlock_battery") >= 1.0:
			_toggle_build_mode("battery")
	if Input.is_action_just_pressed("build_flame_turret"):
		if GameData.get_research_bonus("turret_fire") >= 1.0:
			_toggle_build_mode("flame_turret")
	if Input.is_action_just_pressed("build_acid_turret"):
		if GameData.get_research_bonus("turret_acid") >= 1.0:
			_toggle_build_mode("acid_turret")
	if Input.is_action_just_pressed("build_repair_drone"):
		if GameData.get_research_bonus("unlock_repair_drone") >= 1.0:
			_toggle_build_mode("repair_drone")
	if Input.is_action_just_pressed("build_poison_turret"):
		if GameData.get_research_bonus("turret_poison") >= 1.0:
			_toggle_build_mode("poison_turret")

	# Build mode placement (click to place)
	if build_mode != "":
		build_mode_cooldown = maxf(0.0, build_mode_cooldown - delta)
		if is_mobile:
			pass  # Mobile: tap sets pending position via HUD, confirm button triggers placement
		else:
			var joystick_blocking = joystick_node != null and joystick_node.is_active
			if Input.is_action_just_pressed("shoot") and build_mode_cooldown <= 0 and not joystick_blocking:
				if _try_build(build_mode):
					pass  # Stay in build mode for quick placement
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				cancel_build_mode()

	_collect_gems()
	_collect_prestige_orbs()
	_collect_powerups()
	if upgrades["damage_aura"] > 0:
		_process_aura(delta)
	if upgrades["orbital_lasers"] > 0:
		_process_orbitals(delta)
	if upgrades["health_regen"] > 0:
		_process_regen(delta)
	if nuke_radius > 0:
		_process_nuke(delta)


func _process_nuke(delta):
	nuke_radius += CFG.nuke_expand_speed * delta
	var can_deal_damage = not NetworkManager.is_multiplayer_active() or NetworkManager.is_host()
	if can_deal_damage:
		for a in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(a): continue
			if a.get_instance_id() in nuke_hit_ids: continue
			var dist = nuke_origin.distance_to(a.global_position)
			if dist <= nuke_radius:
				a.take_damage(CFG.nuke_damage)
				nuke_hit_ids[a.get_instance_id()] = true
	if nuke_radius >= CFG.nuke_range:
		nuke_radius = 0.0
		nuke_hit_ids.clear()


func _process_regen(delta):
	regen_timer += delta
	if regen_timer >= 1.0:
		regen_timer -= 1.0
		var heal_amount = upgrades["health_regen"] * CFG.health_regen_per_level
		health = mini(health + heal_amount, max_health)


func _process_death(delta):
	for i in range(death_particles.size() - 1, -1, -1):
		var p = death_particles[i]
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.96
		p["life"] -= delta
		if p["life"] <= 0:
			death_particles.remove_at(i)


func _shoot():
	var count = 1
	var spread = 0.0
	if upgrades["shotgun"] > 0:
		count = 2 + upgrades["shotgun"]
		spread = 0.3 + upgrades["shotgun"] * 0.06
	for i in range(count):
		var b = preload("res://scenes/bullet.tscn").instantiate()
		var off = 0.0
		if count > 1:
			off = lerpf(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
		b.direction = Vector3(cos(facing_angle + off), 0, sin(facing_angle + off))
		b.damage = CFG.bullet_damage + research_damage
		b.crit_chance = upgrades["crit_chance"] * CFG.crit_per_level
		b.chain_count = upgrades["chain_lightning"] + int(GameData.get_research_bonus("chain_count"))
		b.chain_damage_bonus = int(GameData.get_research_bonus("chain_damage"))
		b.chain_retention = CFG.chain_base_retention + GameData.get_research_bonus("chain_retention")
		b.burn_dps = upgrades["burning"] * CFG.burn_dps_per_level
		b.slow_amount = upgrades["ice"] * CFG.slow_per_level
		b.lifetime = minf(CFG.bullet_lifetime, get_shoot_range() / b.speed)
		var spawn_pos = global_position + Vector3(cos(facing_angle), 0, sin(facing_angle)) * 20.0
		get_tree().current_scene.game_world_2d.add_child(b)
		b.global_position = spawn_pos
		get_tree().current_scene.spawn_synced_bullet(b.global_position, b.direction, false, b.burn_dps, b.slow_amount)


func _mine_nearby(qty: int):
	var resources = get_tree().get_nodes_in_group("resources")
	var sorted_res: Array = []
	var mine_range = get_mine_range()
	for r in resources:
		if not is_instance_valid(r): continue
		var d = global_position.distance_to(r.global_position)
		if d < mine_range:
			sorted_res.append({"node": r, "dist": d})
	sorted_res.sort_custom(func(a, b): return a["dist"] < b["dist"])

	mine_targets.clear()
	var heads = get_mine_heads()
	for i in range(mini(heads, sorted_res.size())):
		var r = sorted_res[i]["node"]
		mine_targets.append(r)
		var res_pos = r.global_position
		var result = r.mine(qty)
		if result["type"] == "iron":
			iron += result["amount"]
		elif result["type"] == "crystal":
			crystal += result["amount"]
		# Drop XP gem when resource is fully depleted
		if result["amount"] > 0 and not is_instance_valid(r):
			var gem = preload("res://scenes/xp_gem.tscn").instantiate()
			gem.xp_value = maxi(1, result["amount"])
			get_tree().current_scene.game_world_2d.add_child(gem)
			gem.global_position = res_pos
			# 1 in 5 chance to drop a prestige orb from depleted rock
			if randi() % 5 == 0:
				var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
				orb.prestige_value = NetworkManager.get_player_count()
				get_tree().current_scene.game_world_2d.add_child(orb)
				orb.global_position = res_pos


func _repair_nearby():
	var buildings = get_tree().get_nodes_in_group("buildings")
	var sorted_buildings: Array = []
	var repair_range = get_mine_range()
	for b in buildings:
		if not is_instance_valid(b): continue
		if not ("hp" in b and "max_hp" in b): continue
		if b.hp >= b.max_hp: continue
		var d = global_position.distance_to(b.global_position)
		if d < repair_range:
			sorted_buildings.append({"node": b, "dist": d})
	sorted_buildings.sort_custom(func(a, b2): return a["dist"] < b2["dist"])

	repair_targets.clear()
	var heads = 1 + int(GameData.get_research_bonus("repair_beams"))
	var heal = 2 + int(GameData.get_research_bonus("repair_rate"))
	for i in range(mini(heads, sorted_buildings.size())):
		var b = sorted_buildings[i]["node"]
		repair_targets.append(b)
		b.hp = mini(b.hp + heal, b.max_hp)


func _collect_gems():
	var collect_range = get_gem_range()
	for gem in get_tree().get_nodes_in_group("xp_gems"):
		if not is_instance_valid(gem): continue
		if global_position.distance_to(gem.global_position) < collect_range:
			add_xp(gem.xp_value)
			gem.collect()


func _collect_prestige_orbs():
	var collect_range = get_gem_range()
	for orb in get_tree().get_nodes_in_group("prestige_orbs"):
		if not is_instance_valid(orb): continue
		if global_position.distance_to(orb.global_position) < collect_range:
			get_tree().current_scene.add_run_prestige(orb.prestige_value)
			orb.collect()


func _collect_powerups():
	for p in get_tree().get_nodes_in_group("powerups"):
		if not is_instance_valid(p): continue
		if global_position.distance_to(p.global_position) < 30:
			_apply_powerup(p.powerup_type)
			p.queue_free()


func get_shoot_range() -> float:
	return CFG.shoot_range + upgrades["shoot_range"] * CFG.shoot_range_per_level


func _find_nearest_alien() -> Node3D:
	var aliens = get_tree().get_nodes_in_group("aliens")
	var nearest: Node3D = null
	var max_range = get_shoot_range()
	var nearest_dist = max_range
	for a in aliens:
		if not is_instance_valid(a): continue
		var d = global_position.distance_to(a.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = a
	return nearest


func _apply_powerup(type: String):
	var text = ""
	var color = Color.WHITE
	match type:
		"magnet":
			magnet_timer = CFG.magnet_duration
			text = "MAGNET!"
			color = Color(0.3, 1.0, 0.5)
		"weapon_scroll":
			var weapons = ["chain_lightning", "shotgun", "burning", "ice", "damage_aura", "orbital_lasers"]
			var pick = weapons[randi() % weapons.size()]
			if upgrades[pick] < 5:
				upgrades[pick] += 1
			text = "WEAPON UP!"
			color = Color(1.0, 0.8, 0.2)
		"heal":
			health = mini(health + CFG.heal_powerup_amount, max_health)
			text = "+%d HP" % CFG.heal_powerup_amount
			color = Color(1.0, 0.3, 0.4)
		"nuke":
			nuke_radius = 0.01
			nuke_origin = global_position
			nuke_hit_ids.clear()
			text = "NUKE!"
			color = Color(1.0, 0.5, 0.1)
		"mining_boost":
			mining_boost_timer = CFG.mining_boost_duration
			text = "MINING BOOST!"
			color = Color(1.0, 0.8, 0.3)

	if text != "":
		_spawn_popup(text, color)


func _spawn_popup(text: String, color: Color):
	var popup = preload("res://scenes/popup_text.tscn").instantiate()
	popup.text = text
	popup.color = color
	get_tree().current_scene.game_world_2d.add_child(popup)
	popup.global_position = global_position + Vector3(0, 30, 0)


func add_xp(amount: int):
	var bonus = int(amount * research_xp_gain)
	xp += amount + bonus
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = CFG.base_xp_to_level + level * CFG.xp_per_level_scale
		level_up.emit()


func apply_upgrade(key: String):
	if upgrades.has(key):
		upgrades[key] += 1
	match key:
		"max_health":
			max_health += CFG.health_per_level
			health = mini(health + CFG.health_per_level, max_health)
		"turret_damage":
			for t in get_tree().get_nodes_in_group("turrets"):
				if is_instance_valid(t):
					t.damage_bonus = upgrades["turret_damage"] * CFG.turret_damage_per_level + int(GameData.get_research_bonus("turret_damage"))
		"turret_fire_rate":
			for t in get_tree().get_nodes_in_group("turrets"):
				if is_instance_valid(t):
					t.fire_rate_bonus = upgrades["turret_fire_rate"] * CFG.turret_fire_rate_per_level
		"factory_speed":
			for f in get_tree().get_nodes_in_group("factories"):
				if is_instance_valid(f):
					f.speed_bonus = upgrades["factory_speed"] * CFG.factory_speed_per_level + GameData.get_research_bonus("factory_speed") + GameData.get_research_bonus("factory_rate")


func get_building_cost(type: String) -> Dictionary:
	var base = CFG.get_base_cost(type)
	var count = get_tree().get_nodes_in_group(type + "s").size()
	var multiplier = pow(CFG.get_cost_scale(type), count)
	var efficiency = 1.0 - GameData.get_research_bonus("cost_efficiency")
	return {
		"iron": maxi(1, int(base["iron"] * multiplier * efficiency)),
		"crystal": int(base["crystal"] * multiplier * efficiency)
	}


func _try_build(type: String) -> bool:
	var bp = get_tree().current_scene.mouse_world_2d.snapped(Vector3(40, 0, 40))
	return _try_build_at(type, bp)


func confirm_build() -> bool:
	if build_mode == "" or pending_build_world_pos == Vector3.ZERO:
		return false
	return _try_build_at(build_mode, pending_build_world_pos)


func _try_build_at(type: String, bp: Vector3) -> bool:
	# MP client: route build request to host
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_host():
		get_tree().current_scene._request_build.rpc_id(1, type, bp.x, bp.z)
		return true

	# Check research locks
	if type == "lightning" and GameData.get_research_bonus("unlock_lightning") < 1.0:
		return false
	if type == "slow" and GameData.get_research_bonus("turret_ice") < 1.0:
		return false
	if type == "flame_turret" and GameData.get_research_bonus("turret_fire") < 1.0:
		return false
	if type == "acid_turret" and GameData.get_research_bonus("turret_acid") < 1.0:
		return false
	if type == "battery" and GameData.get_research_bonus("unlock_battery") < 1.0:
		return false
	if type == "repair_drone" and GameData.get_research_bonus("unlock_repair_drone") < 1.0:
		return false
	if type == "poison_turret" and GameData.get_research_bonus("turret_poison") < 1.0:
		return false
	if global_position.distance_to(bp) > CFG.build_range:
		return false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(bp) < 36:
			return false

	var cost = get_building_cost(type)
	if iron < cost["iron"] or crystal < cost["crystal"]:
		var parts: Array = []
		if cost["iron"] > iron:
			parts.append("%d more iron" % (cost["iron"] - iron))
		if cost["crystal"] > crystal:
			parts.append("%d more crystal" % (cost["crystal"] - crystal))
		_show_build_error("Need " + " & ".join(parts))
		return false

	iron -= cost["iron"]
	crystal -= cost["crystal"]

	var building: Node3D
	match type:
		"turret":
			building = preload("res://scenes/turret.tscn").instantiate()
			building.damage_bonus = upgrades["turret_damage"] * CFG.turret_damage_per_level + int(GameData.get_research_bonus("turret_damage"))
			building.fire_rate_bonus = upgrades["turret_fire_rate"] * CFG.turret_fire_rate_per_level
			building.bullet_count = 1 + int(GameData.get_research_bonus("turret_spread"))
		"factory":
			building = preload("res://scenes/factory.tscn").instantiate()
			building.speed_bonus = upgrades["factory_speed"] * CFG.factory_speed_per_level + GameData.get_research_bonus("factory_speed") + GameData.get_research_bonus("factory_rate")
		"wall":
			building = preload("res://scenes/wall.tscn").instantiate()
		"lightning":
			building = preload("res://scenes/lightning_tower.tscn").instantiate()
		"slow":
			building = preload("res://scenes/slow_tower.tscn").instantiate()
		"pylon":
			building = preload("res://scenes/pylon.tscn").instantiate()
		"power_plant":
			building = preload("res://scenes/power_plant.tscn").instantiate()
		"battery":
			building = preload("res://scenes/battery.tscn").instantiate()
		"flame_turret":
			building = preload("res://scenes/flame_turret.tscn").instantiate()
		"acid_turret":
			building = preload("res://scenes/acid_turret.tscn").instantiate()
		"repair_drone":
			building = preload("res://scenes/repair_drone.tscn").instantiate()
		"poison_turret":
			building = preload("res://scenes/poison_turret.tscn").instantiate()

	if building:
		get_tree().current_scene.buildings_node.add_child(building)
		building.global_position = bp
		# Apply building health research bonus
		var health_bonus = GameData.get_research_bonus("building_health")
		if health_bonus > 0 and "hp" in building and "max_hp" in building:
			var bonus_hp = int(building.max_hp * health_bonus)
			building.hp += bonus_hp
			building.max_hp += bonus_hp
		# Sync to client in MP
		if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
			get_tree().current_scene._sync_building_placed.rpc(type, bp.x, bp.z)
		return true
	return false


func can_place_at(pos: Vector3) -> bool:
	if global_position.distance_to(pos) > CFG.build_range:
		return false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(pos) < 36:
			return false
	return true


func can_afford(type: String) -> bool:
	var cost = get_building_cost(type)
	return iron >= cost["iron"] and crystal >= cost["crystal"]


var _build_error_cooldown: float = 0.0

func _show_build_error(msg: String):
	if _build_error_cooldown > 0:
		return
	_build_error_cooldown = 1.0
	var popup = preload("res://scenes/popup_text.tscn").instantiate()
	popup.text = msg
	popup.color = Color(1.0, 0.4, 0.3)
	popup.velocity = Vector3(0, 40, 0)
	popup.lifetime = 1.5
	get_tree().current_scene.game_world_2d.add_child(popup)
	popup.global_position = global_position + Vector3(0, 30, 0)


func get_building_type_string(building: Node3D) -> String:
	if not building.has_method("get_building_name"):
		return ""
	match building.get_building_name():
		"Turret": return "turret"
		"Factory": return "factory"
		"Wall": return "wall"
		"Lightning Tower": return "lightning"
		"Slow Tower": return "slow"
		"Pylon": return "pylon"
		"Power Plant": return "power_plant"
		"Battery": return "battery"
		"Flame Turret": return "flame_turret"
		"Acid Turret": return "acid_turret"
		"Repair Drone": return "repair_drone"
	return ""


func get_recycle_value(building: Node3D) -> Dictionary:
	var type_str = get_building_type_string(building)
	if type_str == "":
		return {"iron": 0, "crystal": 0}
	var base = CFG.get_base_cost(type_str)
	var hp_ratio = 1.0
	if "hp" in building and "max_hp" in building and building.max_hp > 0:
		hp_ratio = float(building.hp) / float(building.max_hp)
	return {
		"iron": int(base["iron"] * hp_ratio),
		"crystal": int(base["crystal"] * hp_ratio)
	}


func recycle_building(building: Node3D) -> Dictionary:
	var value = get_recycle_value(building)
	iron += value["iron"]
	crystal += value["crystal"]
	building.queue_free()
	return value


func _process_aura(delta):
	aura_timer += delta
	if aura_timer >= 0.5:
		aura_timer -= 0.5
		var r = CFG.aura_radius_base + upgrades["damage_aura"] * CFG.aura_radius_per_level
		var dmg = upgrades["damage_aura"] * CFG.aura_damage_per_level
		for a in get_tree().get_nodes_in_group("aliens"):
			if is_instance_valid(a) and global_position.distance_to(a.global_position) < r:
				a.take_damage(dmg)


func _process_orbitals(delta):
	orbital_angle += delta * (2.5 + upgrades["orbital_lasers"] * 0.5)
	var cnt = upgrades["orbital_lasers"]
	var can_deal_damage = not NetworkManager.is_multiplayer_active() or NetworkManager.is_host()
	for i in range(cnt):
		var ang = orbital_angle + TAU * i / cnt
		var op = global_position + Vector3(cos(ang), 0, sin(ang)) * 80.0
		if not can_deal_damage:
			continue
		for a in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(a): continue
			if op.distance_to(a.global_position) < 22 and a.can_take_orbital_hit():
				a.take_damage(12)
				a.orbital_cooldown = 0.4


func take_damage(amount: int):
	if invuln_timer > 0 or is_dead:
		return
	# Dodge chance
	var dodge_chance = upgrades["dodge"] * CFG.dodge_per_level
	if randf() < dodge_chance:
		_spawn_popup("DODGE!", Color(0.5, 0.8, 1.0))
		return
	# Armor reduction
	var armor_reduction = upgrades["armor"] * CFG.armor_per_level
	var final_damage = maxi(1, amount - armor_reduction)
	health -= final_damage
	invuln_timer = 0.5
	hit_flash_timer = 0.15
	if health <= 0:
		health = 0
		_die()


func _die():
	is_dead = true
	_spawn_death_particles()
	get_tree().current_scene.on_player_died(self)


func _spawn_death_particles():
	for i in range(20):
		var angle = randf() * TAU
		var speed = randf_range(80, 200)
		death_particles.append({
			"pos": Vector3.ZERO,
			"vel": Vector3(cos(angle) * speed, 0, sin(angle) * speed),
			"life": randf_range(0.8, 1.5),
			"color": [Color(0.2, 0.9, 0.3), Color(1.0, 0.8, 0.2), Color(1.0, 0.4, 0.1)][randi() % 3],
			"size": randf_range(3, 8)
		})
