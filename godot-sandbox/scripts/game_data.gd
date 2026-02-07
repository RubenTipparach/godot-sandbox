extends Node

const SAVE_PATH = "user://prestige_save.dat"

var prestige_points: int = 0
var highest_wave: int = 0
var total_bosses_killed: int = 0
var total_runs: int = 0

# Prestige unlocks: starting wave levels
var unlocked_start_waves: Array = [1]  # Always can start at wave 1

# Prestige costs for each starting wave unlock
const PRESTIGE_COSTS = {
	5: 10,
	10: 30,
	15: 60,
	20: 100,
}

# Research tree - permanent upgrades
var research: Dictionary = {
	"starting_iron": 0,
	"starting_crystal": 0,
	"max_health": 0,
	"move_speed": 0,
	"base_damage": 0,
	"turret_damage": 0,
	"factory_speed": 0,
	"mining_speed": 0,
	"xp_gain": 0,
	"unlock_lightning": 0,
	"unlock_repair": 0,
	"repair_beams": 0,
	"repair_rate": 0,
	"chain_damage": 0,
	"chain_retention": 0,
	"chain_count": 0,
	"unlock_wall": 0,
	"wall_health": 0,
	"factory_rate": 0,
	"turret_ice": 0,
	"turret_fire": 0,
	"turret_acid": 0,
	"turret_spread": 0,
	"unlock_battery": 0,
	"cost_efficiency": 0,
	"mining_yield": 0,
	"mining_range": 0,
	"building_health": 0,
	"unlock_repair_drone": 0,
	"repair_drone_range": 0,
	"repair_drone_speed": 0,
}

