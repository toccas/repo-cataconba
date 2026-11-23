extends Node3D
## Arredo della stanza di spawn: montacarichi con la pila di secchi, leva, negozio, torce.
## Gli oggetti con cui si interagisce sono StaticBody3D con il meta "interact".
## Le posizioni sono relative al nodo Spawn, che sta al centro della stanza iniziale.

const FLOOR_Y := 2.0
const LIFT_POS := Vector3(-2.75, FLOOR_Y, -2.75)
const LIFT_SIZE := 2.2
const LEVER_POS := Vector3(-1.45, FLOOR_Y, -3.65)
const SHOP_POS := Vector3(2.9, FLOOR_Y, -3.4)
const LIFT_TRAVEL := 5.0
const MAX_VISIBLE_BUCKETS := 75
const BARREL_SCALE := 0.7
const DUNGEON := "res://assetpack/kenney_mini-dungeon/Models/GLB format/"
const GRAVEYARD := "res://assetpack/kenney_graveyard-kit_5.0/Models/GLB format/"

var lift: Node3D
var pile: MultiMeshInstance3D
var lever_handle: Node3D
var busy := false
var lift_base_y := 0.0


func _ready() -> void:
	lift = $Montacarichi
	pile = $Montacarichi/Pila
	lever_handle = $ManigliaLeva
	lift_base_y = lift.position.y
	_arrange_pile()


## Posizioni dei secchi sul montacarichi: 5 x 5 per strato, 3 strati.
## Si calcolano all'avvio perché le posizioni di un MultiMesh non restano salvate nella scena.
func _arrange_pile() -> void:
	var mm := pile.multimesh
	mm.mesh = _barrel_mesh()
	mm.instance_count = MAX_VISIBLE_BUCKETS
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in MAX_VISIBLE_BUCKETS:
		var layer := i / 25
		var k := i % 25
		var p := LIFT_POS + Vector3((k % 5 - 2) * 0.4, 0.12 + layer * BARREL_SCALE * 0.48, (k / 5 - 2) * 0.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * BARREL_SCALE)
		mm.set_instance_transform(i, Transform3D(b, p))


