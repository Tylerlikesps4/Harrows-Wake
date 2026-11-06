extends CanvasLayer
## Minimal 1998-style HUD built in code (320x240 canvas).

var status: Label
var ammo: Label
var prompt: Label
var message: Label
var stamina_bg: ColorRect
var stamina_bar: ColorRect
var panic_bg: ColorRect
var panic_bar: ColorRect
var panic_lbl: Label
var overlay: ColorRect
var ov_title: Label
var ov_body: Label
var msg_t: float = 0.0


func _ready() -> void:
	layer = 2
	status = _label(Vector2(6, 4), 10, HORIZONTAL_ALIGNMENT_LEFT, Vector2(200, 14))
	ammo = _label(Vector2(214, 4), 10, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(100, 14))
	prompt = _label(Vector2(0, 222), 9, HORIZONTAL_ALIGNMENT_CENTER, Vector2(320, 14))
	message = _label(Vector2(10, 196), 10, HORIZONTAL_ALIGNMENT_CENTER, Vector2(300, 24))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	stamina_bg = _rect(Vector2(6, 20), Vector2(60, 4), Color(0.1, 0.1, 0.1, 0.8))
	stamina_bar = _rect(Vector2(6, 20), Vector2(60, 4), Color(0.75, 0.75, 0.45))
	panic_bg = _rect(Vector2(6, 27), Vector2(60, 4), Color(0.1, 0.1, 0.1, 0.8))
	panic_bar = _rect(Vector2(6, 27), Vector2(0, 4), Color(0.8, 0.12, 0.1))
	panic_lbl = _label(Vector2(70, 22), 8, HORIZONTAL_ALIGNMENT_LEFT, Vector2(80, 12))
	panic_lbl.text = "PANIC"
	overlay = _rect(Vector2.ZERO, Vector2(320, 240), Color(0, 0, 0, 0.88))
	ov_title = _label(Vector2(10, 20), 16, HORIZONTAL_ALIGNMENT_CENTER, Vector2(300, 30))
	ov_body = _label(Vector2(16, 56), 9, HORIZONTAL_ALIGNMENT_LEFT, Vector2(288, 176))
	ov_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	ov_title.reparent(overlay)
	ov_body.reparent(overlay)
	overlay.visible = false


func _label(pos: Vector2, size: int, align: int, box: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = box
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
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
	for n in [status, ammo, prompt, stamina_bg, stamina_bar]:
		n.visible = v


func show_message(text: String, secs: float = 3.0) -> void:
	message.text = text
	msg_t = secs


func show_overlay(title: String, body: String, title_color: Color = Color(0.86, 0.84, 0.78)) -> void:
	overlay.visible = true
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
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0:
			message.text = ""
