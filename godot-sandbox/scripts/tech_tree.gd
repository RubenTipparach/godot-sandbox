extends Control

signal node_purchased(key: String)

const NODE_SIZE = 50.0
const HALF_NODE = NODE_SIZE / 2.0

# Node positions (relative to center of tree area)
const NODE_LAYOUT = {
	# Top row - Vision/Awareness upgrades
	"xp_gain": Vector2(-120, -200),
	"mining_speed": Vector2(0, -200),
	"move_speed": Vector2(120, -200),

	# Middle-upper - Core stats
	"max_health": Vector2(0, -100),

	# Middle row - Combat/Production
	"base_damage": Vector2(-100, 0),
	"factory_speed": Vector2(100, 0),

	# Lower-middle - Resources
	"starting_iron": Vector2(-60, 100),
	"starting_crystal": Vector2(60, 100),

	# Bottom - Turret
	"turret_damage": Vector2(0, 200),

	# Bottom row - Building unlocks
	"unlock_lightning": Vector2(-100, 300),
	"unlock_slow": Vector2(100, 300),

	# Right branch - Repair
	"unlock_repair": Vector2(200, 100),
	"repair_beams": Vector2(260, 200),
	"repair_rate": Vector2(140, 200),

	# Left branch - Chain Lightning
	"chain_damage": Vector2(-200, 400),
	"chain_retention": Vector2(-100, 400),
	"chain_count": Vector2(0, 400),
}

# Connections between nodes (prerequisites)
const NODE_CONNECTIONS = [
	["max_health", "xp_gain"],
	["max_health", "mining_speed"],
	["max_health", "move_speed"],
	["max_health", "base_damage"],
	["max_health", "factory_speed"],
	["starting_iron", "base_damage"],
	["starting_crystal", "factory_speed"],
	["turret_damage", "starting_iron"],
	["turret_damage", "starting_crystal"],
	["unlock_lightning", "turret_damage"],
	["unlock_slow", "turret_damage"],
	["unlock_repair", "factory_speed"],
	["repair_beams", "unlock_repair"],
	["repair_rate", "unlock_repair"],
	["chain_damage", "unlock_lightning"],
	["chain_retention", "unlock_lightning"],
	["chain_count", "unlock_lightning"],
]

# Node icons (simple shapes drawn procedurally)
const NODE_ICONS = {
	"starting_iron": "iron",
	"starting_crystal": "crystal",
	"max_health": "health",
	"move_speed": "speed",
	"base_damage": "damage",
	"turret_damage": "turret",
	"factory_speed": "factory",
	"mining_speed": "mining",
	"xp_gain": "xp",
	"unlock_lightning": "lightning",
	"unlock_slow": "slow",
	"unlock_repair": "repair",
	"repair_beams": "repair_multi",
	"repair_rate": "repair_fast",
	"chain_damage": "chain_power",
	"chain_retention": "chain_conduct",
	"chain_count": "chain_reach",
}

var hovered_node: String = ""
var tree_center: Vector2 = Vector2.ZERO
var pan_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_pan: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD = 5.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta):
	queue_redraw()


func _draw():
	tree_center = size / 2.0

	# Draw connections first (behind nodes)
	for conn in NODE_CONNECTIONS:
		var from_pos = tree_center + pan_offset + NODE_LAYOUT[conn[0]]
		var to_pos = tree_center + pan_offset + NODE_LAYOUT[conn[1]]
		draw_line(from_pos, to_pos, Color(0.4, 0.4, 0.5), 2.0)

	# Draw nodes
	for key in NODE_LAYOUT.keys():
		var pos = tree_center + pan_offset + NODE_LAYOUT[key]
		_draw_node(key, pos)

	# Draw tooltip for hovered node
	if hovered_node != "":
		_draw_tooltip(hovered_node)


