extends Node3D
## Harrow's Wake - vertical slice.
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
const BellmanScript := preload("res://scripts/bellman.gd")
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
			Vector2i(1, -1): {"name": "Chief's Office", "floor": "dirty_carpet", "fcol": Color(0.85, 0.55, 0.42), "wall": "decrepit_wallpaper", "wcol": Color(0.6, 0.5, 0.42), "step": "carpet", "light": Color(1.0, 0.72, 0.45), "fog": Color(0.06, 0.04, 0.03), "cam": 2},
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
			Vector2i(1, -1): {"name": "Playroom", "floor": "dirty_carpet", "fcol": Color(0.85, 0.62, 0.78), "wall": "decrepit_wallpaper", "wcol": Color(0.65, 0.5, 0.6), "step": "carpet", "light": Color(0.8, 0.65, 0.95), "fog": Color(0.05, 0.03, 0.07), "cam": 1},
		},
		"links": [[Vector2i(0, 0), Vector2i(1, 0), ""], [Vector2i(1, 0), Vector2i(2, 0), ""], [Vector2i(1, 0), Vector2i(1, 1), ""], [Vector2i(1, 0), Vector2i(1, -1), ""]],
	},
}

var NOTES := {
	"intro": ["October 31, 1998", "Harrow's Wake, Maine.\n\nAt 11:52 PM the bell above the Meridian Biotech site rang by itself. Everyone who heard it changed. The fog came down and never lifted.\n\nTwo survivors are still breathing on opposite ends of town. If they ever meet, the Choir Stone's resonance kills them both.\n\nThe town's old pneumatic mail tubes still work.\n\n%s Continue"],
	"note_toll": ["Dispatch Memo", "Oct 31, 11:52 PM.\nMultiple calls: the Meridian bell is ringing on its own. Callers report 'singing' coming up through the storm drains. Two callers say their husbands 'went soft, like candle wax.'\nAll units to Bell Street.\n- Dispatch"],
	"note_chief": ["Chief's Log", "Meridian's people sealed the lab and left us the town.\n\nThe old mail tubes still run from our Records Room to St. Agnes Orphanage on Hill Road. If anyone's alive up there, that's how we reach them.\n\nThe evidence room's mag-lock blew its fuse. Spares went up to the orphanage with the Christmas lights last year. Of course they did.\n- Chief Harlan"],
	"note_jenny": ["Torn Diary Page", "If you find this, I'm hiding.\n\nThe tall man with the bell walks the halls. Don't run near him. He HEARS you. Don't shine a light at him either.\n\nThe wardrobes are safe if he didn't see you get in. Hold your breath in there, but not too long.\n\nHe never comes into the Mail Room. The tube there goes all the way to the police station.\n- J."],
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


func _ready() -> void:
	randomize()
	_build_sfx()
	_build_environment()
	for m in MAPS.keys():
		_build_map(m)
	_build_interactables()
	_build_players()
	_build_enemies()
	_build_scares()
	_build_ui()
	_apply_state()
	if "--smoke" in OS.get_cmdline_user_args():
		add_child(load("res://tests/smoke.gd").new())
	if "--flow" in OS.get_cmdline_user_args():
		add_child(load("res://tests/flow.gd").new())
	if "--shots" in OS.get_cmdline_user_args():
		add_child(load("res://tests/shots.gd").new())
	if Game.skip_title:
		Game.skip_title = false
		Game.mode = "play"
		_fade_in(1.2)
		_announce()
	else:
		Game.mode = "title"
		_show_title()


# ---------------------------------------------------------------- building

func box(parent: Node3D, size: Vector3, pos: Vector3, texname: String, col: Color, layer: int = 1, collide: bool = true, emission: float = 0.0, wscale: float = 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	# Subdivide big faces (~1 m) so PS1 affine warping wobbles instead of tearing.
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


func _add_light(root: Node3D, key: String, pos: Vector3, col: Color, energy: float, rng: float, flicker: bool = false) -> OmniLight3D:
	var lt := OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = energy
	lt.omni_range = rng
	lt.omni_attenuation = 1.4
	lt.position = pos
	root.add_child(lt)
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
		var energy := 1.7
		var lt := _add_light(root, "%s_%s" % [map, c], ctr + Vector3(0, 2.45, 0), r["light"], energy, 10.5, r.get("flicker", false))
		if r.get("needs_power", false) and not Game.flag("power"):
			lt.light_energy = 0.08
		# fixed camera
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


func _wall_segment(root: Node3D, size: Vector3, center: Vector3, r: Dictionary, along_x: bool) -> void:
	# Plaster/wallpaper above, dark wood wainscot below, like a 1950s institution.
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
		_p(root, map, E, "desk", Vector3(-2.8, 0, -2.6), PI / 2.0, 1.4)
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
		_p(root, map, R, "cardboardBoxClosed", Vector3(2.8, 0, -3.3), 0.3, 0.7)
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
		_p(root, map, M, "table", Vector3(-0.8, 0, -1.5), 0.2, 1.5)
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
			p.walk_speed = 2.1
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

	var b := CharacterBody3D.new()
	b.set_script(BellmanScript)
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

func play_sfx(sname: String, pos = null, vol: float = 0.0, pitch: float = 1.0, max_dist: float = 35.0) -> void:
	if not sfx.has(sname) or sfx[sname] == null:
		return
	if pos == null:
		var a := AudioStreamPlayer.new()
		a.stream = sfx[sname]
		a.volume_db = vol
		a.pitch_scale = pitch
		add_child(a)
		a.finished.connect(a.queue_free)
		a.play()
	else:
		var a3 := AudioStreamPlayer3D.new()
		a3.stream = sfx[sname]
		a3.volume_db = vol
		a3.pitch_scale = pitch
		a3.unit_size = 4.0
		a3.max_distance = max_dist
		add_child(a3)
		a3.global_position = pos
		a3.finished.connect(a3.queue_free)
		a3.play()


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


func next_waypoint(map: String, from: Vector3, to: Vector3, blocked: Array) -> Vector3:
	var rooms: Dictionary = MAPS[map]["rooms"]
	var a := cell_of(map, from)
	var b := cell_of(map, to)
	if a == b or not rooms.has(a) or not rooms.has(b):
		return to
	var prev := {a: a}
	var q: Array = [a]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == b:
			break
		for l in MAPS[map]["links"]:
			if l[2] != "" and not Game.flag("door_" + l[2]):
				continue
			var n := Vector2i(9999, 9999)
			if l[0] == c:
				n = l[1]
			elif l[1] == c:
				n = l[0]
			if n.x == 9999 or prev.has(n) or blocked.has(n):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(b):
		return from
	var step: Vector2i = b
	while prev[step] != a:
		step = prev[step]
	var door := (cell_center(map, a) + cell_center(map, step)) / 2.0
	if Vector2(door.x - from.x, door.z - from.z).length() < 0.9:
		return cell_center(map, step)
	return door


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
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.85, 0.5)
	fl.light_energy = 5.0
	fl.omni_range = 7.0
	add_child(fl)
	fl.global_position = p.global_position + Vector3(0, 1.3, 0) - p.global_transform.basis.z * 0.6
	get_tree().create_timer(0.06).timeout.connect(fl.queue_free)
	if target != null:
		target.hit(1)


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
	struggle_need = int(7.0 + panic / 10.0 * difficulty)
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
	var body := reason + "\n\n"
	body += ("%s Continue from last save" if Game.has_save() else "%s Try again") % Game.glyph("interact")
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: post_mat.set_shader_parameter("fade", v), 0.0, 0.6, 1.5)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if Game.mode == "dead":
			hud.show_overlay("YOU DIED", body, Color(0.8, 0.05, 0.05), 0.6))


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
	var body := "Jenny slips the Tower Key into the padlock. The chain falls. Outside, the fog is moving like breath.\n\nSomewhere above the town, the bell starts to ring again.\n\nTIME  %02d:%02d\nSAVES  %d\nRANK  %s\n\nEND OF VERTICAL SLICE - thank you for playing.\n%s Play again" % [int(secs) / 60, int(secs) % 60, saves, rank, Game.glyph("interact")]
	play_sfx("bell_toll", null, -6.0, 0.7)
	hud.show_overlay("HARROW'S WAKE", body, Color(0.85, 0.7, 0.35))


