extends Node3D
## Harrow's Wake - vertical slice.
## Builds both maps (Police Station for Dana, Orphanage for Jenny) in code,
## runs fixed cameras, interactions, menus, the tube network, panic and saves.

const CELL := 8.0
const WALL_H := 3.0
const DOOR_W := 1.8
const DOOR_H := 2.2
const PSX_SHADER := preload("res://shaders/psx.gdshader")
const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const PlayerScript := preload("res://scripts/player.gd")
const ZombieScript := preload("res://scripts/zombie.gd")
const BellmanScript := preload("res://scripts/bellman.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch.gd")

const CORNERS := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
const NAMES := {"dana": "Dana Reyes", "jenny": "Jenny Hale"}
const PLACES := {"dana": "Harrow's Wake Police Station", "jenny": "St. Agnes Orphanage, Hill Road"}
const MAX_HP := {"dana": 5, "jenny": 3}

var MAPS := {
	"dana": {
		"origin": Vector3(0, 0, 0),
		"rooms": {
			Vector2i(0, 0): {"name": "Lobby", "floor": "tile", "fcol": Color(0.62, 0.58, 0.5), "wcol": Color(0.55, 0.58, 0.5), "light": Color(1.0, 0.82, 0.55), "cam": 2},
			Vector2i(1, 0): {"name": "West Hall", "floor": "tile", "fcol": Color(0.5, 0.5, 0.46), "wcol": Color(0.5, 0.52, 0.47), "light": Color(0.85, 0.95, 0.8), "cam": 0, "flicker": true},
			Vector2i(2, 0): {"name": "Evidence Room", "floor": "metal", "fcol": Color(0.45, 0.47, 0.5), "wcol": Color(0.45, 0.48, 0.52), "light": Color(0.7, 0.8, 1.0), "cam": 3, "needs_power": true},
			Vector2i(1, 1): {"name": "Records Room", "floor": "wood", "fcol": Color(0.5, 0.36, 0.25), "wcol": Color(0.55, 0.5, 0.4), "light": Color(1.0, 0.9, 0.65), "cam": 1, "safe": true},
			Vector2i(1, -1): {"name": "Chief's Office", "floor": "wood", "fcol": Color(0.45, 0.3, 0.2), "wcol": Color(0.5, 0.45, 0.38), "light": Color(1.0, 0.75, 0.5), "cam": 2},
		},
		"links": [[Vector2i(0, 0), Vector2i(1, 0), ""], [Vector2i(1, 0), Vector2i(2, 0), "evidence"], [Vector2i(1, 0), Vector2i(1, 1), ""], [Vector2i(1, 0), Vector2i(1, -1), ""]],
	},
	"jenny": {
		"origin": Vector3(100, 0, 0),
		"rooms": {
			Vector2i(0, 0): {"name": "Dormitory", "floor": "wood", "fcol": Color(0.42, 0.32, 0.25), "wcol": Color(0.48, 0.5, 0.42), "light": Color(0.75, 0.85, 0.7), "cam": 1},
			Vector2i(1, 0): {"name": "Corridor", "floor": "wood", "fcol": Color(0.38, 0.28, 0.22), "wcol": Color(0.42, 0.45, 0.38), "light": Color(0.7, 0.8, 0.65), "cam": 3, "flicker": true},
			Vector2i(2, 0): {"name": "Chapel", "floor": "tile", "fcol": Color(0.4, 0.36, 0.34), "wcol": Color(0.4, 0.36, 0.38), "light": Color(0.9, 0.5, 0.4), "cam": 0},
			Vector2i(1, 1): {"name": "Mail Room", "floor": "wood", "fcol": Color(0.45, 0.35, 0.25), "wcol": Color(0.5, 0.47, 0.38), "light": Color(1.0, 0.88, 0.6), "cam": 2, "safe": true},
			Vector2i(1, -1): {"name": "Playroom", "floor": "fabric", "fcol": Color(0.45, 0.3, 0.32), "wcol": Color(0.5, 0.42, 0.42), "light": Color(0.8, 0.7, 0.9), "cam": 1},
		},
		"links": [[Vector2i(0, 0), Vector2i(1, 0), ""], [Vector2i(1, 0), Vector2i(2, 0), ""], [Vector2i(1, 0), Vector2i(1, 1), ""], [Vector2i(1, 0), Vector2i(1, -1), ""]],
	},
}

