extends Node
## Screenshot tour: xvfb-run -s "-screen 0 1280x960x24" godot -- --shots
var m
var f := 0
const OUT := "/workspace/work/harrows-wake/shots/"
func _ready() -> void:
	m = get_parent()
	Engine.max_fps = 30
	DirAccess.make_dir_recursive_absolute(OUT)
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot ", n)
func _process(_d: float) -> void:
	f += 1
	match f:
		90: shot("0_title")
		92:
			m.hud.hide_overlay(); Game.mode = "play"; Game.set_flag("intro_done")
			m.post_mat.set_shader_parameter("fade", 0.0)
			m.bellman.set_physics_process(false)
			m.bellman.global_position = Vector3(300,0,300)
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(0,0), Vector3(-0.5,0.05,0.8))
			p.rotation.y = PI * 0.75
		130: shot("1_jenny_dorm")
		132:
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(1,0), Vector3(-2,0.05,1))
			p.rotation.y = -PI/2
			p.set_light(true)
			var b = m.bellman
			b.global_position = m._off("jenny", Vector2i(1,0), Vector3(2.6,0.05,-1.0))
			b.look_at(p.global_position, Vector3.UP)
			b.mesh_root.snap()
			b.mesh_root.play_anim("Walk_Formal", 0.0, 0.0)
			m.panic = 70.0
		175: shot("2_corridor_bellman")
		177:
			m.panic = 0.0
			m.players["jenny"].set_light(false)
			m._switch_to("dana")
			m.post_mat.set_shader_parameter("fade", 0.0)
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(0,0), Vector3(-0.5,0.05,0.5))
			p.rotation.y = PI * 0.8
		220: shot("3_dana_lobby")
		222:
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,0), Vector3(-1.5,0.05,1.5))
			p.rotation.y = -PI/2
			p.set_light(true)
		265: shot("4_hall_tallow")
		267:
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,1), Vector3(1.0,0.05,0.5))
		300: shot("5_records")
		302:
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,-1), Vector3(1.0,0.05,0.0))
		335: shot("6_chief")
		337:
			m._switch_to("jenny")
			m.post_mat.set_shader_parameter("fade", 0.0)
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(2,0), Vector3(-2.5,0.05,0))
			p.rotation.y = -PI/2
			var b = m.bellman
			b.global_position = m._off("jenny", Vector2i(2,0), Vector3(1.5,0.05,0))
			b.look_at(p.global_position, Vector3.UP)
			b.mesh_root.snap()
		380: shot("7_chapel")
		382:
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(1,-1), Vector3(0.5,0.05,1.0))
			m.bellman.global_position = Vector3(300,0,300)
		425: shot("8_playroom")
		427:
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(1,1), Vector3(0.5,0.05,0.5))
		465: shot("9_mailroom")
		467:
			# Character line-up, facing a close camera (checks model facing and clothing).
			var base: Vector3 = m._off("dana", Vector2i(0,0), Vector3(0, 0.05, 0))
			var ps := [m.players["jenny"], m.players["dana"], m.bellman, m.zombies[0]]
			m.zombies[0].set_physics_process(false)
			m.zombies[0].dead = false
			for i in ps.size():
				ps[i].global_position = base + Vector3(-1.8 + i * 1.2, 0, 1.2)
				ps[i].rotation = Vector3(0, 0, 0)
				ps[i].visible = true
				ps[i].mesh_root.snap()
				ps[i].mesh_root.lean = 0.0
			m.players["jenny"].set_light(false)
			m.players["dana"].set_light(false)
			var cam := Camera3D.new()
			m.add_child(cam)
			cam.look_at_from_position(base + Vector3(0, 1.5, -3.0), base + Vector3(0, 1.0, 0), Vector3.UP)
			cam.make_current()
			Game.mode = "menu"
			m.hud.visible = false
		500: shot("c_lineup")
		502: get_tree().quit()
