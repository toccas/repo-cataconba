extends SceneTree
## Scheletro scomponibile in 6 pezzi (testa, torace, braccio destro e sinistro,
## gamba destra e sinistra), in stile low-poly Kenney.
##
## Va eseguito due volte (la seconda dopo che Godot ha importato i modelli):
##   godot --headless --path . --script res://tools/make_skeleton.gd
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/make_skeleton.gd -- --scena
## La prima volta crea i modelli in res://modelli/scheletro/, la seconda la scena
## res://scenes/scheletro.tscn con i perni dei pezzi e le animazioni "idle" e "cammina".
## Lo scheletro guarda verso +Z, è alto circa 1,8 m, i piedi sono a y = 0.

const LowPoly := preload("res://tools/low_poly.gd")
const SkeletonScript := preload("res://scripts/scheletro.gd")
const OUT := "res://modelli/scheletro/"

const OSSO := Color(0.91, 0.87, 0.76)
const OSSO_SCURO := Color(0.76, 0.71, 0.60)
const BUIO := Color(0.12, 0.09, 0.08)

## Perni dei pezzi (nel nodo Corpo): spalle, anche, collo, bacino.
const ANCA := 0.9
const SPALLA := 1.5
const COLLO := 1.56
const PERNI := {
	"Torace": Vector3(0, ANCA, 0),
	"Testa": Vector3(0, COLLO, 0),
	"BraccioDestro": Vector3(-0.25, SPALLA, 0),
	"BraccioSinistro": Vector3(0.25, SPALLA, 0),
	"GambaDestra": Vector3(-0.1, ANCA, 0),
	"GambaSinistra": Vector3(0.1, ANCA, 0),
}
## Braccia leggermente aperte a riposo.
const RIPOSO := {
	"BraccioDestro": Vector3(0, 0, -0.1),
	"BraccioSinistro": Vector3(0, 0, 0.1),
}

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
		_arm()
		lp.save_glb(OUT + "braccio.glb", "braccio")
		_leg()
		lp.save_glb(OUT + "gamba.glb", "gamba")
	quit()


# --- modelli (ogni pezzo ha l'origine nel suo perno) ------------------------------

## Teschio: origine alla base del collo, faccia verso +Z. La mandibola è a parte.
func _head() -> void:
	lp.prism(Vector3(0, -0.05, 0), Vector3(0, 0.05, 0), 0.045, 0.04, 6, OSSO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.25, -0.005)), Vector3(0.34, 0.3, 0.32), 0.11, OSSO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.23, -0.06)), Vector3(0.3, 0.26, 0.24), 0.1, OSSO)
	# zigomi e mascella superiore
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.12, 0.06)), Vector3(0.24, 0.07, 0.22), 0.03, OSSO)
	# orbite, naso
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(Vector3.BACK, sx * 0.12), Vector3(sx * 0.068, 0.205, 0.148)), Vector3(0.085, 0.075, 0.02), 0.015, BUIO)
	lp.cbox(Transform3D(Basis(Vector3.BACK, PI / 4.0), Vector3(0, 0.145, 0.165)), Vector3(0.035, 0.035, 0.02), 0.006, BUIO)
	# denti superiori
	for i in 6:
		lp.cbox(Transform3D(Basis(), Vector3(-0.075 + i * 0.03, 0.08, 0.165)), Vector3(0.024, 0.035, 0.02), 0.006, OSSO)


## Mandibola: origine al cardine (dietro, all'altezza delle orecchie).
func _jaw() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.02, 0.1)), Vector3(0.22, 0.05, 0.11), 0.02, OSSO_SCURO)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * 0.1, 0.0, 0.03)), Vector3(0.03, 0.07, 0.1), 0.012, OSSO_SCURO)
	for i in 6:
		lp.cbox(Transform3D(Basis(), Vector3(-0.075 + i * 0.03, 0.015, 0.145)), Vector3(0.024, 0.03, 0.02), 0.006, OSSO)


