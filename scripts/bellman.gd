extends CharacterBody3D
## The Bellman: unkillable stalker. Sees, hears, searches, can be stunned.

enum S { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, FOUND, STUNNED, LEAVE, NOTICE }

var state: int = S.DORMANT
var main = null
var map: String = "jenny"
var target := Vector3.ZERO
var last_seen := Vector3.ZERO
var lost_t: float = 0.0
var timer: float = 0.0
var think_t: float = 0.0
var bell_t: float = 2.0
var dormant_t: float = 14.0
var sees: bool = false
var patrol_cells: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1)]
var blocked: Array = [Vector2i(1, 1)]
var home_cell := Vector2i(2, 0)
var mesh_root: Node3D = null
var t: float = 0.0
var step_t: float = 0.0
var notice_t: float = 0.0
var grab_cd: float = 0.0
var grabbing_t: float = 0.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if Game.mode != "play" or Game.state["active"] != map:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	t += delta
	grab_cd = maxf(0.0, grab_cd - delta)
	grabbing_t = maxf(0.0, grabbing_t - delta)
	var p = main.players[map]
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.15
		_perceive(p)

	var spd: float = 0.0
	match state:
		S.DORMANT:
			dormant_t -= delta
			if dormant_t <= 0.0:
				_pick_patrol()
		S.PATROL:
			spd = 1.35
			if _arrived(target):
				spd = 0.0
				timer -= delta
				if timer <= 0.0:
					_pick_patrol()
		S.INVESTIGATE:
			spd = 2.1
			if _arrived(target):
				state = S.SEARCH
				timer = 4.0
		S.NOTICE:
			# Readable telegraph: he stops, turns to you, the bell shrieks - then comes.
			notice_t -= delta
			var to: Vector3 = p.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 8.0 * delta)
			if notice_t <= 0.0:
				state = S.CHASE
				lost_t = 0.0
		S.CHASE:
			spd = 3.0 if not p.exhausted else 2.7
			target = last_seen
			if sees:
				lost_t = 0.0
			else:
				lost_t += delta
			if lost_t > 3.0 or (_arrived(target) and not sees):
				state = S.SEARCH
				timer = 5.0
			if sees and _flat_dist(p.global_position) < 1.3 and grab_cd <= 0.0:
				grabbing_t = 0.6
				main.bellman_grab(1.0)
		S.SEARCH:
			spd = 1.6
			if _arrived(target):
				spd = 0.0
				timer -= delta
				rotation.y += delta * 1.6
				if timer <= 0.0:
					_pick_patrol()
		S.FOUND:
			spd = 2.6
			target = p.global_position
			if _flat_dist(p.global_position) < 1.6 and grab_cd <= 0.0:
				grabbing_t = 0.6
				main.bellman_grab(1.6)
		S.STUNNED:
			timer -= delta
			if timer <= 0.0:
				state = S.LEAVE
				target = main.cell_center(map, home_cell)
		S.LEAVE:
			spd = 1.5
			if _arrived(target):
				state = S.DORMANT
				dormant_t = randf_range(12.0, 20.0)

	velocity.x = 0.0
	velocity.z = 0.0
	if spd > 0.0 and not _arrived(target):
		var wp: Vector3 = main.next_waypoint(map, global_position, target, blocked)
		var dir: Vector3 = wp - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			dir = dir.normalized()
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
	move_and_slide()

	# The bell: you hear him before you see him.
	bell_t -= delta
	if bell_t <= 0.0:
		var interval := 3.2
		match state:
			S.CHASE, S.FOUND, S.NOTICE:
				interval = 0.85
			S.INVESTIGATE, S.SEARCH:
				interval = 1.8
			S.DORMANT:
				interval = 7.0
			S.STUNNED:
				interval = 99.0
		bell_t = interval
		main.play_sfx("bell", global_position + Vector3(0, 1.8, 0), 0.0)

	# Heavy, unhurried footsteps - audible through walls before he's in view.
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.2:
		step_t += delta * hs
		if step_t > 1.05:
			step_t = 0.0
			main.play_step(global_position, main.floor_at(map, global_position), 2.0, 0.62, 16.0)
	_animate(hs)


func _animate(hs: float) -> void:
	if mesh_root == null:
		return
	if state == S.STUNNED:
		mesh_root.play_anim("Hit_Chest", 0.1, 0.5)
		mesh_root.lean = lerpf(mesh_root.lean, 0.35, 0.1)
		return
	mesh_root.lean = lerpf(mesh_root.lean, 0.06, 0.1)  # slight forward stoop
	if grabbing_t > 0.0:
		mesh_root.play_anim("Punch_Cross", 0.05, 1.3)
	elif state == S.NOTICE:
		mesh_root.play_anim("Idle_Torch", 0.1, 2.5)   # raises the bell
	elif hs > 0.2:
		mesh_root.play_anim("Walk_Formal", 0.25, clampf(hs / 1.25, 0.7, 2.3))
	else:
		mesh_root.play_anim("Idle_Torch", 0.3, 0.6)


func _perceive(p) -> void:
	sees = false
	if p.hidden_in != "" or state == S.STUNNED or state == S.LEAVE:
		return
	var pc: Vector2i = main.cell_of(map, p.global_position)
	if blocked.has(pc):
		return
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var d: float = to.length()
	var rng: float = 11.0
	if p.light_on:
		rng = 16.0      # a lit flashlight gives you away
	if d > rng:
		return
	var fwd: Vector3 = -global_transform.basis.z
	var ang: float = rad_to_deg(fwd.angle_to(to.normalized())) if d > 0.01 else 0.0
	if (ang < 60.0 or d < 2.5) and main.los(global_position + Vector3(0, 1.7, 0), p.global_position + Vector3(0, 1.0, 0)):
		sees = true
		last_seen = p.global_position
		if state != S.CHASE and state != S.FOUND and state != S.NOTICE:
			state = S.NOTICE
			notice_t = 0.9 if d > 3.0 else 0.45
			lost_t = 0.0
			main.on_chase_start()


func hear(pos: Vector3, radius: float) -> void:
	if state == S.CHASE or state == S.FOUND or state == S.STUNNED or state == S.LEAVE or state == S.NOTICE:
		return
	if blocked.has(main.cell_of(map, pos)):
		return
	if global_position.distance_to(pos) < radius:
		state = S.INVESTIGATE
		target = pos


func on_player_hide(p) -> void:
	if state == S.CHASE or state == S.NOTICE:
		var close: bool = _flat_dist(p.global_position) < 7.0
		if close and lost_t < 0.6 and main.los(global_position + Vector3(0, 1.7, 0), p.global_position + Vector3(0, 1.0, 0)):
			state = S.FOUND
			main.show_message("He saw you hide...")
		else:
			state = S.SEARCH
			target = last_seen
			timer = 5.0


func on_scream() -> void:
	if state != S.STUNNED and state != S.LEAVE:
		state = S.FOUND


func stun(duration: float = 4.0) -> void:
	state = S.STUNNED
	timer = duration
	sees = false
	grab_cd = duration + 2.5


func is_hunting() -> bool:
	return state == S.CHASE or state == S.FOUND or state == S.NOTICE


func _pick_patrol() -> void:
	state = S.PATROL
	var c: Vector2i = patrol_cells[randi() % patrol_cells.size()]
	target = main.cell_center(map, c) + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
	timer = randf_range(1.5, 3.5)


func _arrived(pos: Vector3) -> bool:
	return _flat_dist(pos) < 0.7


func _flat_dist(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
