extends Control

signal node_purchased(key: String)
signal back_pressed

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

	# Right branch - Repair
	"unlock_repair": Vector2(200, 100),
	"repair_beams": Vector2(260, 200),
	"repair_rate": Vector2(140, 200),

	# Left branch - Chain Lightning
	"chain_damage": Vector2(-200, 400),
	"chain_retention": Vector2(-100, 400),
	"chain_count": Vector2(0, 400),

	# Building unlocks
	"unlock_wall": Vector2(-180, 200),

	# Wall upgrades
	"wall_health": Vector2(-250, 300),

	# Factory upgrades
	"factory_rate": Vector2(240, 50),

	# Turret upgrades
	"turret_spread": Vector2(100, 300),
	"turret_ice": Vector2(200, 300),
	"turret_fire": Vector2(300, 300),
	"turret_acid": Vector2(400, 300),

	# Economy / Mining
	"cost_efficiency": Vector2(-240, 50),
	"mining_yield": Vector2(-80, -300),
	"mining_range": Vector2(80, -300),

	# Building durability
	"building_health": Vector2(-320, 300),

	# Battery unlock
	"unlock_battery": Vector2(240, -50),

	# Repair Drone
	"unlock_repair_drone": Vector2(360, 100),
	"repair_drone_range": Vector2(440, 200),
	"repair_drone_speed": Vector2(360, 200),

	# Pickup Range
	"pickup_range": Vector2(-240, -300),
}

# Connections between nodes: [prerequisite, child]
const NODE_CONNECTIONS = [
	["max_health", "xp_gain"],
	["max_health", "mining_speed"],
	["max_health", "move_speed"],
	["max_health", "base_damage"],
	["max_health", "factory_speed"],
	["base_damage", "starting_iron"],
	["factory_speed", "starting_crystal"],
	["starting_iron", "turret_damage"],
	["starting_crystal", "turret_damage"],
	["turret_damage", "unlock_lightning"],
	["factory_speed", "unlock_repair"],
	["unlock_repair", "repair_beams"],
	["unlock_repair", "repair_rate"],
	["unlock_lightning", "chain_damage"],
	["unlock_lightning", "chain_retention"],
	["unlock_lightning", "chain_count"],
	["starting_iron", "unlock_wall"],
	["unlock_wall", "wall_health"],
	["factory_speed", "factory_rate"],
	["turret_damage", "turret_spread"],
	["turret_damage", "turret_ice"],
	["turret_damage", "turret_fire"],
	["turret_damage", "turret_acid"],
	["starting_iron", "cost_efficiency"],
	["mining_speed", "mining_yield"],
	["mining_speed", "mining_range"],
	["xp_gain", "pickup_range"],
	["unlock_wall", "building_health"],
	["factory_speed", "unlock_battery"],
	["unlock_repair", "unlock_repair_drone"],
	["unlock_repair_drone", "repair_drone_range"],
	["unlock_repair_drone", "repair_drone_speed"],
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
	"unlock_repair": "repair",
	"repair_beams": "repair_multi",
	"repair_rate": "repair_fast",
	"chain_damage": "chain_power",
	"chain_retention": "chain_conduct",
	"chain_count": "chain_reach",
	"unlock_wall": "wall",
	"wall_health": "wall_hp",
	"factory_rate": "factory_fast",
	"turret_spread": "spread",
	"turret_ice": "slow",
	"turret_fire": "fire_round",
	"turret_acid": "acid_round",
	"cost_efficiency": "efficiency",
	"mining_yield": "yield",
	"mining_range": "range",
	"building_health": "building_hp",
	"unlock_battery": "battery",
	"unlock_repair_drone": "repair_drone",
	"repair_drone_range": "drone_range",
	"repair_drone_speed": "drone_speed",
	"pickup_range": "magnet",
}

var hovered_node: String = ""
var tree_center: Vector2 = Vector2.ZERO
var pan_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_pan: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD = 5.0
const PAN_MARGIN = 60.0  # Extra margin beyond outermost nodes

# Controller cursor
var cursor_node: String = ""  # Currently selected node key for controller
var cursor_active: bool = false  # Whether controller cursor is shown
var cursor_input_cooldown: float = 0.0
const CURSOR_COOLDOWN = 0.15


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_prerequisites(key: String) -> Array:
	var prereqs = []
	for conn in NODE_CONNECTIONS:
		if conn[1] == key:
			prereqs.append(conn[0])
	return prereqs


