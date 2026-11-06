extends Node
## Title -> intro -> pause -> flashlight -> hide/breath flow check:  godot --headless -- --flow
var m
var t := 0.0
var step := 0
func ok(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
func _ready() -> void:
	m = get_parent()
	Engine.max_fps = 60
	process_priority = -10  # run before main so simulated presses are 'just pressed'
func _process(d: float) -> void:
	t += d
	match step:
		0:
			if t > 0.5:
				ok(Game.mode == "title", "Title screen up")
				ok(m._title_opts().has("SETTINGS"), "Title has SETTINGS")
				m.title_index = m._title_opts().find("SETTINGS")
				Input.action_press("interact"); step = 20
		20:
			Input.action_release("interact")
			ok(Game.mode == "menu" and m.menu_title == "SETTINGS", "Settings opens from title"); step = 21
		21:
			Input.action_press("move_right"); step = 22
		22:
			Input.action_release("move_right")
			ok(m.menu_index == 0 and Game.settings["brightness"] > 1.05 or Game.settings["brightness"] >= 1.8, "Right arrow raises brightness (%.1f)" % Game.settings["brightness"])
			Input.action_press("move_left"); step = 23
		23:
			Input.action_release("move_left")
			Input.action_press("cancel"); step = 24
		24:
			Input.action_release("cancel")
			ok(Game.mode == "title", "BACK returns to the title"); step = 25; t = 0
		25:
			if t > 0.2:
				m.title_index = 0
				Input.action_press("interact"); step = 1
		1:
			Input.action_release("interact")
			ok(Game.mode == "note", "Intro note shown"); step = 2; t = 0
		2:
			if t > 0.3:
				Input.action_press("interact"); step = 3
		3:
			Input.action_release("interact")
			ok(m.intro_t >= 0.0 and m.players["jenny"].frozen, "Intro beat running, Jenny frozen"); step = 4; t = 0
		4:
			if t > 7.0:
				ok(not m.players["jenny"].frozen and m.phantom == null, "Intro done, phantom gone")
				Input.action_press("pause"); step = 5
		5:
			Input.action_release("pause")
			ok(Game.mode == "menu" and m.menu_title == "PAUSED" and m.hud.ov_body.text.contains("CURRENT OBJECTIVE"), "Pause menu opens with objective")
			m.menu_cb.call(2)
			ok(m.menu_title == "SETTINGS", "Settings opens from pause")
			step = 30
		30:
			Input.action_press("cancel"); step = 31
		31:
			Input.action_release("cancel")
			ok(m.menu_title == "PAUSED", "Settings BACK returns to pause"); step = 6
		6:
			Input.action_press("cancel"); step = 7
		7:
			Input.action_release("cancel")
			ok(Game.mode == "play", "Pause menu closes")
			Input.action_press("flashlight"); step = 8
		8:
			Input.action_release("flashlight")
			step = 9
		9:
			ok(m.players["jenny"].light_on, "Flashlight toggles on")
			var hid
			for it in m.interactables:
				if it["id"] == "hide_dorm": hid = it
			m._interact(hid)
			Input.action_press("run"); step = 10; t = 0
		10:
			if t > 7.0:
				ok(m.players["jenny"].breath < 0.5, "Holding breath drains (%.2f)" % m.players["jenny"].breath)
				Input.action_release("run")
				m._unhide(m.players["jenny"])
				print("FLOW DONE"); get_tree().quit()
