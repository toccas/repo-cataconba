extends SceneTree
## Costruisce e salva le scene del gioco (main.tscn, player.tscn, hud.tscn)
## e i suoni provvisori in res://audio/.
## Dopo averlo eseguito, tutto si modifica direttamente dall'editor di Godot.
## ATTENZIONE: rieseguirlo sovrascrive le scene, comprese le modifiche fatte a mano.
## Uso: godot --headless --path . --script res://tools/build_scenes.gd

const MainScript := preload("res://scripts/main.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const SpawnScript := preload("res://scripts/spawn_room.gd")
const StateScript := preload("res://scripts/game_state.gd")
const SfxScript := preload("res://scripts/dig_sfx.gd")
const BucketScript := preload("res://scripts/secchio.gd")
const ViewmodelScript := preload("res://scripts/viewmodel.gd")

const KIT := "res://assetpack/kenney_modular-cave-kit_1.0/Models/GLB format/"
const PEZZI := "res://scenes/pezzi/"
## Altezza utile di stanze e corridoi del kit: fin qui arriva la terra, sopra c'è il soffitto.
const ALTEZZA := 4.0
const PAVIMENTO := 2.0
const MONDO := 64.0

## Pianta della catacomba di prova, su griglia da 4 m. Pavimento a y = 2.
## [nome del nodo, pezzo del kit, posizione (x, z), rotazione in gradi, piena di terra?]
## Rotazioni: corridor va lungo X; corridor-end è aperto verso +X;
## corridor-corner è aperto verso -X e -Z. Con +90 gradi +X diventa -Z.
const SPAWN_POS := Vector2(32, 32)
const LAYOUT := [
	["StanzaSpawn", "room-small", Vector2(32, 32), 0, false],
	["CorridoioEst1", "corridor", Vector2(40, 32), 0, true],
	["CorridoioEst2", "corridor", Vector2(44, 32), 0, true],
	["StanzaEst", "room-small", Vector2(52, 32), 0, true],
	["StanzaEstNicchiaNord", "corridor-end", Vector2(52, 24), -90, true],
	["StanzaEstNicchiaSud", "corridor-end", Vector2(52, 40), 90, true],
	["StanzaEstNicchiaEst", "corridor-end", Vector2(60, 32), 180, true],
	["CorridoioNord1", "corridor", Vector2(32, 24), 90, true],
	["CorridoioNord2", "corridor", Vector2(32, 20), 90, true],
	["StanzaNord", "room-small-variation", Vector2(32, 12), 0, true],
	["StanzaNordNicchiaNord", "corridor-end", Vector2(32, 4), -90, true],
	["StanzaNordNicchiaOvest", "corridor-end", Vector2(24, 12), 0, true],
	["StanzaNordNicchiaEst", "corridor-end", Vector2(40, 12), 180, true],
	["CorridoioOvest1", "corridor", Vector2(24, 32), 0, true],
	["CorridoioOvest2", "corridor", Vector2(20, 32), 0, true],
	["CorridoioOvest3", "corridor", Vector2(16, 32), 0, true],
	["CurvaOvest", "corridor-corner", Vector2(12, 32), -90, true],
	["CorridoioOvestNord1", "corridor", Vector2(12, 28), 90, true],
	["CorridoioOvestNord2", "corridor", Vector2(12, 24), 90, true],
	["FondoOvestNord", "corridor-end", Vector2(12, 20), -90, true],
	["CorridoioSud1", "corridor", Vector2(32, 40), 90, true],
	["CorridoioSud2", "corridor", Vector2(32, 44), 90, true],
	["CorridoioSud3", "corridor", Vector2(32, 48), 90, true],
	["FondoSud", "corridor-end", Vector2(32, 52), 90, true],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	var sounds := _save_sounds()
	_save_pieces()
	_save_bucket()

	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.build_nodes()
	var sfx := player.get_node("Sfx")
	for kind in sounds:
		sfx.set(kind, sounds[kind])
	_save(player, "res://scenes/player.tscn")

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HudScript)
	hud.build_nodes()
	_save(hud, "res://scenes/hud.tscn")

	var main := Node3D.new()
	main.name = "Main"
	main.set_script(MainScript)
	main.add_child(_environment())
	main.add_child(_catacomb())
	main.add_child(_ceiling())
	var terrain := Node3D.new()
	terrain.name = "Terra"
	terrain.set_script(TerrainScript)
	terrain.stone_path = NodePath("../Catacomba")
	main.add_child(terrain)
	var spawn := Node3D.new()
	spawn.name = "Spawn"
	spawn.set_script(SpawnScript)
	spawn.position = Vector3(SPAWN_POS.x, 0, SPAWN_POS.y)
	spawn.build_nodes()
	main.add_child(spawn)
	var state := Node.new()
	state.name = "GameState"
	state.set_script(StateScript)
	main.add_child(state)
	var bucket_root := Node3D.new()
	bucket_root.name = "Secchi"
	main.add_child(bucket_root)
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector3(SPAWN_POS.x, PAVIMENTO + 0.1, SPAWN_POS.y + 2.0)
	main.add_child(p)
	main.add_child(load("res://scenes/hud.tscn").instantiate())
	_save(main, "res://scenes/main.tscn")
	quit()


func _save_sounds() -> Dictionary:
	var gen: Node3D = SfxScript.new()
	var banks: Dictionary = gen.generate_banks()
	gen.free()
	var out := {}
	for kind in banks:
		var arr: Array[AudioStream] = []
		var i := 0
		for w in banks[kind]:
			var path := "res://audio/%s_%d.tres" % [kind, i + 1]
			ResourceSaver.save(w, path)
			arr.append(load(path))
			i += 1
		out[kind] = arr
	return out


func _environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.22, 0.3)
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.name = "Ambiente"
	we.environment = env
	return we


