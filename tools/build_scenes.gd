extends Node
## Costruisce e salva le scene del gioco (main.tscn, player.tscn, hud.tscn)
## e i suoni provvisori in res://audio/.
## Dopo averlo eseguito, tutto si modifica direttamente dall'editor di Godot.
## ATTENZIONE: rieseguirlo sovrascrive le scene, comprese le modifiche fatte a mano.
## Uso: godot --headless --path . res://tools/build_scenes.tscn
## (gira come scena, non con --script, così l'autoload Rete esiste e main.gd si carica)

const MainScript := preload("res://scripts/main.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const DevScript := preload("res://scripts/dev_tool.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const SpawnScript := preload("res://scripts/spawn_room.gd")
const StateScript := preload("res://scripts/game_state.gd")
const SfxScript := preload("res://scripts/dig_sfx.gd")
const BucketScript := preload("res://scripts/secchio.gd")
const BoneScript := preload("res://scripts/osso.gd")
const DynamiteScript := preload("res://scripts/dinamite.gd")

## Ossa del primo scheletro, sepolte nella terra di corridoi e stanze: [parte, posizione].
## Più sono lontane dallo spawn più è dura arrivarci (terra dura e roccia).
const OSSA := [
	# primo scheletro: nei raggi e nelle stanze vicine allo spawn
	["Testa", "Testa", Vector3(41.0, 2.35, 32.4)],
	["BraccioSinistro", "BraccioSinistro", Vector3(21.5, 2.3, 31.6)],
	["BraccioDestro", "BraccioDestro", Vector3(32.4, 2.3, 22.5)],
	["GambaDestra", "GambaDestra", Vector3(31.6, 2.3, 43.0)],
	["Torace", "Torace", Vector3(51.0, 2.4, 31.0)],
	["GambaSinistra", "GambaSinistra", Vector3(33.0, 2.3, 13.0)],
	# secondo scheletro: nell'anello e nelle stanze d'angolo (terra più dura)
	["Testa2", "Testa", Vector3(10.0, 2.35, 10.5)],
	["Torace2", "Torace", Vector3(53.5, 2.4, 54.0)],
	["BraccioDestro2", "BraccioDestro", Vector3(42.5, 2.3, 12.4)],
	["BraccioSinistro2", "BraccioSinistro", Vector3(12.4, 2.3, 42.0)],
	["GambaDestra2", "GambaDestra", Vector3(31.0, 2.3, 54.5)],
	["GambaSinistra2", "GambaSinistra", Vector3(9.5, 2.3, 33.5)],
	# la chiave del cancello: in fondo alla nicchia ovest dell'angolo sud-ovest
	["Chiave", "Chiave", Vector3(4.6, 2.3, 52.3)],
]
## Cancello verso la prossima zona: sul portale est della stanza est.
const CANCELLO := Vector3(57.7, 2.0, 32.0)
const ViewmodelScript := preload("res://scripts/viewmodel.gd")

const KIT := "res://assetpack/kenney_modular-cave-kit_1.0/Models/GLB format/"
## Pezzi della cripta generati da tools/make_crypt.gd (con la loro collisione semplice).
const CRIPTA := "res://modelli/cripta/"
const PEZZI := "res://scenes/pezzi/"
## Altezza utile di stanze e corridoi del kit: fin qui arriva la terra, sopra c'è il soffitto.
const ALTEZZA := 4.0
const PAVIMENTO := 2.0
const MONDO := 64.0

## Pianta della catacomba di prova, su griglia da 4 m. Pavimento a y = 2.
## [nome del nodo, pezzo del kit, posizione (x, z), rotazione in gradi, piena di terra?]
## Pezzi della cripta (tools/make_crypt.gd). Rotazioni: cripta-corridoio va lungo X;
## cripta-fondo è aperto verso +X; cripta-curva è aperta verso -X e -Z.
## Con +90 gradi +X diventa -Z.
const SPAWN_POS := Vector2(32, 32)
const LAYOUT := [
	["StanzaSpawn", "cripta-stanza-spawn", Vector2(32, 32), 0, false],
	["CorridoioEst1", "cripta-corridoio", Vector2(40, 32), 0, true],
	["CorridoioEst2", "cripta-corridoio", Vector2(44, 32), 0, true],
	["CorridoioOvest1", "cripta-corridoio", Vector2(24, 32), 0, true],
	["CorridoioOvest2", "cripta-corridoio", Vector2(20, 32), 0, true],
	["CorridoioNord1", "cripta-corridoio", Vector2(32, 24), 90, true],
	["CorridoioNord2", "cripta-corridoio", Vector2(32, 20), 90, true],
	["CorridoioSud1", "cripta-corridoio", Vector2(32, 40), 90, true],
	["CorridoioSud2", "cripta-corridoio", Vector2(32, 44), 90, true],
	["AnelloNordOvest1", "cripta-corridoio", Vector2(20, 12), 0, true],
	["AnelloNordOvest2", "cripta-corridoio", Vector2(24, 12), 0, true],
	["AnelloNordEst1", "cripta-corridoio", Vector2(40, 12), 0, true],
	["AnelloNordEst2", "cripta-corridoio", Vector2(44, 12), 0, true],
	["AnelloEstNord1", "cripta-corridoio", Vector2(52, 20), 90, true],
	["AnelloEstNord2", "cripta-corridoio", Vector2(52, 24), 90, true],
	["AnelloEstSud1", "cripta-corridoio", Vector2(52, 40), 90, true],
	["AnelloEstSud2", "cripta-corridoio", Vector2(52, 44), 90, true],
	["AnelloSudEst1", "cripta-corridoio", Vector2(40, 52), 0, true],
	["AnelloSudEst2", "cripta-corridoio", Vector2(44, 52), 0, true],
	["AnelloSudOvest1", "cripta-corridoio", Vector2(20, 52), 0, true],
	["AnelloSudOvest2", "cripta-corridoio", Vector2(24, 52), 0, true],
	["AnelloOvestSud1", "cripta-corridoio", Vector2(12, 40), 90, true],
	["AnelloOvestSud2", "cripta-corridoio", Vector2(12, 44), 90, true],
	["AnelloOvestNord1", "cripta-corridoio", Vector2(12, 20), 90, true],
	["AnelloOvestNord2", "cripta-corridoio", Vector2(12, 24), 90, true],
	["StanzaNord", "cripta-stanza", Vector2(32, 12), 0, true],
	["StanzaNordNicchiaNord", "cripta-fondo", Vector2(32, 4), -90, true],
	["StanzaEst", "cripta-stanza", Vector2(52, 32), 0, true],
	["OltreIlCancello", "cripta-fondo", Vector2(60, 32), 180, true],
	["StanzaSud", "cripta-stanza", Vector2(32, 52), 0, true],
	["StanzaSudNicchiaSud", "cripta-fondo", Vector2(32, 60), 90, true],
	["StanzaOvest", "cripta-stanza", Vector2(12, 32), 0, true],
	["StanzaOvestNicchiaOvest", "cripta-fondo", Vector2(4, 32), 0, true],
	["AngoloNordOvest", "cripta-stanza", Vector2(12, 12), 0, true],
	["AngoloNordOvestNicchiaNord", "cripta-fondo", Vector2(12, 4), -90, true],
	["AngoloNordOvestNicchiaOvest", "cripta-fondo", Vector2(4, 12), 0, true],
	["AngoloNordEst", "cripta-stanza", Vector2(52, 12), 0, true],
	["AngoloNordEstNicchiaNord", "cripta-fondo", Vector2(52, 4), -90, true],
	["AngoloNordEstNicchiaEst", "cripta-fondo", Vector2(60, 12), 180, true],
	["AngoloSudEst", "cripta-stanza", Vector2(52, 52), 0, true],
	["AngoloSudEstNicchiaSud", "cripta-fondo", Vector2(52, 60), 90, true],
	["AngoloSudEstNicchiaEst", "cripta-fondo", Vector2(60, 52), 180, true],
	["AngoloSudOvest", "cripta-stanza", Vector2(12, 52), 0, true],
	["AngoloSudOvestNicchiaSud", "cripta-fondo", Vector2(12, 60), 90, true],
	["AngoloSudOvestNicchiaOvest", "cripta-fondo", Vector2(4, 52), 0, true],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	var sounds := _save_sounds()
	_save_pieces()
	_save_bucket()
	_save_bone()
	_save_dynamite()
	_save_keeper()
	_save_cart()

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

	var dev := CanvasLayer.new()
	dev.name = "DevTool"
	dev.set_script(DevScript)
	dev.build_nodes()
	_save(dev, "res://scenes/dev_tool.tscn")

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
	var bones := Node3D.new()
	bones.name = "Ossa"
	main.add_child(bones)
	var dyns := Node3D.new()
	dyns.name = "Dinamiti"
	main.add_child(dyns)
	var rails := Node3D.new()
	rails.name = "Binari"
	rails.set_script(load("res://scripts/binari.gd"))
	main.add_child(rails)
	main.add_child(_gate())
	var grid := Node3D.new()
	grid.name = "Griglia"
	grid.set_script(load("res://scripts/griglia.gd"))
	main.add_child(grid)
	var bone_scene: PackedScene = load("res://scenes/osso.tscn")
	for o in OSSA:
		var b: RigidBody3D = bone_scene.instantiate()
		b.name = o[0]
		b.parte = o[1]
		b.freeze = true
		b.position = o[2]
		b.rotation = Vector3(PI / 2.0 * (0.3 + 0.4 * (o[2].x - floorf(o[2].x))), o[2].z, 0.0)
		bones.add_child(b)
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector3(SPAWN_POS.x, PAVIMENTO + 0.1, SPAWN_POS.y + 2.0)
	main.add_child(p)
	main.add_child(load("res://scenes/hud.tscn").instantiate())
	main.add_child(load("res://scenes/dev_tool.tscn").instantiate())
	_save(main, "res://scenes/main.tscn")
	get_tree().quit()


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
	for dir in [KIT, CRIPTA]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".glb"):
				_save_piece(dir, f.get_basename())


func _save_piece(dir: String, id: String) -> void:
	var root := Node3D.new()
	root.name = id.to_pascal_case()
	var model: Node3D = (load(dir + id + ".glb") as PackedScene).instantiate()
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
	var col_path := dir + id + "_collisione.res"
	if not ResourceLoader.exists(col_path):
		# kit Kenney: collisione presa dalla mesh stessa
		col_path = PEZZI + id + "_collisione.res"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		ResourceSaver.save(shape, col_path)
	var body := StaticBody3D.new()
	body.name = "Corpo"
	var cs := CollisionShape3D.new()
	cs.name = "Collisione"
	cs.shape = load(col_path)
	body.add_child(cs)
	root.add_child(body)
	if id.begins_with("corridor") or id.begins_with("room") or id.begins_with("cripta"):
		var c := box.get_center()
		root.set_meta("volume_size", Vector3(snappedf(box.size.x, 4.0), ALTEZZA, snappedf(box.size.z, 4.0)))
		root.set_meta("volume_offset", Vector3(snappedf(c.x, 2.0), ALTEZZA / 2.0, snappedf(c.z, 2.0)))
		root.set_meta("terra", true)
	_save(root, PEZZI + id + ".tscn")


## Cancello di ferro che chiude la zona: si apre con la chiave (E con la chiave in mano).
## Le sbarre (nodo Sbarre) salgono quando si apre.
func _gate() -> Node3D:
	var g := Node3D.new()
	g.name = "Cancello"
	g.position = CANCELLO
	g.rotation.y = PI / 2.0
	var arch: Node3D = (load(KIT + "gate.glb") as PackedScene).instantiate()
	arch.name = "Arco"
	arch.scale = Vector3(0.68, 0.72, 0.6)
	g.add_child(arch)
	var bars: Node3D = (load(KIT + "gate-metal-bars.glb") as PackedScene).instantiate()
	bars.name = "Sbarre"
	bars.scale = Vector3(0.68, 0.72, 0.6)
	g.add_child(bars)
	var body := StaticBody3D.new()
	body.name = "Blocco"
	body.set_meta("interact", "cancello")
	var cs := CollisionShape3D.new()
	cs.name = "Collisione"
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.8, 3.2, 0.5)
	cs.shape = bs
	cs.position = Vector3(0, 1.6, 0)
	body.add_child(cs)
	g.add_child(body)
	var sign := Label3D.new()
	sign.name = "Scritta"
	sign.text = "Prossima zona"
	sign.position = Vector3(0, 3.35, 0.35)
	sign.pixel_size = 0.004
	sign.font_size = 56
	sign.outline_size = 10
	sign.modulate = Color(0.95, 0.85, 0.6)
	g.add_child(sign)
	return g