var NOTES := {
	"intro": ["October 31, 1998", "Harrow's Wake, Maine.\n\nAt 11:52 PM the bell above the Meridian Biotech site rang by itself. Everyone who heard it changed. The fog came down and never lifted.\n\nTwo survivors are still breathing on opposite ends of town. If they ever meet, the Choir Stone's resonance kills them both.\n\nThe town's old pneumatic mail tubes still work.\n\n[E] Continue"],
	"note_toll": ["Dispatch Memo", "Oct 31, 11:52 PM.\nMultiple calls: the Meridian bell is ringing on its own. Callers report 'singing' coming up through the storm drains. Two callers say their husbands 'went soft, like candle wax.'\nAll units to Bell Street.\n- Dispatch"],
	"note_chief": ["Chief's Log", "Meridian's people sealed the lab and left us the town.\n\nThe old mail tubes still run from our Records Room to St. Agnes Orphanage on Hill Road. If anyone's alive up there, that's how we reach them.\n\nThe evidence room's mag-lock blew its fuse. Spares went up to the orphanage with the Christmas lights last year. Of course they did.\n- Chief Harlan"],
	"note_jenny": ["Torn Diary Page", "If you find this, I'm hiding.\n\nThe tall man with the bell walks the halls. Don't run near him. He HEARS you.\n\nThe wardrobes are safe if he didn't see you get in. Try not to panic in there.\n\nHe never comes into the Mail Room. The tube there goes all the way to the police station.\n- J."],
}

var players: Dictionary = {}
var cameras: Dictionary = {"dana": {}, "jenny": {}}
var room_lights: Dictionary = {}
var flicker_lights: Array = []
var interactables: Array = []
var doors: Dictionary = {}
var zombies: Array = []
var bellman = null
var hud: CanvasLayer = null
var post_mat: ShaderMaterial = null
var post_rect: ColorRect = null
var panic: float = 0.0
var sfx: Dictionary = {}
var static_player: AudioStreamPlayer = null
var drone_player: AudioStreamPlayer = null
var heart_t: float = 0.0
var tex_cache: Dictionary = {}
var mat_cache: Dictionary = {}
var cur_cam_key: String = ""
var cur_room_name: String = ""
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
var crt_on: bool = true


func _ready() -> void:
	randomize()
	_build_sfx()
	_build_environment()
	for m in MAPS.keys():
		_build_map(m)
	_build_interactables()
	_build_players()
	_build_enemies()
	_build_ui()
	_apply_state()
	if "--smoke" in OS.get_cmdline_user_args():
		add_child(load("res://tests/smoke.gd").new())
	if "--shots" in OS.get_cmdline_user_args():
		add_child(load("res://tests/shots.gd").new())
	if Game.skip_title:
		Game.skip_title = false
		Game.mode = "play"
		_announce()
	else:
		Game.mode = "title"
		_show_title()


# ---------------------------------------------------------------- building

func tex(kind: String) -> ImageTexture:
	if tex_cache.has(kind):
		return tex_cache[kind]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for y in 64:
		for x in 64:
			var n := rng.randf()
			var v := 0.8 + n * 0.2
			match kind:
				"tile":
					var chk: bool = (int(x / 16.0) + int(y / 16.0)) % 2 == 0
					v = (0.95 if chk else 0.72) + n * 0.12
					if x % 16 == 0 or y % 16 == 0:
						v = 0.38
				"wall":
					v = 0.8 + n * 0.14 + sin(x * 0.2) * 0.03
					if y > 50:
						v -= 0.22 + n * 0.1
					if y == 50:
						v = 0.4
				"wood":
					v = 0.62 + 0.22 * sin(y * 0.9 + sin(x * 0.12) * 3.0) + n * 0.1
					if y % 16 == 0:
						v = 0.3
				"metal":
					v = 0.6 + n * 0.22
					if (x % 32 == 3 or x % 32 == 28) and (y % 32 == 3 or y % 32 == 28):
						v = 1.0
				"fabric":
					v = 0.62 + n * 0.3 + (0.08 if (x + y) % 4 == 0 else 0.0)
				"flesh":
					v = 0.55 + 0.3 * sin(x * 0.37) * sin(y * 0.29) + n * 0.2
				"plain":
					v = 0.9 + n * 0.1
			img.set_pixel(x, y, Color(v, v, v))
	var t := ImageTexture.create_from_image(img)
	tex_cache[kind] = t
	return t


func mat(kind: String, col: Color, uvs: float = 1.0, emission: float = 0.0) -> ShaderMaterial:
	var key := "%s_%s_%.2f_%.2f" % [kind, col.to_html(), uvs, emission]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	m.set_shader_parameter("albedo_tex", tex(kind))
	m.set_shader_parameter("albedo_color", col)
	m.set_shader_parameter("uv_scale", uvs)
	m.set_shader_parameter("emission", emission)
	mat_cache[key] = m
	return m


