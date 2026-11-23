extends CharacterBody3D
## Giocatore in prima persona: WASD per muoversi, mouse per guardare,
## tasto sinistro tenuto premuto per scavare, 1/2/3 per cambiare attrezzo.
## A ogni colpo dell'attrezzo: suono, schegge di terra e una leggera vibrazione.

const ViewmodelScript := preload("res://scripts/viewmodel.gd")
const SfxScript := preload("res://scripts/dig_sfx.gd")

const SPEED := 4.0
const JUMP := 4.5
const REACH := 3.5
const SENS := 0.0025

## periodo = durata di un colpo in secondi, scossa = forza della vibrazione al colpo
const TOOLS := [
	{"nome": "Mani", "raggio": 0.65, "potenza": 2.0, "max_mat": 0, "periodo": 0.38, "scossa": 0.30, "schegge": 10},
	{"nome": "Pala", "raggio": 0.9, "potenza": 3.0, "max_mat": 1, "periodo": 0.55, "scossa": 0.45, "schegge": 22},
	{"nome": "Piccone", "raggio": 0.7, "potenza": 6.0, "max_mat": 2, "periodo": 0.62, "scossa": 0.60, "schegge": 18},
]
const SOUND_BY_MAT := ["terra", "dura", "roccia"]
const INTERACT_DIST := 2.8

signal interact(id: String)
signal blocked(reason: String)

var terrain: Node3D
var cam: Camera3D
var viewmodel: Node3D
var sfx: Node3D
var bursts: Array[CPUParticles3D] = []
var next_burst := 0
var state: Node
var tool_i := 0
var ui_open := false
var look_target := ""
var zaino_pieno := false
var digging := false
var force_dig := false   # usato dalla prova automatica
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var last_hit := {}
var removed_since_impact := 0.0
var trauma := 0.0
var shake_t := 0.0


func _ready() -> void:
	cam = $Camera3D
	viewmodel = $Camera3D/Viewmodel
	sfx = $Sfx
	for c in get_children():
		if c is CPUParticles3D:
			bursts.append(c)
	viewmodel.set_tool(tool_i)


## Crea i nodi del giocatore. Usato solo da tools/build_scenes.gd per salvare la scena.
func build_nodes() -> void:
	var col := CollisionShape3D.new()
	col.name = "Collisione"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.55
	camera.fov = 80.0
	camera.near = 0.03
	add_child(camera)
	var flame := OmniLight3D.new()
	flame.name = "FiammaMagica"
	flame.light_color = Color(1.0, 0.62, 0.32)
	flame.light_energy = 1.6
	flame.omni_range = 11.0
	flame.shadow_enabled = true
	flame.position = Vector3(-0.35, -0.2, -0.3)
	camera.add_child(flame)

	var vm: Node3D = ViewmodelScript.new()
	vm.name = "Viewmodel"
	camera.add_child(vm)
	vm.build_nodes()

	var fx: Node3D = SfxScript.new()
	fx.name = "Sfx"
	fx.top_level = true
	add_child(fx)
	fx.build_nodes()

	var chunk_mat := StandardMaterial3D.new()
	chunk_mat.vertex_color_use_as_albedo = true
	chunk_mat.roughness = 1.0
	var chunk_mesh := BoxMesh.new()
	chunk_mesh.size = Vector3(0.05, 0.05, 0.05)
	chunk_mesh.material = chunk_mat
	for i in 4:
		var p := CPUParticles3D.new()
		p.name = "Schegge%d" % (i + 1)
		p.top_level = true
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 24
		p.lifetime = 0.9
		p.mesh = chunk_mesh
		p.direction = Vector3(0, 0, -1)
		p.spread = 55.0
		p.initial_velocity_min = 1.2
		p.initial_velocity_max = 3.2
		p.gravity = Vector3(0, -9.8, 0)
		p.damping_min = 0.5
		p.damping_max = 1.5
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.4
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.12
		add_child(p)


