extends Node3D

var CFG = load("res://resources/game_config.tres")

# 3D scene nodes
var camera_3d: Camera3D
var _ground_mesh: MeshInstance3D
var _dir_light: DirectionalLight3D
var game_world_2d: Node3D
var mouse_world_2d: Vector3 = Vector3.ZERO

# 3D light tracking (OmniLight3D)
var building_lights: Dictionary = {}   # Node3D -> OmniLight3D
var player_lights: Dictionary = {}     # Node3D -> OmniLight3D
var alien_lights: Dictionary = {}      # Node3D -> OmniLight3D
var resource_lights: Dictionary = {}   # Node3D -> OmniLight3D
var mining_laser_beams: Dictionary = {} # target -> pool entry dict
var _laser_pool: Array = []              # Pre-created beam objects (grabbed on demand)
const LASER_POOL_SIZE = 12
var repair_beam_active: Dictionary = {} # "drone_id:target_id" -> pool entry dict
var player_repair_beams: Dictionary = {} # target -> pool entry dict
# Lightning bolt pool
var _lightning_pool: Array = []
const LIGHTNING_POOL_SIZE = 16
var lightning_beam_active: Dictionary = {} # building -> Array of pool entries
# Acid puddle 3D
var puddle_meshes: Dictionary = {}      # Node3D -> MeshInstance3D
# Pylon wire 3D
var wire_meshes: Dictionary = {}        # String (pair key) -> MeshInstance3D
var _wire_mat_powered: StandardMaterial3D
var _wire_mat_unpowered: StandardMaterial3D
# HQ light
var hq_light_3d: OmniLight3D
# 3D mesh representations (replaces SubViewport mirrors)
var building_meshes: Dictionary = {}    # Node3D -> Node3D
var player_meshes: Dictionary = {}      # Node3D -> Node3D
var alien_meshes: Dictionary = {}       # Node3D -> Node3D
var resource_meshes: Dictionary = {}    # Node3D -> Node3D
var bullet_meshes: Dictionary = {}      # Node3D -> Node3D
var gem_meshes: Dictionary = {}         # Node3D -> Node3D
var powerup_meshes: Dictionary = {}     # Node3D -> Node3D
var _powerup_textures: Dictionary = {}  # String -> ImageTexture
var orb_meshes: Dictionary = {}         # Node3D -> Node3D
var _mat_cache: Dictionary = {}         # String -> StandardMaterial3D
var resource_init_amt: Dictionary = {}   # Node3D -> int (initial amount for scale calc)
var _laser_shader: Shader                # Cached laser beam shader
var _crystal_shader: Shader              # Cached crystal shader
var _iron_material: StandardMaterial3D   # Cached iron PBR material
var hp_bar_layer: CanvasLayer            # Screen-space HP bar overlay
var hp_bar_nodes: Dictionary = {}        # Node3D -> Control (HP bar UI)
var build_preview_mesh: Node3D = null    # 3D ghost for build placement
var build_preview_type: String = ""      # Current preview building type
var aoe_meshes: Dictionary = {}          # Node3D -> MeshInstance3D (combat range rings, selected-only)
var aoe_player_mesh: MeshInstance3D = null  # Player damage aura mesh
var shoot_range_mesh: MeshInstance3D = null  # Player shoot range ring (on hover)
var _aoe_shader: Shader                  # Cached dithered AoE shader (with ring_width uniform)
# Energy grid merged-disc system (shader-based union of circles)
var _energy_proj_mesh: MeshInstance3D     # Large ground plane with energy disc shader
var _energy_proj_shader: Shader
var _energy_proj_mat: ShaderMaterial
# Nuke explosion visual
var _nuke_ring_mesh: MeshInstance3D
var _nuke_ring_mat: ShaderMaterial
var _nuke_flash_light: OmniLight3D
var _dither_occlude_shader: Shader
var _dither_occlude_mat: ShaderMaterial
var _flash_white_mat: StandardMaterial3D
var _debug_label: Label = null  # On-screen debug overlay for mobile web diagnostics

var wave_number: int = 0
var wave_timer: float = CFG.first_wave_delay
var wave_active: bool = false
var is_first_wave: bool = true  # Extra prep time on first wave of each run
var game_over: bool = false
var world_visible: bool = false  # False until game starts (menu shows clean background)
var resource_regen_timer: float = CFG.resource_regen_interval
var powerup_timer: float = 10.0
var pending_upgrades: int = 0
var upgrade_cooldown: float = 0.0
var bosses_killed: int = 0
var starting_wave: int = 1
var next_wave_direction: float = 0.0  # Angle for next wave spawn
var players: Dictionary = {}  # peer_id -> Node3D
var state_sync_timer: float = 0.0
const STATE_SYNC_INTERVAL: float = 0.05  # 20Hz
var next_net_id: int = 1
var alien_net_ids: Dictionary = {}  # net_id -> Node3D
var resource_net_ids: Dictionary = {}  # net_id -> Node3D
var player_names: Dictionary = {}  # peer_id -> String
var run_prestige: int = 0  # Prestige collected this run (host-authoritative)
var _client_own_research: Dictionary = {}  # Client's own research, saved before host override
var _waiting_for_clients: bool = false
var clients_ready: Dictionary = {}  # peer_id -> bool

# Upgrade voting (multiplayer)
var vote_active: bool = false
var vote_upgrade_keys: Array = []
var vote_choices: Dictionary = {}  # peer_id -> chosen_key (or "")
var vote_round: int = 0
var respawn_timers: Dictionary = {}  # peer_id -> float (seconds remaining)

const PLAYER_COLORS: Array = [
	Color(0.2, 0.9, 0.3),   # Green (host)
	Color(0.4, 0.6, 1.0),   # Blue
	Color(1.0, 0.5, 0.2),   # Orange
	Color(0.9, 0.3, 0.8),   # Purple
	Color(1.0, 0.9, 0.2),   # Yellow
	Color(0.2, 0.9, 0.9),   # Cyan
	Color(1.0, 0.4, 0.4),   # Red
	Color(0.6, 0.8, 0.3),   # Lime
]

# Global power system
var total_power_gen: float = 0.0
var total_power_consumption: float = 0.0
var power_bank: float = 0.0
var max_power_bank: float = 0.0
var power_on: bool = true


func get_max_resources() -> int:
	# More rocks spawn as waves progress
	return CFG.base_max_resources + wave_number * CFG.resources_per_wave


func get_regen_interval() -> float:
	var base = CFG.resource_regen_interval
	if is_instance_valid(player_node):
		base /= player_node.get_rock_regen_multiplier()
	return base


func _count_active(group: String) -> int:
	var count = 0
	for b in get_tree().get_nodes_in_group(group):
		if "manually_disabled" in b and b.manually_disabled:
			continue
		count += 1
	return count


func _update_power_system(delta):
	# Calculate generation (HQ=10, Power Plant=40)
	var hq_count = get_tree().get_nodes_in_group("hq").size()
	var all_plants = get_tree().get_nodes_in_group("power_plants").size()
	var plant_count = all_plants - hq_count  # HQ is also in power_plants group
	total_power_gen = hq_count * CFG.hq_power_gen + plant_count * CFG.power_plant_gen

	# Calculate consumption (skip manually disabled buildings)
	var turret_count = _count_active("turrets")
	var factory_count = _count_active("factories")
	var lightning_count = _count_active("lightnings")
	var slow_count = _count_active("slows")
	var pylon_count = get_tree().get_nodes_in_group("pylons").size()
	var flame_count = _count_active("flame_turrets")
	var acid_count = _count_active("acid_turrets")
	var drone_count = _count_active("repair_drones")
	var poison_count = _count_active("poison_turrets")
	total_power_consumption = turret_count * CFG.power_turret + factory_count * CFG.power_factory + lightning_count * CFG.power_lightning + slow_count * CFG.power_slow + pylon_count * CFG.power_pylon + flame_count * CFG.power_flame_turret + acid_count * CFG.power_acid_turret + drone_count * CFG.power_repair_drone + poison_count * CFG.power_poison_turret

	# Calculate energy storage capacity (HQ = 200 base, each battery = 50)
	var battery_count = get_tree().get_nodes_in_group("batteries").size()
	max_power_bank = hq_count * CFG.hq_energy_storage + battery_count * CFG.battery_energy_storage

	if total_power_gen >= total_power_consumption:
		power_on = true
		# Store surplus in bank
		if max_power_bank > 0:
			power_bank = minf(power_bank + (total_power_gen - total_power_consumption) * delta, max_power_bank)
	else:
		if max_power_bank > 0 and power_bank > 0:
			# Drain bank to cover deficit
			power_bank -= (total_power_consumption - total_power_gen) * delta
			if power_bank <= 0:
				power_bank = 0.0
				power_on = false
			else:
				power_on = true
		else:
			power_on = false


func get_factory_rates() -> Dictionary:
	var iron_per_sec = 0.0
	var crystal_per_sec = 0.0
	for f in get_tree().get_nodes_in_group("factories"):
		if not is_instance_valid(f):
			continue
		if f.is_powered():
			var interval = CFG.factory_generate_interval / (1.0 + f.speed_bonus)
			iron_per_sec += float(CFG.factory_iron_per_cycle) / interval
			crystal_per_sec += float(CFG.factory_crystal_per_cycle) / interval
	return {"iron": iron_per_sec, "crystal": crystal_per_sec}


var player_node: Node3D
var buildings_node: Node3D
var aliens_node: Node3D
var resources_node: Node3D
var powerups_node: Node3D
var hud_node: CanvasLayer
var hq_node: Node3D


func _debug_log(msg: String):
	print("[DEBUG] ", msg)
	if _debug_label:
		_debug_label.text += msg + "\n"
	# Also log via WebDebug autoload (survives even if main.gd overlay fails)
	if Engine.has_singleton("WebDebug") or has_node("/root/WebDebug"):
		var wd = get_node_or_null("/root/WebDebug")
		if wd and wd.has_method("log_msg"):
			wd.log_msg("main: " + msg)


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_log("main.gd _ready() started")
	_setup_inputs()
	_debug_log("_setup_inputs OK. Starting _create_world...")
	_create_world()
	_debug_log("_create_world OK. Waiting for user input.")


func _setup_inputs():
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("build_power_plant", KEY_1)
	_add_key_action("build_pylon", KEY_2)
	_add_key_action("build_factory", KEY_3)
	_add_key_action("build_turret", KEY_4)
	_add_key_action("build_wall", KEY_5)
	_add_key_action("build_lightning", KEY_6)
	_add_key_action("build_slow", KEY_7)
	_add_key_action("build_battery", KEY_8)
	_add_key_action("build_flame_turret", KEY_9)
	_add_key_action("build_acid_turret", KEY_0)
	_add_key_action("build_repair_drone", KEY_Q)
	_add_key_action("build_poison_turret", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)


func _create_world():
	_debug_log("  Creating WorldEnvironment...")
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.11, 0.1, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = CFG.ambient_light_color
	env_node.environment = env
	add_child(env_node)
	_debug_log("  WorldEnvironment OK")

	_debug_log("  Creating Camera3D...")
	camera_3d = Camera3D.new()
	camera_3d.fov = 50
	camera_3d.position = Vector3(0, 600, 350)
	camera_3d.rotation_degrees = Vector3(-60, 0, 0)
	add_child(camera_3d)
	_debug_log("  Camera3D OK")

	_debug_log("  Loading HUD scene...")
	var hud_scene = load("res://scenes/hud.tscn")
	hud_node = hud_scene.instantiate()
	add_child(hud_node)
	hud_node.upgrade_chosen.connect(_on_upgrade_chosen)
	hud_node.game_started.connect(_on_game_started)
	_debug_log("  HUD loaded OK. is_mobile=%s" % str(hud_node.is_mobile if "is_mobile" in hud_node else "N/A"))


func _init_game_world():
	# Called when the game actually starts (host clicks Play / player clicks wave).
	# Creates all gameplay objects, pools, shaders, etc. with loading progress.
	_debug_log("_init_game_world() started")

	# Step 1: Lighting & ground
	if is_instance_valid(hud_node):
		hud_node.show_loading("Creating world...", 0.0)
	await get_tree().process_frame

	_dir_light = DirectionalLight3D.new()
	_dir_light.rotation_degrees = Vector3(-60, 30, 0)
	_dir_light.light_energy = CFG.directional_light_energy
	_dir_light.shadow_enabled = true
	_dir_light.directional_shadow_max_distance = 1500.0
	add_child(_dir_light)

	_ground_mesh = MeshInstance3D.new()
	var ground = _ground_mesh
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2400, 2400)
	plane_mesh.subdivide_width = 60
	plane_mesh.subdivide_depth = 60
	ground.mesh = plane_mesh
	var mat = StandardMaterial3D.new()
	var ground_tex = load("res://resources/dirt_grass.png")
	if ground_tex:
		mat.albedo_texture = ground_tex
		mat.uv1_scale = Vector3(60, 60, 1)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	else:
		# Fallback for mobile/web where S3TC texture may not load
		mat.albedo_color = Color(0.35, 0.45, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	ground.material_override = mat
	add_child(ground)

	# Step 2: Game viewport & entities
	if is_instance_valid(hud_node):
		hud_node.show_loading("Setting up entities...", 0.15)
	await get_tree().process_frame

	# Container for all game entities (direct child, no SubViewport)
	game_world_2d = Node3D.new()
	game_world_2d.name = "GameWorld"
	game_world_2d.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game_world_2d)

	resources_node = Node3D.new()
	resources_node.name = "Resources"
	game_world_2d.add_child(resources_node)

	powerups_node = Node3D.new()
	powerups_node.name = "Powerups"
	game_world_2d.add_child(powerups_node)

	buildings_node = Node3D.new()
	buildings_node.name = "Buildings"
	game_world_2d.add_child(buildings_node)

	# Spawn HQ at center - if destroyed, game over
	hq_node = load("res://scenes/hq.tscn").instantiate()
	hq_node.position = Vector3.ZERO
	hq_node.destroyed.connect(_on_hq_destroyed)
	hq_node.visible = false  # Hidden; 3D standing sprite handles visuals
	buildings_node.add_child(hq_node)

	# HQ pointlight — illuminates surroundings
	hq_light_3d = OmniLight3D.new()
	hq_light_3d.light_energy = CFG.hq_light_energy
	hq_light_3d.omni_range = CFG.hq_light_range
	hq_light_3d.light_color = Color(1.0, 0.85, 0.4)
	hq_light_3d.shadow_enabled = false
	hq_light_3d.position = Vector3(0, 50, 0)
	add_child(hq_light_3d)

	var player_scene = load("res://scenes/player.tscn")
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	player_node.peer_id = 1
	player_node.is_local = true
	game_world_2d.add_child(player_node)
	player_node.level_up.connect(_on_player_level_up)
	players[1] = player_node

	aliens_node = Node3D.new()
	aliens_node.name = "Aliens"
	game_world_2d.add_child(aliens_node)

	# 3D map boundary lines (replaces 2D world_overlay)
	var hs = CFG.map_half_size
	var boundary_y = 0.12
	var boundary_color = Color(1, 0.3, 0.2, 0.8)
	var boundary_mat = StandardMaterial3D.new()
	boundary_mat.albedo_color = boundary_color
	boundary_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boundary_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var line_thickness = 1.5
	# Top edge
	var top_line = MeshInstance3D.new()
	var top_box = BoxMesh.new()
	top_box.size = Vector3(hs * 2, 0.1, line_thickness)
	top_line.mesh = top_box
	top_line.material_override = boundary_mat
	top_line.position = Vector3(0, boundary_y, -hs)
	add_child(top_line)
	# Bottom edge
	var bot_line = MeshInstance3D.new()
	bot_line.mesh = top_box
	bot_line.material_override = boundary_mat
	bot_line.position = Vector3(0, boundary_y, hs)
	add_child(bot_line)
	# Left edge
	var left_line = MeshInstance3D.new()
	var side_box = BoxMesh.new()
	side_box.size = Vector3(line_thickness, 0.1, hs * 2)
	left_line.mesh = side_box
	left_line.material_override = boundary_mat
	left_line.position = Vector3(-hs, boundary_y, 0)
	add_child(left_line)
	# Right edge
	var right_line = MeshInstance3D.new()
	right_line.mesh = side_box
	right_line.material_override = boundary_mat
	right_line.position = Vector3(hs, boundary_y, 0)
	add_child(right_line)

	# Step 3: Compile shaders
	if is_instance_valid(hud_node):
		hud_node.show_loading("Compiling shaders...", 0.35)
	await get_tree().process_frame

	_laser_shader = Shader.new()
	_laser_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 beam_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float time_offset = 0.0;
void fragment() {
	float t = TIME + time_offset;
	float pulse = 0.7 + 0.3 * sin(t * 8.0);
	float scroll = fract(UV.y * 3.0 - t * 2.0);
	float band = smoothstep(0.0, 0.15, scroll) * smoothstep(1.0, 0.85, scroll);
	float edge_glow = 1.0 - abs(UV.x - 0.5) * 2.0;
	edge_glow = pow(edge_glow, 0.5);
	float brightness = pulse * (0.6 + 0.4 * band) * edge_glow;
	ALBEDO = beam_color.rgb * brightness;
	EMISSION = beam_color.rgb * brightness * 2.0;
	ALPHA = clamp(brightness * beam_color.a, 0.0, 1.0);
}
"""
	_aoe_shader = Shader.new()
	_aoe_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 ring_color : source_color = vec4(0.3, 0.6, 1.0, 0.5);
uniform float ring_width = 0.2;
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);
	if (dist > 1.0) discard;
	vec2 sp = floor(FRAGCOORD.xy);
	float m1 = mod(sp.x + sp.y, 2.0);
	float m2 = mod(floor(sp.x * 0.5) + floor(sp.y * 0.5), 2.0);
	float threshold = (m1 * 2.0 + m2 + 0.5) / 4.0;
	float inner = 1.0 - ring_width;
	float fade_in = inner + ring_width * 0.3;
	float fade_out = 1.0 - ring_width * 0.3;
	float ring = smoothstep(inner, fade_in, dist) * (1.0 - smoothstep(fade_out, 1.0, dist));
	float fill = (1.0 - smoothstep(0.0, inner, dist)) * 0.08;
	float alpha = (ring * 0.8 + fill) * ring_color.a;
	if (alpha < threshold) discard;
	ALBEDO = ring_color.rgb;
	ALPHA = 1.0;
}
"""
	_crystal_shader = Shader.new()
	_crystal_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 crystal_color : source_color = vec4(0.2, 0.4, 0.95, 1.0);