## Il negoziante: uno scheletro con il berretto viola. La scena si crea solo se non c'è:
## poi si modifica a mano nell'editor (berretto compreso) e il builder non la tocca più.
func _save_keeper() -> void:
	if ResourceLoader.exists("res://scenes/negoziante.tscn"):
		print("res://scenes/negoziante.tscn: esiste già, non la tocco")
		return
	var root := Node3D.new()
	root.name = "Negoziante"
	var sk: Node3D = (load("res://scenes/scheletro.tscn") as PackedScene).instantiate()
	sk.name = "Scheletro"
	root.add_child(sk)
	var beret: Node3D = (load("res://modelli/berretto.glb") as PackedScene).instantiate()
	beret.name = "Berretto"
	sk.get_node("Corpo/Testa").add_child(beret)
	_save(root, "res://scenes/negoziante.tscn")


## Carrello da miniera: base con le ruote, cassone che si ribalta (perno sul lato +X),
## 6 secchi dentro (visibili secondo il carico), area per l'interazione (E).
func _save_cart() -> void:
	var cart := Node3D.new()
	cart.name = "Vagone"
	var base: Node3D = (load("res://modelli/vagone_base.glb") as PackedScene).instantiate()
	base.name = "Base"
	cart.add_child(base)
	var tip := Node3D.new()
	tip.name = "Cassone"
	tip.position = Vector3(0.35, 0.24, 0)
	cart.add_child(tip)
	var body: Node3D = (load("res://modelli/vagone_cassone.glb") as PackedScene).instantiate()
	body.name = "Modello"
	tip.add_child(body)
	var load_node := Node3D.new()
	load_node.name = "Carico"
	tip.add_child(load_node)
	for i in 6:
		var bucket: Node3D = (load(SpawnScript.DUNGEON + "barrel.glb") as PackedScene).instantiate()
		bucket.name = "Secchio%d" % i
		bucket.scale = Vector3.ONE * SpawnScript.BARREL_SCALE
		bucket.position = Vector3(-0.35 + (i % 2 - 0.5) * 0.3, 0.07 + (i / 4) * 0.34, ((i / 2) % 2 - 0.5) * 0.4 if i < 4 else 0.0)
		bucket.visible = false
		load_node.add_child(bucket)
	var area := StaticBody3D.new()
	area.name = "Area"
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("interact", "vagone")
	var cs := CollisionShape3D.new()
	cs.name = "Collisione"
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 0.8, 1.1)
	cs.shape = bs
	cs.position = Vector3(0, 0.45, 0)
	area.add_child(cs)
	cart.add_child(area)
	_save(cart, "res://scenes/vagone.tscn")