func tool_name() -> String:
	return TOOLS[tool_i]["nome"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		cam.rotate_x(-event.relative.y * SENS)
		cam.rotation.x = clampf(cam.rotation.x, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed and not ui_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if ui_open:
			if event.physical_keycode in [KEY_E, KEY_ESCAPE]:
				interact.emit("chiudi")
			return
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_E:
				if look_target != "":
					interact.emit(look_target)
			KEY_1:
				tool_i = 0
			KEY_2:
				if state.attrezzi[1]:
					tool_i = 1
			KEY_3:
				if state.attrezzi[2]:
					tool_i = 2


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP
	var dir := Vector3.ZERO
	if not ui_open:
		if Input.is_physical_key_pressed(KEY_W): dir.z -= 1
		if Input.is_physical_key_pressed(KEY_S): dir.z += 1
		if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D): dir.x += 1
	dir = (transform.basis * dir.normalized())
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()

	var hit := _aim()
	look_target = ""
	if not hit.is_empty() and hit.collider.has_meta("interact") and cam.global_position.distance_to(hit.position) < INTERACT_DIST:
		look_target = hit.collider.get_meta("interact")
	zaino_pieno = state.zaino_pieno()
	digging = force_dig or (not ui_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if digging and look_target == "":
		_dig(hit, delta)
	else:
		last_hit = {}


func _process(delta: float) -> void:
	viewmodel.set_tool(tool_i)
	var t: Dictionary = TOOLS[tool_i]
	var speed := Vector2(velocity.x, velocity.z).length()
	if viewmodel.step(delta, digging, t["periodo"], speed if is_on_floor() else 0.0):
		_on_impact()
	_update_shake(delta)


func _aim() -> Dictionary:
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


## Scava nel punto mirato, se lo zaino ha ancora posto.
func _dig(hit: Dictionary, delta: float) -> void:
	if hit.is_empty():
		last_hit = {}
		return
	last_hit = {"pos": hit.position, "normal": hit.normal, "terra": hit.collider == terrain.body}
	if zaino_pieno:
		return
	var t: Dictionary = TOOLS[tool_i]
	var v: Vector3 = terrain.dig(hit.position, t["raggio"], t["potenza"] * delta, t["max_mat"])
	state.aggiungi_terra(v)
	removed_since_impact += v.x + v.y + v.z


## Il colpo dell'attrezzo arriva a segno: feedback diverso se si è scavato o no.
func _on_impact() -> void:
	if last_hit.is_empty() or zaino_pieno:
		return
	var pos: Vector3 = last_hit["pos"]
	var n: Vector3 = last_hit["normal"]
	var t: Dictionary = TOOLS[tool_i]
	if last_hit["terra"] and removed_since_impact > 0.0002:
		var m: int = terrain.material_at(pos - n * 0.3)
		sfx.play(SOUND_BY_MAT[m], pos, -2.0 if tool_i == 0 else 0.0)
		_burst(pos, n, terrain.MAT_COLOR[m], t["schegge"])
		_add_trauma(t["scossa"] * (1.0 + 0.4 * m))
	else:
		# pietra della catacomba o materiale troppo duro per questo attrezzo
		if last_hit["terra"]:
			var m: int = terrain.material_at(pos - n * 0.3)
			if m == 1:
				blocked.emit("Terra dura: serve la pala")
			elif m == 2:
				blocked.emit("Roccia: serve il piccone")
		else:
			blocked.emit("Pietra della catacomba: non si scava")
		sfx.play("pietra", pos, -4.0)
		_burst(pos, n, Color(0.45, 0.44, 0.42), 5)
		_add_trauma(0.25)
	removed_since_impact = 0.0


func _burst(pos: Vector3, normal: Vector3, color: Color, amount: int) -> void:
	var p := bursts[next_burst]
	next_burst = (next_burst + 1) % bursts.size()
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	p.global_transform = Transform3D(Basis.looking_at(normal, up), pos + normal * 0.05)
	p.amount = maxi(amount, 1)
	p.color = color
	p.restart()


func _add_trauma(v: float) -> void:
	trauma = minf(trauma + v, 1.0)


## Vibrazione della camera: piccoli spostamenti e rotazioni che si smorzano.
func _update_shake(delta: float) -> void:
	trauma = maxf(trauma - delta * 2.2, 0.0)
	shake_t += delta * 38.0
	var s := trauma * trauma
	cam.h_offset = s * 0.05 * (sin(shake_t * 1.3) + 0.5 * sin(shake_t * 3.1))
	cam.v_offset = s * 0.05 * (sin(shake_t * 1.7 + 1.0) + 0.5 * sin(shake_t * 2.9))
	cam.rotation.z = s * 0.025 * sin(shake_t * 1.1 + 2.0)
