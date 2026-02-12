class_name GameConfig
extends Resource

@export var game_version: String = "dev"

# =============================================================================
# WORLD
# =============================================================================
@export_group("Lighting")
@export var ambient_light_color: Color = Color(0.15, 0.14, 0.12)
@export var directional_light_energy: float = 1.2
@export var player_light_energy: float = 3.0
@export var player_light_range: float = 120.0
@export var building_light_energy: float = 2.0
@export var building_light_range: float = 80.0
@export var hq_light_energy: float = 4.0
@export var hq_light_range: float = 150.0
@export var resource_iron_light_color: Color = Color(0.9, 0.25, 0.15)
@export var resource_iron_light_energy: float = 3.0
@export var resource_iron_light_range: float = 40.0
@export var resource_crystal_light_color: Color = Color(0.3, 0.5, 1.0)
@export var resource_crystal_light_energy: float = 4.0
@export var resource_crystal_light_range: float = 50.0

@export_group("Debug")
@export var debug_overlay_default: bool = false

@export_group("World")
@export var map_half_size: float = 1000.0
@export var wave_interval: float = 20.0
@export var first_wave_delay: float = 45.0
@export var resource_regen_interval: float = 30.0
@export var base_max_resources: int = 30
@export var resources_per_wave: int = 3
@export var powerup_spawn_interval: float = 25.0
@export var max_powerups: int = 5

# =============================================================================
# PLAYER
# =============================================================================
@export_group("Player")
@export var player_speed: float = 250.0
@export var player_health: int = 100
@export var shoot_cooldown: float = 0.25
@export var bullet_damage: int = 10
@export var mine_range: float = 80.0
@export var mine_interval: float = 0.5
@export var gem_collect_range: float = 20.0
@export var build_range: float = 300.0
@export var base_xp_to_level: int = 15
@export var xp_per_level_scale: int = 12

# =============================================================================
# POWERUPS
# =============================================================================
@export_group("Powerups")
@export var magnet_duration: float = 8.0
@export var magnet_range: float = 500.0
@export var mining_boost_duration: float = 30.0
@export var mining_boost_multiplier: int = 5
@export var heal_powerup_amount: int = 50
@export var nuke_damage: int = 50
@export var nuke_range: float = 250.0
@export var nuke_expand_speed: float = 300.0

# =============================================================================
# BULLET
# =============================================================================
@export_group("Bullet")
@export var shoot_range: float = 600.0
@export var bullet_speed: float = 450.0
@export var bullet_lifetime: float = 2.0
@export var bullet_hit_radius: float = 14.0
@export var chain_base_retention: float = 0.6
@export var chain_range: float = 120.0

# =============================================================================
# BUILDING COSTS
# =============================================================================
@export_group("Building Costs")
@export var cost_turret_iron: int = 10
@export var cost_turret_crystal: int = 5
@export var cost_factory_iron: int = 20
@export var cost_factory_crystal: int = 10
@export var cost_wall_iron: int = 5
@export var cost_wall_crystal: int = 0
@export var cost_lightning_iron: int = 15
@export var cost_lightning_crystal: int = 10
@export var cost_slow_iron: int = 12
@export var cost_slow_crystal: int = 8
@export var cost_pylon_iron: int = 8
@export var cost_pylon_crystal: int = 3
@export var cost_power_plant_iron: int = 25
@export var cost_power_plant_crystal: int = 15
@export var cost_battery_iron: int = 15
@export var cost_battery_crystal: int = 8
@export var cost_flame_turret_iron: int = 18
@export var cost_flame_turret_crystal: int = 10
@export var cost_acid_turret_iron: int = 20
@export var cost_acid_turret_crystal: int = 12
@export var cost_repair_drone_iron: int = 22
@export var cost_repair_drone_crystal: int = 12

@export_group("Cost Scaling")
@export var cost_scale_default: float = 1.5
@export var cost_scale_wall: float = 1.15
@export var cost_scale_pylon: float = 1.15