func _draw_node(key: String, pos: Vector2):
	var data = GameData.RESEARCH_DATA.get(key, {})
	var level = GameData.research.get(key, 0)
	var max_level = data.get("max", 5)
	var cost = GameData.get_research_cost(key)
	var can_afford = GameData.prestige_points >= cost and level < max_level
	var is_maxed = level >= max_level

	# Determine border color
	var border_color: Color
	if is_maxed:
		border_color = Color(0.3, 1.0, 0.4)  # Green - fully owned
	elif level > 0:
		border_color = Color(0.9, 0.8, 0.2)  # Yellow - partially owned
	elif can_afford:
		border_color = Color(0.9, 0.8, 0.2)  # Yellow - can buy
	else:
		border_color = Color(0.8, 0.2, 0.2)  # Red - locked

	# Highlight if hovered
	var is_hovered = hovered_node == key
	if is_hovered:
		border_color = border_color.lightened(0.3)

	# Draw node background
	var rect = Rect2(pos.x - HALF_NODE, pos.y - HALF_NODE, NODE_SIZE, NODE_SIZE)
	draw_rect(rect, Color(0.1, 0.1, 0.15))

	# Draw border
	draw_rect(rect, border_color, false, 3.0 if is_hovered else 2.0)

	# Draw icon
	_draw_icon(pos, NODE_ICONS.get(key, ""), is_maxed)

	# Draw level indicator dots below
	if max_level <= 10:
		var dot_y = pos.y + HALF_NODE + 8
		var total_width = (max_level - 1) * 8
		var start_x = pos.x - total_width / 2.0
		for i in range(max_level):
			var dot_pos = Vector2(start_x + i * 8, dot_y)
			var dot_color = Color(0.3, 1.0, 0.4) if i < level else Color(0.3, 0.3, 0.35)
			draw_circle(dot_pos, 2.5, dot_color)


