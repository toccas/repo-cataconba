extends SceneTree
const OUT := "C:/Users/ltocc/AppData/Local/Temp/claude/8f654ea5001ddece/1cff861c-eedf-40a0-8fa6-624cd4552ead/scratchpad/"
func _init() -> void:
	var root := Node3D.new(); get_root().add_child(root)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); root.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.2, 0.2, 0.25)
	env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.5
	root.add_child(env)
	var cam := Camera3D.new(); root.add_child(cam)
	var sk = (load("res://scenes/scheletro.tscn") as PackedScene).instantiate()
	root.add_child(sk)
	await process_frame
	sk.anim.play("RESET"); sk.anim.advance(0); sk.anim.stop()
	var b: Node3D = (load("res://modelli/berretto.glb") as PackedScene).instantiate()
	sk.get_node("Corpo/Testa").add_child(b)
	for v in [["b_front", Vector3(0.0, 1.95, 1.1)], ["b_side", Vector3(1.1, 2.0, 0.2)], ["b_back", Vector3(-0.7, 2.2, -0.9)]]:
		cam.look_at_from_position(v[1], Vector3(0, 1.85, 0))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OUT + v[0] + ".png")
	quit()
