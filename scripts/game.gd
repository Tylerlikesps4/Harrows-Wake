extends Node
## Global game state for Harrow's Wake (autoload "Game").

const SAVE_PATH := "user://harrows_wake_save.json"

var state: Dictionary = {}
var mode: String = "title"   # title, play, note, menu, struggle, dead, win
var tank_controls: bool = true
var skip_title: bool = false
var input_kind: String = "keyboard"   # keyboard, gamepad, touch
var crt_on: bool = true


func _ready() -> void:
	_setup_input()
	# Phones: camera-relative movement by default (tank controls are F1 / pause menu).
	if DisplayServer.is_touchscreen_available():
		tank_controls = false
		input_kind = "touch"
	new_game()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		input_kind = "touch"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		input_kind = "gamepad"
	elif event is InputEventKey or event is InputEventMouseButton:
		input_kind = "keyboard"


## Button name for prompts, matching the device the player is using right now.
func glyph(action: String) -> String:
	var t := {
		"keyboard": {"interact": "[E]", "run": "[Shift]", "aim": "[K]", "fire": "[J]", "quick_turn": "[Q]", "inventory": "[Tab]", "cancel": "[Esc]", "flashlight": "[F]", "pause": "[Esc]", "breath": "[Shift]"},
		"gamepad": {"interact": "(A)", "run": "(B)", "aim": "(RB)", "fire": "(X)", "quick_turn": "(Y)", "inventory": "(Back)", "cancel": "(Back)", "flashlight": "(LB)", "pause": "(Start)", "breath": "(B)"},
		"touch": {"interact": "Tap A", "run": "Hold RUN", "aim": "Hold AIM", "fire": "Tap FIRE", "quick_turn": "Tap TURN", "inventory": "Tap ITEMS", "cancel": "Tap BACK", "flashlight": "Tap LIGHT", "pause": "Tap II", "breath": "Hold RUN"},
	}
	return t.get(input_kind, t["keyboard"]).get(action, action)


func new_game() -> void:
	state = {
		"active": "jenny",
		"inv": {"dana": ["Handgun", "Green Herb"], "jenny": []},
		"ammo": 10,
		"hp": {"dana": 5, "jenny": 3},
		"tube": {"dana": [], "jenny": []},
		"pos": {"dana": [], "jenny": []},
		"rot": {"dana": 0.0, "jenny": 0.0},
		"flags": {},
		"light": {"dana": false, "jenny": false},
		"saves": 0,
		"time": 0.0,
	}


func has_item(who: String, item: String) -> bool:
	return state["inv"][who].has(item)


func give(who: String, item: String) -> void:
	state["inv"][who].append(item)


func take(who: String, item: String) -> void:
	state["inv"][who].erase(item)


func flag(name: String) -> bool:
	return state["flags"].get(name, false)


func set_flag(name: String) -> void:
	state["flags"][name] = true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	state["saves"] = int(state["saves"]) + 1
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))
		f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	state = data
	return true


func restart(from_save: bool) -> void:
	if from_save and load_game():
		pass
	else:
		new_game()
	skip_title = true
	get_tree().reload_current_scene()


func _add_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	_add_key("move_forward", [KEY_W, KEY_UP])
	_add_key("move_back", [KEY_S, KEY_DOWN])
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("run", [KEY_SHIFT])
	_add_key("interact", [KEY_E, KEY_SPACE, KEY_ENTER])
	_add_key("aim", [KEY_K])
	_add_key("fire", [KEY_J])
	_add_key("quick_turn", [KEY_Q])
	_add_key("inventory", [KEY_TAB, KEY_I])
	_add_key("cancel", [KEY_ESCAPE, KEY_BACKSPACE])
	_add_key("pause", [KEY_ESCAPE, KEY_P])
	_add_key("flashlight", [KEY_F])
	_add_key("toggle_controls", [KEY_F1])
	_add_key("toggle_crt", [KEY_F2])
	_add_key("continue_game", [KEY_C])
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("move_forward", JOY_BUTTON_DPAD_UP)
	_add_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_button("run", JOY_BUTTON_B)
	_add_joy_button("aim", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("fire", JOY_BUTTON_X)
	_add_joy_button("quick_turn", JOY_BUTTON_Y)
	_add_joy_button("inventory", JOY_BUTTON_BACK)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("flashlight", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("cancel", JOY_BUTTON_BACK)
	_add_joy_button("continue_game", JOY_BUTTON_Y)
	_add_mouse("aim", MOUSE_BUTTON_RIGHT)
	_add_mouse("fire", MOUSE_BUTTON_LEFT)
