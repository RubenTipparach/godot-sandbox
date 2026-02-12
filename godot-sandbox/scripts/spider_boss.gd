extends Node3D

const CFG = preload("res://resources/game_config.tres")

var hp: int = 6000
var max_hp: int = 6000
var speed: float = 20.0
var damage: int = 30
var xp_value: int = 100
var wave_level: int = 30
var move_direction: Vector3 = Vector3.ZERO

# Status effects (same interface as boss_alien.gd)
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var orbital_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var shield_hit_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0

# Stuck detection
var _stuck_check_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _unstuck_timer: float = 0.0
var _unstuck_dir: Vector3 = Vector3.ZERO

# Multiplayer puppet
var net_id: int = 0
var is_puppet: bool = false
var target_pos: Vector3 = Vector3.ZERO

# Phase system — 6-phase boss fight
enum Phase { VULNERABLE_1, WEAKPOINTS, VULNERABLE_2, GENERATORS, FINAL, DYING }
var current_phase: Phase = Phase.VULNERABLE_1
var armor_active: bool = false
var shield_active: bool = false
var dying_timer: float = 0.0
const DYING_DURATION: float = 4.0
var dying_explosion_timer: float = 0.0

# Phase thresholds (loaded from config)
var phase2_threshold: int = 5000
var phase4_threshold: int = 2500

# Weak points (Phase 2: WEAKPOINTS)
var weak_point_nodes: Array = []
var weak_points_alive: int = 0
var minion_timer: float = 0.0

# Shield generators (Phase 4: GENERATORS)
var generators_alive: int = 0
var telegraph_circles: Array = []
var telegraph_timer: float = 0.0
var _next_telegraph_id: int = 0

# Config-driven telegraph values
var _telegraph_lifetime: float = 3.0
var _telegraph_damage: int = 80
var _telegraph_radius: float = 60.0

# Cluster spawner — spawns one beam at a time, predicting player each tick
var cluster_beams_remaining: int = 0
var cluster_spawn_timer: float = 0.0
var cluster_spread: float = 80.0
var cluster_lead: float = 80.0

# Final phase attack patterns
var pattern_timer: float = 0.0
var current_pattern: int = 0
var attack_angle: float = 0.0
var burst_timer: float = 0.0
var lightning_ray_angle: float = 0.0
var radial_telegraph_timer: float = 0.0
var radial_telegraph_angle: float = 0.0
const PATTERNS = ["spiral", "ring", "rotating_streams"]
var pattern_duration: float = 4.0

# Leg animation
var leg_anim_time: float = 0.0

# Contact damage
var contact_timer: float = 0.0
var _contact_range: float = 80.0
var _contact_interval: float = 0.8

const RESOURCE_AVOID_FORCE = 1.5


func _ready():
	add_to_group("aliens")
	add_to_group("bosses")
	add_to_group("spider_boss")
	# Load all stats from config
	hp = CFG.spider_hp
	max_hp = CFG.spider_hp
	speed = CFG.spider_speed
	damage = CFG.spider_contact_damage
	xp_value = CFG.spider_xp_value
	phase2_threshold = CFG.spider_phase2_threshold
	phase4_threshold = CFG.spider_phase4_threshold
	_telegraph_lifetime = CFG.spider_telegraph_lifetime
	_telegraph_damage = CFG.spider_telegraph_damage
	_telegraph_radius = CFG.spider_telegraph_radius
	_contact_range = CFG.spider_contact_range
	_contact_interval = CFG.spider_contact_interval
	# Show boss HP bar immediately (boss is damageable from Phase 1)
	get_tree().current_scene.show_boss_hp_bar(self)


