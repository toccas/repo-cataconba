extends SceneTree
## Scheletro scomponibile in 6 pezzi (testa, torace, braccio destro e sinistro,
## gamba destra e sinistra), in stile low-poly Kenney. Braccia e gambe hanno il
## gomito e il ginocchio (sotto-perni Avambraccio e Stinco), la testa ha la mandibola
## e gli occhi che si accendono.
##
## Va eseguito due volte (la seconda dopo che Godot ha importato i modelli):
##   godot --headless --path . --script res://tools/make_skeleton.gd
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/make_skeleton.gd -- --scena
## La prima volta crea i modelli in res://modelli/scheletro/, la seconda la scena
## res://scenes/scheletro.tscn con i perni dei pezzi e le animazioni "idle" e "cammina".
## Lo scheletro guarda verso +Z, è alto circa 1,85 m, i piedi sono a y = 0.
## braccio.glb e gamba.glb (pezzo intero, dritto) servono per le ossa sciolte e in mano.

const LowPoly := preload("res://tools/low_poly.gd")
const SkeletonScript := preload("res://scripts/scheletro.gd")
const OUT := "res://modelli/scheletro/"

const OSSO := Color(0.92, 0.88, 0.77)
const OSSO_SCURO := Color(0.77, 0.72, 0.61)
const OSSO_CHIARO := Color(0.97, 0.95, 0.88)
const BUIO := Color(0.10, 0.08, 0.07)

## Perni dei pezzi (nel nodo Corpo).
const ANCA := 0.9
const SPALLA := 1.5
const COLLO := 1.56
const GOMITO := 0.31     # dalla spalla
const GINOCCHIO := 0.44  # dall'anca
const PERNI := {
	"Torace": Vector3(0, ANCA, 0),
	"Testa": Vector3(0, COLLO, 0),
	"BraccioDestro": Vector3(-0.25, SPALLA, 0),
	"BraccioSinistro": Vector3(0.25, SPALLA, 0),
	"GambaDestra": Vector3(-0.1, ANCA, 0),
	"GambaSinistra": Vector3(0.1, ANCA, 0),
}
## Braccia leggermente aperte e gomiti un po' piegati a riposo.
const RIPOSO := {
	"BraccioDestro": Vector3(0, 0, -0.1),
	"BraccioSinistro": Vector3(0, 0, 0.1),
}
const GOMITO_RIPOSO := Vector3(-0.15, 0, 0)

var lp := LowPoly.new()


func _init() -> void:
	if "--scena" in OS.get_cmdline_user_args():
		_build_scene()
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		_head()
		lp.save_glb(OUT + "testa.glb", "testa")
		_jaw()
		lp.save_glb(OUT + "mascella.glb", "mascella")
		_torso()
		lp.save_glb(OUT + "torace.glb", "torace")
		_arm_upper(Vector3.ZERO)
		lp.save_glb(OUT + "braccio_sopra.glb", "braccio_sopra")
		_arm_lower(Vector3.ZERO)
		lp.save_glb(OUT + "braccio_sotto.glb", "braccio_sotto")
		_arm_upper(Vector3.ZERO)
		_arm_lower(Vector3(0, -GOMITO, 0))
		lp.save_glb(OUT + "braccio.glb", "braccio")
		_leg_upper(Vector3.ZERO)
		lp.save_glb(OUT + "gamba_sopra.glb", "gamba_sopra")
		_leg_lower(Vector3.ZERO)
		lp.save_glb(OUT + "gamba_sotto.glb", "gamba_sotto")
		_leg_upper(Vector3.ZERO)
		_leg_lower(Vector3(0, -GINOCCHIO, 0))
		lp.save_glb(OUT + "gamba.glb", "gamba")
	quit()


func _box(pos: Vector3, size: Vector3, bevel: float, c: Color, rot := Vector3.ZERO) -> void:
	lp.cbox(Transform3D(Basis.from_euler(rot), pos), size, bevel, c)


# --- modelli (ogni pezzo ha l'origine nel suo perno) ------------------------------

