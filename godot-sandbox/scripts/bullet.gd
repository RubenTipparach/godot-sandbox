extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 450.0
var damage: int = 10
var lifetime: float = 2.0
var from_turret: bool = false
const HIT_RADIUS = 14.0

# Upgrade properties
var chain_count: int = 0
var burn_dps: float = 0.0
var slow_amount: float = 0.0
var crit_chance: float = 0.0
var chain_damage_bonus: int = 0
var chain_retention: float = 0.6


func _process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	for alien in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(alien): continue
		if global_position.distance_to(alien.global_position) < HIT_RADIUS:
			_on_hit(alien)
			queue_free()
			return

	queue_redraw()


func _on_hit(alien: Node2D):
	var final_damage = damage
	var is_crit = randf() < crit_chance
	if is_crit:
		final_damage = damage * 2
	alien.take_damage(final_damage)
	_spawn_damage_number(alien.global_position, final_damage, is_crit)
	if burn_dps > 0 and alien.has_method("apply_burn"):
		alien.apply_burn(burn_dps)
	if slow_amount > 0 and alien.has_method("apply_slow"):
		alien.apply_slow(slow_amount)
	if chain_count > 0:
		_chain_lightning(alien)


func _spawn_damage_number(pos: Vector2, amount: int, is_crit: bool):
	var popup = preload("res://scenes/popup_text.tscn").instantiate()
	popup.global_position = pos + Vector2(randf_range(-10, 10), -15)
	popup.text = str(amount)
	if is_crit:
		popup.text = str(amount) + "!"
		popup.color = Color(1.0, 0.8, 0.2)
	else:
		popup.color = Color(1.0, 1.0, 1.0)
	popup.velocity = Vector2(randf_range(-20, 20), -60)
	popup.lifetime = 0.8
	get_tree().current_scene.add_child(popup)


func _chain_lightning(start: Node2D):
	var prev_pos = start.global_position
	var hit = [start]
	var chain_positions = [start.global_position]

	for i in range(chain_count):
		var nearest: Node2D = null
		var nearest_dist = 120.0
		for alien in get_tree().get_nodes_in_group("aliens"):
			if not is_instance_valid(alien) or alien in hit:
				continue
			var d = prev_pos.distance_to(alien.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = alien
		if nearest:
			var chain_dmg = int(damage * chain_retention) + chain_damage_bonus
			nearest.take_damage(chain_dmg)
			if burn_dps > 0 and nearest.has_method("apply_burn"):
				nearest.apply_burn(burn_dps * 0.5)
			if slow_amount > 0 and nearest.has_method("apply_slow"):
				nearest.apply_slow(slow_amount * 0.5)
			hit.append(nearest)
			chain_positions.append(nearest.global_position)
			prev_pos = nearest.global_position
		else:
			break

	if chain_positions.size() > 1:
		var fx = Node2D.new()
		fx.set_script(preload("res://scripts/lightning_effect.gd"))
		fx.points = chain_positions
		get_tree().current_scene.add_child(fx)


func _draw():
	var color = Color(1, 0.9, 0.2)
	if from_turret:
		color = Color(0.3, 0.9, 1.0)
	if burn_dps > 0:
		color = Color(1.0, 0.5, 0.1)
	if slow_amount > 0:
		color = Color(0.4, 0.8, 1.0)

	draw_circle(Vector2.ZERO, 3.0, color)
	draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.8))
	draw_line(Vector2.ZERO, -direction * 6.0, Color(color.r, color.g, color.b, 0.3), 2.0)
