extends SceneTree
## Crea i modelli low-poly delle mani e del piccone, nello stile dei pack Kenney
## (forme squadrate con spigoli smussati, colori pieni, ombreggiatura piatta),
## e li salva come GLB in res://modelli/.
## Uso: godot --headless --path . --script res://tools/make_models.gd

const OUT := "res://modelli/"

const PELLE := Color(0.93, 0.71, 0.55)
const PELLE_SCURA := Color(0.80, 0.56, 0.42)
const MANICA := Color(0.26, 0.23, 0.38)
const POLSINO := Color(0.42, 0.37, 0.56)
const LEGNO := Color(0.62, 0.40, 0.23)
const LEGNO_SCURO := Color(0.45, 0.27, 0.15)
const CUOIO := Color(0.30, 0.17, 0.11)
const FERRO := Color(0.36, 0.38, 0.45)
const ACCIAIO := Color(0.64, 0.68, 0.75)
const ACCIAIO_CHIARO := Color(0.82, 0.85, 0.90)

var parts := {}   # Color -> PackedVector3Array (vertici, 3 per triangolo)
var normals := {} # Color -> PackedVector3Array


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_hand(false)
	_save("mano")
	_hand(true)
	_save("pugno")
	_pickaxe()
	_save("piccone")
	quit()


# --- modelli -------------------------------------------------------------------

## Mano destra con manica. La mano punta verso -Z, il palmo guarda in basso (-Y),
## la manica va indietro verso +Z. fist = true: dita chiuse attorno a un manico
## che passa per l'origine lungo l'asse X.
func _hand(fist: bool) -> void:
	var palm_z := 0.05 if fist else 0.0
	# manica e polsino
	_prism(Vector3(0, -0.005, palm_z + 0.07), Vector3(0, -0.03, palm_z + (0.24 if fist else 0.3)), 0.052, 0.062, 8, MANICA, PI / 8)
	_prism(Vector3(0, -0.004, palm_z + 0.045), Vector3(0, -0.008, palm_z + 0.095), 0.064, 0.066, 8, POLSINO, PI / 8)
	# palmo
	_cbox(Transform3D(Basis(), Vector3(0, 0, palm_z)), Vector3(0.105, 0.048, 0.10), 0.014, PELLE)
	if fist:
		# dita chiuse: un rotolo di nocche davanti e sotto al manico
		_cbox(Transform3D(Basis(), Vector3(0, 0.002, 0.0)), Vector3(0.108, 0.05, 0.05), 0.016, PELLE)
		_cbox(Transform3D(Basis(), Vector3(0, -0.032, 0.012)), Vector3(0.10, 0.03, 0.05), 0.012, PELLE_SCURA)
		for i in 3:
			# solchi tra le dita
			_cbox(Transform3D(Basis(), Vector3(-0.027 + i * 0.027, 0.0, -0.026)), Vector3(0.004, 0.044, 0.004), 0.001, PELLE_SCURA)
		# pollice sopra il manico
		var tb := Basis(Vector3.UP, 0.35)
		_cbox(Transform3D(tb, Vector3(-0.035, 0.03, 0.012)), Vector3(0.03, 0.026, 0.06), 0.009, PELLE)
	else:
		# quattro dita leggermente piegate, a "rastrello"
		for i in 4:
			var x := -0.039 + i * 0.026
			var length := 0.046 if i in [1, 2] else 0.04
			var base := Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(x, -0.002, palm_z - 0.045))
			_cbox(base * Transform3D(Basis(), Vector3(0, 0, -length / 2.0)), Vector3(0.023, 0.026, length), 0.008, PELLE)
			var tip := base * Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, -0.002, -length + 0.004))
			_cbox(tip * Transform3D(Basis(), Vector3(0, 0, -0.017)), Vector3(0.021, 0.023, 0.036), 0.008, PELLE)
		# pollice, sul lato sinistro della mano destra
		var thumb := Transform3D(Basis(Vector3.UP, 0.75) * Basis(Vector3.RIGHT, -0.2), Vector3(-0.05, -0.006, palm_z - 0.005))
		_cbox(thumb * Transform3D(Basis(), Vector3(0, 0, -0.026)), Vector3(0.026, 0.026, 0.052), 0.009, PELLE)


## Piccone: manico lungo +Y con l'impugnatura vicino all'origine, testa in cima
## lungo l'asse Z (punta principale verso -Z, in avanti).
func _pickaxe() -> void:
	# manico
	_prism(Vector3(0, -0.16, 0), Vector3(0, 0.56, 0), 0.029, 0.025, 8, LEGNO, PI / 8)
	_cbox(Transform3D(Basis(), Vector3(0, -0.18, 0)), Vector3(0.07, 0.045, 0.07), 0.016, LEGNO_SCURO)
	# fasciatura di cuoio sull'impugnatura
	for i in 3:
		var y := -0.14 + i * 0.05
		_prism(Vector3(0, y, 0), Vector3(0, y + 0.036, 0), 0.034, 0.034, 8, CUOIO, PI / 8)
	# collare di ferro
	_cbox(Transform3D(Basis(), Vector3(0, 0.53, 0)), Vector3(0.08, 0.105, 0.1), 0.018, FERRO)
	_cbox(Transform3D(Basis(), Vector3(0, 0.592, 0)), Vector3(0.062, 0.024, 0.062), 0.008, FERRO)
	# punta principale (in avanti, curva verso il basso)
	_prism(Vector3(0, 0.535, -0.045), Vector3(0, 0.53, -0.16), 0.04, 0.032, 4, ACCIAIO, PI / 4)
	_prism(Vector3(0, 0.53, -0.16), Vector3(0, 0.49, -0.265), 0.032, 0.019, 4, ACCIAIO, PI / 4)
	_prism(Vector3(0, 0.49, -0.265), Vector3(0, 0.415, -0.335), 0.019, 0.002, 4, ACCIAIO_CHIARO, PI / 4)
	# lama piatta dietro (scalpello)
	_prism(Vector3(0, 0.535, 0.045), Vector3(0, 0.525, 0.14), 0.04, 0.03, 4, ACCIAIO, PI / 4)
	_cbox(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.505, 0.185)), Vector3(0.066, 0.026, 0.08), 0.008, ACCIAIO_CHIARO)