func box(parent: Node3D, size: Vector3, pos: Vector3, kind: String, col: Color, layer: int = 1, collide: bool = true, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(kind, col, maxf(1.0, maxf(size.x, maxf(size.y, size.z)) * 1.2), emission)
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


func part(parent: Node3D, mesh: Mesh, pos: Vector3, kind: String, col: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(kind, col, 1.0, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


func cyl(top: float, bottom: float, h: float, segs: int = 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 0
	return c


func sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 4
	return s


func bmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.29, 0.31)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.07, 0.08)
	env.fog_density = 0.05
	we.environment = env
	add_child(we)


func cell_center(map: String, c: Vector2i) -> Vector3:
	var o: Vector3 = MAPS[map]["origin"]
	return o + Vector3(c.x * CELL, 0, c.y * CELL)


func cell_of(map: String, pos: Vector3) -> Vector2i:
	var o: Vector3 = MAPS[map]["origin"]
	return Vector2i(roundi((pos.x - o.x) / CELL), roundi((pos.z - o.z) / CELL))


func _link_between(map: String, a: Vector2i, b: Vector2i) -> Array:
	for l in MAPS[map]["links"]:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return l
	return []


func _build_map(map: String) -> void:
	var root := Node3D.new()
	root.name = map
	add_child(root)
	var rooms: Dictionary = MAPS[map]["rooms"]
	for c in rooms.keys():
		var r: Dictionary = rooms[c]
		var ctr := cell_center(map, c)
		box(root, Vector3(CELL, 0.2, CELL), ctr + Vector3(0, -0.1, 0), r["floor"], r["fcol"])
		box(root, Vector3(CELL, 0.2, CELL), ctr + Vector3(0, WALL_H + 0.1, 0), "plain", Color(0.18, 0.17, 0.16), 1, false)
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if rooms.has(n):
				if d.x > 0 or d.y > 0:
					var l := _link_between(map, c, n)
					_build_wall(root, map, ctr, d, not l.is_empty(), r["wcol"], (l[2] if not l.is_empty() else ""))
			else:
				_build_wall(root, map, ctr, d, false, r["wcol"], "")
		# light
		var lt := OmniLight3D.new()
		lt.light_color = r["light"]
		lt.light_energy = 1.7
		lt.omni_range = 10.5
		lt.omni_attenuation = 1.2
		lt.position = ctr + Vector3(0, 2.6, 0)
		root.add_child(lt)
		room_lights["%s_%s" % [map, c]] = lt
		if r.get("needs_power", false) and not Game.flag("power"):
			lt.light_energy = 0.12
		if r.get("flicker", false):
			flicker_lights.append(lt)
		# fixed camera
		var cam := Camera3D.new()
		cam.fov = 62.0
		cam.near = 0.05
		cam.far = 45.0
		root.add_child(cam)
		var corner: Vector2 = CORNERS[r["cam"]]
		var cpos := ctr + Vector3(corner.x * CELL * 0.43, 2.65, corner.y * CELL * 0.43)
		cam.look_at_from_position(cpos, ctr + Vector3(-corner.x * 0.6, 0.6, -corner.y * 0.6), Vector3.UP)
		cameras[map][c] = cam
	_build_props(map, root)


func _build_wall(root: Node3D, map: String, ctr: Vector3, d: Vector2i, gap: bool, wcol: Color, door_id: String) -> void:
	var along_x: bool = d.y != 0
	var mid := ctr + Vector3(d.x * CELL / 2.0, 0, d.y * CELL / 2.0)
	if not gap:
		var sz := Vector3(CELL + 0.2, WALL_H, 0.2) if along_x else Vector3(0.2, WALL_H, CELL + 0.2)
		box(root, sz, mid + Vector3(0, WALL_H / 2.0, 0), "wall", wcol)
		return
	var seg := (CELL - DOOR_W) / 2.0
	for s in [-1.0, 1.0]:
		var off: float = s * (DOOR_W / 2.0 + seg / 2.0)
		var sz2 := Vector3(seg + 0.1, WALL_H, 0.2) if along_x else Vector3(0.2, WALL_H, seg + 0.1)
		var p := mid + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off)) + Vector3(0, WALL_H / 2.0, 0)
		box(root, sz2, p, "wall", wcol)
	var lh := WALL_H - DOOR_H
	var lsz := Vector3(DOOR_W, lh, 0.2) if along_x else Vector3(0.2, lh, DOOR_W)
	box(root, lsz, mid + Vector3(0, DOOR_H + lh / 2.0, 0), "wall", wcol * 0.8)
	if door_id != "" and not Game.flag("door_" + door_id):
		var dsz := Vector3(DOOR_W, DOOR_H, 0.14) if along_x else Vector3(0.14, DOOR_H, DOOR_W)
		var door := box(root, dsz, mid + Vector3(0, DOOR_H / 2.0, 0), "metal", Color(0.35, 0.42, 0.45))
		doors[door_id] = door
		interactables.append({"map": map, "kind": "door", "id": door_id, "pos": mid + Vector3(0, 1.0, 0), "point": mid, "label": "Examine door"})


func _off(map: String, c: Vector2i, o: Vector3) -> Vector3:
	return cell_center(map, c) + o