func _has_prerequisites(key: String) -> bool:
	for conn in NODE_CONNECTIONS:
		if conn[1] == key:
			if GameData.research.get(conn[0], 0) <= 0:
				return false
	return true


func _process(delta):
	cursor_input_cooldown = maxf(0.0, cursor_input_cooldown - delta)
	_handle_controller_input()
	queue_redraw()


func _draw():
	tree_center = size / 2.0

	# Draw connections first (behind nodes)
	for conn in NODE_CONNECTIONS:
		var from_pos = tree_center + pan_offset + NODE_LAYOUT[conn[0]]
		var to_pos = tree_center + pan_offset + NODE_LAYOUT[conn[1]]
		var prereq_level = GameData.research.get(conn[0], 0)
		var line_color = Color(0.3, 0.7, 0.4, 0.6) if prereq_level > 0 else Color(0.3, 0.3, 0.35, 0.5)
		draw_line(from_pos, to_pos, line_color, 2.0)

	# Draw nodes
	for key in NODE_LAYOUT.keys():
		var pos = tree_center + pan_offset + NODE_LAYOUT[key]
		_draw_node(key, pos)

	# Draw controller cursor
	if cursor_active and cursor_node != "" and cursor_node in NODE_LAYOUT:
		var cpos = tree_center + pan_offset + NODE_LAYOUT[cursor_node]
		var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.005) * 0.3
		draw_arc(cpos, HALF_NODE + 6, 0, TAU, 24, Color(0.3, 0.9, 1.0, pulse), 3.0)

	# Draw tooltip for hovered node
	if hovered_node != "":
		_draw_tooltip(hovered_node)


