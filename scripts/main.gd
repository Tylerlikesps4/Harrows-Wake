extends Node3D
## Harrow's Wake - free demo.
## Builds both maps (Police Station for Dana, Orphanage for Jenny) in code from
## CC0 textures and props, runs fixed cameras, interactions, menus, the tube
## network, panic, scripted scares, the title screen, pause menu and saves.

const CELL := 8.0
const WALL_H := 3.0
const DOOR_W := 1.8
const DOOR_H := 2.2
const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const PlayerScript := preload("res://scripts/player.gd")
const ZombieScript := preload("res://scripts/zombie.gd")
const BellmanScript := preload("res://csharp/Bellman.cs")
const GraphScript := preload("res://csharp/WaypointGraph.cs")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch.gd")
const ActorScript := preload("res://scripts/actor_model.gd")

const CORNERS := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
const NAMES := {"dana": "Dana Reyes", "jenny": "Jenny Hale"}
const PLACES := {"dana": "Harrow's Wake Police Station", "jenny": "St. Agnes Orphanage, Hill Road"}
const MAX_HP := {"dana": 5, "jenny": 3}

# floor/wall = texture names in assets/tex. step = footstep surface.
var MAPS := {
	"dana": {
		"origin": Vector3(0, 0, 0),
		"amb": "amb_station",
		"rooms": {
			Vector2i(0, 0): {"name": "Lobby", "floor": "checkered_pavement_tiles", "fcol": Color(0.8, 0.78, 0.7), "wall": "plastered_wall_02", "wcol": Color(0.62, 0.66, 0.56), "step": "concrete", "light": Color(1.0, 0.8, 0.55), "fog": Color(0.05, 0.06, 0.05), "cam": 2},
			Vector2i(1, 0): {"name": "West Hall", "floor": "floor_tiles_06", "fcol": Color(0.75, 0.75, 0.7), "wall": "blue_plaster_weathered", "wcol": Color(0.55, 0.62, 0.55), "step": "concrete", "light": Color(0.8, 0.95, 0.75), "fog": Color(0.04, 0.07, 0.05), "cam": 0, "flicker": true},
			Vector2i(2, 0): {"name": "Evidence Room", "floor": "concrete_floor_worn_001", "fcol": Color(0.7, 0.72, 0.75), "wall": "painted_metal_shutter", "wcol": Color(0.5, 0.55, 0.62), "step": "concrete", "light": Color(0.65, 0.78, 1.0), "fog": Color(0.03, 0.045, 0.07), "cam": 3, "needs_power": true},
			Vector2i(1, 1): {"name": "Records Room", "floor": "old_wood_floor", "fcol": Color(0.8, 0.65, 0.5), "wall": "decrepit_wallpaper", "wcol": Color(0.75, 0.68, 0.55), "step": "wood", "light": Color(1.0, 0.85, 0.6), "fog": Color(0.07, 0.05, 0.03), "cam": 1, "safe": true},
			Vector2i(1, -1): {"name": "Chief's Office", "floor": "dirty_carpet", "fcol": Color(0.85, 0.55, 0.42), "wall": "decrepit_wallpaper", "wcol": Color(0.6, 0.5, 0.42), "step": "carpet", "light": Color(1.0, 0.72, 0.45), "fog": Color(0.12, 0.08, 0.055), "cam": 2, "energy": 3.6, "fog_d": 0.05, "ambient": 1.5},
		},
		"links": [[Vector2i(0, 0), Vector2i(1, 0), ""], [Vector2i(1, 0), Vector2i(2, 0), "evidence"], [Vector2i(1, 0), Vector2i(1, 1), ""], [Vector2i(1, 0), Vector2i(1, -1), ""]],
	},
	"jenny": {
		"origin": Vector3(100, 0, 0),
		"amb": "amb_orphanage",
		"rooms": {
			Vector2i(0, 0): {"name": "Dormitory", "floor": "old_wood_floor", "fcol": Color(0.7, 0.6, 0.5), "wall": "decrepit_wallpaper", "wcol": Color(0.55, 0.6, 0.62), "step": "wood", "light": Color(0.6, 0.72, 0.95), "fog": Color(0.03, 0.04, 0.07), "cam": 1},
			Vector2i(1, 0): {"name": "Corridor", "floor": "dark_wooden_planks", "fcol": Color(0.75, 0.6, 0.5), "wall": "damaged_plaster", "wcol": Color(0.6, 0.6, 0.55), "step": "wood", "light": Color(0.75, 0.82, 0.65), "fog": Color(0.04, 0.05, 0.04), "cam": 3, "flicker": true},
			Vector2i(2, 0): {"name": "Chapel", "floor": "floor_tiles_06", "fcol": Color(0.65, 0.55, 0.52), "wall": "damaged_plaster", "wcol": Color(0.55, 0.42, 0.42), "step": "concrete", "light": Color(1.0, 0.45, 0.3), "fog": Color(0.08, 0.025, 0.02), "cam": 0, "amb": "amb_chapel"},
			Vector2i(1, 1): {"name": "Mail Room", "floor": "old_wood_floor", "fcol": Color(0.8, 0.65, 0.5), "wall": "plastered_wall_02", "wcol": Color(0.7, 0.65, 0.52), "step": "wood", "light": Color(1.0, 0.86, 0.6), "fog": Color(0.07, 0.05, 0.03), "cam": 2, "safe": true},
			Vector2i(1, -1): {"name": "Playroom", "floor": "dirty_carpet", "fcol": Color(0.85, 0.62, 0.78), "wall": "decrepit_wallpaper", "wcol": Color(0.65, 0.5, 0.6), "step": "carpet", "light": Color(0.85, 0.68, 0.95), "fog": Color(0.1, 0.065, 0.12), "cam": 1, "energy": 3.4, "fog_d": 0.05, "ambient": 1.7},
		},
		"links": [[Vector2i(0, 0), Vector2i(1, 0), ""], [Vector2i(1, 0), Vector2i(2, 0), ""], [Vector2i(1, 0), Vector2i(1, 1), ""], [Vector2i(1, 0), Vector2i(1, -1), ""]],
	},
}

var NOTES := {
	"intro": ["October 31, 1998", "Harrow's Wake, Maine.\n\nAt 11:52 PM the bell above the Meridian Biotech site rang by itself. Everyone who heard it changed. The fog came down and never lifted.\n\nTwo survivors are still breathing on opposite ends of town. If they ever meet, the Choir Stone's resonance kills them both.\n\nThe town's old pneumatic mail tubes still work."],
	"note_toll": ["Dispatch Memo", "Oct 31, 11:52 PM.\nMultiple calls: the Meridian bell is ringing on its own. Callers report 'singing' coming up through the storm drains. Two callers say their husbands 'went soft, like candle wax.'\nAll units to Bell Street.\n- Dispatch"],
	"note_chief": ["Chief's Log", "Meridian's people sealed the lab and left us the town.\n\nThe old mail tubes still run from our Records Room to St. Agnes Orphanage on Hill Road. If anyone's alive up there, that's how we reach them.\n\nThe evidence room's mag-lock blew its fuse. Spares went up to the orphanage with the Christmas lights last year. Of course they did.\n- Chief Harlan"],
	"note_jenny": ["Torn Diary Page", "If you find this, I'm hiding.\n\nThe tall man with the bell walks the halls. Don't run near him. He HEARS you. Don't shine a light at him either.\n\nThe wardrobes are safe if he didn't see you get in. Hold your breath in there, but not too long.\n\nHe never comes into the Mail Room. The tube there goes all the way to the police station.\n- J."],
	"file_meridian": ["Meridian Biotech - Internal", "MERIDIAN BIOTECHNOLOGY - HARROW'S WAKE SITE\nPROJECT CHOIR / Phase III summary (partial)\n\nThe specimen recovered from the quarry (\"the Choir Stone\") emits a standing tone below human hearing. Subjects exposed for 40+ hours report hearing singing. Tissue samples show softening of fat and muscle, \"a tallow-like state\".\n\nThe tone can be carried and focused by bronze. Requisition approved: one hand bell, cast on site.\n\nDo NOT allow paired subjects within 30 m of each other while exposed. See incident 7 (both deceased).\n- Dr. E. Voss"],
	"file_choir": ["Field Report: The Stone", "Records copy. Harrow's Wake PD, 1974.\n\nQuarry workers dug up a dark stone \"the size of a church door\" that rang when struck - and kept ringing after. Three men walked into the flooded pit that night, humming.\n\nThe county sold the site to a company called Meridian. Case closed by order of the mayor.\n\nHandwritten in the margin, newer ink: IT ISN'T RINGING. IT'S ANSWERING."],
	"file_bellman": ["St. Agnes Ledger", "ST. AGNES ORPHANAGE - STAFF LEDGER\n\nMr. Abel Crane, bell-ringer and caretaker. Rings the hand bell for meals, prayers and lights-out. The children say he never sleeps.\n\n(added later, a different hand)\nThe men from Meridian took Mr. Crane to the hill for \"tests\" and gave him a new bell. He came back wearing a white face. He doesn't ring for meals anymore. He rings when one of us is out of bed.\n\nWhen the bell stops, he is close."],
	"page_typed": ["The Typewriter", "The paper in the roller is still warm. One line, typed over and over until the ribbon tore:\n\nHE HEARS THE TUBES  HE HEARS THE TUBES  HE HEARS THE TUBES  HE HEARS THE TUBES  HE HEARS THE\n\nThe keys are still moving."],
}

var players: Dictionary = {}
var cameras: Dictionary = {"dana": {}, "jenny": {}}
var room_lights: Dictionary = {}
var light_base: Dictionary = {}   # light -> base energy
var flicker_lights: Array = []
var candle_lights: Array = []
var interactables: Array = []
var doors: Dictionary = {}
var zombies: Array = []
var bellman = null
var hud: CanvasLayer = null
var touch: CanvasLayer = null
var post_mat: ShaderMaterial = null
var post_rect: ColorRect = null
var env: Environment = null
var panic: float = 0.0
var sfx: Dictionary = {}
var static_player: AudioStreamPlayer = null
var amb_player: AudioStreamPlayer = null
var amb2_player: AudioStreamPlayer = null
var title_music: AudioStreamPlayer = null
var credits_music: AudioStreamPlayer = null
var heart_t: float = 0.0
var cur_cam_key: String = ""
var cur_room_name: String = ""
var cur_amb: String = ""
var menu_options: Array = []
var menu_index: int = 0
var menu_title: String = ""
var menu_header: String = ""
var menu_cb: Callable
var struggle_need: int = 0
var struggle_count: int = 0
var struggle_t: float = 0.0
var fire_cd: float = 0.0
var flick_t: float = 0.0
var near: Dictionary = {}
var spin_nodes: Array = []
var shake: float = 0.0
var distort: float = 0.0
var title_index: int = 0
var title_cam: Camera3D = null
var title_bell_t: float = 3.0
var scare_nodes: Dictionary = {}
var phone_player: AudioStreamPlayer3D = null
var musicbox_player: AudioStreamPlayer3D = null
var typer_t: float = 0.0
var props: Dictionary = {}
var hide_noise_t: float = 0.0
var intro_t: float = -1.0
var phantom: Node3D = null
var menu_desc: Callable          # optional: description text for the highlighted option
var menu_adjust: Callable        # optional: left/right adjusts the highlighted option
var menu_back: Callable          # optional: what BACK does (default: close)
var settings_from_title: bool = false
var dead_index: int = 0
var end_t: float = -1.0
var credits_lbl: Label = null
var map_roots: Dictionary = {}
var muzzle_tex: ImageTexture = null
var door_t: float = 0.0
const ITEM_INFO := {
	"Handgun": "Dana's 9mm service pistol. Hold AIM to lock on, FIRE to shoot. Three rounds drop a Tallow-folk.",
	"Green Herb": "A bitter local herb. Restores 2 health. Select it here to use it.",
	"Fuse": "A 30-amp cartridge fuse wrapped in Christmas tinsel. The station's evidence mag-lock needs one.",
	"Tower Key": "A heavy iron key on a tag: BELL TOWER - ST. AGNES. It opens the chapel padlock.",
}


var graph: RefCounted = null  # C# WaypointGraph


func _ready() -> void:
	randomize()
	graph = GraphScript.new()
	graph.setup(MAPS, CELL)
	_build_sfx()
	_build_environment()
	for m in MAPS.keys():
		_build_map(m)
	_build_interactables()
	_build_players()
	_build_enemies()
	_build_scares()
	_build_ui()
	_build_door_stage()
	_apply_state()
	Game.settings_changed.connect(_apply_settings)
	_apply_settings()
	if "--smoke" in OS.get_cmdline_user_args():
		add_child(load("res://tests/smoke.gd").new())
	if "--flow" in OS.get_cmdline_user_args():
		add_child(load("res://tests/flow.gd").new())
	if "--shots" in OS.get_cmdline_user_args():
		add_child(load("res://tests/shots.gd").new())
	if "--regress" in OS.get_cmdline_user_args():
		add_child(load("res://tests/regress.gd").new())
	if "--perf" in OS.get_cmdline_user_args():
		add_child(load("res://tests/perf.gd").new())
	if Game.skip_title:
		Game.skip_title = false
		Game.mode = "play"
		_fade_in(1.2)
		_announce()
	else:
		Game.mode = "title"
		_show_title()


## Phones: backgrounding the app pauses and lets go of the touch stick,
## so you don't come back to find you walked into the Bellman.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if touch != null:
			touch.release_all()
		if is_node_ready() and Game.mode == "door":
			_door_finish()
		if is_node_ready() and Game.mode == "play" and intro_t < 0.0:
			_open_pause()


# ---------------------------------------------------------------- building