func _build_props(map: String, root: Node3D) -> void:
	var wood := Color(0.45, 0.3, 0.2)
	if map == "dana":
		box(root, Vector3(3.0, 1.1, 0.8), _off(map, Vector2i(0, 0), Vector3(1.5, 0.55, -3.0)), "wood", wood, 2)
		box(root, Vector3(0.6, 0.5, 2.4), _off(map, Vector2i(0, 0), Vector3(-3.3, 0.25, 0.5)), "fabric", Color(0.3, 0.32, 0.45), 2)
		box(root, Vector3(2.4, 0.5, 0.6), _off(map, Vector2i(0, 0), Vector3(-1.0, 0.25, 3.4)), "fabric", Color(0.3, 0.32, 0.45), 2)
		box(root, Vector3(1.6, 0.02, 0.9), _off(map, Vector2i(1, 0), Vector3(0.8, 0.01, 1.2)), "flesh", Color(0.35, 0.03, 0.02), 1, false)
		box(root, Vector3(0.7, 0.02, 2.0), _off(map, Vector2i(1, 0), Vector3(2.4, 0.01, -0.6)), "flesh", Color(0.3, 0.02, 0.02), 1, false)
		for i in 3:
			box(root, Vector3(0.6, 2.0, 0.5), _off(map, Vector2i(2, 0), Vector3(-1.5 + i * 0.7, 1.0, 3.5)), "metal", Color(0.4, 0.45, 0.4), 2)
		box(root, Vector3(2.5, 1.8, 0.5), _off(map, Vector2i(2, 0), Vector3(2.0, 0.9, -3.5)), "metal", Color(0.35, 0.35, 0.38), 2)
		box(root, Vector3(1.8, 0.8, 0.9), _off(map, Vector2i(1, -1), Vector3(0, 0.4, -2.4)), "wood", wood, 2)
		box(root, Vector3(2.4, 1.9, 0.5), _off(map, Vector2i(1, 1), Vector3(-2.0, 0.95, 3.6)), "wood", wood * 0.8, 2)
	else:
		for i in 3:
			box(root, Vector3(1.0, 0.5, 2.0), _off(map, Vector2i(0, 0), Vector3(-1.5 + i * 1.6, 0.25, 2.6)), "fabric", Color(0.55, 0.55, 0.5), 2)
		for i in 3:
			box(root, Vector3(2.6, 0.5, 0.5), _off(map, Vector2i(2, 0), Vector3(-1.0, 0.25, -2.4 + i * 1.6)), "wood", wood * 0.7, 2)
		box(root, Vector3(1.0, 1.0, 2.0), _off(map, Vector2i(2, 0), Vector3(2.4, 0.5, 0)), "fabric", Color(0.5, 0.08, 0.08), 2)
		var cross := Node3D.new()
		root.add_child(cross)
		cross.position = _off(map, Vector2i(2, 0), Vector3(3.8, 1.9, 0))
		box(cross, Vector3(0.1, 1.2, 0.12), Vector3.ZERO, "wood", wood, 1, false)
		box(cross, Vector3(0.1, 0.12, 0.7), Vector3(0, 0.25, 0), "wood", wood, 1, false)
		box(root, Vector3(1.2, 0.6, 0.7), _off(map, Vector2i(1, -1), Vector3(2.5, 0.3, -3.0)), "wood", Color(0.6, 0.2, 0.15), 2)
		box(root, Vector3(0.3, 0.7, 1.0), _off(map, Vector2i(1, -1), Vector3(-0.5, 0.45, 2.5)), "wood", Color(0.7, 0.55, 0.3), 2)
		part(root, sph(0.25), _off(map, Vector2i(1, -1), Vector3(-0.5, 0.95, 2.1)), "wood", Color(0.7, 0.55, 0.3))
		box(root, Vector3(2.4, 1.9, 0.5), _off(map, Vector2i(1, 1), Vector3(-2.0, 0.95, 3.6)), "wood", wood * 0.8, 2)
		box(root, Vector3(1.4, 0.02, 0.7), _off(map, Vector2i(1, 0), Vector3(-1.5, 0.01, 0.8)), "flesh", Color(0.3, 0.02, 0.02), 1, false)