func _draw_node(key: String, pos: Vector2):
	var data = GameData.RESEARCH_DATA.get(key, {})
	var level = GameData.research.get(key, 0)
	var max_level = data.get("max", 5)
	var cost = GameData.get_research_cost(key)
	var prereqs_met = _has_prerequisites(key)
	var can_afford = GameData.prestige_points >= cost and level < max_level and prereqs_met
	var is_maxed = level >= max_level

	# Determine border color
	var border_color: Color
	if is_maxed:
		border_color = Color(0.3, 1.0, 0.4)  # Green - fully owned
	elif not prereqs_met:
		border_color = Color(0.3, 0.3, 0.35)  # Gray - prerequisites not met
	elif level > 0:
		border_color = Color(0.9, 0.8, 0.2)  # Yellow - partially owned
	elif can_afford:
		border_color = Color(0.9, 0.8, 0.2)  # Yellow - can buy
	else:
		border_color = Color(0.8, 0.2, 0.2)  # Red - can't afford

	# Highlight if hovered
	var is_hovered = hovered_node == key
	if is_hovered:
		border_color = border_color.lightened(0.3)

	# Draw node background (dimmed if prerequisites not met)
	var rect = Rect2(pos.x - HALF_NODE, pos.y - HALF_NODE, NODE_SIZE, NODE_SIZE)
	var bg_color = Color(0.06, 0.06, 0.08) if not prereqs_met and level == 0 else Color(0.1, 0.1, 0.15)
	draw_rect(rect, bg_color)

	# Draw border
	draw_rect(rect, border_color, false, 3.0 if is_hovered else 2.0)

	# Draw lock icon if prerequisites not met and not purchased
	if not prereqs_met and level == 0:
		# Small lock overlay
		var lock_color = Color(0.4, 0.4, 0.45, 0.7)
		draw_arc(pos + Vector2(0, -4), 6, PI, TAU, 8, lock_color, 2.0)
		draw_rect(Rect2(pos.x - 7, pos.y - 4, 14, 10), lock_color)
	else:
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
			var lc = Color(0.5, 0.7, 1.0)
			draw_line(pos + Vector2(-s*0.3, -s*0.8), pos + Vector2(s*0.2, -s*0.1), lc, 4.0)
			draw_line(pos + Vector2(s*0.2, -s*0.1), pos + Vector2(-s*0.2, s*0.1), lc, 4.0)
			draw_line(pos + Vector2(-s*0.2, s*0.1), pos + Vector2(s*0.3, s*0.8), lc, 4.0)
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
			draw_line(pos + Vector2(-s*0.2, -s*0.8), pos + Vector2(s*0.15, -s*0.1), cc, 3.5)
			draw_line(pos + Vector2(s*0.15, -s*0.1), pos + Vector2(-s*0.15, s*0.1), cc, 3.5)
			draw_line(pos + Vector2(-s*0.15, s*0.1), pos + Vector2(s*0.2, s*0.6), cc, 3.5)
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
		"wall":
			# Brick wall shape
			var wc2 = Color(0.6, 0.55, 0.45)
			draw_rect(Rect2(pos.x - s*0.7, pos.y - s*0.5, s*1.4, s), wc2)
			draw_line(pos + Vector2(-s*0.7, 0), pos + Vector2(s*0.7, 0), Color(0.4, 0.35, 0.3), 1.5)
			draw_line(pos + Vector2(0, -s*0.5), pos + Vector2(0, 0), Color(0.4, 0.35, 0.3), 1.5)
			draw_line(pos + Vector2(-s*0.35, 0), pos + Vector2(-s*0.35, s*0.5), Color(0.4, 0.35, 0.3), 1.5)
			draw_line(pos + Vector2(s*0.35, 0), pos + Vector2(s*0.35, s*0.5), Color(0.4, 0.35, 0.3), 1.5)
		"wall_hp":
			# Brick with heart/plus
			var whc = Color(0.6, 0.55, 0.45)
			draw_rect(Rect2(pos.x - s*0.6, pos.y - s*0.4, s*1.2, s*0.8), whc)
			draw_line(pos + Vector2(-s*0.2, 0), pos + Vector2(s*0.2, 0), Color(0.3, 1.0, 0.4), 3.0)
			draw_line(pos + Vector2(0, -s*0.2), pos + Vector2(0, s*0.2), Color(0.3, 1.0, 0.4), 3.0)
		"factory_fast":
			# Gear with speed lines
			draw_circle(pos, s*0.4, Color(0.8, 0.6, 0.3))
			for fi in range(6):
				var fa = TAU * fi / 6.0
				draw_line(pos + Vector2.from_angle(fa) * s*0.3, pos + Vector2.from_angle(fa) * s*0.6, Color(0.8, 0.6, 0.3), 2.5)
			draw_line(pos + Vector2(s*0.4, s*0.3), pos + Vector2(s*0.8, s*0.3), Color(1.0, 0.9, 0.3), 2.0)
			draw_line(pos + Vector2(s*0.3, s*0.5), pos + Vector2(s*0.7, s*0.5), Color(1.0, 0.9, 0.3), 2.0)
		"spread":
			# Multiple barrel lines from turret
			var sc2 = Color(0.5, 0.5, 0.6)
			draw_circle(pos, s*0.4, sc2)
			draw_line(pos, pos + Vector2(s*0.8, 0), sc2, 2.5)
			draw_line(pos, pos + Vector2(s*0.7, -s*0.4), sc2, 2.5)
			draw_line(pos, pos + Vector2(s*0.7, s*0.4), sc2, 2.5)
		"ice_round":
			# Bullet with snowflake
			draw_circle(pos + Vector2(-s*0.3, 0), s*0.25, Color(0.4, 0.4, 0.5))
			draw_line(pos + Vector2(-s*0.3, 0), pos + Vector2(s*0.3, 0), Color(0.4, 0.4, 0.5), 3.0)
			for ii in range(3):
				var ia = TAU * ii / 3.0
				var ip1 = pos + Vector2(s*0.3, 0) + Vector2.from_angle(ia) * s * 0.35
				var ip2 = pos + Vector2(s*0.3, 0) + Vector2.from_angle(ia + PI) * s * 0.35
				draw_line(ip1, ip2, Color(0.5, 0.85, 1.0), 2.0)
		"fire_round":
			# Bullet with flame
			draw_circle(pos + Vector2(-s*0.3, 0), s*0.25, Color(0.4, 0.4, 0.5))
			draw_line(pos + Vector2(-s*0.3, 0), pos + Vector2(s*0.1, 0), Color(0.4, 0.4, 0.5), 3.0)
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(s*0.1, s*0.3),
				pos + Vector2(s*0.3, -s*0.1),
				pos + Vector2(s*0.5, s*0.3),
				pos + Vector2(s*0.6, -s*0.4),
				pos + Vector2(s*0.8, s*0.3),
				pos + Vector2(s*0.45, s*0.6),
			]), Color(1.0, 0.5, 0.1))
		"acid_round":
			# Bullet with droplets
			draw_circle(pos + Vector2(-s*0.3, 0), s*0.25, Color(0.4, 0.4, 0.5))
			draw_line(pos + Vector2(-s*0.3, 0), pos + Vector2(s*0.1, 0), Color(0.4, 0.4, 0.5), 3.0)
			draw_circle(pos + Vector2(s*0.3, -s*0.2), s*0.15, Color(0.3, 0.9, 0.2))
			draw_circle(pos + Vector2(s*0.5, s*0.1), s*0.12, Color(0.3, 0.9, 0.2))
			draw_circle(pos + Vector2(s*0.2, s*0.3), s*0.1, Color(0.3, 0.9, 0.2))
		"efficiency":
			# Coins/discount - circle with % sign
			draw_circle(pos, s*0.6, Color(0.9, 0.75, 0.3))
			draw_circle(pos, s*0.4, Color(0.7, 0.55, 0.2))
			draw_line(pos + Vector2(-s*0.2, s*0.3), pos + Vector2(s*0.2, -s*0.3), Color(1.0, 0.9, 0.5), 2.0)
		"yield":
			# Pile of ore nuggets
			draw_circle(pos + Vector2(-s*0.3, s*0.2), s*0.3, Color(0.7, 0.6, 0.4))
			draw_circle(pos + Vector2(s*0.3, s*0.2), s*0.3, Color(0.7, 0.6, 0.4))
			draw_circle(pos + Vector2(0, -s*0.1), s*0.35, Color(0.8, 0.7, 0.5))
			draw_circle(pos + Vector2(0, -s*0.1), s*0.15, Color(1.0, 0.9, 0.6))
		"range":
			# Expanding circle with arrow
			draw_arc(pos, s*0.4, 0, TAU, 16, Color(0.5, 0.9, 0.5), 1.5)
			draw_arc(pos, s*0.7, 0, TAU, 16, Color(0.5, 0.9, 0.5, 0.5), 1.5)
			draw_line(pos + Vector2(s*0.3, 0), pos + Vector2(s*0.8, 0), Color(0.5, 0.9, 0.5), 2.0)
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(s*0.8, -s*0.2),
				pos + Vector2(s, 0),
				pos + Vector2(s*0.8, s*0.2),
			]), Color(0.5, 0.9, 0.5))
		"building_hp":
			# Building with shield/plus
			draw_rect(Rect2(pos.x - s*0.5, pos.y - s*0.3, s, s*0.8), Color(0.5, 0.5, 0.55))
			draw_line(pos + Vector2(-s*0.2, 0), pos + Vector2(s*0.2, 0), Color(0.3, 1.0, 0.4), 3.0)
			draw_line(pos + Vector2(0, -s*0.2), pos + Vector2(0, s*0.2), Color(0.3, 1.0, 0.4), 3.0)
		"battery":
			# Battery shape
			draw_rect(Rect2(pos.x - s*0.4, pos.y - s*0.3, s*0.8, s*0.8), Color(0.4, 0.4, 0.5))
			draw_rect(Rect2(pos.x - s*0.15, pos.y - s*0.5, s*0.3, s*0.25), Color(0.5, 0.5, 0.6))
			draw_rect(Rect2(pos.x - s*0.3, pos.y + s*0.05, s*0.6, s*0.3), Color(0.3, 0.8, 0.4, 0.7))
		"repair_drone":
			# Small drone shape
			draw_circle(pos, s*0.4, Color(0.4, 0.5, 0.4))
			for di in range(4):
				var da = TAU * di / 4.0 + PI/4.0
				var arm_end = pos + Vector2.from_angle(da) * s*0.7
				draw_line(pos, arm_end, Color(0.5, 0.6, 0.5), 2.0)
				draw_circle(arm_end, s*0.15, Color(0.3, 0.8, 0.4))
		"drone_range":
			# Drone with expanding circle
			draw_circle(pos, s*0.3, Color(0.4, 0.5, 0.4))
			draw_arc(pos, s*0.6, 0, TAU, 16, Color(0.3, 0.8, 0.4, 0.6), 1.5)
			draw_arc(pos, s*0.85, 0, TAU, 16, Color(0.3, 0.8, 0.4, 0.3), 1.5)
		"drone_speed":
			# Drone with speed lines
			draw_circle(pos, s*0.3, Color(0.4, 0.5, 0.4))
			draw_line(pos + Vector2(-s*0.6, 0), pos + Vector2(-s*0.3, 0), Color(0.3, 0.8, 0.4), 2.0)
			draw_line(pos + Vector2(s*0.4, s*0.2), pos + Vector2(s*0.8, s*0.2), Color(1.0, 0.9, 0.3), 2.0)
			draw_line(pos + Vector2(s*0.3, s*0.5), pos + Vector2(s*0.7, s*0.5), Color(1.0, 0.9, 0.3), 2.0)
		"magnet":
			# U-shaped magnet
			var mc2 = Color(1.0, 0.85, 0.3)
			draw_arc(pos + Vector2(0, s*0.1), s*0.5, PI, TAU, 12, mc2, 3.0)
			draw_line(pos + Vector2(-s*0.5, s*0.1), pos + Vector2(-s*0.5, -s*0.6), Color(1.0, 0.3, 0.3), 3.0)
			draw_line(pos + Vector2(s*0.5, s*0.1), pos + Vector2(s*0.5, -s*0.6), Color(0.3, 0.5, 1.0), 3.0)
			# Field lines
			draw_arc(pos + Vector2(0, s*0.1), s*0.8, PI + 0.3, TAU - 0.3, 8, Color(1.0, 0.9, 0.3, 0.3), 1.5)