func _draw_icon(pos: Vector2, icon_type: String, is_owned: bool):
	var icon_color = Color(0.4, 0.85, 1.0) if is_owned else Color(0.5, 0.7, 0.9)
	var s = 12.0  # Icon scale

	match icon_type:
		"iron":
			# Rock/ore shape
			var pts = PackedVector2Array([
				pos + Vector2(-s, s*0.3),
				pos + Vector2(-s*0.5, -s*0.7),
				pos + Vector2(s*0.3, -s*0.8),
				pos + Vector2(s, -s*0.2),
				pos + Vector2(s*0.6, s*0.7),
				pos + Vector2(-s*0.3, s*0.8),
			])
			draw_colored_polygon(pts, Color(0.7, 0.6, 0.5))
		"crystal":
			# Diamond shape
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, -s),
				pos + Vector2(s*0.7, 0),
				pos + Vector2(0, s),
				pos + Vector2(-s*0.7, 0),
			]), Color(0.5, 0.7, 1.0))
		"health":
			# Heart shape
			draw_circle(pos + Vector2(-s*0.35, -s*0.2), s*0.45, Color(1.0, 0.3, 0.4))
			draw_circle(pos + Vector2(s*0.35, -s*0.2), s*0.45, Color(1.0, 0.3, 0.4))
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-s*0.75, -s*0.1),
				pos + Vector2(0, s*0.8),
				pos + Vector2(s*0.75, -s*0.1),
			]), Color(1.0, 0.3, 0.4))
		"speed":
			# Running figure / arrow
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(s, 0),
				pos + Vector2(-s*0.5, -s*0.6),
				pos + Vector2(-s*0.2, 0),
				pos + Vector2(-s*0.5, s*0.6),
			]), Color(0.3, 1.0, 0.5))
		"damage":
			# Sword/blade
			draw_line(pos + Vector2(-s*0.6, s*0.6), pos + Vector2(s*0.6, -s*0.6), Color(0.9, 0.5, 0.9), 4.0)
			draw_line(pos + Vector2(-s*0.3, -s*0.1), pos + Vector2(s*0.1, -s*0.5), Color(0.9, 0.5, 0.9), 3.0)
		"turret":
			# Turret shape
			draw_circle(pos, s*0.6, Color(0.5, 0.5, 0.6))
			draw_line(pos, pos + Vector2(s, -s*0.3), Color(0.4, 0.4, 0.5), 4.0)
		"factory":
			# Gear/cog
			draw_circle(pos, s*0.5, Color(0.8, 0.6, 0.3))
			for i in range(6):
				var angle = TAU * i / 6.0
				var outer = pos + Vector2.from_angle(angle) * s*0.8
				draw_line(pos + Vector2.from_angle(angle) * s*0.4, outer, Color(0.8, 0.6, 0.3), 3.0)
		"mining":
			# Pickaxe
			draw_line(pos + Vector2(-s*0.7, s*0.7), pos + Vector2(s*0.3, -s*0.3), Color(0.6, 0.5, 0.4), 3.0)
			draw_line(pos + Vector2(s*0.3, -s*0.3), pos + Vector2(s*0.7, -s*0.7), Color(0.7, 0.7, 0.8), 4.0)
			draw_line(pos + Vector2(s*0.3, -s*0.3), pos + Vector2(s*0.7, 0), Color(0.7, 0.7, 0.8), 4.0)
		"xp":
			# Eye shape
			draw_circle(pos, s*0.7, Color(0.2, 0.5, 0.9))
			draw_circle(pos, s*0.35, Color(0.1, 0.2, 0.4))
			draw_circle(pos + Vector2(-s*0.1, -s*0.1), s*0.12, Color(1.0, 1.0, 1.0))
		"lightning":
			# Lightning bolt
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-s*0.3, -s*0.8),
				pos + Vector2(s*0.3, -s*0.1),
				pos + Vector2(-s*0.1, -s*0.1),
				pos + Vector2(s*0.3, s*0.8),
				pos + Vector2(-s*0.3, s*0.1),
				pos + Vector2(s*0.1, s*0.1),
			]), Color(0.5, 0.7, 1.0))
		"slow":
			# Ice crystal / snowflake
			for i in range(3):
				var angle = TAU * i / 3.0
				var p1 = pos + Vector2.from_angle(angle) * s * 0.8
				var p2 = pos + Vector2.from_angle(angle + PI) * s * 0.8
				draw_line(p1, p2, Color(0.5, 0.8, 1.0), 2.0)
		"repair":
			# Wrench shape
			var wc = Color(0.3, 1.0, 0.5)
			draw_line(pos + Vector2(-s*0.5, s*0.5), pos + Vector2(s*0.2, -s*0.2), wc, 3.0)
			draw_line(pos + Vector2(s*0.2, -s*0.2), pos + Vector2(s*0.6, -s*0.6), wc, 3.0)
			draw_line(pos + Vector2(s*0.2, -s*0.2), pos + Vector2(s*0.6, -s*0.0), wc, 3.0)
			draw_circle(pos + Vector2(-s*0.5, s*0.5), s*0.25, wc)
		"repair_multi":
			# Multiple beams icon
			var mc = Color(0.3, 1.0, 0.5)
			draw_circle(pos + Vector2(0, s*0.4), s*0.25, mc)
			draw_line(pos + Vector2(0, s*0.4), pos + Vector2(-s*0.6, -s*0.5), mc, 2.0)
			draw_line(pos + Vector2(0, s*0.4), pos + Vector2(0, -s*0.7), mc, 2.0)
			draw_line(pos + Vector2(0, s*0.4), pos + Vector2(s*0.6, -s*0.5), mc, 2.0)
			draw_circle(pos + Vector2(-s*0.6, -s*0.5), s*0.15, mc)
			draw_circle(pos + Vector2(0, -s*0.7), s*0.15, mc)
			draw_circle(pos + Vector2(s*0.6, -s*0.5), s*0.15, mc)
		"repair_fast":
			# Fast repair - wrench with speed lines
			var fc = Color(0.3, 1.0, 0.5)
			draw_line(pos + Vector2(-s*0.3, s*0.3), pos + Vector2(s*0.3, -s*0.3), fc, 3.0)
			draw_circle(pos + Vector2(-s*0.3, s*0.3), s*0.2, fc)
			# Speed lines
			draw_line(pos + Vector2(s*0.3, s*0.1), pos + Vector2(s*0.7, s*0.1), Color(1.0, 0.9, 0.3), 2.0)
			draw_line(pos + Vector2(s*0.2, s*0.4), pos + Vector2(s*0.6, s*0.4), Color(1.0, 0.9, 0.3), 2.0)
			draw_line(pos + Vector2(s*0.1, s*0.7), pos + Vector2(s*0.5, s*0.7), Color(1.0, 0.9, 0.3), 2.0)
		"chain_power":
			# Lightning bolt with plus sign (more damage)
			var cc = Color(0.5, 0.7, 1.0)
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-s*0.2, -s*0.8),
				pos + Vector2(s*0.2, -s*0.1),
				pos + Vector2(0, -s*0.1),
				pos + Vector2(s*0.2, s*0.6),
				pos + Vector2(-s*0.2, s*0.1),
				pos + Vector2(0, s*0.1),
			]), cc)
			# Plus sign
			draw_line(pos + Vector2(s*0.4, -s*0.5), pos + Vector2(s*0.8, -s*0.5), Color(1.0, 0.9, 0.3), 2.5)
			draw_line(pos + Vector2(s*0.6, -s*0.7), pos + Vector2(s*0.6, -s*0.3), Color(1.0, 0.9, 0.3), 2.5)
		"chain_conduct":
			# Two connected bolts (damage retention)
			var dc = Color(0.5, 0.7, 1.0)
			# First bolt
			draw_line(pos + Vector2(-s*0.7, -s*0.4), pos + Vector2(-s*0.2, 0), dc, 2.5)
			draw_line(pos + Vector2(-s*0.2, 0), pos + Vector2(-s*0.5, 0), dc, 2.5)
			draw_line(pos + Vector2(-s*0.5, 0), pos + Vector2(0, s*0.4), dc, 2.5)
			# Arrow to second bolt
			draw_line(pos + Vector2(0, 0), pos + Vector2(s*0.3, 0), Color(1.0, 0.9, 0.3), 2.0)
			# Second bolt
			draw_line(pos + Vector2(s*0.2, -s*0.4), pos + Vector2(s*0.5, 0), dc, 2.5)
			draw_line(pos + Vector2(s*0.5, 0), pos + Vector2(s*0.3, 0), dc, 2.5)
			draw_line(pos + Vector2(s*0.3, 0), pos + Vector2(s*0.7, s*0.4), dc, 2.5)
		"chain_reach":
			# Lightning bolt with extending arcs (more bounces)
			var rc = Color(0.5, 0.7, 1.0)
			draw_circle(pos, s*0.3, rc)
			# Radiating arcs
			for ci in range(3):
				var ca = TAU * ci / 3.0 - PI / 6.0
				var p1 = pos + Vector2.from_angle(ca) * s * 0.4
				var p2 = pos + Vector2.from_angle(ca) * s * 0.8
				draw_line(p1, p2, rc, 2.0)
				draw_circle(p2, s*0.15, rc)


