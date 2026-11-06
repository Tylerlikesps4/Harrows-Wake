extends Node3D
## Animated character model built from Quaternius' CC0 Universal Animation Library
## mannequins. Clothing is baked into vertex colours from the rest pose, the PSX
## shader is applied, and the model follows its physics body with interpolation
## (so movement looks smooth on 90/120 Hz phone screens).

const PSX_SHADER := preload("res://shaders/psx.gdshader")
const BASE := "res://assets/models/mannequin.glb"
const ZOMBIE := "res://assets/models/mannequin_zombie.glb"

var style: String = "jenny"
var anim: AnimationPlayer = null
var skel: Skeleton3D = null
var body: Node3D = null
var cur_anim: String = ""
var _prev: Transform3D
var _cur: Transform3D
var _have: bool = false
var lean: float = 0.0          # extra pitch used for stagger / stun poses
var y_off: float = 0.0
var inner: Node3D = null
var extras: Dictionary = {}    # named attachments (gun, bell, ...)

static var _mesh_cache: Dictionary = {}


func setup(p_style: String, p_body: Node3D) -> void:
	style = p_style
	body = p_body
	top_level = true
	inner = Node3D.new()
	inner.rotation.y = PI  # glTF faces +Z, Godot actors face -Z
	add_child(inner)
	var src: String = ZOMBIE if style == "tallow" else BASE
	var sc: Node3D = load(src).instantiate()
	inner.add_child(sc)
	anim = sc.get_node("AnimationPlayer")
	skel = sc.find_child("Skeleton3D", true, false)
	var mi: MeshInstance3D = sc.find_child("Mannequin", true, false)
	match style:
		"jenny":
			inner.scale = Vector3(0.86, 0.86, 0.86)
		"dana":
			inner.scale = Vector3(0.97, 0.97, 0.97)
		"bellman":
			inner.scale = Vector3(1.0, 1.27, 1.0) * 1.04
		"tallow":
			inner.scale = Vector3(1.12, 0.98, 1.12)
	if mi != null:
		mi.mesh = _baked_mesh(mi.mesh, style)
		var m := ShaderMaterial.new()
		m.shader = PSX_SHADER
		m.set_shader_parameter("albedo_tex", load("res://assets/tex/dirty_carpet.png"))
		m.set_shader_parameter("use_vcolor", true)
		m.set_shader_parameter("tex_mix", 0.35 if style != "tallow" else 0.6)
		m.set_shader_parameter("uv_scale", 3.0)
		m.set_shader_parameter("albedo_color", Color(1, 1, 1))
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_accessories()
	play_anim(idle_name())


func idle_name() -> String:
	match style:
		"tallow":
			return "Zombie_Idle"
		"bellman":
			return "Idle_Torch"
	return "Idle"