## Teschio: origine alla base del collo, faccia verso +Z. Mandibola e occhi a parte.
func _head() -> void:
	lp.prism(Vector3(0, -0.06, -0.01), Vector3(0, 0.07, -0.01), 0.045, 0.04, 6, OSSO_SCURO)
	# volta cranica tonda (sfera sfaccettata) e nuca
	lp.ball(Vector3(0, 0.29, -0.015), Vector3(0.19, 0.175, 0.19), 12, 8, OSSO)
	lp.ball(Vector3(0, 0.25, -0.06), Vector3(0.165, 0.15, 0.16), 10, 6, OSSO)
	# arcate sopraccigliari, zigomi, mascella superiore
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.075, 0.253, 0.15), Vector3(0.12, 0.035, 0.05), 0.016, OSSO_CHIARO, Vector3(0, 0, sx * -0.12))
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.125, 0.17, 0.115), Vector3(0.09, 0.06, 0.12), 0.025, OSSO, Vector3(0, sx * 0.3, 0))
		_box(Vector3(sx * 0.16, 0.2, 0.03), Vector3(0.05, 0.08, 0.12), 0.02, OSSO_SCURO)
	_box(Vector3(0, 0.125, 0.105), Vector3(0.21, 0.08, 0.15), 0.03, OSSO)
	# orbite (inclinate verso l'esterno) e naso a cuore rovesciato
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.075, 0.2, 0.17), Vector3(0.1, 0.09, 0.03), 0.02, BUIO, Vector3(0, 0, sx * 0.15))
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.012, 0.145, 0.188), Vector3(0.03, 0.05, 0.02), 0.006, BUIO, Vector3(0, 0, sx * -0.35))
	# denti superiori
	for i in 6:
		_box(Vector3(-0.075 + i * 0.03, 0.08, 0.175), Vector3(0.025, 0.04, 0.025), 0.007, OSSO_CHIARO)


## Mandibola: origine al cardine (davanti alle orecchie).
func _jaw() -> void:
	_box(Vector3(0, -0.045, 0.12), Vector3(0.2, 0.05, 0.1), 0.02, OSSO)
	_box(Vector3(0, -0.055, 0.17), Vector3(0.1, 0.04, 0.03), 0.012, OSSO_CHIARO)
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.095, -0.015, 0.05), Vector3(0.035, 0.09, 0.11), 0.012, OSSO_SCURO, Vector3(0.3, 0, 0))
	for i in 6:
		_box(Vector3(-0.075 + i * 0.03, -0.008, 0.165), Vector3(0.024, 0.035, 0.024), 0.007, OSSO_CHIARO)


## Torace: origine al centro del bacino. Bacino con le ali, colonna con le vertebre,
## 5 costole per lato che scendono verso lo sterno, scapole, clavicole, prime vertebre del collo.
func _torso() -> void:
	# bacino
	_box(Vector3(0, 0.03, -0.045), Vector3(0.11, 0.15, 0.09), 0.03, OSSO_SCURO)
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.115, 0.07, -0.01), Vector3(0.17, 0.15, 0.05), 0.03, OSSO, Vector3(0, sx * -0.55, sx * 0.3))
		_box(Vector3(sx * 0.09, -0.03, 0.035), Vector3(0.09, 0.05, 0.06), 0.018, OSSO_SCURO)
		_box(Vector3(sx * 0.1, -0.01, 0.0), Vector3(0.08, 0.08, 0.08), 0.03, OSSO)
	_box(Vector3(0, -0.04, 0.07), Vector3(0.12, 0.05, 0.05), 0.018, OSSO)
	# colonna: corpi vertebrali e processi spinosi
	var y := 0.12
	var i := 0
	while y < 0.72:
		_box(Vector3(0, y, -0.07), Vector3(0.075, 0.036, 0.065), 0.013, OSSO if i % 2 == 0 else OSSO_SCURO)
		_box(Vector3(0, y - 0.005, -0.115), Vector3(0.025, 0.03, 0.05), 0.008, OSSO_SCURO, Vector3(0.4, 0, 0))
		y += 0.052
		i += 1
	lp.prism(Vector3(0, 0.08, -0.07), Vector3(0, 0.74, -0.07), 0.022, 0.022, 6, OSSO_SCURO)
	# costole: da dietro (colonna) a davanti (sterno), più basse davanti
	for r in 5:
		var ry := 0.3 + r * 0.065
		var rx: float = [0.15, 0.17, 0.175, 0.17, 0.15][r]
		var rz := 0.12
		var segs := 7
		for sx in [-1.0, 1.0]:
			for k in segs:
				var a0 := -PI / 2.0 + PI * k / segs
				var a1 := -PI / 2.0 + PI * (k + 1) / segs
				var p0 := Vector3(sx * cos(a0) * rx, ry + (sin(a0) + 1.0) * -0.025, sin(a0) * rz)
				var p1 := Vector3(sx * cos(a1) * rx, ry + (sin(a1) + 1.0) * -0.025, sin(a1) * rz)
				if k == segs - 1:
					p1.x = sx * 0.03
				var dir := (p1 - p0).normalized()
				var b := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).orthonormalized()
				lp.cbox(Transform3D(b, (p0 + p1) / 2.0 + Vector3(0, 0, -0.005)), Vector3(p0.distance_to(p1) + 0.02, 0.042, 0.035), 0.012, OSSO)
	# sterno
	_box(Vector3(0, 0.42, 0.12), Vector3(0.06, 0.24, 0.035), 0.012, OSSO_CHIARO, Vector3(-0.15, 0, 0))
	_box(Vector3(0, 0.56, 0.11), Vector3(0.09, 0.06, 0.035), 0.012, OSSO_CHIARO)
	# scapole e clavicole
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.12, 0.52, -0.125), Vector3(0.12, 0.16, 0.03), 0.015, OSSO_SCURO, Vector3(0, 0, sx * 0.2))
		var a := Vector3(sx * 0.03, 0.58, 0.11)
		var b2 := Vector3(sx * 0.21, 0.6, -0.01)
		var dir := (b2 - a).normalized()
		var bb := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).orthonormalized()
		lp.cbox(Transform3D(bb, (a + b2) / 2.0), Vector3(a.distance_to(b2) + 0.02, 0.04, 0.04), 0.014, OSSO)
		_box(Vector3(sx * 0.21, 0.6, -0.02), Vector3(0.08, 0.07, 0.1), 0.025, OSSO_SCURO)


