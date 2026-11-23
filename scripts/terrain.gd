@tool
extends Node3D
## Terreno scavabile: una griglia di densità (>0 = terra, <0 = aria)
## trasformata in una superficie liscia con l'algoritmo "surface nets".
## Il mondo è diviso in chunk: quando si scava si ricalcolano solo i chunk toccati.
##
## La terra riempie i pezzi della catacomba (nodo Catacomba): ogni pezzo con il meta
## "volume_size" (e "volume_offset", centro locale) definisce un volume pieno di terra.
## Sul pezzo si può impostare il meta "terra" = false per lasciarlo vuoto (es. lo spawn)
## e "spawn" = true per indicare il centro della zona iniziale, dove c'è solo terra normale.
## Anche nell'editor la terra viene generata come anteprima: dopo aver spostato,
## aggiunto o tolto pezzi premi "Rigenera terra" nell'Inspector.

@export var stone_path: NodePath
## Raggio in metri attorno allo spawn dove non ci sono venature di terra dura e roccia.
@export var pure_radius := 14.0
@export_tool_button("Rigenera terra") var rigenera_terra = rebuild

const VOXEL := 0.5          # lato di una cella in metri
const CHUNK := 8            # celle per lato di un chunk
const NX := 128
const NY := 32
const NZ := 128
const SX := NX + 1          # campioni per asse
const SY := NY + 1
const SXY := SX * SY

const MAT_TERRA := 0
const MAT_DURA := 1
const MAT_ROCCIA := 2
const MAT_RATE := [1.0, 0.33, 0.1]
const MAT_COLOR := [Color(0.42, 0.29, 0.18), Color(0.20, 0.15, 0.14), Color(0.30, 0.31, 0.34)]

const CORNERS := [
	Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1),
]
const EDGES := [
	[0, 1], [2, 3], [4, 5], [6, 7],
	[0, 2], [1, 3], [4, 6], [5, 7],
	[0, 4], [1, 5], [2, 6], [3, 7],
]

var density := PackedFloat32Array()
var material_id := PackedByteArray()
var chunk_nodes := {}   # Vector3i -> [MeshInstance3D, CollisionShape3D]
var dirty := {}         # Vector3i -> true
var surface_material: StandardMaterial3D
var body: StaticBody3D

var last_remesh_ms := 0.0
var max_remesh_ms := 0.0
var last_remesh_chunks := 0
var removed_volume := 0.0   # metri cubi di terra rimossa
var gen_ms := 0
var used_chunks := {}  # Vector3i -> true: chunk che contengono terra all'inizio


func _init() -> void:
	surface_material = StandardMaterial3D.new()
	surface_material.vertex_color_use_as_albedo = true
	surface_material.roughness = 1.0
	# grana della terra, per distinguerla dalla pietra liscia della catacomba
	var grain := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	n.fractal_octaves = 4
	grain.noise = n
	grain.seamless = true
	grain.width = 256
	grain.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.45, 0.45))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	grain.color_ramp = ramp
	surface_material.albedo_texture = grain
	surface_material.uv1_triplanar = true
	surface_material.uv1_scale = Vector3(0.6, 0.6, 0.6)


func _ready() -> void:
	rebuild()


## Rigenera tutta la terra leggendo stanze e corridoi dalla pietra.
func rebuild() -> void:
	var t0 := Time.get_ticks_msec()
	for c in chunk_nodes:
		chunk_nodes[c][0].free()
	chunk_nodes.clear()
	dirty.clear()
	if body:
		body.free()
	body = StaticBody3D.new()
	body.name = "CorpoTerra"
	add_child(body)
	removed_volume = 0.0
	max_remesh_ms = 0.0
	var layout := read_layout()
	if layout.is_empty():
		return
	generate(layout["terra"], layout["vuoti"], layout["centro"], pure_radius)
	build_all()
	gen_ms = Time.get_ticks_msec() - t0


