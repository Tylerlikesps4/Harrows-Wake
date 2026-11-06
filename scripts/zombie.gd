extends CharacterBody3D
## Tallow-folk: slow, fused townsperson. Three handgun rounds put it down.
## Starts facing the wall, scratching at it; turns when you come close.

var main = null
var map: String = "dana"
var id: String = "tallow1"
var hp: int = 3
var dead: bool = false
var stagger: float = 0.0
var atk_cd: float = 0.0
var speed: float = 0.85
var groan_cd: float = 2.0
var mesh_root: Node3D = null
var t: float = 0.0
var awake: bool = false
var attack_t: float = 0.0


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	stagger = 0.7
	awake = true
	main.play_sfx("splat", global_position)
	if mesh_root != null:
		mesh_root.play_once("Hit_Knockback", 0.05, 1.6)
	if hp <= 0:
		die()


var push := Vector3.ZERO
var puddle: MeshInstance3D = null


## Hit reaction: a shove away from the shooter and a burst of wax chips.
func knockback(from: Vector3) -> void:
	var d := global_position - from
	d.y = 0.0
	if d.length() > 0.01:
		push = d.normalized() * (2.2 if not dead else 0.0)
	_chips()


func _chips() -> void:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.emitting = false
	cp.amount = 10
	cp.lifetime = 0.5
	cp.explosiveness = 1.0
	cp.direction = Vector3(0, 1, 0)
	cp.spread = 70.0
	cp.initial_velocity_min = 1.5
	cp.initial_velocity_max = 3.0
	cp.gravity = Vector3(0, -9.8, 0)
	cp.scale_amount_min = 0.6
	cp.scale_amount_max = 1.2
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	cp.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.75, 0.5)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	cp.material_override = m
	main.add_child(cp)
	cp.global_position = global_position + Vector3(0, 1.3, 0)
	cp.emitting = true
	get_tree().create_timer(1.2).timeout.connect(cp.queue_free)


## Death: it buckles, then slumps and melts down into a spreading wax puddle,
## hissing. Saved games show the puddle (and nothing else) where it died.
func die() -> void:
	dead = true
	Game.set_flag(id + "_dead")
	collision_layer = 0
	push = Vector3.ZERO
	if mesh_root != null and is_inside_tree() and main != null and Game.mode != "title" and main.is_node_ready():
		main.play_sfx("zombie_die", global_position)
		main.play_sfx("splat", global_position, -4.0, 0.55)
		mesh_root.play_once("Hit_Knockback", 0.05, 0.8)
		var inner: Node3D = mesh_root.inner
		var base_sc: Vector3 = inner.scale
		var tw := create_tween()
		tw.tween_interval(0.45)
		tw.tween_callback(func() -> void:
			mesh_root.anim.pause()
			main.play_sfx("static", global_position, -10.0, 0.5, 12.0)   # hiss of melting wax
			_spawn_puddle(true))
		tw.tween_property(mesh_root, "lean", -0.35, 0.5)
		tw.parallel().tween_property(inner, "scale", Vector3(base_sc.x * 1.5, base_sc.y * 0.12, base_sc.z * 1.5), 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_hide_body)
	else:
		_spawn_puddle(false)
		if mesh_root != null:
			mesh_root.visible = false
			mesh_root.set_process(false)


func _hide_body() -> void:
	if mesh_root != null:
		mesh_root.visible = false
		mesh_root.set_process(false)


func _spawn_puddle(animated: bool) -> void:
	if puddle != null:
		return
	puddle = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.75
	c.bottom_radius = 0.8
	c.height = 0.04
	c.radial_segments = 9
	c.rings = 0
	puddle.mesh = c
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/psx.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://assets/tex/damaged_plaster.png"))
	m.set_shader_parameter("albedo_color", Color(0.78, 0.66, 0.45))
	m.set_shader_parameter("tex_mix", 0.5)
	m.set_shader_parameter("emission", 0.05)
	puddle.material_override = m
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puddle)
	puddle.top_level = true
	puddle.global_position = Vector3(global_position.x, global_position.y + 0.02, global_position.z)
	# a few lumps that used to be a head and hands
	for o in [Vector3(0.25, 0.05, 0.1), Vector3(-0.3, 0.04, -0.15), Vector3(0.05, 0.07, -0.3)]:
		var lump := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.12
		sm.radial_segments = 6
		sm.rings = 3
		lump.mesh = sm
		lump.material_override = m
		lump.position = o
		puddle.add_child(lump)
	if animated:
		puddle.scale = Vector3(0.1, 1.0, 0.1)
		var tw := create_tween()
		tw.tween_property(puddle, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if dead or Game.mode != "play" or Game.state["active"] != map:
		velocity.x = 0.0
		velocity.z = 0.0
		if not dead:
			move_and_slide()
		return
	t += delta
	var p = main.players[map]
	var d: float = global_position.distance_to(p.global_position)
	atk_cd -= delta
	stagger -= delta
	groan_cd -= delta
	attack_t = maxf(0.0, attack_t - delta)
	if not awake and (d < 4.5 or (p.light_on and d < 7.0)):
		awake = true
		main.play_sfx("groan_1", global_position, 4.0)
		main.tutorial("aim", "Hold %s to aim at it, then %s to shoot." % [Game.glyph("aim"), Game.glyph("fire")])
	if groan_cd <= 0.0 and d < 14.0:
		groan_cd = randf_range(3.0, 6.0)
		main.play_sfx("groan_%d" % (randi() % 4 + 1), global_position)
	velocity.x = push.x
	velocity.z = push.z
	push = push.move_toward(Vector3.ZERO, 9.0 * delta)
	if awake and stagger <= 0.0 and d < 11.0:
		if d < 1.15:
			if atk_cd <= 0.0:
				atk_cd = 1.6
				attack_t = 0.9
				main.hurt_player(map, 1)
		else:
			var wp: Vector3 = main.next_waypoint(map, global_position, p.global_position, [])
			var dir: Vector3 = wp - global_position
			dir.y = 0.0
			dir = dir.normalized()
			velocity.x += dir.x * speed
			velocity.z += dir.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 3.0 * delta)
	move_and_slide()
	if mesh_root != null and stagger <= 0.0:
		if not awake:
			mesh_root.play_anim("Zombie_Scratch", 0.3, 0.8)
		elif attack_t > 0.0:
			mesh_root.play_anim("Zombie_Scratch", 0.1, 1.6)
		elif Vector2(velocity.x, velocity.z).length() > 0.1:
			mesh_root.play_anim("Zombie_Walk_Fwd", 0.3, speed / (1.0 * mesh_root.inner.scale.z))   # stride-matched
		else:
			mesh_root.play_anim("Zombie_Idle", 0.3)