func _add_inter(map: String, c: Vector2i, offset: Vector3, kind: String, id: String, label: String) -> Dictionary:
	var pos := _off(map, c, offset)
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
			box(root, Vector3(1.4, 0.8, 0.8), pos + Vector3(0, 0.4, 0), "wood", Color(0.45, 0.3, 0.2), 2)
			box(root, Vector3(0.45, 0.16, 0.35), pos + Vector3(0, 0.88, 0), "metal", Color(0.15, 0.15, 0.17), 1, false)
			box(root, Vector3(0.3, 0.12, 0.02), pos + Vector3(0, 1.0, -0.12), "plain", Color(0.9, 0.9, 0.85), 1, false)
		"tube":
			part(root, cyl(0.15, 0.15, WALL_H), pos + Vector3(0, WALL_H / 2.0, 0), "metal", Color(0.75, 0.6, 0.3))
			box(root, Vector3(0.5, 0.6, 0.5), pos + Vector3(0, 1.2, 0), "metal", Color(0.7, 0.55, 0.28), 2)
		"fusebox":
			box(root, Vector3(0.6, 0.7, 0.2), pos, "metal", Color(0.45, 0.48, 0.42), 1, false)
		"hide":
			var wd := box(root, Vector3(1.1, 2.1, 1.1), pos + Vector3(0, 1.05, 0), "wood", Color(0.35, 0.22, 0.14), 2)
			wd.name = "wardrobe_" + id
		"exit":
			box(root, Vector3(0.16, DOOR_H, 1.6), pos + Vector3(0, DOOR_H / 2.0, 0), "wood", Color(0.3, 0.18, 0.1), 1, false)
			box(root, Vector3(0.2, 0.3, 1.7), pos + Vector3(-0.05, 1.1, 0), "metal", Color(0.5, 0.5, 0.5), 1, false)
		"note":
			var nm := box(root, Vector3(0.3, 0.02, 0.38), pos, "plain", Color(0.95, 0.93, 0.85), 1, false, 0.4)
			it["node"] = nm
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
			var im := part(root, bmesh(Vector3(0.22, 0.22, 0.22)), pos, "plain", col, 0.9)
			it["node"] = im
			spin_nodes.append(im)
	return it


func _build_interactables() -> void:
	_add_inter("dana", Vector2i(0, 0), Vector3(1.0, 1.12, -3.0), "note", "note_toll", "Read memo")
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


func _make_body(who: String) -> Node3D:
	var root := Node3D.new()
	match who:
		"dana":
			part(root, bmesh(Vector3(0.36, 0.8, 0.22)), Vector3(0, 0.4, 0), "fabric", Color(0.15, 0.15, 0.2))
			part(root, cyl(0.24, 0.2, 0.75), Vector3(0, 1.17, 0), "fabric", Color(0.5, 0.45, 0.32))
			part(root, bmesh(Vector3(0.12, 0.65, 0.12)), Vector3(-0.3, 1.15, 0), "fabric", Color(0.5, 0.45, 0.32))
			part(root, bmesh(Vector3(0.12, 0.65, 0.12)), Vector3(0.3, 1.15, 0), "fabric", Color(0.5, 0.45, 0.32))
			part(root, sph(0.16), Vector3(0, 1.72, 0), "flesh", Color(0.85, 0.65, 0.5))
			part(root, bmesh(Vector3(0.34, 0.12, 0.3)), Vector3(0, 1.86, 0.03), "fabric", Color(0.2, 0.12, 0.08))
			part(root, bmesh(Vector3(0.06, 0.1, 0.25)), Vector3(0.3, 0.85, -0.12), "metal", Color(0.1, 0.1, 0.1))
		"jenny":
			part(root, bmesh(Vector3(0.26, 0.6, 0.16)), Vector3(0, 0.3, 0), "flesh", Color(0.8, 0.62, 0.5))
			part(root, cyl(0.16, 0.3, 0.75), Vector3(0, 0.88, 0), "fabric", Color(0.25, 0.3, 0.55))
			part(root, bmesh(Vector3(0.09, 0.5, 0.09)), Vector3(-0.22, 1.0, 0), "flesh", Color(0.8, 0.62, 0.5))
			part(root, bmesh(Vector3(0.09, 0.5, 0.09)), Vector3(0.22, 1.0, 0), "flesh", Color(0.8, 0.62, 0.5))
			part(root, sph(0.15), Vector3(0, 1.42, 0), "flesh", Color(0.85, 0.68, 0.55))
			part(root, bmesh(Vector3(0.32, 0.4, 0.2)), Vector3(0, 1.4, 0.08), "fabric", Color(0.45, 0.25, 0.12))
		"bellman":
			part(root, cyl(0.3, 0.68, 2.1), Vector3(0, 1.05, 0), "fabric", Color(0.12, 0.09, 0.08))
			part(root, sph(0.23), Vector3(0, 2.32, 0), "flesh", Color(0.75, 0.72, 0.66))
			part(root, cyl(0.02, 0.33, 0.6), Vector3(0, 2.5, 0.04), "fabric", Color(0.1, 0.07, 0.06))
			part(root, bmesh(Vector3(0.16, 0.9, 0.16)), Vector3(-0.42, 1.55, -0.1), "fabric", Color(0.12, 0.09, 0.08))
			part(root, bmesh(Vector3(0.16, 0.9, 0.16)), Vector3(0.42, 1.55, -0.1), "fabric", Color(0.12, 0.09, 0.08))
			part(root, cyl(0.06, 0.13, 0.22), Vector3(-0.42, 0.98, -0.2), "metal", Color(0.85, 0.68, 0.3))
			part(root, bmesh(Vector3(0.05, 0.05, 0.75)), Vector3(0.4, 1.05, -0.5), "metal", Color(0.7, 0.7, 0.72))
			part(root, bmesh(Vector3(0.05, 0.05, 0.75)), Vector3(0.46, 1.05, -0.5), "metal", Color(0.6, 0.6, 0.62))
			part(root, sph(0.035), Vector3(-0.08, 2.36, -0.2), "plain", Color(1.0, 0.9, 0.6), 2.0)
			part(root, sph(0.035), Vector3(0.08, 2.36, -0.2), "plain", Color(1.0, 0.9, 0.6), 2.0)
		"tallow":
			part(root, sph(0.45), Vector3(0, 0.6, 0), "flesh", Color(0.75, 0.6, 0.45))
			part(root, sph(0.38), Vector3(0.1, 1.1, 0.05), "flesh", Color(0.8, 0.65, 0.5))
			part(root, sph(0.3), Vector3(-0.15, 1.45, 0), "flesh", Color(0.72, 0.55, 0.42))
			part(root, sph(0.17), Vector3(0.12, 1.75, -0.05), "flesh", Color(0.8, 0.62, 0.5))
			part(root, sph(0.15), Vector3(-0.25, 1.68, 0.05), "flesh", Color(0.7, 0.5, 0.4))
			part(root, bmesh(Vector3(0.12, 0.7, 0.12)), Vector3(0.4, 1.0, -0.25), "flesh", Color(0.7, 0.5, 0.4))
	return root