# =============================================================================
# BUILDING HP
# =============================================================================
@export_group("Building HP")
@export var hp_hq: int = 200
@export var hp_turret: int = 50
@export var hp_factory: int = 80
@export var hp_power_plant: int = 100
@export var hp_lightning: int = 60
@export var hp_slow: int = 50
@export var hp_pylon: int = 40
@export var hp_wall: int = 150
@export var hp_battery: int = 60
@export var hp_flame_turret: int = 55
@export var hp_acid_turret: int = 50
@export var hp_repair_drone: int = 40

# =============================================================================
# POWER SYSTEM
# =============================================================================
@export_group("Power System")
@export var hq_power_gen: float = 10.0
@export var power_plant_gen: float = 40.0
@export var hq_energy_storage: float = 200.0
@export var battery_energy_storage: float = 50.0
@export var power_range_hq: float = 150.0
@export var power_range_plant: float = 120.0
@export var power_range_pylon: float = 150.0

@export_group("Power Consumption")
@export var power_turret: float = 5.0
@export var power_factory: float = 8.0
@export var power_lightning: float = 10.0
@export var power_slow: float = 8.0
@export var power_pylon: float = 2.0
@export var power_flame_turret: float = 8.0
@export var power_acid_turret: float = 7.0
@export var power_repair_drone: float = 6.0

# =============================================================================
# TURRET
# =============================================================================
@export_group("Turret")
@export var turret_shoot_interval: float = 1.0
@export var turret_range: float = 250.0
@export var turret_base_damage: int = 8

# =============================================================================
# FACTORY
# =============================================================================
@export_group("Factory")
@export var factory_generate_interval: float = 10.0
@export var factory_iron_per_cycle: int = 2
@export var factory_crystal_per_cycle: int = 1

# =============================================================================
# LIGHTNING TOWER
# =============================================================================
@export_group("Lightning Tower")
@export var lightning_zap_interval: float = 1.5
@export var lightning_range: float = 180.0
@export var lightning_damage: int = 15

# =============================================================================
# SLOW TOWER
# =============================================================================
@export_group("Slow Tower")
@export var slow_range: float = 150.0
@export var slow_amount: float = 0.5

# =============================================================================
# FLAME TURRET
# =============================================================================
@export_group("Flame Turret")
@export var flame_range: float = 120.0
@export var flame_damage: int = 8
@export var flame_tick_interval: float = 0.5
@export var flame_burn_dps: float = 6.0
@export var flame_burn_duration: float = 3.0

# =============================================================================
# ACID TURRET
# =============================================================================
@export_group("Acid Turret")
@export var acid_range: float = 200.0
@export var acid_shoot_interval: float = 1.5
@export var acid_bullet_damage: int = 5
@export var acid_puddle_radius: float = 40.0
@export var acid_puddle_duration: float = 4.0
@export var acid_puddle_dps: int = 6
@export var acid_puddle_tick: float = 0.5

# =============================================================================
# REPAIR DRONE
# =============================================================================
@export_group("Repair Drone")
@export var repair_drone_range: float = 150.0
@export var repair_drone_repair_rate: float = 2.0
@export var repair_drone_tick_interval: float = 1.0

# =============================================================================
# POISON TURRET
# =============================================================================
@export_group("Poison Turret")
@export var poison_range: float = 130.0
@export var poison_dps: float = 4.0
@export var poison_duration: float = 5.0
@export var poison_tick_interval: float = 1.0
@export var hp_poison_turret: int = 50
@export var cost_poison_turret_iron: int = 22
@export var cost_poison_turret_crystal: int = 14
@export var power_poison_turret: float = 9.0

# =============================================================================
# WAVE ENEMIES
# =============================================================================
@export_group("Basic Alien")
@export var alien_basic_base_hp: int = 15
@export var alien_basic_hp_per_wave: int = 5
@export var alien_basic_base_damage: int = 5
@export var alien_basic_damage_per_wave: int = 1
@export var alien_basic_base_speed: float = 50.0
@export var alien_basic_speed_per_wave: float = 2.0
@export var alien_basic_xp: int = 1

