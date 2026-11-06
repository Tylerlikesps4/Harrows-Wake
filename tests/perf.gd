extends Node
## Render cost probe (needs a real renderer):
##   xvfb-run -s "-screen 0 1280x960x24" godot --rendering-driver opengl3 -- --perf
## Puts the active survivor in every room and prints draw calls / objects /
## primitives as the fixed camera sees them. Also saves a brightness reading.
var m
var f := 0
var rooms: Array = []
var i := 0
func _ready() -> void:
	m = get_parent()
	Engine.max_fps = 30
	Game.settings["doors"] = false
	for who in ["dana", "jenny"]:
		for c in m.MAPS[who]["rooms"].keys():
			rooms.append([who, c])
func _process(_d: float) -> void:
	f += 1
	if f == 20:
		m.hud.hide_overlay(); Game.mode = "play"; Game.set_flag("intro_done")
		m.bellman.set_physics_process(false)
		m.bellman.global_position = Vector3(300, 0, 300)
		m.zombies[0].set_physics_process(false)
	if f < 30:
		return
	var k := (f - 30) % 25
	if k == 0:
		if i >= rooms.size():
			print("PERF DONE")
			get_tree().quit()
			return
		var who: String = rooms[i][0]
		var c: Vector2i = rooms[i][1]
		if Game.state["active"] != who:
			m._switch_to(who)
		m.players[who].global_position = m.cell_center(who, c) + Vector3(0.3, 0.05, 0.6)
	elif k == 24:
		var who: String = rooms[i][0]
		var c: Vector2i = rooms[i][1]
		m.post_mat.set_shader_parameter("fade", 0.0)
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_L8)
		var tot := 0.0
		var data := img.get_data()
		for b in data:
			tot += b
		print("PERF %s %-14s draws=%d objects=%d prims=%d luma=%.1f" % [who, m.MAPS[who]["rooms"][c]["name"],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), tot / data.size()])
		i += 1