func _draw_tooltip(key: String):
	var data = GameData.RESEARCH_DATA.get(key, {})
	var level = GameData.research.get(key, 0)
	var max_level = data.get("max", 5)
	var cost = GameData.get_research_cost(key)
	var is_maxed = level >= max_level
	var prereqs_met = _has_prerequisites(key)

	var name_text = data.get("name", key)
	var desc_text = data.get("desc", "")
	var level_text = "Level: %d / %d" % [level, max_level]
	var cost_text = "MAXED" if is_maxed else "Cost: %d P" % cost

	# Build prerequisite text if needed
	var prereq_text = ""
	if not prereqs_met and not is_maxed:
		var missing = []
		for conn in NODE_CONNECTIONS:
			if conn[1] == key and GameData.research.get(conn[0], 0) <= 0:
				var prereq_data = GameData.RESEARCH_DATA.get(conn[0], {})
				missing.append(prereq_data.get("name", conn[0]))
		prereq_text = "Requires: " + ", ".join(missing)

	var font = ThemeDB.fallback_font
	var pos = tree_center + pan_offset + NODE_LAYOUT[key]

	# Position tooltip to the right of node, or left if too close to edge
	var tooltip_x = pos.x + HALF_NODE + 15
	var tooltip_width = 200.0
	if tooltip_x + tooltip_width > size.x - 20:
		tooltip_x = pos.x - HALF_NODE - tooltip_width - 15

	var tooltip_height = 90.0
	if prereq_text != "":
		tooltip_height += 18.0
	var tooltip_rect = Rect2(tooltip_x, pos.y - 40, tooltip_width, tooltip_height)

	# Background
	draw_rect(tooltip_rect, Color(0.05, 0.05, 0.1, 0.95))
	draw_rect(tooltip_rect, Color(0.4, 0.6, 0.8), false, 2.0)

	# Text
	var text_x = tooltip_rect.position.x + 10
	var text_y = tooltip_rect.position.y + 20
	draw_string(font, Vector2(text_x, text_y), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.9, 1.0))
	draw_string(font, Vector2(text_x, text_y + 20), desc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(text_x, text_y + 38), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.8))

	var cost_color = Color(0.3, 1.0, 0.5) if is_maxed else (Color(1.0, 0.9, 0.3) if GameData.prestige_points >= cost and prereqs_met else Color(1.0, 0.4, 0.4))
	draw_string(font, Vector2(text_x, text_y + 56), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cost_color)

	if prereq_text != "":
		draw_string(font, Vector2(text_x, text_y + 74), prereq_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.5, 0.3))