func box(parent: Node3D, size: Vector3, pos: Vector3, texname: String, col: Color, layer: int = 1, collide: bool = true, emission: float = 0.0, wscale: float = 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	# subdivide big faces (~1 m) so affine warping wobbles instead of tearing
	bm.subdivide_width = clampi(int(size.x / 1.0), 0, 10)
	bm.subdivide_height = clampi(int(size.y / 1.0), 0, 10)
	bm.subdivide_depth = clampi(int(size.z / 1.0), 0, 10)
	mi.mesh = bm
	mi.material_override = Lib.mat(texname, col, true, wscale, emission)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = layer
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func part(parent: Node3D, mesh: Mesh, pos: Vector3, texname: String, col: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Lib.mat(texname, col, false, 1.0, emission, 0.6)
	mi.position = pos
	parent.add_child(mi)
	return mi


func cyl(top: float, bottom: float, h: float, segs: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 0
	return c


func bmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _glow_quad(parent: Node3D, size: Vector2, pos: Vector3, rot: Vector3, col: Color, additive: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.16, 0.2)
	env.ambient_light_energy = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.04, 0.05)
	env.fog_density = 0.075
	we.environment = env
	add_child(we)


func cell_center(map: String, c: Vector2i) -> Vector3:
	var o: Vector3 = MAPS[map]["origin"]
	return o + Vector3(c.x * CELL, 0, c.y * CELL)


func cell_of(map: String, pos: Vector3) -> Vector2i:
	var o: Vector3 = MAPS[map]["origin"]
	return Vector2i(roundi((pos.x - o.x) / CELL), roundi((pos.z - o.z) / CELL))


func room_at(map: String, pos: Vector3) -> Dictionary:
	return MAPS[map]["rooms"].get(cell_of(map, pos), {})


func floor_at(map: String, pos: Vector3) -> String:
	return room_at(map, pos).get("step", "wood")


func _link_between(map: String, a: Vector2i, b: Vector2i) -> Array:
	for l in MAPS[map]["links"]:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return l
	return []


## GL Compatibility redraws each object once per light touching it, so lights
## are culled per room: its own lights plus the ceiling bulbs of rooms its
## doorways open onto (see _update_lights).
var light_cell: Dictionary = {}   # light -> [map, cell, is_ceiling]


func _register_light(lt: Light3D, map: String, ceiling: bool) -> void:
	light_cell[lt] = [map, cell_of(map, lt.global_position), ceiling]


func _update_lights(who: String, c: Vector2i) -> void:
	for lt in light_cell.keys():
		if not is_instance_valid(lt):
			continue
		var info: Array = light_cell[lt]
		if info[0] != who:
			continue
		lt.visible = info[1] == c or (info[2] and not _link_between(who, info[1], c).is_empty())


func _add_light(root: Node3D, key: String, pos: Vector3, col: Color, energy: float, rng: float, flicker: bool = false) -> OmniLight3D:
	var lt := OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = energy
	lt.omni_range = rng
	lt.omni_attenuation = 1.4
	lt.position = pos
	root.add_child(lt)
	if MAPS.has(str(root.name)):
		_register_light(lt, str(root.name), key != "")
	light_base[lt] = energy
	if flicker:
		flicker_lights.append(lt)
	if key != "":
		room_lights[key] = lt
	return lt


func _build_map(map: String) -> void:
	var root := Node3D.new()
	root.name = map
	add_child(root)
	map_roots[map] = root
	var rooms: Dictionary = MAPS[map]["rooms"]
	for c in rooms.keys():
		var r: Dictionary = rooms[c]
		var ctr := cell_center(map, c)
		box(root, Vector3(CELL, 0.2, CELL), ctr + Vector3(0, -0.1, 0), r["floor"], r["fcol"], 1, true, 0.0, 0.45)
		box(root, Vector3(CELL, 0.2, CELL), ctr + Vector3(0, WALL_H + 0.1, 0), "damaged_plaster", Color(0.3, 0.29, 0.27), 1, false, 0.0, 0.35)
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if rooms.has(n):
				if d.x > 0 or d.y > 0:
					var l := _link_between(map, c, n)
					_build_wall(root, map, ctr, d, not l.is_empty(), r, (l[2] if not l.is_empty() else ""))
			else:
				_build_wall(root, map, ctr, d, false, r, "")
		# Ceiling bulb: a lamp shade, an emissive bulb and a dim light.
		Lib.prop(root, "lampSquareCeiling", ctr + Vector3(0, WALL_H - 0.45, 0), 0.0, 0.5, 0)
		var energy: float = r.get("energy", 1.7)
		var lt := _add_light(root, "%s_%s" % [map, c], ctr + Vector3(0, 2.45, 0), r["light"], energy, 10.5, r.get("flicker", false))
		if r.get("needs_power", false) and not Game.flag("power"):
			lt.light_energy = 0.08
		var cam := Camera3D.new()
		cam.fov = 64.0
		cam.near = 0.05
		cam.far = 40.0
		root.add_child(cam)
		var corner: Vector2 = CORNERS[r["cam"]]
		var cpos := ctr + Vector3(corner.x * CELL * 0.44, 2.7, corner.y * CELL * 0.44)
		cam.look_at_from_position(cpos, ctr + Vector3(-corner.x * 0.6, 0.5, -corner.y * 0.6), Vector3.UP)
		cam.set_meta("base", cam.transform)
		cameras[map][c] = cam
	_build_props(map, root)


## Moonlit window on an outer wall: glowing pane, bars, and a cool spot
## light on the floor so dark rooms have a light source.
func _moon_window(root: Node3D, map: String, c: Vector2i, o: Vector3, rot_y: float, target: Vector3) -> void:
	var pos := _off(map, c, o)
	var q := _glow_quad(root, Vector2(1.3, 1.5), pos, Vector3(0, rot_y, 0), Color(0.32, 0.42, 0.62), false)
	q.name = "moon_window"
	var bar := Vector3(0.06, 1.45, 0.08) if absf(sin(rot_y)) > 0.5 else Vector3(0.08, 1.45, 0.06)
	box(root, bar, pos, "dark_wooden_planks", Color(0.2, 0.15, 0.12), 1, false)
	var hb := Vector3(0.06, 0.08, 1.4) if absf(sin(rot_y)) > 0.5 else Vector3(1.4, 0.08, 0.06)
	box(root, hb, pos, "dark_wooden_planks", Color(0.2, 0.15, 0.12), 1, false)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 2.2
	moon.spot_range = 8.0
	moon.spot_angle = 32.0
	root.add_child(moon)
	var inward := (cell_center(map, c) - pos)
	inward.y = 0.0
	moon.look_at_from_position(pos + Vector3(0, 0.8, 0) + inward.normalized() * 0.25, _off(map, c, target), Vector3.UP)
	_register_light(moon, map, false)


func _wall_segment(root: Node3D, size: Vector3, center: Vector3, r: Dictionary, along_x: bool) -> void:
	# plaster/wallpaper over dark wood wainscot, 1950s institution look
	var low := 1.0
	var hi := size.y - low
	var c := center
	box(root, Vector3(size.x, low, size.z), Vector3(c.x, low / 2.0, c.z), "dark_wooden_planks", Color(0.55, 0.42, 0.34), 1, true, 0.0, 0.6)
	box(root, Vector3(size.x, hi, size.z), Vector3(c.x, low + hi / 2.0, c.z), r["wall"], r["wcol"], 1, true, 0.0, 0.4)
	# chair rail
	var rail := Vector3(size.x + (0.0 if along_x else 0.06), 0.06, size.z + (0.06 if along_x else 0.0))
	box(root, rail, Vector3(c.x, low + 0.03, c.z), "dark_wooden_planks", Color(0.35, 0.25, 0.2), 1, false)


func _build_wall(root: Node3D, map: String, ctr: Vector3, d: Vector2i, gap: bool, r: Dictionary, door_id: String) -> void:
	var along_x: bool = d.y != 0
	var mid := ctr + Vector3(d.x * CELL / 2.0, 0, d.y * CELL / 2.0)
	if not gap:
		var sz := Vector3(CELL + 0.2, WALL_H, 0.2) if along_x else Vector3(0.2, WALL_H, CELL + 0.2)
		_wall_segment(root, sz, mid, r, along_x)
		return
	var seg := (CELL - DOOR_W) / 2.0
	for s in [-1.0, 1.0]:
		var off: float = s * (DOOR_W / 2.0 + seg / 2.0)
		var sz2 := Vector3(seg + 0.1, WALL_H, 0.2) if along_x else Vector3(0.2, WALL_H, seg + 0.1)
		var p := mid + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
		_wall_segment(root, sz2, p, r, along_x)
		# door frame posts
		var post := mid + (Vector3(s * (DOOR_W / 2.0 + 0.05), DOOR_H / 2.0, 0) if along_x else Vector3(0, DOOR_H / 2.0, s * (DOOR_W / 2.0 + 0.05)))
		box(root, Vector3(0.1, DOOR_H, 0.3) if along_x else Vector3(0.3, DOOR_H, 0.1), post, "dark_wooden_planks", Color(0.4, 0.3, 0.24), 1, false)
	var lh := WALL_H - DOOR_H
	var lsz := Vector3(DOOR_W + 0.2, lh, 0.24) if along_x else Vector3(0.24, lh, DOOR_W + 0.2)
	box(root, lsz, mid + Vector3(0, DOOR_H + lh / 2.0, 0), "dark_wooden_planks", Color(0.4, 0.3, 0.24))
	if door_id != "" and not Game.flag("door_" + door_id):
		var dsz := Vector3(DOOR_W, DOOR_H, 0.14) if along_x else Vector3(0.14, DOOR_H, DOOR_W)
		var door := box(root, dsz, mid + Vector3(0, DOOR_H / 2.0, 0), "painted_metal_shutter", Color(0.45, 0.52, 0.55), 1, true, 0.0, 0.7)
		# a red mag-lock lamp
		var lamp := part(door, bmesh(Vector3(0.12, 0.12, 0.2) if along_x else Vector3(0.2, 0.12, 0.12)), Vector3(0, 0.35, 0), "plastered_wall_02", Color(1.0, 0.1, 0.05), 2.0)
		lamp.name = "lock_lamp"
		doors[door_id] = door
		interactables.append({"map": map, "kind": "door", "id": door_id, "pos": mid + Vector3(0, 1.0, 0), "point": mid, "label": "Examine door"})


func _off(map: String, c: Vector2i, o: Vector3) -> Vector3:
	return cell_center(map, c) + o


func _p(root: Node3D, map: String, c: Vector2i, name: String, o: Vector3, rot: float = 0.0, size: float = -2.0, layer: int = 2, tint := Color(1, 1, 1), by_h: bool = false) -> Node3D:
	return Lib.prop(root, name, _off(map, c, o), rot, size, layer, tint, by_h)


func _top(n: Node3D) -> float:
	if n == null:
		return 0.5
	var s: Vector3 = n.get_meta("size", Vector3.ONE)
	return n.global_position.y + s.y


func _build_props(map: String, root: Node3D) -> void:
	var wood := Color(0.55, 0.4, 0.3)
	var blood := Color(0.3, 0.02, 0.02)
	if map == "dana":
		var L := Vector2i(0, 0)
		# Lobby: reception desk, waiting benches, coat rack, a dead plant.
		box(root, Vector3(3.0, 1.1, 0.8), _off(map, L, Vector3(1.5, 0.55, -3.0)), "dark_wooden_planks", wood, 2, true, 0.0, 0.8)
		box(root, Vector3(3.1, 0.06, 0.9), _off(map, L, Vector3(1.5, 1.12, -3.0)), "dark_wooden_planks", wood * 0.7, 1, false)
		_p(root, map, L, "radio", Vector3(2.4, 1.15, -3.05), 0.0, 0.45, 0)
		_p(root, map, L, "gy_bench", Vector3(-3.35, 0, 0.6), PI / 2.0, 1.9, 2, Color(0.7, 0.6, 0.55))
		_p(root, map, L, "gy_bench", Vector3(-1.0, 0, 3.4), 0.0, 1.9, 2, Color(0.7, 0.6, 0.55))
		_p(root, map, L, "coatRackStanding", Vector3(-3.4, 0, -1.6), 0.0, 1.8, 2, Color(1, 1, 1), true)
		_p(root, map, L, "plantSmall1", Vector3(-3.4, 0, 2.2), 0.0, 0.7, 2, Color(0.6, 0.5, 0.4))
		props["ammo_lobby"] = _p(root, map, L, "cardboardBoxClosed", Vector3(-3.0, 0, -3.0), 0.4, 0.7)
		_p(root, map, L, "rugRectangle", Vector3(0.0, 0.0, 0.8), 0.0, 3.0, 0, Color(0.6, 0.5, 0.5))
		_p(root, map, L, "trashcan", Vector3(2.8, 0, -2.1), 0.0, 0.45)
		# West Hall: filing cabinets, a knocked-over chair, blood.
		var H := Vector2i(1, 0)
		box(root, Vector3(1.6, 0.02, 0.9), _off(map, H, Vector3(0.8, 0.01, 1.2)), "dirty_carpet", blood, 1, false)
		box(root, Vector3(0.7, 0.02, 2.0), _off(map, H, Vector3(2.4, 0.01, -0.6)), "dirty_carpet", blood * 0.9, 1, false)
		for i in 3:
			box(root, Vector3(0.6, 1.4, 0.6), _off(map, H, Vector3(-3.3 + i * 0.65, 0.7, 3.55)), "painted_metal_shutter", Color(0.45, 0.5, 0.45), 2, true, 0.0, 1.5)
		var ch := _p(root, map, H, "chair", Vector3(-1.2, 0.0, -1.6), 0.6, 0.6)
		ch.rotation.z = PI / 2.0
		ch.position.y += 0.25
		_p(root, map, H, "gy_bench-damaged", Vector3(2.6, 0, -3.4), 0.0, 1.6, 2, Color(0.7, 0.6, 0.55))
		_p(root, map, H, "cardboardBoxOpen", Vector3(3.3, 0, -2.4), 0.3, 0.6)
		# Evidence Room: steel shelving, boxed evidence.
		var E := Vector2i(2, 0)
		for i in 3:
			_p(root, map, E, "bookcaseOpen", Vector3(-1.5 + i * 0.9, 0, 3.55), PI, 0.85, 2, Color(0.55, 0.6, 0.62))
		box(root, Vector3(2.5, 1.8, 0.5), _off(map, E, Vector3(2.0, 0.9, -3.5)), "rusty_metal_02", Color(0.45, 0.47, 0.5), 2, true, 0.0, 1.2)
		_p(root, map, E, "cardboardBoxClosed", Vector3(3.3, 0, 2.0), 0.2, 0.7)
		_p(root, map, E, "cardboardBoxClosed", Vector3(3.1, 0, 1.2), 1.1, 0.6)
		props["file_meridian"] = _p(root, map, E, "desk", Vector3(-2.8, 0, -2.6), PI / 2.0, 1.4)
		# Chief's office: desk, chair, bookcase, the TV left on.
		var C := Vector2i(1, -1)
		var dk := box(root, Vector3(1.8, 0.8, 0.9), _off(map, C, Vector3(0, 0.4, -2.4)), "dark_wooden_planks", wood * 0.9, 2, true, 0.0, 0.9)
		dk.name = "chief_desk"
		_p(root, map, C, "chairDesk", Vector3(0, 0, -3.3), PI, 0.65)
		_p(root, map, C, "bookcaseClosedWide", Vector3(-3.55, 0, -1.2), PI / 2.0, 1.6)
		_p(root, map, C, "sideTableDrawers", Vector3(3.2, 0, -3.3), 0.0, 0.8)
		_p(root, map, C, "televisionVintage", Vector3(3.2, 0.72, -3.3), 0.0, 0.7, 0)
		var tv := _add_light(root, "", _off(map, C, Vector3(3.0, 1.2, -2.7)), Color(0.5, 0.65, 1.0), 0.7, 3.5, true)
		tv.set_meta("tv", true)
		_p(root, map, C, "radio", Vector3(-0.5, 0.8, -2.45), 0.2, 0.4, 0, Color(0.4, 0.35, 0.3))
		# Light motivation: a green banker's lamp on the desk and moonlight through the blinds.
		_p(root, map, C, "lampRoundTable", Vector3(-0.75, 0.8, -2.2), 0.0, 0.32, 0)
		_glow_quad(root, Vector2(0.18, 0.1), _off(map, C, Vector3(-0.75, 1.12, -2.2)), Vector3(-PI / 2.0, 0, 0), Color(1.0, 0.8, 0.45))
		_add_light(root, "", _off(map, C, Vector3(-0.75, 1.35, -1.9)), Color(1.0, 0.78, 0.48), 3.2, 7.5)
		_moon_window(root, map, C, Vector3(3.88, 1.8, 0.8), -PI / 2.0, Vector3(0.5, 0, 0.6))
		props["ammo_chief"] = _p(root, map, C, "cardboardBoxOpen", Vector3(-3.0, 0, 2.5), 0.0, 0.7)
		_p(root, map, C, "rugRectangle", Vector3(0, 0.0, 0.5), PI / 2.0, 3.0, 0, Color(0.5, 0.35, 0.3))
		# Records: bookcases, cabinets, a desk lamp by the typewriter.
		var R := Vector2i(1, 1)
		_p(root, map, R, "bookcaseClosedWide", Vector3(-2.5, 0, 3.55), PI, 1.8)
		_p(root, map, R, "bookcaseClosedWide", Vector3(-0.5, 0, 3.55), PI, 1.8)
		_p(root, map, R, "bookcaseOpen", Vector3(-3.55, 0, 0.6), PI / 2.0, 1.0)
		props["herb_records"] = _p(root, map, R, "sideTableDrawers", Vector3(-2.5, 0, -2.0), 0.0, 0.7)
		_p(root, map, R, "lampRoundTable", Vector3(1.8, 0.8, 3.0), 0.0, 0.3, 0)
		_add_light(root, "", _off(map, R, Vector3(1.8, 1.4, 2.7)), Color(1.0, 0.75, 0.45), 0.9, 4.0)
		_p(root, map, R, "chair", Vector3(2.4, 0, 2.1), PI, 0.55)
		props["file_choir"] = _p(root, map, R, "cardboardBoxClosed", Vector3(2.8, 0, -3.3), 0.3, 0.7)
	else:
		# Dormitory: iron-frame beds in a row, a bunk bed, a moonlit window.
		var D := Vector2i(0, 0)
		for x in [-2.5, -0.4]:
			_p(root, map, D, "bedSingle", Vector3(x, 0, 2.7), PI, 2.0, 2, Color(0.75, 0.75, 0.8))
		props["note_jenny"] = _p(root, map, D, "bedSingle", Vector3(1.7, 0, 2.7), PI, 2.0, 2, Color(0.75, 0.75, 0.8))
		_p(root, map, D, "cabinetBedDrawer", Vector3(-1.45, 0, 3.4), PI, 0.5)
		_p(root, map, D, "cabinetBedDrawer", Vector3(0.65, 0, 3.4), PI, 0.5)
		_p(root, map, D, "bedBunk", Vector3(0.8, 0, -3.0), 0.0, 2.0, 2, Color(0.7, 0.7, 0.75))
		_p(root, map, D, "bear", Vector3(-0.4, 0.45, 2.3), 0.4, 0.35, 0)
		_p(root, map, D, "rugRectangle", Vector3(-0.5, 0, 0.6), 0.0, 3.2, 0, Color(0.45, 0.45, 0.55))
		# moonlight through the window on the outer wall
		_glow_quad(root, Vector2(1.4, 1.6), _off(map, D, Vector3(-3.88, 1.8, 0.4)), Vector3(0, PI / 2.0, 0), Color(0.35, 0.45, 0.65), false)
		box(root, Vector3(0.06, 1.5, 0.08), _off(map, D, Vector3(-3.86, 1.8, 0.4)), "dark_wooden_planks", Color(0.2, 0.15, 0.12), 1, false)
		box(root, Vector3(0.06, 0.08, 1.5), _off(map, D, Vector3(-3.86, 1.8, 0.4)), "dark_wooden_planks", Color(0.2, 0.15, 0.12), 1, false)
		var moon := SpotLight3D.new()
		moon.light_color = Color(0.55, 0.65, 1.0)
		moon.light_energy = 2.0
		moon.spot_range = 8.0
		moon.spot_angle = 30.0
		root.add_child(moon)
		moon.look_at_from_position(_off(map, D, Vector3(-3.7, 2.6, 0.4)), _off(map, D, Vector3(-0.8, 0, 0.6)), Vector3.UP)
		_register_light(moon, map, false)
		# Corridor: wall sconces, debris, a toppled bench.
		var Co := Vector2i(1, 0)
		box(root, Vector3(1.4, 0.02, 0.7), _off(map, Co, Vector3(-1.5, 0.01, 0.8)), "dirty_carpet", blood, 1, false)
		_p(root, map, Co, "gy_debris-wood", Vector3(-2.6, 0, 3.0), 0.5, 1.2, 0, Color(0.6, 0.5, 0.45))
		_p(root, map, Co, "gy_bench-damaged", Vector3(2.8, 0, 3.4), 0.0, 1.6, 2, Color(0.7, 0.6, 0.55))
		_p(root, map, Co, "coatRackStanding", Vector3(-3.4, 0, -3.3), 0.0, 1.7, 2, Color(1, 1, 1), true)
		for z in [-3.85, 3.85]:
			_p(root, map, Co, "lampWall", Vector3(-1.8, 1.9, z * 0.97), (0.0 if z < 0 else PI), 0.3, 0)
		# Chapel: pews either side of an aisle, altar, candles, a coffin.
		var Ch := Vector2i(2, 0)
		for x in [-2.6, -1.1, 0.4]:
			for z in [-1.8, 1.8]:
				_p(root, map, Ch, "gy_bench", Vector3(x, 0, z), -PI / 2.0, 2.0, 2, Color(0.55, 0.45, 0.4))
		_p(root, map, Ch, "gy_altar-wood", Vector3(2.7, 0, -2.6), -PI / 2.0, 1.3, 2, Color(0.7, 0.6, 0.55))
		_p(root, map, Ch, "gy_candle-multiple", Vector3(2.7, 0.75, -2.6), 0.0, 0.4, 0)
		_p(root, map, Ch, "gy_coffin-old", Vector3(2.2, 0, 2.6), PI / 2.0, 1.9, 2, Color(0.7, 0.6, 0.55))
		_p(root, map, Ch, "gy_candle-multiple", Vector3(3.4, 0, 1.4), 0.0, 0.45, 0)
		_p(root, map, Ch, "gy_candle-multiple", Vector3(3.4, 0, -1.4), 0.0, 0.45, 0)
		_p(root, map, Ch, "gy_cross-wood", Vector3(3.8, 2.3, 0), PI / 2.0, 1.0, 0, Color(0.7, 0.6, 0.55), true)
		for z in [-1.4, 1.4]:
			candle_lights.append(_add_light(root, "", _off(map, Ch, Vector3(3.2, 0.9, z)), Color(1.0, 0.55, 0.25), 0.9, 4.0))
		candle_lights.append(_add_light(root, "", _off(map, Ch, Vector3(2.7, 1.5, -2.4)), Color(1.0, 0.55, 0.25), 0.7, 3.5))
		for x in [-2.0, 1.0]:
			for z in [-3.88, 3.88]:
				_glow_quad(root, Vector2(0.8, 1.6), _off(map, Ch, Vector3(x, 2.0, z)), Vector3.ZERO, Color(0.35, 0.06, 0.05), false)
		# Mail room: sorting shelves, parcels, a table.
		var M := Vector2i(1, 1)
		_p(root, map, M, "bookcaseOpen", Vector3(-3.55, 0, 1.0), PI / 2.0, 1.2)
		_p(root, map, M, "bookcaseOpen", Vector3(-3.55, 0, -0.4), PI / 2.0, 1.2)
		props["file_bellman"] = _p(root, map, M, "table", Vector3(-0.8, 0, -1.5), 0.2, 1.5)
		_p(root, map, M, "cardboardBoxClosed", Vector3(-2.6, 0, 3.2), 0.4, 0.7)
		_p(root, map, M, "cardboardBoxOpen", Vector3(-1.8, 0, 3.4), 0.0, 0.6)
		_p(root, map, M, "lampRoundTable", Vector3(1.8, 0.8, 3.0), 0.0, 0.3, 0)
		_add_light(root, "", _off(map, M, Vector3(1.8, 1.4, 2.7)), Color(1.0, 0.75, 0.45), 0.9, 4.0)
		_p(root, map, M, "chair", Vector3(2.4, 0, 2.1), PI, 0.55)
		# Playroom: toy chest, a big teddy, a little table set for tea.
		var P := Vector2i(1, -1)
		box(root, Vector3(1.2, 0.6, 0.7), _off(map, P, Vector3(2.5, 0.3, -3.0)), "dark_wooden_planks", Color(0.6, 0.3, 0.25), 2)
		props["bear"] = _p(root, map, P, "bear", Vector3(-0.5, 0, 2.5), PI, 0.9)
		_p(root, map, P, "tableCloth", Vector3(0.5, 0, -0.6), 0.0, 1.0, 2, Color(0.8, 0.7, 0.75))
		_p(root, map, P, "chair", Vector3(-0.3, 0, -0.6), PI / 2.0, 0.45)
		_p(root, map, P, "chair", Vector3(1.3, 0, -0.6), -PI / 2.0, 0.45)
		_p(root, map, P, "pillow", Vector3(2.6, 0, 1.2), 0.3, 0.6, 0)
		_p(root, map, P, "rugRectangle", Vector3(0.5, 0, 0.0), 0.0, 3.4, 0, Color(0.6, 0.45, 0.6))
		_p(root, map, P, "bookcaseOpen", Vector3(3.55, 0, 0.6), -PI / 2.0, 1.1, 2, Color(0.9, 0.8, 0.85))
		# Light motivation: a little moon-and-stars nightlight by the cots, and a moonlit window.
		box(root, Vector3(0.05, 0.16, 0.12), _off(map, P, Vector3(-3.87, 0.4, 2.2)), "plastered_wall_02", Color(0.9, 0.85, 0.7), 1, false)
		_glow_quad(root, Vector2(0.14, 0.14), _off(map, P, Vector3(-3.83, 0.42, 2.2)), Vector3(0, PI / 2.0, 0), Color(1.0, 0.75, 0.45))
		var nl := _add_light(root, "", _off(map, P, Vector3(-3.5, 0.5, 2.2)), Color(1.0, 0.62, 0.42), 2.6, 6.5)
		nl.set_meta("nightlight", true)
		_moon_window(root, map, P, Vector3(-1.2, 1.8, -3.88), 0.0, Vector3(0.0, 0, 0.5))


func _add_inter(map: String, c: Vector2i, offset: Vector3, kind: String, id: String, label: String) -> Dictionary:
	var pos := _off(map, c, offset)
	if props.has(id):
		pos.y = _top(props[id]) + 0.12
	var ctr := cell_center(map, c)
	var to_c := Vector3(ctr.x - pos.x, 0, ctr.z - pos.z)
	var point := Vector3(pos.x, 0, pos.z)
	if to_c.length() > 1.2:
		point += to_c.normalized() * 0.95
	var it := {"map": map, "kind": kind, "id": id, "pos": pos, "point": point, "label": label, "cell": c}
	interactables.append(it)
	var root: Node3D = get_node(map)
	match kind:
		"typewriter":
			Lib.prop(root, "desk", pos, PI, 1.4)
			var tw := part(root, bmesh(Vector3(0.45, 0.16, 0.35)), pos + Vector3(0, 0.86, 0), "rusty_metal_02", Color(0.2, 0.2, 0.22))
			part(tw, bmesh(Vector3(0.5, 0.06, 0.06)), Vector3(0, 0.08, -0.12), "rusty_metal_02", Color(0.12, 0.12, 0.12))
			part(tw, bmesh(Vector3(0.3, 0.2, 0.02)), Vector3(0, 0.18, -0.14), "plastered_wall_02", Color(0.95, 0.93, 0.85), 0.25)
			it["node"] = tw
		"tube":
			part(root, cyl(0.15, 0.15, WALL_H), pos + Vector3(0, WALL_H / 2.0, 0), "rusty_metal_02", Color(0.85, 0.65, 0.35))
			box(root, Vector3(0.5, 0.6, 0.5), pos + Vector3(0, 1.2, 0), "rusty_metal_02", Color(0.8, 0.6, 0.3), 2, true, 0.0, 1.5)
			part(root, cyl(0.2, 0.2, 0.08), pos + Vector3(0, 1.55, 0), "rusty_metal_02", Color(0.7, 0.55, 0.3))
		"fusebox":
			box(root, Vector3(0.6, 0.7, 0.2), pos, "painted_metal_shutter", Color(0.5, 0.52, 0.45), 1, false, 0.0, 2.0)
			var fl := part(root, bmesh(Vector3(0.08, 0.08, 0.05)), pos + Vector3(0.2, 0.25, 0.12), "plastered_wall_02", Color(1.0, 0.2, 0.1) if not Game.flag("power") else Color(0.2, 1.0, 0.3), 2.0)
			fl.name = "fuse_lamp"
		"hide":
			var to_c2 := Vector3(ctr.x - pos.x, 0, ctr.z - pos.z)
			var face: float = atan2(to_c2.x, to_c2.z)
			var wd := Lib.prop(root, "bookcaseClosedDoors", pos, face + PI, 2.2, 2, Color(0.75, 0.6, 0.5), true)
			wd.name = "wardrobe_" + id
		"exit":
			box(root, Vector3(0.16, DOOR_H, 1.6), pos + Vector3(0, DOOR_H / 2.0, 0), "dark_wooden_planks", Color(0.5, 0.32, 0.22), 1, false, 0.0, 0.8)
			box(root, Vector3(0.2, 0.3, 1.7), pos + Vector3(-0.05, 1.1, 0), "rusty_metal_02", Color(0.5, 0.5, 0.5), 1, false)
			var chain := part(root, cyl(0.04, 0.04, 1.5, 4), pos + Vector3(-0.12, 1.1, 0.0), "rusty_metal_02", Color(0.4, 0.4, 0.4))
			chain.rotation.x = PI / 2.0
		"note":
			var nm := part(root, bmesh(Vector3(0.3, 0.02, 0.38)), pos, "plastered_wall_02", Color(0.95, 0.93, 0.85), 0.5)
			it["node"] = nm
		"phone":
			pass
		"item", "ammo":
			if Game.flag("picked_" + id):
				interactables.erase(it)
				return it
			var col := Color(0.9, 0.8, 0.3)
			match label:
				"Fuse":
					col = Color(1.0, 0.5, 0.15)
				"Tower Key":
					col = Color(1.0, 0.85, 0.2)
				"Green Herb":
					col = Color(0.3, 0.9, 0.3)
			if kind == "ammo":
				col = Color(0.6, 0.65, 0.45)
			var im := part(root, bmesh(Vector3(0.18, 0.18, 0.18)), pos, "plastered_wall_02", col, 0.8)
			# the classic glint, so items read in the dark
			var gl := _glow_quad(im, Vector2(0.35, 0.35), Vector3(0, 0.2, 0), Vector3.ZERO, Color(0.6, 0.55, 0.4))
			var bm := StandardMaterial3D.new()
			bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			bm.albedo_texture = _sparkle_tex()
			bm.albedo_color = Color(1, 0.95, 0.8)
			gl.material_override = bm
			it["node"] = im
			it["glint"] = gl
			spin_nodes.append(im)
	return it


var _sparkle: ImageTexture = null


func _sparkle_tex() -> ImageTexture:
	if _sparkle != null:
		return _sparkle
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var dx := absf(x - 7.5)
			var dy := absf(y - 7.5)
			var v := maxf(0.0, 1.0 - minf(dx, dy) / 1.2) * maxf(0.0, 1.0 - maxf(dx, dy) / 8.0)
			v = maxf(v, maxf(0.0, 1.0 - Vector2(dx, dy).length() / 3.0))
			img.set_pixel(x, y, Color(v, v, v, v))
	_sparkle = ImageTexture.create_from_image(img)
	return _sparkle


func _build_interactables() -> void:
	_add_inter("dana", Vector2i(0, 0), Vector3(1.0, 1.15, -3.0), "note", "note_toll", "Read memo")
	_add_inter("dana", Vector2i(0, 0), Vector3(-3.0, 0.4, -3.0), "ammo", "ammo_lobby", "Handgun Ammo")
	_add_inter("dana", Vector2i(1, 0), Vector3(-1.5, 1.4, -3.85), "fusebox", "fusebox", "Examine fuse box")
	_add_inter("dana", Vector2i(2, 0), Vector3(2.0, 1.95, -3.4), "item", "tower_key", "Tower Key")
	_add_inter("dana", Vector2i(1, 1), Vector3(2.4, 0, 2.9), "typewriter", "tw_dana", "Use typewriter")
	_add_inter("dana", Vector2i(1, 1), Vector3(3.75, 0, -1.5), "tube", "tube_dana", "Use mail tube")
	_add_inter("dana", Vector2i(1, 1), Vector3(-2.5, 0.4, -2.0), "item", "herb_records", "Green Herb")
	_add_inter("dana", Vector2i(1, -1), Vector3(0.4, 0.82, -2.4), "note", "note_chief", "Read log")
	_add_inter("dana", Vector2i(1, -1), Vector3(-3.0, 0.4, 2.5), "ammo", "ammo_chief", "Handgun Ammo")
	_add_inter("jenny", Vector2i(0, 0), Vector3(1.7, 0.52, 2.6), "note", "note_jenny", "Read page")
	_add_inter("jenny", Vector2i(0, 0), Vector3(-3.3, 0, -2.5), "hide", "hide_dorm", "Hide in wardrobe")
	_add_inter("jenny", Vector2i(1, 0), Vector3(1.5, 0, -3.3), "hide", "hide_corr", "Hide in closet")
	_add_inter("jenny", Vector2i(1, -1), Vector3(2.5, 0.75, -3.0), "item", "fuse", "Fuse")
	_add_inter("jenny", Vector2i(1, -1), Vector3(-3.3, 0, -0.5), "hide", "hide_play", "Hide in wardrobe")
	_add_inter("jenny", Vector2i(1, 1), Vector3(2.4, 0, 2.9), "typewriter", "tw_jenny", "Use typewriter")
	_add_inter("jenny", Vector2i(1, 1), Vector3(3.75, 0, -1.5), "tube", "tube_jenny", "Use mail tube")
	_add_inter("jenny", Vector2i(2, 0), Vector3(3.85, 0, 0), "exit", "chapel_exit", "Open chapel doors")
	# Lore files (Meridian Biotech, the Choir Stone, the Bellman).
	_add_inter("dana", Vector2i(2, 0), Vector3(-2.8, 0.8, -2.6), "note", "file_meridian", "Read file")
	_add_inter("dana", Vector2i(1, 1), Vector3(2.8, 0.75, -3.3), "note", "file_choir", "Read report")
	_add_inter("jenny", Vector2i(1, 1), Vector3(-0.8, 0.8, -1.5), "note", "file_bellman", "Read ledger")


func _capsule(body: CollisionObject3D, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position = Vector3(0, h / 2.0, 0)
	body.add_child(cs)


func _model(style: String, body: Node3D) -> Node3D:
	var m := Node3D.new()
	m.set_script(ActorScript)
	body.add_child(m)
	m.setup(style, body)
	return m


func _build_players() -> void:
	var starts := {"dana": _off("dana", Vector2i(0, 0), Vector3(0, 0.05, 1.0)), "jenny": _off("jenny", Vector2i(0, 0), Vector3(-1.0, 0.05, 0.5))}
	var start_rot := {"dana": PI / 2.0, "jenny": -PI / 2.0}
	for who in ["dana", "jenny"]:
		var p := CharacterBody3D.new()
		p.set_script(PlayerScript)
		p.name = who
		p.who = who
		p.main = self
		p.collision_layer = 4
		p.collision_mask = 1 | 2 | 8
		if who == "dana":
			p.walk_speed = 1.85
			p.run_speed = 4.3
		_capsule(p, 0.3, 1.7)
		add_child(p)
		p.global_position = starts[who]
		p.rotation.y = start_rot[who]
		p.mesh_root = _model(who, p)
		players[who] = p


func _build_enemies() -> void:
	var z := CharacterBody3D.new()
	z.set_script(ZombieScript)
	z.main = self
	z.collision_layer = 8
	z.collision_mask = 1 | 4
	_capsule(z, 0.4, 1.8)
	add_child(z)
	z.global_position = _off("dana", Vector2i(1, 0), Vector3(3.2, 0.05, 2.4))
	z.rotation.y = -PI / 2.0   # facing the wall, scratching
	z.mesh_root = _model("tallow", z)
	zombies.append(z)
	if Game.flag("tallow1_dead"):
		z.die()

	var b: CharacterBody3D = BellmanScript.new()  # C#
	b.main = self
	b.collision_layer = 8
	b.collision_mask = 1 | 4
	_capsule(b, 0.45, 2.4)
	add_child(b)
	b.global_position = _off("jenny", Vector2i(2, 0), Vector3(1.0, 0.05, 0))
	b.rotation.y = PI / 2.0
	b.mesh_root = _model("bellman", b)
	bellman = b


func _build_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST_SHADER
	post_rect.material = post_mat
	post_layer.add_child(post_rect)
	post_mat.set_shader_parameter("scanlines", 0.12 if Game.crt_on else 0.0)
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	touch = CanvasLayer.new()
	touch.set_script(TouchScript)
	add_child(touch)
	hud.touch_ref = touch
	hud.layout_overlay()
	# Title camera: looking down the chapel aisle through the fog.
	title_cam = Camera3D.new()
	title_cam.fov = 55.0
	title_cam.far = 40.0
	add_child(title_cam)
	title_cam.look_at_from_position(_off("jenny", Vector2i(2, 0), Vector3(-3.4, 1.3, 0.3)), _off("jenny", Vector2i(2, 0), Vector3(3.5, 1.6, 0)), Vector3.UP)


func _load_sfx(n: String) -> AudioStream:
	var path := "res://assets/audio/%s.ogg" % n
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _build_sfx() -> void:
	for n in ["bell", "bell_toll", "bell_roar", "gunshot", "splat", "hurt", "tube", "pickup", "menu", "sting", "heart", "unlock", "creak", "door", "scream", "breath", "typewriter", "flashlight", "glitch", "zombie_die", "slam", "bulb_pop", "groan_1", "groan_2", "groan_3", "groan_4"]:
		sfx[n] = _load_sfx(n)
	for surf in ["wood", "concrete", "carpet"]:
		for i in 3:
			sfx["step_%s_%d" % [surf, i]] = _load_sfx("step_%s_%d" % [surf, i])
	sfx["phone"] = Synth.phone_ring()
	sfx["musicbox"] = Synth.music_box()
	sfx["click"] = sfx["flashlight"]
	static_player = _loop_player("static", -80.0)
	amb_player = _loop_player("amb_orphanage", -80.0)
	amb2_player = _loop_player("amb_station", -80.0)
	title_music = _loop_player("title_music", -80.0)
	title_music.bus = &"Music"
	# End credits: the sung version of the main theme, played once.
	credits_music = AudioStreamPlayer.new()
	credits_music.name = "credits_music"
	credits_music.stream = _load_sfx("credits_song")
	credits_music.volume_db = -4.0
	credits_music.bus = &"Music"
	add_child(credits_music)
	var rain := _loop_player("amb_rain", -80.0)
	rain.name = "rain"


func _loop_player(n: String, vol: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	var st: AudioStream = _load_sfx(n)
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		st.loop = true
	a.stream = st
	a.volume_db = vol
	a.name = n
	a.bus = &"SFX"  # ambience rides SFX; title_music goes on Music
	add_child(a)
	a.play()
	return a


func _apply_state() -> void:
	var st: Dictionary = Game.state
	if not st.has("light"):
		st["light"] = {"dana": false, "jenny": false}
	for who in ["dana", "jenny"]:
		var pos: Array = st["pos"][who]
		if pos.size() == 3:
			players[who].global_position = Vector3(pos[0], pos[1] + 0.05, pos[2])
			players[who].rotation.y = float(st["rot"][who])
		players[who].active = st["active"] == who
		players[who].set_light(bool(st["light"].get(who, false)))
		players[who].mesh_root.snap()
	for z in zombies:
		z.mesh_root.snap()
	bellman.mesh_root.snap()


# ---------------------------------------------------------------- helpers

const MAX_VOICES := 4  # max copies of one sound at once (the self-typing typewriter piles up otherwise)
var voices: Dictionary = {}


func play_sfx(sname: String, pos = null, vol: float = 0.0, pitch: float = 1.0, max_dist: float = 35.0) -> void:
	if not sfx.has(sname) or sfx[sname] == null:
		return
	if int(voices.get(sname, 0)) >= MAX_VOICES:
		return
	voices[sname] = int(voices.get(sname, 0)) + 1
	var a: Node = null
	if pos == null:
		var a2 := AudioStreamPlayer.new()
		a2.stream = sfx[sname]
		a2.volume_db = vol
		a2.pitch_scale = pitch
		a2.bus = &"SFX"
		a = a2
		add_child(a2)
	else:
		var a3 := AudioStreamPlayer3D.new()
		a3.stream = sfx[sname]
		a3.volume_db = vol
		a3.pitch_scale = pitch
		a3.unit_size = 4.0
		a3.max_distance = max_dist
		a3.bus = &"SFX"
		a = a3
		add_child(a3)
		a3.global_position = pos
	a.finished.connect(_voice_done.bind(sname, a))
	a.play()


func _voice_done(sname: String, a: Node) -> void:
	voices[sname] = maxi(0, int(voices.get(sname, 1)) - 1)
	a.queue_free()


func play_step(pos: Vector3, surface: String, vol: float = 0.0, pitch: float = 1.0, max_dist: float = 25.0) -> void:
	play_sfx("step_%s_%d" % [surface, randi() % 3], pos, vol, pitch * randf_range(0.93, 1.07), max_dist)


func show_message(text: String, secs: float = 3.5) -> void:
	hud.show_message(text, secs)


func tutorial(key: String, text: String) -> void:
	if text == "" or Game.flag("tut_" + key):
		return
	Game.set_flag("tut_" + key)
	hud.show_tutorial(text, 6.5)


func los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()


func make_noise(pos: Vector3, radius: float) -> void:
	if Game.state["active"] == "jenny" and bellman != null:
		bellman.hear(pos, radius)


## Pathfinding is in C# (WaypointGraph.cs), shared by both enemies.
func next_waypoint(map: String, from: Vector3, to: Vector3, blocked: Array) -> Vector3:
	return graph.next_waypoint(map, from, to, blocked)


func find_aim_target(p):
	var best = null
	var best_d := 14.0
	var fwd: Vector3 = -p.global_transform.basis.z
	for z in zombies:
		if z.dead:
			continue
		var to: Vector3 = z.global_position - p.global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and rad_to_deg(fwd.angle_to(to.normalized())) < 75.0 and los(p.global_position + Vector3(0, 1.4, 0), z.global_position + Vector3(0, 1.2, 0)):
			best = z
			best_d = d
	return best


func fire(p, target) -> void:
	if fire_cd > 0.0:
		return
	fire_cd = 0.45
	if int(Game.state["ammo"]) <= 0:
		play_sfx("click")
		show_message("Out of ammo.")
		return
	Game.state["ammo"] = int(Game.state["ammo"]) - 1
	play_sfx("gunshot", null, -2.0, randf_range(0.95, 1.05))
	shake = maxf(shake, 0.25)
	var muzzle: Vector3 = p.muzzle_position()
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.85, 0.5)
	fl.light_energy = 5.0
	fl.omni_range = 7.0
	add_child(fl)
	fl.global_position = muzzle
	create_tween().tween_callback(fl.queue_free).set_delay(0.06)
	# Muzzle flash: a star-shaped billboard for two frames.
	var mf := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	mf.mesh = q
	var mm := StandardMaterial3D.new()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.albedo_texture = _muzzle_tex()
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mm.albedo_color = Color(1.0, 0.85, 0.55)
	mf.material_override = mm
	mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mf)
	mf.global_position = muzzle
	mf.rotation.z = randf() * TAU
	create_tween().tween_callback(mf.queue_free).set_delay(0.07)
	p.recoil()
	if target != null:
		target.hit(1)
		target.knockback(p.global_position)


func _muzzle_tex() -> ImageTexture:
	if muzzle_tex != null:
		return muzzle_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5)
			var a := atan2(d.y, d.x)
			var r := d.length() / 8.0
			var spike := 0.55 + 0.45 * absf(cos(a * 3.0))
			var v := clampf(1.0 - r / spike, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.9, v * 0.6, v))
	muzzle_tex = ImageTexture.create_from_image(img)
	return muzzle_tex