# --- primitive -------------------------------------------------------------------

## Scatola con spigoli smussati (bevel), trasformata da xf.
func _cbox(xf: Transform3D, size: Vector3, bevel: float, c: Color) -> void:
	var h := size / 2.0
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	# per ogni angolo (sx, sy, sz) tre vertici, uno su ogni faccia che lo tocca
	var v := func(s: Vector3, axis: int) -> Vector3:
		var p := Vector3(s.x * (h.x - b), s.y * (h.y - b), s.z * (h.z - b))
		p[axis] = s[axis] * h[axis]
		return p
	var signs := [-1.0, 1.0]
	# facce principali
	for axis in 3:
		for sa in signs:
			var q := []
			for u in signs:
				for w in signs:
					var s := Vector3.ZERO
					s[axis] = sa
					s[(axis + 1) % 3] = u
					s[(axis + 2) % 3] = w
					q.append(v.call(s, axis))
			var n := Vector3.ZERO
			n[axis] = sa
			_quad(xf, q[0], q[1], q[3], q[2], n, c)
	# smussi sugli spigoli
	for axis in 3:
		var a1 := (axis + 1) % 3
		var a2 := (axis + 2) % 3
		for s1 in signs:
			for s2 in signs:
				var q := []
				for sa in signs:
					var s := Vector3.ZERO
					s[axis] = sa
					s[a1] = s1
					s[a2] = s2
					q.append(v.call(s, a1))
					q.append(v.call(s, a2))
				var n := Vector3.ZERO
				n[a1] = s1
				n[a2] = s2
				_quad(xf, q[0], q[1], q[3], q[2], n.normalized(), c)
	# triangoli sugli angoli
	for sx in signs:
		for sy in signs:
			for sz in signs:
				var s := Vector3(sx, sy, sz)
				_tri(xf, v.call(s, 0), v.call(s, 1), v.call(s, 2), s.normalized(), c)


## Prisma a n lati da a a b, raggio r0 in a e r1 in b, con i tappi. rot ruota la sezione.
func _prism(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, c: Color, rot := 0.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i in sides:
		var ang := rot + TAU * i / sides
		var d := side * cos(ang) + up * sin(ang)
		ring0.append(a + d * r0)
		ring1.append(b + d * r1)
	var xf := Transform3D()
	for i in sides:
		var j := (i + 1) % sides
		var mid: Vector3 = (ring0[i] + ring0[j] + ring1[i] + ring1[j]) / 4.0
		var n: Vector3 = (mid - (a + b) / 2.0)
		n -= axis * n.dot(axis)
		_quad(xf, ring0[i], ring0[j], ring1[j], ring1[i], n.normalized(), c)
	for i in range(1, sides - 1):
		_tri(xf, ring0[0], ring0[i], ring0[i + 1], -axis, c)
		if r1 > 0.003:
			_tri(xf, ring1[0], ring1[i], ring1[i + 1], axis, c)


func _quad(xf: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, c: Color) -> void:
	_tri(xf, p0, p1, p2, n, c)
	_tri(xf, p0, p2, p3, n, c)


## Triangolo con normale piatta n (verso l'esterno). Godot considera fronte i triangoli
## in senso orario visti da fuori: l'ordine viene sistemato qui.
func _tri(xf: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3, c: Color) -> void:
	if (p1 - p0).cross(p2 - p0).length_squared() < 1e-14:
		return
	if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
		var t := p1
		p1 = p2
		p2 = t
	if not parts.has(c):
		parts[c] = PackedVector3Array()
		normals[c] = PackedVector3Array()
	var wn := (xf.basis * n).normalized()
	for p in [p0, p1, p2]:
		parts[c].append(xf * p)
		normals[c].append(wn)


# --- salvataggio -----------------------------------------------------------------

func _save(model_name: String) -> void:
	var mesh := ArrayMesh.new()
	for c in parts:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = parts[c]
		arr[Mesh.ARRAY_NORMAL] = normals[c]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		if c in [ACCIAIO, ACCIAIO_CHIARO, FERRO]:
			m.metallic = 0.4
			m.roughness = 0.45
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var root := Node3D.new()
	root.name = model_name
	var mi := MeshInstance3D.new()
	mi.name = model_name
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT + model_name + ".glb"))
	var tris := 0
	for c in parts:
		tris += parts[c].size() / 3
	print("%s.glb: %s (%d triangoli)" % [model_name, "salvato" if err == OK else "ERRORE %d" % err, tris])
	root.free()
	parts.clear()
	normals.clear()