# ---------------------------------------------------------------- title

func _title_body() -> String:
	var opts := ["NEW GAME"]
	if Game.has_save():
		opts.append("CONTINUE")
	var body := "\n\n\n\n\n\n"
	for i in opts.size():
		body += ("              > " if i == title_index else "                 ") + opts[i] + "\n"
	body += "\n\n      %s select      Headphones recommended." % Game.glyph("interact")
	return body


func _show_title() -> void:
	title_cam.make_current()
	_set_fog(Color(0.09, 0.03, 0.025), 0.11)
	hud.show_overlay("HARROW'S WAKE", _title_body(), Color(0.75, 0.12, 0.1), 0.25)
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
	var n := 2 if Game.has_save() else 1
	if Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("move_back"):
		title_index = (title_index + 1) % n
		play_sfx("menu", null, -8.0)
		hud.show_overlay("HARROW'S WAKE", _title_body(), Color(0.75, 0.12, 0.1), 0.25)
	if Input.is_action_just_pressed("interact"):
		if title_index == 1:
			Game.restart(true)
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
	var body: String = n[1]
	if body.contains("%s"):
		body = body % Game.glyph("interact")
	hud.show_overlay(n[0], body)
	play_sfx("pickup", null, -6.0)


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
	Game.mode = "menu"
	_render_menu()


