extends Node3D

var hp: int = 5000
var max_hp: int = 5000
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

# Phase system
enum Phase { ARMOR, SHIELDS, FINAL }
var current_phase: Phase = Phase.ARMOR
var armor_active: bool = true
var shield_active: bool = false

# Phase 1: Weak points
var weak_point_nodes: Array = []
var weak_points_alive: int = 3
const WEAK_POINT_COUNT = 3
var minion_timer: float = 0.0

# Phase 2: Shield generators
var generators_alive: int = 0
var telegraph_circles: Array = []
var telegraph_timer: float = 0.0
const TELEGRAPH_LIFETIME: float = 1.5
const TELEGRAPH_DAMAGE: int = 40
const TELEGRAPH_RADIUS: float = 60.0

# Phase 3: Final showdown
var pattern_timer: float = 0.0
var current_pattern: int = 0
var attack_angle: float = 0.0
var burst_timer: float = 0.0
var lightning_ray_angle: float = 0.0
const PATTERNS = ["spiral", "ring", "rotating_streams"]
var pattern_duration: float = 4.0

# Leg animation
var leg_anim_time: float = 0.0

# Contact damage
var contact_timer: float = 0.0
const CONTACT_RANGE: float = 80.0
const CONTACT_INTERVAL: float = 0.8

const RESOURCE_AVOID_FORCE = 1.5


func _ready():
	add_to_group("aliens")
	add_to_group("bosses")
	add_to_group("spider_boss")
	_spawn_weak_points()


func _spawn_weak_points():
	for i in range(WEAK_POINT_COUNT):
		var wp = Node3D.new()
		wp.set_script(load("res://scripts/weak_point.gd"))
		wp.hp = 300
		wp.max_hp = 300
		wp.boss_ref = self
		wp.wp_index = i
		wp.orbit_angle = TAU * i / WEAK_POINT_COUNT
		wp.orbit_distance = 40.0
		get_tree().current_scene.aliens_node.add_child(wp)
		wp.global_position = global_position
		weak_point_nodes.append(wp)
	weak_points_alive = WEAK_POINT_COUNT


func can_take_orbital_hit() -> bool:
	return orbital_cooldown <= 0.0


func apply_burn(dps: float, duration: float = 3.0):
	if armor_active or shield_active:
		return
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)


func apply_slow(amount: float, duration: float = 2.0):
	slow_factor = minf(slow_factor, 1.0 - clampf(amount, 0.0, 0.5))
	slow_timer = maxf(slow_timer, duration * 0.5)


func apply_poison(dps: float, duration: float = 5.0):
	if armor_active or shield_active:
		return
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, duration * 0.5)


func _process(delta):
	orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	leg_anim_time += delta

	if is_puppet:
		if target_pos != Vector3.ZERO:
			global_position = global_position.lerp(target_pos, 10.0 * delta)
		return

	# Status effects (only in final phase)
	if current_phase == Phase.FINAL:
		if burn_timer > 0:
			burn_timer -= delta
			hp -= int(burn_dps * delta)
			if hp <= 0:
				_die()
				return
		if poison_timer > 0:
			poison_timer -= delta
			hp -= int(poison_dps * delta)
			if hp <= 0:
				_die()
				return

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
			var dist = global_position.distance_to(target.global_position)
			var dir = (target.global_position - global_position).normalized()
			var approach_dist = 120.0 if current_phase == Phase.FINAL else 200.0
			if dist > approach_dist:
				var resource_avoid = _get_resource_avoidance()
				var move_dir = (dir + resource_avoid * RESOURCE_AVOID_FORCE).normalized()
				position += move_dir * speed * slow_factor * delta
				move_direction = move_dir

	# Contact damage — hurt nearby players
	contact_timer += delta
	if contact_timer >= CONTACT_INTERVAL:
		contact_timer = 0.0
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and not p.is_dead:
				if global_position.distance_to(p.global_position) < CONTACT_RANGE:
					if p.has_method("take_damage"):
						p.take_damage(damage)

	# Minion spawning (all phases)
	var minion_interval = 15.0
	match current_phase:
		Phase.ARMOR: minion_interval = 15.0
		Phase.SHIELDS: minion_interval = 10.0
		Phase.FINAL: minion_interval = 8.0
	minion_timer += delta
	if minion_timer >= minion_interval:
		minion_timer = 0.0
		_spawn_minions()

	# Phase-specific logic
	match current_phase:
		Phase.ARMOR:
			_update_armor_phase(delta)
		Phase.SHIELDS:
			_update_shields_phase(delta)
		Phase.FINAL:
			_update_final_phase(delta)


