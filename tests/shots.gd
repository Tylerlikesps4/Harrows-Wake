extends Node
var m
var f := 0
const OUT := "/workspace/work/harrows-wake/shots/"
func _ready() -> void:
	m = get_parent()
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot ", n)
func _process(_d: float) -> void:
	f += 1
	match f:
		20: shot("0_title")
		22:
			m.hud.hide_overlay(); Game.mode = "play"
		50: shot("1_jenny_dorm")
		52:
			var p = m.players["jenny"]
			p.global_position = m._off("jenny", Vector2i(1,0), Vector3(-2,0.05,1))
			p.rotation.y = -PI/2
			var b = m.bellman
			b.global_position = m._off("jenny", Vector2i(1,0), Vector3(3.3,0.05,-1.2))
			b.look_at(p.global_position, Vector3.UP)
			b.dormant_t = 999.0
			b.set_physics_process(false)
			m.panic = 80.0
		90: shot("2_corridor_bellman")
		92:
			m.panic = 0.0
			m._switch_to("dana")
			m.bellman.global_position = Vector3(300,0,300)
			Game.mode = "play"; m.hud.hide_overlay()
		150: shot("3_dana_lobby")
		152:
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,0), Vector3(-2.5,0.05,0))
			p.rotation.y = -PI/2
			Game.mode = "note"
		153:
			Game.mode = "play"
		190: shot("4_hall_tallow")
		192:
			var p = m.players["dana"]
			p.global_position = m._off("dana", Vector2i(1,1), Vector3(1.5,0.05,1.5))
			m._open_tube()
		230: shot("5_tube_menu")
		232:
			m._close_menu()
			var p = m.players["jenny"]
			m._switch_to("jenny")
			p.global_position = m._off("jenny", Vector2i(2,0), Vector3(0,0.05,0))
		290: shot("6_chapel")
		292: get_tree().quit()
