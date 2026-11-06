extends Node
## Regression tests for bugs fixed in build-9:  godot --headless -- --regress
## One check per fixed bug. The last check reloads the scene (quit to title)
## and finishes in the fresh scene, like the smoke test's retry phase.
var m
var f := 0
var t := 0.0

func ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)

func item(id: String) -> Dictionary:
	for it in m.interactables:
		if it["id"] == id:
			return it
	return {}

func _ready() -> void:
	m = get_parent()
	Engine.max_fps = 60
	process_priority = -10  # run before main so simulated presses are 'just pressed'
	if Game.smoke_phase == 10:
		set_process(false)
		_after_title.call_deferred()

func _start_play(who: String) -> void:
	m.hud.hide_overlay()
	Game.set_flag("intro_done")
	if Game.state["active"] != who:
		m._switch_to(who)
	Game.mode = "play"

func _process(d: float) -> void:
	f += 1
	t += d
	match f:
		3:
			Game.settings["doors"] = false
			_start_play("jenny")
			# Music / SFX volume sliders: players must sit on the buses they control.
			ok(m.title_music.bus == &"Music" and m.credits_music.bus == &"Music", "Title + credits music play on the Music bus")
			m.play_sfx("menu")
			var last: Node = m.get_child(m.get_child_count() - 1)
			ok(last is AudioStreamPlayer and last.bus == &"SFX", "Sound effects play on the SFX bus")
			ok(m.get_node("rain").bus == &"SFX" and m.phone_player.bus == &"SFX", "Ambience and scare sounds follow the SFX volume")
			var old: int = int(Game.settings["music"])
			Game.set_setting("music", 0)
			ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music volume 0 mutes the Music bus")
			Game.set_setting("music", old)
			# Voice limiter: the self-typing typewriter used to stack dozens of players.
			for i in 12:
				m.play_sfx("typewriter", Vector3(100, 1, 0))
			ok(int(m.voices.get("typewriter", 0)) == m.MAX_VOICES, "One sound can't stack past %d voices (%d)" % [m.MAX_VOICES, int(m.voices.get("typewriter", 0))])
			# C# interop must not allocate per frame.
			ok(is_same(m.bellman.S, m.bellman.S), "Bellman.S enum dictionary is cached")
			# Struggle is winnable on a touchscreen.
			m.panic = 100.0
			m.players["jenny"].invuln = 0.0
			m.bellman_grab(1.6)
			ok(Game.mode == "struggle" and m.struggle_need <= 15, "Struggle presses capped (%d)" % m.struggle_need)
			m.struggle_count = 999
		5:
			ok(Game.mode == "play", "Struggle resolves back to play")
			# Bellman stuck: a target he can't reach (the Mail Room he never enters)
			# used to freeze him forever in SEARCH.
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(0, 0), Vector3(-1, 0.05, 0.5))
			p.hidden_in = "test"     # keep him from seeing her
			m.panic = 0.0
			var b = m.bellman
			b.grab_cd = 99.0
			b.global_position = m._off("jenny", Vector2i(1, 0), Vector3(0, 0.05, 1.5))
			b.state = b.S.SEARCH
			b.target = m._off("jenny", Vector2i(1, 1), Vector3(0, 0, 0))
			b.timer = 4.0
			t = 0.0
		300:
			ok(m.bellman.state != m.bellman.S.SEARCH, "Bellman gives up on an unreachable target (state %d)" % m.bellman.state)
			# FOUND used to last forever once you escaped into the Mail Room.
			var p = m.players["jenny"]
			p.hidden_in = ""
			p.global_position = m._off("jenny", Vector2i(1, 1), Vector3(0, 0.05, 0))
			m.bellman.global_position = m._off("jenny", Vector2i(2, 0), Vector3(2, 0.05, 0))
			m.bellman.on_scream()
		310:
			ok(m.bellman.state == m.bellman.S.SEARCH, "Bellman stops hunting once you reach the Mail Room (state %d)" % m.bellman.state)
			m.bellman.global_position = Vector3(300, 0, 300)
			m.bellman.set_physics_process(false)
			# Silent loops are paused (a decoder each on phones).
			ok(m.title_music.stream_paused and m.amb2_player.stream_paused, "Inaudible music/ambience loops are paused")
			# Phone focus loss: auto-pause and let go of the stick.
			m.players["jenny"].global_position = m._off("jenny", Vector2i(0, 0), Vector3(-1, 0.05, 0.5))
			m.touch._set_vec(Vector2(0, -1))
			ok(Input.is_action_pressed("move_forward"), "Touch stick presses move_forward")
			m._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			ok(Game.mode == "menu" and m.menu_title == "PAUSED", "Leaving the app pauses the game")
			ok(not Input.is_action_pressed("move_forward"), "Leaving the app releases the touch stick")
			m._close_menu()
			# Touch controls OFF on a phone used to be a softlock (no way back to Settings).
			m.touch.touch_capable = true
			Game.settings["touch"] = false
			m.touch.apply_settings()
			ok(not m.touch.visible, "Touch controls can be switched off")
			var ev := InputEventScreenTouch.new()
			ev.pressed = true
			ev.position = Vector2(300, 120)
			ev.index = 3
			m.touch._input(ev)
			ok(m.touch.visible, "Touching the screen brings the touch controls back")
			var ev2 := InputEventScreenTouch.new()
			ev2.pressed = false
			ev2.index = 3
			m.touch._input(ev2)
			Game.settings["touch"] = true
			m.touch.touch_capable = false
			m.touch.apply_settings()
			m.touch.visible = false
			# Fuse box lamp turns green with power.
			_start_play("dana")
			Game.give("dana", "Fuse")
			var fb := item("fusebox")
			m.players["dana"].global_position = Vector3(fb["point"].x, 0.05, fb["point"].z)
			m._interact(fb)
			var lamp: MeshInstance3D = m.get_node("dana/fuse_lamp")
			var col: Color = lamp.material_override.get_shader_parameter("albedo_color")
			ok(Game.flag("power") and col.g > 0.9 and col.r < 0.5, "Fuse box lamp turns green when powered")
			# Timers bound to the level (a SceneTreeTimer outlives a scene reload).
			var src := FileAccess.get_file_as_string("res://scripts/main.gd")
			ok(not src.contains("get_tree().create_timer("), "No scene-tree timers left in main.gd")
			# Light culling: only this room's lights + neighbouring ceiling bulbs.
			var who := "dana"
			var c := Vector2i(1, -1)
			m.players[who].global_position = m.cell_center(who, c) + Vector3(0.3, 0.05, 0.6)
		314:
			var vis := 0
			var total := 0
			for lt in m.light_cell.keys():
				if m.light_cell[lt][0] == "dana":
					total += 1
					if lt.visible:
						vis += 1
			ok(m.cur_room_name == "Chief's Office" and vis < total and m.room_lights["dana_%s" % [Vector2i(1, 0)]].visible and not m.room_lights["dana_%s" % [Vector2i(0, 0)]].visible, "Lights culled per room (%d of %d on in the Chief's Office)" % [vis, total])
			# Door scene: plays on a room change, freezes play, skippable.
			Game.settings["doors"] = true
			m.door_cool = 0.0
			m.players["dana"].global_position = m.cell_center("dana", Vector2i(1, 0)) + Vector3(0, 0.05, -2.0)
		316:
			ok(Game.mode == "door" and m.door_cam.current, "Door scene plays when entering a room")
			Input.action_press("interact")
		317:
			Input.action_release("interact")
		318:
			ok(Game.mode == "play" and not m.door_cam.current and m.cameras["dana"][Vector2i(1, 0)].current, "Door scene skips back to the room camera")
			m.players["dana"].global_position = m.cell_center("dana", Vector2i(1, -1)) + Vector3(0, 0.05, 2.0)
		320:
			ok(Game.mode == "play", "Door scene doesn't replay when stepping straight back (cooldown)")
			m.door_cool = 0.0
			m.players["dana"].global_position = m.cell_center("dana", Vector2i(1, 0)) + Vector3(0, 0.05, -2.0)
		322:
			ok(Game.mode == "door", "Door scene plays again after the cooldown")
		420:
			ok(Game.mode == "play" and m.cameras["dana"][Vector2i(1, 0)].current and not m.door_stage.visible, "Door scene ends by itself in about 1.5 s")
			Game.settings["doors"] = false
			# Quit to title after progress: the world must be rebuilt fresh, or NEW GAME
			# starts with the fuse already taken (softlock).
			Game.give("jenny", "Fuse")
			Game.set_flag("picked_fuse")
			Game.set_flag("tallow1_dead")
			Game.smoke_phase = 10
			m._open_pause()
			m.menu_cb.call(3)   # Quit to title


