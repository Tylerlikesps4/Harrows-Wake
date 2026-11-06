extends CharacterBody3D
## Survivor controller: modern camera-relative (default on phones) or classic
## tank controls. Smooth acceleration and turning, a flashlight, animations.

var who: String = "jenny"
var main = null
var active: bool = false
var frozen: bool = false
var hidden_in: String = ""
var walk_speed: float = 1.7
var run_speed: float = 4.0
var turn_speed: float = 2.8
var stamina: float = 100.0
var exhausted: bool = false
var aiming: bool = false
var aim_target = null
var quick_turning: bool = false
var mesh_root: Node3D = null      # actor_model.gd instance
var step_t: float = 0.0
var noise_t: float = 0.0
var invuln: float = 0.0
var flashlight: SpotLight3D = null
var light_on: bool = false
var hvel := Vector3.ZERO          # smoothed horizontal velocity
var move_basis_cam: Camera3D = null  # camera whose frame movement uses (held across cuts)
var breath: float = 1.0           # Jenny holding her breath while hidden
var holding_breath: bool = false
var shoot_t: float = 0.0
var acting_t: float = 0.0
var laser: MeshInstance3D = null
var laser_dot: MeshInstance3D = null
var turning_in_place: bool = false
# Ground speed (m/s) of each animation at scale 1, measured from the foot bones
# (tools/measure.gd). Playback speed = actual speed / (native * model scale),
# so feet stay planted instead of sliding.
const NATIVE_SPEED := {"Walk": 1.0, "Jog_Fwd": 2.5, "Sprint": 3.3}


func _ready() -> void:
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.93, 0.78)
	flashlight.light_energy = 3.2
	flashlight.spot_range = 11.0
	flashlight.spot_angle = 26.0
	flashlight.spot_attenuation = 0.9
	flashlight.spot_angle_attenuation = 1.6
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.12, 1.25, -0.25)
	flashlight.rotation.x = deg_to_rad(-8.0)
	flashlight.visible = false
	add_child(flashlight)
	# Aim laser (Dana): a thin additive beam plus a dot where it lands.
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lm.albedo_color = Color(1.0, 0.1, 0.05, 0.75)
	lm.no_depth_test = false
	laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 1.0)
	laser.mesh = bm
	laser.material_override = lm
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser.top_level = true
	laser.visible = false
	add_child(laser)
	laser_dot = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	laser_dot.mesh = sm
	var dm: StandardMaterial3D = lm.duplicate()
	dm.albedo_color = Color(1.0, 0.25, 0.15, 1.0)
	laser_dot.material_override = dm
	laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser_dot.top_level = true
	laser_dot.visible = false
	add_child(laser_dot)


func muzzle_position() -> Vector3:
	var g = mesh_root.extras.get("gun") if mesh_root != null else null
	var fwd: Vector3 = -global_transform.basis.z
	if g != null and g.is_inside_tree():
		return g.global_position + fwd * 0.22 + Vector3(0, 0.05, 0)
	return global_position + Vector3(0, 1.35, 0) + fwd * 0.6


## Recoil: the upper body kicks back and settles.
func recoil() -> void:
	if mesh_root == null:
		return
	var tw := create_tween()
	tw.tween_property(mesh_root, "lean", -0.09, 0.04)
	tw.tween_property(mesh_root, "lean", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_laser() -> void:
	var on: bool = aiming and visible and main != null
	laser.visible = on
	laser_dot.visible = on
	if not on:
		return
	var from: Vector3 = muzzle_position()
	var dir: Vector3 = -global_transform.basis.z
	var to: Vector3 = from + dir * 12.0
	if aim_target != null and is_instance_valid(aim_target):
		to = aim_target.global_position + Vector3(0, 1.25, 0)
		dir = (to - from).normalized()
	else:
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			to = hit["position"]
	var length := from.distance_to(to)
	laser.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT), (from + to) / 2.0)
	laser.scale = Vector3(1, 1, maxf(0.05, length))
	laser_dot.global_position = to - dir * 0.03
	# Locked on: the dot pulses a little bigger.
	var pulse := 1.0 + (0.5 * absf(sin(Time.get_ticks_msec() / 90.0)) if aim_target != null else 0.0)
	laser_dot.scale = Vector3.ONE * pulse