## Braccio sopra (omero): origine alla spalla, scende lungo -Y fino al gomito.
func _arm_upper(o: Vector3) -> void:
	_box(o + Vector3(0, -0.005, 0), Vector3(0.09, 0.09, 0.09), 0.035, OSSO)
	lp.prism(o + Vector3(0, -0.04, 0), o + Vector3(0, -0.27, 0), 0.038, 0.031, 6, OSSO)
	_box(o + Vector3(0, -0.29, 0), Vector3(0.085, 0.05, 0.06), 0.018, OSSO_SCURO)


## Braccio sotto: origine al gomito. Radio e ulna, polso, mano con 4 dita e pollice.
func _arm_lower(o: Vector3) -> void:
	_box(o + Vector3(0, -0.01, -0.01), Vector3(0.065, 0.06, 0.065), 0.02, OSSO)
	for sx in [-1.0, 1.0]:
		lp.prism(o + Vector3(sx * 0.02, -0.03, 0), o + Vector3(sx * 0.016, -0.26, 0.008), 0.021, 0.018, 6, OSSO)
	_box(o + Vector3(0, -0.28, 0.008), Vector3(0.075, 0.035, 0.05), 0.012, OSSO_SCURO)
	_box(o + Vector3(0, -0.33, 0.01), Vector3(0.09, 0.075, 0.035), 0.013, OSSO)
	for f in 4:
		var x := -0.033 + f * 0.022
		var l: float = [0.045, 0.055, 0.052, 0.04][f]
		lp.prism(o + Vector3(x, -0.365, 0.01), o + Vector3(x, -0.365 - l, 0.022), 0.011, 0.01, 5, OSSO)
		lp.prism(o + Vector3(x, -0.365 - l, 0.022), o + Vector3(x, -0.39 - l, 0.045), 0.01, 0.008, 5, OSSO_CHIARO)
	lp.prism(o + Vector3(0.047, -0.31, 0.02), o + Vector3(0.07, -0.36, 0.045), 0.012, 0.01, 5, OSSO)
	lp.prism(o + Vector3(0.07, -0.36, 0.045), o + Vector3(0.075, -0.39, 0.065), 0.01, 0.008, 5, OSSO_CHIARO)


## Gamba sopra (femore): origine all'anca, scende lungo -Y fino al ginocchio.
func _leg_upper(o: Vector3) -> void:
	_box(o + Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.1), 0.04, OSSO)
	_box(o + Vector3(-0.04, -0.04, -0.01), Vector3(0.05, 0.07, 0.06), 0.02, OSSO_SCURO)
	lp.prism(o + Vector3(0, -0.05, 0), o + Vector3(0, -0.4, 0.01), 0.047, 0.04, 6, OSSO)
	_box(o + Vector3(0, -0.42, 0.005), Vector3(0.11, 0.06, 0.09), 0.022, OSSO_SCURO)