func _capsule(body: CollisionObject3D, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position = Vector3(0, h / 2.0, 0)
	body.add_child(cs)


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
		var body := _make_body(who)
		p.add_child(body)
		p.mesh_root = body
		add_child(p)
		p.global_position = starts[who]
		p.rotation.y = start_rot[who]
		players[who] = p


func _build_enemies() -> void:
	var z := CharacterBody3D.new()
	z.set_script(ZombieScript)
	z.main = self
	z.collision_layer = 8
	z.collision_mask = 1 | 4
	_capsule(z, 0.4, 1.8)
	var zb := _make_body("tallow")
	z.add_child(zb)
	z.mesh_root = zb
	add_child(z)
	z.global_position = _off("dana", Vector2i(1, 0), Vector3(2.2, 0.05, 1.5))
	zombies.append(z)
	if Game.flag("tallow1_dead"):
		z.die()

	var b := CharacterBody3D.new()
	b.set_script(BellmanScript)
	b.main = self
	b.collision_layer = 8
	b.collision_mask = 1 | 4
	_capsule(b, 0.45, 2.4)
	var bb := _make_body("bellman")
	b.add_child(bb)
	b.mesh_root = bb
	add_child(b)
	b.global_position = _off("jenny", Vector2i(2, 0), Vector3(1.0, 0.05, 0))
	b.rotation.y = PI / 2.0
	bellman = b


func _build_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	post_rect = ColorRect.new()
	post_rect.position = Vector2.ZERO
	post_rect.size = Vector2(320, 240)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST_SHADER
	post_rect.material = post_mat
	post_layer.add_child(post_rect)
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	var touch := CanvasLayer.new()
	touch.set_script(TouchScript)
	add_child(touch)


func _build_sfx() -> void:
	sfx["bell"] = Synth.bell()
	sfx["step"] = Synth.noise_burst(0.09, 40.0, 0.25, 0.5)
	sfx["gunshot"] = Synth.gunshot()
	sfx["click"] = Synth.blip(1400.0, 0.04)
	sfx["splat"] = Synth.noise_burst(0.3, 10.0, 0.15, 0.9)
	sfx["groan"] = Synth.groan()
	sfx["tube"] = Synth.noise_burst(1.0, 2.5, 0.06, 1.0)
	sfx["pickup"] = Synth.blip(880.0, 0.15)
	sfx["menu"] = Synth.blip(520.0, 0.05)
	sfx["sting"] = Synth.blip(98.0, 0.9)
	sfx["heart"] = Synth.heartbeat()
	sfx["unlock"] = Synth.blip(660.0, 0.3)
	static_player = AudioStreamPlayer.new()
	static_player.stream = Synth.static_loop()
	static_player.volume_db = -80.0
	add_child(static_player)
	static_player.play()
	drone_player = AudioStreamPlayer.new()
	drone_player.stream = Synth.drone()
	drone_player.volume_db = -14.0
	add_child(drone_player)
	drone_player.play()


func _apply_state() -> void:
	var st: Dictionary = Game.state
	for who in ["dana", "jenny"]:
		var pos: Array = st["pos"][who]
		if pos.size() == 3:
			players[who].global_position = Vector3(pos[0], pos[1] + 0.05, pos[2])
			players[who].rotation.y = float(st["rot"][who])
		players[who].active = st["active"] == who


# ---------------------------------------------------------------- helpers

func play_sfx(sname: String, pos = null, vol: float = 0.0) -> void:
	if not sfx.has(sname):
		return
	if pos == null:
		var a := AudioStreamPlayer.new()
		a.stream = sfx[sname]
		a.volume_db = vol
		add_child(a)
		a.finished.connect(a.queue_free)
		a.play()
	else:
		var a3 := AudioStreamPlayer3D.new()
		a3.stream = sfx[sname]
		a3.volume_db = vol
		a3.unit_size = 4.0
		a3.max_distance = 35.0
		add_child(a3)
		a3.global_position = pos
		a3.finished.connect(a3.queue_free)
		a3.play()


func show_message(text: String, secs: float = 3.5) -> void:
	hud.show_message(text, secs)


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
	play_sfx("gunshot")
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.85, 0.5)
	fl.light_energy = 4.0
	fl.omni_range = 6.0
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
	show_message("Ugh!", 1.0)
	if int(Game.state["hp"][map]) <= 0:
		die("The Tallow-folk pull you into the wax.")


