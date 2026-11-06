extends CharacterBody3D
## Tallow-folk: slow, fused townsperson. Three handgun rounds put it down.

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


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	stagger = 0.7
	main.play_sfx("splat", global_position)
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	Game.set_flag(id + "_dead")
	collision_layer = 0
	if mesh_root != null:
		mesh_root.rotation.x = -PI / 2.0
		mesh_root.position.y = 0.25


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
	if groan_cd <= 0.0 and d < 14.0:
		groan_cd = randf_range(3.0, 6.0)
		main.play_sfx("groan", global_position)
	velocity.x = 0.0
	velocity.z = 0.0
	if stagger <= 0.0 and d < 11.0:
		if d < 1.15:
			if atk_cd <= 0.0:
				atk_cd = 1.6
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
	if mesh_root != null:
		mesh_root.rotation.z = sin(t * 2.2) * 0.15
		if stagger > 0.0:
			mesh_root.rotation.x = 0.35
		else:
			mesh_root.rotation.x = 0.12