func _update_armor_phase(_delta):
	# Just walks around. Weak points handle themselves.
	pass


func _update_shields_phase(delta):
	# Telegraph circles — spawn new ones
	var interval = 2.0 + generators_alive * 0.5
	telegraph_timer += delta
	if telegraph_timer >= interval:
		telegraph_timer = 0.0
		_spawn_telegraph()

	# Update existing telegraphs
	var expired: Array = []
	for tc in telegraph_circles:
		tc["timer"] -= delta
		if tc["timer"] <= 0:
			_telegraph_strike(tc)
			expired.append(tc)
	for tc in expired:
		telegraph_circles.erase(tc)


func _update_final_phase(delta):
	pattern_timer += delta
	burst_timer += delta
	lightning_ray_angle += delta * 1.5
	_execute_pattern(delta)

	if pattern_timer >= pattern_duration:
		pattern_timer = 0.0
		current_pattern = (current_pattern + 1) % PATTERNS.size()
		burst_timer = 0.0


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


func _spawn_telegraph():
	# Pick a random position near a player or building
	var targets: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_dead:
			targets.append(p.global_position)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b):
			targets.append(b.global_position)
	if targets.is_empty():
		return
	var target_pos_pick = targets[randi() % targets.size()]
	var offset = Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	var strike_pos = target_pos_pick + offset
	telegraph_circles.append({
		"position": strike_pos,
		"timer": TELEGRAPH_LIFETIME,
		"lifetime": TELEGRAPH_LIFETIME,
	})


func _telegraph_strike(tc: Dictionary):
	var strike_pos = tc["position"]
	# Damage players and buildings in radius
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_dead:
			if p.global_position.distance_to(strike_pos) < TELEGRAPH_RADIUS:
				p.take_damage(TELEGRAPH_DAMAGE)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.has_method("take_damage"):
			if b.global_position.distance_to(strike_pos) < TELEGRAPH_RADIUS:
				b.take_damage(TELEGRAPH_DAMAGE)


func take_damage(amount: int):
	if is_puppet:
		return
	if armor_active:
		return
	if shield_active:
		return
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		_die()


func on_weak_point_destroyed(_index: int):
	weak_points_alive -= 1
	if weak_points_alive <= 0:
		_transition_to_shields()


func _transition_to_shields():
	armor_active = false
	shield_active = true
	current_phase = Phase.SHIELDS
	get_tree().current_scene.spawn_shield_generators(self)


func on_generator_destroyed():
	generators_alive -= 1
	if generators_alive <= 0:
		_transition_to_final()


func _transition_to_final():
	shield_active = false
	current_phase = Phase.FINAL
	get_tree().current_scene.show_boss_hp_bar(self)


func _spawn_minions():
	if not is_inside_tree():
		return
	get_tree().current_scene.spawn_spider_minions(global_position + Vector3(randf_range(-80, 80), 0, randf_range(-80, 80)))


func _die():
	var death_pos = global_position
	# Drop XP gems
	for i in range(10):
		var gem = preload("res://scenes/xp_gem.tscn").instantiate()
		gem.xp_value = maxi(xp_value / 10, 1)
		gem.gem_size = 2
		get_tree().current_scene.game_world_2d.add_child(gem)
		gem.global_position = death_pos + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	# Drop prestige orbs
	var orb_count = 20 * NetworkManager.get_player_count()
	for i in range(orb_count):
		var orb = preload("res://scenes/prestige_orb.tscn").instantiate()
		get_tree().current_scene.game_world_2d.add_child(orb)
		orb.global_position = death_pos + Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
		get_tree().current_scene.spawn_synced_prestige_orb(orb.global_position)
	# Clean up remaining weak points
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