func on_chase_start() -> void:
	play_sfx("sting", null, -4.0)
	panic = minf(100.0, panic + 20.0)


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
	_update_struggle()


func _update_struggle() -> void:
	var bar := ""
	for i in struggle_need:
		bar += "#" if i < struggle_count else "-"
	hud.show_overlay("STRUGGLE!", "The Bellman has you!\n\nMash [E] / (A) to break free!\n\n[%s]\n\n%.1f" % [bar, maxf(0.0, struggle_t)], Color(0.95, 0.2, 0.15))


func _end_struggle(won: bool) -> void:
	hud.hide_overlay()
	Game.mode = "play"
	var p = players["jenny"]
	p.invuln = 3.0
	if won:
		bellman.stun(4.5)
		panic = 65.0
		show_message("You wrench free and he staggers!")
	else:
		Game.state["hp"]["jenny"] = int(Game.state["hp"]["jenny"]) - 1
		play_sfx("splat")
		if int(Game.state["hp"]["jenny"]) <= 0:
			die("The shears close.")
			return
		bellman.stun(3.5)
		panic = 85.0
		show_message("The shears bite. You tear loose, bleeding. RUN.")


func die(reason: String) -> void:
	Game.mode = "dead"
	var body := reason + "\n\n"
	body += "[E] Continue from last save" if Game.has_save() else "[E] Try again"
	hud.show_overlay("YOU DIED", body, Color(0.8, 0.05, 0.05))


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
	var body := "Jenny slips the Tower Key into the padlock. The chain falls. Outside, the fog is moving like breath.\n\nSomewhere above the town, the bell starts to ring again.\n\nTIME  %02d:%02d\nSAVES  %d\nRANK  %s\n\nEND OF VERTICAL SLICE - thank you for playing.\n[E] Play again" % [int(secs) / 60, int(secs) % 60, saves, rank]
	hud.show_overlay("HARROW'S WAKE", body, Color(0.85, 0.7, 0.35))


func _show_title() -> void:
	var body := "\n\n          A PS1-STYLE SURVIVAL HORROR\n                 VERTICAL SLICE\n\n\n               [E]  NEW GAME\n"
	if Game.has_save():
		body += "               [C]  CONTINUE\n"
	body += "\nMove WASD  Run Shift  Act E  Turn Q  Items Tab\nAim K/RMB  Fire J/LMB  F1 controls  F2 CRT"
	hud.show_overlay("HARROW'S WAKE", body, Color(0.75, 0.12, 0.1))


func _announce() -> void:
	var who: String = Game.state["active"]
	show_message("- %s -\n%s" % [NAMES[who].to_upper(), PLACES[who]], 4.0)


func _show_note(key: String) -> void:
	var n: Array = NOTES[key]
	Game.mode = "note"
	hud.show_overlay(n[0], n[1])


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
	hud.show_overlay(menu_title, body)


func _close_menu() -> void:
	hud.hide_overlay()
	if Game.mode == "menu":
		Game.mode = "play"


func _other(who: String) -> String:
	return "jenny" if who == "dana" else "dana"