func hurt_player(map: String, n: int) -> void:
	var p = players[map]
	if p.invuln > 0.0:
		return
	p.invuln = 1.0
	Game.state["hp"][map] = int(Game.state["hp"][map]) - n
	play_sfx("splat")
	play_sfx("hurt", null, -4.0, 1.25 if map == "jenny" else 0.9)
	shake = maxf(shake, 0.5)
	distort = maxf(distort, 0.5)
	p.act("Hit_Chest", 0.5)
	show_message("Ugh!", 1.0)
	if int(Game.state["hp"][map]) <= 0:
		die("The Tallow-folk pull you into the wax.")


func on_chase_start() -> void:
	# Spotted: a sting, a shriek of the bell, a jolt - then he comes.
	play_sfx("sting", null, -3.0)
	play_sfx("bell_roar", bellman.global_position + Vector3(0, 2, 0), 2.0, 0.7)
	play_sfx("glitch", null, -8.0)
	shake = maxf(shake, 0.35)
	distort = maxf(distort, 0.35)
	panic = minf(100.0, panic + 20.0)
	if not Game.flag("first_chase"):
		Game.set_flag("first_chase")
		_kill_lights_near(bellman.global_position, true)
		tutorial("chase", "RUN. Break line of sight, then hide - or reach the Mail Room.")