## Gamba sotto: origine al ginocchio. Rotula, tibia e perone, caviglia, piede verso +Z.
func _leg_lower(o: Vector3) -> void:
	_box(o + Vector3(0, -0.005, 0.05), Vector3(0.055, 0.06, 0.03), 0.012, OSSO_CHIARO)
	_box(o + Vector3(0, -0.03, 0), Vector3(0.1, 0.05, 0.085), 0.02, OSSO)
	lp.prism(o + Vector3(0, -0.04, 0.005), o + Vector3(0, -0.38, 0), 0.04, 0.03, 6, OSSO)
	lp.prism(o + Vector3(0.038, -0.05, -0.01), o + Vector3(0.032, -0.37, -0.005), 0.015, 0.013, 5, OSSO_SCURO)
	_box(o + Vector3(0, -0.4, 0), Vector3(0.085, 0.05, 0.08), 0.018, OSSO_SCURO)
	_box(o + Vector3(0, -0.435, -0.03), Vector3(0.08, 0.05, 0.08), 0.02, OSSO)
	_box(o + Vector3(0, -0.44, 0.06), Vector3(0.11, 0.04, 0.16), 0.015, OSSO)
	for t in 4:
		_box(o + Vector3(-0.036 + t * 0.024, -0.445, 0.165), Vector3(0.02, 0.03, 0.06), 0.008, OSSO_CHIARO)


# --- scena e animazioni ------------------------------------------------------------

func _build_scene() -> void:
	var root := Node3D.new()
	root.name = "Scheletro"
	root.set_script(SkeletonScript)
	var body := Node3D.new()
	body.name = "Corpo"
	root.add_child(body)
	for part in PERNI:
		var pivot := Node3D.new()
		pivot.name = part
		pivot.position = PERNI[part]
		pivot.rotation = RIPOSO.get(part, Vector3.ZERO)
		body.add_child(pivot)
		var left: bool = part.ends_with("Sinistro") or part.ends_with("Sinistra")
		match part:
			"Torace":
				pivot.add_child(_model("torace", false))
			"Testa":
				pivot.add_child(_model("testa", false))
				var jaw_pivot := Node3D.new()
				jaw_pivot.name = "Mascella"
				jaw_pivot.position = Vector3(0, 0.1, 0.0)
				pivot.add_child(jaw_pivot)
				jaw_pivot.add_child(_model("mascella", false))
				pivot.add_child(_eyes())
			"BraccioDestro", "BraccioSinistro":
				pivot.add_child(_model("braccio_sopra", left))
				var elbow := Node3D.new()
				elbow.name = "Avambraccio"
				elbow.position = Vector3(0, -GOMITO, 0)
				elbow.rotation = GOMITO_RIPOSO
				pivot.add_child(elbow)
				elbow.add_child(_model("braccio_sotto", left))
			"GambaDestra", "GambaSinistra":
				pivot.add_child(_model("gamba_sopra", left))
				var knee := Node3D.new()
				knee.name = "Stinco"
				knee.position = Vector3(0, -GINOCCHIO, 0)
				pivot.add_child(knee)
				knee.add_child(_model("gamba_sotto", left))

	# secchio tenuto davanti alla pancia, appoggiato sulle mani (si vede solo quando lo
	# scheletro lavoratore lo porta). Il barile è largo 0,36 m: passa tra le braccia.
	var bucket := Node3D.new()
	bucket.name = "SecchioInMano"
	bucket.position = Vector3(0, 0.97, 0.36)
	bucket.visible = false
	body.add_child(bucket)
	var barrel: Node3D = (load("res://assetpack/kenney_mini-dungeon/Models/GLB format/barrel.glb") as PackedScene).instantiate()
	barrel.name = "Modello"
	barrel.scale = Vector3.ONE * 0.7
	bucket.add_child(barrel)

	var player := AnimationPlayer.new()
	player.name = "Animazioni"
	var lib := AnimationLibrary.new()
	lib.add_animation("RESET", _reset())
	lib.add_animation("idle", _idle())
	lib.add_animation("cammina", _walk())
	lib.add_animation("porta", _carry())
	lib.add_animation("porta_fermo", _carry_idle())
	lib.add_animation("scava", _dig())
	player.add_animation_library("", lib)
	player.autoplay = "idle"
	root.add_child(player)

	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, "res://scenes/scheletro.tscn")
	print("res://scenes/scheletro.tscn: %s" % ("salvata" if err == OK else "ERRORE %d" % err))
	root.free()


