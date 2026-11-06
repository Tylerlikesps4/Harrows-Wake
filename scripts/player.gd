extends CharacterBody3D
## Survivor controller: modern camera-relative (default on phones) or classic
## tank controls. Smooth acceleration and turning, a flashlight, animations.

var who: String = "jenny"
var main = null
var active: bool = false
var frozen: bool = false
var hidden_in: String = ""
var walk_speed: float = 1.9
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
		return

	if Input.is_action_just_pressed("flashlight"):
		set_light(not light_on)
		main.play_sfx("flashlight", null, -6.0)
		main.tutorial("flashlight_cost", "A light helps you see - and helps HIM see you." if who == "jenny" else "")

	var iv: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
				target = dir * spd * minf(1.0, iv.length() * 1.25)
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 9.0 * delta)
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
	elif sp > 3.0:
		mesh_root.play_anim("Sprint" if who == "dana" else "Jog_Fwd", 0.2, sp / 4.2)
	elif sp > 0.25:
		var wspd := sp / 1.6
		if who == "jenny" and main != null and main.panic > 50.0:
			wspd *= 1.1
		mesh_root.play_anim("Walk", 0.2, clampf(wspd, 0.5, 1.5))
	else:
		mesh_root.play_anim("Idle", 0.25)


func act(anim_name: String, secs: float) -> void:
	if mesh_root != null:
		mesh_root.play_once(anim_name, 0.15, 1.4)
		acting_t = secs


func _quick_turn() -> void:
	quick_turning = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + PI, 0.28)
	tw.finished.connect(func() -> void: quick_turning = false)
