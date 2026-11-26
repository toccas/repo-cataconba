extends RefCounted
## Costruttore di modelli low-poly nello stile dei pack Kenney: scatole con spigoli
## smussati, prismi, archi, colori pieni e ombreggiatura piatta. Salva in GLB.
## Tiene anche una lista separata di triangoli di collisione (forme semplici).
## Usato da tools/make_models.gd (mani, piccone) e tools/make_crypt.gd (cripta).

var parts := {}       # Color -> PackedVector3Array (vertici, 3 per triangolo)
var normals := {}     # Color -> PackedVector3Array
var col_faces := PackedVector3Array()


## Scatola con spigoli smussati (bevel), trasformata da xf.
func cbox(xf: Transform3D, size: Vector3, bevel: float, c: Color) -> void:
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
			quad(xf, q[0], q[1], q[3], q[2], n, c)
	if b <= 0.0:
		return
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
				quad(xf, q[0], q[1], q[3], q[2], n.normalized(), c)
	# triangoli sugli angoli
	for sx in signs:
		for sy in signs:
			for sz in signs:
				var s := Vector3(sx, sy, sz)
				tri(xf, v.call(s, 0), v.call(s, 1), v.call(s, 2), s.normalized(), c)


## Prisma a n lati da a a b, raggio r0 in a e r1 in b, con i tappi. rot ruota la sezione.
func prism(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, c: Color, rot := 0.0) -> void:
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
		quad(xf, ring0[i], ring0[j], ring1[j], ring1[i], n.normalized(), c)
	for i in range(1, sides - 1):
		tri(xf, ring0[0], ring0[i], ring0[i + 1], -axis, c)
		if r1 > 0.003:
			tri(xf, ring1[0], ring1[i], ring1[i + 1], axis, c)


## Arco a tutto sesto fatto di conci (blocchi smussati).
## center: centro dell'arco all'imposta; span: direzione in cui l'arco si apre
## (da un piedritto all'altro); depth: spessore dell'arco lungo la direzione perpendicolare.
## Se fill_to è un'altezza (y locale), riempie i pennacchi sopra l'arco fino a lì.
func arch(center: Vector3, span: Vector3, depth_dir: Vector3, ri: float, ro: float, depth: float,
		segs: int, c: Color, bevel := 0.03, fill_to := INF, fill_c := Color.BLACK) -> void:
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var am := (a0 + a1) / 2.0
		var radial := (span * cos(am) + Vector3.UP * sin(am)).normalized()
		var tangent := depth_dir.cross(radial).normalized()
		var chord := 2.0 * ro * sin((a1 - a0) / 2.0) * 1.03
		var b := Basis(depth_dir, radial, tangent)
		cbox(Transform3D(b, center + radial * (ri + ro) / 2.0), Vector3(depth, ro - ri, chord), bevel, c)
		if fill_to < INF:
			# pennacchio: colonna verticale dal dorso dell'arco fino a fill_to
			var x0 := ro * cos(a0)
			var x1 := ro * cos(a1)
			var ytop := center.y + ro * minf(sin(a0), sin(a1))
			if fill_to - ytop > 0.02:
				var xm := (x0 + x1) / 2.0
				var w := absf(x1 - x0) + 0.02
				var p := center + span * xm
				p.y = (ytop + fill_to) / 2.0
				cbox(Transform3D(Basis(span, Vector3.UP, span.cross(Vector3.UP)), p),
					Vector3(w, fill_to - ytop, depth * 0.9), 0.0, fill_c)


## Ellissoide sfaccettato (stile low-poly): centro c, semiassi r, segs spicchi, rings fasce.
## lat_min: latitudine da cui parte (-PI/2 = sfera intera, 0 = solo la metà di sopra).
func ball(c: Vector3, r: Vector3, segs: int, rings: int, col: Color, lat_min := -PI / 2.0) -> void:
	var pt := func(lat: float, lon: float) -> Vector3:
		return c + Vector3(cos(lat) * cos(lon) * r.x, sin(lat) * r.y, cos(lat) * sin(lon) * r.z)
	var xf := Transform3D()
	for i in rings:
		var la0 := lat_min + (PI / 2.0 - lat_min) * i / rings
		var la1 := lat_min + (PI / 2.0 - lat_min) * (i + 1) / rings
		for j in segs:
			var lo0 := TAU * j / segs
			var lo1 := TAU * (j + 1) / segs
			var p00: Vector3 = pt.call(la0, lo0)
			var p01: Vector3 = pt.call(la0, lo1)
			var p11: Vector3 = pt.call(la1, lo1)
			var p10: Vector3 = pt.call(la1, lo0)
			var n := ((p00 + p01 + p11 + p10) / 4.0 - c).normalized()
			quad(xf, p00, p01, p11, p10, n, col)


func quad(xf: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, c: Color) -> void:
	tri(xf, p0, p1, p2, n, c)
	tri(xf, p0, p2, p3, n, c)


## Triangolo con normale piatta n (verso l'esterno). Godot considera fronte i triangoli
## in senso orario visti da fuori: l'ordine viene sistemato qui.
func tri(xf: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3, c: Color) -> void:
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


## Scatola di collisione (non disegnata): 12 triangoli nella lista col_faces.
func col_box(xf: Transform3D, size: Vector3) -> void:
	var h := size / 2.0
	var corners := []
	for i in 8:
		corners.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		col_faces.append_array([corners[f[0]], corners[f[1]], corners[f[2]], corners[f[0]], corners[f[2]], corners[f[3]]])


func triangle_count() -> int:
	var tris := 0
	for c in parts:
		tris += parts[c].size() / 3
	return tris


## Salva il modello in GLB (un materiale per colore) e svuota il costruttore.
## shiny: colori da rendere metallici (es. ferro).
func save_glb(path: String, model_name: String, shiny := []) -> Error:
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
		if c in shiny:
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
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	print("%s: %s (%d triangoli)" % [path.get_file(), "salvato" if err == OK else "ERRORE %d" % err, triangle_count()])
	root.free()
	parts.clear()
	normals.clear()
	return err


## Salva i triangoli di collisione come ConcavePolygonShape3D e svuota la lista.
func save_collision(path: String) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(col_faces)
	shape.backface_collision = true
	ResourceSaver.save(shape, path)
	col_faces = PackedVector3Array()