## Legge dal nodo Catacomba i volumi di terra dei pezzi (stanze e corridoi).
func read_layout() -> Dictionary:
	var stone := get_node_or_null(stone_path)
	if stone == null:
		push_warning("Terreno: stone_path non impostato")
		return {}
	var terra := []
	var vuoti := []
	var centro := Vector3.ZERO
	for c in stone.find_children("*", "Node3D", true, false):
		if not c.has_meta("volume_size"):
			continue
		var t := Transform3D()
		var n: Node = c
		while n != null and n != stone.get_parent():
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var size: Vector3 = c.get_meta("volume_size")
		var b := t.basis.orthonormalized()
		var half := (b.x.abs() * size.x + b.y.abs() * size.y + b.z.abs() * size.z) / 2.0
		var box := [t * (c.get_meta("volume_offset", Vector3.ZERO) as Vector3), half]
		if c.get_meta("terra", true):
			terra.append(box)
		else:
			vuoti.append(box)
		if c.get_meta("spawn", false):
			centro = box[0]
	return {"terra": terra, "vuoti": vuoti, "centro": centro}


## Riempie di terra gli spazi interni della catacomba (dirt_boxes),
## lasciando vuoti gli spazi in empty_boxes (es. lo spawn).
## Ogni box è [centro: Vector3, metà dimensioni: Vector3].
## Fuori dai box c'è la pietra della catacomba, che non fa parte di questo campo.
## Entro pure_radius metri da pure_center la terra è solo terra normale (zona iniziale).
func generate(dirt_boxes: Array, empty_boxes: Array, pure_center := Vector3.ZERO, pure_radius := 0.0) -> void:
	density.resize(SX * SY * (NZ + 1))
	material_id.resize(SX * SY * (NZ + 1))
	density.fill(-1.0)
	material_id.fill(MAT_TERRA)
	used_chunks.clear()
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.06
	# la terra sborda un po' dentro la pietra, così il bordo resta nascosto
	for b in dirt_boxes:
		var r := _range(b, 0.15 + VOXEL)
		for z in range(r[2], r[5] + 1):
			for y in range(r[1], r[4] + 1):
				for x in range(r[0], r[3] + 1):
					var i := x + y * SX + z * SXY
					var p := Vector3(x, y, z) * VOXEL
					var v := clampf(-(_sdf_box(p, b[0], b[1], 0.0) - 0.15) / VOXEL, -1.0, 1.0)
					if v <= density[i]:
						continue
					density[i] = v
					var m := MAT_TERRA
					if Vector2(p.x - pure_center.x, p.z - pure_center.z).length() >= pure_radius:
						var n := noise.get_noise_3dv(p)
						if n > 0.45:
							m = MAT_ROCCIA
						elif n > 0.2:
							m = MAT_DURA
					material_id[i] = m
		_mark_chunks(r)
	for b in empty_boxes:
		var r := _range(b, VOXEL)
		for z in range(r[2], r[5] + 1):
			for y in range(r[1], r[4] + 1):
				for x in range(r[0], r[3] + 1):
					var i := x + y * SX + z * SXY
					var v := clampf(_sdf_box(Vector3(x, y, z) * VOXEL, b[0], b[1], 0.0) / VOXEL, -1.0, 1.0)
					density[i] = minf(density[i], v)


## Indici dei campioni che coprono un box allargato di margin metri (senza toccare i bordi del campo).
func _range(b: Array, margin: float) -> Array:
	var lo: Vector3 = (b[0] - b[1]) / VOXEL - Vector3.ONE * margin / VOXEL
	var hi: Vector3 = (b[0] + b[1]) / VOXEL + Vector3.ONE * margin / VOXEL
	return [maxi(1, floori(lo.x)), maxi(1, floori(lo.y)), maxi(1, floori(lo.z)),
		mini(NX - 1, ceili(hi.x)), mini(NY - 1, ceili(hi.y)), mini(NZ - 1, ceili(hi.z))]


func _mark_chunks(r: Array) -> void:
	for cz in range(maxi(0, (r[2] - 1) / CHUNK), (r[5] + 1) / CHUNK + 1):
		for cy in range(maxi(0, (r[1] - 1) / CHUNK), (r[4] + 1) / CHUNK + 1):
			for cx in range(maxi(0, (r[0] - 1) / CHUNK), (r[3] + 1) / CHUNK + 1):
				used_chunks[Vector3i(cx, cy, cz)] = true


func _sdf_box(p: Vector3, c: Vector3, half: Vector3, r: float) -> float:
	var q := (p - c).abs() - (half - Vector3(r, r, r))
	return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r


func build_all() -> void:
	for c in used_chunks:
		if c.x * CHUNK < NX and c.y * CHUNK < NY and c.z * CHUNK < NZ:
			_remesh_chunk(c)