func _spawn_weak_points():
	var wp_count = CFG.spider_weak_point_count
	for i in range(wp_count):
		var wp = Node3D.new()
		wp.set_script(load("res://scripts/weak_point.gd"))
		wp.hp = CFG.spider_weak_point_hp
		wp.max_hp = CFG.spider_weak_point_hp
		wp.boss_ref = self
		wp.wp_index = i
		wp.orbit_angle = TAU * i / wp_count
		wp.orbit_distance = CFG.spider_weak_point_orbit_distance
		get_tree().current_scene.aliens_node.add_child(wp)
		wp.global_position = global_position
		weak_point_nodes.append(wp)
	weak_points_alive = wp_count


func can_take_orbital_hit() -> bool:
	return orbital_cooldown <= 0.0


func apply_burn(dps: float, duration: float = 3.0):
	if shield_active:
		return
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)


func apply_slow(amount: float, duration: float = 2.0):
	slow_factor = minf(slow_factor, 1.0 - clampf(amount, 0.0, 0.5))
	slow_timer = maxf(slow_timer, duration * 0.5)


func apply_poison(dps: float, duration: float = 5.0):
	if shield_active:
		return
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, duration * 0.5)


func _process(delta):
	orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	shield_hit_timer = maxf(0.0, shield_hit_timer - delta)
	leg_anim_time += delta

	if current_phase == Phase.DYING:
		_update_dying(delta)
		return

	if is_puppet:
		if target_pos != Vector3.ZERO:
			global_position = global_position.lerp(target_pos, 10.0 * delta)
		return

	# Status effects apply in all vulnerable phases
	if current_phase in [Phase.VULNERABLE_1, Phase.VULNERABLE_2, Phase.FINAL]:
		if burn_timer > 0:
			burn_timer -= delta
			hp -= int(burn_dps * delta)
			if hp <= 0:
				_die()
				return
			_check_hp_thresholds()
		if poison_timer > 0:
			poison_timer -= delta
			hp -= int(poison_dps * delta)
			if hp <= 0:
				_die()
				return
			_check_hp_thresholds()

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_factor = 1.0

	# Stuck detection
	_stuck_timer += delta
	if _stuck_timer >= 0.5:
		if _stuck_check_pos != Vector3.ZERO and global_position.distance_to(_stuck_check_pos) < 3.0:
			_unstuck_timer = randf_range(1.0, 2.0)
			var escape_angle = randf() * TAU
			_unstuck_dir = Vector3(cos(escape_angle), 0, sin(escape_angle))
		_stuck_check_pos = global_position
		_stuck_timer = 0.0

	# Movement
	if _unstuck_timer > 0:
		_unstuck_timer -= delta
		position += _unstuck_dir * speed * slow_factor * delta
		move_direction = _unstuck_dir
	else:
		var target = _find_player()
		if target:
			var dir = (target.global_position - global_position).normalized()
			var resource_avoid = _get_resource_avoidance()
			var move_dir = (dir + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
			position += move_dir * speed * slow_factor * delta
			move_direction = move_dir

	# Contact damage — hurt nearby players
	contact_timer += delta
	if contact_timer >= _contact_interval:
		contact_timer = 0.0
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and not p.is_dead:
				if global_position.distance_to(p.global_position) < _contact_range:
					if p.has_method("take_damage"):
						p.take_damage(damage)

	# Minion spawning (phase-specific interval)
	var minion_interval: float
	match current_phase:
		Phase.VULNERABLE_1: minion_interval = CFG.spider_minion_interval_v1
		Phase.WEAKPOINTS: minion_interval = CFG.spider_minion_interval_wp
		Phase.VULNERABLE_2: minion_interval = CFG.spider_minion_interval_v2
		Phase.GENERATORS: minion_interval = CFG.spider_minion_interval_gen
		Phase.FINAL: minion_interval = CFG.spider_minion_interval_final
		_: minion_interval = 15.0
	minion_timer += delta
	if minion_timer >= minion_interval:
		minion_timer = 0.0
		_spawn_minions()

	# Phase-specific logic
	match current_phase:
		Phase.VULNERABLE_1:
			_update_vulnerable_1_phase(delta)
		Phase.WEAKPOINTS:
			_update_weakpoints_phase(delta)
		Phase.VULNERABLE_2:
			_update_vulnerable_2_phase(delta)
		Phase.GENERATORS:
			_update_generators_phase(delta)
		Phase.FINAL:
			_update_final_phase(delta)


func _update_vulnerable_1_phase(delta):
	# Simple aimed burst pattern (same as old ARMOR phase)
	burst_timer += delta
	attack_angle += delta * 1.5
	if burst_timer >= 1.5:
		burst_timer = 0.0
		var player = _find_player()
		if player:
			var dir = (player.global_position - global_position).normalized()
			_fire(dir, 120.0)
			var spread = 0.25
			var left = Vector3(dir.x * cos(spread) - dir.z * sin(spread), 0, dir.x * sin(spread) + dir.z * cos(spread))
			var right = Vector3(dir.x * cos(-spread) - dir.z * sin(-spread), 0, dir.x * sin(-spread) + dir.z * cos(-spread))
			_fire(left, 120.0)
			_fire(right, 120.0)


func _update_weakpoints_phase(delta):
	# Cluster telegraphs
	var interval = CFG.spider_wp_cluster_interval
	telegraph_timer += delta
	if telegraph_timer >= interval and cluster_beams_remaining <= 0:
		telegraph_timer = 0.0
		_start_cluster(
			randi_range(CFG.spider_wp_cluster_beam_min, CFG.spider_wp_cluster_beam_max),
			CFG.spider_wp_cluster_spread,
			CFG.spider_wp_cluster_lead
		)
	_tick_cluster_spawner(delta)
	_tick_telegraphs(delta)

	# Bullet pattern — rotating dual streams + aimed shots
	burst_timer += delta
	attack_angle += delta * 2.0
	if burst_timer >= 0.2:
		burst_timer = 0.0
		_fire(Vector3(cos(attack_angle), 0, sin(attack_angle)), 140.0)
		_fire(Vector3(cos(attack_angle + PI), 0, sin(attack_angle + PI)), 140.0)
	pattern_timer += delta
	if pattern_timer >= 2.5:
		pattern_timer = 0.0
		var player = _find_player()
		if player:
			var dir = (player.global_position - global_position).normalized()
			for i in range(5):
				var spread_angle = (i - 2) * 0.15
				var sd = Vector3(
					dir.x * cos(spread_angle) - dir.z * sin(spread_angle),
					0,
					dir.x * sin(spread_angle) + dir.z * cos(spread_angle)
				)
				_fire(sd, 160.0)


func _update_vulnerable_2_phase(delta):
	# Same attacks as WEAKPOINTS but boss is hittable
	var interval = CFG.spider_wp_cluster_interval
	telegraph_timer += delta
	if telegraph_timer >= interval and cluster_beams_remaining <= 0:
		telegraph_timer = 0.0
		_start_cluster(
			randi_range(CFG.spider_wp_cluster_beam_min, CFG.spider_wp_cluster_beam_max),
			CFG.spider_wp_cluster_spread,
			CFG.spider_wp_cluster_lead
		)
	_tick_cluster_spawner(delta)
	_tick_telegraphs(delta)

	# Bullet pattern — rotating dual streams + aimed shots
	burst_timer += delta
	attack_angle += delta * 2.0
	if burst_timer >= 0.2:
		burst_timer = 0.0
		_fire(Vector3(cos(attack_angle), 0, sin(attack_angle)), 140.0)
		_fire(Vector3(cos(attack_angle + PI), 0, sin(attack_angle + PI)), 140.0)
	pattern_timer += delta
	if pattern_timer >= 2.5:
		pattern_timer = 0.0
		var player = _find_player()
		if player:
			var dir = (player.global_position - global_position).normalized()
			for i in range(5):
				var spread_angle = (i - 2) * 0.15
				var sd = Vector3(
					dir.x * cos(spread_angle) - dir.z * sin(spread_angle),
					0,
					dir.x * sin(spread_angle) + dir.z * cos(spread_angle)
				)
				_fire(sd, 160.0)


func _update_generators_phase(delta):
	# Cluster telegraphs (interval scales with alive generators)
	var interval = CFG.spider_gen_cluster_base_interval + generators_alive * CFG.spider_gen_cluster_interval_per_gen
	telegraph_timer += delta
	if telegraph_timer >= interval and cluster_beams_remaining <= 0:
		telegraph_timer = 0.0
		_start_cluster(
			randi_range(CFG.spider_gen_cluster_beam_min, CFG.spider_gen_cluster_beam_max),
			CFG.spider_gen_cluster_spread,
			CFG.spider_gen_cluster_lead
		)
	_tick_cluster_spawner(delta)
	_tick_telegraphs(delta)

	# Bullet pattern — rotating dual streams + aimed shots
	burst_timer += delta
	attack_angle += delta * 2.0
	if burst_timer >= 0.2:
		burst_timer = 0.0
		_fire(Vector3(cos(attack_angle), 0, sin(attack_angle)), 140.0)
		_fire(Vector3(cos(attack_angle + PI), 0, sin(attack_angle + PI)), 140.0)
	pattern_timer += delta
	if pattern_timer >= 2.5:
		pattern_timer = 0.0
		var player = _find_player()
		if player:
			var dir = (player.global_position - global_position).normalized()
			for i in range(5):
				var spread_angle = (i - 2) * 0.15
				var sd = Vector3(
					dir.x * cos(spread_angle) - dir.z * sin(spread_angle),
					0,
					dir.x * sin(spread_angle) + dir.z * cos(spread_angle)
				)
				_fire(sd, 160.0)


func _update_final_phase(delta):
	pattern_timer += delta
	burst_timer += delta
	lightning_ray_angle += delta * 1.5
	_execute_pattern(delta)

	if pattern_timer >= pattern_duration:
		pattern_timer = 0.0
		current_pattern = (current_pattern + 1) % PATTERNS.size()
		burst_timer = 0.0

	# Cluster telegraphs (final phase config)
	telegraph_timer += delta
	if telegraph_timer >= CFG.spider_final_cluster_interval and cluster_beams_remaining <= 0:
		telegraph_timer = 0.0
		_start_cluster(
			randi_range(CFG.spider_final_cluster_beam_min, CFG.spider_final_cluster_beam_max),
			CFG.spider_final_cluster_spread,
			CFG.spider_final_cluster_lead
		)
	_tick_cluster_spawner(delta)

	# Radial telegraph lines
	radial_telegraph_timer += delta
	if radial_telegraph_timer >= CFG.spider_radial_interval:
		radial_telegraph_timer = 0.0
		_spawn_radial_telegraphs()

	_tick_telegraphs(delta)


func _execute_pattern(_delta):
	match PATTERNS[current_pattern]:
		"spiral":
			attack_angle += _delta * 3.0
			if burst_timer >= 0.1:
				burst_timer = 0.0
				_fire(Vector3(cos(attack_angle), 0, sin(attack_angle)), 180.0)
				_fire(Vector3(cos(attack_angle + PI), 0, sin(attack_angle + PI)), 180.0)
		"ring":
			if burst_timer >= 1.2:
				burst_timer = 0.0
				var n = 16
				for i in range(n):
					var a = TAU * i / n
					_fire(Vector3(cos(a), 0, sin(a)), 150.0)
		"rotating_streams":
			attack_angle += _delta * 2.0
			if burst_timer >= 0.15:
				burst_timer = 0.0
				for i in range(6):
					var a = attack_angle + TAU * i / 6.0
					_fire(Vector3(cos(a), 0, sin(a)), 160.0)


func _fire(dir: Vector3, spd: float):
	var b = preload("res://scenes/enemy_bullet.tscn").instantiate()
	var spawn_pos = global_position + dir * 30
	b.direction = dir
	b.speed = spd
	b.damage = maxi(int(damage * 0.3), 5)
	get_tree().current_scene.game_world_2d.add_child(b)
	b.global_position = spawn_pos
	get_tree().current_scene.spawn_synced_enemy_bullet(b.global_position, b.direction)


func _start_cluster(beam_count: int, spread: float, lead_dist: float):
	cluster_beams_remaining = beam_count
	cluster_spawn_timer = 0.0
	cluster_spread = spread
	cluster_lead = lead_dist


func _tick_cluster_spawner(delta):
	if cluster_beams_remaining <= 0:
		return
	cluster_spawn_timer -= delta
	if cluster_spawn_timer <= 0:
		cluster_spawn_timer = 1.0
		cluster_beams_remaining -= 1
		var player = _find_player()
		if not player:
			return
		var lead = Vector3.ZERO
		if "move_direction" in player and player.move_direction.length_squared() > 0.01:
			lead = player.move_direction.normalized() * cluster_lead
		var center = player.global_position + lead
		var offset = Vector3(randf_range(-cluster_spread, cluster_spread), 0, randf_range(-cluster_spread, cluster_spread))
		var strike_pos = center + offset
		telegraph_circles.append({
			"id": _next_telegraph_id,
			"position": strike_pos,
			"timer": _telegraph_lifetime,
			"lifetime": _telegraph_lifetime,
		})
		_next_telegraph_id += 1


func _tick_telegraphs(delta):
	var expired: Array = []
	for tc in telegraph_circles:
		tc["timer"] -= delta
		if tc["timer"] <= 0:
			_telegraph_strike(tc)
			expired.append(tc)
	for tc in expired:
		telegraph_circles.erase(tc)


func _spawn_radial_telegraphs():
	radial_telegraph_angle += randf_range(0.3, 0.8)
	var directions = CFG.spider_radial_directions
	var beams_per_dir = CFG.spider_radial_beams_per_dir
	var spacing = CFG.spider_radial_spacing
	for d in range(directions):
		var angle = radial_telegraph_angle + TAU * d / directions
		var dir = Vector3(cos(angle), 0, sin(angle))
		for b in range(beams_per_dir):
			var dist = (b + 1) * spacing
			var strike_pos = global_position + dir * dist
			var perp = Vector3(-dir.z, 0, dir.x)
			strike_pos += perp * randf_range(-15, 15)
			telegraph_circles.append({
				"id": _next_telegraph_id,
				"position": strike_pos,
				"timer": _telegraph_lifetime + b * 0.15,
				"lifetime": _telegraph_lifetime + b * 0.15,
			})
			_next_telegraph_id += 1


func _telegraph_strike(tc: Dictionary):
	var strike_pos = tc["position"]
	get_tree().current_scene.spawn_mushroom_cloud(strike_pos)
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_dead:
			if p.global_position.distance_to(strike_pos) < _telegraph_radius:
				p.take_damage(_telegraph_damage)
	var bldg_dmg = int(_telegraph_damage * CFG.boss_telegraph_building_damage_pct)
	if bldg_dmg > 0:
		for b in get_tree().get_nodes_in_group("buildings"):
			if is_instance_valid(b) and b.has_method("take_damage"):
				if b.global_position.distance_to(strike_pos) < _telegraph_radius:
					b.take_damage(bldg_dmg)


func take_damage(amount: int):
	if is_puppet:
		return
	if current_phase == Phase.DYING:
		return
	if current_phase == Phase.WEAKPOINTS or current_phase == Phase.GENERATORS:
		shield_hit_timer = 0.3
		return
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		_die()
		return
	_check_hp_thresholds()


func _check_hp_thresholds():
	if current_phase == Phase.VULNERABLE_1 and hp <= phase2_threshold:
		_transition_to_weakpoints()
	elif current_phase == Phase.VULNERABLE_2 and hp <= phase4_threshold:
		_transition_to_generators()


func _transition_to_weakpoints():
	current_phase = Phase.WEAKPOINTS
	shield_active = true
	hp = maxi(hp, phase2_threshold)
	_spawn_weak_points()
	telegraph_circles.clear()
	burst_timer = 0.0
	pattern_timer = 0.0
	telegraph_timer = 0.0


func on_weak_point_destroyed(_index: int):
	weak_points_alive -= 1
	if weak_points_alive <= 0:
		_transition_to_vulnerable_2()


func _transition_to_vulnerable_2():
	current_phase = Phase.VULNERABLE_2
	shield_active = false
	telegraph_circles.clear()
	burst_timer = 0.0
	pattern_timer = 0.0
	telegraph_timer = 0.0


func _transition_to_generators():
	current_phase = Phase.GENERATORS
	shield_active = true
	hp = maxi(hp, phase4_threshold)
	telegraph_circles.clear()
	burst_timer = 0.0
	pattern_timer = 0.0
	telegraph_timer = 0.0
	get_tree().current_scene.spawn_shield_generators(self)


func on_generator_destroyed():
	generators_alive -= 1
	if generators_alive <= 0:
		_transition_to_final()


func _transition_to_final():
	shield_active = false
	current_phase = Phase.FINAL
	telegraph_circles.clear()
	burst_timer = 0.0
	pattern_timer = 0.0
	telegraph_timer = 0.0
	radial_telegraph_timer = 0.0


func _spawn_minions():
	if not is_inside_tree():
		return
	var waves = 1
	match current_phase:
		Phase.VULNERABLE_1: waves = 1
		Phase.WEAKPOINTS: waves = 2
		Phase.VULNERABLE_2: waves = 2
		Phase.GENERATORS: waves = 2
		Phase.FINAL: waves = 4
	for i in range(waves):
		get_tree().current_scene.spawn_spider_minions(global_position + Vector3(randf_range(-120, 120), 0, randf_range(-120, 120)))


func _die():
	if current_phase == Phase.DYING:
		return
	current_phase = Phase.DYING
	dying_timer = 0.0
	dying_explosion_timer = 0.0
	telegraph_circles.clear()


func _update_dying(delta):
	dying_timer += delta
	dying_explosion_timer += delta
	if dying_explosion_timer >= 0.3:
		dying_explosion_timer = 0.0
		var offset = Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))
		get_tree().current_scene.spawn_boss_death_explosion(global_position + offset)
	if dying_timer >= DYING_DURATION:
		get_tree().current_scene.spawn_boss_death_explosion(global_position)
		_actually_die()