func bellman_grab(difficulty: float) -> void:
	if Game.mode != "play" or players["jenny"].invuln > 0.0:
		return
	var p = players["jenny"]
	if p.hidden_in != "":
		_unhide(p)
	Game.mode = "struggle"
	# capped so it stays winnable on a touchscreen
	struggle_need = mini(int(7.0 + panic / 10.0 * difficulty), 15)
	struggle_count = 0
	struggle_t = 3.2
	play_sfx("sting")
	play_sfx("glitch", null, -2.0)
	play_sfx("scream", null, -6.0, 1.1)
	shake = 1.0
	distort = 1.0
	_update_struggle()


func _update_struggle() -> void:
	var bar := ""
	for i in struggle_need:
		bar += "#" if i < struggle_count else "-"
	hud.show_overlay("STRUGGLE!", "The Bellman has you!\n\nMash %s to break free!\n\n[%s]\n\n%.1f" % [Game.glyph("interact"), bar, maxf(0.0, struggle_t)], Color(0.95, 0.2, 0.15), 0.45)


func _end_struggle(won: bool) -> void:
	hud.hide_overlay()
	Game.mode = "play"
	var p = players["jenny"]
	p.invuln = 3.0
	if won:
		bellman.stun(4.5)
		panic = 65.0
		play_sfx("slam", bellman.global_position)
		show_message("You wrench free and he staggers!")
	else:
		Game.state["hp"]["jenny"] = int(Game.state["hp"]["jenny"]) - 1
		play_sfx("splat")
		distort = 1.0
		if int(Game.state["hp"]["jenny"]) <= 0:
			die("The shears close.")
			return
		bellman.stun(3.5)
		panic = 85.0
		show_message("The shears bite. You tear loose, bleeding. RUN.")