## Scava una sfera. power = quanta densità toglie al centro in questa chiamata.
## Restituisce i metri cubi rimossi per materiale: x = terra, y = terra dura, z = roccia.
func dig(center: Vector3, radius: float, power: float, max_mat: int) -> Vector3:
	var cs := center / VOXEL
	var rs := radius / VOXEL
	var x0 := maxi(1, floori(cs.x - rs))
	var x1 := mini(NX - 1, ceili(cs.x + rs))
	var y0 := maxi(1, floori(cs.y - rs))
	var y1 := mini(NY - 1, ceili(cs.y + rs))
	var z0 := maxi(1, floori(cs.z - rs))
	var z1 := mini(NZ - 1, ceili(cs.z + rs))
	if x0 > x1 or y0 > y1 or z0 > z1:
		return Vector3.ZERO
	var removed := [0.0, 0.0, 0.0]
	var changed := false
	for z in range(z0, z1 + 1):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var dist := Vector3(x, y, z).distance_to(cs)
				if dist > rs:
					continue
				var i := x + y * SX + z * SXY
				var m := material_id[i]
				if m > max_mat:
					continue
				var old := density[i]
				if old <= -1.0:
					continue
				var nd := maxf(old - power * (1.0 - dist / rs) * MAT_RATE[m], -1.0)
				density[i] = nd
				removed[m] += clampf(old, 0.0, 1.0) - clampf(nd, 0.0, 1.0)
				changed = true
	if changed:
		for cz in range(floori((z0 - 1) / float(CHUNK)), floori((z1 + 1) / float(CHUNK)) + 1):
			for cy in range(floori((y0 - 1) / float(CHUNK)), floori((y1 + 1) / float(CHUNK)) + 1):
				for cx in range(floori((x0 - 1) / float(CHUNK)), floori((x1 + 1) / float(CHUNK)) + 1):
					dirty[Vector3i(cx, cy, cz)] = true
	var vol := Vector3(removed[0], removed[1], removed[2]) * (VOXEL * VOXEL * VOXEL)
	removed_volume += vol.x + vol.y + vol.z
	return vol


## Ricalcola i chunk modificati. Chiamato ogni frame.
func flush() -> void:
	if dirty.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var n := 0
	for c in dirty.keys():
		_remesh_chunk(c)
		n += 1
	dirty.clear()
	last_remesh_ms = (Time.get_ticks_usec() - t0) / 1000.0
	last_remesh_chunks = n
	max_remesh_ms = maxf(max_remesh_ms, last_remesh_ms)


