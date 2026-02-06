extends Node2D

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
var pending_build_world_pos: Vector2 = Vector2.ZERO  # Mobile: ghost position set by tap

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
}

var aura_timer: float = 0.0
var orbital_angle: float = 0.0
var regen_timer: float = 0.0

# Research bonuses (set by main.gd on game start)
var research_move_speed: float = 0.0
var research_damage: int = 0
var research_mining_speed: float = 0.0
var research_xp_gain: float = 0.0


func _ready():
	add_to_group("player")
	var cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)


func enter_build_mode(building_type: String):
	build_mode = building_type
	build_mode_cooldown = 0.15  # Brief cooldown to prevent immediate placement from the same click
	if is_mobile:
		pending_build_world_pos = global_position.snapped(Vector2(40, 40))


func cancel_build_mode():
	build_mode = ""
	build_mode_cooldown = 0.0


func is_in_build_mode() -> bool:
	return build_mode != ""


func get_mine_interval() -> float:
	return CFG.mine_interval / (1.0 + upgrades["mining_speed"] * CFG.mining_speed_per_level + research_mining_speed)


func get_mine_heads() -> int:
	return 1 + upgrades["mining_heads"]


func get_mine_range() -> float:
	return CFG.mine_range + upgrades["mining_range"] * CFG.mining_range_per_level


func get_rock_regen_multiplier() -> float:
	return 1.0 + upgrades["rock_regen"] * CFG.rock_regen_per_level


func get_gem_range() -> float:
	if magnet_timer > 0:
		return CFG.magnet_range
	return CFG.gem_collect_range