func die(reason: String) -> void:
	Game.mode = "dead"
	var who: String = Game.state["active"]
	players[who].act("Death01", 99.0)
	play_sfx("bell_toll", null, -4.0, 0.8)
	distort = 0.6
	dead_index = 0
	set_meta("death_reason", reason)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: post_mat.set_shader_parameter("fade", v), 0.0, 0.6, 1.5)
	# tween on the node, not a SceneTreeTimer: tree timers survive a scene
	# reload and call into the freed level
	create_tween().tween_callback(func() -> void:
		if Game.mode == "dead":
			_render_death()).set_delay(1.2)


func death_options() -> Array:
	return ["Retry from last save" if Game.has_save() else "Restart the demo", "Quit to title"]


func _render_death() -> void:
	var body: String = str(get_meta("death_reason", "")) + "\n\n"
	var opts := death_options()
	for i in opts.size():
		body += ("> " if i == dead_index else "   ") + opts[i] + "\n"
	body += "\n%s choose" % Game.glyph("interact")
	hud.show_overlay("YOU DIED", body, Color(0.8, 0.05, 0.05), 0.6)


func death_choose(i: int) -> void:
	if i == 0:
		Game.restart(Game.has_save())
	else:
		Game.go_to_title()


func _win() -> void:
	Game.mode = "win"
	var secs := float(Game.state["time"])
	var saves := int(Game.state["saves"])
	var rank := "D"
	if secs < 420.0 and saves <= 2:
		rank = "S"
	elif secs < 660.0:
		rank = "A"
	elif secs < 960.0:
		rank = "B"
	elif secs < 1500.0:
		rank = "C"
	var body := "Jenny slips the Tower Key into the padlock. The chain falls. Outside, the fog is moving like breath.\n\nSomewhere above the town, the bell starts to ring again.\n\nTIME  %02d:%02d\nSAVES  %d\nRANK  %s" % [int(secs) / 60, int(secs) % 60, saves, rank]
	play_sfx("bell_toll", null, -6.0, 0.7)
	hud.show_overlay("HARROW'S WAKE", body, Color(0.85, 0.7, 0.35), 0.88, "%s Continue" % Game.glyph("interact"))


# ---------------------------------------------------------------- demo end card

const CREDITS := """HARROW'S WAKE - FREE DEMO

Design, code and direction
Tylerlikesps4

Characters and animation
Quaternius - Universal Animation Library (CC0)

Furniture and graveyard props
Kenney - Furniture Kit, Graveyard Kit (CC0)

Textures
Poly Haven (CC0)

Sound effects
Kenney, rubberduck, kurt, AntumDeluge, bart,
Cassie-OrbitGames, remaxim, Nocturnal_Vanguard,
bretbernhoft, techiew, Kresiek (CC0, via OpenGameArt)

Music
\"Harrow's Wake (Main Theme)\" - original score
and lullaby by Tylerlikesps4 (GPL-3.0)
FluidR3 GM soundfont - Frank Wen (MIT)
Voice: Piper TTS, LJ Speech voice (MIT, public-domain data)

Engine
Godot Engine 4.3 (MIT)

Code licensed GPL-3.0. Assets keep their own licenses.
Full credits: CREDITS.md

Thank you for playing."""


func _show_end_card() -> void:
	Game.mode = "endcard"
	end_t = 0.0
	hud.show_overlay("THANKS FOR PLAYING", "Thanks for playing the Harrow's Wake demo -\nfull game coming soon.\n\nComing in the full game: Elias and the cryo lab, the Otherworld, the bell tower, more endings.", Color(0.85, 0.7, 0.35), 0.96)
	hud.ov_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if credits_lbl == null:
		credits_lbl = Label.new()
		credits_lbl.add_theme_font_size_override("font_size", 8)
		credits_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
		credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		credits_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.overlay.add_child(credits_lbl)
	credits_lbl.text = CREDITS
	credits_lbl.size = Vector2(hud.W, 400)
	credits_lbl.position = Vector2(0, 250)
	credits_lbl.visible = true
	play_sfx("bell_toll", null, -8.0, 0.6)
	if credits_music != null and credits_music.stream != null:
		credits_music.play()


func end_card_text() -> String:
	return hud.ov_title.text + " " + hud.ov_body.text


func _end_card_process(delta: float) -> void:
	end_t += delta
	# The sung main theme plays over the roll; the title loop steps aside.
	title_music.volume_db = lerpf(title_music.volume_db, -80.0, minf(1.0, delta))
	if end_t > 4.0 and credits_lbl != null:
		credits_lbl.position.y -= delta * 10.0
		var fadeout := clampf((end_t - 4.0) / 2.0, 0.0, 1.0)
		hud.ov_body.modulate.a = 1.0 - fadeout
		hud.ov_title.modulate.a = 1.0 - fadeout
	var finished := credits_lbl != null and credits_lbl.position.y < -credits_lbl.get_minimum_size().y
	if (Input.is_action_just_pressed("interact") and end_t > 1.0) or finished:
		Game.go_to_title()


# ---------------------------------------------------------------- title

func _title_opts() -> Array:
	var opts := ["NEW GAME"]
	if Game.has_save():
		opts.append("CONTINUE")
	opts.append("SETTINGS")
	return opts


func _title_body() -> String:
	var opts := _title_opts()
	var body := "\n\n\n\n\n"
	for i in opts.size():
		body += ("              > " if i == title_index else "                 ") + opts[i] + "\n"
	return body.strip_edges(false, true)


func _title_hint() -> String:
	return "%s select      Headphones recommended.      FREE DEMO" % Game.glyph("interact")


func _show_title() -> void:
	title_cam.make_current()
	_set_fog(Color(0.09, 0.03, 0.025), 0.11)
	hud.show_overlay("HARROW'S WAKE", _title_body(), Color(0.75, 0.12, 0.1), 0.25, _title_hint())
	hud.ov_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fade_in(2.5)


func _title_process(delta: float) -> void:
	title_cam.rotation.y += sin(Time.get_ticks_msec() / 3000.0) * 0.0004
	title_bell_t -= delta
	if title_bell_t <= 0.0:
		title_bell_t = randf_range(7.0, 11.0)
		play_sfx("bell_toll", null, -12.0, randf_range(0.55, 0.65))
		for lt in candle_lights:
			lt.light_energy = 0.2
	var opts := _title_opts()
	var n := opts.size()
	if Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("move_back"):
		title_index = (title_index + (1 if Input.is_action_just_pressed("move_back") else n - 1)) % n
		play_sfx("menu", null, -8.0)
		hud.show_overlay("HARROW'S WAKE", _title_body(), Color(0.75, 0.12, 0.1), 0.25, _title_hint())
	if Input.is_action_just_pressed("interact"):
		var choice: String = opts[title_index]
		if choice == "CONTINUE":
			Game.restart(true)
			return
		if choice == "SETTINGS":
			play_sfx("menu", null, -6.0)
			_open_settings(true)
			return
		hud.hide_overlay()
		Game.new_game()
		_apply_state()
		play_sfx("bell_toll", null, -6.0, 0.6)
		_show_note("intro")
	elif Input.is_action_just_pressed("continue_game") and Game.has_save():
		Game.restart(true)


func _announce() -> void:
	var who: String = Game.state["active"]
	show_message("- %s -\n%s" % [NAMES[who].to_upper(), PLACES[who]], 4.0)


func _show_note(key: String) -> void:
	var n: Array = NOTES[key]
	Game.mode = "note"
	if key != "intro":
		if not Game.state.has("files"):
			Game.state["files"] = []
		if not Game.state["files"].has(key):
			Game.state["files"].append(key)
		Game.set_flag("read_" + key)
	var body: String = n[1]
	if body.contains("%s"):
		body = body % Game.glyph("interact")
	# docs use the framed reader (wraps, scrolls, controls in the footer)
	hud.show_overlay(n[0], body, Color(0.86, 0.84, 0.78), 0.88, _note_hint(key == "intro"), true)
	play_sfx("pickup", null, -6.0)


func _note_hint(cont: bool = false) -> String:
	if cont:
		return "%s Continue" % Game.glyph("interact")
	return "%s / %s close" % [Game.glyph("interact"), Game.glyph("cancel")]


func _fade_in(secs: float) -> void:
	post_mat.set_shader_parameter("fade", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: post_mat.set_shader_parameter("fade", v), 1.0, 0.0, secs)


# ---------------------------------------------------------------- menus

func open_menu(title: String, header: String, options: Array, cb: Callable) -> void:
	menu_title = title
	menu_header = header
	menu_options = options
	menu_index = 0
	menu_cb = cb
	menu_desc = Callable()
	menu_adjust = Callable()
	menu_back = Callable()
	Game.mode = "menu"
	_render_menu()