## La botte del Mini Dungeon: ogni secchio di terra sul montacarichi è una botticella.
func _barrel_mesh() -> Mesh:
	var n: Node = (load(DUNGEON + "barrel.glb") as PackedScene).instantiate()
	var mesh: Mesh = (n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	n.free()
	return mesh


func lift_sound_pos() -> Vector3:
	return pile.global_position + LIFT_POS + Vector3(0, 0.5, 0)


func lever_sound_pos() -> Vector3:
	return lever_handle.global_position


## Crea l'arredo. Usato solo da tools/build_scenes.gd per salvare la scena:
## dopo si può spostare e modificare tutto dall'editor.
func build_nodes() -> void:
	var wood := _mat(Color(0.30, 0.19, 0.11))
	var dark_wood := _mat(Color(0.20, 0.13, 0.08))
	var iron := _mat(Color(0.25, 0.25, 0.27), 0.7)

	# --- montacarichi ---
	lift = Node3D.new()
	lift.name = "Montacarichi"
	add_child(lift)
	var plat := BoxMesh.new()
	plat.size = Vector3(LIFT_SIZE, 0.12, LIFT_SIZE)
	lift.add_child(_mesh(plat, wood, LIFT_POS + Vector3(0, 0.06, 0)))
	pile = MultiMeshInstance3D.new()
	pile.name = "Pila"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _barrel_mesh()
	mm.instance_count = MAX_VISIBLE_BUCKETS
	mm.visible_instance_count = 0
	pile.multimesh = mm
	lift.add_child(pile)
	_prop(DUNGEON + "wood-structure", "Castello", LIFT_POS, Vector3(2.3, 4.0, 2.3))
	_prop(GRAVEYARD + "shovel-dirt", "PalaNellaTerra", LIFT_POS + Vector3(2.0, 0, 1.2), Vector3.ONE * 2.0, 0.6)
	_interact_box("montacarichi", "AreaMontacarichi", LIFT_POS + Vector3(0, 0.6, 0), Vector3(LIFT_SIZE, 1.2, LIFT_SIZE))
	_sign("Montacarichi", LIFT_POS + Vector3(1.3, 2.6, 1.3))

	# --- leva ---
	var base := BoxMesh.new()
	base.size = Vector3(0.18, 0.7, 0.18)
	add_child(_mesh(base, dark_wood, LEVER_POS + Vector3(0, 0.35, 0)))
	lever_handle = Node3D.new()
	lever_handle.name = "ManigliaLeva"
	lever_handle.position = LEVER_POS + Vector3(0, 0.7, 0)
	lever_handle.rotation.x = -0.6
	add_child(lever_handle)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.025
	stick.bottom_radius = 0.025
	stick.height = 0.5
	lever_handle.add_child(_mesh(stick, iron, Vector3(0, 0.25, 0)))
	var knob := SphereMesh.new()
	knob.radius = 0.05
	knob.height = 0.1
	lever_handle.add_child(_mesh(knob, _mat(Color(0.5, 0.1, 0.08)), Vector3(0, 0.5, 0)))
	_interact_box("leva", "Leva", LEVER_POS + Vector3(0, 0.6, 0), Vector3(0.35, 1.2, 0.35))

	# --- negozio ---
	_prop(DUNGEON + "table", "Bancone", SHOP_POS, Vector3.ONE * 3.0)
	_interact_box("negozio", "Negozio", SHOP_POS + Vector3(0, 0.47, 0), Vector3(2.6, 0.94, 1.9))
	_prop(DUNGEON + "coin", "Moneta", SHOP_POS + Vector3(0.5, 0.93, 0.2), Vector3.ONE * 0.8, -0.3)
	_prop(DUNGEON + "chest", "Forziere", SHOP_POS + Vector3(-2.0, 0, -0.8), Vector3.ONE * 2.0, 0.4, true)
	_sign("Negozio", SHOP_POS + Vector3(0, 2.3, 0))
	_lantern("CandeleNegozio", GRAVEYARD + "candle-multiple", SHOP_POS + Vector3(-0.7, 0.93, -0.3), 2.0, 0.9, 5.0)

	# --- barili con le lanterne ---
	for side in [-1.0, 1.0]:
		var p := Vector3(4.5 * side, FLOOR_Y, 3.5)
		var tag := "Ovest" if side < 0 else "Est"
		_prop(DUNGEON + "barrel", "Barile" + tag, p, Vector3.ONE * 2.0, 0.0, true)
		_prop(DUNGEON + "barrel", "BarilePiccolo" + tag, p + Vector3(-0.3 * side, 0, 1.0), Vector3.ONE * 1.5, 0.8, true)
		_lantern("Lanterna" + tag, GRAVEYARD + "lantern-candle", p + Vector3(0, 0.96, 0), 2.0, 1.6, 10.0)

	# --- puntelli di legno agli ingressi e detriti ---
	for d in [["Est", Vector3(5.8, 0, 0), 90.0], ["Ovest", Vector3(-5.8, 0, 0), 90.0],
			["Nord", Vector3(0, 0, -5.8), 0.0], ["Sud", Vector3(0, 0, 5.8), 0.0]]:
		_prop(DUNGEON + "wood-support", "Puntello" + d[0], d[1] + Vector3(0, FLOOR_Y, 0), Vector3(2.8, 4.0, 2.0), deg_to_rad(d[2]))
	_prop(GRAVEYARD + "debris-wood", "Assi", Vector3(-3.6, FLOOR_Y, 1.0), Vector3.ONE * 2.5, 0.7)
	_prop(DUNGEON + "stones", "Sassi", Vector3(1.8, FLOOR_Y, 4.4), Vector3.ONE * 1.5, 1.2)


## Mette un modello degli asset pack. Con collide aggiunge una collisione a scatola.
func _prop(path: String, node_name: String, pos: Vector3, scl: Vector3, rot_y := 0.0, collide := false) -> Node3D:
	var n: Node3D = (load(path + ".glb") as PackedScene).instantiate()
	n.name = node_name
	n.position = pos
	n.rotation.y = rot_y
	n.scale = scl
	add_child(n)
	if collide:
		var box := AABB()
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			box = box.merge(mi.get_aabb()) if box.has_volume() else mi.get_aabb()
		var body := StaticBody3D.new()
		body.name = node_name + "Collisione"
		body.position = pos + Basis(Vector3.UP, rot_y) * (box.get_center() * scl)
		body.rotation.y = rot_y
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size * scl
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
	return n


## Una lanterna (modello) con la sua luce.
func _lantern(node_name: String, path: String, pos: Vector3, scl: float, energy: float, light_range: float) -> void:
	_prop(path, node_name, pos, Vector3.ONE * scl)
	var light := OmniLight3D.new()
	light.name = node_name + "Luce"
	light.position = pos + Vector3(0, 0.45 * scl, 0)
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = true
	add_child(light)


func update_pile(secchi: float) -> void:
	pile.multimesh.visible_instance_count = mini(floori(secchi), MAX_VISIBLE_BUCKETS)


## Tira la leva e fa salire il montacarichi; on_top viene chiamata in cima (vendita).
func send(on_top: Callable) -> void:
	busy = true
	var lt := create_tween()
	lt.tween_property(lever_handle, "rotation:x", 0.6, 0.15)
	lt.tween_interval(0.4)
	lt.tween_property(lever_handle, "rotation:x", -0.6, 0.4)
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(lift, "position:y", lift_base_y + LIFT_TRAVEL, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(on_top)
	tw.tween_interval(0.5)
	tw.tween_property(lift, "position:y", lift_base_y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): busy = false)


func _mat(c: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.5 if metal > 0.0 else 0.9
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


func _interact_box(id: String, node_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.set_meta("interact", id)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	add_child(body)


func _sign(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.004
	l.font_size = 64
	l.outline_size = 12
	l.modulate = Color(0.95, 0.85, 0.65)
	l.name = "Cartello" + text
	add_child(l)
