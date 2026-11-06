extends Node
## Screenshot tour: xvfb-run -s "-screen 0 1280x960x24" godot -- --shots
## The game renders at 320x240 (PS1 resolution); shots are upscaled 4x with
## nearest filtering to 1280x960 so they look like the real window.
var m
var f := 0
const OUT := "/workspace/work/harrows-wake/shots/"
var only := ""
var tag := "b9"
var docs: Array = []
func _ready() -> void:
	m = get_parent()
	Engine.max_fps = 30
	DirAccess.make_dir_recursive_absolute(OUT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a.begins_with("--tag="):
			tag = a.substr(6)
func shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(1280, 960, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT + "b9_" + n + ".png")
	print("shot ", n)
## Native-resolution shot (phones/tablets): the window size is the device size.
func shot_native(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var ws := DisplayServer.window_get_size()
	img.resize(ws.x, ws.y, Image.INTERPOLATE_NEAREST)
	var fn := OUT + "docs/%s_%dx%d_%s.png" % [tag, ws.x, ws.y, n]
	img.save_png(fn)
	print("shot ", fn)
func lineup(close: bool, mask: bool = false) -> void:
	var base: Vector3 = m._off("dana", Vector2i(0,0), Vector3(0, 0.05, 0))
	var ps := [m.players["jenny"], m.players["dana"], m.bellman, m.zombies[0]]
	m.zombies[0].set_physics_process(false)
	m.bellman.set_physics_process(false)
	for i in ps.size():
		ps[i].global_position = base + Vector3(-1.8 + i * 1.2, 0, 1.2)
		ps[i].rotation = Vector3(0, 0, 0)
		ps[i].visible = true
		ps[i].mesh_root.snap()
		ps[i].mesh_root.lean = 0.0
		ps[i].mesh_root.play_anim(ps[i].mesh_root.idle_name(), 0.0, 0.0)
	m.get_node("dana").visible = true
	m.players["jenny"].set_light(false)
	m.players["dana"].set_light(false)
	var key := OmniLight3D.new()
	key.omni_range = 6.0
	key.light_energy = 1.4
	m.add_child(key)
	key.global_position = base + Vector3(0, 2.0, -1.0)
	var cam := Camera3D.new()
	m.add_child(cam)
	if mask:
		cam.fov = 30.0
		key.global_position = base + Vector3(0.6, 2.4, -0.6)
		cam.look_at_from_position(base + Vector3(0.6, 2.2, -0.9), base + Vector3(0.6, 2.05, 1.2), Vector3.UP)
	elif close:
		cam.fov = 34.0
		cam.look_at_from_position(base + Vector3(-1.2, 1.65, -1.2), base + Vector3(-1.2, 1.45, 1.2), Vector3.UP)
	else:
		cam.look_at_from_position(base + Vector3(0, 1.5, -3.0), base + Vector3(0, 1.0, 0), Vector3.UP)
	cam.make_current()
	Game.mode = "menu"
	m.hud.visible = false
	m.touch.visible = false
func play_setup() -> void:
	m.hud.hide_overlay(); Game.mode = "play"; Game.set_flag("intro_done")
	m.post_mat.set_shader_parameter("fade", 0.0)
	m.bellman.set_physics_process(false)
	m.bellman.global_position = Vector3(300,0,300)
func _process(_d: float) -> void:
	f += 1
	if only == "rooms":
		match f:
			20:
				play_setup()
				Game.settings["doors"] = false
				m._switch_to("dana")
				var p = m.players["dana"]
				p.global_position = m._off("dana", Vector2i(1,-1), Vector3(-0.8,0.05,0.6))
				p.rotation.y = PI * 0.9
			70:
				m.post_mat.set_shader_parameter("fade", 0.0)
				shot("chief")
				m._switch_to("jenny")
				var p = m.players["jenny"]
				p.global_position = m._off("jenny", Vector2i(1,-1), Vector3(0.5,0.05,1.0))
				p.rotation.y = PI
			130:
				m.post_mat.set_shader_parameter("fade", 0.0)
				shot("playroom")
				Game.settings["doors"] = true
				m.door_cool = 0.0
				m.players["jenny"].global_position = m._off("jenny", Vector2i(1,0), Vector3(0,0.05,-2.0))
			148: shot("door_a")
			158: shot("door_b")
			168: shot("door_c")
			190: get_tree().quit()
		return
	# Every lore document plus the other overlay screens at the window's own size:
	#   xvfb-run -s "-screen 0 2400x1080x24" godot --resolution 2400x1080 -- --shots --only=docs
	if only == "docs":
		if f == 2:
			DirAccess.make_dir_recursive_absolute(OUT + "docs")
			docs = m.NOTES.keys()
		if f == 20:
			play_setup()
		var step := (f - 30) / 12
		var sub := (f - 30) % 12
		if f >= 30 and sub == 0:
			if step < docs.size():
				m._show_note(docs[step])
			elif step == docs.size():
				m._open_pause()
			elif step == docs.size() + 1:
				m._close_menu(); m._open_inventory()
			elif step == docs.size() + 2:
				m._close_menu(); Game.mode = "play"
				m.hud.item_get("Tower Key", m.ITEM_INFO.get("Tower Key", ""))
				m.hud.show_tutorial("Use the typewriter to switch to Dana and collect it. Hold RUN to sprint; the Bellman hears running.")
				m.show_message("The canister rattles away toward Dana.", 5.0)
			elif step == docs.size() + 3:
				m._win()
			elif step == docs.size() + 4:
				m._show_end_card()
			elif step == docs.size() + 5:
				if m.credits_lbl != null:
					m.credits_lbl.visible = false
				m._open_settings(false)
			elif step == docs.size() + 6:
				m._close_menu()
				Game.mode = "title"
				m._show_title()
			elif step == docs.size() + 7:
				m.set_meta("death_reason", "The Bellman's bell stopped. Then it was very close.")
				Game.mode = "dead"
				m.dead_index = 0
				m._render_death()
			else:
				get_tree().quit()
		if f >= 30 and sub == 6:
			var names := docs + ["pause", "inventory", "popups", "win", "endcard", "settings", "title", "death"]
			if step < names.size():
				shot_native(names[step])
			if step < docs.size():
				m.hud.ov_scroll.scroll_vertical = 100000  # the end of a long document
		if f >= 30 and sub == 10 and step < docs.size() and m.hud.overlay_overflows():
			shot_native(docs[step] + "_end")
		return
	if only == "faces":
		match f:
			20: play_setup()
			22: lineup(true)
			60: shot("faces_close")
			62: lineup(true, true)
			95: shot("faces_bellman")
			97: lineup(false)
			130: shot("lineup")
			132: get_tree().quit()
		return
	match f:
		60:
			play_setup()
			m._open_settings(true)
		75: shot("settings")
		77:
			m._close_settings()
			play_setup()
			m._switch_to("dana")
			m.post_mat.set_shader_parameter("fade", 0.0)
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,-1), Vector3(-0.8,0.05,0.6))
			p.rotation.y = PI * 0.9
		125: shot("chief")
		127:
			m._switch_to("jenny")
			m.post_mat.set_shader_parameter("fade", 0.0)
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(1,-1), Vector3(0.5,0.05,1.0))
			p.rotation.y = PI
		175: shot("playroom")
		177:
			m._switch_to("dana")
			m.post_mat.set_shader_parameter("fade", 0.0)
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,0), Vector3(-1.5,0.05,1.5))
			p.look_at(m.zombies[0].global_position, Vector3.UP)
			p.rotation.x = 0.0
			m.zombies[0].set_physics_process(false)
			Input.action_press("aim")
		215: shot("aim_laser")
		217:
			Input.action_release("aim")
			m._open_pause()
		225: shot("pause_objective")
		227:
			m._close_menu()
			m._open_inventory()
		235: shot("inventory")
		237:
			m._close_menu()
			m._win()
		245:
			m._show_end_card()
		300: shot("endcard")
		302: get_tree().quit()