func _render_menu() -> void:
	var body := menu_header + "\n\n" if menu_header != "" else ""
	for i in menu_options.size():
		body += ("> " if i == menu_index else "   ") + str(menu_options[i]) + "\n"
	body += "\n%s choose   %s back" % [Game.glyph("interact"), Game.glyph("cancel")]
	hud.show_overlay(menu_title, body)


func _close_menu() -> void:
	hud.hide_overlay()
	if Game.mode == "menu":
		Game.mode = "play"


func _other(who: String) -> String:
	return "jenny" if who == "dana" else "dana"


func _open_pause() -> void:
	var opts := ["Resume", "Controls: %s" % ("TANK (classic)" if Game.tank_controls else "MODERN (camera-relative)"), "CRT scanlines: %s" % ("ON" if Game.crt_on else "OFF"), "Touch controls: %s" % ("ON" if touch.visible else "OFF"), "Quit to title"]
	open_menu("PAUSED", "%s - %s" % [NAMES[Game.state["active"]], cur_room_name], opts, func(i: int) -> void:
		match i:
			1:
				Game.tank_controls = not Game.tank_controls
				_open_pause()
				menu_index = 1
				_render_menu()
			2:
				Game.crt_on = not Game.crt_on
				post_mat.set_shader_parameter("scanlines", 0.12 if Game.crt_on else 0.0)
				_open_pause()
				menu_index = 2
				_render_menu()
			3:
				touch.visible = not touch.visible
				_open_pause()
				menu_index = 3
				_render_menu()
			4:
				Game.mode = "title"
				Game.skip_title = false
				get_tree().reload_current_scene()
			_:
				_close_menu()
	)


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
	opts.append("Leave")
	var header := "%s   HP %d/%d" % [NAMES[who], int(Game.state["hp"][who]), MAX_HP[who]]
	if who == "dana":
		header += "   Handgun rounds: %d" % int(Game.state["ammo"])
	open_menu("ITEMS", header, opts, func(i: int) -> void:
		if i >= inv.size():
			_close_menu()
			return
		var item: String = inv[i]
		_close_menu()
		match item:
			"Green Herb":
				Game.take(who, item)
				Game.state["hp"][who] = mini(MAX_HP[who], int(Game.state["hp"][who]) + 2)
				play_sfx("pickup")
				show_message("You feel a little better.")
			"Handgun":
				show_message("Service pistol, 9mm. %s to aim, %s to fire." % [Game.glyph("aim"), Game.glyph("fire")])
			"Fuse":
				show_message("A 30-amp cartridge fuse wrapped in Christmas tinsel.")
			"Tower Key":
				show_message("A heavy iron key on a tag: BELL TOWER - ST. AGNES.")
			_:
				show_message(item)
	)


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
			if it.has("node"):
				spin_nodes.erase(it["node"])
				it["node"].queue_free()
			play_sfx("pickup")
			p.act("PickUp_Table", 0.6)
			show_message("Picked up: " + it["label"])
			if it["id"] == "fuse":
				_on_fuse_taken()
		"ammo":
			interactables.erase(it)
			Game.set_flag("picked_" + it["id"])
			if it.has("node"):
				spin_nodes.erase(it["node"])
				it["node"].queue_free()
			if who == "dana":
				Game.state["ammo"] = int(Game.state["ammo"]) + 6
			play_sfx("pickup")
			p.act("PickUp_Table", 0.6)
			show_message("Picked up: Handgun Ammo x6")
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
	add_child(phone_player)
	phone_player.global_position = _off("dana", Vector2i(1, -1), Vector3(-0.5, 1.0, -2.4))
	musicbox_player = AudioStreamPlayer3D.new()
	musicbox_player.stream = sfx["musicbox"]
	musicbox_player.unit_size = 3.0
	musicbox_player.max_distance = 25.0
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
			lt.light_energy = 0.45
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
		get_tree().create_timer(30.0).timeout.connect(func() -> void:
			if phone_player.playing:
				phone_player.stop()
				interactables.erase(pit))
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
	hud.show_overlay("The Phone", "Static. Then a child, very close to the receiver:\n\n\"Officer? He rings when he's hungry. When the bell stops, that's when he's near.\"\n\nBreathing. Then, faint and far away on the line - a hand bell.\n\n%s Hang up" % Game.glyph("interact"))
	get_tree().create_timer(2.0).timeout.connect(func() -> void: play_sfx("bell", null, -16.0, 0.9))


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

	match Game.mode:
		"title":
			_title_process(delta)
		"note":
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
			elif Input.is_action_just_pressed("interact"):
				play_sfx("menu", null, -4.0, 1.3)
				menu_cb.call(menu_index)
			elif Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("inventory") or (menu_title == "PAUSED" and Input.is_action_just_pressed("pause")):
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
		"dead", "win":
			if Input.is_action_just_pressed("interact"):
				Game.restart(Game.mode == "dead")
		"play":
			_play_process(delta)
	_intro_process(delta)
	if Game.mode != "title":
		_update_camera()
	_update_audio_and_fx(delta)
	var who: String = Game.state["active"]
	hud.set_hud_visible(Game.mode != "title")
	hud.update_status(who, int(Game.state["hp"][who]), MAX_HP[who], int(Game.state["ammo"]), players[who].stamina, panic, who == "jenny" and Game.mode != "title")