## Modello di un pezzo; i pezzi sinistri sono quelli destri specchiati.
func _model(file: String, mirror: bool) -> Node3D:
	var m: Node3D = (load(OUT + file + ".glb") as PackedScene).instantiate()
	m.name = "Modello"
	if mirror:
		m.scale = Vector3(-1, 1, 1)
	return m


## Occhi luminosi (spenti finché lo scheletro non si sveglia: li accende scheletro.gd).
func _eyes() -> Node3D:
	var eyes := Node3D.new()
	eyes.name = "Occhi"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 1.0, 0.8)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 0.024
	sphere.height = 0.048
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = mat
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.name = "Occhio" + ("Destro" if sx < 0 else "Sinistro")
		e.mesh = sphere
		e.position = Vector3(sx * 0.075, 0.2, 0.165)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.add_child(e)
	var light := OmniLight3D.new()
	light.name = "Luce"
	light.light_color = Color(0.4, 1.0, 0.8)
	light.light_energy = 0.6
	light.omni_range = 1.6
	light.position = Vector3(0, 0.2, 0.3)
	eyes.add_child(light)
	return eyes


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


## Posa di riposo (usata dall'editor e quando lo scheletro è incompleto).
func _reset() -> Animation:
	var a := Animation.new()
	a.length = 0.001
	_track(a, "Corpo:position", [[0.0, Vector3.ZERO]])
	for part in PERNI:
		_track(a, "Corpo/%s:rotation" % part, [[0.0, RIPOSO.get(part, Vector3.ZERO)]])
	for side in ["Destro", "Sinistro"]:
		_track(a, "Corpo/Braccio%s/Avambraccio:rotation" % side, [[0.0, GOMITO_RIPOSO]])
	for side in ["Destra", "Sinistra"]:
		_track(a, "Corpo/Gamba%s/Stinco:rotation" % side, [[0.0, Vector3.ZERO]])
	_track(a, "Corpo/Testa/Mascella:rotation", [[0.0, Vector3.ZERO]])
	return a


