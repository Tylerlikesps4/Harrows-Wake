extends CharacterBody3D
## Survivor controller: classic tank controls or modern camera-relative.

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
var mesh_root: Node3D = null
var step_t: float = 0.0
var noise_t: float = 0.0
var bob_t: float = 0.0
var invuln: float = 0.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.1
	invuln = maxf(0.0, invuln - delta)
	var playing: bool = Game.mode == "play"
	if not active or frozen or not playing or hidden_in != "":
		velocity.x = 0.0
		velocity.z = 0.0
		aiming = false
		move_and_slide()
		if active and playing and hidden_in != "":
			stamina = minf(100.0, stamina + 15.0 * delta)
		return

	var iv: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var want_run: bool = Input.is_action_pressed("run")
	var move := Vector3.ZERO
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
	elif not quick_turning:
		var spd := walk_speed
		if Game.tank_controls:
			rotation.y -= iv.x * turn_speed * delta
			if iv.y < -0.1:
				running = want_run and not exhausted
				spd = run_speed if running else walk_speed
				move = -global_transform.basis.z * spd * minf(1.0, -iv.y * 1.3)
			elif iv.y > 0.1:
				move = global_transform.basis.z * walk_speed * 0.6
				if Input.is_action_just_pressed("run"):
					_quick_turn()
			if Input.is_action_just_pressed("quick_turn"):
				_quick_turn()
		else:
			var cam: Camera3D = get_viewport().get_camera_3d()
			if cam != null and iv.length() > 0.1:
				var f: Vector3 = -cam.global_transform.basis.z
				f.y = 0.0
				f = f.normalized()
				var r: Vector3 = cam.global_transform.basis.x
				r.y = 0.0
				r = r.normalized()
				var dir: Vector3 = (r * iv.x + f * (-iv.y)).normalized()
				running = want_run and not exhausted
				spd = run_speed if running else walk_speed
				move = dir * spd * minf(1.0, iv.length() * 1.3)
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
			if Input.is_action_just_pressed("quick_turn"):
				_quick_turn()
		if who == "jenny" and main != null:
			move *= 1.0 - main.panic * 0.0025

	# Stamina (Jenny tires; Dana is trained).
	if running and move.length() > 0.5:
		stamina -= (24.0 if who == "jenny" else 10.0) * delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
	else:
		stamina = minf(100.0, stamina + 12.0 * delta)
		if exhausted and stamina > 35.0:
			exhausted = false

	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()

	# Footsteps, noise, stiff PS1 bob.
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > 0.2:
		bob_t += delta * sp * 3.2
		step_t += delta * sp
		noise_t -= delta
		if step_t > 0.85:
			step_t = 0.0
			main.play_sfx("step", global_position, -6.0 if sp < 3.0 else 0.0)
		if noise_t <= 0.0:
			noise_t = 0.3
			main.make_noise(global_position, 8.0 if sp > 3.0 else 2.2)
	if mesh_root != null:
		mesh_root.position.y = absf(sin(bob_t)) * 0.05


func _quick_turn() -> void:
	quick_turning = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + PI, 0.28)
	tw.finished.connect(func() -> void: quick_turning = false)
