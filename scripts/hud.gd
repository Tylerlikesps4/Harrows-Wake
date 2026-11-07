extends CanvasLayer
## 1998-style HUD built in code. Canvas is 240 px tall, width follows the
## screen aspect (stretch "expand"). Everything stays inside the safe area.
## Docs, menus and end screens share one reader panel (<= 90% safe width,
## 85% height) that wraps, scrolls and keeps clear of the touch buttons.

const BOX_MAX_W := 360.0  # ~70 chars, easy to read
const BODY_FONT := 9
const PAD := 6.0

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
var ov_box: PanelContainer     # the reader panel: title, scrolling body, footer hint
var ov_title: Label
var ov_scroll: ScrollContainer
var ov_body: Label
var ov_hint: Label
var ov_framed := false
var ov_hint_base := ""
var ov_more := false
var ov_follow := ""            # menu line to keep in view after the next layout
var ov_rect := Rect2()         # where the panel sits (canvas pixels)
var touch_ref: Node = null     # set by main; its buttons are kept clear of the panel
## Tests: fake the device safe area (window pixels, e.g. a notch).
var safe_override := Rect2()
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
	# "item get" banner, slides in and fades
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
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_reader()
	overlay.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var sr := safe_rect()
	W = s.x
	var il := sr.position.x
	var it := sr.position.y
	var ir := s.x - sr.end.x
	var ib := s.y - sr.end.y
	var cx := sr.get_center().x
	status.position = Vector2(6 + il, 4 + it)
	stamina_bg.position = Vector2(6 + il, 20 + it)
	stamina_bar.position = stamina_bg.position
	panic_bg.position = Vector2(6 + il, 27 + it)
	panic_bar.position = panic_bg.position
	panic_lbl.position = Vector2(70 + il, 22 + it)
	ammo.position = Vector2(W - 106 - ir, 30 + it)
	prompt.position = Vector2(il, 222 - ib)
	prompt.size.x = sr.size.x
	tut_bg.size.x = minf(200.0, sr.size.x - 20.0)
	tut_bg.position = Vector2(cx - tut_bg.size.x / 2.0, 34 + it)
	tutorial.size.x = tut_bg.size.x - 8.0
	tutorial.position = Vector2(tut_bg.position.x + 4.0, tut_bg.position.y + 2.0)
	breath_bg.position.x = cx - 30
	breath_bar.position.x = cx - 30
	breath_lbl.position.x = cx - 50
	fps.position = Vector2(6 + il, s.y - 12 - ib)
	_fit_message()
	_fit_tutorial()
	_fit_banner()
	layout_overlay()


## Usable canvas area: the display safe area mapped from window to canvas pixels.
func safe_rect() -> Rect2:
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var win := Vector2(get_window().size)
	if win.x <= 0.0 or win.y <= 0.0:
		return Rect2(Vector2.ZERO, vis)
	var wr := Rect2(Vector2(DisplayServer.window_get_position()) if not safe_override.has_area() else Vector2.ZERO, win)
	var sa: Rect2 = safe_override if safe_override.has_area() else Rect2(DisplayServer.get_display_safe_area())
	var inter := wr.intersection(sa) if sa.has_area() else wr
	if inter.size.x < win.x * 0.5 or inter.size.y < win.y * 0.5:
		inter = wr # bogus report (window off-screen etc), just use the window
	var k := vis / win
	return Rect2((inter.position - wr.position) * k, inter.size * k)


func _build_reader() -> void:
	ov_box = PanelContainer.new()
	ov_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ov_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov_box.add_child(vb)
	ov_title = _label(Vector2.ZERO, 16, HORIZONTAL_ALIGNMENT_CENTER, Vector2(10, 20))
	ov_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	ov_title.reparent(vb)
	ov_scroll = ScrollContainer.new()
	ov_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ov_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	ov_scroll.scroll_deadzone = 4
	var bar := ov_scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.06)
	track.content_margin_left = 1.5
	track.content_margin_right = 1.5
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.86, 0.84, 0.78, 0.55)
	grab.content_margin_left = 1.5
	grab.content_margin_right = 1.5
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	vb.add_child(ov_scroll)
	ov_body = _label(Vector2.ZERO, BODY_FONT, HORIZONTAL_ALIGNMENT_LEFT, Vector2(10, 10))
	ov_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_body.reparent(ov_scroll)
	ov_hint = _label(Vector2.ZERO, 7, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(10, 10))
	ov_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	ov_hint.reparent(vb)
	_set_frame(false)


func _set_frame(framed: bool) -> void:
	ov_framed = framed
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.02, 0.55) if framed else Color(0, 0, 0, 0)
	if framed:
		sb.set_border_width_all(1)
		sb.border_color = Color(0.55, 0.48, 0.36, 0.7)
	sb.set_content_margin_all(PAD)
	ov_box.add_theme_stylebox_override("panel", sb)


