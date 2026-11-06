extends Node
## Automated smoke test: run with  godot --headless -- --smoke
var m
var f := 0
var log_lines: Array = []

func ok(cond: bool, what: String) -> void:
	var line := ("PASS " if cond else "FAIL ") + what
	print(line)

func near_item(id: String) -> Dictionary:
	for it in m.interactables:
		if it["id"] == id:
			return it
	return {}

func tp(who: String, it: Dictionary) -> void:
	var p = m.players[who]
	p.global_position = Vector3(it["point"].x, 0.05, it["point"].z)

func _ready() -> void:
	m = get_parent()

func _process(_d: float) -> void:
	f += 1
	match f:
		5:
			Game.mode = "play"
			m.hud.hide_overlay()
			Input.action_press("move_forward")
		40:
			Input.action_release("move_forward")
			var p = m.players["jenny"]
			ok(p.global_position.distance_to(m._off("jenny", Vector2i(0,0), Vector3(-1,0,0.5))) > 0.5, "Jenny moves with tank controls")
			var fuse = near_item("fuse")
			tp("jenny", fuse)
			m._interact(fuse)
			ok(Game.has_item("jenny", "Fuse"), "Jenny picks up Fuse")
			tp("jenny", near_item("tube_jenny"))
			m._open_tube()
			m.menu_cb.call(0)
			ok(Game.state["tube"]["dana"].has("Fuse"), "Fuse sent through tube")
			m._switch_to("dana")
		60:
			ok(Game.state["active"] == "dana" and m.cur_cam_key.begins_with("dana"), "Switched to Dana + camera")
			tp("dana", near_item("tube_dana"))
			m._open_tube()
			ok(Game.has_item("dana", "Fuse"), "Dana receives Fuse")
			m._close_menu()
			var p = m.players["dana"]
			var z = m.zombies[0]
			p.global_position = z.global_position + Vector3(-4, 0, 0)
			p.look_at(z.global_position, Vector3.UP)
		70:
			var p = m.players["dana"]
			var t = m.find_aim_target(p)
			ok(t != null, "Aim auto-targets Tallow-folk")
			for i in 3:
				m.fire_cd = 0.0
				m.fire(p, t)
			ok(m.zombies[0].dead, "Three shots kill Tallow-folk")
			var fb = near_item("fusebox")
			tp("dana", fb)
			m._interact(fb)
			ok(Game.flag("power") and not m.doors.has("evidence"), "Fuse powers evidence door")
		80:
			var key = near_item("tower_key")
			tp("dana", key)
			m._interact(key)
			ok(Game.has_item("dana", "Tower Key"), "Dana gets Tower Key")
			var w = m.next_waypoint("dana", m._off("dana", Vector2i(0,0), Vector3.ZERO), m._off("dana", Vector2i(2,0), Vector3.ZERO), [])
			ok(w.distance_to(m._off("dana", Vector2i(0,0), Vector3(4,0,0))) < 0.1, "Pathfinding via doorway")
			tp("dana", near_item("tube_dana"))
			m._open_tube()
			var idx = -1
			for i in m.menu_options.size():
				if str(m.menu_options[i]).contains("Tower Key"):
					idx = i
			m.menu_cb.call(idx)
			Game.save_game()
			ok(Game.has_save(), "Save written")
			m._switch_to("jenny")
		100:
			# Bellman chase test
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(1,0), Vector3(0,0.05,0))
			var b = m.bellman
			b.global_position = m._off("jenny", Vector2i(1,0), Vector3(3,0.05,0))
			b.look_at(p.global_position, Vector3.UP)
			b.dormant_t = 5.0
			b.think_t = 0.0
		160:
			ok(m.bellman.state == m.bellman.S.CHASE or Game.mode == "struggle", "Bellman spots Jenny and chases (state %d, mode %s)" % [m.bellman.state, Game.mode])
		300:
			ok(Game.mode == "struggle" or m.bellman.state == m.bellman.S.STUNNED, "Bellman grabs Jenny -> struggle (mode %s)" % Game.mode)
			if Game.mode == "struggle":
				m.struggle_count = 999
		305:
			ok(Game.mode == "play" and m.bellman.state == m.bellman.S.STUNNED, "Winning struggle stuns Bellman")
			# hide test
			var hid = near_item("hide_corr")
			tp("jenny", hid)
			m._interact(hid)
			ok(m.players["jenny"].hidden_in == "hide_corr", "Hide in closet")
			m._unhide(m.players["jenny"])
			tp("jenny", near_item("tube_jenny"))
			m._open_tube()
			ok(Game.has_item("jenny", "Tower Key"), "Jenny receives Tower Key")
			m._close_menu()
			var ex = near_item("chapel_exit")
			tp("jenny", ex)
			m._interact(ex)
			ok(Game.mode == "win", "Chapel exit -> WIN screen")
			print(m.hud.ov_body.text)
		320:
			ok(Game.load_game() and Game.state["inv"]["jenny"].has("Tower Key") == false, "Save loads (snapshot before key handoff)")
			print("SMOKE DONE")
			get_tree().quit()