const RESEARCH_DATA = {
	"starting_iron": {"name": "Iron Stockpile", "desc": "+10 starting iron", "max": 10, "cost": [5, 8, 12, 18, 25, 35, 50, 70, 100, 150]},
	"starting_crystal": {"name": "Crystal Cache", "desc": "+5 starting crystal", "max": 10, "cost": [5, 8, 12, 18, 25, 35, 50, 70, 100, 150]},
	"max_health": {"name": "Fortitude", "desc": "+10 max HP", "max": 10, "cost": [8, 12, 18, 28, 40, 55, 75, 100, 140, 200]},
	"move_speed": {"name": "Agility", "desc": "+5% move speed", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"base_damage": {"name": "Firepower", "desc": "+2 base damage", "max": 5, "cost": [15, 30, 50, 80, 120]},
	"turret_damage": {"name": "Turret Tech", "desc": "+2 turret damage", "max": 5, "cost": [12, 25, 45, 70, 100]},
	"factory_speed": {"name": "Automation", "desc": "+10% factory speed", "max": 5, "cost": [12, 25, 45, 70, 100]},
	"mining_speed": {"name": "Excavation", "desc": "+10% mining speed", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"xp_gain": {"name": "Wisdom", "desc": "+10% XP gain", "max": 5, "cost": [15, 30, 50, 80, 120]},
	"unlock_lightning": {"name": "Lightning Tech", "desc": "Unlock Lightning Tower", "max": 1, "cost": [20]},
	"unlock_repair": {"name": "Repair Beams", "desc": "Repair nearby buildings", "max": 1, "cost": [5]},
	"repair_beams": {"name": "Multi-Repair", "desc": "+1 repair beam", "max": 4, "cost": [15, 30, 50, 80]},
	"repair_rate": {"name": "Rapid Repair", "desc": "+2 HP per tick", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"chain_damage": {"name": "Arc Power", "desc": "+3 chain damage", "max": 5, "cost": [12, 25, 45, 70, 100]},
	"chain_retention": {"name": "Conductivity", "desc": "+8% chain retention", "max": 5, "cost": [15, 30, 50, 80, 120]},
	"chain_count": {"name": "Arc Reach", "desc": "+1 chain bounce", "max": 3, "cost": [20, 40, 70]},
	"unlock_wall": {"name": "Fortification", "desc": "Double wall HP", "max": 1, "cost": [10]},
	"wall_health": {"name": "Reinforced Walls", "desc": "+20 wall HP", "max": 5, "cost": [8, 15, 25, 40, 60]},
	"factory_rate": {"name": "Production Line", "desc": "+15% factory rate", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"turret_ice": {"name": "Cryo Tech", "desc": "Unlock Slow Tower", "max": 1, "cost": [20]},
	"turret_fire": {"name": "Flame Tech", "desc": "Unlock Flame Turret", "max": 1, "cost": [15]},
	"turret_acid": {"name": "Acid Tech", "desc": "Unlock Acid Turret", "max": 1, "cost": [20]},
	"turret_spread": {"name": "Multi-Barrel", "desc": "+1 turret bullet", "max": 4, "cost": [20, 40, 70, 110]},
	"unlock_battery": {"name": "Battery Tech", "desc": "Unlock Battery building", "max": 1, "cost": [15]},
	"cost_efficiency": {"name": "Cost Efficiency", "desc": "-8% building costs", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"mining_yield": {"name": "Rich Veins", "desc": "+15% mining yield", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"mining_range": {"name": "Long Reach", "desc": "+15 mining range", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"building_health": {"name": "Reinforcement", "desc": "+10% building HP", "max": 5, "cost": [12, 25, 45, 70, 100]},
	"unlock_repair_drone": {"name": "Repair Drone", "desc": "Unlock Repair Drone", "max": 1, "cost": [25]},
	"repair_drone_range": {"name": "Drone Range", "desc": "+20 drone repair range", "max": 5, "cost": [10, 20, 35, 55, 80]},
	"repair_drone_speed": {"name": "Drone Efficiency", "desc": "+1 HP/tick repair", "max": 5, "cost": [10, 20, 35, 55, 80]},
}


func _ready():
	load_data()


func add_prestige(amount: int):
	prestige_points += amount
	save_data()


func can_unlock_wave(wave: int) -> bool:
	if wave in unlocked_start_waves:
		return false
	if not PRESTIGE_COSTS.has(wave):
		return false
	return prestige_points >= PRESTIGE_COSTS[wave]


func unlock_start_wave(wave: int) -> bool:
	if not can_unlock_wave(wave):
		return false
	prestige_points -= PRESTIGE_COSTS[wave]
	unlocked_start_waves.append(wave)
	unlocked_start_waves.sort()
	save_data()
	return true


func get_available_start_waves() -> Array:
	return unlocked_start_waves.duplicate()


func record_run(wave_reached: int, bosses_killed: int):
	if wave_reached > highest_wave:
		highest_wave = wave_reached
	total_bosses_killed += bosses_killed
	total_runs += 1
	# Prestige is now earned by collecting physical orb drops during gameplay
	# Auto-unlock starting waves based on progress
	_auto_unlock_waves(wave_reached)
	save_data()


func _auto_unlock_waves(wave_reached: int):
	# Unlock starting waves for any wave the player has surpassed
	for wave in [5, 10, 15, 20]:
		if wave_reached >= wave and not (wave in unlocked_start_waves):
			unlocked_start_waves.append(wave)
	unlocked_start_waves.sort()


func get_research_cost(key: String) -> int:
	if not RESEARCH_DATA.has(key):
		return 999999
	var level = research.get(key, 0)
	var data = RESEARCH_DATA[key]
	if level >= data["max"]:
		return 0  # Already maxed
	return data["cost"][level]


func can_buy_research(key: String) -> bool:
	var cost = get_research_cost(key)
	if cost == 0:
		return false  # Already maxed
	return prestige_points >= cost


func buy_research(key: String) -> bool:
	if not can_buy_research(key):
		return false
	var cost = get_research_cost(key)
	prestige_points -= cost
	research[key] = research.get(key, 0) + 1
	save_data()
	return true


func get_research_bonus(key: String) -> float:
	var level = research.get(key, 0)
	match key:
		"starting_iron": return level * 10.0
		"starting_crystal": return level * 5.0
		"max_health": return level * 10.0
		"move_speed": return level * 0.05
		"base_damage": return level * 2.0
		"turret_damage": return level * 2.0
		"factory_speed": return level * 0.10
		"mining_speed": return level * 0.10
		"xp_gain": return level * 0.10
		"unlock_lightning": return level * 1.0
		"unlock_repair": return level * 1.0
		"repair_beams": return level * 1.0
		"repair_rate": return level * 2.0
		"chain_damage": return level * 3.0
		"chain_retention": return level * 0.08
		"chain_count": return level * 1.0
		"unlock_wall": return level * 1.0
		"wall_health": return level * 20.0
		"factory_rate": return level * 0.15
		"turret_ice": return level * 1.0
		"turret_fire": return level * 1.0
		"turret_acid": return level * 1.0
		"turret_spread": return level * 1.0
		"unlock_battery": return level * 1.0
		"cost_efficiency": return level * 0.08
		"mining_yield": return level * 0.15
		"mining_range": return level * 15.0
		"building_health": return level * 0.10
		"unlock_repair_drone": return level * 1.0
		"repair_drone_range": return level * 20.0
		"repair_drone_speed": return level * 1.0
	return 0.0


func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"prestige": prestige_points,
			"highest_wave": highest_wave,
			"bosses_killed": total_bosses_killed,
			"total_runs": total_runs,
			"unlocked_waves": unlocked_start_waves,
			"research": research,
		}
		file.store_var(data)
		file.close()


func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				prestige_points = data.get("prestige", 0)
				highest_wave = data.get("highest_wave", 0)
				total_bosses_killed = data.get("bosses_killed", 0)
				total_runs = data.get("total_runs", 0)
				unlocked_start_waves = data.get("unlocked_waves", [1])
				if not 1 in unlocked_start_waves:
					unlocked_start_waves.insert(0, 1)
				var saved_research = data.get("research", {})
				for key in research.keys():
					research[key] = saved_research.get(key, 0)
				# Auto-unlock waves based on stored highest wave (for saves before this feature)
				_auto_unlock_waves(highest_wave)