func _process(delta):
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if is_dead:
		_process_death(delta)
		queue_redraw()
		return

	var input = Vector2.ZERO
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
		input = joystick_node.input_vector
	else:
		if Input.is_action_pressed("move_up"): input.y -= 1
		if Input.is_action_pressed("move_down"): input.y += 1
		if Input.is_action_pressed("move_left"): input.x -= 1
		if Input.is_action_pressed("move_right"): input.x += 1
	if input != Vector2.ZERO:
		position += input.normalized() * CFG.player_speed * (1.0 + upgrades["move_speed"] * CFG.move_speed_per_level + research_move_speed) * delta
	position = position.clamp(Vector2(-CFG.map_half_size, -CFG.map_half_size), Vector2(CFG.map_half_size, CFG.map_half_size))

	if is_mobile:
		if look_joystick_node and look_joystick_node.input_vector != Vector2.ZERO:
			facing_angle = look_joystick_node.input_vector.angle()
		else:
			var nearest_alien = _find_nearest_alien()
			if nearest_alien:
				facing_angle = (nearest_alien.global_position - global_position).angle()
	else:
		facing_angle = (get_global_mouse_position() - global_position).angle()
	shoot_timer = maxf(0.0, shoot_timer - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	magnet_timer = maxf(0.0, magnet_timer - delta)
	mining_boost_timer = maxf(0.0, mining_boost_timer - delta)

	if shoot_timer <= 0 and get_tree().get_nodes_in_group("aliens").size() > 0:
		_shoot()
		shoot_timer = CFG.shoot_cooldown / (1.0 + upgrades["attack_speed"] * CFG.attack_speed_per_level)

	auto_mine_timer += delta
	if auto_mine_timer >= get_mine_interval():
		auto_mine_timer = 0.0
		var mine_amount = 2 + upgrades["mining_speed"]
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

	# Hotkey building (instant place at mouse)
	if Input.is_action_just_pressed("build_power_plant"):
		_try_build("power_plant")
	if Input.is_action_just_pressed("build_pylon"):
		_try_build("pylon")
	if Input.is_action_just_pressed("build_factory"):
		_try_build("factory")
	if Input.is_action_just_pressed("build_turret"):
		_try_build("turret")
	if Input.is_action_just_pressed("build_wall"):
		_try_build("wall")
	if Input.is_action_just_pressed("build_lightning"):
		if GameData.get_research_bonus("unlock_lightning") >= 1.0:
			_try_build("lightning")
	if Input.is_action_just_pressed("build_slow"):
		if GameData.get_research_bonus("turret_ice") >= 1.0:
			_try_build("slow")
	if Input.is_action_just_pressed("build_battery"):
		_try_build("battery")
	if Input.is_action_just_pressed("build_flame_turret"):
		if GameData.get_research_bonus("turret_fire") >= 1.0:
			_try_build("flame_turret")
	if Input.is_action_just_pressed("build_acid_turret"):
		if GameData.get_research_bonus("turret_acid") >= 1.0:
			_try_build("acid_turret")

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
	_collect_powerups()
	if upgrades["damage_aura"] > 0:
		_process_aura(delta)
	if upgrades["orbital_lasers"] > 0:
		_process_orbitals(delta)
	if upgrades["health_regen"] > 0:
		_process_regen(delta)

	queue_redraw()


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
		b.direction = Vector2.from_angle(facing_angle + off)
		b.global_position = global_position + Vector2.from_angle(facing_angle) * 20.0
		b.damage = CFG.bullet_damage + research_damage
		b.crit_chance = upgrades["crit_chance"] * CFG.crit_per_level
		b.chain_count = upgrades["chain_lightning"] + int(GameData.get_research_bonus("chain_count"))
		b.chain_damage_bonus = int(GameData.get_research_bonus("chain_damage"))
		b.chain_retention = CFG.chain_base_retention + GameData.get_research_bonus("chain_retention")
		b.burn_dps = upgrades["burning"] * CFG.burn_dps_per_level
		b.slow_amount = upgrades["ice"] * CFG.slow_per_level
		get_tree().current_scene.add_child(b)


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
			gem.global_position = res_pos
			gem.xp_value = maxi(1, result["amount"])
			get_tree().current_scene.add_child(gem)


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


func _collect_powerups():
	for p in get_tree().get_nodes_in_group("powerups"):
		if not is_instance_valid(p): continue
		if global_position.distance_to(p.global_position) < 30:
			_apply_powerup(p.powerup_type)
			p.queue_free()


func _find_nearest_alien() -> Node2D:
	var aliens = get_tree().get_nodes_in_group("aliens")
	var nearest: Node2D = null
	var nearest_dist = INF
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
			for a in get_tree().get_nodes_in_group("aliens"):
				if is_instance_valid(a) and not a.is_in_group("bosses"):
					a.take_damage(CFG.nuke_damage)
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
	popup.global_position = global_position + Vector2(0, -30)
	popup.text = text
	popup.color = color
	get_tree().current_scene.add_child(popup)


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
	return {
		"iron": int(base["iron"] * multiplier),
		"crystal": int(base["crystal"] * multiplier)
	}


func _try_build(type: String) -> bool:
	var bp = get_global_mouse_position().snapped(Vector2(40, 40))
	return _try_build_at(type, bp)


func confirm_build() -> bool:
	if build_mode == "" or pending_build_world_pos == Vector2.ZERO:
		return false
	return _try_build_at(build_mode, pending_build_world_pos)


func _try_build_at(type: String, bp: Vector2) -> bool:
	# Check research locks
	if type == "lightning" and GameData.get_research_bonus("unlock_lightning") < 1.0:
		return false
	if type == "slow" and GameData.get_research_bonus("turret_ice") < 1.0:
		return false
	if type == "flame_turret" and GameData.get_research_bonus("turret_fire") < 1.0:
		return false
	if type == "acid_turret" and GameData.get_research_bonus("turret_acid") < 1.0:
		return false
	if global_position.distance_to(bp) > CFG.build_range:
		return false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(bp) < 36:
			return false

	var cost = get_building_cost(type)
	if iron < cost["iron"] or crystal < cost["crystal"]:
		return false

	iron -= cost["iron"]
	crystal -= cost["crystal"]

	var building: Node2D
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

	if building:
		building.global_position = bp
		get_tree().current_scene.get_node("Buildings").add_child(building)
		return true
	return false


func can_place_at(pos: Vector2) -> bool:
	if global_position.distance_to(pos) > CFG.build_range:
		return false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(pos) < 36:
			return false
	return true


func can_afford(type: String) -> bool:
	var cost = get_building_cost(type)
	return iron >= cost["iron"] and crystal >= cost["crystal"]


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
	for i in range(cnt):
		var ang = orbital_angle + TAU * i / cnt
		var op = global_position + Vector2.from_angle(ang) * 80.0
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
	# Create explosion particles
	for i in range(20):
		var angle = randf() * TAU
		var speed = randf_range(80, 200)
		death_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(angle) * speed,
			"life": randf_range(0.8, 1.5),
			"color": [Color(0.2, 0.9, 0.3), Color(1.0, 0.8, 0.2), Color(1.0, 0.4, 0.1)][randi() % 3],
			"size": randf_range(3, 8)
		})
	get_tree().current_scene.on_player_died()