func _clamp_pan():
	# Calculate tree center (average of all node positions) and extents
	var avg = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	for pos in NODE_LAYOUT.values():
		avg += pos
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	avg /= NODE_LAYOUT.size()

	# Tree half-extent with padding
	var tree_half = (max_pos - min_pos) / 2.0 + Vector2(HALF_NODE + PAN_MARGIN, HALF_NODE + PAN_MARGIN)
	var view_half = size / 2.0

	# Center offset: pan_offset that places tree center at screen center
	var center_pan = -avg

	# Allow panning only as far as needed to see edges
	var max_pan_x = maxf(0.0, tree_half.x - view_half.x)
	var max_pan_y = maxf(0.0, tree_half.y - view_half.y)
	pan_offset.x = clampf(pan_offset.x, center_pan.x - max_pan_x, center_pan.x + max_pan_x)
	pan_offset.y = clampf(pan_offset.y, center_pan.y - max_pan_y, center_pan.y + max_pan_y)


func activate_cursor():
	cursor_active = true
	if cursor_node == "" or cursor_node not in NODE_LAYOUT:
		cursor_node = "max_health"
	hovered_node = cursor_node


func _handle_controller_input():
	if not is_visible_in_tree() or cursor_input_cooldown > 0.0:
		return

	# Check any connected joystick (device 0 for single player)
	var lx = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ly = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var stick = Vector2(lx, ly)
	if stick.length() > 0.4:
		cursor_active = true
		_move_cursor(stick.normalized())
		cursor_input_cooldown = CURSOR_COOLDOWN