func _open_typewriter() -> void:
	var who: String = Game.state["active"]
	var other := _other(who)
	open_menu("TYPEWRITER", "An old Smith-Corona. The keys are cold.", ["Save the game", "Switch to " + NAMES[other], "Leave"], func(i: int) -> void:
		match i:
			0:
				_sync_state()
				Game.save_game()
				_close_menu()
				play_sfx("menu")
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
	header += "\nControls: %s (F1 to switch)" % ("TANK" if Game.tank_controls else "MODERN")
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
				show_message("Service pistol, 9mm. Hold K / RMB to aim, J / LMB to fire.")
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
	post_mat.set_shader_parameter("fade", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: post_mat.set_shader_parameter("fade", v), 1.0, 0.0, 1.2)
	_announce()


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
			show_message("Picked up: " + it["label"])
		"ammo":
			interactables.erase(it)
			Game.set_flag("picked_" + it["id"])
			if it.has("node"):
				spin_nodes.erase(it["node"])
				it["node"].queue_free()
			if who == "dana":
				Game.state["ammo"] = int(Game.state["ammo"]) + 6
			play_sfx("pickup")
			show_message("Picked up: Handgun Ammo x6")
		"typewriter":
			_open_typewriter()
		"tube":
			_open_tube()
		"hide":
			p.hidden_in = it["id"]
			p.global_position = Vector3(it["point"].x, p.global_position.y, it["point"].z)
			p.visible = false
			post_mat.set_shader_parameter("fade", 0.55)
			show_message("You squeeze inside and hold your breath... [E] to leave", 3.0)
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
				lt.light_energy = 1.7
				play_sfx("unlock")
				show_message("You seat the fuse. Lights stutter on. Down the hall, a mag-lock clacks open.")
			else:
				show_message("The fuse box is missing a 30-amp fuse.")
		"door":
			if it["id"] == "evidence":
				show_message("EVIDENCE - the mag-lock is dead. No power.")
		"exit":
			if Game.has_item(who, "Tower Key"):
				play_sfx("unlock")
				_win()
			else:
				show_message("The chapel doors are chained shut. The padlock is stamped BELL TOWER.")


func _unhide(p) -> void:
	p.hidden_in = ""
	p.visible = true
	post_mat.set_shader_parameter("fade", 0.0)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	for n in spin_nodes:
		n.rotation.y += delta * 2.0
		n.rotation.x += delta * 1.1
	flick_t -= delta
	if flick_t <= 0.0:
		flick_t = randf_range(0.05, 0.4)
		for lt in flicker_lights:
			lt.light_energy = 1.7 if randf() > 0.15 else 0.2
	fire_cd = maxf(0.0, fire_cd - delta)

	match Game.mode:
		"title":
			if Input.is_action_just_pressed("interact"):
				hud.hide_overlay()
				Game.new_game()
				_show_note("intro")
			elif Input.is_action_just_pressed("continue_game") and Game.has_save():
				Game.restart(true)
		"note":
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("cancel"):
				hud.hide_overlay()
				Game.mode = "play"
				if cur_cam_key == "":
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
				menu_cb.call(menu_index)
			elif Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("inventory"):
				_close_menu()
		"struggle":
			struggle_t -= delta
			if Input.is_action_just_pressed("interact"):
				struggle_count += 1
				play_sfx("menu", null, -6.0)
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
	_update_camera()
	_update_audio_and_fx(delta)
	var who: String = Game.state["active"]
	hud.set_hud_visible(Game.mode != "title")
	hud.update_status(who, int(Game.state["hp"][who]), MAX_HP[who], int(Game.state["ammo"]), players[who].stamina, panic, who == "jenny" and Game.mode != "title")


func _play_process(delta: float) -> void:
	Game.state["time"] = float(Game.state["time"]) + delta
	var who: String = Game.state["active"]
	var p = players[who]
	if Input.is_action_just_pressed("toggle_controls"):
		Game.tank_controls = not Game.tank_controls
		show_message("Controls: " + ("TANK (classic)" if Game.tank_controls else "MODERN (camera-relative)"))
	if Input.is_action_just_pressed("toggle_crt"):
		crt_on = not crt_on
		post_mat.set_shader_parameter("scanlines", 0.12 if crt_on else 0.0)
	if p.hidden_in != "":
		hud.prompt.text = "[E] Leave hiding place"
		if Input.is_action_just_pressed("interact"):
			_unhide(p)
		return
	near = _find_near()
	hud.prompt.text = ("[E] " + near["label"]) if not near.is_empty() else ""
	if Input.is_action_just_pressed("interact") and not near.is_empty() and not p.aiming:
		_interact(near)
	elif Input.is_action_just_pressed("inventory"):
		_open_inventory()


func _update_camera() -> void:
	var who: String = Game.state["active"]
	var c := cell_of(who, players[who].global_position)
	var key := "%s_%s" % [who, c]
	if key != cur_cam_key and cameras[who].has(c):
		cur_cam_key = key
		cameras[who][c].make_current()
		cur_room_name = MAPS[who]["rooms"][c]["name"]


func _update_audio_and_fx(delta: float) -> void:
	var who: String = Game.state["active"]
	var p = players[who]
	# Radio static near monsters (Dana's police radio).
	var target_db := -80.0
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
				panic += 9.0 * delta
				if panic >= 100.0:
					_unhide(p)
					bellman.on_scream()
					panic = 85.0
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
	elif who != "jenny":
		panic = maxf(0.0, panic - 20.0 * delta)
	post_mat.set_shader_parameter("panic", maxf(0.0, (panic - 35.0) / 65.0))
	if panic > 40.0 and Game.mode == "play":
		heart_t -= delta
		if heart_t <= 0.0:
			heart_t = lerpf(1.1, 0.42, (panic - 40.0) / 60.0)
			play_sfx("heart", null, lerpf(-14.0, -2.0, (panic - 40.0) / 60.0))