## Torace: origine al centro del bacino. Bacino, colonna, costole, clavicole.
func _torso() -> void:
	# bacino
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.32, 0.12, 0.15), 0.04, OSSO_SCURO)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(Vector3.BACK, sx * 0.35), Vector3(sx * 0.12, 0.07, -0.01)), Vector3(0.12, 0.1, 0.13), 0.035, OSSO)
	# colonna
	for i in 6:
		var y := 0.1 + i * 0.065
		lp.cbox(Transform3D(Basis(), Vector3(0, y, -0.07)), Vector3(0.07, 0.045, 0.07), 0.015, OSSO if i % 2 == 0 else OSSO_SCURO)
	lp.prism(Vector3(0, 0.07, -0.07), Vector3(0, 0.66, -0.07), 0.026, 0.026, 6, OSSO_SCURO)
	# costole: anelli aperti dietro (dove c'è la colonna) e davanti (sterno)
	for r in 4:
		var y := 0.34 + r * 0.075
		var rx := 0.17 - r * 0.004 - (0.02 if r == 0 else 0.0)
		var rz := 0.12
		var segs := 16
		for k in segs:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			var am := (a0 + a1) / 2.0
			# salto il segmento dietro (colonna) e quello davanti (sterno)
			if absf(sin(am) + 1.0) < 0.03 or absf(sin(am) - 1.0) < 0.03:
				continue
			var p0 := Vector3(cos(a0) * rx, 0, sin(a0) * rz)
			var p1 := Vector3(cos(a1) * rx, 0, sin(a1) * rz)
			var dir := (p1 - p0).normalized()
			var b := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
			lp.cbox(Transform3D(b, (p0 + p1) / 2.0 + Vector3(0, y, -0.01)), Vector3(p0.distance_to(p1) + 0.025, 0.045, 0.04), 0.012, OSSO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.44, 0.115)), Vector3(0.05, 0.26, 0.03), 0.012, OSSO)
	# clavicole e spalle
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.6, 0.0)), Vector3(0.42, 0.05, 0.07), 0.02, OSSO)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * 0.21, 0.6, -0.02)), Vector3(0.09, 0.08, 0.11), 0.03, OSSO_SCURO)


## Braccio: origine alla spalla, scende lungo -Y. Uguale per destro e sinistro.
func _arm() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.01, 0)), Vector3(0.08, 0.08, 0.08), 0.03, OSSO)
	lp.prism(Vector3(0, -0.04, 0), Vector3(0, -0.3, 0), 0.036, 0.03, 6, OSSO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.32, 0)), Vector3(0.07, 0.06, 0.065), 0.02, OSSO_SCURO)
	for sx in [-1.0, 1.0]:
		lp.prism(Vector3(sx * 0.02, -0.34, 0), Vector3(sx * 0.016, -0.58, 0.01), 0.02, 0.017, 6, OSSO)
	# mano: palmo e tre dita
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.62, 0.01)), Vector3(0.07, 0.07, 0.04), 0.015, OSSO_SCURO)
	for i in 3:
		var x := -0.022 + i * 0.022
		lp.prism(Vector3(x, -0.65, 0.01), Vector3(x, -0.72, 0.025), 0.009, 0.007, 4, OSSO, PI / 4.0)
	lp.prism(Vector3(0.04, -0.62, 0.015), Vector3(0.055, -0.67, 0.035), 0.009, 0.007, 4, OSSO, PI / 4.0)


## Gamba: origine all'anca, scende lungo -Y fino ai piedi (y = -0,9). Piede verso +Z.
func _leg() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.01, 0)), Vector3(0.085, 0.085, 0.085), 0.03, OSSO)
	lp.prism(Vector3(0, -0.04, 0), Vector3(0, -0.42, 0), 0.044, 0.036, 6, OSSO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.445, 0.005)), Vector3(0.085, 0.07, 0.08), 0.025, OSSO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.445, 0.045)), Vector3(0.045, 0.045, 0.02), 0.01, OSSO)
	lp.prism(Vector3(0, -0.47, 0), Vector3(0, -0.83, 0), 0.036, 0.028, 6, OSSO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.85, 0)), Vector3(0.07, 0.05, 0.07), 0.018, OSSO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.88, 0.06)), Vector3(0.09, 0.04, 0.2), 0.015, OSSO)
	for i in 3:
		lp.cbox(Transform3D(Basis(), Vector3(-0.028 + i * 0.028, -0.885, 0.175)), Vector3(0.022, 0.03, 0.05), 0.008, OSSO_SCURO)


# --- scena e animazioni ------------------------------------------------------------

func _build_scene() -> void:
	var root := Node3D.new()
	root.name = "Scheletro"
	root.set_script(SkeletonScript)
	var body := Node3D.new()
	body.name = "Corpo"
	root.add_child(body)
	var files := {"Torace": "torace", "Testa": "testa", "BraccioDestro": "braccio",
		"BraccioSinistro": "braccio", "GambaDestra": "gamba", "GambaSinistra": "gamba"}
	for part in PERNI:
		var pivot := Node3D.new()
		pivot.name = part
		pivot.position = PERNI[part]
		pivot.rotation = RIPOSO.get(part, Vector3.ZERO)
		body.add_child(pivot)
		var model: Node3D = (load(OUT + files[part] + ".glb") as PackedScene).instantiate()
		model.name = "Modello"
		pivot.add_child(model)
		if part == "Testa":
			var jaw_pivot := Node3D.new()
			jaw_pivot.name = "Mascella"
			jaw_pivot.position = Vector3(0, 0.1, 0.0)
			pivot.add_child(jaw_pivot)
			var jaw: Node3D = (load(OUT + "mascella.glb") as PackedScene).instantiate()
			jaw.name = "Modello"
			jaw_pivot.add_child(jaw)

	var player := AnimationPlayer.new()
	player.name = "Animazioni"
	var lib := AnimationLibrary.new()
	lib.add_animation("RESET", _reset())
	lib.add_animation("idle", _idle())
	lib.add_animation("cammina", _walk())
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
	_track(a, "Corpo/Testa/Mascella:rotation", [[0.0, Vector3.ZERO]])
	return a