func play_anim(n: String, blend: float = 0.2, spd: float = 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	anim.speed_scale = spd
	if n == cur_anim and anim.is_playing():
		return
	cur_anim = n
	anim.play(n, blend)


func play_once(n: String, blend: float = 0.1, spd: float = 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	cur_anim = n
	anim.speed_scale = spd
	anim.play(n, blend)
	anim.seek(0.0, true)


func anim_length(n: String) -> float:
	if anim == null or not anim.has_animation(n):
		return 0.0
	return anim.get_animation(n).length


func _physics_process(_d: float) -> void:
	if body == null:
		return
	_prev = _cur if _have else body.global_transform
	_cur = body.global_transform
	_have = true


func snap() -> void:
	if body != null:
		_cur = body.global_transform
		_prev = _cur
		_have = true
		global_transform = _cur


func _process(_d: float) -> void:
	if body == null or not _have:
		return
	var f: float = Engine.get_physics_interpolation_fraction()
	var t: Transform3D = _prev.interpolate_with(_cur, f)
	# Teleports (room changes, switching survivors) snap instead of sliding.
	if _prev.origin.distance_to(_cur.origin) > 2.0:
		t = _cur
	global_transform = t
	inner.rotation.x = lean
	inner.position.y = y_off
	visible = body.visible


# ------------------------------------------------------------ clothing bake

static func _region_color(st: String, p: Vector3, front: float, rng: float) -> Color:
	var v: float = p.y / 1.83
	var ax: float = absf(p.x)
	var fz: float = p.z * front           # > 0 = front of the body
	var skin := Color(0.78, 0.6, 0.5)
	var is_arm: bool = ax > 0.2 and v > 0.66
	var is_hand: bool = ax > 0.70 and v > 0.66
	var is_head: bool = v > 0.835 and not is_arm
	var c := Color(0.5, 0.5, 0.5)
	match st:
		"jenny":
			# Pale nightgown to the knee, cardigan sleeves, dark long hair.
			skin = Color(0.86, 0.7, 0.62)
			if is_hand:
				c = skin
			elif is_arm:
				c = Color(0.36, 0.28, 0.34) if ax < 0.62 else skin
			elif is_head:
				c = skin
				if v > 0.905 or (fz < 0.02 and v > 0.85):
					c = Color(0.16, 0.1, 0.07)
			elif v > 0.74 and fz < -0.02 and ax < 0.17:
				c = Color(0.16, 0.1, 0.07)       # hair down the back
			elif v > 0.3:
				c = Color(0.74, 0.76, 0.8)       # nightgown
				if v < 0.34:
					c = Color(0.6, 0.6, 0.66)
			elif v < 0.05:
				c = Color(0.3, 0.2, 0.18)        # slippers
			else:
				c = skin
		"dana":
			# Navy police shirt, dark trousers, black boots, short brown hair.
			if is_hand:
				c = skin
			elif is_arm:
				c = Color(0.16, 0.2, 0.34)
			elif is_head:
				c = skin
				if v > 0.915 or (fz < -0.01 and v > 0.87):
					c = Color(0.22, 0.13, 0.08)
			elif v > 0.49:
				c = Color(0.16, 0.2, 0.34)
				if v > 0.5 and v < 0.53:
					c = Color(0.05, 0.05, 0.05)  # duty belt
				if fz > 0.05 and v > 0.7 and v < 0.74 and p.x * front > 0.04:
					c = Color(0.85, 0.7, 0.3)    # badge
			elif v < 0.06:
				c = Color(0.04, 0.04, 0.04)
			else:
				c = Color(0.09, 0.09, 0.11)
		"bellman":
			# Long black undertaker's coat to the shins, grey-white dead skin.
			skin = Color(0.72, 0.72, 0.68)
			if is_hand:
				c = Color(0.62, 0.6, 0.55)
			elif is_arm:
				c = Color(0.06, 0.05, 0.05)
			elif is_head:
				c = skin
				if fz > 0.0 and v > 0.915 and v < 0.94 and absf(p.x) > 0.015 and absf(p.x) < 0.07:
					c = Color(0.02, 0.02, 0.02)  # hollow eyes
				if fz > 0.0 and v > 0.86 and v < 0.875 and absf(p.x) < 0.05:
					c = Color(0.25, 0.08, 0.08)  # sewn mouth
			elif v > 0.17:
				c = Color(0.07, 0.06, 0.06)
				if v > 0.8:
					c = Color(0.55, 0.53, 0.5)   # stiff collar
			else:
				c = Color(0.03, 0.03, 0.03)
		"tallow":
			# Melted candle-wax skin with darker drips and torn grey clothes.
			var wax := Color(0.86, 0.78, 0.58).lerp(Color(0.62, 0.48, 0.34), rng)
			c = wax
			if v > 0.3 and v < 0.78 and not is_arm and rng > 0.45:
				c = Color(0.3, 0.3, 0.28)
			if v < 0.3 and rng > 0.3:
				c = Color(0.22, 0.2, 0.18)
			if is_head and fz > 0.0 and v > 0.915 and v < 0.94 and absf(p.x) > 0.015 and absf(p.x) < 0.07:
				c = Color(0.12, 0.04, 0.02)
	return c


static func _baked_mesh(src: Mesh, st: String) -> Mesh:
	var key := st
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var out := ArrayMesh.new()
	# Which way is "front" in the rest pose? Toes stick out forward.
	var zsum := 0.0
	var zn := 0
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for vtx in verts:
			if vtx.y < 0.05:
				zsum += vtx.z
				zn += 1
	var front: float = 1.0 if (zn == 0 or zsum / zn >= 0.0) else -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(st)
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			var p: Vector3 = verts[i]
			var n := fposmod(sin(p.x * 41.0 + p.y * 17.0) * 43758.5 + cos(p.z * 29.0) * 1531.0, 1.0)
			var c := _region_color(st, p, front, n)
			c = c.darkened(n * 0.12)
			cols[i] = c
		arr[Mesh.ARRAY_COLOR] = cols
		var flags := 0
		var bones = arr[Mesh.ARRAY_BONES]
		if bones != null and bones is PackedInt32Array and verts.size() > 0 and bones.size() == verts.size() * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	_mesh_cache[key] = out
	return out


# ------------------------------------------------------------ attachments

func _mat(col: Color, emission: float = 0.0, texname: String = "rusty_metal_02") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	m.set_shader_parameter("albedo_tex", load("res://assets/tex/%s.png" % texname))
	m.set_shader_parameter("albedo_color", col)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("tex_mix", 0.4)
	return m


func _attach(bone: String, nm: String) -> BoneAttachment3D:
	if skel == null or skel.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = nm
	ba.bone_name = bone
	skel.add_child(ba)
	return ba


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, segs: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 0
	return c


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _accessories() -> void:
	var head := "Head" if style == "tallow" else "DEF-head"
	var hand_r := "hand_r" if style == "tallow" else "DEF-hand.R"
	var hand_l := "hand_l" if style == "tallow" else "DEF-hand.L"
	match style:
		"bellman":
			var h := _attach(head, "Hat")
			if h:
				var hm := _mat(Color(0.05, 0.045, 0.04), 0.0, "dirty_carpet")
				_mesh(h, _cyl(0.3, 0.3, 0.02, 10), Vector3(0, 0.2, 0), hm)
				_mesh(h, _cyl(0.13, 0.15, 0.24, 8), Vector3(0, 0.32, 0), hm)
				# Faint eye-shine so he reads in the dark.
				var em := _mat(Color(1.0, 0.85, 0.55), 3.0, "plastered_wall_02")
				for sx in [-0.04, 0.04]:
					var s := SphereMesh.new()
					s.radius = 0.014
					s.height = 0.028
					s.radial_segments = 4
					s.rings = 2
					_mesh(h, s, Vector3(sx, 0.09, 0.1), em)
			var b := _attach(hand_l, "Bell")
			if b:
				var bm := _mat(Color(0.85, 0.65, 0.3), 0.15)
				_mesh(b, _cyl(0.025, 0.08, 0.13, 8), Vector3(0, 0.18, 0), bm, Vector3(PI, 0, 0))
				_mesh(b, _cyl(0.015, 0.015, 0.14, 4), Vector3(0, 0.07, 0), _mat(Color(0.25, 0.15, 0.08), 0.0, "dark_wooden_planks"))
				extras["bell"] = b
			var sh := _attach(hand_r, "Shears")
			if sh:
				var sm := _mat(Color(0.7, 0.7, 0.72), 0.1)
				_mesh(sh, _box(Vector3(0.02, 0.55, 0.035)), Vector3(0.01, 0.3, 0.02), sm, Vector3(0, 0, 0.06))
				_mesh(sh, _box(Vector3(0.02, 0.55, 0.035)), Vector3(-0.01, 0.3, 0.02), sm, Vector3(0, 0, -0.06))
		"dana":
			var g := _attach(hand_r, "Gun")
			if g:
				var gm := _mat(Color(0.12, 0.12, 0.13), 0.0)
				_mesh(g, _box(Vector3(0.04, 0.2, 0.06)), Vector3(0.0, 0.12, 0.05), gm)
				_mesh(g, _box(Vector3(0.035, 0.05, 0.12)), Vector3(0.0, 0.05, 0.0), gm)
				extras["gun"] = g
				g.visible = false
		"tallow":
			# Fused wax lumps: a second half-melted head and shoulder masses.
			var wm := _mat(Color(0.8, 0.7, 0.5), 0.05, "damaged_plaster")
			var sp := _attach("spine_03", "Lumps")
			if sp:
				for d in [[Vector3(0.18, 0.18, -0.08), 0.17], [Vector3(-0.2, 0.08, -0.1), 0.14], [Vector3(0.05, 0.3, -0.14), 0.12]]:
					var s := SphereMesh.new()
					s.radius = d[1]
					s.height = d[1] * 1.7
					s.radial_segments = 6
					s.rings = 3
					_mesh(sp, s, d[0], wm)