uniform float refraction_strength = 0.08;
void fragment() {
	float t = TIME;
	float facet = abs(sin(VERTEX.x * 2.0 + VERTEX.y * 3.0 + t * 0.5));
	float shimmer = sin(t * 2.0 + VERTEX.y * 4.0) * 0.5 + 0.5;
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float fresnel = pow(edge, 2.5);
	ALBEDO = crystal_color.rgb * (0.3 + 0.2 * facet);
	METALLIC = 0.1;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	EMISSION = crystal_color.rgb * (fresnel * 1.5 + shimmer * 0.3 + facet * 0.2);
	ALPHA = 0.85 + fresnel * 0.15;
	RIM = 0.6;
	RIM_TINT = 0.3;
}
"""
	_energy_proj_shader = Shader.new()
	_energy_proj_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 disc_color : source_color = vec4(0.2, 0.5, 1.0, 0.35);
uniform int source_count = 0;
uniform vec4 sources[32];
varying vec3 world_vertex;
void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float max_cov = 0.0;
	for (int i = 0; i < source_count; i++) {
		float d = length(world_vertex.xz - sources[i].xy);
		float r = sources[i].z;
		max_cov = max(max_cov, 1.0 - smoothstep(r * 0.92, r, d));
	}
	if (max_cov < 0.01) discard;
	vec2 sp = floor(FRAGCOORD.xy);
	float m1 = mod(sp.x + sp.y, 2.0);
	float m2 = mod(floor(sp.x * 0.5) + floor(sp.y * 0.5), 2.0);
	float threshold = (m1 * 2.0 + m2 + 0.5) / 4.0;
	float alpha = max_cov * disc_color.a;
	if (alpha < threshold) discard;
	ALBEDO = disc_color.rgb;
	ALPHA = 1.0;
}
"""
	_energy_proj_mat = ShaderMaterial.new()
	_energy_proj_mat.shader = _energy_proj_shader
	_energy_proj_mat.set_shader_parameter("disc_color", Color(0.2, 0.5, 1.0, 0.35))
	_energy_proj_mat.set_shader_parameter("source_count", 0)
	_energy_proj_mesh = MeshInstance3D.new()
	var energy_plane = PlaneMesh.new()
	energy_plane.size = Vector2(CFG.map_half_size * 2, CFG.map_half_size * 2)
	_energy_proj_mesh.mesh = energy_plane
	_energy_proj_mesh.material_override = _energy_proj_mat
	_energy_proj_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_energy_proj_mesh.position = Vector3(0, 0.15, 0)
	_energy_proj_mesh.visible = false
	add_child(_energy_proj_mesh)

	_nuke_ring_mesh = MeshInstance3D.new()
	var nuke_plane = PlaneMesh.new()
	nuke_plane.size = Vector2(2, 2)
	_nuke_ring_mesh.mesh = nuke_plane
	_nuke_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nuke_ring_mat = ShaderMaterial.new()
	_nuke_ring_mat.shader = _aoe_shader
	_nuke_ring_mat.set_shader_parameter("ring_color", Color(1.0, 0.5, 0.1, 0.7))
	_nuke_ring_mat.set_shader_parameter("ring_width", 0.3)
	_nuke_ring_mesh.material_override = _nuke_ring_mat
	_nuke_ring_mesh.visible = false
	_nuke_ring_mesh.position.y = 0.2
	add_child(_nuke_ring_mesh)
	_nuke_flash_light = OmniLight3D.new()
	_nuke_flash_light.light_color = Color(1.0, 0.6, 0.2)
	_nuke_flash_light.light_energy = 0.0
	_nuke_flash_light.omni_range = 200.0
	_nuke_flash_light.omni_attenuation = 0.8
	_nuke_flash_light.shadow_enabled = false
	_nuke_flash_light.visible = false
	add_child(_nuke_flash_light)

	_dither_occlude_shader = Shader.new()
	_dither_occlude_shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled;
