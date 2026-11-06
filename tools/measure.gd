extends SceneTree
func _init() -> void:
	for src in ["res://assets/models/mannequin.glb", "res://assets/models/mannequin_zombie.glb"]:
		var sc: Node3D = load(src).instantiate()
		root.add_child(sc)
		var ap: AnimationPlayer = sc.get_node("AnimationPlayer")
		var sk: Skeleton3D = sc.find_child("Skeleton3D", true, false)
		print(src, " anims: ", ap.get_animation_list())
		var feet := []
		for b in sk.get_bone_count():
			var n := sk.get_bone_name(b)
			if n.to_lower().contains("foot") or n.to_lower().contains("head"):
				feet.append(n)
		print("bones: ", feet)
		var head := "DEF-head" if sk.find_bone("DEF-head") >= 0 else "Head"
		var hb := sk.find_bone(head)
		sk.reset_bone_poses()
		print("head rest global: ", sk.get_bone_global_rest(hb))
		for a in ["Walk", "Jog_Fwd", "Sprint", "Walk_Formal", "Zombie_Walk_Fwd"]:
			if not ap.has_animation(a): continue
			var fb := -1
			for cand in ["DEF-foot.L", "foot_l", "DEF-toe.L"]:
				if sk.find_bone(cand) >= 0:
					fb = sk.find_bone(cand); break
			var anim := ap.get_animation(a)
			ap.play(a)
			var mn := 99.0; var mx := -99.0
			var steps := 60
			for i in steps:
				ap.seek(anim.length * i / steps, true)
				ap.advance(0)
				sk.force_update_all_bone_transforms() if sk.has_method("force_update_all_bone_transforms") else null
				var z := sk.get_bone_global_pose(fb).origin.z
				mn = minf(mn, z); mx = maxf(mx, z)
			print(a, " len %.3f range %.3f speed~ %.3f" % [anim.length, mx - mn, 2.0 * (mx - mn) / anim.length])
		sc.queue_free()
	quit()
