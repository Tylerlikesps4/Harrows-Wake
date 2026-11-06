extends CanvasLayer
## Minimal 1998-style HUD built in code. The canvas is 240 px tall; its width
## follows the phone's aspect ratio (stretch aspect "expand").

var status: Label
var ammo: Label
var prompt: Label
var message: Label
var tutorial: Label
var tut_bg: ColorRect
var stamina_bg: ColorRect
var stamina_bar: ColorRect
var panic_bg: ColorRect
var panic_bar: ColorRect
var panic_lbl: Label
var breath_bg: ColorRect
var breath_bar: ColorRect
var breath_lbl: Label
var overlay: ColorRect
var ov_title: Label
var ov_body: Label
var fps: Label
var get_bg: ColorRect
var get_title: Label
var get_body: Label
var get_t: float = 0.0
var msg_t: float = 0.0
var tut_t: float = 0.0
var W: float = 320.0


func _ready() -> void:
	layer = 2
	status = _label(Vector2(6, 4), 10, HORIZONTAL_ALIGNMENT_LEFT, Vector2(200, 14))
	ammo = _label(Vector2(214, 30), 10, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(100, 14))
	prompt = _label(Vector2(0, 222), 9, HORIZONTAL_ALIGNMENT_CENTER, Vector2(320, 14))
	message = _label(Vector2(10, 190), 10, HORIZONTAL_ALIGNMENT_CENTER, Vector2(300, 30))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	tut_bg = _rect(Vector2(60, 34), Vector2(200, 30), Color(0, 0, 0, 0.55))
	tutorial = _label(Vector2(64, 36), 8, HORIZONTAL_ALIGNMENT_CENTER, Vector2(192, 26))
	tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD
	tutorial.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	tut_bg.visible = false
	stamina_bg = _rect(Vector2(6, 20), Vector2(60, 4), Color(0.1, 0.1, 0.1, 0.8))
	stamina_bar = _rect(Vector2(6, 20), Vector2(60, 4), Color(0.75, 0.75, 0.45))
	panic_bg = _rect(Vector2(6, 27), Vector2(60, 4), Color(0.1, 0.1, 0.1, 0.8))
	panic_bar = _rect(Vector2(6, 27), Vector2(0, 4), Color(0.8, 0.12, 0.1))
	panic_lbl = _label(Vector2(70, 22), 8, HORIZONTAL_ALIGNMENT_LEFT, Vector2(80, 12))
	panic_lbl.text = "PANIC"
	breath_bg = _rect(Vector2(130, 150), Vector2(60, 4), Color(0.1, 0.1, 0.1, 0.8))
	breath_bar = _rect(Vector2(130, 150), Vector2(60, 4), Color(0.6, 0.75, 0.9))
	breath_lbl = _label(Vector2(110, 156), 8, HORIZONTAL_ALIGNMENT_CENTER, Vector2(100, 12))
	breath_lbl.text = "BREATH"
	set_breath(-1.0)
	# "Item get" banner: name + description, slides in and fades.
	get_bg = _rect(Vector2(40, 150), Vector2(240, 34), Color(0.02, 0.02, 0.02, 0.8))
	get_title = _label(Vector2(44, 152), 10, HORIZONTAL_ALIGNMENT_CENTER, Vector2(232, 12))
	get_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	get_body = _label(Vector2(44, 165), 7, HORIZONTAL_ALIGNMENT_CENTER, Vector2(232, 18))
	get_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	get_title.reparent(get_bg)
	get_body.reparent(get_bg)
	get_title.position = Vector2(4, 2)
	get_body.position = Vector2(4, 15)
	get_bg.visible = false
	fps = _label(Vector2(6, 228), 8, HORIZONTAL_ALIGNMENT_LEFT, Vector2(60, 10))
	fps.visible = false
	overlay = _rect(Vector2.ZERO, Vector2(320, 240), Color(0, 0, 0, 0.88))
	ov_title = _label(Vector2(10, 20), 16, HORIZONTAL_ALIGNMENT_CENTER, Vector2(300, 30))
	ov_body = _label(Vector2(16, 56), 9, HORIZONTAL_ALIGNMENT_LEFT, Vector2(288, 176))
	ov_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	ov_title.reparent(overlay)
	ov_body.reparent(overlay)
	overlay.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	W = s.x
	var cx := W / 2.0
	ammo.position.x = W - 106
	prompt.size.x = W
	message.position.x = cx - 150
	tut_bg.position.x = cx - 100
	tutorial.position.x = cx - 96
	breath_bg.position.x = cx - 30
	breath_bar.position.x = cx - 30
	breath_lbl.position.x = cx - 50
	overlay.size = s
	get_bg.position.x = cx - 120
	fps.position.y = s.y - 12
	ov_title.position.x = cx - 150
	ov_body.position.x = cx - 144


