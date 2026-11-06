extends CanvasLayer
## On-screen touch controls for phones/tablets (320x240 canvas).
## Every button just presses an existing input action, so game code is unchanged.
## Shown automatically on touchscreen devices; F3 toggles it on desktop for testing.

const BTN := 22
var root: Node2D


func _ready() -> void:
	layer = 3
	root = Node2D.new()
	add_child(root)
	# D-pad (bottom-left). passby_press lets a thumb slide between directions.
	_button("move_forward", "^", Vector2(30, 160))
	_button("move_back", "v", Vector2(30, 206))
	_button("move_left", "<", Vector2(7, 183))
	_button("move_right", ">", Vector2(53, 183))
	# Face buttons (bottom-right).
	_button("interact", "A", Vector2(291, 190), Color(0.35, 0.75, 0.35))
	_button("run", "B", Vector2(265, 212), Color(0.8, 0.3, 0.3))
	_button("fire", "X", Vector2(265, 168), Color(0.35, 0.5, 0.9))
	_button("quick_turn", "Y", Vector2(239, 190), Color(0.85, 0.75, 0.3))
	_button("aim", "AIM", Vector2(291, 146), Color(0.6, 0.6, 0.6), 26)
	# Menu buttons (top-right, under the ammo counter).
	_button("inventory", "INV", Vector2(268, 20), Color(0.55, 0.55, 0.55), 22)
	_button("cancel", "ESC", Vector2(294, 20), Color(0.55, 0.55, 0.55), 22)
	visible = DisplayServer.is_touchscreen_available()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible


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
				cc.a = alpha if not edge else minf(1.0, alpha + 0.25)
				img.set_pixel(x, y, cc)
	return ImageTexture.create_from_image(img)


func _button(action: String, glyph: String, pos: Vector2, col := Color(0.6, 0.6, 0.6), size := BTN) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.texture_normal = _circle(size, col, 0.35)
	b.texture_pressed = _circle(size, col.lightened(0.25), 0.7)
	b.passby_press = action.begins_with("move_")
	var shape := CircleShape2D.new()
	shape.radius = size / 2.0 + 3.0  # a little larger than drawn, for fat fingers
	b.shape = shape
	b.shape_centered = true
	b.position = pos
	var l := Label.new()
	l.text = glyph
	l.size = Vector2(size, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	root.add_child(b)