## Lore documents were cut off at the screen edges on phones (build-9): every
## document panel must sit inside the viewport and the display safe area, clear of
## the touch buttons, with all of its text reachable by scrolling.
func _check_reader() -> void:
	var root := get_tree().root
	var old_size := root.size
	var hud = m.hud
	var touch_was: bool = m.touch.visible
	m.touch.visible = true   # as on a phone
	var sizes := [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 768)]
	for sz: Vector2i in sizes:
		# Plain screen, then the same phone with a camera cutout on the left and a
		# rounded-corner inset on the right (safe area in window pixels).
		for notch in [false, true]:
			hud.safe_override = Rect2(120, 0, sz.x - 120 - 48, sz.y) if notch else Rect2()
			root.size = sz
			await get_tree().process_frame
			m.touch._layout()
			hud._layout()
			var vp := Rect2(Vector2.ZERO, hud.get_viewport().get_visible_rect().size)
			var safe: Rect2 = hud.safe_rect()
			var bad: Array = []
			for key in m.NOTES.keys():
				m._show_note(key)
				await get_tree().process_frame
				await get_tree().process_frame
				var box: Rect2 = hud.ov_box.get_global_rect()
				var why := ""
				if not vp.encloses(box):
					why = "outside viewport"
				elif not safe.grow(0.5).encloses(box):
					why = "outside safe area"
				elif not box.grow(0.5).encloses(hud.ov_scroll.get_global_rect()) or not box.grow(0.5).encloses(hud.ov_title.get_global_rect()) or (hud.ov_hint.visible and not box.grow(0.5).encloses(hud.ov_hint.get_global_rect())):
					why = "title/body/footer spill out of the panel"
				elif hud.ov_body.size.x > hud.ov_scroll.size.x + 0.5:
					why = "text wider than the panel"
				elif hud.ov_scroll.get_v_scroll_bar().max_value + 1.0 < hud.ov_body.get_combined_minimum_size().y:
					why = "end of the text can't be scrolled to"
				else:
					for r: Rect2 in m.touch.overlay_rects():
						if r.intersects(box):
							why = "overlaps a touch button"
				if why != "":
					bad.append("%s %s %s" % [key, why, box])
				hud.hide_overlay()
				Game.mode = "play"
			ok(bad.is_empty(), "Document reader fits %dx%d%s (%d documents)%s" % [sz.x, sz.y, " with notch" if notch else "", m.NOTES.size(), "" if bad.is_empty() else ": " + str(bad)])
			# The other popups: messages, the item banner and the tutorial box.
			m.show_message("The canister rattles away toward Dana. Use the typewriter to switch to her and collect it.", 1.0)
			hud.show_tutorial("Use the typewriter to switch to Dana and collect it. Hold RUN to sprint; the Bellman hears running.", 1.0)
			hud.item_get("Tower Key", m.ITEM_INFO.get("Tower Key", ""))
			await get_tree().process_frame
			var pops := [hud.message.get_global_rect(), hud.get_bg.get_global_rect(), hud.tut_bg.get_global_rect()]
			var inside := true
			for r: Rect2 in pops:
				inside = inside and safe.grow(0.5).encloses(r)
			ok(inside and not pops[0].intersects(pops[1]) and not pops[1].intersects(pops[2]), "Messages, item banner and tutorial stay on screen without overlapping at %dx%d%s" % [sz.x, sz.y, " with notch" if notch else ""])
			hud.get_t = 0.01
			hud.msg_t = 0.01
			hud.tut_t = 0.01
	hud.safe_override = Rect2()
	root.size = old_size
	m.touch.visible = touch_was
	await get_tree().process_frame


func _after_title() -> void:
	for i in 5:
		await get_tree().process_frame
	ok(Game.mode == "title" and not Game.flag("picked_fuse") and not Game.flag("power") and not item("fuse").is_empty() and not m.zombies[0].dead, "Quit to title resets the world (fuse back, Tallow-folk back)")
	ok(not Game.has_item("jenny", "Fuse") and Game.has_item("dana", "Handgun"), "Quit to title resets the inventory")
	# NEW GAME from this title works end to end: pick up the fuse.
	m.title_index = 0
	Game.settings["doors"] = false
	m.hud.hide_overlay()
	Game.new_game()
	m._apply_state()
	Game.mode = "play"
	Game.set_flag("intro_done")
	var fz := item("fuse")
	m.players["jenny"].global_position = Vector3(fz["point"].x, 0.05, fz["point"].z)
	m._interact(fz)
	ok(Game.has_item("jenny", "Fuse"), "NEW GAME after quitting to title can still get the fuse")
	await _check_reader()
	Game.smoke_phase = 0
	print("REGRESS DONE")
	get_tree().quit()