func _draw_tooltip(key: String):
	var data = GameData.RESEARCH_DATA.get(key, {})
	var level = GameData.research.get(key, 0)
	var max_level = data.get("max", 5)
	var cost = GameData.get_research_cost(key)
	var is_maxed = level >= max_level

	var name_text = data.get("name", key)
	var desc_text = data.get("desc", "")
	var level_text = "Level: %d / %d" % [level, max_level]
	var cost_text = "MAXED" if is_maxed else "Cost: %d P" % cost

	var font = ThemeDB.fallback_font
	var pos = tree_center + pan_offset + NODE_LAYOUT[key]

	# Position tooltip to the right of node, or left if too close to edge
	var tooltip_x = pos.x + HALF_NODE + 15
	var tooltip_width = 180.0
	if tooltip_x + tooltip_width > size.x - 20:
		tooltip_x = pos.x - HALF_NODE - tooltip_width - 15

	var tooltip_rect = Rect2(tooltip_x, pos.y - 40, tooltip_width, 90)

	# Background
	draw_rect(tooltip_rect, Color(0.05, 0.05, 0.1, 0.95))
	draw_rect(tooltip_rect, Color(0.4, 0.6, 0.8), false, 2.0)

	# Text
	var text_x = tooltip_rect.position.x + 10
	var text_y = tooltip_rect.position.y + 20
	draw_string(font, Vector2(text_x, text_y), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.9, 1.0))
	draw_string(font, Vector2(text_x, text_y + 20), desc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(text_x, text_y + 38), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.8))

	var cost_color = Color(0.3, 1.0, 0.5) if is_maxed else (Color(1.0, 0.9, 0.3) if GameData.prestige_points >= cost else Color(1.0, 0.4, 0.4))
	draw_string(font, Vector2(text_x, text_y + 56), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cost_color)


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = false
			drag_start_mouse = event.position
			drag_start_pan = pan_offset
		else:
			if not is_dragging and hovered_node != "":
				_try_purchase(hovered_node)
			is_dragging = false
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if event.position.distance_to(drag_start_mouse) > DRAG_THRESHOLD:
				is_dragging = true
			if is_dragging:
				pan_offset = drag_start_pan + (event.position - drag_start_mouse)
		_update_hovered_node(event.position)


func _update_hovered_node(mouse_pos: Vector2):
	hovered_node = ""
	for key in NODE_LAYOUT.keys():
		var node_pos = tree_center + pan_offset + NODE_LAYOUT[key]
		if mouse_pos.distance_to(node_pos) < HALF_NODE + 5:
			hovered_node = key
			break


func _try_purchase(key: String):
	if GameData.buy_research(key):
		node_purchased.emit(key)