## Una scena per ogni modello del kit in res://scenes/pezzi/: il modello, la sua collisione
## e, per stanze e corridoi, il volume da riempire di terra (meta volume_size / volume_offset).
func _save_pieces() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PEZZI))
	for f in DirAccess.get_files_at(KIT):
		if not f.ends_with(".glb"):
			continue
		var id := f.get_basename()
		var root := Node3D.new()
		root.name = id.to_pascal_case()
		var model: Node3D = (load(KIT + f) as PackedScene).instantiate()
		model.name = "Modello"
		root.add_child(model)
		var faces := PackedVector3Array()
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D()
			var n: Node = mi
			while n != root:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			faces.append_array(t * mi.mesh.get_faces())
			box = t * mi.get_aabb() if first else box.merge(t * mi.get_aabb())
			first = false
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		ResourceSaver.save(shape, PEZZI + id + "_collisione.res")
		var body := StaticBody3D.new()
		body.name = "Corpo"
		var cs := CollisionShape3D.new()
		cs.name = "Collisione"
		cs.shape = load(PEZZI + id + "_collisione.res")
		body.add_child(cs)
		root.add_child(body)
		if id.begins_with("corridor") or id.begins_with("room"):
			var c := box.get_center()
			root.set_meta("volume_size", Vector3(snappedf(box.size.x, 4.0), ALTEZZA, snappedf(box.size.z, 4.0)))
			root.set_meta("volume_offset", Vector3(snappedf(c.x, 2.0), ALTEZZA / 2.0, snappedf(c.z, 2.0)))
			root.set_meta("terra", true)
		_save(root, PEZZI + id + ".tscn")


## Il secchio pieno che si lancia: la botte del Mini Dungeon con fisica.
func _save_bucket() -> void:
	var b := RigidBody3D.new()
	b.name = "Secchio"
	b.set_script(BucketScript)
	b.mass = 6.0
	b.continuous_cd = true
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector3(0, 0.168, 0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.15
	b.physics_material_override = pm
	b.set_meta("interact", "secchio")
	b.add_to_group("secchi", true)
	var model: Node3D = (load(SpawnScript.DUNGEON + "barrel.glb") as PackedScene).instantiate()
	model.name = "Modello"
	model.scale = Vector3.ONE * SpawnScript.BARREL_SCALE
	b.add_child(model)
	b.add_child(ViewmodelScript.dirt_disc())
	var cs := CollisionShape3D.new()
	cs.name = "Collisione"
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.17
	cyl.height = 0.33
	cs.shape = cyl
	cs.position.y = 0.168
	b.add_child(cs)
	_save(b, "res://scenes/secchio.tscn")


## La catacomba: pezzi del kit (la loro pietra non si scava). Ogni pezzo con meta
## "terra" = true viene riempito di terra dal nodo Terra.
func _catacomb() -> Node3D:
	var cat := Node3D.new()
	cat.name = "Catacomba"
	for e in LAYOUT:
		var piece: Node3D = (load(PEZZI + e[1] + ".tscn") as PackedScene).instantiate()
		piece.name = e[0]
		piece.position = Vector3(e[2].x, PAVIMENTO, e[2].y)
		piece.rotation_degrees.y = e[3]
		piece.set_meta("terra", e[4])
		if e[2] == SPAWN_POS:
			piece.set_meta("spawn", true)
		cat.add_child(piece)
	return cat


## Il soffitto: i pezzi del kit sono aperti in alto. Una lastra di pietra sopra tutto,
## con il pozzo del montacarichi sopra lo spawn.
func _ceiling() -> CSGCombiner3D:
	var roof := CSGCombiner3D.new()
	roof.name = "Soffitto"
	roof.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.27, 0.25)
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	var tex := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.02
	tex.noise = n
	tex.seamless = true
	mat.albedo_texture = tex
	var slab := CSGBox3D.new()
	slab.name = "Lastra"
	slab.size = Vector3(MONDO, 3.0, MONDO)
	slab.position = Vector3(MONDO / 2.0, PAVIMENTO + ALTEZZA - 0.05 + 1.5, MONDO / 2.0)
	slab.material = mat
	roof.add_child(slab)
	var shaft := CSGBox3D.new()
	shaft.name = "PozzoMontacarichi"
	shaft.operation = CSGShape3D.OPERATION_SUBTRACTION
	shaft.size = Vector3(2.5, 3.4, 2.5)
	shaft.position = Vector3(SPAWN_POS.x + SpawnScript.LIFT_POS.x, slab.position.y, SPAWN_POS.y + SpawnScript.LIFT_POS.z)
	shaft.material = mat
	roof.add_child(shaft)
	return roof


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("%s: %s" % [path, "salvata" if err == OK else "ERRORE %d" % err])
	root.free()


## Imposta il proprietario di tutti i nodi (così vengono salvati) e dà nomi leggibili.
func _own(n: Node, root: Node) -> void:
	var i := 0
	for c in n.get_children():
		if str(c.name).begins_with("@"):
			c.name = "%s%d" % [c.get_class(), i]
		i += 1
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)