@export_group("Fast Alien")
@export var alien_fast_base_hp: int = 8
@export var alien_fast_hp_per_wave: int = 3
@export var alien_fast_base_damage: int = 3
@export var alien_fast_damage_per_wave: int = 1
@export var alien_fast_base_speed: float = 90.0
@export var alien_fast_speed_per_wave: float = 3.0
@export var alien_fast_xp: int = 1
@export var alien_fast_start_wave: int = 4

@export_group("Ranged Alien")
@export var alien_ranged_base_hp: int = 12
@export var alien_ranged_hp_per_wave: int = 4
@export var alien_ranged_base_damage: int = 4
@export var alien_ranged_damage_per_wave: int = 1
@export var alien_ranged_base_speed: float = 40.0
@export var alien_ranged_speed_per_wave: float = 1.5
@export var alien_ranged_xp: int = 2
@export var alien_ranged_start_wave: int = 6
@export var alien_ranged_max_count: int = 6

@export_group("Boss Alien")
@export var boss_base_hp: int = 150
@export var boss_hp_per_wave: int = 50
@export var boss_base_damage: int = 10
@export var boss_damage_per_wave: int = 3
@export var boss_speed: float = 30.0
@export var boss_xp: int = 15
@export var boss_start_wave: int = 5
@export var boss_wave_interval: int = 5

# =============================================================================
# UPGRADE SCALING (per-level bonuses from in-run upgrades)
# =============================================================================
@export_group("Upgrade Scaling")
@export var move_speed_per_level: float = 0.15
@export var attack_speed_per_level: float = 0.2
@export var mining_speed_per_level: float = 0.3
@export var mining_range_per_level: float = 25.0
@export var rock_regen_per_level: float = 0.4
@export var health_per_level: int = 25
@export var health_regen_per_level: int = 2
@export var dodge_per_level: float = 0.08
@export var armor_per_level: int = 2
@export var crit_per_level: float = 0.1
@export var turret_damage_per_level: int = 3
@export var turret_fire_rate_per_level: float = 0.2
@export var factory_speed_per_level: float = 0.25
@export var aura_radius_base: float = 60.0
@export var aura_radius_per_level: float = 30.0
@export var aura_damage_per_level: int = 4
@export var burn_dps_per_level: float = 4.0
@export var slow_per_level: float = 0.15
@export var pickup_range_per_level: float = 15.0
@export var shoot_range_per_level: float = 40.0


func get_base_cost(type: String) -> Dictionary:
	match type:
		"turret": return {"iron": cost_turret_iron, "crystal": cost_turret_crystal}
		"factory": return {"iron": cost_factory_iron, "crystal": cost_factory_crystal}
		"wall": return {"iron": cost_wall_iron, "crystal": cost_wall_crystal}
		"lightning": return {"iron": cost_lightning_iron, "crystal": cost_lightning_crystal}
		"slow": return {"iron": cost_slow_iron, "crystal": cost_slow_crystal}
		"pylon": return {"iron": cost_pylon_iron, "crystal": cost_pylon_crystal}
		"power_plant": return {"iron": cost_power_plant_iron, "crystal": cost_power_plant_crystal}
		"battery": return {"iron": cost_battery_iron, "crystal": cost_battery_crystal}
		"flame_turret": return {"iron": cost_flame_turret_iron, "crystal": cost_flame_turret_crystal}
		"acid_turret": return {"iron": cost_acid_turret_iron, "crystal": cost_acid_turret_crystal}
		"repair_drone": return {"iron": cost_repair_drone_iron, "crystal": cost_repair_drone_crystal}
		"poison_turret": return {"iron": cost_poison_turret_iron, "crystal": cost_poison_turret_crystal}
	return {"iron": 10, "crystal": 5}


func get_cost_scale(type: String) -> float:
	match type:
		"wall": return cost_scale_wall
		"pylon": return cost_scale_pylon
	return cost_scale_default