func _render_menu() -> void:
	var body := menu_header + "\n\n" if menu_header != "" else ""
	var first := 0
	var last := menu_options.size()
	const WIN := 6
	if menu_options.size() > WIN + 1:
		first = clampi(menu_index - WIN / 2, 0, menu_options.size() - WIN)
		last = first + WIN
		if first > 0:
			body += "   ...\n"
	for i in range(first, last):
		body += ("> " if i == menu_index else "   ") + str(menu_options[i]) + "\n"
	if last < menu_options.size():
		body += "   ...\n"
	if menu_desc.is_valid():
		body += "\n" + str(menu_desc.call(menu_index)) + "\n"
	# controls go in the footer so a long menu can't push them off screen
	var hint := ("Left/Right change   %s toggle   %s back" if menu_adjust.is_valid() else "%s choose   %s back") % [Game.glyph("interact"), Game.glyph("cancel")]
	hud.show_overlay(menu_title, body.strip_edges(false, true), Color(0.86, 0.84, 0.78), 0.88, hint)
	hud.follow_line("> ")


func _close_menu() -> void:
	hud.hide_overlay()
	if Game.mode == "menu":
		Game.mode = "play"


func _other(who: String) -> String:
	return "jenny" if who == "dana" else "dana"


func current_objective() -> String:
	var f := func(n: String) -> bool: return Game.flag(n)
	if Game.has_item("jenny", "Tower Key"):
		return "Jenny: reach the Chapel and unlock its doors with the Tower Key."
	if Game.state["tube"]["jenny"].has("Tower Key"):
		return "Switch to Jenny (typewriter) and collect the Tower Key from the Mail Room tube."
	if Game.has_item("dana", "Tower Key"):
		return "Dana: send the Tower Key to Jenny through the Records Room mail tube."
	if f.call("power"):
		return "Dana: take the Tower Key from the Evidence Room."
	if Game.has_item("dana", "Fuse"):
		return "Dana: put the Fuse in the fuse box in the West Hall (beware the Tallow-folk)."
	if Game.state["tube"]["dana"].has("Fuse"):
		return "Switch to Dana (typewriter) and collect the Fuse from the Records Room tube."
	if Game.has_item("jenny", "Fuse"):
		return "Jenny: send the Fuse to the police station through the Mail Room tube."
	return "Jenny: find a fuse in the Playroom. Avoid the Bellman."


func _open_pause() -> void:
	var opts := ["Resume", "Items", "Settings", "Quit to title"]
	var hdr := "%s - %s\n\nCURRENT OBJECTIVE:\n%s" % [NAMES[Game.state["active"]], cur_room_name, current_objective()]
	open_menu("PAUSED", hdr, opts, func(i: int) -> void:
		match i:
			1:
				_open_inventory()
			2:
				_open_settings(false)
			3:
				Game.go_to_title()
			_:
				_close_menu()
	)


# ---------------------------------------------------------------- settings

const SETTING_ROWS := [
	["brightness", "Brightness", "float", 0.6, 1.8, 0.1],
	["master", "Master volume", "int", 0, 10, 1],
	["music", "Music volume", "int", 0, 10, 1],
	["sfx", "SFX volume", "int", 0, 10, 1],
	["tank", "Controls", "bool"],
	["invert_y", "Invert stick up/down", "bool"],
	["crt", "CRT scanlines", "bool"],
	["shadows", "Flashlight shadows", "bool"],
	["fps", "FPS counter", "bool"],
	["touch", "Touch controls", "bool"],
	["stick_sens", "Touch stick sensitivity", "float", 0.5, 2.0, 0.1],
	["btn_size", "Touch button size", "float", 0.7, 1.5, 0.1],
	["btn_opacity", "Touch button opacity", "float", 0.2, 1.0, 0.1],
	["doors", "Door animations", "bool"],
	["fullscreen", "Fullscreen (PC)", "bool"],
]


func _setting_label(row: Array) -> String:
	var v = Game.settings[row[0]]
	var txt := ""
	match row[2]:
		"bool":
			if row[0] == "tank":
				txt = "TANK (classic)" if v else "MODERN"
			else:
				txt = "ON" if v else "OFF"
		"int":
			txt = "%s%s" % ["|".repeat(int(v)), ".".repeat(10 - int(v))]
		"float":
			txt = "%.1f" % float(v)
	return "%s:  < %s >" % [row[1], txt]


func _settings_options() -> Array:
	var o: Array = []
	for row in SETTING_ROWS:
		o.append(_setting_label(row))
	o.append("Back")
	return o


func _adjust_setting(i: int, dir: int) -> void:
	if i >= SETTING_ROWS.size():
		return
	var row: Array = SETTING_ROWS[i]
	var k: String = row[0]
	match row[2]:
		"bool":
			Game.set_setting(k, not bool(Game.settings[k]))
		"int":
			Game.set_setting(k, clampi(int(Game.settings[k]) + dir * int(row[5]), int(row[3]), int(row[4])))
		"float":
			Game.set_setting(k, snappedf(clampf(float(Game.settings[k]) + dir * float(row[5]), float(row[3]), float(row[4])), 0.01))
	play_sfx("menu", null, -8.0, 1.1)
	menu_options = _settings_options()
	_render_menu()


func _open_settings(from_title: bool) -> void:
	settings_from_title = from_title
	var keep := menu_index if menu_title == "SETTINGS" else 0
	open_menu("SETTINGS", "", _settings_options(), func(i: int) -> void:
		if i >= SETTING_ROWS.size():
			_close_settings()
		else:
			_adjust_setting(i, 1)
	)
	menu_index = keep
	menu_adjust = _adjust_setting
	menu_back = _close_settings
	menu_desc = func(i: int) -> String:
		if i >= SETTING_ROWS.size():
			return "Settings are saved automatically."
		match SETTING_ROWS[i][0]:
			"brightness":
				return "Raise this if the rooms look too dark on your screen."
			"tank":
				return "Tank: up walks forward, left/right turn. Modern: move toward the stick."
			"shadows":
				return "Off is faster on phones (60 fps)."
			"invert_y":
				return "Swaps the stick's up and down for movement."
			"doors":
				return "The classic door-opening scene between rooms. %s skips it." % Game.glyph("interact")
			"fullscreen":
				return "PC and laptop only. F11 or Alt+Enter also toggles it."
		return ""
	_render_menu()


func _close_settings() -> void:
	if settings_from_title:
		settings_from_title = false
		Game.mode = "title"
		_show_title()
	else:
		_open_pause()
		menu_index = 2
		_render_menu()


func _apply_settings() -> void:
	if post_mat == null:
		return
	post_mat.set_shader_parameter("scanlines", 0.12 if Game.crt_on else 0.0)
	post_mat.set_shader_parameter("gamma", float(Game.settings["brightness"]))
	for who in players.keys():
		players[who].flashlight.shadow_enabled = bool(Game.settings["shadows"])
	if hud != null:
		hud.fps.visible = bool(Game.settings["fps"])
	if touch != null:
		touch.apply_settings()


func _open_typewriter() -> void:
	var who: String = Game.state["active"]
	var other := _other(who)
	play_sfx("typewriter", null, -6.0)
	open_menu("TYPEWRITER", "An old Smith-Corona. The keys are cold.", ["Save the game", "Switch to " + NAMES[other], "Leave"], func(i: int) -> void:
		match i:
			0:
				_sync_state()
				Game.save_game()
				_close_menu()
				play_sfx("typewriter")
				show_message("Progress saved. (%d)" % int(Game.state["saves"]))
			1:
				_close_menu()
				_switch_to(other)
			_:
				_close_menu()
	)


func _open_tube() -> void:
	var who: String = Game.state["active"]
	var other := _other(who)
	var box_in: Array = Game.state["tube"][who]
	var got: Array = []
	while not box_in.is_empty():
		var it: String = box_in.pop_front()
		Game.give(who, it)
		got.append(it)
	var header := "A brass canister rests in the tube's mouth." if got.is_empty() else "Received: " + ", ".join(got)
	if not got.is_empty():
		play_sfx("pickup")
	var opts: Array = []
	var items: Array = []
	for it in Game.state["inv"][who]:
		if it != "Handgun":
			opts.append("Send: " + it)
			items.append(it)
	opts.append("Leave")
	open_menu("MAIL TUBE", header + "\nIt leads to " + PLACES[other] + ".", opts, func(i: int) -> void:
		if i < items.size():
			var item: String = items[i]
			Game.take(who, item)
			Game.state["tube"][other].append(item)
			_close_menu()
			play_sfx("tube")
			show_message("The canister rattles away toward %s." % NAMES[other].split(" ")[0])
			tutorial("switch", "Use the typewriter to switch to %s and collect it." % NAMES[other].split(" ")[0])
		else:
			_close_menu()
	)


func _open_inventory() -> void:
	var who: String = Game.state["active"]
	var inv: Array = Game.state["inv"][who]
	var opts: Array = inv.duplicate()
	var files: Array = Game.state.get("files", [])
	opts.append("Files (%d)" % files.size())
	opts.append("Leave")
	var header := "%s   HP %d/%d" % [NAMES[who], int(Game.state["hp"][who]), MAX_HP[who]]
	if who == "dana":
		header += "   Handgun rounds: %d" % int(Game.state["ammo"])
	open_menu("ITEMS", header, opts, func(i: int) -> void:
		if i == inv.size():
			_open_files()
			return
		if i > inv.size():
			_close_menu()
			return
		var item: String = inv[i]
		match item:
			"Green Herb":
				_close_menu()
				Game.take(who, item)
				Game.state["hp"][who] = mini(MAX_HP[who], int(Game.state["hp"][who]) + 2)
				play_sfx("pickup")
				show_message("You feel a little better.")
			_:
				_close_menu()
				show_message(ITEM_INFO.get(item, item), 4.0)
	)
	menu_desc = func(i: int) -> String:
		if i < inv.size():
			return "-- " + str(ITEM_INFO.get(inv[i], inv[i]))
		if i == inv.size():
			return "-- Documents you've found. Read them again here."
		return ""
	_render_menu()


func _open_files() -> void:
	var files: Array = Game.state.get("files", [])
	var opts: Array = []
	for k in files:
		opts.append(NOTES[k][0])
	opts.append("Back")
	open_menu("FILES", "" if not files.is_empty() else "No documents yet.", opts, func(i: int) -> void:
		if i < files.size():
			_show_note(files[i])
		else:
			_open_inventory()
	)
	menu_back = _open_inventory


func _switch_to(other: String) -> void:
	_sync_state()
	var who: String = Game.state["active"]
	players[who].active = false
	Game.state["active"] = other
	players[other].active = true
	cur_cam_key = ""
	panic = 0.0
	_fade_in(1.4)
	_announce()
	_on_switch_scares(other)


func _sync_state() -> void:
	for who in ["dana", "jenny"]:
		var p = players[who]
		Game.state["pos"][who] = [p.global_position.x, p.global_position.y, p.global_position.z]
		Game.state["rot"][who] = p.rotation.y


# ---------------------------------------------------------------- interaction

func _find_near() -> Dictionary:
	var who: String = Game.state["active"]
	var p = players[who]
	var fwd: Vector3 = -p.global_transform.basis.z
	var best: Dictionary = {}
	var best_d := 1.6
	for it in interactables:
		if it["map"] != who:
			continue
		if it["kind"] == "door" and Game.flag("door_" + it["id"]):
			continue
		var pt: Vector3 = it["point"]
		var d := Vector2(pt.x - p.global_position.x, pt.z - p.global_position.z).length()
		if d > best_d:
			continue
		var to: Vector3 = it["pos"] - p.global_position
		to.y = 0.0
		if to.length() > 0.5 and rad_to_deg(fwd.angle_to(to.normalized())) > 80.0:
			continue
		best = it
		best_d = d
	return best


func _interact(it: Dictionary) -> void:
	var who: String = Game.state["active"]
	var p = players[who]
	match it["kind"]:
		"note":
			_show_note(it["id"])
		"item":
			interactables.erase(it)
			Game.set_flag("picked_" + it["id"])
			Game.give(who, it["label"])
			_pickup_flourish(it)
			play_sfx("pickup")
			p.act("PickUp_Table", 0.6)
			show_message("Picked up: " + it["label"])
			hud.item_get(it["label"], ITEM_INFO.get(it["label"], ""))
			if it["id"] == "fuse":
				_on_fuse_taken()
		"ammo":
			interactables.erase(it)
			Game.set_flag("picked_" + it["id"])
			_pickup_flourish(it)
			if who == "dana":
				Game.state["ammo"] = int(Game.state["ammo"]) + 6
			play_sfx("pickup")
			p.act("PickUp_Table", 0.6)
			show_message("Picked up: Handgun Ammo x6")
			hud.item_get("Handgun Ammo x6", "Six 9mm rounds.")
		"typewriter":
			if it["id"] == "tw_jenny" and Game.flag("typer_armed") and not Game.flag("typer_read"):
				Game.set_flag("typer_read")
				typer_t = 0.0
				_show_note("page_typed")
				return
			_open_typewriter()
		"tube":
			_open_tube()
		"phone":
			_answer_phone(it)
		"hide":
			p.hidden_in = it["id"]
			p.global_position = Vector3(it["point"].x, p.global_position.y, it["point"].z)
			p.visible = false
			p.breath = 1.0
			play_sfx("creak", p.global_position, -4.0)
			post_mat.set_shader_parameter("slit", 1.0)
			show_message("You squeeze inside and pull the doors almost shut.", 3.0)
			tutorial("hide", "%s to hold your breath when he's close. %s to leave." % [Game.glyph("breath"), Game.glyph("interact")])
			bellman.on_player_hide(p)
		"fusebox":
			if Game.flag("power"):
				show_message("The fuse box hums.")
			elif Game.has_item(who, "Fuse"):
				Game.take(who, "Fuse")
				Game.set_flag("power")
				Game.set_flag("door_evidence")
				if doors.has("evidence"):
					doors["evidence"].queue_free()
					doors.erase("evidence")
				var lt: OmniLight3D = room_lights["dana_%s" % [Vector2i(2, 0)]]
				lt.light_energy = light_base[lt]
				var lamp: MeshInstance3D = get_node_or_null("dana/fuse_lamp")
				if lamp != null:
					lamp.material_override = Lib.mat("plastered_wall_02", Color(0.2, 1.0, 0.3), false, 1.0, 2.0, 0.6)
				play_sfx("unlock")
				play_sfx("door", _off("dana", Vector2i(1, 0), Vector3(4, 1, 0)), 0.0)
				p.act("Interact", 0.8)
				show_message("You seat the fuse. Lights stutter on. Down the hall, a mag-lock clacks open.")
			else:
				show_message("The fuse box is missing a 30-amp fuse.")
		"door":
			if it["id"] == "evidence":
				show_message("EVIDENCE - the mag-lock is dead. No power.")
		"exit":
			if Game.has_item(who, "Tower Key"):
				play_sfx("unlock")
				play_sfx("door", null, 0.0, 0.8)
				_win()
			else:
				play_sfx("slam", it["pos"], -6.0)
				show_message("The chapel doors are chained shut. The padlock is stamped BELL TOWER.")