func _label(pos: Vector2, size: int, align: int, box: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = box
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _rect(pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func set_hud_visible(v: bool) -> void:
	for n in [status, ammo, prompt, stamina_bg, stamina_bar, message]:
		n.visible = v
	if not v:
		tut_bg.visible = false


func show_message(text: String, secs: float = 3.0) -> void:
	message.text = text
	msg_t = secs


func show_tutorial(text: String, secs: float = 6.0) -> void:
	tutorial.text = text
	tut_bg.visible = true
	tut_t = secs


func item_get(name: String, desc: String) -> void:
	get_title.text = name.to_upper()
	get_body.text = desc
	get_bg.visible = true
	get_bg.modulate.a = 0.0
	get_bg.scale = Vector2(1.0, 0.2)
	get_bg.pivot_offset = get_bg.size / 2.0
	var tw := create_tween()
	tw.tween_property(get_bg, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(get_bg, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_t = 3.0


func set_breath(v: float) -> void:
	var on := v >= 0.0
	breath_bg.visible = on
	breath_bar.visible = on
	breath_lbl.visible = on
	if on:
		breath_bar.size.x = 60.0 * v


func show_overlay(title: String, body: String, title_color: Color = Color(0.86, 0.84, 0.78), alpha: float = 0.88) -> void:
	overlay.visible = true
	overlay.color = Color(0, 0, 0, alpha)
	ov_title.text = title
	ov_title.add_theme_color_override("font_color", title_color)
	ov_body.text = body


func hide_overlay() -> void:
	overlay.visible = false


func update_status(who: String, hp: int, max_hp: int, ammo_count: int, stamina: float, panic: float, show_panic: bool) -> void:
	var cond := "FINE"
	var col := Color(0.35, 0.85, 0.35)
	var ratio := float(hp) / float(max_hp)
	if ratio <= 0.34:
		cond = "DANGER"
		col = Color(0.9, 0.15, 0.1)
	elif ratio <= 0.67:
		cond = "CAUTION"
		col = Color(0.95, 0.7, 0.15)
	status.text = "%s   %s" % [who.to_upper(), cond]
	status.add_theme_color_override("font_color", col)
	ammo.text = ("HANDGUN %d" % ammo_count) if who == "dana" else ""
	stamina_bar.size.x = 60.0 * stamina / 100.0
	panic_bar.size.x = 60.0 * panic / 100.0
	panic_bg.visible = show_panic
	panic_bar.visible = show_panic
	panic_lbl.visible = show_panic


func _process(delta: float) -> void:
	if fps.visible:
		fps.text = "%d FPS" % Engine.get_frames_per_second()
	if get_t > 0.0:
		get_t -= delta
		if get_t < 0.4:
			get_bg.modulate.a = maxf(0.0, get_t / 0.4)
		if get_t <= 0.0:
			get_bg.visible = false
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0:
			message.text = ""
	if tut_t > 0.0:
		tut_t -= delta
		if tut_t <= 0.0:
			tut_bg.visible = false
			tutorial.text = ""