uniform vec4 silhouette_color : source_color = vec4(1.0, 1.0, 1.0, 0.7);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
void fragment() {
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
	float scene_depth = -view_pos.z / view_pos.w;
	float frag_depth = -VERTEX.z;
	if (frag_depth <= scene_depth + 0.5) discard;
	ivec2 px = ivec2(FRAGCOORD.xy);
	if ((px.x + px.y) % 2 == 0) discard;
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
"""
	_dither_occlude_mat = ShaderMaterial.new()
	_dither_occlude_mat.shader = _dither_occlude_shader
	_dither_occlude_mat.set_shader_parameter("silhouette_color", Color(1.0, 1.0, 1.0, 0.7))
	_flash_white_mat = StandardMaterial3D.new()
	_flash_white_mat.albedo_color = Color.WHITE
	_flash_white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_white_mat.next_pass = _dither_occlude_mat

	# Tiny invisible meshes that force GPU shader compilation
	for shader in [_laser_shader, _aoe_shader, _crystal_shader, _energy_proj_shader, _dither_occlude_shader]:
		var warmup = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.height = 0.01
		cm.top_radius = 0.01
		cm.bottom_radius = 0.01
		warmup.mesh = cm
		var wm = ShaderMaterial.new()
		wm.shader = shader
		warmup.material_override = wm
		warmup.position = Vector3(0, -500, 0)
		warmup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(warmup)

	# Step 4: Create object pools
	if is_instance_valid(hud_node):
		hud_node.show_loading("Creating object pools...", 0.6)
	await get_tree().process_frame

	for i in range(LASER_POOL_SIZE):
		var e = {}
		var laser_light = OmniLight3D.new()
		laser_light.light_energy = 2.0
		laser_light.omni_range = 45.0
		laser_light.omni_attenuation = 1.0
		laser_light.shadow_enabled = false
		laser_light.visible = false
		add_child(laser_light)
		e["light"] = laser_light
		var beam_group = Node3D.new()
		beam_group.visible = false
		add_child(beam_group)
		e["group"] = beam_group
		var mi_outer = MeshInstance3D.new()
		var cm_outer = CylinderMesh.new()
		cm_outer.top_radius = 2.0
		cm_outer.bottom_radius = 2.0
		cm_outer.height = 1.0
		cm_outer.radial_segments = 8
		mi_outer.mesh = cm_outer
		mi_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var outer_mat = ShaderMaterial.new()
		outer_mat.shader = _laser_shader
		outer_mat.set_shader_parameter("beam_color", Color(1.0, 0.8, 0.3, 0.6))
		outer_mat.set_shader_parameter("time_offset", 0.0)
		mi_outer.material_override = outer_mat
		beam_group.add_child(mi_outer)
		e["outer_mi"] = mi_outer
		e["outer_mat"] = outer_mat
		var mi_inner = MeshInstance3D.new()
		var cm_inner = CylinderMesh.new()
		cm_inner.top_radius = 0.6
		cm_inner.bottom_radius = 0.6
		cm_inner.height = 1.0
		cm_inner.radial_segments = 6
		mi_inner.mesh = cm_inner
		mi_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var inner_mat = ShaderMaterial.new()
		inner_mat.shader = _laser_shader
		inner_mat.set_shader_parameter("beam_color", Color(1, 1, 1, 1))
		inner_mat.set_shader_parameter("time_offset", 0.5)
		mi_inner.material_override = inner_mat
		beam_group.add_child(mi_inner)
		e["inner_mi"] = mi_inner
		e["inner_mat"] = inner_mat
		var sparks = preload("res://scenes/particles/laser_sparks.tscn").instantiate()
		sparks.emitting = false
		beam_group.add_child(sparks)
		e["sparks"] = sparks
		e["spark_mat"] = sparks.process_material
		var crystal_sparks = preload("res://scenes/particles/crystal_sparks.tscn").instantiate()
		crystal_sparks.emitting = false
		beam_group.add_child(crystal_sparks)
		e["crystal_sparks"] = crystal_sparks
		e["crystal_spark_mat"] = crystal_sparks.process_material
		e["active"] = false
		_laser_pool.append(e)

	for i in range(LIGHTNING_POOL_SIZE):
		var le = {}
		var bolt_group = Node3D.new()
		bolt_group.visible = false
		add_child(bolt_group)
		le["group"] = bolt_group
		var bolt_mi = MeshInstance3D.new()
		var bolt_cm = CylinderMesh.new()
		bolt_cm.top_radius = 0.5
		bolt_cm.bottom_radius = 0.5
		bolt_cm.height = 1.0
		bolt_cm.radial_segments = 4
		bolt_mi.mesh = bolt_cm
		var bolt_mat = StandardMaterial3D.new()
		bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bolt_mat.albedo_color = Color(0.7, 0.85, 1.0)
		bolt_mat.emission_enabled = true
		bolt_mat.emission = Color(0.6, 0.8, 1.0)
		bolt_mat.emission_energy_multiplier = 4.0
		bolt_mi.material_override = bolt_mat
		bolt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt_group.add_child(bolt_mi)
		le["mi"] = bolt_mi
		var bolt_light = OmniLight3D.new()
		bolt_light.light_color = Color(0.6, 0.8, 1.0)
		bolt_light.light_energy = 3.0
		bolt_light.omni_range = 30.0
		bolt_light.omni_attenuation = 1.2
		bolt_light.shadow_enabled = false
		bolt_light.visible = false
		add_child(bolt_light)
		le["light"] = bolt_light
		le["active"] = false
		_lightning_pool.append(le)

	# Step 5: Materials & overlays
	if is_instance_valid(hud_node):
		hud_node.show_loading("Preparing materials...", 0.85)
	await get_tree().process_frame

	_wire_mat_powered = StandardMaterial3D.new()
	_wire_mat_powered.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wire_mat_powered.albedo_color = Color(0.3, 0.7, 1.0)
	_wire_mat_powered.emission_enabled = true
	_wire_mat_powered.emission = Color(0.3, 0.7, 1.0)
	_wire_mat_powered.emission_energy_multiplier = 1.0
	_wire_mat_unpowered = StandardMaterial3D.new()
	_wire_mat_unpowered.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wire_mat_unpowered.albedo_color = Color(0.4, 0.35, 0.3)
	_wire_mat_unpowered.emission_enabled = true
	_wire_mat_unpowered.emission = Color(0.2, 0.2, 0.2)
	_wire_mat_unpowered.emission_energy_multiplier = 0.2

	hp_bar_layer = CanvasLayer.new()
	hp_bar_layer.layer = 1
	add_child(hp_bar_layer)

	_generate_powerup_textures()

	# Step 6: Spawn resources
	if is_instance_valid(hud_node):
		hud_node.show_loading("Spawning resources...", 0.95)
	await get_tree().process_frame

	if not NetworkManager.is_multiplayer_active() or NetworkManager.is_host():
		_spawn_resources()

	# Done — mark world as ready
	world_visible = true
	if is_instance_valid(hud_node):
		hud_node.hide_loading()


func _spawn_resources():
	var resource_scene = load("res://scenes/resource_node.tscn")
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Iron veins: 10 veins, 4-5 nodes each, closer to center
	_spawn_veins(resource_scene, rng, "iron", 10, 4, 5, 80, 700, 30, 60, 8, 20)

	# Crystal veins: 8 veins, 3-4 nodes each, further out
	_spawn_veins(resource_scene, rng, "crystal", 8, 3, 4, 200, 900, 25, 50, 5, 15)

	# Scattered singles so the map doesn't feel empty
	for i in range(8):
		var res = resource_scene.instantiate()
		var a = rng.randf() * TAU
		res.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(100, 800)
		res.resource_type = "iron" if rng.randf() < 0.6 else "crystal"
		res.amount = rng.randi_range(4, 10)
		res.net_id = next_net_id
		resource_net_ids[next_net_id] = res
		next_net_id += 1
		resources_node.add_child(res)


func _spawn_veins(scene: PackedScene, rng: RandomNumberGenerator, type: String,
		vein_count: int, min_per_vein: int, max_per_vein: int,
		min_dist: float, max_dist: float, min_spread: float, max_spread: float,
		min_amt: int, max_amt: int):
	for _v in range(vein_count):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(min_dist, max_dist)
		var center = Vector3(cos(angle), 0, sin(angle)) * dist
		var count = rng.randi_range(min_per_vein, max_per_vein)
		var spread = rng.randf_range(min_spread, max_spread)
		for _n in range(count):
			var res = scene.instantiate()
			var offset_a = rng.randf() * TAU
			var offset_d = rng.randf_range(0, spread)
			res.position = center + Vector3(cos(offset_a), 0, sin(offset_a)) * offset_d
			res.resource_type = type
			res.amount = rng.randi_range(min_amt, max_amt)
			res.net_id = next_net_id
			resource_net_ids[next_net_id] = res
			next_net_id += 1
			resources_node.add_child(res)


func _process(delta):
	if game_over:
		return

	# Before game world is created, nothing to process
	if not world_visible:
		return

	# Host waiting for all clients to finish loading
	if _waiting_for_clients:
		return

	# When paused (during voting), do network sync + 3D rendering but skip game logic
	if get_tree().paused:
		if NetworkManager.is_multiplayer_active():
			state_sync_timer += delta
			if state_sync_timer >= STATE_SYNC_INTERVAL:
				state_sync_timer = 0.0
				if NetworkManager.is_host():
					_broadcast_state()
				else:
					_send_client_state()
		if is_instance_valid(hud_node):
			var rates = get_factory_rates()
			hud_node.update_hud(player_node, wave_timer, wave_number, wave_active, total_power_gen, total_power_consumption, power_on, rates, power_bank, max_power_bank, run_prestige)
		# Keep 3D visuals in sync even during pause (entities may still move via RPCs)
		_sync_3d_lights()
		_sync_3d_meshes()
		_sync_hp_bars()
		return

	var is_authority = not NetworkManager.is_multiplayer_active() or NetworkManager.is_host()

	# Tick respawn timers (host only)
	if is_authority:
		var to_respawn: Array = []
		for pid in respawn_timers:
			respawn_timers[pid] -= delta
			if respawn_timers[pid] <= 0:
				to_respawn.append(pid)
		for pid in to_respawn:
			_respawn_player(pid)

	if is_authority and not vote_active:
		_update_power_system(delta)

		var alien_count = get_tree().get_nodes_in_group("aliens").size()

		# Wave logic: countdown only when no aliens
		if wave_active:
			if alien_count == 0:
				wave_active = false
		else:
			wave_timer -= delta
			if wave_timer <= 0:
				wave_number += 1
				_spawn_wave()
				wave_timer = CFG.wave_interval
				wave_active = true
				is_first_wave = false

		resource_regen_timer -= delta
		if resource_regen_timer <= 0:
			resource_regen_timer = get_regen_interval()
			_regenerate_resources()

		powerup_timer -= delta
		if powerup_timer <= 0:
			powerup_timer = CFG.powerup_spawn_interval
			_spawn_powerup()

		upgrade_cooldown = maxf(0.0, upgrade_cooldown - delta)
		if pending_upgrades > 0 and upgrade_cooldown <= 0:
			_try_show_upgrade()

	# Network state sync
	if NetworkManager.is_multiplayer_active():
		state_sync_timer += delta
		if state_sync_timer >= STATE_SYNC_INTERVAL:
			state_sync_timer = 0.0
			if is_authority:
				_broadcast_state()
			else:
				_send_client_state()

	if is_instance_valid(hud_node):
		var rates = get_factory_rates()
		# Update respawn countdown for host's local player
		if is_authority and is_instance_valid(player_node):
			hud_node.respawn_countdown = respawn_timers.get(player_node.peer_id, 0.0)
		hud_node.update_hud(player_node, wave_timer, wave_number, wave_active, total_power_gen, total_power_consumption, power_on, rates, power_bank, max_power_bank, run_prestige)

	# Update mouse world position from 3D camera raycast
	_update_mouse_world()

	# Update 3D camera to follow player (position only, fixed angle)
	if is_instance_valid(camera_3d) and is_instance_valid(player_node):
		var p2d = player_node.global_position
		var cam_target = Vector3(p2d.x, 0, p2d.z)
		var cam_offset = Vector3(0, 600, 350)
		camera_3d.position = camera_3d.position.lerp(cam_target + cam_offset, 8.0 * delta)

	# Sync 3D lights for buildings and player
	_sync_3d_lights()

	# Sync 3D meshes for all entities
	_sync_3d_meshes()

	# Sync screen-space HP bars
	_sync_hp_bars()

	# Sync AoE range rings (dithered overlay)
	_sync_aoe_rings()

	# Sync 3D pylon wires
	_sync_pylon_wires()

	# Sync 3D build placement preview
	_sync_build_preview()

	# Sync nuke explosion visual
	_sync_nuke_visual()

	# Sync HQ light position
	if is_instance_valid(hq_node) and is_instance_valid(hq_light_3d):
		var hpos = hq_node.global_position
		hq_light_3d.position = Vector3(hpos.x, 50, hpos.z)


func _regenerate_resources():
	var current = get_tree().get_nodes_in_group("resources").size()
	var max_res = get_max_resources()
	if current >= max_res:
		return
	var resource_scene = load("res://scenes/resource_node.tscn")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	# Spawn more rocks per cycle as waves progress
	var spawn_count = mini(5 + wave_number / 2, max_res - current)
	for i in range(spawn_count):
		var res = resource_scene.instantiate()
		var a3 = rng.randf() * TAU
		res.position = Vector3(cos(a3), 0, sin(a3)) * rng.randf_range(100, CFG.map_half_size * 0.85)
		res.resource_type = "iron" if rng.randf() < 0.6 else "crystal"
		res.amount = rng.randi_range(5 + wave_number, 15 + wave_number * 2)
		res.net_id = next_net_id
		resource_net_ids[next_net_id] = res
		next_net_id += 1
		resources_node.add_child(res)


func _spawn_powerup():
	var current = get_tree().get_nodes_in_group("powerups").size()
	if current >= CFG.max_powerups:
		return
	var powerup = load("res://scenes/powerup.tscn").instantiate()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var a4 = rng.randf() * TAU
	powerup.position = Vector3(cos(a4), 0, sin(a4)) * rng.randf_range(150, CFG.map_half_size * 0.8)
	var types = ["magnet", "weapon_scroll", "heal", "nuke", "mining_boost"]
	powerup.powerup_type = types[rng.randi() % types.size()]
	powerups_node.add_child(powerup)


func _update_mouse_world():
	if not is_instance_valid(camera_3d):
		return
	var mouse_screen = get_viewport().get_mouse_position()
	var from = camera_3d.project_ray_origin(mouse_screen)
	var dir = camera_3d.project_ray_normal(mouse_screen)
	if dir.y != 0:
		var t = -from.y / dir.y
		if t > 0:
			var hit = from + dir * t
			mouse_world_2d = Vector3(hit.x, 0, hit.z)


func world_to_screen(world_pos: Vector3) -> Vector2:
	if is_instance_valid(camera_3d):
		return camera_3d.unproject_position(world_pos)
	return Vector2.ZERO


func _sync_3d_lights():
	# Clean up lights for destroyed entities
	for key in building_lights.keys():
		if not is_instance_valid(key):
			building_lights[key].queue_free()
			building_lights.erase(key)
	for key in player_lights.keys():
		if not is_instance_valid(key):
			player_lights[key].queue_free()
			player_lights.erase(key)
	for key in alien_lights.keys():
		if not is_instance_valid(key):
			alien_lights[key].queue_free()
			alien_lights.erase(key)
	for key in resource_lights.keys():
		if not is_instance_valid(key):
			resource_lights[key].queue_free()
			resource_lights.erase(key)

	# Building lights (skip HQ — it has its own dedicated light)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b): continue
		if b.is_in_group("hq"): continue
		var bcolor = _get_building_light_color(b)
		var pos3d = Vector3(b.global_position.x, 10, b.global_position.z)
		if b not in building_lights:
			var light = OmniLight3D.new()
			light.light_energy = CFG.building_light_energy
			light.omni_range = CFG.building_light_range
			light.omni_attenuation = 1.0
			light.light_color = bcolor
			light.shadow_enabled = false
			add_child(light)
			building_lights[b] = light
		var blight = building_lights[b]
		blight.position = pos3d
		var b_disabled = "manually_disabled" in b and b.manually_disabled
		var b_powered = not b.has_method("is_powered") or b.is_powered()
		if b_disabled or not b_powered:
			blight.light_energy = 0.0
		else:
			blight.light_energy = CFG.building_light_energy
			blight.light_color = bcolor

	# Player lights
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var pcolor = p.player_color if "player_color" in p else Color(0.2, 0.9, 0.3)
		var pos3d = Vector3(p.global_position.x, 12, p.global_position.z)
		if p not in player_lights:
			var light = OmniLight3D.new()
			light.light_energy = CFG.player_light_energy
			light.omni_range = CFG.player_light_range
			light.omni_attenuation = 1.0
			light.light_color = pcolor
			light.shadow_enabled = false
			add_child(light)
			player_lights[p] = light
		player_lights[p].position = pos3d

	# Alien lights (red/orange glow) — on mobile, only boss aliens get lights
	for a in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(a): continue
		var is_boss = a.is_in_group("bosses")
		var pos3d = Vector3(a.global_position.x, 30 if is_boss else 8, a.global_position.z)
		if a not in alien_lights:
			var light = OmniLight3D.new()
			light.light_energy = 0.6
			light.omni_range = 30.0
			light.omni_attenuation = 1.5
			var acolor = Color(0.9, 0.2, 0.1)
			if is_boss:
				light.light_energy = 8.0
				light.omni_range = 120.0
				light.omni_attenuation = 0.8
				acolor = Color(1.0, 0.15, 0.1)
			light.light_color = acolor
			light.shadow_enabled = false
			add_child(light)
			alien_lights[a] = light
		alien_lights[a].position = pos3d

	# Resource lights (blue for crystal, red for iron)
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r): continue
		var rtype = r.resource_type if "resource_type" in r else "iron"
		var rpos = Vector3(r.global_position.x, 15, r.global_position.z)
		if r not in resource_lights:
			var light = OmniLight3D.new()
			if rtype == "crystal":
				light.light_color = CFG.resource_crystal_light_color
				light.light_energy = CFG.resource_crystal_light_energy
				light.omni_range = CFG.resource_crystal_light_range
			else:
				light.light_color = CFG.resource_iron_light_color
				light.light_energy = CFG.resource_iron_light_energy
				light.omni_range = CFG.resource_iron_light_range
			light.omni_attenuation = 1.2
			light.shadow_enabled = false
			add_child(light)
			resource_lights[r] = light
		resource_lights[r].position = rpos

	# Mining laser beams — use pre-created pool, zero allocation at runtime
	var active_targets: Dictionary = {}
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var ppos = p.global_position
		# Local player: use mine_targets directly
		if "mine_targets" in p:
			for target in p.mine_targets:
				if not is_instance_valid(target): continue
				active_targets[target] = p
		# Remote player: resolve synced positions to nearest resource node
		if "remote_mine_positions" in p and p.remote_mine_positions.size() > 0 and (not "is_local" in p or not p.is_local):
			var mt_arr = p.remote_mine_positions
			for mi_idx in range(0, mt_arr.size(), 2):
				var tpos2 = Vector3(mt_arr[mi_idx], 0, mt_arr[mi_idx + 1])
				# Find closest resource to this position
				var best_r = null
				var best_d = 20.0  # Max match distance
				for r in get_tree().get_nodes_in_group("resources"):
					if not is_instance_valid(r): continue
					var d = r.global_position.distance_to(tpos2)
					if d < best_d:
						best_d = d
						best_r = r
				if best_r and best_r not in active_targets:
					active_targets[best_r] = p
	# Render beams for all active targets
	for target in active_targets:
		if not is_instance_valid(target): continue
		var p_node = active_targets[target]
		var ppos = p_node.global_position
		var tpos = target.global_position
		var lc = Color(1.0, 0.8, 0.3)
		if "resource_type" in target and target.resource_type == "crystal":
			lc = Color(0.4, 0.7, 1.0)
		var t_amt = target.amount if "amount" in target else 10
		var t_sz = 10.0 + t_amt * 0.5
		var t_rtype = target.resource_type if "resource_type" in target else "iron"
		var t_center_y = t_sz * 0.3 if t_rtype == "iron" else t_sz * 0.5
		var laser_y = 8.0
		var pmesh = player_meshes.get(p_node)
		if pmesh:
			var marker = pmesh.get_node_or_null("Body/PlayerShip/LaserOrigin")
			if marker:
				laser_y = marker.global_position.y
		var start = Vector3(ppos.x, laser_y, ppos.z)
		var raw_end = Vector3(tpos.x, t_center_y, tpos.z)
		var to_player = start - raw_end
		var to_len = to_player.length()
		var end_pt: Vector3
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(start, raw_end)
		var ray_result = space_state.intersect_ray(query)
		if ray_result:
			end_pt = ray_result.position
		else:
			var surface_offset = minf(t_sz * 0.4, to_len * 0.5)
			end_pt = raw_end + to_player.normalized() * surface_offset if to_len > 0.1 else raw_end
		var dist = start.distance_to(end_pt)
		if dist < 0.1: continue
		var mid = (start + end_pt) / 2.0
		var dir = (end_pt - start).normalized()
		var side: Vector3
		if abs(dir.dot(Vector3.UP)) < 0.999:
			side = dir.cross(Vector3.UP).normalized()
		else:
			side = dir.cross(Vector3.FORWARD).normalized()
		var fwd = side.cross(dir).normalized()
		var scaled_basis = Basis(side, dir * dist, fwd)
		var is_crystal = t_rtype == "crystal"
		var spark_key = "crystal_sparks" if is_crystal else "sparks"
		var spark_mat_key = "crystal_spark_mat" if is_crystal else "spark_mat"
		if target in mining_laser_beams:
			# UPDATE existing — just set transforms (no allocation)
			var e = mining_laser_beams[target]
			e["light"].position = Vector3(tpos.x, 6, tpos.z)
			e["outer_mi"].global_transform = Transform3D(scaled_basis, mid)
			e["inner_mi"].global_transform = Transform3D(scaled_basis, mid)
			e[spark_key].global_position = end_pt
			e[spark_mat_key].direction = Vector3(to_player.x, 1, to_player.z).normalized()
		else:
			# ACTIVATE a pool entry (no node creation, just show + set uniforms)
			var e = _acquire_laser_beam()
			e["light"].light_color = lc
			e["light"].position = Vector3(tpos.x, 6, tpos.z)
			e["light"].visible = true
			e["outer_mat"].set_shader_parameter("beam_color", Color(lc.r, lc.g, lc.b, 0.6))
			e["outer_mat"].set_shader_parameter("time_offset", tpos.x * 0.01)
			e["inner_mat"].set_shader_parameter("time_offset", tpos.x * 0.01 + 0.5)
			e["outer_mi"].global_transform = Transform3D(scaled_basis, mid)
			e["inner_mi"].global_transform = Transform3D(scaled_basis, mid)
			e[spark_mat_key].direction = Vector3(to_player.x, 1, to_player.z).normalized()
			e[spark_key].global_position = end_pt
			e[spark_key].emitting = true
			e["group"].visible = true
			e["active"] = true
			mining_laser_beams[target] = e
	# Return beams to pool for targets no longer being mined
	for key in mining_laser_beams.keys():
		if key not in active_targets or not is_instance_valid(key):
			var e = mining_laser_beams[key]
			e["light"].visible = false
			e["group"].visible = false
			e["sparks"].emitting = false
			e["crystal_sparks"].emitting = false
			e["active"] = false
			mining_laser_beams.erase(key)

	# --- Player repair beams (green, reuse laser pool) ---
	var active_player_repair: Dictionary = {}
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		if not "repair_targets" in p: continue
		var ppos = p.global_position
		for target in p.repair_targets:
			if not is_instance_valid(target): continue
			active_player_repair[target] = true
			var tpos = target.global_position
			var start = Vector3(ppos.x, 8, ppos.z)
			var end_pt = Vector3(tpos.x, 10, tpos.z)
			var dist3 = start.distance_to(end_pt)
			if dist3 < 0.1: continue
			var mid3 = (start + end_pt) / 2.0
			var dir3 = (end_pt - start).normalized()
			var side3: Vector3
			if abs(dir3.dot(Vector3.UP)) < 0.999:
				side3 = dir3.cross(Vector3.UP).normalized()
			else:
				side3 = dir3.cross(Vector3.FORWARD).normalized()
			var fwd3 = side3.cross(dir3).normalized()
			var scaled_basis3 = Basis(side3, dir3 * dist3, fwd3)
			if target in player_repair_beams:
				var re = player_repair_beams[target]
				re["light"].position = end_pt
				re["outer_mi"].global_transform = Transform3D(scaled_basis3, mid3)
				re["inner_mi"].global_transform = Transform3D(scaled_basis3, mid3)
				re["sparks"].global_position = end_pt
			else:
				var re = _acquire_laser_beam()
				var gc = Color(0.3, 1.0, 0.5)
				re["light"].light_color = gc
				re["light"].position = end_pt
				re["light"].visible = true
				re["outer_mat"].set_shader_parameter("beam_color", Color(gc.r, gc.g, gc.b, 0.5))
				re["outer_mat"].set_shader_parameter("time_offset", tpos.x * 0.01)
				re["inner_mat"].set_shader_parameter("beam_color", Color(1, 1, 1, 0.8))
				re["inner_mat"].set_shader_parameter("time_offset", tpos.x * 0.01 + 0.5)
				re["outer_mi"].global_transform = Transform3D(scaled_basis3, mid3)
				re["inner_mi"].global_transform = Transform3D(scaled_basis3, mid3)
				re["spark_mat"].color = gc
				re["sparks"].global_position = end_pt
				re["sparks"].emitting = true
				re["group"].visible = true
				re["active"] = true
				player_repair_beams[target] = re
	for key in player_repair_beams.keys():
		if key not in active_player_repair or not is_instance_valid(key):
			var re = player_repair_beams[key]
			re["light"].visible = false
			re["group"].visible = false
			re["sparks"].emitting = false
			re["active"] = false
			player_repair_beams.erase(key)

	# --- Repair drone beams (green, reuse laser pool) ---
	var active_repair_keys: Dictionary = {}
	for b in get_tree().get_nodes_in_group("repair_drones"):
		if not is_instance_valid(b): continue
		if not "repair_targets" in b or not "drone_angle" in b: continue
		if not b.has_method("is_powered") or not b.is_powered(): continue
		var mr = building_meshes.get(b)
		if not mr: continue
		var drone_node = mr.get_node_or_null("Drone")
		if not drone_node: continue
		var bpos = b.global_position
		var drone_world = Vector3(bpos.x, 0, bpos.z) + drone_node.position
		for target in b.repair_targets:
			if not is_instance_valid(target): continue
			var rkey = str(b.get_instance_id()) + ":" + str(target.get_instance_id())
			active_repair_keys[rkey] = true
			var tpos = target.global_position
			var start = drone_world
			var end_pt = Vector3(tpos.x, 10, tpos.z)
			var dist2 = start.distance_to(end_pt)
			if dist2 < 0.1: continue
			var mid2 = (start + end_pt) / 2.0
			var dir2 = (end_pt - start).normalized()
			var side2: Vector3
			if abs(dir2.dot(Vector3.UP)) < 0.999:
				side2 = dir2.cross(Vector3.UP).normalized()
			else:
				side2 = dir2.cross(Vector3.FORWARD).normalized()
			var fwd2 = side2.cross(dir2).normalized()
			var scaled_basis2 = Basis(side2, dir2 * dist2, fwd2)
			if rkey in repair_beam_active:
				var re = repair_beam_active[rkey]
				re["light"].position = end_pt
				re["outer_mi"].global_transform = Transform3D(scaled_basis2, mid2)
				re["inner_mi"].global_transform = Transform3D(scaled_basis2, mid2)
				re["sparks"].global_position = end_pt
			else:
				var re = _acquire_laser_beam()
				var gc = Color(0.3, 1.0, 0.5)
				re["light"].light_color = gc
				re["light"].position = end_pt
				re["light"].visible = true
				re["outer_mat"].set_shader_parameter("beam_color", Color(gc.r, gc.g, gc.b, 0.5))
				re["outer_mat"].set_shader_parameter("time_offset", tpos.x * 0.01)
				re["inner_mat"].set_shader_parameter("beam_color", Color(1, 1, 1, 0.8))
				re["inner_mat"].set_shader_parameter("time_offset", tpos.x * 0.01 + 0.5)
				re["outer_mi"].global_transform = Transform3D(scaled_basis2, mid2)
				re["inner_mi"].global_transform = Transform3D(scaled_basis2, mid2)
				re["spark_mat"].color = gc
				re["sparks"].global_position = end_pt
				re["sparks"].emitting = true
				re["group"].visible = true
				re["active"] = true
				repair_beam_active[rkey] = re
	for rkey in repair_beam_active.keys():
		if rkey not in active_repair_keys:
			var re = repair_beam_active[rkey]
			re["light"].visible = false
			re["group"].visible = false
			re["sparks"].emitting = false
			re["active"] = false
			repair_beam_active.erase(rkey)

	# --- Lightning bolts (flash on for one frame per zap) ---
	# Deactivate all current bolts first
	for entries in lightning_beam_active.values():
		for le in entries:
			le["group"].visible = false
			le["light"].visible = false
			le["active"] = false
	lightning_beam_active.clear()
	for b in get_tree().get_nodes_in_group("lightnings"):
		if not is_instance_valid(b): continue
		if not "zap_targets" in b or b.zap_targets.is_empty(): continue
		var bpos = b.global_position
		var bolt_entries: Array = []
		for target_offset in b.zap_targets:
			var le = _acquire_lightning_bolt()
			var bolt_start = Vector3(bpos.x, 32, bpos.z)
			var tpos2 = bpos + target_offset
			var bolt_end = Vector3(tpos2.x, 8, tpos2.z)
			var bolt_dist = bolt_start.distance_to(bolt_end)
			if bolt_dist < 0.1: continue
			var bolt_mid = (bolt_start + bolt_end) / 2.0
			var bolt_dir = (bolt_end - bolt_start).normalized()
			var bolt_side: Vector3
			if abs(bolt_dir.dot(Vector3.UP)) < 0.999:
				bolt_side = bolt_dir.cross(Vector3.UP).normalized()
			else:
				bolt_side = bolt_dir.cross(Vector3.FORWARD).normalized()
			var bolt_fwd = bolt_side.cross(bolt_dir).normalized()
			var bolt_basis = Basis(bolt_side, bolt_dir * bolt_dist, bolt_fwd)
			le["mi"].global_transform = Transform3D(bolt_basis, bolt_mid)
			le["group"].visible = true
			le["light"].position = bolt_mid
			le["light"].visible = true
			le["active"] = true
			bolt_entries.append(le)
		if not bolt_entries.is_empty():
			lightning_beam_active[b] = bolt_entries


func _acquire_laser_beam() -> Dictionary:
	# Grab an inactive pool entry, or create a new one if pool is exhausted
	for e in _laser_pool:
		if not e["active"]:
			return e
	# Pool exhausted — expand (shouldn't normally happen)
	var e = {}
	var laser_light = OmniLight3D.new()
	laser_light.light_energy = 2.0
	laser_light.omni_range = 45.0
	laser_light.omni_attenuation = 1.0
	laser_light.shadow_enabled = false
	laser_light.visible = false
	add_child(laser_light)
	e["light"] = laser_light
	var beam_group = Node3D.new()
	beam_group.visible = false
	add_child(beam_group)
	e["group"] = beam_group
	var mi_outer = MeshInstance3D.new()
	var cm_outer = CylinderMesh.new()
	cm_outer.top_radius = 2.0
	cm_outer.bottom_radius = 2.0
	cm_outer.height = 1.0
	cm_outer.radial_segments = 8
	mi_outer.mesh = cm_outer
	mi_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var outer_mat = ShaderMaterial.new()
	outer_mat.shader = _laser_shader
	mi_outer.material_override = outer_mat
	beam_group.add_child(mi_outer)
	e["outer_mi"] = mi_outer
	e["outer_mat"] = outer_mat
	var mi_inner = MeshInstance3D.new()
	var cm_inner = CylinderMesh.new()
	cm_inner.top_radius = 0.6
	cm_inner.bottom_radius = 0.6
	cm_inner.height = 1.0
	cm_inner.radial_segments = 6
	mi_inner.mesh = cm_inner
	mi_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inner_mat = ShaderMaterial.new()
	inner_mat.shader = _laser_shader
	inner_mat.set_shader_parameter("beam_color", Color(1, 1, 1, 1))
	mi_inner.material_override = inner_mat
	beam_group.add_child(mi_inner)
	e["inner_mi"] = mi_inner
	e["inner_mat"] = inner_mat
	var sparks = preload("res://scenes/particles/laser_sparks.tscn").instantiate()
	sparks.emitting = false
	beam_group.add_child(sparks)
	e["sparks"] = sparks
	e["spark_mat"] = sparks.process_material
	var crystal_sparks = preload("res://scenes/particles/crystal_sparks.tscn").instantiate()
	crystal_sparks.emitting = false
	beam_group.add_child(crystal_sparks)
	e["crystal_sparks"] = crystal_sparks
	e["crystal_spark_mat"] = crystal_sparks.process_material
	e["active"] = false
	_laser_pool.append(e)
	print("[BEAM] Pool exhausted, created extra beam entry")
	return e


func _acquire_lightning_bolt() -> Dictionary:
	for e in _lightning_pool:
		if not e["active"]:
			return e
	# Pool exhausted — create new bolt entry
	var le = {}
	var bolt_group = Node3D.new()
	bolt_group.visible = false
	add_child(bolt_group)
	le["group"] = bolt_group
	var bolt_mi = MeshInstance3D.new()
	var bolt_cm = CylinderMesh.new()
	bolt_cm.top_radius = 0.5
	bolt_cm.bottom_radius = 0.5
	bolt_cm.height = 1.0
	bolt_cm.radial_segments = 4
	bolt_mi.mesh = bolt_cm
	var bolt_mat = StandardMaterial3D.new()
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mat.albedo_color = Color(0.7, 0.85, 1.0)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.6, 0.8, 1.0)
	bolt_mat.emission_energy_multiplier = 4.0
	bolt_mi.material_override = bolt_mat
	bolt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt_group.add_child(bolt_mi)
	le["mi"] = bolt_mi
	var bolt_light = OmniLight3D.new()
	bolt_light.light_color = Color(0.6, 0.8, 1.0)
	bolt_light.light_energy = 3.0
	bolt_light.omni_range = 30.0
	bolt_light.omni_attenuation = 1.2
	bolt_light.shadow_enabled = false
	bolt_light.visible = false
	add_child(bolt_light)
	le["light"] = bolt_light
	le["active"] = false
	_lightning_pool.append(le)
	return le


func _get_building_light_color(building: Node3D) -> Color:
	if building.has_method("get_building_name"):
		match building.get_building_name():
			"Turret": return Color(0.4, 0.6, 1.0)
			"Factory": return Color(0.9, 0.7, 0.2)
			"Wall": return Color(0.5, 0.5, 0.6)
			"Lightning Tower": return Color(0.5, 0.3, 1.0)
			"Slow Tower": return Color(0.3, 0.7, 1.0)
			"Pylon": return Color(0.8, 0.9, 0.3)
			"Power Plant": return Color(1.0, 0.9, 0.3)
			"Battery": return Color(0.5, 0.9, 0.3)
			"Flame Turret": return Color(1.0, 0.5, 0.15)
			"Acid Turret": return Color(0.3, 0.9, 0.2)
			"Repair Drone": return Color(0.3, 1.0, 0.5)
			"Poison Turret": return Color(0.3, 0.85, 0.2)
			"HQ": return Color(1.0, 0.85, 0.4)
	return Color(1.0, 0.85, 0.5)


# ---- 3D Mesh Helpers ----

func _vert_mat(color: Color) -> StandardMaterial3D:
	var key = "v_" + color.to_html()
	if _mat_cache.has(key): return _mat_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	_mat_cache[key] = m
	return m


func _generate_powerup_textures():
	for type in ["magnet", "weapon_scroll", "heal", "nuke", "mining_boost"]:
		_powerup_textures[type] = _make_powerup_icon(type)


func _make_powerup_icon(type: String) -> ImageTexture:
	var s = 64
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx = s / 2.0
	var cy = s / 2.0
	var r = 22.0

	var bg: Color
	match type:
		"magnet": bg = Color(0.3, 1.0, 0.5)
		"weapon_scroll": bg = Color(1.0, 0.8, 0.2)
		"heal": bg = Color(1.0, 0.3, 0.4)
		"nuke": bg = Color(1.0, 0.5, 0.1)
		"mining_boost": bg = Color(1.0, 0.8, 0.3)
		_: bg = Color(0.5, 0.5, 0.5)

	# Background circle with ring edge
	_img_circle(img, cx, cy, r + 2, bg)
	_img_circle(img, cx, cy, r, bg.darkened(0.3))

	# Icon overlay per type
	match type:
		"magnet":
			# U-shape magnet
			for a in range(180):
				var angle = PI + deg_to_rad(a)
				for t in range(3):
					var pr = 10.0 + t
					var px = cx + cos(angle) * pr
					var py = cy + 4 + sin(angle) * pr
					if px >= 0 and px < s and py >= 0 and py < s:
						img.set_pixel(int(px), int(py), Color.WHITE)
			_img_rect(img, 20, 24, 4, 10, Color(1, 0.2, 0.2))
			_img_rect(img, 40, 24, 4, 10, Color(0.2, 0.2, 1.0))
		"weapon_scroll":
			_img_rect(img, 22, 20, 20, 24, Color(0.9, 0.85, 0.7))
			_img_rect(img, 25, 25, 14, 2, Color(0.3, 0.3, 0.3))
			_img_rect(img, 25, 30, 14, 2, Color(0.3, 0.3, 0.3))
			_img_rect(img, 25, 35, 10, 2, Color(0.3, 0.3, 0.3))
		"heal":
			_img_rect(img, 29, 20, 6, 24, Color.WHITE)
			_img_rect(img, 20, 29, 24, 6, Color.WHITE)
		"nuke":
			_img_circle(img, cx, cy, 5, Color(0.1, 0.1, 0.1))
			for i in range(3):
				var angle = TAU * i / 3.0 - PI / 2.0
				_img_circle(img, cx + cos(angle) * 11, cy + sin(angle) * 11, 5, Color.WHITE)
		"mining_boost":
			_img_line(img, 22, 42, 42, 22, Color(0.6, 0.4, 0.2), 3)
			_img_line(img, 38, 22, 42, 26, Color(0.8, 0.8, 0.9), 3)
			_img_line(img, 42, 22, 38, 26, Color(0.8, 0.8, 0.9), 3)

	return ImageTexture.create_from_image(img)


func _img_circle(img: Image, cx: float, cy: float, radius: float, color: Color):
	var r2 = radius * radius
	var y0 = maxi(0, int(cy - radius - 1))
	var y1 = mini(img.get_height(), int(cy + radius + 2))
	var x0 = maxi(0, int(cx - radius - 1))
	var x1 = mini(img.get_width(), int(cx + radius + 2))
	for y in range(y0, y1):
		for x in range(x0, x1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
				img.set_pixel(x, y, color)


func _img_rect(img: Image, x: int, y: int, w: int, h: int, color: Color):
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, color)


func _img_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color, width: int = 1):
	var steps = maxi(absi(x1 - x0), absi(y1 - y0))
	if steps == 0: return
	var hw = width / 2
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var px = int(lerpf(float(x0), float(x1), t))
		var py = int(lerpf(float(y0), float(y1), t))
		for wy in range(-hw, hw + 1):
			for wx in range(-hw, hw + 1):
				var fx = px + wx
				var fy = py + wy
				if fx >= 0 and fx < img.get_width() and fy >= 0 and fy < img.get_height():
					img.set_pixel(fx, fy, color)


func _bb_mat(color: Color) -> StandardMaterial3D:
	var key = "bb_" + color.to_html()
	if _mat_cache.has(key): return _mat_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.5
	_mat_cache[key] = m
	return m


func _unlit_mat(color: Color) -> StandardMaterial3D:
	var key = "u_" + color.to_html()
	if _mat_cache.has(key): return _mat_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[key] = m
	return m


func _mesh_box(sz: Vector3, col: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = _vert_mat(col)
	mi.position = pos
	return mi


func _mesh_cyl(r: float, h: float, col: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = _vert_mat(col)
	mi.position = pos
	return mi


func _mesh_sphere(r: float, col: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	mi.mesh = sm
	mi.material_override = _vert_mat(col)
	mi.position = pos
	return mi


# ---- Status Effect 3D FX Helpers ----

func _ensure_burn_fx(alien_root: Node3D, active: bool):
	var fx = alien_root.get_node_or_null("BurnFX")
	if active:
		if not fx:
			fx = GPUParticles3D.new()
			fx.name = "BurnFX"
			fx.amount = 8
			fx.lifetime = 0.6
			fx.explosiveness = 0.3
			var pm = ParticleProcessMaterial.new()
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 25.0
			pm.initial_velocity_min = 8.0
			pm.initial_velocity_max = 20.0
			pm.gravity = Vector3(0, -5, 0)
			pm.scale_min = 0.8
			pm.scale_max = 2.0
			pm.color = Color(1.0, 0.5, 0.1)
			fx.process_material = pm
			var sm = SphereMesh.new()
			sm.radius = 1.5
			sm.height = 3.0
			fx.draw_pass_1 = sm
			fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fx.position.y = 6
			alien_root.add_child(fx)
		fx.emitting = true
		fx.visible = true
	elif fx:
		fx.emitting = false
		fx.visible = false


func _ensure_frozen_fx(alien_root: Node3D, active: bool, alien_size: float):
	var fx = alien_root.get_node_or_null("FrozenFX")
	if active:
		if not fx:
			fx = MeshInstance3D.new()
			fx.name = "FrozenFX"
			var bm = BoxMesh.new()
			var s = alien_size * 1.3
			bm.size = Vector3(s, s, s)
			fx.mesh = bm
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.75, 1.0, 0.3)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.6, 1.0)
			mat.emission_energy_multiplier = 0.5
			fx.material_override = mat
			fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fx.position.y = alien_size * 0.5
			alien_root.add_child(fx)
		fx.visible = true
	elif fx:
		fx.visible = false


func _ensure_poison_fx(alien_root: Node3D, active: bool):
	var fx = alien_root.get_node_or_null("PoisonFX")
	if active:
		if not fx:
			fx = GPUParticles3D.new()
			fx.name = "PoisonFX"
			fx.amount = 6
			fx.lifetime = 0.8
			fx.explosiveness = 0.2
			var pm = ParticleProcessMaterial.new()
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 35.0
			pm.initial_velocity_min = 4.0
			pm.initial_velocity_max = 12.0
			pm.gravity = Vector3(0, 2, 0)
			pm.scale_min = 1.0
			pm.scale_max = 3.0
			pm.color = Color(0.2, 0.85, 0.15, 0.6)
			fx.process_material = pm
			var sm = SphereMesh.new()
			sm.radius = 1.2
			sm.height = 2.4
			fx.draw_pass_1 = sm
			fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fx.position.y = 6
			alien_root.add_child(fx)
		fx.emitting = true
		fx.visible = true
	elif fx:
		fx.emitting = false
		fx.visible = false


func _create_hp_bar_ui() -> Control:
	var container = Control.new()
	container.size = Vector2(40, 6)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.1, 0.1, 0.1, 0.7)
	bg.size = Vector2(40, 6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	var fill = ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.2, 0.8, 0.2)
	fill.size = Vector2(40, 6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(fill)
	return container


func _sync_hp_bars():
	if not is_instance_valid(camera_3d) or not is_instance_valid(hp_bar_layer):
		return
	# Hide HP bars when game is paused (so they don't draw over pause/upgrade menus)
	if get_tree().paused:
		hp_bar_layer.visible = false
		return
	hp_bar_layer.visible = true
	# Collect all entities that should have HP bars: buildings + players + aliens
	var entities: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and "hp" in b and "max_hp" in b:
			var h = 30.0
			if b in building_meshes:
				h = 30.0
			entities.append({"node": b, "hp": b.hp, "max_hp": b.max_hp, "y_offset": h, "bar_w": 40})
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and "health" in p and "max_health" in p:
			var dead = p.is_dead if "is_dead" in p else false
			if not dead:
				entities.append({"node": p, "hp": p.health, "max_hp": p.max_health, "y_offset": 18, "bar_w": 32, "always": true})
	for a in get_tree().get_nodes_in_group("aliens"):
		if is_instance_valid(a) and "hp" in a and "max_hp" in a:
			entities.append({"node": a, "hp": a.hp, "max_hp": a.max_hp, "y_offset": 16, "bar_w": 28})
	# Track which entities still exist
	var active_set: Dictionary = {}
	for e in entities:
		var node = e["node"]
		if e["max_hp"] <= 0: continue
		if e["hp"] >= e["max_hp"] and not e.get("always", false): continue  # Full health = no bar (unless always-on)
		active_set[node] = true
		if node not in hp_bar_nodes:
			var new_bar = _create_hp_bar_ui()
			hp_bar_layer.add_child(new_bar)
			hp_bar_nodes[node] = new_bar
		var bar = hp_bar_nodes[node]
		var pos2d = node.global_position
		var world_pos = Vector3(pos2d.x, e["y_offset"], pos2d.z)
		if camera_3d.is_position_behind(world_pos):
			bar.visible = false
			continue
		var screen_pos = camera_3d.unproject_position(world_pos)
		var bw = e["bar_w"]
		bar.position = Vector2(screen_pos.x - bw / 2.0, screen_pos.y - 10)
		bar.visible = true
		var bg_rect = bar.get_node("Bg") as ColorRect
		bg_rect.size.x = bw
		var fill_rect = bar.get_node("Fill") as ColorRect
		var ratio = clampf(float(e["hp"]) / float(e["max_hp"]), 0, 1)
		fill_rect.size.x = bw * ratio
		fill_rect.color = Color(1.0 - ratio, ratio, 0.1)
	# Clean up bars for dead/removed entities or full-health entities
	for node in hp_bar_nodes.keys():
		if not is_instance_valid(node) or node not in active_set:
			if is_instance_valid(hp_bar_nodes[node]):
				hp_bar_nodes[node].queue_free()
			hp_bar_nodes.erase(node)


# ---- Building Mesh Factories ----

func _create_building_mesh(bname: String) -> Node3D:
	var root = Node3D.new()
	match bname:
		"HQ":
			root.add_child(_mesh_box(Vector3(40, 20, 30), Color(0.35, 0.45, 0.65), Vector3(0, 10, 0)))
			root.add_child(_mesh_box(Vector3(24, 10, 22), Color(0.4, 0.5, 0.7), Vector3(0, 25, 0)))
			root.add_child(_mesh_cyl(2, 12, Color(0.6, 0.65, 0.75), Vector3(0, 36, 0)))
			root.add_child(_mesh_sphere(3, Color(0.3, 0.8, 1.0), Vector3(0, 44, 0)))
			root.add_child(_mesh_box(Vector3(12, 14, 20), Color(0.3, 0.4, 0.6), Vector3(-22, 7, 0)))
			root.add_child(_mesh_box(Vector3(12, 14, 20), Color(0.3, 0.4, 0.6), Vector3(22, 7, 0)))
		"Turret":
			root.add_child(_mesh_box(Vector3(18, 10, 18), Color(0.3, 0.4, 0.6), Vector3(0, 5, 0)))
			var head = Node3D.new()
			head.name = "Head"
			head.position = Vector3(0, 13, 0)
			head.add_child(_mesh_box(Vector3(12, 7, 12), Color(0.35, 0.45, 0.65)))
			var barrel = _mesh_cyl(2, 18, Color(0.5, 0.55, 0.7), Vector3(0, 0, -9))
			barrel.rotation_degrees.x = 90
			head.add_child(barrel)
			root.add_child(head)
		"Factory":
			var factory_scene = load("res://scenes/factory_building.tscn").instantiate()
			root.add_child(factory_scene)
		"Wall":
			root.add_child(_mesh_box(Vector3(30, 18, 10), Color(0.5, 0.5, 0.55), Vector3(0, 9, 0)))
			root.add_child(_mesh_box(Vector3(6, 4, 11), Color(0.45, 0.45, 0.5), Vector3(-10, 20, 0)))
			root.add_child(_mesh_box(Vector3(6, 4, 11), Color(0.45, 0.45, 0.5), Vector3(10, 20, 0)))
		"Lightning Tower":
			root.add_child(_mesh_cyl(6, 8, Color(0.35, 0.25, 0.6), Vector3(0, 4, 0)))
			root.add_child(_mesh_cyl(4, 24, Color(0.4, 0.3, 0.65), Vector3(0, 16, 0)))
			root.add_child(_mesh_sphere(5, Color(0.6, 0.4, 1.0), Vector3(0, 32, 0)))
		"Slow Tower":
			root.add_child(_mesh_box(Vector3(16, 10, 16), Color(0.25, 0.4, 0.6), Vector3(0, 5, 0)))
			root.add_child(_mesh_cyl(3, 12, Color(0.3, 0.5, 0.7), Vector3(0, 13, 0)))
			root.add_child(_mesh_sphere(5, Color(0.4, 0.7, 1.0), Vector3(0, 24, 0)))
		"Pylon":
			root.add_child(_mesh_cyl(3, 24, Color(0.55, 0.6, 0.25), Vector3(0, 12, 0)))
			root.add_child(_mesh_box(Vector3(8, 3, 8), Color(0.65, 0.7, 0.3), Vector3(0, 26, 0)))
			root.add_child(_mesh_sphere(2, Color(0.8, 0.9, 0.4), Vector3(0, 29, 0)))
		"Power Plant":
			root.add_child(_mesh_box(Vector3(28, 14, 28), Color(0.65, 0.55, 0.2), Vector3(0, 7, 0)))
			root.add_child(_mesh_cyl(6, 8, Color(0.75, 0.65, 0.25), Vector3(0, 18, 0)))
			root.add_child(_mesh_sphere(3, Color(1.0, 0.9, 0.3), Vector3(0, 24, 0)))
		"Battery":
			root.add_child(_mesh_box(Vector3(16, 22, 16), Color(0.3, 0.55, 0.25), Vector3(0, 11, 0)))
			root.add_child(_mesh_box(Vector3(8, 4, 8), Color(0.4, 0.65, 0.3), Vector3(0, 24, 0)))
		"Flame Turret":
			root.add_child(_mesh_box(Vector3(18, 10, 18), Color(0.65, 0.35, 0.15), Vector3(0, 5, 0)))
			root.add_child(_mesh_cyl(4, 8, Color(0.75, 0.4, 0.15), Vector3(0, 14, 0)))
			root.add_child(_mesh_sphere(2, Color(1.0, 0.6, 0.2), Vector3(0, 20, 0)))
			# Fire particles (toggled by power state in _sync_3d_meshes)
			var fire_fx = GPUParticles3D.new()
			fire_fx.name = "FireFX"
			fire_fx.amount = 24
			fire_fx.lifetime = 0.8
			fire_fx.explosiveness = 0.1
			fire_fx.emitting = false
			var fpm = ParticleProcessMaterial.new()
			fpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			fpm.emission_sphere_radius = 8.0
			fpm.direction = Vector3(0, 1, 0)
			fpm.spread = 180.0
			fpm.initial_velocity_min = 10.0
			fpm.initial_velocity_max = 25.0
			fpm.gravity = Vector3(0, 5, 0)
			fpm.scale_min = 1.0
			fpm.scale_max = 3.0
			fpm.color = Color(1.0, 0.5, 0.1, 0.7)
			fire_fx.process_material = fpm
			var fsm = SphereMesh.new()
			fsm.radius = 1.5
			fsm.height = 3.0
			fire_fx.draw_pass_1 = fsm
			fire_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fire_fx.position = Vector3(0, 12, 0)
			root.add_child(fire_fx)
		"Acid Turret":
			root.add_child(_mesh_box(Vector3(18, 10, 18), Color(0.25, 0.55, 0.2), Vector3(0, 5, 0)))
			var ahead = Node3D.new()
			ahead.name = "Head"
			ahead.position = Vector3(0, 13, 0)
			ahead.add_child(_mesh_box(Vector3(10, 6, 10), Color(0.3, 0.6, 0.25)))
			var abarrel = _mesh_cyl(2, 16, Color(0.35, 0.65, 0.3), Vector3(0, 0, -8))
			abarrel.rotation_degrees.x = 90
			ahead.add_child(abarrel)
			root.add_child(ahead)
		"Repair Drone":
			root.add_child(_mesh_box(Vector3(16, 6, 16), Color(0.2, 0.5, 0.35), Vector3(0, 3, 0)))
			var drone = Node3D.new()
			drone.name = "Drone"
			drone.position = Vector3(0, 16, 0)
			drone.add_child(_mesh_box(Vector3(8, 4, 8), Color(0.25, 0.65, 0.4)))
			drone.add_child(_mesh_cyl(5, 1, Color(0.3, 0.7, 0.45), Vector3(0, 3, 0)))
			root.add_child(drone)
		"Poison Turret":
			root.add_child(_mesh_box(Vector3(18, 10, 18), Color(0.25, 0.45, 0.2), Vector3(0, 5, 0)))
			root.add_child(_mesh_cyl(4, 8, Color(0.3, 0.55, 0.15), Vector3(0, 14, 0)))
			root.add_child(_mesh_sphere(3, Color(0.4, 0.85, 0.2), Vector3(0, 20, 0)))
	return root


# ---- Other Mesh Factories ----

func _create_player_mesh(col: Color) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	body.name = "Body"
	var ship_scene = load("res://scenes/player_ship.tscn")
	var ship = ship_scene.instantiate()
	body.add_child(ship)
	root.add_child(body)
	return root


func _create_alien_mesh(a: Node3D) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	body.name = "Body"
	var is_boss = a.is_in_group("bosses")
	var atype = a.alien_type if "alien_type" in a else "basic"
	var mi = MeshInstance3D.new()
	mi.name = "Mesh"
	var pm = PrismMesh.new()
	var col: Color
	if is_boss:
		pm.size = Vector3(20, 28, 18)
		col = Color(0.7, 0.12, 0.08)
	elif a.get_script() == load("res://scripts/ranged_alien.gd"):
		pm.size = Vector3(10, 14, 10)
		col = Color(0.55, 0.2, 0.65)
	elif atype == "fast":
		pm.size = Vector3(7, 16, 8)
		col = Color(0.85, 0.5, 0.15)
	else:
		pm.size = Vector3(10, 14, 10)
		col = Color(0.75, 0.18, 0.1)
	pm.left_to_right = 0.5
	mi.mesh = pm
	var base_mat = _unlit_mat(col).duplicate()
	base_mat.next_pass = _dither_occlude_mat
	mi.material_override = base_mat
	mi.rotation.x = -PI / 2
	mi.position.y = pm.size.z * 0.5
	body.add_child(mi)
	root.add_child(body)
	root.set_meta("base_mat", base_mat)
	return root


func _get_crystal_mat() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _crystal_shader
	m.set_shader_parameter("crystal_color", Color(0.2, 0.45, 0.95))
	return m


func _get_iron_mat() -> StandardMaterial3D:
	if not _iron_material:
		_iron_material = StandardMaterial3D.new()
		_iron_material.albedo_color = Color(0.45, 0.18, 0.12)
		_iron_material.metallic = 0.85
		_iron_material.roughness = 0.35
		_iron_material.metallic_specular = 0.7
		_iron_material.emission_enabled = true
		_iron_material.emission = Color(0.7, 0.2, 0.1)
		_iron_material.emission_energy_multiplier = 0.4
		_iron_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_iron_material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		_iron_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return _iron_material


func _create_resource_mesh(rtype: String, amount: int) -> Node3D:
	var root = Node3D.new()
	var sz = 10.0 + amount * 0.5
	if rtype == "crystal":
		var mat = _get_crystal_mat()
		# Main crystal spire
		var mi1 = MeshInstance3D.new()
		var bm1 = BoxMesh.new()
		bm1.size = Vector3(sz * 0.45, sz * 1.1, sz * 0.45)
		mi1.mesh = bm1
		mi1.material_override = mat
		mi1.position = Vector3(0, sz * 0.55, 0)
		mi1.rotation_degrees = Vector3(0, 15, 5)
		root.add_child(mi1)
		# Secondary crystal shard
		var mi2 = MeshInstance3D.new()
		var bm2 = BoxMesh.new()
		bm2.size = Vector3(sz * 0.3, sz * 0.75, sz * 0.3)
		mi2.mesh = bm2
		var mat2 = _get_crystal_mat()
		mat2.set_shader_parameter("crystal_color", Color(0.3, 0.55, 1.0))
		mi2.material_override = mat2
		mi2.position = Vector3(sz * 0.22, sz * 0.37, sz * 0.12)
		mi2.rotation_degrees = Vector3(-8, -25, 12)
		root.add_child(mi2)
		# Small accent shard
		var mi3 = MeshInstance3D.new()
		var bm3 = BoxMesh.new()
		bm3.size = Vector3(sz * 0.2, sz * 0.5, sz * 0.2)
		mi3.mesh = bm3
		mi3.material_override = mat
		mi3.position = Vector3(-sz * 0.18, sz * 0.25, -sz * 0.1)
		mi3.rotation_degrees = Vector3(5, 40, -10)
		root.add_child(mi3)
	else:
		var iron_rock = load("res://scenes/iron_rock.tscn").instantiate()
		root.add_child(iron_rock)
	return root


# ---- Mesh Dict Cleanup ----

func _clean_mesh_dict(dict: Dictionary):
	for key in dict.keys():
		if not is_instance_valid(key):
			if is_instance_valid(dict[key]):
				dict[key].queue_free()
			dict.erase(key)


# ---- Master 3D Mesh Sync ----

func _sync_3d_meshes():
	# ---- Buildings ----
	_clean_mesh_dict(building_meshes)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b): continue
		if b not in building_meshes:
			var bname = b.get_building_name() if b.has_method("get_building_name") else ""
			var new_mesh = _create_building_mesh(bname)
			add_child(new_mesh)
			building_meshes[b] = new_mesh
			if not b.is_in_group("pylons"):
				b.visible = false
		var mr = building_meshes[b]
		var bp = b.global_position
		mr.position = Vector3(bp.x, 0, bp.z)
		# Turret / acid turret barrel rotation
		var head = mr.get_node_or_null("Head")
		if head and "target_angle" in b:
			head.rotation.y = -b.target_angle - PI / 2
		# Repair drone orbit
		var drone_node = mr.get_node_or_null("Drone")
		if drone_node and "drone_angle" in b:
			drone_node.position = Vector3(cos(b.drone_angle) * 12, 16, sin(b.drone_angle) * 12)
		# Flame turret particle toggle
		var fire_fx = mr.get_node_or_null("FireFX")
		if fire_fx and fire_fx is GPUParticles3D:
			var b_powered = b.has_method("is_powered") and b.is_powered()
			fire_fx.emitting = b_powered
			if b_powered and "pulse_timer" in b:
				var pulse = 0.6 + sin(b.pulse_timer * 4.0) * 0.4
				fire_fx.process_material.emission_sphere_radius = 8.0 + pulse * 15.0
		# Toggle scene-embedded lights & particles based on power/disabled state
		var b_active = (not b.has_method("is_powered") or b.is_powered()) and not ("manually_disabled" in b and b.manually_disabled)
		_set_scene_lights_visible(mr, b_active)
		# Unpowered indicator (red sphere above building)
		if b.has_method("is_powered"):
			var powered = b.is_powered()
			var poff = mr.get_node_or_null("PowerOff")
			if not powered:
				if not poff:
					poff = MeshInstance3D.new()
					poff.name = "PowerOff"
					var sm = SphereMesh.new()
					sm.radius = 3.0
					sm.height = 6.0
					poff.mesh = sm
					var mat = StandardMaterial3D.new()
					mat.albedo_color = Color(1.0, 0.1, 0.05)
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mat.emission_enabled = true
					mat.emission = Color(1.0, 0.15, 0.05)
					mat.emission_energy_multiplier = 2.0
					poff.material_override = mat
					poff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					poff.position.y = 38
					mr.add_child(poff)
				poff.visible = true
				# Blink effect
				var blink = fmod(Time.get_ticks_msec() * 0.003, 1.0) < 0.5
				poff.visible = blink
			elif poff:
				poff.visible = false

	# ---- Players ----
	_clean_mesh_dict(player_meshes)
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		if p not in player_meshes:
			var col = p.player_color if "player_color" in p else Color(0.2, 0.9, 0.3)
			var new_mesh = _create_player_mesh(col)
			add_child(new_mesh)
			player_meshes[p] = new_mesh
			p.visible = false
		var mr = player_meshes[p]
		var pp = p.global_position
		mr.position = Vector3(pp.x, 0, pp.z)
		mr.visible = not p.is_dead if "is_dead" in p else true
		var body = mr.get_node_or_null("Body")
		if body and "facing_angle" in p:
			body.rotation.y = -p.facing_angle - PI / 2
		# Orbital lasers — sync 3D spheres + lights
		var orb_count = p.upgrades.get("orbital_lasers", 0) if "upgrades" in p else 0
		var orb_parent = mr.get_node_or_null("Orbitals")
		if orb_count > 0:
			if not orb_parent:
				orb_parent = Node3D.new()
				orb_parent.name = "Orbitals"
				mr.add_child(orb_parent)
			# Add/remove orbital nodes to match count
			while orb_parent.get_child_count() < orb_count:
				var orb_node = Node3D.new()
				var orb_mi = MeshInstance3D.new()
				var orb_sm = SphereMesh.new()
				orb_sm.radius = 5.0
				orb_sm.height = 10.0
				orb_mi.mesh = orb_sm
				var orb_mat = StandardMaterial3D.new()
				orb_mat.albedo_color = Color(1.0, 0.3, 0.1)
				orb_mat.emission_enabled = true
				orb_mat.emission = Color(1.0, 0.5, 0.15)
				orb_mat.emission_energy_multiplier = 2.0
				orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				orb_mi.material_override = orb_mat
				orb_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				orb_node.add_child(orb_mi)
				var orb_light = OmniLight3D.new()
				orb_light.light_color = Color(1.0, 0.4, 0.1)
				orb_light.light_energy = 3.0
				orb_light.omni_range = 35.0
				orb_light.omni_attenuation = 1.2
				orb_light.shadow_enabled = false
				orb_node.add_child(orb_light)
				orb_parent.add_child(orb_node)
			while orb_parent.get_child_count() > orb_count:
				orb_parent.get_child(orb_parent.get_child_count() - 1).queue_free()
			# Position each orbital around the player
			var orb_angle = p.orbital_angle if "orbital_angle" in p else 0.0
			for i in range(mini(orb_count, orb_parent.get_child_count())):
				var ang = orb_angle + TAU * i / orb_count
				orb_parent.get_child(i).position = Vector3(cos(ang) * 80.0, 8, sin(ang) * 80.0)
			orb_parent.visible = mr.visible
		elif orb_parent:
			orb_parent.visible = false

	# ---- Aliens ----
	_clean_mesh_dict(alien_meshes)
	for a in get_tree().get_nodes_in_group("aliens"):
		if not is_instance_valid(a): continue
		if a not in alien_meshes:
			var new_mesh = _create_alien_mesh(a)
			add_child(new_mesh)
			alien_meshes[a] = new_mesh
			a.visible = false
		var mr = alien_meshes[a]
		var ap = a.global_position
		mr.position = Vector3(ap.x, 0, ap.z)
		var body = mr.get_node_or_null("Body")
		if body and "move_direction" in a and a.move_direction.length_squared() > 0.01:
			var target_rot = atan2(-a.move_direction.x, -a.move_direction.z)
			body.rotation.y = lerp_angle(body.rotation.y, target_rot, minf(8.0 * get_process_delta_time(), 1.0))
		# Hit flash
		var mesh_node = body.get_node_or_null("Mesh") if body else null
		if mesh_node and mesh_node is MeshInstance3D:
			var flashing = "hit_flash_timer" in a and a.hit_flash_timer > 0
			if flashing:
				mesh_node.material_override = _flash_white_mat
			else:
				var bm = mr.get_meta("base_mat", null)
				if bm:
					mesh_node.material_override = bm
		# Status effect FX
		var has_burn = "burn_timer" in a and a.burn_timer > 0
		var has_slow = ("slow_timer" in a and a.slow_timer > 0) or ("tower_slow" in a and a.tower_slow > 0) if "tower_slow" in a else ("slow_timer" in a and a.slow_timer > 0)
		var has_poison = "poison_timer" in a and a.poison_timer > 0
		var alien_sz = 28.0 if a.is_in_group("bosses") else 14.0
		_ensure_burn_fx(mr, has_burn)
		_ensure_frozen_fx(mr, has_slow, alien_sz)
		_ensure_poison_fx(mr, has_poison)

	# ---- Resources (shrink as they're mined) ----
	_clean_mesh_dict(resource_meshes)
	for key in resource_init_amt.keys():
		if not is_instance_valid(key):
			resource_init_amt.erase(key)
	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r): continue
		if r not in resource_meshes:
			var _t0 = Time.get_ticks_usec()
			var rtype = r.resource_type if "resource_type" in r else "iron"
			var amt = r.amount if "amount" in r else 10
			var new_mesh = _create_resource_mesh(rtype, amt)
			add_child(new_mesh)
			resource_meshes[r] = new_mesh
			resource_init_amt[r] = amt
			r.visible = false
			print("[RESOURCE] Created ", rtype, " mesh in ", (Time.get_ticks_usec() - _t0) / 1000.0, "ms")
		var mr = resource_meshes[r]
		mr.position = Vector3(r.global_position.x, 0, r.global_position.z)
		# Scale down as resource is mined
		var cur_amt = r.amount if "amount" in r else 1
		var init_amt = resource_init_amt.get(r, cur_amt)
		if init_amt > 0:
			var s = clampf(float(cur_amt) / float(init_amt), 0.15, 1.0)
			var prev_s = mr.scale.x
			mr.scale = Vector3(s, s, s)
			if abs(s - prev_s) > 0.001:
				var _t1 = Time.get_ticks_usec()
				print("[RESOURCE] Scaled ", r.resource_type if "resource_type" in r else "?", " to ", snapped(s, 0.01), " in ", (Time.get_ticks_usec() - _t1) / 1000.0, "ms")

	# ---- XP Gems (billboard) ----
	_clean_mesh_dict(gem_meshes)
	for g in get_tree().get_nodes_in_group("xp_gems"):
		if not is_instance_valid(g): continue
		if g not in gem_meshes:
			var gsz = g.gem_size if "gem_size" in g else 1
			var col = Color(0.3, 0.9, 0.4)
			if gsz == 2: col = Color(0.3, 0.6, 1.0)
			elif gsz >= 3: col = Color(0.9, 0.3, 0.9)
			var mr = Node3D.new()
			var mi = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 3.0 + gsz * 1.5
			sm.height = sm.radius * 2
			mi.mesh = sm
			mi.material_override = _bb_mat(col)
			mi.position.y = 6
			mr.add_child(mi)
			add_child(mr)
			gem_meshes[g] = mr
			g.visible = false
		gem_meshes[g].position = Vector3(g.global_position.x, 0, g.global_position.z)

	# ---- Powerups (3D Sprite3D billboard with icons) ----
	_clean_mesh_dict(powerup_meshes)
	for pu in get_tree().get_nodes_in_group("powerups"):
		if not is_instance_valid(pu): continue
		if pu not in powerup_meshes:
			var ptype = pu.powerup_type if "powerup_type" in pu else "magnet"
			var tex = _powerup_textures.get(ptype)
			var mr = Node3D.new()
			var spr = Sprite3D.new()
			spr.texture = tex
			spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			spr.no_depth_test = true
			spr.shaded = false
			spr.transparent = true
			spr.pixel_size = 0.5
			spr.position.y = 10
			mr.add_child(spr)
			add_child(mr)
			powerup_meshes[pu] = mr
			pu.visible = false
		var bob = sin(pu.bob_offset) * 4.0 if "bob_offset" in pu else 0.0
		powerup_meshes[pu].position = Vector3(pu.global_position.x, bob, pu.global_position.z)

	# ---- Prestige Orbs (billboard) ----
	_clean_mesh_dict(orb_meshes)
	for o in get_tree().get_nodes_in_group("prestige_orbs"):
		if not is_instance_valid(o): continue
		if o not in orb_meshes:
			var mr = Node3D.new()
			var mi = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 5
			sm.height = 10
			mi.mesh = sm
			mi.material_override = _bb_mat(Color(1.0, 0.85, 0.3))
			mi.position.y = 6
			mr.add_child(mi)
			add_child(mr)
			orb_meshes[o] = mr
			o.visible = false
		orb_meshes[o].position = Vector3(o.global_position.x, 0, o.global_position.z)

	# ---- Bullets (billboard + point light, scan game_world_2d children) ----
	_clean_mesh_dict(bullet_meshes)
	for child in game_world_2d.get_children():
		if not is_instance_valid(child): continue
		if not ("direction" in child and "lifetime" in child): continue
		if child in bullet_meshes: continue
		var is_enemy = child.get_script() == load("res://scripts/enemy_bullet.gd")
		var col = Color(1.0, 0.9, 0.2)
		if "from_turret" in child and child.from_turret:
			col = Color(0.3, 0.9, 1.0)
		elif is_enemy:
			col = Color(0.8, 0.2, 1.0)
		var mr = Node3D.new()
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 3
		sm.height = 6
		mi.mesh = sm
		mi.material_override = _bb_mat(col)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 8
		mr.add_child(mi)
		# Point light per bullet
		var bl = OmniLight3D.new()
		bl.light_color = col
		bl.light_energy = 1.5 if is_enemy else 1.0
		bl.omni_range = 25.0 if is_enemy else 20.0
		bl.omni_attenuation = 1.5
		bl.shadow_enabled = false
		bl.position.y = 8
		mr.add_child(bl)
		add_child(mr)
		bullet_meshes[child] = mr
		child.visible = false
	for b in bullet_meshes:
		if is_instance_valid(b):
			bullet_meshes[b].position = Vector3(b.global_position.x, 0, b.global_position.z)

	# ---- Acid Puddles (ground disc) ----
	_clean_mesh_dict(puddle_meshes)
	for p in get_tree().get_nodes_in_group("acid_puddles"):
		if not is_instance_valid(p): continue
		if p not in puddle_meshes:
			var mi = MeshInstance3D.new()
			var pm = PlaneMesh.new()
			var r = p.radius if "radius" in p else 40.0
			pm.size = Vector2(r * 2, r * 2)
			mi.mesh = pm
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.8, 0.15, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.9, 0.1)
			mat.emission_energy_multiplier = 0.6
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position.y = 0.12
			add_child(mi)
			puddle_meshes[p] = mi
			p.visible = false
		var pmi = puddle_meshes[p]
		pmi.position.x = p.global_position.x
		pmi.position.z = p.global_position.z
		# Fade out in last second
		var fade = clampf(p.lifetime / 1.0, 0.0, 1.0) if "lifetime" in p else 1.0
		pmi.material_override.albedo_color.a = 0.35 * fade


func _get_combat_aoe(b: Node3D) -> Dictionary:
	if not b.has_method("get_building_name"): return {}
	match b.get_building_name():
		"Turret": return {"radius": CFG.turret_range, "color": Color(0.5, 0.8, 1.0, 0.35), "ring_width": 0.04}
		"Lightning Tower": return {"radius": CFG.lightning_range, "color": Color(0.6, 0.4, 1.0, 0.4), "ring_width": 0.12}
		"Slow Tower": return {"radius": CFG.slow_range, "color": Color(0.4, 0.7, 1.0, 0.4), "ring_width": 0.12}
		"Flame Turret": return {"radius": CFG.flame_range, "color": Color(1.0, 0.5, 0.2, 0.4), "ring_width": 0.12}
		"Acid Turret": return {"radius": CFG.acid_range, "color": Color(0.3, 0.9, 0.2, 0.4), "ring_width": 0.12}
		"Repair Drone": return {"radius": CFG.repair_drone_range, "color": Color(0.3, 1.0, 0.4, 0.4), "ring_width": 0.12}
		"Poison Turret": return {"radius": CFG.poison_range, "color": Color(0.3, 0.85, 0.15, 0.4), "ring_width": 0.12}
	return {}


func _get_energy_radius(b: Node3D) -> float:
	if not b.has_method("get_building_name"): return 0.0
	match b.get_building_name():
		"HQ": return CFG.power_range_hq
		"Power Plant": return CFG.power_range_plant
		"Pylon": return CFG.power_range_pylon
	return 0.0


func _create_aoe_ring(radius: float, color: Color, ring_width: float = 0.2) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(radius * 2, radius * 2)
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = ShaderMaterial.new()
	mat.shader = _aoe_shader
	mat.set_shader_parameter("ring_color", color)
	mat.set_shader_parameter("ring_width", ring_width)
	mi.material_override = mat
	mi.position.y = 0.15
	return mi


func _sync_aoe_rings():
	# Clean up rings for destroyed buildings
	for key in aoe_meshes.keys():
		if not is_instance_valid(key):
			if is_instance_valid(aoe_meshes[key]):
				aoe_meshes[key].queue_free()
			aoe_meshes.erase(key)

	# --- Combat range rings (only for selected building) ---
	var sel_b = hud_node.selected_building if is_instance_valid(hud_node) and "selected_building" in hud_node else null
	if is_instance_valid(sel_b):
		var info = _get_combat_aoe(sel_b)
		if not info.is_empty():
			if sel_b not in aoe_meshes:
				var ring = _create_aoe_ring(info["radius"], info["color"], info["ring_width"])
				add_child(ring)
				aoe_meshes[sel_b] = ring
			aoe_meshes[sel_b].position = Vector3(sel_b.global_position.x, 0.15, sel_b.global_position.z)
			aoe_meshes[sel_b].visible = true
	# Hide rings for non-selected buildings
	for key in aoe_meshes.keys():
		if key != sel_b and is_instance_valid(aoe_meshes[key]):
			aoe_meshes[key].visible = false

	# --- Energy merged disc (only during build mode) ---
	var in_build_mode = is_instance_valid(player_node) and "build_mode" in player_node and player_node.build_mode != ""
	if in_build_mode:
		var sources: Array = []
		var max_sources = 32
		# HQ
		if is_instance_valid(hq_node):
			var p = hq_node.global_position
			sources.append(Vector4(p.x, p.z, CFG.power_range_hq, 0))
		# All power buildings
		for b in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(b): continue
			var r = _get_energy_radius(b)
			if r > 0 and not b.is_in_group("hq"):
				var p = b.global_position
				sources.append(Vector4(p.x, p.z, r, 0))
			if sources.size() >= max_sources:
				break
		_energy_proj_mat.set_shader_parameter("source_count", sources.size())
		# Pad array to match shader uniform array size
		while sources.size() < max_sources:
			sources.append(Vector4(0, 0, 0, 0))
		_energy_proj_mat.set_shader_parameter("sources", sources)
		_energy_proj_mesh.visible = true
	else:
		_energy_proj_mesh.visible = false

	# --- Player damage aura (always visible when active) ---
	if is_instance_valid(player_node) and "upgrades" in player_node:
		var aura_lv = player_node.upgrades.get("damage_aura", 0)
		if aura_lv > 0:
			var r = CFG.aura_radius_base + aura_lv * CFG.aura_radius_per_level
			if not is_instance_valid(aoe_player_mesh):
				aoe_player_mesh = _create_aoe_ring(r, Color(0.8, 0.2, 0.8, 0.45))
				add_child(aoe_player_mesh)
			var cur_size = aoe_player_mesh.mesh.size.x / 2.0
			if absf(cur_size - r) > 1.0:
				aoe_player_mesh.mesh.size = Vector2(r * 2, r * 2)
			var pp = player_node.global_position
			aoe_player_mesh.position = Vector3(pp.x, 0.15, pp.z)
			aoe_player_mesh.visible = not (player_node.is_dead if "is_dead" in player_node else false)
		else:
			if is_instance_valid(aoe_player_mesh):
				aoe_player_mesh.visible = false
	else:
		if is_instance_valid(aoe_player_mesh):
			aoe_player_mesh.visible = false

	# --- Player shoot range ring (visible when mouse hovers player) ---
	if is_instance_valid(player_node) and player_node.has_method("get_shoot_range"):
		var pp = player_node.global_position
		var mouse_dist = mouse_world_2d.distance_to(pp)
		var show_range = mouse_dist < 40.0 and not player_node.is_dead
		if show_range:
			var r = player_node.get_shoot_range()
			if not is_instance_valid(shoot_range_mesh):
				shoot_range_mesh = _create_aoe_ring(r, Color(0.9, 0.9, 0.3, 0.3), 0.08)
				add_child(shoot_range_mesh)
			var cur_size = shoot_range_mesh.mesh.size.x / 2.0
			if absf(cur_size - r) > 1.0:
				shoot_range_mesh.mesh.size = Vector2(r * 2, r * 2)
			shoot_range_mesh.position = Vector3(pp.x, 0.15, pp.z)
			shoot_range_mesh.visible = true
		else:
			if is_instance_valid(shoot_range_mesh):
				shoot_range_mesh.visible = false
	else:
		if is_instance_valid(shoot_range_mesh):
			shoot_range_mesh.visible = false


func _sync_pylon_wires():
	# Track which wire keys are still active this frame
	var active_keys: Dictionary = {}

	# Pylon-to-pylon wires
	var pylons = get_tree().get_nodes_in_group("pylons")
	for i in range(pylons.size()):
		var pa = pylons[i]
		if not is_instance_valid(pa): continue
		for j in range(i + 1, pylons.size()):
			var pb = pylons[j]
			if not is_instance_valid(pb): continue
			var dist = pa.global_position.distance_to(pb.global_position)
			if dist >= pa.POWER_RANGE * 2: continue
			var key = "%d_%d" % [pa.get_instance_id(), pb.get_instance_id()]
			active_keys[key] = true
			var powered = pa.is_powered() and pb.is_powered()
			if key not in wire_meshes:
				var mi = MeshInstance3D.new()
				mi.mesh = CylinderMesh.new()
				mi.mesh.top_radius = 0.5
				mi.mesh.bottom_radius = 0.5
				mi.mesh.radial_segments = 4
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
				wire_meshes[key] = mi
			var wmi = wire_meshes[key]
			wmi.material_override = _wire_mat_powered if powered else _wire_mat_unpowered
			var a_pos = Vector3(pa.global_position.x, 26, pa.global_position.z)
			var b_pos = Vector3(pb.global_position.x, 26, pb.global_position.z)
			var mid = (a_pos + b_pos) * 0.5
			mid.y -= dist * 0.04  # slight sag
			var diff = b_pos - a_pos
			var wire_len = diff.length()
			wmi.mesh.height = wire_len
			wmi.position = mid
			wmi.look_at_from_position(mid, b_pos, Vector3.UP)
			wmi.rotation.x += PI / 2.0
			wmi.visible = true

	# Pylon-to-power-plant wires
	for pa in pylons:
		if not is_instance_valid(pa): continue
		for plant in get_tree().get_nodes_in_group("power_plants"):
			if not is_instance_valid(plant): continue
			var dist = pa.global_position.distance_to(plant.global_position)
			var max_dist = pa.POWER_RANGE + plant.POWER_RANGE
			if dist >= max_dist: continue
			var key = "pp_%d_%d" % [pa.get_instance_id(), plant.get_instance_id()]
			active_keys[key] = true
			if key not in wire_meshes:
				var mi = MeshInstance3D.new()
				mi.mesh = CylinderMesh.new()
				mi.mesh.top_radius = 0.5
				mi.mesh.bottom_radius = 0.5
				mi.mesh.radial_segments = 4
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
				wire_meshes[key] = mi
			var wmi = wire_meshes[key]
			wmi.material_override = _wire_mat_powered  # plant always provides power
			var a_pos = Vector3(pa.global_position.x, 26, pa.global_position.z)
			var b_pos = Vector3(plant.global_position.x, 22, plant.global_position.z)
			var mid = (a_pos + b_pos) * 0.5
			mid.y -= dist * 0.04
			var diff = b_pos - a_pos
			var wire_len = diff.length()
			wmi.mesh.height = wire_len
			wmi.position = mid
			wmi.look_at_from_position(mid, b_pos, Vector3.UP)
			wmi.rotation.x += PI / 2.0
			wmi.visible = true

	# Clean up wires for destroyed buildings
	for key in wire_meshes.keys():
		if key not in active_keys:
			if is_instance_valid(wire_meshes[key]):
				wire_meshes[key].queue_free()
			wire_meshes.erase(key)


func _sync_nuke_visual():
	var active = false
	if is_instance_valid(player_node) and "nuke_radius" in player_node:
		var r = player_node.nuke_radius
		if r > 0:
			active = true
			var origin = player_node.nuke_origin if "nuke_origin" in player_node else player_node.global_position
			_nuke_ring_mesh.position = Vector3(origin.x, 0.2, origin.z)
			_nuke_ring_mesh.scale = Vector3(r, 1, r)
			_nuke_ring_mesh.visible = true
			# Flash light — bright at start, fades as it expands
			var progress = r / CFG.nuke_range
			_nuke_flash_light.position = Vector3(origin.x, 30, origin.z)
			_nuke_flash_light.light_energy = lerpf(20.0, 0.0, progress)
			_nuke_flash_light.visible = true
	if not active:
		_nuke_ring_mesh.visible = false
		_nuke_flash_light.visible = false
		_nuke_flash_light.light_energy = 0.0


func _apply_ghost_material(node: Node, mat: StandardMaterial3D):
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat
		if child is Light3D or child is GPUParticles3D:
			child.visible = false
		_apply_ghost_material(child, mat)


func _set_ghost_color(node: Node, col: Color):
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override:
			child.material_override.albedo_color = col
		_set_ghost_color(child, col)


func _set_scene_lights_visible(node: Node, on: bool):
	for child in node.get_children():
		if child is Light3D:
			child.visible = on
		if child is GPUParticles3D and child.name != "FireFX" and child.name != "PowerOff":
			child.emitting = on
		_set_scene_lights_visible(child, on)


func _sync_build_preview():
	if not is_instance_valid(player_node):
		if is_instance_valid(build_preview_mesh):
			build_preview_mesh.visible = false
		return
	var bmode = player_node.build_mode if "build_mode" in player_node else ""
	if bmode == "":
		if is_instance_valid(build_preview_mesh):
			build_preview_mesh.visible = false
		build_preview_type = ""
		return
	# Recreate mesh if building type changed
	if bmode != build_preview_type:
		if is_instance_valid(build_preview_mesh):
			build_preview_mesh.queue_free()
		var name_map = {
			"turret": "Turret", "factory": "Factory", "wall": "Wall",
			"lightning": "Lightning Tower", "slow": "Slow Tower", "pylon": "Pylon",
			"power_plant": "Power Plant", "battery": "Battery",
			"flame_turret": "Flame Turret", "acid_turret": "Acid Turret",
			"repair_drone": "Repair Drone", "poison_turret": "Poison Turret"
		}
		build_preview_mesh = _create_building_mesh(name_map.get(bmode, ""))
		# Make semi-transparent ghost material for all mesh children
		var ghost_mat = StandardMaterial3D.new()
		ghost_mat.albedo_color = Color(0.3, 1.0, 0.5, 0.4)
		ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_apply_ghost_material(build_preview_mesh, ghost_mat)
		add_child(build_preview_mesh)
		build_preview_type = bmode
	# Position at snapped mouse world pos
	var bp: Vector3
	if "is_mobile" in player_node and player_node.is_mobile and "pending_build_world_pos" in player_node and player_node.pending_build_world_pos != Vector3.ZERO:
		bp = player_node.pending_build_world_pos
	else:
		bp = mouse_world_2d.snapped(Vector3(40, 0, 40))
	build_preview_mesh.position = bp
	build_preview_mesh.visible = true
	# Color based on validity
	var valid = player_node.can_place_at(bp) and player_node.can_afford(bmode)
	var ghost_col = Color(0.3, 1.0, 0.5, 0.4) if valid else Color(1.0, 0.3, 0.3, 0.4)
	_set_ghost_color(build_preview_mesh, ghost_col)


func _spawn_wave():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Use the pre-determined direction for this wave
	var wave_dir = next_wave_direction

	# Pick direction for NEXT wave and tell HUD
	next_wave_direction = rng.randf() * TAU
	if is_instance_valid(hud_node):
		hud_node.set_wave_direction(next_wave_direction)

	# Slower scaling: fewer enemies early on, scale for player count
	var mp_scale = 1.0 + (players.size() - 1) * 0.5
	var basic_count = int((2 + wave_number) * mp_scale)
	_spawn_aliens("basic", basic_count, rng, wave_dir)
	if wave_number >= CFG.alien_fast_start_wave:
		_spawn_aliens("fast", int(maxi(1, wave_number - 3) * mp_scale), rng, wave_dir)
	if wave_number >= CFG.alien_ranged_start_wave:
		_spawn_aliens("ranged", int(mini(wave_number - 5, CFG.alien_ranged_max_count) * mp_scale), rng, wave_dir)
	if wave_number >= CFG.boss_start_wave and wave_number % CFG.boss_wave_interval == 0:
		_spawn_boss(rng, wave_dir)
	if is_instance_valid(hud_node):
		hud_node.show_wave_alert(wave_number, wave_number >= CFG.boss_start_wave and wave_number % CFG.boss_wave_interval == 0)


func _get_player_centroid() -> Vector3:
	var total = Vector3.ZERO
	var count = 0
	for p in players.values():
		if is_instance_valid(p) and not p.is_dead:
			total += p.global_position
			count += 1
	if count == 0:
		return Vector3.ZERO
	return total / count


func _get_offscreen_spawn_pos(base_angle: float, rng: RandomNumberGenerator) -> Vector3:
	# Spawn outside map bounds so enemies walk in and don't land on buildings
	var spread = rng.randf_range(-0.4, 0.4)  # ~45 degree spread
	var angle = base_angle + spread
	var dist = rng.randf_range(850, 1100)
	var spawn_pos = _get_player_centroid() + Vector3(cos(angle), 0, sin(angle)) * dist
	var margin = CFG.map_half_size + 200.0
	spawn_pos.x = clampf(spawn_pos.x, -margin, margin)
	spawn_pos.z = clampf(spawn_pos.z, -margin, margin)
	return spawn_pos


func _spawn_aliens(type: String, count: int, rng: RandomNumberGenerator, wave_dir: float):
	for i in range(count):
		var spawn_pos = _get_offscreen_spawn_pos(wave_dir, rng)
		var alien: Node3D
		match type:
			"basic":
				alien = load("res://scenes/alien.tscn").instantiate()
				alien.hp = CFG.alien_basic_base_hp + wave_number * CFG.alien_basic_hp_per_wave
				alien.max_hp = alien.hp
				alien.damage = CFG.alien_basic_base_damage + wave_number * CFG.alien_basic_damage_per_wave
				alien.speed = CFG.alien_basic_base_speed + wave_number * CFG.alien_basic_speed_per_wave
				alien.xp_value = CFG.alien_basic_xp
			"fast":
				alien = load("res://scenes/alien.tscn").instantiate()
				alien.hp = CFG.alien_fast_base_hp + wave_number * CFG.alien_fast_hp_per_wave
				alien.max_hp = alien.hp
				alien.damage = CFG.alien_fast_base_damage + wave_number * CFG.alien_fast_damage_per_wave
				alien.speed = CFG.alien_fast_base_speed + wave_number * CFG.alien_fast_speed_per_wave
				alien.xp_value = CFG.alien_fast_xp
				alien.alien_type = "fast"
			"ranged":
				alien = load("res://scenes/ranged_alien.tscn").instantiate()
				alien.hp = CFG.alien_ranged_base_hp + wave_number * CFG.alien_ranged_hp_per_wave
				alien.max_hp = alien.hp
				alien.damage = CFG.alien_ranged_base_damage + wave_number * CFG.alien_ranged_damage_per_wave
				alien.speed = CFG.alien_ranged_base_speed + wave_number * CFG.alien_ranged_speed_per_wave
				alien.xp_value = CFG.alien_ranged_xp
		alien.position = spawn_pos
		alien.net_id = next_net_id
		next_net_id += 1
		aliens_node.add_child(alien)
		alien_net_ids[alien.net_id] = alien


func _spawn_boss(rng: RandomNumberGenerator, wave_dir: float):
	var boss = load("res://scenes/boss_alien.tscn").instantiate()
	boss.position = _get_offscreen_spawn_pos(wave_dir, rng)
	boss.hp = CFG.boss_base_hp + wave_number * CFG.boss_hp_per_wave
	boss.max_hp = boss.hp
	boss.damage = CFG.boss_base_damage + wave_number * CFG.boss_damage_per_wave
	boss.speed = CFG.boss_speed
	boss.xp_value = CFG.boss_xp
	boss.wave_level = wave_number
	boss.net_id = next_net_id
	next_net_id += 1
	aliens_node.add_child(boss)
	alien_net_ids[boss.net_id] = boss


func _on_player_level_up():
	pending_upgrades += 1


func _try_show_upgrade():
	if is_instance_valid(hud_node) and not hud_node.is_upgrade_showing():
		if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
			_start_vote_round()
		elif not NetworkManager.is_multiplayer_active():
			hud_node.show_upgrade_selection(player_node.upgrades)
			get_tree().paused = true


func _on_upgrade_chosen(upgrade_key: String):
	if NetworkManager.is_multiplayer_active() and vote_active:
		# Submit vote instead of applying immediately
		if NetworkManager.is_host():
			_receive_vote(multiplayer.get_unique_id(), upgrade_key)
		else:
			_rpc_submit_vote.rpc_id(1, upgrade_key, vote_round)
		return
	# Single player path
	if is_instance_valid(player_node):
		player_node.apply_upgrade(upgrade_key)
	pending_upgrades -= 1
	get_tree().paused = false
	upgrade_cooldown = 0.4


func _on_game_started(start_wave: int):
	starting_wave = start_wave
	run_prestige = 0
	# Create all gameplay objects (deferred from _ready to avoid loading during menu)
	await _init_game_world()
	# Apply research bonuses
	if is_instance_valid(player_node):
		player_node.iron += int(GameData.get_research_bonus("starting_iron"))
		player_node.crystal += int(GameData.get_research_bonus("starting_crystal"))
		player_node.max_health += int(GameData.get_research_bonus("max_health"))
		player_node.health = player_node.max_health
		player_node.research_move_speed = GameData.get_research_bonus("move_speed")
		player_node.research_damage = int(GameData.get_research_bonus("base_damage"))
		player_node.research_mining_speed = GameData.get_research_bonus("mining_speed")
		player_node.research_xp_gain = GameData.get_research_bonus("xp_gain")
	# Start at selected wave
	is_first_wave = true
	if starting_wave > 1:
		wave_number = starting_wave - 1
		wave_timer = 5.0 + 15.0  # Short delay + extra prep time for first wave
	else:
		wave_timer = CFG.first_wave_delay + 15.0  # Extra prep time for first wave

	# Apply building health research to HQ
	var health_bonus = GameData.get_research_bonus("building_health")
	if health_bonus > 0 and is_instance_valid(hq_node):
		var bonus_hp = int(hq_node.max_hp * health_bonus)
		hq_node.hp += bonus_hp
		hq_node.max_hp += bonus_hp

	# Start with HQ energy bank full
	power_bank = CFG.hq_energy_storage

	# Initialize first wave direction
	next_wave_direction = randf() * TAU
	if is_instance_valid(hud_node):
		hud_node.set_wave_direction(next_wave_direction)

	# Multiplayer setup
	if NetworkManager.is_multiplayer_active():
		NetworkManager.peer_disconnected.connect(_on_game_peer_disconnected)
		var my_id = multiplayer.get_unique_id()
		player_node.peer_id = my_id
		players.erase(1)
		players[my_id] = player_node
		# Set local player name
		var local_name = hud_node.local_player_name if is_instance_valid(hud_node) and hud_node.local_player_name != "" else "Player"
		player_node.player_name = local_name
		player_names[my_id] = local_name
		if NetworkManager.is_host():
			player_node.player_color = PLAYER_COLORS[0]
			var peers = multiplayer.get_peers()
			var peer_info: Array = []
			for i in range(peers.size()):
				var pid = peers[i]
				var color_idx = (i + 1) % PLAYER_COLORS.size()
				_spawn_remote_player(pid, PLAYER_COLORS[color_idx])
				players[pid].player_name = player_names.get(pid, "Player")
				peer_info.append([pid, color_idx, player_names.get(pid, "Player")])
			# Wait for all clients to finish loading before starting gameplay
			if peers.size() > 0:
				_waiting_for_clients = true
				clients_ready.clear()
				for pid in peers:
					clients_ready[pid] = false
			_rpc_start_game.rpc(starting_wave, peer_info, GameData.research.duplicate())
			if _waiting_for_clients and is_instance_valid(hud_node):
				hud_node.show_alert("Waiting for players to load...")
		else:
			var my_color_idx = _get_color_index_for_peer(my_id)
			player_node.player_color = PLAYER_COLORS[my_color_idx]
			_spawn_remote_player(1, PLAYER_COLORS[0])


func _input(event):
	if event.is_action_pressed("pause"):
		if is_instance_valid(hud_node):
			hud_node.toggle_pause()
	# Debug dump: Ctrl+Shift+Home
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME and event.ctrl_pressed and event.shift_pressed:
		_debug_dump()


func _debug_dump():
	var is_host = not NetworkManager.is_multiplayer_active() or NetworkManager.is_host()
	var role = "HOST" if is_host else "CLIENT"
	var peer_id = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active() else 0
	var lines: PackedStringArray = []
	lines.append("=== DEBUG DUMP [%s] peer=%d ===" % [role, peer_id])
	lines.append("wave=%d timer=%.1f active=%s first=%s" % [wave_number, wave_timer, wave_active, is_first_wave])

	# Players
	var player_count = get_tree().get_nodes_in_group("player").size()
	lines.append("players_in_scene=%d players_dict=%d" % [player_count, players.size()])
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			var local = "LOCAL" if ("is_local" in p and p.is_local) else "REMOTE"
			lines.append("  player pid=%d %s pos=(%.0f,%.0f) hp=%d/%d dead=%s color=%s mine_targets=%d" % [
				pid, local, p.global_position.x, p.global_position.z,
				p.health, p.max_health, p.is_dead,
				p.player_color.to_html(), p.mine_targets.size()])

	# Buildings
	var buildings = get_tree().get_nodes_in_group("buildings")
	var building_hash = 0
	for b in buildings:
		if is_instance_valid(b):
			building_hash += int(b.global_position.x * 7 + b.global_position.z * 13)
			if "hp" in b:
				building_hash += b.hp
	lines.append("buildings=%d hash=%d" % [buildings.size(), building_hash])

	# Resources
	var resources = get_tree().get_nodes_in_group("resources")
	var res_hash = 0
	var res_iron = 0
	var res_crystal = 0
	for r in resources:
		if is_instance_valid(r):
			res_hash += int(r.global_position.x * 7 + r.global_position.z * 13 + r.amount)
			if r.resource_type == "iron":
				res_iron += 1
			else:
				res_crystal += 1
	lines.append("resources=%d (iron=%d crystal=%d) hash=%d" % [resources.size(), res_iron, res_crystal, res_hash])

	# Aliens
	var aliens = get_tree().get_nodes_in_group("aliens")
	var alien_hash = 0
	for a in aliens:
		if is_instance_valid(a):
			alien_hash += int(a.global_position.x * 3 + a.global_position.z * 7)
			if "hp" in a:
				alien_hash += a.hp
	lines.append("aliens=%d hash=%d" % [aliens.size(), alien_hash])

	# 3D mesh counts
	lines.append("3d_meshes: players=%d buildings=%d aliens=%d resources=%d" % [
		player_meshes.size(), building_meshes.size(), alien_meshes.size(), resource_meshes.size()])

	# Lights
	var pl_lights = 0
	var bl_lights = 0
	var al_lights = 0
	var rl_lights = 0
	for k in player_lights:
		if is_instance_valid(player_lights[k]): pl_lights += 1
	for k in building_lights:
		if is_instance_valid(building_lights[k]): bl_lights += 1
	for k in alien_lights:
		if is_instance_valid(alien_lights[k]): al_lights += 1
	for k in resource_lights:
		if is_instance_valid(resource_lights[k]): rl_lights += 1
	lines.append("3d_lights: players=%d buildings=%d aliens=%d resources=%d" % [pl_lights, bl_lights, al_lights, rl_lights])

	# Mining lasers
	lines.append("mining_lasers=%d" % mining_laser_beams.size())

	# Power
	lines.append("power: bank=%.0f/%.0f on=%s gen=%.1f consume=%.1f" % [
		power_bank, max_power_bank, power_on, total_power_gen, total_power_consumption])

	var dump = "\n".join(lines)
	print(dump)
	DisplayServer.clipboard_set(dump)
	if is_instance_valid(hud_node) and is_instance_valid(hud_node.alert_label):
		hud_node.alert_label.text = "Debug dump copied to clipboard"
		hud_node.alert_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		hud_node.alert_label.visible = true
		hud_node.alert_timer = 3.0


func on_player_died(dead_player: Node3D = null):
	# In MP, respawn after 10s unless ALL players are dead
	if NetworkManager.is_multiplayer_active():
		var all_dead = true
		for p in players.values():
			if is_instance_valid(p) and not p.is_dead:
				all_dead = false
				break
		if not all_dead:
			# Start respawn timer for the dead player (host only)
			if dead_player and NetworkManager.is_host():
				respawn_timers[dead_player.peer_id] = 10.0
			return
	_end_run()


func _end_run():
	game_over = true
	respawn_timers.clear()
	# Divide run prestige evenly among all players
	var player_count = maxi(players.size(), 1)
	var prestige_share = run_prestige / player_count
	# Restore client's own research before saving
	if _client_own_research.size() > 0:
		GameData.research = _client_own_research
		_client_own_research = {}
	GameData.add_prestige(prestige_share)
	GameData.record_run(wave_number, bosses_killed)
	if is_instance_valid(hud_node):
		hud_node.show_death_screen(wave_number, bosses_killed, prestige_share, GameData.prestige_points)
	# Notify clients of game over in MP
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
		_rpc_game_over.rpc(wave_number, bosses_killed, prestige_share)


func _on_hq_destroyed():
	# Notify clients to destroy their HQ too
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
		_rpc_hq_destroyed.rpc()
	# Clean up HQ light (mesh cleanup happens in _sync_3d_meshes)
	if is_instance_valid(hq_light_3d):
		hq_light_3d.queue_free()
	# HQ destruction also kills the player
	if is_instance_valid(player_node) and not player_node.is_dead:
		player_node.health = 0
		player_node.is_dead = true
		player_node._spawn_death_particles()
	on_player_died(player_node)


func on_boss_killed():
	bosses_killed += 1


func restart_game(start_wave: int = 1):
	starting_wave = start_wave
	get_tree().reload_current_scene()


func _add_key_action(action_name: String, keycode: int):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)


func _add_mouse_action(action_name: String, button: MouseButton):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)


func _get_color_index_for_peer(peer_id: int) -> int:
	# Host (1) = index 0, client 2 = index 1, client 3 = index 2, etc.
	if peer_id == 1:
		return 0
	return clampi(peer_id - 1, 1, PLAYER_COLORS.size() - 1)


func _spawn_remote_player(pid: int, color: Color):
	var player_scene = load("res://scenes/player.tscn")
	var remote = player_scene.instantiate()
	remote.name = "Player_%d" % pid
	remote.peer_id = pid
	remote.is_local = false
	remote.player_color = color
	# Distribute spawn positions in a circle
	var player_index = players.size()
	var total = maxi(players.size() + 1, 2)
	var angle = TAU * player_index / total
	remote.position = Vector3(cos(angle), 0, sin(angle)) * 60.0
	game_world_2d.add_child(remote)
	players[pid] = remote


@rpc("authority", "call_remote", "reliable")
func _rpc_start_game(wave: int, all_peers: Array = [], host_research: Dictionary = {}):
	# Client receives this from host to start the game
	# Apply host's tech tree for this session (host-authoritative)
	if host_research.size() > 0:
		_client_own_research = GameData.research.duplicate()
		for key in GameData.research:
			GameData.research[key] = host_research.get(key, 0)
	if is_instance_valid(hud_node):
		hud_node.start_mp_game()
	get_tree().paused = false
	await _on_game_started(wave)
	# Spawn other remote players that this client doesn't know about yet
	var my_id = multiplayer.get_unique_id()
	for info in all_peers:
		var pid: int = info[0]
		var color_idx: int = info[1]
		var pname: String = info[2] if info.size() > 2 else "Player"
		player_names[pid] = pname
		if pid != my_id and not players.has(pid):
			_spawn_remote_player(pid, PLAYER_COLORS[color_idx])
			players[pid].player_name = pname
	# Also set host name from peer info
	if player_names.has(1) and players.has(1) and is_instance_valid(players[1]):
		players[1].player_name = player_names[1]
	# Tell host we're done loading
	_rpc_client_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready():
	var sender = multiplayer.get_remote_sender_id()
	clients_ready[sender] = true
	# Check if all clients are ready
	for pid in clients_ready:
		if not clients_ready[pid]:
			return
	_waiting_for_clients = false
	if is_instance_valid(hud_node):
		hud_node.show_alert("All players loaded!")


func _broadcast_state():
	# Host sends full game state to client at 20Hz
	var player_states = []
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			# Encode mine target positions as flat array [x1,y1,x2,y2,...]
			var mt = []
			if "mine_targets" in p:
				for t in p.mine_targets:
					if is_instance_valid(t):
						mt.append(t.global_position.x)
						mt.append(t.global_position.z)
			player_states.append([pid, p.global_position.x, p.global_position.z, p.facing_angle, p.health, p.max_health, p.is_dead, respawn_timers.get(pid, 0.0), p.upgrades.get("orbital_lasers", 0), mt])

	# Clean dead aliens from tracking
	var dead_ids = []
	for nid in alien_net_ids:
		if not is_instance_valid(alien_net_ids[nid]):
			dead_ids.append(nid)
	for nid in dead_ids:
		alien_net_ids.erase(nid)

	# Enemy data: [net_id, type_id, pos_x, pos_y, hp, max_hp]
	var enemy_data = []
	for nid in alien_net_ids:
		var a = alien_net_ids[nid]
		var type_id = 0  # basic
		if a.is_in_group("bosses"):
			type_id = 3
		elif a.get_script() == load("res://scripts/ranged_alien.gd"):
			type_id = 2
		elif "alien_type" in a and a.alien_type == "fast":
			type_id = 1
		enemy_data.append([nid, type_id, a.global_position.x, a.global_position.z, a.hp, a.max_hp])

	var hq_hp = 0
	var hq_max_hp = 0
	if is_instance_valid(hq_node):
		hq_hp = hq_node.hp
		hq_max_hp = hq_node.max_hp

	# Resource data: [net_id, type_id, pos_x, pos_y, amount]
	var res_data = []
	# Clean dead resources
	var dead_res = []
	for nid in resource_net_ids:
		if not is_instance_valid(resource_net_ids[nid]):
			dead_res.append(nid)
	for nid in dead_res:
		resource_net_ids.erase(nid)
	for nid in resource_net_ids:
		var r = resource_net_ids[nid]
		res_data.append([nid, 0 if r.resource_type == "iron" else 1, r.global_position.x, r.global_position.z, r.amount])

	# Building data: [pos_x, pos_y, hp, max_hp]
	var building_data = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b): continue
		if b.is_in_group("hq"): continue
		building_data.append([b.global_position.x, b.global_position.z, b.hp if "hp" in b else 0, b.max_hp if "max_hp" in b else 0])

	_receive_state.rpc([
		player_states,
		player_node.iron, player_node.crystal,
		wave_number, wave_timer, wave_active,
		power_bank, max_power_bank, power_on,
		total_power_gen, total_power_consumption,
		bosses_killed,
		enemy_data,
		hq_hp, hq_max_hp,
		run_prestige,
		res_data,
		building_data
	])


@rpc("authority", "call_remote", "unreliable")
func _receive_state(state: Array):
	# Client receives state from host
	var player_states: Array = state[0]
	var shared_iron: int = state[1]
	var shared_crystal: int = state[2]
	wave_number = state[3]
	wave_timer = state[4]
	wave_active = state[5]
	power_bank = state[6]
	max_power_bank = state[7]
	power_on = state[8]
	total_power_gen = state[9]
	total_power_consumption = state[10]
	bosses_killed = state[11]
	var enemy_data: Array = state[12] if state.size() > 12 else []

	# Sync HQ health from host
	if state.size() > 14 and is_instance_valid(hq_node):
		hq_node.hp = state[13]
		hq_node.max_hp = state[14]
	if state.size() > 15:
		run_prestige = state[15]

	# Sync shared resources to local player
	if is_instance_valid(player_node):
		player_node.iron = shared_iron
		player_node.crystal = shared_crystal

	# Update player positions
	var my_id = multiplayer.get_unique_id()
	for ps in player_states:
		var pid: int = ps[0]
		if pid == my_id:
			# Own player: sync HP and death state from host, keep local position
			if is_instance_valid(player_node):
				player_node.health = ps[4]
				player_node.max_health = ps[5]
				if ps[6] and not player_node.is_dead:
					player_node.is_dead = true
					player_node._spawn_death_particles()
				elif not ps[6] and player_node.is_dead:
					player_node.is_dead = false
					player_node.health = player_node.max_health
					player_node.death_particles.clear()
					player_node.invuln_timer = 2.0
				# Store respawn countdown for HUD
				if ps.size() > 7 and is_instance_valid(hud_node):
					hud_node.respawn_countdown = ps[7]
		else:
			# Remote player: update position and state (interpolated)
			if players.has(pid) and is_instance_valid(players[pid]):
				var rp = players[pid]
				rp._remote_target_pos = Vector3(ps[1], 0, ps[2])
				rp.facing_angle = ps[3]
				rp.health = ps[4]
				rp.max_health = ps[5]
				rp.is_dead = ps[6]
				if ps.size() > 8:
					rp.upgrades["orbital_lasers"] = ps[8]
				if ps.size() > 9:
					rp.remote_mine_positions = ps[9]

	# Sync enemies
	_sync_enemies(enemy_data)

	# Sync resources (index 16)
	if state.size() > 16:
		_sync_resources(state[16])

	# Sync building HP (index 17)
	if state.size() > 17:
		_sync_building_hp(state[17])


func _sync_resources(res_data: Array):
	var live_ids = {}
	var resource_scene = load("res://scenes/resource_node.tscn")
	for rd in res_data:
		var nid: int = rd[0]
		var rtype: int = rd[1]
		var pos = Vector3(rd[2], 0, rd[3])
		var amt: int = rd[4]
		live_ids[nid] = true
		if resource_net_ids.has(nid) and is_instance_valid(resource_net_ids[nid]):
			var r = resource_net_ids[nid]
			r.global_position = pos
			r.amount = amt
		else:
			var r = resource_scene.instantiate()
			r.global_position = pos
			r.resource_type = "iron" if rtype == 0 else "crystal"
			r.amount = amt
			r.net_id = nid
			resources_node.add_child(r)
			resource_net_ids[nid] = r
	# Remove resources that no longer exist on host
	var to_remove = []
	for nid in resource_net_ids:
		if not live_ids.has(nid):
			var r = resource_net_ids[nid]
			if is_instance_valid(r):
				r.queue_free()
			to_remove.append(nid)
	for nid in to_remove:
		resource_net_ids.erase(nid)


func _sync_building_hp(building_data: Array):
	for bd in building_data:
		var pos = Vector3(bd[0], 0, bd[1])
		var bhp: int = bd[2]
		var bmax: int = bd[3]
		var b = _find_building_at(pos)
		if b:
			if "hp" in b:
				b.hp = bhp
			if "max_hp" in b:
				b.max_hp = bmax


func _send_client_state():
	# Client sends their position/angle to host
	if is_instance_valid(player_node):
		_receive_client_state.rpc_id(1,
			player_node.global_position.x,
			player_node.global_position.z,
			player_node.facing_angle)


@rpc("any_peer", "call_remote", "unreliable")
func _receive_client_state(pos_x: float, pos_y: float, angle: float):
	# Host receives client position
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id) and is_instance_valid(players[sender_id]):
		players[sender_id]._remote_target_pos = Vector3(pos_x, 0, pos_y)
		players[sender_id].facing_angle = angle


@rpc("authority", "call_remote", "reliable")
func _rpc_game_over(wave: int, bosses: int, prestige_share: int = 0):
	# Client receives game over from host
	game_over = true
	# Restore client's own research before saving
	if _client_own_research.size() > 0:
		GameData.research = _client_own_research
		_client_own_research = {}
	GameData.add_prestige(prestige_share)
	GameData.record_run(wave, bosses)
	if is_instance_valid(hud_node):
		hud_node.show_death_screen(wave, bosses, prestige_share, GameData.prestige_points)


@rpc("authority", "call_remote", "reliable")
func _rpc_hq_destroyed():
	# Client: destroy local HQ and kill local player
	if is_instance_valid(hq_node):
		hq_node.queue_free()
	_on_hq_destroyed()


# --- Name sync ---

func send_player_name(pname: String):
	var my_id = multiplayer.get_unique_id()
	player_names[my_id] = pname
	if NetworkManager.is_host():
		_broadcast_names()
	else:
		_rpc_send_name.rpc_id(1, pname)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_send_name(pname: String):
	var sender_id = multiplayer.get_remote_sender_id()
	player_names[sender_id] = pname
	if players.has(sender_id) and is_instance_valid(players[sender_id]):
		players[sender_id].player_name = pname
	_broadcast_names()


func _broadcast_names():
	var names_array: Array = []
	for pid in player_names:
		names_array.append([pid, player_names[pid]])
	_rpc_receive_names.rpc(names_array)
	# Also update local HUD
	if is_instance_valid(hud_node):
		hud_node.update_lobby_player_list(player_names)


@rpc("authority", "call_remote", "reliable")
func _rpc_receive_names(names_array: Array):
	for entry in names_array:
		var pid: int = entry[0]
		var pname: String = entry[1]
		player_names[pid] = pname
		if players.has(pid) and is_instance_valid(players[pid]):
			players[pid].player_name = pname
	if is_instance_valid(hud_node):
		hud_node.update_lobby_player_list(player_names)


# --- Upgrade voting (multiplayer) ---

func _start_vote_round():
	# Host picks 3 random upgrades and broadcasts
	var available: Array = []
	for key in hud_node.UPGRADE_DATA:
		if player_node.upgrades.get(key, 0) < hud_node.UPGRADE_DATA[key]["max"]:
			available.append(key)
	if available.size() == 0:
		pending_upgrades -= 1
		return
	available.shuffle()
	vote_upgrade_keys = available.slice(0, mini(3, available.size()))

	vote_choices.clear()
	for pid in players:
		vote_choices[pid] = ""
	vote_round += 1
	vote_active = true

	# Pause game during voting
	get_tree().paused = true

	# Show locally on host
	hud_node.show_vote_selection(vote_upgrade_keys, player_node.upgrades, vote_choices, players, player_names)
	# Send to all clients
	_rpc_start_vote.rpc(vote_upgrade_keys, vote_round)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_vote(keys: Array, round_num: int):
	vote_upgrade_keys = keys
	vote_round = round_num
	vote_active = true
	vote_choices.clear()
	for pid in players:
		vote_choices[pid] = ""
	get_tree().paused = true
	if is_instance_valid(hud_node):
		hud_node.show_vote_selection(keys, player_node.upgrades if is_instance_valid(player_node) else {}, vote_choices, players, player_names)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_vote(key: String, round_num: int):
	if round_num != vote_round:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_receive_vote(sender_id, key)


func _receive_vote(pid: int, key: String):
	if not vote_active:
		return
	vote_choices[pid] = key

	# Broadcast updated vote state to all
	_rpc_vote_state.rpc(vote_choices, vote_round)
	# Also update locally on host
	if is_instance_valid(hud_node):
		hud_node.update_vote_display(vote_choices, players, player_names)

	# Check if all players have voted
	var all_voted = true
	for vpid in vote_choices:
		if vote_choices[vpid] == "":
			all_voted = false
			break

	if all_voted:
		_evaluate_votes()


func _evaluate_votes():
	var chosen_key = ""
	var unanimous = true
	for pid in vote_choices:
		var v = vote_choices[pid]
		if chosen_key == "":
			chosen_key = v
		elif v != chosen_key:
			unanimous = false
			break

	if unanimous and chosen_key != "":
		# Apply upgrade for all players
		vote_active = false
		get_tree().paused = false
		for pid in players:
			if is_instance_valid(players[pid]):
				players[pid].apply_upgrade(chosen_key)
		pending_upgrades -= 1
		upgrade_cooldown = 0.4
		_rpc_vote_resolved.rpc(chosen_key)
		if is_instance_valid(hud_node):
			hud_node.hide_vote_panel(chosen_key)
	# If not unanimous, do nothing — players can change their votes until they agree


@rpc("authority", "call_remote", "reliable")
func _rpc_vote_state(votes: Dictionary, round_num: int):
	if round_num != vote_round:
		return
	vote_choices = votes
	if is_instance_valid(hud_node):
		hud_node.update_vote_display(vote_choices, players, player_names)


@rpc("authority", "call_remote", "reliable")
func _rpc_vote_resolved(key: String):
	vote_active = false
	get_tree().paused = false
	if is_instance_valid(player_node):
		player_node.apply_upgrade(key)
	if is_instance_valid(hud_node):
		hud_node.hide_vote_panel(key)


func _respawn_player(pid: int):
	respawn_timers.erase(pid)
	if not players.has(pid) or not is_instance_valid(players[pid]):
		return
	var p = players[pid]
	p.is_dead = false
	p.health = p.max_health
	p.death_particles.clear()
	p.invuln_timer = 2.0
	# Respawn near HQ or center
	if is_instance_valid(hq_node):
		p.global_position = hq_node.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	else:
		p.global_position = Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	if NetworkManager.is_multiplayer_active():
		_rpc_player_respawned.rpc(pid)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_respawned(pid: int):
	if players.has(pid) and is_instance_valid(players[pid]):
		var p = players[pid]
		p.is_dead = false
		p.health = p.max_health
		p.death_particles.clear()
		p.invuln_timer = 2.0


func _on_game_peer_disconnected(pid: int):
	# If the host disconnected and we're a client, end the game
	if pid == 1 and NetworkManager.is_multiplayer_active() and not NetworkManager.is_host():
		game_over = true
		if is_instance_valid(hud_node):
			hud_node.show_disconnect_panel()
		return
	respawn_timers.erase(pid)
	# Remove from loading wait list if applicable
	if clients_ready.has(pid):
		clients_ready.erase(pid)
		if _waiting_for_clients:
			var all_ready = true
			for cpid in clients_ready:
				if not clients_ready[cpid]:
					all_ready = false
					break
			if all_ready:
				_waiting_for_clients = false
	# Remove disconnected player from vote if active
	if vote_active and vote_choices.has(pid):
		vote_choices.erase(pid)
		# Broadcast updated state
		_rpc_vote_state.rpc(vote_choices, vote_round)
		if is_instance_valid(hud_node):
			hud_node.update_vote_display(vote_choices, players, player_names)
		# Check if remaining players are now unanimous
		var all_voted = true
		for vpid in vote_choices:
			if vote_choices[vpid] == "":
				all_voted = false
				break
		if all_voted and vote_choices.size() > 0:
			_evaluate_votes()
	# Clean up player entry
	if players.has(pid):
		if is_instance_valid(players[pid]):
			players[pid].queue_free()
		players.erase(pid)
	player_names.erase(pid)


# --- Building recycling ---

const BUILDING_NAME_TO_TYPE = {
	"Turret": "turret",
	"Factory": "factory",
	"Wall": "wall",
	"Lightning Tower": "lightning",
	"Slow Tower": "slow",
	"Pylon": "pylon",
	"Power Plant": "power_plant",
	"Battery": "battery",
	"Flame Turret": "flame_turret",
	"Acid Turret": "acid_turret",
	"Repair Drone": "repair_drone",
	"Poison Turret": "poison_turret",
}


func recycle_building(building: Node3D):
	if not is_instance_valid(building):
		return
	if not building.has_method("get_building_name"):
		return
	if building.get_building_name() == "HQ":
		return
	# MP client: request recycle from host
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_host():
		_request_recycle.rpc_id(1, building.global_position.x, building.global_position.z)
		return
	# Host / single-player: perform recycle
	_do_recycle(building)


func _do_recycle(building: Node3D):
	var bname = building.get_building_name()
	var btype = BUILDING_NAME_TO_TYPE.get(bname, "")
	if btype == "":
		return
	var base = CFG.get_base_cost(btype)
	var hp_ratio = 1.0
	if "hp" in building and "max_hp" in building and building.max_hp > 0:
		hp_ratio = float(building.hp) / float(building.max_hp)
	var refund_iron = int(base["iron"] * hp_ratio)
	var refund_crystal = int(base["crystal"] * hp_ratio)
	if is_instance_valid(player_node):
		player_node.iron += refund_iron
		player_node.crystal += refund_crystal
	var pos = building.global_position
	building.queue_free()
	# Sync to clients
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
		_sync_building_recycled.rpc(pos.x, pos.z)


@rpc("any_peer", "call_remote", "reliable")
func _request_recycle(pos_x: float, pos_y: float):
	var building = _find_building_at(Vector3(pos_x, 0, pos_y))
	if building and building.get_building_name() != "HQ":
		_do_recycle(building)


@rpc("authority", "call_remote", "reliable")
func _sync_building_recycled(pos_x: float, pos_y: float):
	var building = _find_building_at(Vector3(pos_x, 0, pos_y))
	if building:
		building.queue_free()


func _find_building_at(pos: Vector3) -> Node3D:
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.global_position.distance_to(pos) < 5.0:
			return b
	return null


# --- Building power toggle ---

func sync_building_toggle(building: Node3D):
	if not is_instance_valid(building) or "manually_disabled" not in building:
		return
	var pos = building.global_position
	var disabled = building.manually_disabled
	if not NetworkManager.is_multiplayer_active():
		return
	if NetworkManager.is_host():
		_rpc_building_toggled.rpc(pos.x, pos.z, disabled)
	else:
		_request_building_toggle.rpc_id(1, pos.x, pos.z, disabled)


@rpc("any_peer", "call_remote", "reliable")
func _request_building_toggle(pos_x: float, pos_y: float, disabled: bool):
	var b = _find_building_at(Vector3(pos_x, 0, pos_y))
	if b and "manually_disabled" in b:
		b.manually_disabled = disabled
		_rpc_building_toggled.rpc(pos_x, pos_y, disabled)


@rpc("authority", "call_remote", "reliable")
func _rpc_building_toggled(pos_x: float, pos_y: float, disabled: bool):
	var b = _find_building_at(Vector3(pos_x, 0, pos_y))
	if b and "manually_disabled" in b:
		b.manually_disabled = disabled


# --- Drop sync RPCs ---

func spawn_synced_prestige_orb(pos: Vector3):
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
		_rpc_spawn_prestige_orb.rpc(pos.x, pos.z)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_prestige_orb(px: float, py: float):
	var orb = load("res://scenes/prestige_orb.tscn").instantiate()
	orb.global_position = Vector3(px, 0, py)
	game_world_2d.add_child(orb)


func spawn_synced_powerup(pos: Vector3, type: String):
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_host():
		_rpc_spawn_powerup.rpc(pos.x, pos.z, type)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_powerup(px: float, py: float, type: String):
	var powerup = load("res://scenes/powerup.tscn").instantiate()
	powerup.global_position = Vector3(px, 0, py)
	powerup.powerup_type = type
	powerups_node.add_child(powerup)


@rpc("any_peer", "call_remote", "reliable")
func _request_build(type: String, pos_x: float, pos_y: float):
	# Host handles client build request
	var sender_id = multiplayer.get_remote_sender_id()
	if not players.has(sender_id) or not is_instance_valid(players[sender_id]):
		return
	var requester = players[sender_id]
	var bp = Vector3(pos_x, 0, pos_y)
	# Range check from requester's position
	if requester.global_position.distance_to(bp) > CFG.build_range:
		return
	# Use host's shared resources to place building
	if is_instance_valid(player_node) and player_node._try_build_at(type, bp):
		pass  # _try_build_at already broadcasts via _sync_building_placed


@rpc("authority", "call_remote", "reliable")
func _sync_building_placed(type: String, pos_x: float, pos_y: float):
	# Client creates building locally (no cost deduction)
	var bp = Vector3(pos_x, 0, pos_y)
	var building: Node3D
	match type:
		"turret": building = load("res://scenes/turret.tscn").instantiate()
		"factory": building = load("res://scenes/factory.tscn").instantiate()
		"wall": building = load("res://scenes/wall.tscn").instantiate()
		"lightning": building = load("res://scenes/lightning_tower.tscn").instantiate()
		"slow": building = load("res://scenes/slow_tower.tscn").instantiate()
		"pylon": building = load("res://scenes/pylon.tscn").instantiate()
		"power_plant": building = load("res://scenes/power_plant.tscn").instantiate()
		"battery": building = load("res://scenes/battery.tscn").instantiate()
		"flame_turret": building = load("res://scenes/flame_turret.tscn").instantiate()
		"acid_turret": building = load("res://scenes/acid_turret.tscn").instantiate()
		"repair_drone": building = load("res://scenes/repair_drone.tscn").instantiate()
		"poison_turret": building = load("res://scenes/poison_turret.tscn").instantiate()
	if building:
		building.global_position = bp
		buildings_node.add_child(building)
		var health_bonus = GameData.get_research_bonus("building_health")
		if health_bonus > 0 and "hp" in building and "max_hp" in building:
			var bonus_hp = int(building.max_hp * health_bonus)
			building.hp += bonus_hp
			building.max_hp += bonus_hp


func _sync_enemies(enemy_data: Array):
	# Client-side: sync puppet enemies from host broadcast
	var live_ids = {}
	for ed in enemy_data:
		var nid: int = ed[0]
		var type_id: int = ed[1]
		var pos = Vector3(ed[2], 0, ed[3])
		var enemy_hp: int = ed[4]
		var enemy_max_hp: int = ed[5]
		live_ids[nid] = true

		if alien_net_ids.has(nid) and is_instance_valid(alien_net_ids[nid]):
			# Update existing puppet
			var a = alien_net_ids[nid]
			a.target_pos = pos
			a.hp = enemy_hp
			a.max_hp = enemy_max_hp
		else:
			# Spawn new puppet
			var alien: Node3D
			match type_id:
				2:
					alien = load("res://scenes/ranged_alien.tscn").instantiate()
				3:
					alien = load("res://scenes/boss_alien.tscn").instantiate()
				_:
					alien = load("res://scenes/alien.tscn").instantiate()
					if type_id == 1:
						alien.alien_type = "fast"
			alien.net_id = nid
			alien.is_puppet = true
			alien.hp = enemy_hp
			alien.max_hp = enemy_max_hp
			alien.global_position = pos
			alien.target_pos = pos
			alien.process_mode = Node.PROCESS_MODE_ALWAYS  # Keep interpolating during pause
			aliens_node.add_child(alien)
			alien_net_ids[nid] = alien

	# Remove puppets that no longer exist on host
	var to_remove = []
	for nid in alien_net_ids:
		if not live_ids.has(nid):
			var a = alien_net_ids[nid]
			if is_instance_valid(a):
				# Spawn XP gem visual on death
				var gem = load("res://scenes/xp_gem.tscn").instantiate()
				gem.global_position = a.global_position
				gem.xp_value = a.xp_value
				game_world_2d.add_child(gem)
				# Clean up 3D mesh and light before freeing
				if alien_meshes.has(a):
					alien_meshes[a].queue_free()
					alien_meshes.erase(a)
				if alien_lights.has(a):
					alien_lights[a].queue_free()
					alien_lights.erase(a)
				a.queue_free()
			to_remove.append(nid)
	for nid in to_remove:
		alien_net_ids.erase(nid)


# --- Bullet sync RPCs ---

func spawn_synced_bullet(pos: Vector3, dir: Vector3, from_turret: bool, burn_dps: float, slow_amount: float):
	if NetworkManager.is_multiplayer_active():
		_rpc_spawn_bullet.rpc(pos.x, pos.z, dir.x, dir.z, from_turret, burn_dps, slow_amount)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_bullet(px: float, py: float, dx: float, dy: float, from_turret: bool, burn: float, slow: float):
	var b = load("res://scenes/bullet.tscn").instantiate()
	b.global_position = Vector3(px, 0, py)
	b.direction = Vector3(dx, 0, dy)
	b.from_turret = from_turret
	b.burn_dps = burn
	b.slow_amount = slow
	b.visual_only = true
	game_world_2d.add_child(b)


func spawn_synced_enemy_bullet(pos: Vector3, dir: Vector3):
	if NetworkManager.is_multiplayer_active():
		_rpc_spawn_enemy_bullet.rpc(pos.x, pos.z, dir.x, dir.z)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_enemy_bullet(px: float, py: float, dx: float, dy: float):
	var b = load("res://scenes/enemy_bullet.tscn").instantiate()
	b.global_position = Vector3(px, 0, py)
	b.direction = Vector3(dx, 0, dy)
	b.visual_only = true
	game_world_2d.add_child(b)


# --- Prestige sync ---

func add_run_prestige(amount: int):
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_host():
		_rpc_add_prestige.rpc_id(1, amount)
		return
	run_prestige += amount


@rpc("any_peer", "call_remote", "reliable")
func _rpc_add_prestige(amount: int):
	run_prestige += amount
