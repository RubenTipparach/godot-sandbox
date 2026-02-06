extends Node2D

const CFG = preload("res://resources/game_config.tres")

var hp: int = CFG.hp_wall
var max_hp: int = CFG.hp_wall


func _ready():
	add_to_group("buildings")
	add_to_group("walls")
	var wall_bonus = int(GameData.get_research_bonus("wall_health"))
	hp += wall_bonus
	max_hp += wall_bonus


func get_building_name() -> String:
	return "Wall"


func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		# Walls don't spawn aliens when destroyed
		queue_free()


func _draw():
	# Stone wall block
	draw_rect(Rect2(-18, -12, 36, 24), Color(0.45, 0.42, 0.38))
	draw_rect(Rect2(-18, -12, 36, 24), Color(0.35, 0.32, 0.28), false, 2.0)

	# Brick pattern
	draw_line(Vector2(-18, 0), Vector2(18, 0), Color(0.35, 0.32, 0.28), 1.0)
	draw_line(Vector2(0, -12), Vector2(0, 0), Color(0.35, 0.32, 0.28), 1.0)
	draw_line(Vector2(-9, 0), Vector2(-9, 12), Color(0.35, 0.32, 0.28), 1.0)
	draw_line(Vector2(9, 0), Vector2(9, 12), Color(0.35, 0.32, 0.28), 1.0)

	# HP bar
	draw_rect(Rect2(-18, -20, 36, 3), Color(0.3, 0, 0))
	draw_rect(Rect2(-18, -20, 36.0 * hp / max_hp, 3), Color(0, 0.8, 0))


func _process(_delta):
	queue_redraw()
