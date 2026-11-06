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
	# Headless runs uncapped; cap the frame rate so the frame-numbered steps
	# below cover real time (fixes the old "Jenny moves" flake).
	Engine.max_fps = 60
	Game.tank_controls = true
	if Game.smoke_phase == 2:
		set_process(false)
		_after_retry.call_deferred()


func _after_retry() -> void:
	# We are in a freshly reloaded scene after choosing "Retry from last save".
	for i in 10:
		await get_tree().process_frame
	ok(Game.mode == "play" and Game.state["active"] == "dana" and Game.state["tube"]["jenny"].has("Tower Key") and Game.state["files"].size() == 2 and int(Game.state["hp"]["dana"]) > 0, "Death -> Retry from last save restores the save (mode %s, active %s)" % [Game.mode, Game.state["active"]])
	Game.smoke_phase = 0
	print("SMOKE DONE")
	get_tree().quit()

func _process(_d: float) -> void:
	f += 1
	match f:
		3:
			ok(str(Game.get_script().resource_path).ends_with("GameState.cs") and str(m.bellman.get_script().resource_path).ends_with("Bellman.cs") and str(m.graph.get_script().resource_path).ends_with("WaypointGraph.cs"), "C# systems loaded (Game autoload, Bellman AI, waypoint graph)")
			ok(m.current_objective().contains("Playroom"), "Objective reminder at start: " + m.current_objective())
			# Settings: change brightness, check it reaches the shader and user://settings.cfg.
			var old_b: float = Game.settings["brightness"]
			m._open_settings(true)
			ok(Game.mode == "menu" and m.menu_title == "SETTINGS" and m.menu_options.size() >= 13, "Settings menu opens (%d rows)" % m.menu_options.size())
			m._adjust_setting(0, 1)
			var cf := ConfigFile.new()
			cf.load(Game.SETTINGS_PATH)
			ok(is_equal_approx(float(m.post_mat.get_shader_parameter("gamma")), old_b + 0.1) and is_equal_approx(float(cf.get_value("settings", "brightness", -1.0)), old_b + 0.1), "Brightness applies and persists to settings.cfg")
			m._adjust_setting(7, 1)
			ok(m.players["dana"].flashlight.shadow_enabled == bool(Game.settings["shadows"]), "Shadow toggle reaches the flashlight")
			m._adjust_setting(7, 1)
			m._adjust_setting(0, -1)
			Game.load_settings()
			ok(is_equal_approx(float(Game.settings["brightness"]), old_b), "Settings reload from disk")
			m._close_settings()
			ok(Game.mode == "title", "Settings BACK returns to title")
			Game.tank_controls = true
		5:
			Game.mode = "play"
			m.hud.hide_overlay()
			Game.set_flag("intro_done")
			Input.action_press("move_forward")
		40:
			Input.action_release("move_forward")
			var p = m.players["jenny"]
			ok(p.global_position.distance_to(m._off("jenny", Vector2i(0,0), Vector3(-1,0,0.5))) > 0.3, "Jenny moves with tank controls")
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
			ok(m.hud.get_bg.visible and m.hud.get_title.text == "TOWER KEY", "Item-get banner shows name + description")
			ok(m.current_objective().contains("send the Tower Key"), "Objective updates: " + m.current_objective())
			# Lore files
			for fid in ["file_meridian", "file_choir"]:
				var it = near_item(fid)
				ok(not it.is_empty(), "Lore file placed: " + fid)
				if not it.is_empty():
					tp("dana", it)
					m._interact(it)
			ok(Game.mode == "note" and m.hud.ov_title.text == "Field Report: The Stone", "Reading a file shows it")
			m.hud.hide_overlay()
			Game.mode = "play"
			ok(Game.state["files"].has("file_meridian") and Game.state["files"].has("file_choir"), "Files are kept for re-reading")
			m._open_inventory()
			ok(m.hud.ov_body.text.contains("9mm") and m.hud.ov_body.text.contains("Files (2)"), "Inventory shows item descriptions + files")
			m._close_menu()
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
			ok(m.bellman.state == m.bellman.S.CHASE or m.bellman.state == m.bellman.S.NOTICE or Game.mode == "struggle", "Bellman spots Jenny and chases (state %d, mode %s)" % [m.bellman.state, Game.mode])
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
			m._show_end_card()
			var t: String = m.end_card_text()
			ok(Game.mode == "endcard" and t.contains("THANKS FOR PLAYING") and t.contains("demo") and t.contains("coming soon") and m.credits_lbl.text.contains("Quaternius"), "Demo end card + credits roll")
			ok(m.credits_music != null and m.credits_music.stream != null and m.credits_lbl.text.contains("Main Theme"), "End credits play the sung main theme")
		320:
			ok(Game.load_game() and Game.state["inv"]["jenny"].has("Tower Key") == false, "Save loads (snapshot before key handoff)")
			# Death -> retry from last save (continues in the reloaded scene).
			Game.mode = "play"
			m.die("Test death.")
		400:
			ok(Game.mode == "dead" and m.hud.overlay.visible and m.hud.ov_body.text.contains("Retry from last save"), "Death screen offers Retry from last save")
			Game.smoke_phase = 2
			m.death_choose(0)