func _draw():
	if is_dead:
		# Draw explosion particles
		for p in death_particles:
			var alpha = p["life"]
			draw_circle(p["pos"], p["size"], Color(p["color"].r, p["color"].g, p["color"].b, alpha))
		return

	if upgrades["damage_aura"] > 0:
		var r = CFG.aura_radius_base + upgrades["damage_aura"] * CFG.aura_radius_per_level
		var a = 0.06 + sin(Time.get_ticks_msec() * 0.005) * 0.03
		draw_circle(Vector2.ZERO, r, Color(0.8, 0.2, 0.8, a))
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.8, 0.2, 0.8, 0.15), 1.5)

	if upgrades["orbital_lasers"] > 0:
		var cnt = upgrades["orbital_lasers"]
		for i in range(cnt):
			var ang = orbital_angle + TAU * i / cnt
			var op = Vector2.from_angle(ang) * 80.0
			draw_circle(op, 8, Color(1.0, 0.2, 0.1, 0.7))
			draw_circle(op, 4, Color(1.0, 0.8, 0.3))
			draw_arc(op, 10, 0, TAU, 16, Color(1.0, 0.3, 0.1, 0.3), 2.0)

	# Mining lasers
	for target in mine_targets:
		if is_instance_valid(target):
			var target_local = target.global_position - global_position
			var laser_color: Color
			if target.resource_type == "iron":
				laser_color = Color(1.0, 0.8, 0.3)
			else:
				laser_color = Color(0.4, 0.7, 1.0)
			var flicker = 0.7 + sin(Time.get_ticks_msec() * 0.02) * 0.3
			draw_line(Vector2.ZERO, target_local, Color(laser_color.r, laser_color.g, laser_color.b, 0.15 * flicker), 6.0)
			draw_line(Vector2.ZERO, target_local, Color(laser_color.r, laser_color.g, laser_color.b, 0.5 * flicker), 2.0)
			draw_line(Vector2.ZERO, target_local, Color(1, 1, 1, 0.4 * flicker), 1.0)
			draw_circle(target_local, 5.0 * flicker, Color(laser_color.r, laser_color.g, laser_color.b, 0.3))

	# Repair beams
	for target in repair_targets:
		if is_instance_valid(target):
			var target_local = target.global_position - global_position
			var repair_color = Color(0.3, 1.0, 0.5)
			var flicker = 0.7 + sin(Time.get_ticks_msec() * 0.02 + 1.0) * 0.3
			draw_line(Vector2.ZERO, target_local, Color(repair_color.r, repair_color.g, repair_color.b, 0.15 * flicker), 6.0)
			draw_line(Vector2.ZERO, target_local, Color(repair_color.r, repair_color.g, repair_color.b, 0.5 * flicker), 2.0)
			draw_line(Vector2.ZERO, target_local, Color(1, 1, 1, 0.4 * flicker), 1.0)
			draw_circle(target_local, 5.0 * flicker, Color(repair_color.r, repair_color.g, repair_color.b, 0.3))

	# Magnet effect
	if magnet_timer > 0:
		var mag_alpha = 0.1 + sin(Time.get_ticks_msec() * 0.008) * 0.05
		draw_arc(Vector2.ZERO, CFG.magnet_range, 0, TAU, 64, Color(0.3, 1.0, 0.5, mag_alpha), 2.0)

	# Mining boost effect
	if mining_boost_timer > 0:
		var boost_alpha = 0.15 + sin(Time.get_ticks_msec() * 0.01) * 0.1
		draw_arc(Vector2.ZERO, get_mine_range(), 0, TAU, 32, Color(1.0, 0.8, 0.3, boost_alpha), 3.0)

	# Player body with hit flash
	var pts = PackedVector2Array()
	pts.append(Vector2.from_angle(facing_angle) * 16)
	pts.append(Vector2.from_angle(facing_angle + 2.5) * 12)
	pts.append(Vector2.from_angle(facing_angle - 2.5) * 12)

	var c: Color
	if hit_flash_timer > 0:
		# Blink red when hit
		c = Color(1.0, 0.2, 0.2)
	elif invuln_timer > 0:
		c = Color(0.6, 0.95, 0.65)
	else:
		c = Color(0.2, 0.9, 0.3)

	draw_colored_polygon(pts, c)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.4, 1.0, 0.5), 1.5)

	var bw = 30.0
	draw_rect(Rect2(-bw / 2, -24, bw, 4), Color(0.3, 0, 0))
	draw_rect(Rect2(-bw / 2, -24, bw * float(health) / float(max_health), 4), Color(0, 0.9, 0))
	draw_arc(Vector2.ZERO, get_mine_range(), 0, TAU, 32, Color(1, 1, 1, 0.08), 1.0)

	# Build mode ghost preview
	if build_mode != "":
		var bp: Vector2
		if is_mobile and pending_build_world_pos != Vector2.ZERO:
			bp = pending_build_world_pos
		else:
			bp = get_global_mouse_position().snapped(Vector2(40, 40))
		var ghost_pos = bp - global_position
		var valid = can_place_at(bp) and can_afford(build_mode)
		var ghost_color = Color(0.3, 1.0, 0.4, 0.5) if valid else Color(1.0, 0.3, 0.3, 0.5)

		# Draw build range
		draw_arc(Vector2.ZERO, CFG.build_range, 0, TAU, 64, Color(0.5, 0.8, 1.0, 0.15), 2.0)

		# Draw ghost based on building type
		match build_mode:
			"turret":
				draw_circle(ghost_pos, 16, ghost_color)
				draw_arc(ghost_pos, 16, 0, TAU, 32, ghost_color.lightened(0.3), 2.0)
			"factory":
				draw_rect(Rect2(ghost_pos.x - 20, ghost_pos.y - 20, 40, 40), ghost_color)
			"wall":
				draw_rect(Rect2(ghost_pos.x - 18, ghost_pos.y - 12, 36, 24), ghost_color)
			"lightning":
				draw_rect(Rect2(ghost_pos.x - 12, ghost_pos.y - 8, 24, 20), ghost_color)
				draw_rect(Rect2(ghost_pos.x - 8, ghost_pos.y - 20, 16, 14), ghost_color)
			"slow":
				var ghost_pts = PackedVector2Array()
				ghost_pts.append(ghost_pos + Vector2(0, -22))
				ghost_pts.append(ghost_pos + Vector2(10, -5))
				ghost_pts.append(ghost_pos + Vector2(6, 0))
				ghost_pts.append(ghost_pos + Vector2(-6, 0))
				ghost_pts.append(ghost_pos + Vector2(-10, -5))
				draw_colored_polygon(ghost_pts, ghost_color)
			"pylon":
				# Pylon tower shape
				var pylon_pts = PackedVector2Array()
				pylon_pts.append(ghost_pos + Vector2(-6, 4))
				pylon_pts.append(ghost_pos + Vector2(-3, -18))
				pylon_pts.append(ghost_pos + Vector2(3, -18))
				pylon_pts.append(ghost_pos + Vector2(6, 4))
				draw_colored_polygon(pylon_pts, ghost_color)
				draw_rect(Rect2(ghost_pos.x - 10, ghost_pos.y - 20, 20, 4), ghost_color)
			"power_plant":
				draw_rect(Rect2(ghost_pos.x - 22, ghost_pos.y - 15, 44, 30), ghost_color)
				draw_circle(ghost_pos + Vector2(0, -8), 8, ghost_color.lightened(0.3))
			"battery":
				draw_rect(Rect2(ghost_pos.x - 14, ghost_pos.y - 18, 28, 36), ghost_color)
				draw_rect(Rect2(ghost_pos.x - 6, ghost_pos.y - 22, 12, 6), ghost_color.lightened(0.3))
			"flame_turret":
				draw_circle(ghost_pos, 16, ghost_color)
				draw_arc(ghost_pos, 16, 0, TAU, 32, ghost_color.lightened(0.3), 2.0)
				draw_arc(ghost_pos, CFG.flame_range, 0, TAU, 48, Color(1.0, 0.5, 0.1, 0.15), 1.5)
			"acid_turret":
				draw_circle(ghost_pos, 16, ghost_color)
				draw_arc(ghost_pos, 16, 0, TAU, 32, ghost_color.lightened(0.3), 2.0)
				draw_arc(ghost_pos, CFG.acid_range, 0, TAU, 48, Color(0.3, 0.9, 0.15, 0.15), 1.5)