## Candelotto di dinamite lanciato: corpo fisico, scintille e luce della miccia.
func _save_dynamite() -> void:
	var b := RigidBody3D.new()
	b.name = "Dinamite"
	b.set_script(DynamiteScript)
	b.mass = 0.5
	b.continuous_cd = true
	# rimbalza poco e rotola poco: resta vicino a dove la lanci
	b.linear_damp = 0.6
	b.angular_damp = 2.0
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	pm.bounce = 0.02
	b.physics_material_override = pm
	var model: Node3D = (load("res://modelli/dinamite.glb") as PackedScene).instantiate()
	model.name = "Modello"
	b.add_child(model)
	var cs := CollisionShape3D.new()
	cs.name = "Collisione"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.06
	cap.height = 0.3
	cs.shape = cap
	b.add_child(cs)
	var sparks := CPUParticles3D.new()
	sparks.name = "Scintille"
	sparks.position = Vector3(0.02, 0.2, 0.01)
	sparks.amount = 24
	sparks.lifetime = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 1.2
	sparks.gravity = Vector3(0, -2, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.albedo_color = Color(1.0, 0.8, 0.3)
	sm.material = spm
	sparks.mesh = sm
	b.add_child(sparks)
	var light := OmniLight3D.new()
	light.name = "Luce"
	light.position = Vector3(0.02, 0.2, 0.01)
	light.light_color = Color(1.0, 0.65, 0.25)
	light.light_energy = 0.8
	light.omni_range = 2.5
	b.add_child(light)
	_save(b, "res://scenes/dinamite.tscn")


## Un pezzo di scheletro raccoglibile: corpo fisico, il modello lo crea osso.gd.
func _save_bone() -> void:
	var b := RigidBody3D.new()
	b.name = "Osso"
	b.set_script(BoneScript)
	b.mass = 3.0
	b.continuous_cd = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.1
	b.physics_material_override = pm
	b.set_meta("interact", "osso")
	b.add_to_group("ossa", true)
	var cs := CollisionShape3D.new()
	cs.name = "Collisione"
	cs.shape = BoxShape3D.new()
	b.add_child(cs)
	_save(b, "res://scenes/osso.tscn")


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
	var k := 0
	for e in LAYOUT:
		var id: String = e[1]
		var rot: float = e[3]
		if id == "cripta-corridoio":
			# tre varianti del corridoio (loculi in punti diversi), a volte girate di 180 gradi
			id = ["cripta-corridoio", "cripta-corridoio-2", "cripta-corridoio-3"][k % 3]
			rot += 180.0 if (k / 3) % 2 == 1 else 0.0
			k += 1
		var piece: Node3D = (load(PEZZI + id + ".tscn") as PackedScene).instantiate()
		piece.name = e[0]
		piece.position = Vector3(e[2].x, PAVIMENTO, e[2].y)
		piece.rotation_degrees.y = rot
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
	# pietra di tufo a lastre irregolari, chiara come i muri (non deve sembrare terra)
	mat.albedo_color = Color(0.70, 0.64, 0.51)
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	var tex := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.frequency = 0.035
	tex.noise = n
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.42, 0.36))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	ramp.set_offset(1, 0.12)
	tex.color_ramp = ramp
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
## Restituisce true se dentro n c'è almeno un nodo aggiunto qui (di proprietà di root).
func _own(n: Node, root: Node) -> bool:
	var i := 0
	var found := false
	for c in n.get_children():
		if str(c.name).begins_with("@"):
			c.name = "%s%d" % [c.get_class(), i]
		i += 1
		var added := c.owner == null
		if added:
			c.owner = root
			found = true
		if c.scene_file_path == "" or c.owner == root:
			var inside := _own(c, root)
			found = found or inside
			# nodi aggiunti dentro una scena istanziata (es. il berretto sul negoziante):
			# Godot li salva solo se l'istanza ha i "figli modificabili"
			if inside and c.scene_file_path != "" and c.owner == root:
				root.set_editable_instance(c, true)
	return found