func _move_cursor(direction: Vector2):
	if cursor_node == "" or cursor_node not in NODE_LAYOUT:
		cursor_node = "max_health"
		hovered_node = cursor_node
		return

	var current_pos = NODE_LAYOUT[cursor_node]
	var best_key = ""
	var best_score = INF

	for key in NODE_LAYOUT.keys():
		if key == cursor_node:
			continue
		var delta_pos = NODE_LAYOUT[key] - current_pos
		var dot = delta_pos.normalized().dot(direction)
		if dot < 0.3:
			continue
		# Score: prefer nodes aligned with direction, penalize distance
		var dist = delta_pos.length()
		var score = dist * (1.0 - dot * 0.5)
		if score < best_score:
			best_score = score
			best_key = key

	if best_key != "":
		cursor_node = best_key
		hovered_node = cursor_node
		# Pan to keep cursor node visible
		var node_screen_pos = tree_center + pan_offset + NODE_LAYOUT[cursor_node]
		var margin = 80.0
		if node_screen_pos.x < margin:
			pan_offset.x += margin - node_screen_pos.x
		elif node_screen_pos.x > size.x - margin:
			pan_offset.x -= node_screen_pos.x - (size.x - margin)
		if node_screen_pos.y < margin:
			pan_offset.y += margin - node_screen_pos.y
		elif node_screen_pos.y > size.y - margin:
			pan_offset.y -= node_screen_pos.y - (size.y - margin)
		_clamp_pan()


func _input(event: InputEvent):
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				if cursor_active and cursor_node != "":
					_try_purchase(cursor_node)
					get_viewport().set_input_as_handled()
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				# Back - emit signal so hud can handle it
				back_pressed.emit()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_UP:
				cursor_active = true
				_move_cursor(Vector2.UP)
				cursor_input_cooldown = CURSOR_COOLDOWN
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_DOWN:
				cursor_active = true
				_move_cursor(Vector2.DOWN)
				cursor_input_cooldown = CURSOR_COOLDOWN
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_LEFT:
				cursor_active = true
				_move_cursor(Vector2.LEFT)
				cursor_input_cooldown = CURSOR_COOLDOWN
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_RIGHT:
				cursor_active = true
				_move_cursor(Vector2.RIGHT)
				cursor_input_cooldown = CURSOR_COOLDOWN
				get_viewport().set_input_as_handled()
	# Mouse movement deactivates controller cursor
	if event is InputEventMouseMotion:
		cursor_active = false


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
				_clamp_pan()
		_update_hovered_node(event.position)


func _update_hovered_node(mouse_pos: Vector2):
	hovered_node = ""
	for key in NODE_LAYOUT.keys():
		var node_pos = tree_center + pan_offset + NODE_LAYOUT[key]
		if mouse_pos.distance_to(node_pos) < HALF_NODE + 5:
			hovered_node = key
			break


func _try_purchase(key: String):
	if not _has_prerequisites(key):
		return
	if GameData.buy_research(key):
		node_purchased.emit(key)