func _remesh_chunk(c: Vector3i) -> void:
	var x0 := c.x * CHUNK
	var y0 := c.y * CHUNK
	var z0 := c.z * CHUNK
	var x1 := mini(x0 + CHUNK, NX)
	var y1 := mini(y0 + CHUNK, NY)
	var z1 := mini(z0 + CHUNK, NZ)
	# celle che servono: una in più all'indietro per i quad sul bordo del chunk
	var cx0 := maxi(x0 - 1, 0)
	var cy0 := maxi(y0 - 1, 0)
	var cz0 := maxi(z0 - 1, 0)
	var lx := x1 - cx0
	var ly := y1 - cy0
	var lz := z1 - cz0
	var vidx := PackedInt32Array()
	vidx.resize(lx * ly * lz)
	vidx.fill(-1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var ds := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	# 1) un vertice per ogni cella attraversata dalla superficie
	for z in range(cz0, z1):
		for y in range(cy0, y1):
			for x in range(cx0, x1):
				var i0 := x + y * SX + z * SXY
				ds[0] = density[i0]
				ds[1] = density[i0 + 1]
				ds[2] = density[i0 + SX]
				ds[3] = density[i0 + 1 + SX]
				ds[4] = density[i0 + SXY]
				ds[5] = density[i0 + 1 + SXY]
				ds[6] = density[i0 + SX + SXY]
				ds[7] = density[i0 + 1 + SX + SXY]
				var solid := 0
				for k in 8:
					if ds[k] > 0.0:
						solid += 1
				if solid == 0 or solid == 8:
					continue
				var acc := Vector3.ZERO
				var cnt := 0
				for e in EDGES:
					var da: float = ds[e[0]]
					var db: float = ds[e[1]]
					if (da > 0.0) != (db > 0.0):
						var t := da / (da - db)
						acc += CORNERS[e[0]].lerp(CORNERS[e[1]], t)
						cnt += 1
				var local := acc / cnt
				var g := Vector3(
					(ds[1] - ds[0]) + (ds[3] - ds[2]) + (ds[5] - ds[4]) + (ds[7] - ds[6]),
					(ds[2] - ds[0]) + (ds[3] - ds[1]) + (ds[6] - ds[4]) + (ds[7] - ds[5]),
					(ds[4] - ds[0]) + (ds[5] - ds[1]) + (ds[6] - ds[2]) + (ds[7] - ds[3]))
				vidx[(x - cx0) + (y - cy0) * lx + (z - cz0) * lx * ly] = verts.size()
				verts.append((Vector3(x, y, z) + local) * VOXEL)
				norms.append((-g).normalized() if g.length_squared() > 0.0 else Vector3.UP)
				cols.append(MAT_COLOR[material_id[i0]])

	# 2) un quad per ogni spigolo che la superficie attraversa
	var idx := PackedInt32Array()
	for z in range(z0, z1):
		for y in range(y0, y1):
			for x in range(x0, x1):
				var i := x + y * SX + z * SXY
				var a := density[i] > 0.0
				# spigolo lungo X
				if y >= 1 and z >= 1 and (density[i + 1] > 0.0) != a:
					var v0 := _v(vidx, x, y - 1, z - 1, cx0, cy0, cz0, lx, ly)
					var v1 := _v(vidx, x, y, z - 1, cx0, cy0, cz0, lx, ly)
					var v2 := _v(vidx, x, y, z, cx0, cy0, cz0, lx, ly)
					var v3 := _v(vidx, x, y - 1, z, cx0, cy0, cz0, lx, ly)
					_quad(idx, v0, v1, v2, v3, not a)
				# spigolo lungo Y
				if x >= 1 and z >= 1 and (density[i + SX] > 0.0) != a:
					var v0 := _v(vidx, x - 1, y, z - 1, cx0, cy0, cz0, lx, ly)
					var v1 := _v(vidx, x, y, z - 1, cx0, cy0, cz0, lx, ly)
					var v2 := _v(vidx, x, y, z, cx0, cy0, cz0, lx, ly)
					var v3 := _v(vidx, x - 1, y, z, cx0, cy0, cz0, lx, ly)
					_quad(idx, v0, v1, v2, v3, a)
				# spigolo lungo Z
				if x >= 1 and y >= 1 and (density[i + SXY] > 0.0) != a:
					var v0 := _v(vidx, x - 1, y - 1, z, cx0, cy0, cz0, lx, ly)
					var v1 := _v(vidx, x, y - 1, z, cx0, cy0, cz0, lx, ly)
					var v2 := _v(vidx, x, y, z, cx0, cy0, cz0, lx, ly)
					var v3 := _v(vidx, x - 1, y, z, cx0, cy0, cz0, lx, ly)
					_quad(idx, v0, v1, v2, v3, not a)

	_apply_chunk(c, verts, norms, cols, idx)


func _v(vidx: PackedInt32Array, x: int, y: int, z: int, cx0: int, cy0: int, cz0: int, lx: int, ly: int) -> int:
	return vidx[(x - cx0) + (y - cy0) * lx + (z - cz0) * lx * ly]


## Godot considera "davanti" le facce in senso orario.
func _quad(idx: PackedInt32Array, v0: int, v1: int, v2: int, v3: int, clockwise: bool) -> void:
	if v0 < 0 or v1 < 0 or v2 < 0 or v3 < 0:
		return
	if clockwise:
		idx.append_array([v0, v1, v2, v0, v2, v3])
	else:
		idx.append_array([v0, v3, v2, v0, v2, v1])


func _apply_chunk(c: Vector3i, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array) -> void:
	var nodes: Array = chunk_nodes.get(c, [])
	if idx.is_empty():
		if not nodes.is_empty():
			nodes[0].queue_free()
			nodes[1].queue_free()
			chunk_nodes.erase(c)
		return
	if nodes.is_empty():
		var mi := MeshInstance3D.new()
		add_child(mi)
		var cs := CollisionShape3D.new()
		body.add_child(cs)
		nodes = [mi, cs]
		chunk_nodes[c] = nodes
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, surface_material)
	nodes[0].mesh = mesh
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for k in idx.size():
		faces[k] = verts[idx[k]]
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	nodes[1].shape = shape


func material_at(p: Vector3) -> int:
	var s := (p / VOXEL).round()
	var x := clampi(int(s.x), 0, NX)
	var y := clampi(int(s.y), 0, NY)
	var z := clampi(int(s.z), 0, NZ)
	return material_id[x + y * SX + z * SXY]