## Size and place the reader panel for the current screen.
func layout_overlay() -> void:
	if ov_box == null:
		return
	var s: Vector2 = get_viewport().get_visible_rect().size
	var sr := safe_rect()
	var bw := minf(sr.size.x * 0.9, BOX_MAX_W)
	var bh := sr.size.y * 0.85
	var box := Rect2(sr.get_center() - Vector2(bw, bh) / 2.0, Vector2(bw, bh))
	# keep the touch buttons off the text; drop whichever strip of the panel
	# (top, bottom or sides) costs the least
	if touch_ref != null and touch_ref.visible and touch_ref.has_method("overlay_rects"):
		for r: Rect2 in touch_ref.overlay_rects():
			if not box.intersects(r):
				continue
			var cut_top := (r.end.y + 2.0 - box.position.y) * box.size.x
			var cut_bot := (box.end.y - r.position.y + 2.0) * box.size.x
			var right := r.get_center().x > box.get_center().x
			var side := (box.end.x - r.position.x + 2.0) if right else (r.end.x + 2.0 - box.position.x)
			var cut_side := side * box.size.y
			if r.get_center().y < box.get_center().y and cut_top <= cut_side:
				box = Rect2(box.position.x, r.end.y + 2.0, box.size.x, box.end.y - r.end.y - 2.0)
			elif r.get_center().y >= box.get_center().y and cut_bot <= cut_side:
				box.size.y = r.position.y - 2.0 - box.position.y
			elif right:
				box.size.x -= side
			else:
				box = box.grow_individual(-side, 0, 0, 0)
	ov_rect = box
	ov_box.position = box.position
	ov_box.size = box.size
	ov_box.custom_minimum_size = Vector2.ZERO
	var inner := box.size.x - PAD * 2.0
	ov_title.custom_minimum_size.x = inner
	ov_hint.custom_minimum_size.x = inner
	ov_body.custom_minimum_size.x = inner - 6.0 # room for the scrollbar
	overlay.size = s


## Pixel height of wrapped text in a label (the label may not have re-laid out yet).
func _text_h(l: Label, text: String, width: float, fsize: int) -> float:
	if text == "":
		return 0.0
	var font: Font = l.get_theme_font("font")
	var fh := font.get_height(fsize)
	var raw := font.get_multiline_string_size(text, l.horizontal_alignment, width, fsize).y
	var lines := maxf(1.0, roundf(raw / fh))
	return lines * (fh + l.get_theme_constant("line_spacing"))


## Lane for messages and the item banner: centered, clear of the touch
## controls. On narrow screens (4:3 tablets) it moves up above them.
## Returns Vector3(x, width, bottom).
func _bottom_lane(want_w: float) -> Vector3:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var sr := safe_rect()
	var cx := sr.get_center().x
	var w := minf(want_w, sr.size.x - 20.0)
	var bottom := 220.0 - (s.y - sr.end.y)
	if touch_ref != null and touch_ref.visible and touch_ref.has_method("play_rects"):
		var lo := sr.position.x
		var hi := sr.end.x
		var top := bottom
		for r: Rect2 in touch_ref.play_rects():
			if r.end.y < s.y * 0.5:
				continue
			top = minf(top, r.position.y - 3.0)
			if r.get_center().x < cx:
				lo = maxf(lo, r.end.x + 4.0)
			else:
				hi = minf(hi, r.position.x - 4.0)
		var gap := minf(cx - lo, hi - cx) * 2.0
		if gap >= 200.0:
			w = minf(w, gap)
		else:
			bottom = minf(bottom, top)
	return Vector3(cx - w / 2.0, w, bottom)


## Messages grow upward from above the prompt line.
func _fit_message() -> void:
	var lane := _bottom_lane(300.0)
	message.position.x = lane.x
	message.size.x = lane.y
	var h := maxf(14.0, _text_h(message, message.text, message.size.x, 10))
	message.size.y = h
	message.position.y = lane.z - h


func _fit_tutorial() -> void:
	var h := maxf(12.0, _text_h(tutorial, tutorial.text, tutorial.size.x, 8))
	tutorial.size.y = h
	tut_bg.size.y = h + 4.0