## The item lifts, spins fast and shrinks into a spark before it disappears.
func _pickup_flourish(it: Dictionary) -> void:
	if not it.has("node"):
		return
	var n: Node3D = it["node"]
	spin_nodes.erase(n)
	if not is_instance_valid(n):
		return
	var tw := create_tween()
	tw.tween_property(n, "position:y", n.position.y + 0.45, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation:y", n.rotation.y + TAU * 1.5, 0.45)
	tw.tween_property(n, "scale", Vector3.ONE * 0.05, 0.15)
	tw.tween_callback(n.queue_free)
	var sp := OmniLight3D.new()
	sp.light_color = Color(1.0, 0.9, 0.6)
	sp.light_energy = 1.5
	sp.omni_range = 2.5
	add_child(sp)
	sp.global_position = n.global_position + Vector3(0, 0.3, 0)
	var t2 := create_tween()
	t2.tween_property(sp, "light_energy", 0.0, 0.5)
	t2.tween_callback(sp.queue_free)


func _unhide(p) -> void:
	p.hidden_in = ""
	p.visible = true
	p.holding_breath = false
	post_mat.set_shader_parameter("slit", 0.0)
	hud.set_breath(-1.0)
	play_sfx("creak", p.global_position, -6.0, 1.2)


# ---------------------------------------------------------------- scares

func _build_scares() -> void:
	# The phone in the Chief's office (Dana), the music box (Jenny's playroom).
	phone_player = AudioStreamPlayer3D.new()
	phone_player.stream = sfx["phone"]
	phone_player.unit_size = 5.0
	phone_player.max_distance = 30.0
	phone_player.bus = &"SFX"
	add_child(phone_player)
	phone_player.global_position = _off("dana", Vector2i(1, -1), Vector3(-0.5, 1.0, -2.4))
	musicbox_player = AudioStreamPlayer3D.new()
	musicbox_player.stream = sfx["musicbox"]
	musicbox_player.unit_size = 3.0
	musicbox_player.max_distance = 25.0
	musicbox_player.bus = &"SFX"
	add_child(musicbox_player)
	musicbox_player.global_position = _off("jenny", Vector2i(1, -1), Vector3(0.5, 0.9, -0.6))
	var mb := part(get_node("jenny"), bmesh(Vector3(0.22, 0.14, 0.16)), musicbox_player.global_position - Vector3(0, 0.05, 0), "dark_wooden_planks", Color(0.7, 0.35, 0.3), 0.1)
	mb.name = "music_box"


func _scare_room_enter(who: String, room: String) -> void:
	if who == "jenny" and room == "Playroom" and not Game.flag("scare_musicbox"):
		Game.set_flag("scare_musicbox")
		musicbox_player.play()
		var lt: OmniLight3D = room_lights.get("jenny_%s" % [Vector2i(1, -1)])
		if lt:
			lt.light_energy = light_base.get(lt, 2.0) * 0.8
		var bear: Node3D = props.get("bear")
		if bear:
			var to: Vector3 = players["jenny"].global_position - bear.global_position
			var tw := create_tween()
			tw.tween_property(bear, "rotation:y", atan2(to.x, to.z), 0.08).set_delay(2.5)
		show_message("A music box starts to play. Nobody wound it.", 4.0)
	elif who == "dana" and room == "West Hall" and not Game.flag("scare_phone"):
		Game.set_flag("scare_phone")
		phone_player.play()
		var pit := {"map": "dana", "kind": "phone", "id": "phone", "pos": phone_player.global_position, "point": _off("dana", Vector2i(1, -1), Vector3(-0.5, 0, -1.6)), "label": "Answer the phone"}
		interactables.append(pit)
		create_tween().tween_callback(func() -> void:
			if phone_player.playing:
				phone_player.stop()
				interactables.erase(pit)).set_delay(30.0)
	elif who == "jenny" and room == "Corridor":
		tutorial("flashlight", "It's dark. %s toggles the flashlight." % Game.glyph("flashlight"))
	elif who == "dana" and room == "Records Room":
		tutorial("tube", "The mail tube sends items to the other survivor. Typewriters save and switch.")


func _answer_phone(it: Dictionary) -> void:
	phone_player.stop()
	interactables.erase(it)
	play_sfx("click")
	static_player.volume_db = -14.0
	Game.mode = "note"
	hud.show_overlay("The Phone", "Static. Then a child, very close to the receiver:\n\n\"Officer? He rings when he's hungry. When the bell stops, that's when he's near.\"\n\nBreathing. Then, faint and far away on the line - a hand bell.", Color(0.86, 0.84, 0.78), 0.88, "%s Hang up" % Game.glyph("interact"), true)
	create_tween().tween_callback(play_sfx.bind("bell", null, -16.0, 0.9)).set_delay(2.0)


func _on_fuse_taken() -> void:
	# Build -> release: the music box stops dead, and the bell answers.
	musicbox_player.stop()
	play_sfx("slam", _off("jenny", Vector2i(1, 0), Vector3(0, 1.5, 0)), 0.0)
	play_sfx("bell", _off("jenny", Vector2i(1, 0), Vector3(3, 2, 0)), 2.0)
	bellman.dormant_t = minf(bellman.dormant_t, 1.5)
	show_message("The music stops. Somewhere close, a bell.", 3.5)


func _on_switch_scares(to: String) -> void:
	if to == "jenny" and Game.flag("power") and not Game.flag("typer_armed"):
		Game.set_flag("typer_armed")
		typer_t = 8.0


func _intro_start() -> void:
	# Calm: Jenny wakes. A shape stands between the beds... the light dies... gone.
	Game.set_flag("intro_done")
	intro_t = 0.0
	players["jenny"].frozen = true
	phantom = Node3D.new()
	add_child(phantom)
	phantom.global_position = _off("jenny", Vector2i(0, 0), Vector3(-2.9, 0.0, 1.4))
	var pm := Node3D.new()
	pm.set_script(ActorScript)
	phantom.add_child(pm)
	pm.setup("bellman", phantom)
	pm.snap()
	pm.play_anim("Idle_Torch", 0.0, 0.3)
	phantom.look_at(players["jenny"].global_position, Vector3.UP)
	phantom.rotation.x = 0.0
	pm.snap()
	_fade_in(3.0)


func _intro_process(delta: float) -> void:
	if intro_t < 0.0:
		return
	var prev := intro_t
	intro_t += delta
	var lt: OmniLight3D = room_lights.get("jenny_%s" % [Vector2i(0, 0)])
	if prev < 1.0 and intro_t >= 1.0:
		play_sfx("bell_toll", null, -10.0, 0.6)
	if prev < 3.2 and intro_t >= 3.2:
		play_sfx("bell_toll", null, -8.0, 0.6)
	if intro_t > 3.6 and intro_t < 4.6 and lt:
		lt.light_energy = 0.05 if fmod(intro_t, 0.18) < 0.1 else 0.6
	if prev < 4.6 and intro_t >= 4.6:
		if lt:
			lt.light_energy = 0.0
		play_sfx("bulb_pop", lt.global_position if lt else null, -2.0)
	if prev < 5.4 and intro_t >= 5.4:
		if phantom:
			phantom.queue_free()
			phantom = null
		if lt:
			lt.light_energy = light_base.get(lt, 1.0) * 0.8
		play_sfx("bell_toll", null, -6.0, 0.6)
		show_message("...was someone there?", 3.0)
	if intro_t >= 6.0:
		intro_t = -1.0
		players["jenny"].frozen = false
		_announce()
		tutorial("move", "%s to move. %s to run - but running is loud. %s to examine." % ["Drag the left stick" if Game.input_kind == "touch" else ("Left stick" if Game.input_kind == "gamepad" else "WASD"), Game.glyph("run"), Game.glyph("interact")])


func _kill_lights_near(pos: Vector3, pop: bool) -> void:
	for lt in light_base.keys():
		if is_instance_valid(lt) and lt.global_position.distance_to(pos) < 7.0 and lt.light_energy > 0.1:
			if pop:
				play_sfx("bulb_pop", lt.global_position, -2.0)
			lt.light_energy = 0.05


func _scare_process(delta: float) -> void:
	var who: String = Game.state["active"]
	# The typewriter in the Mail Room types by itself.
	if typer_t > 0.0 and who == "jenny":
		typer_t -= delta
		if randf() < delta * 9.0:
			play_sfx("typewriter", _off("jenny", Vector2i(1, 1), Vector3(2.4, 1.0, 2.9)), -2.0, randf_range(1.2, 1.7), 20.0)
		if typer_t <= 0.0 and not Game.flag("typer_read"):
			typer_t = 3.0
	# Lights die as the Bellman nears (and come back when he's gone).
	if who == "jenny" and bellman != null:
		var bp: Vector3 = bellman.global_position
		for lt in light_base.keys():
			if not is_instance_valid(lt) or lt.global_position.x < 60.0 or lt in candle_lights:
				continue
			var d: float = Vector2(lt.global_position.x - bp.x, lt.global_position.z - bp.z).length()
			if d < 6.0 and bellman.state != bellman.S.DORMANT:
				lt.light_energy = light_base[lt] * (0.08 if randf() < 0.35 else 0.3)
			elif lt.light_energy < light_base[lt] * 0.95 and not (lt in flicker_lights) and intro_t < 0.0:
				lt.light_energy = move_toward(lt.light_energy, light_base[lt], delta * 0.4)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	for n in spin_nodes:
		if is_instance_valid(n):
			n.rotation.y += delta * 2.0
			var g: Node3D = n.get_child(0) if n.get_child_count() > 0 else null
			if g:
				g.scale = Vector3.ONE * (0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 400.0)))
	flick_t -= delta
	if flick_t <= 0.0:
		flick_t = randf_range(0.05, 0.4)
		for lt in flicker_lights:
			var base: float = light_base.get(lt, 1.0)
			lt.light_energy = base if randf() > 0.18 else base * 0.12
	for lt in candle_lights:
		lt.light_energy = lerpf(lt.light_energy, light_base[lt] * randf_range(0.7, 1.15), 0.3)
	fire_cd = maxf(0.0, fire_cd - delta)
	door_cool = maxf(0.0, door_cool - delta)

	match Game.mode:
		"title":
			_title_process(delta)
		"note":
			var sc := Input.get_axis("move_forward", "move_back")
			if absf(sc) > 0.2:
				hud.scroll_overlay(sc * 140.0 * delta)
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("cancel"):
				hud.hide_overlay()
				Game.mode = "play"
				static_player.volume_db = -80.0
				if not Game.flag("intro_done") and Game.state["active"] == "jenny" and players["jenny"].global_position.distance_to(_off("jenny", Vector2i(0, 0), Vector3(-1.0, 0.05, 0.5))) < 1.0:
					_intro_start()
				elif cur_cam_key == "":
					_announce()
		"menu":
			if Input.is_action_just_pressed("move_forward"):
				menu_index = (menu_index - 1 + menu_options.size()) % menu_options.size()
				play_sfx("menu", null, -8.0)
				_render_menu()
			elif Input.is_action_just_pressed("move_back"):
				menu_index = (menu_index + 1) % menu_options.size()
				play_sfx("menu", null, -8.0)
				_render_menu()
			elif menu_adjust.is_valid() and (Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right")):
				menu_adjust.call(menu_index, -1 if Input.is_action_just_pressed("move_left") else 1)
			elif Input.is_action_just_pressed("interact"):
				play_sfx("menu", null, -4.0, 1.3)
				menu_cb.call(menu_index)
			elif Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("inventory") or (menu_title == "PAUSED" and Input.is_action_just_pressed("pause")):
				if menu_back.is_valid():
					menu_back.call()
				else:
					_close_menu()
		"struggle":
			struggle_t -= delta
			shake = maxf(shake, 0.3)
			distort = maxf(distort, 0.4)
			if Input.is_action_just_pressed("interact"):
				struggle_count += 1
				play_sfx("hurt", null, -12.0, randf_range(1.2, 1.4))
			if struggle_count >= struggle_need:
				_end_struggle(true)
			elif struggle_t <= 0.0:
				_end_struggle(false)
			else:
				_update_struggle()
		"dead":
			if Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("move_back"):
				dead_index = (dead_index + 1) % 2
				play_sfx("menu", null, -8.0)
				_render_death()
			elif Input.is_action_just_pressed("interact") and hud.overlay.visible:
				death_choose(dead_index)
		"win":
			if Input.is_action_just_pressed("interact"):
				_show_end_card()
		"endcard":
			_end_card_process(delta)
		"door":
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("cancel"):
				_door_finish()
		"play":
			_play_process(delta)
	_intro_process(delta)
	var in_title: bool = Game.mode == "title" or (Game.mode == "menu" and settings_from_title)
	if not in_title:
		_update_camera()
	_update_audio_and_fx(delta)
	var who: String = Game.state["active"]
	hud.set_hud_visible(not in_title and Game.mode != "endcard" and Game.mode != "door")
	hud.update_status(who, int(Game.state["hp"][who]), MAX_HP[who], int(Game.state["ammo"]), players[who].stamina, panic, who == "jenny" and not in_title and Game.mode != "endcard" and Game.mode != "door")


func _play_process(delta: float) -> void:
	Game.state["time"] = float(Game.state["time"]) + delta
	var who: String = Game.state["active"]
	var p = players[who]
	_scare_process(delta)
	if Input.is_action_just_pressed("toggle_controls"):
		Game.set_setting("tank", not Game.tank_controls)
		show_message("Controls: " + ("TANK (classic)" if Game.tank_controls else "MODERN (camera-relative)"))
	if Input.is_action_just_pressed("toggle_crt"):
		Game.set_setting("crt", not Game.crt_on)
	if Input.is_action_just_pressed("pause") and intro_t < 0.0:
		_open_pause()
		return
	if p.hidden_in != "":
		_hidden_process(p, delta)
		return
	near = _find_near()
	hud.prompt.text = ("%s %s" % [Game.glyph("interact"), near["label"]]) if not near.is_empty() else ""
	if not near.is_empty() and near["kind"] == "hide":
		tutorial("hide_spot", "Wardrobes and closets hide you - if he didn't see you get in.")
	if Input.is_action_just_pressed("interact") and not near.is_empty() and not p.aiming and not p.frozen:
		_interact(near)
	elif Input.is_action_just_pressed("inventory") and not p.frozen:
		_open_inventory()


func _hidden_process(p, delta: float) -> void:
	# Hiding: peer through the gap. Hold your breath when he's close -
	# but not too long, or you'll gasp.
	hud.prompt.text = "%s Leave    %s Hold breath" % [Game.glyph("interact"), Game.glyph("breath")]
	p.holding_breath = Input.is_action_pressed("run") and p.breath > 0.0
	if p.holding_breath:
		p.breath = maxf(0.0, p.breath - delta / 6.0)
		if p.breath <= 0.0:
			p.holding_breath = false
			play_sfx("breath", p.global_position, 4.0, 1.1)
			show_message("Jenny gasps for air!", 2.0)
			make_noise(p.global_position, 7.0)
			if bellman.global_position.distance_to(p.global_position) < 3.0 and bellman.state != bellman.S.STUNNED:
				bellman.on_scream()
			p.breath = -0.4   # needs a moment before she can hold it again
	else:
		p.breath = minf(1.0, p.breath + delta / 4.0)
		hide_noise_t -= delta
		var d: float = bellman.global_position.distance_to(p.global_position)
		if d < 7.0 and hide_noise_t <= 0.0 and p.breath > 0.0:
			hide_noise_t = 1.6
			play_sfx("breath", p.global_position, -14.0 + (7.0 - d) * 1.5, 1.0)
	hud.set_breath(clampf(p.breath, 0.0, 1.0))
	if Input.is_action_just_pressed("interact"):
		_unhide(p)


func _set_fog(col: Color, density: float, ambient: float = 0.95) -> void:
	var tw := create_tween()
	tw.tween_property(env, "fog_light_color", col, 0.6)
	tw.parallel().tween_property(env, "fog_density", density, 0.6)
	tw.parallel().tween_property(env, "ambient_light_energy", ambient, 0.6)


func _update_camera() -> void:
	var who: String = Game.state["active"]
	var c := cell_of(who, players[who].global_position)
	var key := "%s_%s" % [who, c]
	if key != cur_cam_key and cameras[who].has(c):
		var first := cur_cam_key == ""
		cur_cam_key = key
		cameras[who][c].make_current()
		var r: Dictionary = MAPS[who]["rooms"][c]
		cur_room_name = r["name"]
		_set_fog(r["fog"], r.get("fog_d", 0.09 if not r.get("safe", false) else 0.06), r.get("ambient", 0.95))
		_update_lights(who, c)
		var amb: String = r.get("amb", MAPS[who]["amb"])
		if amb != cur_amb:
			cur_amb = amb
			amb_player.stream = _loop_stream(amb)
			amb_player.play()
		for mk in map_roots.keys():
			map_roots[mk].visible = mk == who   # draw only the active survivor's building
		if not first and _doors_on() and Game.mode == "play" and door_cool <= 0.0 and players[who].hidden_in == "":
			_door_sequence(r)
		elif not first:
			# quick fade through black with a creak (door scenes off, or walked straight back)
			door_t = 0.45
			post_mat.set_shader_parameter("fade", 1.0)
			var tw := create_tween()
			tw.tween_interval(0.12)
			tw.tween_method(func(v: float) -> void: post_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.33)
			play_sfx("creak", players[who].global_position, -10.0, randf_range(0.85, 1.05))
			play_sfx("door", players[who].global_position, -16.0, randf_range(0.9, 1.1))
		_scare_room_enter(who, cur_room_name)
	# camera shake
	var cam: Camera3D = cameras[who].get(c)
	if cam != null and cam.has_meta("base"):
		var b: Transform3D = cam.get_meta("base")
		if shake > 0.01:
			cam.transform = b.translated_local(Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.08)
		else:
			cam.transform = b


# ---------------------------------------------------------------- door scene
## RE-style room change: black, a door creaks open as the camera pushes
## through, black, new room. ~1.5 s, skippable, can be turned off in Settings.
## 2 s cooldown so it doesn't replay if you step straight back.

const DOOR_STAGE := Vector3(0, -200, 0)
const DOOR_SECS := 1.5
var door_stage: Node3D = null
var door_cam: Camera3D = null
var door_hinge: Node3D = null
var door_far: OmniLight3D = null
var door_tweens: Array = []
var door_cool: float = 0.0


func _doors_on() -> bool:
	return bool(Game.settings.get("doors", true))


func _build_door_stage() -> void:
	door_stage = Node3D.new()
	door_stage.name = "door_stage"
	add_child(door_stage)
	door_stage.position = DOOR_STAGE
	var wcol := Color(0.5, 0.45, 0.4)
	var frame_col := Color(0.38, 0.28, 0.22)
	box(door_stage, Vector3(8.0, 0.1, 8.0), Vector3(0, -0.05, 0), "old_wood_floor", Color(0.7, 0.6, 0.5), 1, false, 0.0, 0.45)
	box(door_stage, Vector3(3.0, 2.2, 0.25), Vector3(-2.05, 2.1, 0), "decrepit_wallpaper", wcol, 1, false)
	box(door_stage, Vector3(3.0, 2.2, 0.25), Vector3(2.05, 2.1, 0), "decrepit_wallpaper", wcol, 1, false)
	box(door_stage, Vector3(1.2, 1.0, 0.25), Vector3(0, 2.7, 0), "decrepit_wallpaper", wcol, 1, false)
	box(door_stage, Vector3(3.0, 1.0, 0.27), Vector3(-2.05, 0.5, 0), "dark_wooden_planks", Color(0.55, 0.42, 0.34), 1, false, 0.0, 0.6)
	box(door_stage, Vector3(3.0, 1.0, 0.27), Vector3(2.05, 0.5, 0), "dark_wooden_planks", Color(0.55, 0.42, 0.34), 1, false, 0.0, 0.6)
	for x in [-0.6, 0.6]:
		box(door_stage, Vector3(0.12, 2.25, 0.34), Vector3(x, 1.12, 0), "dark_wooden_planks", frame_col, 1, false)
	box(door_stage, Vector3(1.32, 0.12, 0.34), Vector3(0, 2.26, 0), "dark_wooden_planks", frame_col, 1, false)
	door_hinge = Node3D.new()
	door_stage.add_child(door_hinge)
	door_hinge.position = Vector3(-0.54, 0, 0)
	var panel := part(door_hinge, bmesh(Vector3(1.08, 2.18, 0.07)), Vector3(0.54, 1.09, 0), "dark_wooden_planks", Color(0.55, 0.4, 0.3))
	for y in [0.55, 1.6]:
		part(panel, bmesh(Vector3(0.8, 0.6, 0.02)), Vector3(0, y - 1.09, 0.045), "dark_wooden_planks", Color(0.42, 0.3, 0.22))
	var knob := part(panel, cyl(0.035, 0.035, 0.1, 6), Vector3(0.4, -0.1, 0.07), "rusty_metal_02", Color(0.85, 0.7, 0.4), 0.3)
	knob.rotation.x = PI / 2.0
	var near_lt := OmniLight3D.new()
	near_lt.light_color = Color(1.0, 0.85, 0.6)
	near_lt.light_energy = 1.6
	near_lt.omni_range = 5.0
	door_stage.add_child(near_lt)
	near_lt.position = Vector3(0.6, 2.4, 1.7)
	door_far = OmniLight3D.new()
	door_far.light_energy = 2.2
	door_far.omni_range = 5.0
	door_stage.add_child(door_far)
	door_far.position = Vector3(0.3, 1.8, -2.4)
	door_cam = Camera3D.new()
	door_cam.fov = 55.0
	door_cam.far = 20.0
	door_stage.add_child(door_cam)
	door_stage.visible = false


func _door_sequence(to_room: Dictionary) -> void:
	Game.mode = "door"
	door_stage.visible = true
	door_hinge.rotation.y = 0.0
	door_far.light_color = to_room.get("light", Color(1, 0.9, 0.7))
	door_cam.look_at_from_position(DOOR_STAGE + Vector3(0.1, 1.55, 3.3), DOOR_STAGE + Vector3(0, 1.2, 0), Vector3.UP)
	door_cam.make_current()
	post_mat.set_shader_parameter("fade", 1.0)
	play_sfx("door", null, -8.0, randf_range(0.9, 1.05))
	var t1 := create_tween()
	t1.tween_interval(0.3)
	t1.tween_callback(play_sfx.bind("creak", null, -4.0, randf_range(0.8, 0.95)))
	t1.tween_property(door_hinge, "rotation:y", 1.85, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var t2 := create_tween()
	t2.tween_property(door_cam, "position:z", 0.9, DOOR_SECS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var t3 := create_tween()
	t3.tween_method(_set_fade, 1.0, 0.0, 0.2)
	t3.tween_interval(DOOR_SECS - 0.45)
	t3.tween_method(_set_fade, 0.0, 1.0, 0.25)
	t3.tween_callback(_door_finish)
	door_tweens = [t1, t2, t3]


func _set_fade(v: float) -> void:
	post_mat.set_shader_parameter("fade", v)


func _door_finish() -> void:
	for tw in door_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	door_tweens = []
	if door_stage == null or not door_stage.visible:
		return
	door_stage.visible = false
	door_cool = 2.0
	if Game.mode == "door":
		Game.mode = "play"
	var who: String = Game.state["active"]
	var c := cell_of(who, players[who].global_position)
	if cameras[who].has(c):
		cameras[who][c].make_current()
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, 0.25)


var _stream_cache: Dictionary = {}


func _loop_stream(n: String) -> AudioStream:
	if _stream_cache.has(n):
		return _stream_cache[n]
	var st: AudioStream = _load_sfx(n)
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		st.loop = true
	_stream_cache[n] = st
	return st


func _update_audio_and_fx(delta: float) -> void:
	var who: String = Game.state["active"]
	var p = players[who]
	shake = move_toward(shake, 0.0, delta * 1.5)
	distort = move_toward(distort, 0.0, delta * 1.2)
	post_mat.set_shader_parameter("distort", distort)
	# Music & ambience mix.
	var is_title: bool = Game.mode == "title" or (Game.mode == "menu" and settings_from_title)
	if Game.mode != "endcard":
		title_music.volume_db = lerpf(title_music.volume_db, -10.0 if is_title else -80.0, minf(1.0, delta * 1.5))
	var rain: AudioStreamPlayer = get_node("rain")
	var credits: bool = Game.mode == "endcard"   # the sung theme plays alone over the credits
	rain.volume_db = lerpf(rain.volume_db, -14.0 if is_title else (-30.0 if credits else -32.0), minf(1.0, delta * 1.5))
	amb_player.volume_db = lerpf(amb_player.volume_db, -80.0 if (is_title or credits) else -12.0, minf(1.0, delta * 1.0))
	amb2_player.volume_db = -80.0
	# Radio static near monsters (Dana's police radio).
	var target_db: float = -80.0 if Game.mode != "note" else static_player.volume_db
	if who == "dana" and Game.mode == "play":
		for z in zombies:
			if z.dead:
				continue
			var d: float = z.global_position.distance_to(p.global_position)
			if d < 13.0:
				target_db = maxf(target_db, lerpf(-34.0, -9.0, 1.0 - d / 13.0))
	static_player.volume_db = lerpf(static_player.volume_db, target_db, minf(1.0, delta * 6.0))
	# silent loops still hold a Vorbis decoder each, so pause them (phones)
	for ap in [title_music, static_player, amb_player, amb2_player, rain]:
		ap.stream_paused = ap.volume_db <= -79.0

	# Panic (Jenny).
	if who == "jenny" and Game.mode == "play":
		var d2: float = bellman.global_position.distance_to(p.global_position)
		if p.hidden_in != "":
			if d2 < 5.5 and bellman.state != bellman.S.STUNNED:
				panic += (2.5 if p.holding_breath else 9.0) * delta
				if panic >= 100.0:
					_unhide(p)
					bellman.on_scream()
					panic = 85.0
					play_sfx("scream", null, 0.0)
					distort = 1.0
					show_message("Jenny can't hold it in - she SCREAMS!")
			else:
				panic -= 5.0 * delta
		elif bellman.is_hunting():
			panic += 12.0 * delta
		elif d2 < 10.0:
			panic += (10.0 - d2) * 1.6 * delta
		else:
			panic -= 7.0 * delta
		panic = clampf(panic, 0.0, 100.0)
		# The flashlight sputters when he's close.
		if p.light_on and d2 < 6.0 and bellman.state != bellman.S.DORMANT:
			p.flashlight.light_energy = 3.2 if randf() > 0.25 else 0.3
		else:
			p.flashlight.light_energy = 3.2
	elif who != "jenny":
		panic = maxf(0.0, panic - 20.0 * delta)
	post_mat.set_shader_parameter("panic", maxf(0.0, (panic - 35.0) / 65.0))
	# Heartbeat rises with panic; louder in hiding.
	if panic > 30.0 and (Game.mode == "play" or Game.mode == "struggle"):
		heart_t -= delta
		if heart_t <= 0.0:
			var k := (panic - 30.0) / 70.0
			heart_t = lerpf(1.2, 0.45, k)
			var vol := lerpf(-18.0, -3.0, k) + (3.0 if p.hidden_in != "" else 0.0)
			play_sfx("heart", null, vol, lerpf(0.9, 1.15, k))