func _play_process(delta: float) -> void:
	Game.state["time"] = float(Game.state["time"]) + delta
	var who: String = Game.state["active"]
	var p = players[who]
	_scare_process(delta)
	if Input.is_action_just_pressed("toggle_controls"):
		Game.tank_controls = not Game.tank_controls
		show_message("Controls: " + ("TANK (classic)" if Game.tank_controls else "MODERN (camera-relative)"))
	if Input.is_action_just_pressed("toggle_crt"):
		Game.crt_on = not Game.crt_on
		post_mat.set_shader_parameter("scanlines", 0.12 if Game.crt_on else 0.0)
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


func _set_fog(col: Color, density: float) -> void:
	var tw := create_tween()
	tw.tween_property(env, "fog_light_color", col, 0.6)
	tw.parallel().tween_property(env, "fog_density", density, 0.6)


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
		_set_fog(r["fog"], 0.09 if not r.get("safe", false) else 0.06)
		var amb: String = r.get("amb", MAPS[who]["amb"])
		if amb != cur_amb:
			cur_amb = amb
			amb_player.stream = _loop_stream(amb)
			amb_player.play()
		if not first:
			# a quick dip to black on each camera cut softens the jump
			post_mat.set_shader_parameter("fade", 0.7)
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void: post_mat.set_shader_parameter("fade", v), 0.7, 0.0, 0.18)
			play_sfx("door", players[who].global_position, -20.0, randf_range(0.9, 1.1))
		_scare_room_enter(who, cur_room_name)
	# camera shake
	var cam: Camera3D = cameras[who].get(c)
	if cam != null and cam.has_meta("base"):
		var b: Transform3D = cam.get_meta("base")
		if shake > 0.01:
			cam.transform = b.translated_local(Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.08)
		else:
			cam.transform = b


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
	var is_title := Game.mode == "title"
	title_music.volume_db = lerpf(title_music.volume_db, -10.0 if is_title else -80.0, minf(1.0, delta * 1.5))
	var rain: AudioStreamPlayer = get_node("rain")
	rain.volume_db = lerpf(rain.volume_db, -14.0 if is_title else -32.0, minf(1.0, delta * 1.5))
	amb_player.volume_db = lerpf(amb_player.volume_db, -80.0 if is_title else -12.0, minf(1.0, delta * 1.0))
	amb2_player.volume_db = -80.0
	# Radio static near monsters (Dana's police radio).
	var target_db := -80.0 if Game.mode != "note" else static_player.volume_db
	if who == "dana" and Game.mode == "play":
		for z in zombies:
			if z.dead:
				continue
			var d: float = z.global_position.distance_to(p.global_position)
			if d < 13.0:
				target_db = maxf(target_db, lerpf(-34.0, -9.0, 1.0 - d / 13.0))
	static_player.volume_db = lerpf(static_player.volume_db, target_db, minf(1.0, delta * 6.0))

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