func set_light(on: bool) -> void:
	light_on = on
	flashlight.visible = on and hidden_in == ""
	Game.state["light"][who] = on


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.1
	invuln = maxf(0.0, invuln - delta)
	shoot_t = maxf(0.0, shoot_t - delta)
	acting_t = maxf(0.0, acting_t - delta)
	var playing: bool = Game.mode == "play"
	flashlight.visible = light_on and hidden_in == "" and visible
	if not active or frozen or not playing or hidden_in != "":
		hvel = hvel.lerp(Vector3.ZERO, minf(1.0, 12.0 * delta))
		velocity.x = 0.0
		velocity.z = 0.0
		aiming = false
		move_and_slide()
		if active and playing and hidden_in != "":
			stamina = minf(100.0, stamina + 15.0 * delta)
		_animate(0.0, false)
		_update_laser()
		return

	if Input.is_action_just_pressed("flashlight"):
		set_light(not light_on)
		main.play_sfx("flashlight", null, -6.0)
		main.tutorial("flashlight_cost", "A light helps you see - and helps HIM see you." if who == "jenny" else "")

	var iv: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if bool(Game.settings.get("invert_y", false)):
		iv.y = -iv.y
	turning_in_place = false
	var want_run: bool = Input.is_action_pressed("run")
	var target := Vector3.ZERO
	var running := false

	aiming = who == "dana" and Input.is_action_pressed("aim") and Game.has_item("dana", "Handgun")
	if aiming:
		aim_target = main.find_aim_target(self)
		if aim_target != null:
			var to: Vector3 = aim_target.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 12.0 * delta)
		else:
			rotation.y -= iv.x * turn_speed * delta
		if Input.is_action_just_pressed("fire"):
			main.fire(self, aim_target)
			shoot_t = 0.35
	elif not quick_turning:
		var spd := walk_speed
		if Game.tank_controls:
			rotation.y -= iv.x * turn_speed * delta
			turning_in_place = absf(iv.x) > 0.2 and absf(iv.y) <= 0.1
			if iv.y < -0.1:
				running = want_run and not exhausted
				spd = run_speed if running else walk_speed
				target = -global_transform.basis.z * spd * minf(1.0, -iv.y * 1.3)
			elif iv.y > 0.1:
				target = global_transform.basis.z * walk_speed * 0.6
				if Input.is_action_just_pressed("run"):
					_quick_turn()
			if Input.is_action_just_pressed("quick_turn"):
				_quick_turn()
		else:
			var cam: Camera3D = get_viewport().get_camera_3d()
			# Keep using the old camera's frame while the stick is held through a
			# camera cut, so "up" doesn't suddenly mean a different direction.
			if iv.length() < 0.15 or move_basis_cam == null or not is_instance_valid(move_basis_cam):
				move_basis_cam = cam
			var bc: Camera3D = move_basis_cam if move_basis_cam != null else cam
			if bc != null and iv.length() > 0.12:
				var f: Vector3 = -bc.global_transform.basis.z
				f.y = 0.0
				f = f.normalized()
				var r: Vector3 = bc.global_transform.basis.x
				r.y = 0.0
				r = r.normalized()
				var dir: Vector3 = (r * iv.x + f * (-iv.y)).normalized()
				running = want_run and not exhausted
				spd = run_speed if running else walk_speed
				# Turn first, then go: big direction changes pivot on the spot
				# (speed scales with how closely she faces the stick), so there's
				# no moonwalking or skating sideways.
				var want_yaw := atan2(-dir.x, -dir.z)
				var diff := absf(angle_difference(rotation.y, want_yaw))
				var facing := clampf(cos(diff) * 1.25, 0.0, 1.0) if diff > 0.35 else 1.0
				target = (-global_transform.basis.z) * spd * minf(1.0, iv.length() * 1.25) * facing
				rotation.y = rotate_toward(rotation.y, want_yaw, (11.0 if diff > 1.2 else 7.0) * delta)
				turning_in_place = facing < 0.3
			if Input.is_action_just_pressed("quick_turn"):
				_quick_turn()
		if who == "jenny" and main != null:
			target *= 1.0 - main.panic * 0.0025

	# Smooth acceleration / deceleration.
	var accel := 9.0 if target.length() > hvel.length() else 12.0
	hvel = hvel.lerp(target, minf(1.0, accel * delta))
	if target == Vector3.ZERO and hvel.length() < 0.05:
		hvel = Vector3.ZERO

	# Stamina (Jenny tires; Dana is trained).
	if running and hvel.length() > 0.5:
		stamina -= (24.0 if who == "jenny" else 10.0) * delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			main.play_sfx("breath", global_position, -2.0)
	else:
		stamina = minf(100.0, stamina + 12.0 * delta)
		if exhausted and stamina > 35.0:
			exhausted = false

	velocity.x = hvel.x
	velocity.z = hvel.z
	move_and_slide()
	_update_laser()

	# Footsteps by floor surface, and noise the Bellman can hear.
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > 0.25:
		step_t += delta * sp
		noise_t -= delta
		if step_t > (0.72 if sp < 3.0 else 0.95):
			step_t = 0.0
			main.play_step(global_position, main.floor_at(who, global_position), -8.0 if sp < 3.0 else -1.0)
		if noise_t <= 0.0:
			noise_t = 0.3
			main.make_noise(global_position, 8.0 if sp > 3.0 else 2.2)
	_animate(sp, running)


func _animate(sp: float, running: bool) -> void:
	if mesh_root == null:
		return
	var g: Node3D = mesh_root.extras.get("gun")
	if g != null:
		g.visible = aiming or shoot_t > 0.0
	if mesh_root.cur_anim == "Death01":
		return
	if acting_t > 0.0:
		return
	if aiming:
		if shoot_t > 0.2:
			mesh_root.play_anim("Pistol_Shoot", 0.05)
		else:
			mesh_root.play_anim("Pistol_Aim_Neutral", 0.15)
	var msc: float = mesh_root.inner.scale.z if mesh_root.inner != null else 1.0
	if sp > 2.6:
		var run_anim := "Sprint" if who == "dana" else "Jog_Fwd"
		mesh_root.play_anim(run_anim, 0.22, clampf(sp / (NATIVE_SPEED[run_anim] * msc), 0.6, 2.2))
	elif sp > 0.2:
		mesh_root.play_anim("Walk", 0.22, clampf(sp / (NATIVE_SPEED["Walk"] * msc), 0.45, 2.4))
	elif turning_in_place:
		# Turning on the spot: shuffle the feet instead of spinning a statue.
		mesh_root.play_anim("Walk", 0.18, 0.75)
	else:
		mesh_root.play_anim("Idle", 0.3)


func act(anim_name: String, secs: float) -> void:
	if mesh_root != null:
		mesh_root.play_once(anim_name, 0.15, 1.4)
		acting_t = secs


func _quick_turn() -> void:
	quick_turning = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + PI, 0.28)
	tw.finished.connect(func() -> void: quick_turning = false)
