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


func die() -> void:
	dead = true
	Game.set_flag(id + "_dead")
	collision_layer = 0
	if mesh_root != null and is_inside_tree():
		main.play_sfx("zombie_die", global_position)
		mesh_root.play_once("Hit_Knockback", 0.05, 1.0)
		var tw := create_tween()
		tw.tween_property(mesh_root, "lean", -PI / 2.0, 0.7).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(mesh_root, "y_off", 0.2, 0.7).set_delay(0.3)
		tw.tween_callback(func() -> void: mesh_root.anim.pause())
	elif mesh_root != null:
		mesh_root.lean = -PI / 2.0
		mesh_root.y_off = 0.2
		mesh_root.anim.pause()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if dead or Game.mode != "play" or Game.state["active"] != map:
		velocity.x = 0.0
		velocity.z = 0.0
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
	velocity.x = 0.0
	velocity.z = 0.0
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
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 3.0 * delta)
	move_and_slide()
	if mesh_root != null and stagger <= 0.0:
		if not awake:
			mesh_root.play_anim("Zombie_Scratch", 0.3, 0.8)
		elif attack_t > 0.0:
			mesh_root.play_anim("Zombie_Scratch", 0.1, 1.6)
		elif Vector2(velocity.x, velocity.z).length() > 0.1:
			mesh_root.play_anim("Zombie_Walk_Fwd", 0.3, 0.9)
		else:
			mesh_root.play_anim("Zombie_Idle", 0.3)