## Idle: respiro, la testa si guarda intorno, le braccia ondeggiano.
func _idle() -> Animation:
	var a := Animation.new()
	a.length = 3.2
	a.loop_mode = Animation.LOOP_LINEAR
	_track(a, "Corpo:position", [[0.0, Vector3.ZERO], [1.6, Vector3(0, -0.02, 0)], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/Torace:rotation", [[0.0, Vector3.ZERO], [1.6, Vector3(0.05, 0, 0)], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/Testa:rotation", [[0.0, Vector3.ZERO], [0.8, Vector3(0.08, 0.4, 0.08)],
		[1.4, Vector3(0.08, 0.4, 0.08)], [2.0, Vector3(-0.03, -0.35, -0.06)], [2.6, Vector3(-0.03, -0.35, -0.06)], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/BraccioDestro:rotation", [[0.0, Vector3(0, 0, -0.1)], [1.6, Vector3(0.07, 0, -0.15)], [3.2, Vector3(0, 0, -0.1)]])
	_track(a, "Corpo/BraccioSinistro:rotation", [[0.0, Vector3(0, 0, 0.1)], [1.6, Vector3(-0.05, 0, 0.15)], [3.2, Vector3(0, 0, 0.1)]])
	_track(a, "Corpo/BraccioDestro/Avambraccio:rotation", [[0.0, GOMITO_RIPOSO], [1.6, Vector3(-0.3, 0, 0)], [3.2, GOMITO_RIPOSO]])
	_track(a, "Corpo/BraccioSinistro/Avambraccio:rotation", [[0.0, Vector3(-0.25, 0, 0)], [1.6, GOMITO_RIPOSO], [3.2, Vector3(-0.25, 0, 0)]])
	for side in ["Destra", "Sinistra"]:
		_track(a, "Corpo/Gamba%s:rotation" % side, [[0.0, Vector3.ZERO], [1.6, Vector3(-0.03, 0, 0)], [3.2, Vector3.ZERO]])
		_track(a, "Corpo/Gamba%s/Stinco:rotation" % side, [[0.0, Vector3.ZERO], [1.6, Vector3(0.06, 0, 0)], [3.2, Vector3.ZERO]])
	return a


## Camminata: un passo per gamba in 1 secondo, ginocchio che si piega quando la gamba
## torna avanti, braccia in opposizione con il gomito piegato, il corpo si abbassa
## quando le gambe sono aperte, torace che ruota, testa che ciondola.
## Una gamba in avanti = rotazione x negativa (il piede va verso +Z).
func _walk() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var leg := 0.42
	var arm := 0.42
	_track(a, "Corpo:position", [[0.0, Vector3(0, -0.06, 0)], [0.25, Vector3(0, 0.01, 0)],
		[0.5, Vector3(0, -0.06, 0)], [0.75, Vector3(0, 0.01, 0)], [1.0, Vector3(0, -0.06, 0)]])
	_track(a, "Corpo/GambaDestra:rotation", [[0.0, Vector3(-leg, 0, 0)], [0.5, Vector3(leg, 0, 0)], [1.0, Vector3(-leg, 0, 0)]])
	_track(a, "Corpo/GambaSinistra:rotation", [[0.0, Vector3(leg, 0, 0)], [0.5, Vector3(-leg, 0, 0)], [1.0, Vector3(leg, 0, 0)]])
	# ginocchio: dritto quando appoggia davanti, molto piegato quando la gamba torna avanti
	var knee := [[0.0, 0.05], [0.25, 0.15], [0.5, 0.25], [0.68, 0.95], [0.85, 0.45], [1.0, 0.05]]
	var kr := []
	var kl := []
	for k in knee:
		kr.append([k[0], Vector3(k[1], 0, 0)])
		kl.append([fmod(k[0] + 0.5, 1.0), Vector3(k[1], 0, 0)])
	kl.sort_custom(func(x, y): return x[0] < y[0])
	kl.append([1.0, kl[0][1]])
	_track(a, "Corpo/GambaDestra/Stinco:rotation", kr)
	_track(a, "Corpo/GambaSinistra/Stinco:rotation", kl)
	_track(a, "Corpo/BraccioDestro:rotation", [[0.0, Vector3(arm, 0, -0.12)], [0.5, Vector3(-arm, 0, -0.12)], [1.0, Vector3(arm, 0, -0.12)]])
	_track(a, "Corpo/BraccioSinistro:rotation", [[0.0, Vector3(-arm, 0, 0.12)], [0.5, Vector3(arm, 0, 0.12)], [1.0, Vector3(-arm, 0, 0.12)]])
	_track(a, "Corpo/BraccioDestro/Avambraccio:rotation", [[0.0, Vector3(-0.2, 0, 0)], [0.5, Vector3(-0.6, 0, 0)], [1.0, Vector3(-0.2, 0, 0)]])
	_track(a, "Corpo/BraccioSinistro/Avambraccio:rotation", [[0.0, Vector3(-0.6, 0, 0)], [0.5, Vector3(-0.2, 0, 0)], [1.0, Vector3(-0.6, 0, 0)]])
	_track(a, "Corpo/Torace:rotation", [[0.0, Vector3(0.06, 0.13, 0)], [0.5, Vector3(0.06, -0.13, 0)], [1.0, Vector3(0.06, 0.13, 0)]])
	_track(a, "Corpo/Testa:rotation", [[0.0, Vector3(0.0, -0.1, 0.07)], [0.25, Vector3(0.08, 0, 0)],
		[0.5, Vector3(0.0, 0.1, -0.07)], [0.75, Vector3(0.08, 0, 0)], [1.0, Vector3(0.0, -0.1, 0.07)]])
	return a


## Braccia che reggono il secchio: scendono lungo i fianchi del barile e le mani lo
## tengono da sotto, davanti alla pancia. Il torace si piega un po' indietro per il peso.
func _carry_arms(a: Animation, oscilla: float) -> void:
	var b := Vector3(-0.5, 0, 0)
	_track(a, "Corpo/BraccioDestro:rotation", [[0.0, b + Vector3(-oscilla, 0, 0.02)], [0.5, b + Vector3(oscilla, 0, 0.02)], [1.0, b + Vector3(-oscilla, 0, 0.02)]])
	_track(a, "Corpo/BraccioSinistro:rotation", [[0.0, b + Vector3(oscilla, 0, -0.02)], [0.5, b + Vector3(-oscilla, 0, -0.02)], [1.0, b + Vector3(oscilla, 0, -0.02)]])
	_track(a, "Corpo/BraccioDestro/Avambraccio:rotation", [[0.0, Vector3(-0.42, 0, 0)]])
	_track(a, "Corpo/BraccioSinistro/Avambraccio:rotation", [[0.0, Vector3(-0.42, 0, 0)]])
	_track(a, "Corpo/Torace:rotation", [[0.0, Vector3(-0.07, 0.03, 0)], [0.5, Vector3(-0.07, -0.03, 0)], [1.0, Vector3(-0.07, 0.03, 0)]])


## Cammina con un secchio davanti: gambe come "cammina", braccia che reggono il barile.
func _carry() -> Animation:
	var a := _walk()
	for i in range(a.get_track_count() - 1, -1, -1):
		var path := String(a.track_get_path(i))
		if path.contains("Braccio") or path.contains("Torace"):
			a.remove_track(i)
	_carry_arms(a, 0.03)
	return a


## Fermo con il secchio in mano (aspetta il montacarichi): respiro, braccia che reggono.
func _carry_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	_track(a, "Corpo:position", [[0.0, Vector3.ZERO], [0.5, Vector3(0, -0.015, 0)], [1.0, Vector3.ZERO]])
	_track(a, "Corpo/Testa:rotation", [[0.0, Vector3(0.1, 0, 0)]])
	for side in ["Destra", "Sinistra"]:
		_track(a, "Corpo/Gamba%s:rotation" % side, [[0.0, Vector3.ZERO]])
		_track(a, "Corpo/Gamba%s/Stinco:rotation" % side, [[0.0, Vector3.ZERO]])
	_carry_arms(a, 0.0)
	return a


## Scava con le mani: alza le braccia e colpisce la terra davanti, chinandosi (0,8 s).
func _dig() -> Animation:
	var a := Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	var su := Vector3(-2.3, 0, 0)
	var giu := Vector3(-0.45, 0, 0)
	_track(a, "Corpo:position", [[0.0, Vector3.ZERO], [0.45, Vector3(0, -0.06, 0)], [0.8, Vector3.ZERO]])
	_track(a, "Corpo/Torace:rotation", [[0.0, Vector3(0.0, 0, 0)], [0.45, Vector3(0.38, 0, 0)], [0.8, Vector3(0.0, 0, 0)]])
	_track(a, "Corpo/Testa:rotation", [[0.0, Vector3(-0.1, 0, 0)], [0.45, Vector3(0.3, 0, 0)], [0.8, Vector3(-0.1, 0, 0)]])
	_track(a, "Corpo/BraccioDestro:rotation", [[0.0, su + Vector3(0, 0, -0.15)], [0.35, su + Vector3(0.2, 0, -0.15)], [0.45, giu + Vector3(0, 0, -0.1)], [0.8, su + Vector3(0, 0, -0.15)]])
	_track(a, "Corpo/BraccioSinistro:rotation", [[0.0, su + Vector3(0, 0, 0.15)], [0.35, su + Vector3(0.2, 0, 0.15)], [0.45, giu + Vector3(0, 0, 0.1)], [0.8, su + Vector3(0, 0, 0.15)]])
	for side in ["Destro", "Sinistro"]:
		_track(a, "Corpo/Braccio%s/Avambraccio:rotation" % side, [[0.0, Vector3(-0.6, 0, 0)], [0.45, Vector3(-0.1, 0, 0)], [0.8, Vector3(-0.6, 0, 0)]])
	for side in ["Destra", "Sinistra"]:
		_track(a, "Corpo/Gamba%s:rotation" % side, [[0.0, Vector3(-0.05, 0, 0)], [0.45, Vector3(-0.3, 0, 0)], [0.8, Vector3(-0.05, 0, 0)]])
		_track(a, "Corpo/Gamba%s/Stinco:rotation" % side, [[0.0, Vector3(0.1, 0, 0)], [0.45, Vector3(0.45, 0, 0)], [0.8, Vector3(0.1, 0, 0)]])
	return a


func _track(a: Animation, path: String, keys: Array) -> void:
	var i := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i, NodePath(path))
	a.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		a.track_insert_key(i, k[0], k[1])