## Idle: respiro, la testa si guarda intorno, le braccia ondeggiano, la mandibola batte.
func _idle() -> Animation:
	var a := Animation.new()
	a.length = 3.2
	a.loop_mode = Animation.LOOP_LINEAR
	_track(a, "Corpo:position", [[0.0, Vector3.ZERO], [1.6, Vector3(0, -0.02, 0)], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/Torace:rotation", [[0.0, Vector3.ZERO], [1.6, Vector3(0.04, 0, 0)], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/Testa:rotation", [[0.0, Vector3.ZERO], [0.8, Vector3(0.06, 0.35, 0.06)],
		[1.4, Vector3(0.06, 0.35, 0.06)], [2.0, Vector3(-0.02, -0.3, -0.05)], [2.6, Vector3(-0.02, -0.3, -0.05)], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/Testa/Mascella:rotation", [[0.0, Vector3.ZERO], [2.1, Vector3.ZERO], [2.2, Vector3(0.3, 0, 0)],
		[2.3, Vector3(0.02, 0, 0)], [2.4, Vector3(0.3, 0, 0)], [2.5, Vector3.ZERO], [3.2, Vector3.ZERO]])
	_track(a, "Corpo/BraccioDestro:rotation", [[0.0, Vector3(0, 0, -0.1)], [1.6, Vector3(0.06, 0, -0.15)], [3.2, Vector3(0, 0, -0.1)]])
	_track(a, "Corpo/BraccioSinistro:rotation", [[0.0, Vector3(0, 0, 0.1)], [1.6, Vector3(-0.04, 0, 0.15)], [3.2, Vector3(0, 0, 0.1)]])
	_track(a, "Corpo/GambaDestra:rotation", [[0.0, Vector3.ZERO]])
	_track(a, "Corpo/GambaSinistra:rotation", [[0.0, Vector3.ZERO]])
	return a


## Camminata: un passo per gamba in 1 secondo, braccia in opposizione, il corpo
## si abbassa quando le gambe sono aperte, il torace ruota un po', la testa ciondola.
## Una gamba in avanti = rotazione x negativa (il piede va verso +Z).
func _walk() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var leg := 0.45
	var arm := 0.4
	_track(a, "Corpo:position", [[0.0, Vector3(0, -0.07, 0)], [0.25, Vector3(0, 0.0, 0)],
		[0.5, Vector3(0, -0.07, 0)], [0.75, Vector3(0, 0.0, 0)], [1.0, Vector3(0, -0.07, 0)]])
	_track(a, "Corpo/GambaDestra:rotation", [[0.0, Vector3(-leg, 0, 0)], [0.5, Vector3(leg, 0, 0)], [1.0, Vector3(-leg, 0, 0)]])
	_track(a, "Corpo/GambaSinistra:rotation", [[0.0, Vector3(leg, 0, 0)], [0.5, Vector3(-leg, 0, 0)], [1.0, Vector3(leg, 0, 0)]])
	_track(a, "Corpo/BraccioDestro:rotation", [[0.0, Vector3(arm, 0, -0.12)], [0.5, Vector3(-arm, 0, -0.12)], [1.0, Vector3(arm, 0, -0.12)]])
	_track(a, "Corpo/BraccioSinistro:rotation", [[0.0, Vector3(-arm, 0, 0.12)], [0.5, Vector3(arm, 0, 0.12)], [1.0, Vector3(-arm, 0, 0.12)]])
	_track(a, "Corpo/Torace:rotation", [[0.0, Vector3(0.05, 0.12, 0)], [0.5, Vector3(0.05, -0.12, 0)], [1.0, Vector3(0.05, 0.12, 0)]])
	_track(a, "Corpo/Testa:rotation", [[0.0, Vector3(0.0, -0.08, 0.06)], [0.25, Vector3(0.07, 0, 0)],
		[0.5, Vector3(0.0, 0.08, -0.06)], [0.75, Vector3(0.07, 0, 0)], [1.0, Vector3(0.0, -0.08, 0.06)]])
	_track(a, "Corpo/Testa/Mascella:rotation", [[0.0, Vector3(0.08, 0, 0)], [0.25, Vector3(0.0, 0, 0)],
		[0.5, Vector3(0.08, 0, 0)], [0.75, Vector3(0.0, 0, 0)], [1.0, Vector3(0.08, 0, 0)]])
	return a


func _track(a: Animation, path: String, keys: Array) -> void:
	var i := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i, NodePath(path))
	a.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		a.track_insert_key(i, k[0], k[1])