## Item banner grows to fit the description and ends above the message.
func _fit_banner() -> void:
	var lane := _bottom_lane(240.0)
	var w := lane.y
	get_bg.size.x = w
	get_title.size.x = w - 8.0
	get_body.size.x = w - 8.0
	var h := _text_h(get_body, get_body.text, w - 8.0, 7)
	get_body.size.y = h
	get_bg.size.y = 17.0 + h
	get_bg.position.x = lane.x
	var above := message.position.y - 4.0 if message.text != "" else lane.z - 34.0
	get_bg.position.y = minf(150.0, above - get_bg.size.y)
	# narrow screens push the lane up; never go under the tutorial box
	if tut_bg.visible and tut_t > 0.0 and get_bg.position.y < tut_bg.position.y + tut_bg.size.y + 3.0:
		get_bg.position.y = tut_bg.position.y + tut_bg.size.y + 3.0
		if message.text != "":
			message.position.y = maxf(message.position.y, get_bg.position.y + get_bg.size.y + 3.0)
	get_bg.pivot_offset = get_bg.size / 2.0


## Scroll the document by pixels (stick / Up-Down while reading).
func scroll_overlay(px: float) -> void:
	ov_scroll.scroll_vertical = int(ov_scroll.scroll_vertical + px)


func overlay_overflows() -> bool:
	return ov_body.get_combined_minimum_size().y > ov_scroll.size.y + 1.0


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
	# hide the tutorial text with its box (title/credits)
	tutorial.visible = v
	tut_bg.visible = v and tut_t > 0.0


func show_message(text: String, secs: float = 3.0) -> void:
	message.text = text
	msg_t = secs
	_fit_message()
	if get_bg.visible:
		_fit_banner()


func show_tutorial(text: String, secs: float = 6.0) -> void:
	tutorial.text = text
	_fit_tutorial()
	tut_bg.visible = true
	tutorial.visible = true
	tut_t = secs
	if get_bg.visible:
		_fit_banner()


func item_get(name: String, desc: String) -> void:
	get_title.text = name.to_upper()
	get_body.text = desc
	get_bg.visible = true
	_fit_banner()
	get_bg.modulate.a = 0.0
	get_bg.scale = Vector2(1.0, 0.2)
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


## hint: footer line (controls). framed: draw the document panel border.
func show_overlay(title: String, body: String, title_color: Color = Color(0.86, 0.84, 0.78), alpha: float = 0.88, hint: String = "", framed: bool = false) -> void:
	var same := overlay.visible and title == ov_title.text
	overlay.visible = true
	overlay.color = Color(0, 0, 0, alpha)
	ov_title.text = title
	ov_title.add_theme_color_override("font_color", title_color)
	ov_body.text = body
	ov_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ov_body.modulate.a = 1.0
	ov_title.modulate.a = 1.0
	ov_hint_base = hint
	ov_hint.text = hint
	ov_more = false
	ov_hint.visible = hint != ""
	ov_follow = ""
	if framed != ov_framed:
		_set_frame(framed)
	# Document footers sit bottom-right; menu/title footers are centered.
	ov_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if framed else HORIZONTAL_ALIGNMENT_CENTER
	if not same:
		ov_scroll.scroll_vertical = 0
	layout_overlay()


## Keep the body line containing marker in view (menus scroll with the cursor).
func follow_line(marker: String) -> void:
	ov_follow = marker


func hide_overlay() -> void:
	overlay.visible = false


func _update_reader() -> void:
	if ov_follow != "":
		var i := ov_body.text.find(ov_follow)
		if i >= 0:
			var e := ov_body.text.find("\n", i)
			var prefix := ov_body.text.substr(0, e if e >= 0 else ov_body.text.length())
			var bottom := _text_h(ov_body, prefix, ov_body.size.x, BODY_FONT)
			var line := ov_body.get_theme_font("font").get_height(BODY_FONT) + ov_body.get_theme_constant("line_spacing")
			var view := ov_scroll.size.y
			if bottom > ov_scroll.scroll_vertical + view:
				ov_scroll.scroll_vertical = int(bottom - view + 2.0)
			elif bottom - line < ov_scroll.scroll_vertical:
				ov_scroll.scroll_vertical = int(maxf(0.0, bottom - line * 2.0))
		ov_follow = ""
	if ov_hint_base != "":
		var more := overlay_overflows() and ov_scroll.scroll_vertical < int(ov_body.get_combined_minimum_size().y - ov_scroll.size.y) - 1
		if more != ov_more:
			ov_more = more
			ov_hint.text = ("more below - drag or Up/Down      " + ov_hint_base) if more else ov_hint_base


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
	var st := "%s   %s" % [who.to_upper(), cond]
	if st != status.text:
		# theme overrides force a re-layout, so only touch it on change
		status.text = st
		status.add_theme_color_override("font_color", col)
	ammo.text = ("HANDGUN %d" % ammo_count) if who == "dana" else ""
	stamina_bar.size.x = 60.0 * stamina / 100.0
	panic_bar.size.x = 60.0 * panic / 100.0
	panic_bg.visible = show_panic
	panic_bar.visible = show_panic
	panic_lbl.visible = show_panic


func _process(delta: float) -> void:
	if overlay.visible:
		_update_reader()
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
