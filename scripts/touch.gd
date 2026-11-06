extends CanvasLayer
## On-screen touch controls for phones/tablets.
## Left half: a floating analog stick (appears wherever your thumb lands).
## Right side: thumb-sized buttons. Every control presses an existing input
## action, so game code is unchanged. Shown automatically on touchscreens;
## F3 toggles it on desktop for testing.

const STICK_R := 30.0   # canvas pixels (canvas is 240 px tall)
const DEAD := 0.18

var root: Node2D
var base: Sprite2D
var knob: Sprite2D
var hint: Label
var joy_index: int = -1
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO
var buttons: Dictionary = {}
var dana_only: Array = ["fire", "aim"]
var touch_capable: bool = false


func _ready() -> void:
	layer = 3
	root = Node2D.new()
	add_child(root)
	base = Sprite2D.new()
	base.texture = _ring(int(STICK_R * 2 + 4), Color(1, 1, 1, 0.22))
	knob = Sprite2D.new()
	knob.texture = _circle(22, Color(0.85, 0.85, 0.8), 0.45)
	root.add_child(base)
	root.add_child(knob)
	hint = Label.new()
	hint.text = "MOVE"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	hint.size = Vector2(40, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	_button("interact", "A", 18, Color(0.35, 0.75, 0.35))
	_button("run", "RUN", 15, Color(0.8, 0.3, 0.3))
	_button("quick_turn", "TURN", 12, Color(0.85, 0.75, 0.3))
	_button("flashlight", "LIGHT", 12, Color(0.9, 0.9, 0.6))
	_button("fire", "FIRE", 15, Color(0.35, 0.5, 0.9))
	_button("aim", "AIM", 13, Color(0.6, 0.6, 0.6))
	_button("inventory", "ITEMS", 11, Color(0.55, 0.55, 0.55))
	_button("pause", "II", 10, Color(0.55, 0.55, 0.55))
	_button("cancel", "BACK", 10, Color(0.55, 0.55, 0.55))
	touch_capable = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()
	visible = touch_capable and (bool(Game.settings.get("touch", true)) or "--touch" in OS.get_cmdline_user_args())
	get_viewport().size_changed.connect(_layout)
	apply_settings()
	_reset_stick()


## Button size/opacity and on/off from the settings menu.
func apply_settings() -> void:
	var sc: float = float(Game.settings.get("btn_size", 1.0))
	var op: float = float(Game.settings.get("btn_opacity", 0.8))
	for a in buttons.keys():
		var b: TouchScreenButton = buttons[a]
		b.scale = Vector2(sc, sc)
		b.modulate.a = op
	if touch_capable:
		visible = bool(Game.settings.get("touch", true))
		if not visible:
			release_all()
	_layout()


## Let go of everything (app sent to the background, controls hidden mid-drag).
func release_all() -> void:
	joy_index = -1
	_set_vec(Vector2.ZERO)
	for a in buttons.keys():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_reset_stick()


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var w := s.x
	var h := s.y
	_place("interact", Vector2(w - 30, h - 46))
	_place("run", Vector2(w - 66, h - 22))
	_place("fire", Vector2(w - 66, h - 72))
	_place("aim", Vector2(w - 30, h - 92))
	_place("quick_turn", Vector2(w - 98, h - 40))
	_place("flashlight", Vector2(w - 100, h - 84))
	_place("pause", Vector2(w - 14, 14))
	_place("inventory", Vector2(w - 40, 14))
	_place("cancel", Vector2(w - 66, 14))
	if joy_index < 0:
		_reset_stick()


func _reset_stick() -> void:
	var h: float = get_viewport().get_visible_rect().size.y
	joy_origin = Vector2(52, h - 52)
	base.position = joy_origin
	knob.position = joy_origin
	base.modulate.a = 0.5
	knob.modulate.a = 0.5
	hint.position = joy_origin + Vector2(-20, STICK_R + 2)
	hint.visible = true


func _place(action: String, center: Vector2) -> void:
	var b: TouchScreenButton = buttons[action]
	var sc: float = float(Game.settings.get("btn_size", 1.0))
	var r: float = b.get_meta("r") * sc
	var s: Vector2 = get_viewport().get_visible_rect().size
	# Bigger buttons spread out from the screen corner so they don't overlap.
	var c: Vector2 = Vector2(s.x, s.y) + (center - Vector2(s.x, s.y)) * sc if center.y > s.y * 0.5 else Vector2(s.x + (center.x - s.x) * sc, center.y * sc)
	b.position = c - Vector2(r, r)


func _process(_d: float) -> void:
	if not visible:
		return
	var is_dana: bool = Game.state.get("active", "jenny") == "dana"
	for a in dana_only:
		buttons[a].visible = is_dana and Game.mode == "play"
	buttons["flashlight"].visible = Game.mode == "play"
	buttons["quick_turn"].visible = Game.mode == "play"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible
		return
	if not visible:
		# "Touch controls OFF" is for a Bluetooth pad. Touching the screen brings them
		# back, so a phone player who turned them off can still reach the menus
		# (before build-9 that was a softlock with no way back to Settings).
		if touch_capable and event is InputEventScreenTouch and event.pressed:
			visible = true
			_layout()
		else:
			return
	elif not bool(Game.settings.get("touch", true)) and (event is InputEventJoypadButton or event is InputEventKey):
		visible = false
		release_all()
		return
	var half: float = get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		if event.pressed and joy_index < 0 and event.position.x < half and event.position.y > 30:
			joy_index = event.index
			joy_origin = event.position
			base.position = joy_origin
			knob.position = joy_origin
			base.modulate.a = 1.0
			knob.modulate.a = 1.0
			hint.visible = false
			_set_vec(Vector2.ZERO)
		elif not event.pressed and event.index == joy_index:
			joy_index = -1
			_set_vec(Vector2.ZERO)
			_reset_stick()
	elif event is InputEventScreenDrag and event.index == joy_index:
		var d: Vector2 = event.position - joy_origin
		if d.length() > STICK_R:
			# Floating stick: drag the base along so the thumb never "falls off".
			joy_origin += d - d.normalized() * STICK_R
			base.position = joy_origin
			d = d.normalized() * STICK_R
		knob.position = joy_origin + d
		_set_vec(d / STICK_R)


func _set_vec(v: Vector2) -> void:
	v *= float(Game.settings.get("stick_sens", 1.0))
	if v.length() < DEAD:
		v = Vector2.ZERO
	else:
		v = v.normalized() * inverse_lerp(DEAD, 1.0, minf(1.0, v.length()))
	joy_vec = v
	_axis("move_right", maxf(0.0, v.x))
	_axis("move_left", maxf(0.0, -v.x))
	_axis("move_back", maxf(0.0, v.y))
	_axis("move_forward", maxf(0.0, -v.y))


func _axis(action: String, strength: float) -> void:
	if strength > 0.3:
		Input.action_press(action, strength)
	elif strength > 0.0 and Input.is_action_pressed(action):
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _circle(size: int, col: Color, alpha: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0
	var r := size / 2.0 - 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				var edge := d > r - 1.5
				var cc := col.lightened(0.3) if edge else col.darkened(0.45)
				cc.a = alpha if not edge else minf(1.0, alpha + 0.3)
				img.set_pixel(x, y, cc)
	return ImageTexture.create_from_image(img)


func _ring(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0
	var r := size / 2.0 - 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				var cc := col
				cc.a = col.a * (2.5 if d > r - 2.0 else 0.6)
				img.set_pixel(x, y, cc)
	return ImageTexture.create_from_image(img)


func _button(action: String, glyph: String, r: int, col: Color) -> void:
	var size := r * 2
	var b := TouchScreenButton.new()
	b.action = action
	b.texture_normal = _circle(size, col, 0.35)
	b.texture_pressed = _circle(size, col.lightened(0.25), 0.75)
	var shape := CircleShape2D.new()
	shape.radius = r + 4.0  # a little larger than drawn, for thumbs
	b.shape = shape
	b.shape_centered = true
	b.set_meta("r", float(r))
	var l := Label.new()
	l.text = glyph
	l.position = Vector2(-20, 0)
	l.size = Vector2(size + 40, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8 if glyph.length() <= 2 else 6)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	root.add_child(b)
	buttons[action] = b