func _actually_die():
	var death_pos = global_position
	for i in range(10):
		var gem = preload("res://scenes/xp_gem.tscn").instantiate()
		gem.xp_value = maxi(xp_value / 10, 1)
		gem.gem_size = 2
		get_tree().current_scene.game_world_2d.add_child(gem)
		gem.global_position = death_pos + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	var orb_count = 20 * NetworkManager.get_player_count()
	for i in range(orb_count):
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		get_tree().current_scene.game_world_2d.add_child(orb)
		orb.global_position = death_pos + Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	for wp in weak_point_nodes:
		if is_instance_valid(wp):
			wp.queue_free()
	get_tree().current_scene.on_spider_boss_killed()
	queue_free()


func _find_player() -> Node3D:
	var closest: Node3D = null
	var closest_dist = 999999.0
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_dead:
			var d = global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = p
	return closest


func _get_resource_avoidance() -> Vector3:
	var avoidance = Vector3.ZERO
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r): continue
		var diff = global_position - r.global_position
		var dist = diff.length()
		var r_size = (10.0 + r.amount * 0.5) if "amount" in r else 15.0
		var avoid_dist = r_size + 25.0
		if dist < avoid_dist and dist > 0.1:
			avoidance += diff.normalized() * (1.0 - dist / avoid_dist)
	return avoidance.normalized() if avoidance.length() > 0 else Vector3.ZERO
