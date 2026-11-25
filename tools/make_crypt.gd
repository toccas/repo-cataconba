extends SceneTree
## Crea i pezzi della catacomba in stile Kenney e li salva in res://modelli/cripta/ come GLB,
## ognuno con la sua collisione semplice (<nome>_collisione.res).
## Corridoi, curve, incroci e fondi sono scavati nella roccia: pareti a facce irregolari
## che in alto si chiudono a volta, con loculi (nicchie delle sepolture), aperti o chiusi
## da una lastra. Le stanze hanno muri in blocchi di tufo, lesene e portali ad arco.
## Griglia da 4 m, pavimento a y = 0, altezza utile 4 m (sopra c'è il soffitto).
## Stesse convenzioni del Modular Cave Kit: il corridoio va lungo X, il fondo è aperto
## verso +X, la curva è aperta verso -X e -Z, la T è chiusa verso +Z.
## Uso: godot --headless --path . --script res://tools/make_crypt.gd

const LowPoly := preload("res://tools/low_poly.gd")
const OUT := "res://modelli/cripta/"

const H := 4.0          # altezza utile
const W := 1.25         # metà larghezza interna dei corridoi
const IMPOSTA := 2.75   # altezza da cui partono gli archi
const SPESSORE := 0.75  # spessore dei muri

const TUFO := [Color(0.74, 0.67, 0.52), Color(0.68, 0.61, 0.47), Color(0.79, 0.72, 0.57)]
const MALTA := Color(0.44, 0.39, 0.31)
const PIETRA := Color(0.60, 0.54, 0.43)        # pilastri, archi, cornici
const LASTRE := [Color(0.57, 0.52, 0.43), Color(0.51, 0.47, 0.39), Color(0.62, 0.57, 0.47)]
# roccia scavata dei cunicoli
const ROCCIA := [Color(0.58, 0.52, 0.42), Color(0.52, 0.47, 0.38), Color(0.63, 0.57, 0.46), Color(0.47, 0.42, 0.34)]
const ROCCIA_PAV := [Color(0.46, 0.41, 0.33), Color(0.42, 0.38, 0.31), Color(0.50, 0.45, 0.36)]
const NUCLEO := Color(0.28, 0.25, 0.20)
const LOCULO_BUIO := Color(0.10, 0.08, 0.07)
const LAPIDE := Color(0.74, 0.70, 0.60)
const VOLTA := 2.5        # altezza da cui le pareti dei cunicoli piegano verso il centro

var lp := LowPoly.new()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_tile("cripta-corridoio", {"px": true, "nx": true})
	_tile("cripta-corridoio-2", {"px": true, "nx": true})
	_tile("cripta-corridoio-3", {"px": true, "nx": true})
	_tile("cripta-fondo", {"px": true})
	_tile("cripta-curva", {"nx": true, "nz": true})
	_tile("cripta-t", {"px": true, "nx": true, "nz": true})
	_tile("cripta-incrocio", {"px": true, "nx": true, "pz": true, "nz": true})
	_room("cripta-stanza")
	# stanza di spawn: il soffitto ha l'apertura del pozzo del montacarichi
	# (centro come LIFT_POS in scripts/spawn_room.gd)
	_room("cripta-stanza-spawn", Rect2(-4.05, -4.05, 2.6, 2.6))
	quit()


# --- pezzi ---------------------------------------------------------------------

## Pezzo di cunicolo da 4 x 4 m scavato nella roccia.
## open: lati aperti ("px" = +X, "nx" = -X, "pz" = +Z, "nz" = -Z).
func _tile(id: String, open: Dictionary) -> void:
	rng.seed = hash(id)
	_floor(-2.0, 2.0, -2.0, 2.0, ROCCIA_PAV, 0.035)
	if open.size() == 2 and open.has("px") and open.has("nx"):
		# cunicolo dritto: due pareti continue che si chiudono a volta, con loculi
		for side in [1.0, -1.0]:
			var xf := Transform3D(Basis(Vector3.UP, 0.0 if side > 0 else PI), Vector3.ZERO)
			_rock_wall(xf, -2.0, 2.0, true)
	else:
		var sides := {"pz": 0.0, "px": PI / 2.0, "nz": PI, "nx": -PI / 2.0}
		for sd in sides:
			var xf := Transform3D(Basis(Vector3.UP, sides[sd]), Vector3.ZERO)
			# angolo destro di questo lato: massa di roccia
			_rock_mass(xf, Vector3(1.55, 0, 1.55))
			if open.has(sd):
				# apertura scavata: arco grezzo di roccia
				lp.arch(xf * Vector3(0, VOLTA, 1.55), xf.basis * Vector3.RIGHT, xf.basis * Vector3.BACK,
					1.1, 1.45, 0.9, 7, ROCCIA[1], 0.07, H + 0.1, ROCCIA[3])
			else:
				_rock_wall(xf, -1.1, 1.1, open.size() == 1)
	_save(id)


## Stanza da 12 x 12 m con un portale ad arco al centro di ogni lato.
## hole: apertura nel soffitto (rettangolo in x/z), vuoto se non c'è.
func _room(id: String, hole := Rect2()) -> void:
	rng.seed = hash(id)
	_floor(-6.0, 6.0, -6.0, 6.0, LASTRE, 0.015)
	for k in 4:
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0 * k), Vector3.ZERO)
		var inner := 5.25
		_pillar(xf, Vector3(5.55, 0, 5.55), Vector3(0.9, H, 0.9))
		_wall(xf, Vector3(-5.1, 0, inner), Vector3(-2.0, 0, inner))
		_wall(xf, Vector3(2.0, 0, inner), Vector3(5.1, 0, inner))
		# stipiti e arco del portale
		for sx in [-1.55, 1.55]:
			_pillar(xf, Vector3(sx, 0, 5.55), Vector3(0.9, H, 0.9))
		lp.arch(xf * Vector3(0, IMPOSTA, 5.55), xf.basis * Vector3.RIGHT, xf.basis * Vector3.BACK,
			1.1, 1.4, 0.9, 9, PIETRA, 0.03, H + 0.1, TUFO[1])
		# lesene a metà dei muri
		for sx in [-3.55, 3.55]:
			_pillar(xf, Vector3(sx, 0, inner - 0.1), Vector3(0.5, H, 0.2))
	_room_ceiling(hole)
	_save(id)


## Soffitto della stanza: lastre di pietra tra travi che poggiano sulle lesene
## (a -3,55, 0 e 3,55 in entrambe le direzioni). Le travi e le lastre che cadono
## nell'apertura hole vengono tagliate; attorno all'apertura c'è una cornice.
func _room_ceiling(hole: Rect2) -> void:
	var half := 5.25
	var top := H + 0.05
	# lastre
	var n := 7
	var step := 2.0 * half / n
	for i in n:
		for j in n:
			var cell := Rect2(-half + i * step, -half + j * step, step, step)
			if hole.has_area() and hole.grow(-0.01).intersects(cell):
				continue
			var cx := cell.get_center()
			lp.cbox(Transform3D(Basis(), Vector3(cx.x, top - 0.17 + rng.randf_range(0.0, 0.03), cx.y)),
				Vector3(step - 0.06, 0.1, step - 0.06), 0.02, LASTRE[rng.randi() % LASTRE.size()])
	# fondo scuro dietro le fughe
	for seg in _cut(Rect2(-half, -half, 2.0 * half, 2.0 * half), hole):
		var c := (seg as Rect2).get_center()
		lp.cbox(Transform3D(Basis(), Vector3(c.x, top - 0.1, c.y)), Vector3(seg.size.x, 0.06, seg.size.y), 0.0, MALTA)
	# travi
	for k in [-3.55, 0.0, 3.55]:
		for seg in _cut(Rect2(-half, k - 0.2, 2.0 * half, 0.4), hole):
			var c := (seg as Rect2).get_center()
			lp.cbox(Transform3D(Basis(), Vector3(c.x, top - 0.28, c.y)), Vector3(seg.size.x, 0.4, seg.size.y), 0.04, PIETRA)
		for seg in _cut(Rect2(k - 0.2, -half, 0.4, 2.0 * half), hole):
			var c := (seg as Rect2).get_center()
			lp.cbox(Transform3D(Basis(), Vector3(c.x, top - 0.3, c.y)), Vector3(seg.size.x, 0.36, seg.size.y), 0.04, PIETRA)
	# cornice attorno al pozzo
	if hole.has_area():
		var c := hole.get_center()
		var hs := hole.size / 2.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var p: Vector2 = c + d * (hs + Vector2(0.15, 0.15))
			var size: Vector3 = Vector3(0.3 if d.x != 0 else hole.size.x + 0.6, 0.5, 0.3 if d.y != 0 else hole.size.y + 0.6)
			lp.cbox(Transform3D(Basis(), Vector3(p.x, top - 0.3, p.y)), size, 0.04, PIETRA.darkened(0.1))


## Parti di r che restano fuori da hole (taglia r lungo l'asse più lungo).
func _cut(r: Rect2, hole: Rect2) -> Array:
	if not hole.has_area() or not r.intersects(hole):
		return [r]
	var out := []
	if r.size.x >= r.size.y:
		if hole.position.x > r.position.x:
			out.append(Rect2(r.position, Vector2(hole.position.x - r.position.x, r.size.y)))
		if hole.end.x < r.end.x:
			out.append(Rect2(Vector2(hole.end.x, r.position.y), Vector2(r.end.x - hole.end.x, r.size.y)))
	else:
		if hole.position.y > r.position.y:
			out.append(Rect2(r.position, Vector2(r.size.x, hole.position.y - r.position.y)))
		if hole.end.y < r.end.y:
			out.append(Rect2(Vector2(r.position.x, hole.end.y), Vector2(r.size.x, r.end.y - hole.end.y)))
	return out


# --- elementi --------------------------------------------------------------------

## Pavimento a lastre da 1 m, con la faccia superiore a y = 0.
## bump: quanto possono affondare le lastre (la roccia è più irregolare delle stanze).
func _floor(x0: float, x1: float, z0: float, z1: float, colors: Array, bump: float) -> void:
	var c := Vector3((x0 + x1) / 2.0, -0.2, (z0 + z1) / 2.0)
	var size := Vector3(x1 - x0, 0.36, z1 - z0)
	lp.cbox(Transform3D(Basis(), c + Vector3(0, -0.02, 0)), size, 0.0, MALTA)
	lp.col_box(Transform3D(Basis(), c), Vector3(size.x, 0.4, size.z))
	var x := x0
	while x < x1 - 0.01:
		var z := z0
		while z < z1 - 0.01:
			var w := minf(1.0, x1 - x)
			var d := minf(1.0, z1 - z)
			var drop := rng.randf_range(0.0, bump)
			lp.cbox(Transform3D(Basis(), Vector3(x + w / 2.0, -0.04 - drop, z + d / 2.0)),
				Vector3(w - 0.06, 0.08, d - 0.06), 0.02, colors[rng.randi() % colors.size()])
			z += 1.0
		x += 1.0


## Muro di blocchi di tufo a corsi sfalsati, con zoccolo e cornice.
## a, b: estremi della faccia interna (a y = 0) nello spazio del lato; la faccia
## interna guarda verso -Z del lato, il muro va verso +Z per SPESSORE.
func _wall(xf: Transform3D, a: Vector3, b: Vector3) -> void:
	var along := (xf.basis * (b - a)).normalized()
	var inward := xf.basis * Vector3.FORWARD
	var length := a.distance_to(b)
	var mid := xf * ((a + b) / 2.0)
	var wb := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	# nucleo del muro (malta) e collisione
	var core := Transform3D(wb, mid - inward * SPESSORE / 2.0 + Vector3.UP * H / 2.0)
	lp.cbox(core, Vector3(length, H, SPESSORE), 0.0, MALTA)
	lp.col_box(core, Vector3(length, H, SPESSORE))
	# blocchi
	var row_h := 0.4
	var rows := int(ceil(H / row_h))
	for r in rows:
		var x := -length / 2.0 - (0.45 if r % 2 == 1 else 0.0)
		while x < length / 2.0:
			var blen := rng.randf_range(0.7, 1.0)
			var s := maxf(x, -length / 2.0)
			var e := minf(x + blen, length / 2.0)
			if e - s > 0.15:
				var p := mid + along * ((s + e) / 2.0) + Vector3.UP * (r * row_h + row_h / 2.0) + inward * 0.02
				var depth := rng.randf_range(0.07, 0.1)
				lp.cbox(Transform3D(wb, p), Vector3(e - s - 0.05, row_h - 0.05, depth), 0.025, TUFO[rng.randi() % TUFO.size()])
			x += blen
	# zoccolo in basso e cornice in alto
	lp.cbox(Transform3D(wb, mid + Vector3.UP * 0.16 + inward * 0.06), Vector3(length, 0.32, 0.16), 0.03, PIETRA)
	lp.cbox(Transform3D(wb, mid + Vector3.UP * (IMPOSTA + 0.08) + inward * 0.05), Vector3(length, 0.16, 0.14), 0.03, PIETRA)


## Parete di roccia scavata, da x0 a x1 nello spazio del lato (faccia interna a z = W,
## la roccia va verso +Z). Facce irregolari che sopra VOLTA piegano verso il centro
## formando la volta. Con loculi = true può avere una colonna di due loculi.
func _rock_wall(xf: Transform3D, x0: float, x1: float, loculi: bool) -> void:
	var along := xf.basis * Vector3.RIGHT
	var wb := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var length := x1 - x0
	# nucleo scuro dietro le facce (si vede nelle fessure) e collisione
	lp.cbox(Transform3D(wb, xf * Vector3((x0 + x1) / 2.0, H / 2.0, W + 0.7)), Vector3(length, H, 0.6), 0.0, NUCLEO)
	lp.col_box(Transform3D(wb, xf * Vector3((x0 + x1) / 2.0, H / 2.0, W + (2.0 - W) / 2.0)), Vector3(length, H, 2.0 - W))
	# colonne di facce lungo il muro: [inizio, fine, è un loculo]
	var cols := []
	var loc_start := INF
	if loculi and length > 3.0 and rng.randf() < 0.85:
		loc_start = (x0 + x1) / 2.0 - 0.85 + rng.randf_range(-0.4, 0.4)
	var x := x0
	while x < x1 - 0.01:
		if x < loc_start and x + 1.2 > loc_start:
			if loc_start - x > 0.2:
				cols.append([x, loc_start, false])
			cols.append([loc_start, loc_start + 1.7, true])
			x = loc_start + 1.7
			continue
		var w := minf(rng.randf_range(0.7, 1.1), x1 - x)
		if x1 - (x + w) < 0.3:
			w = x1 - x
		cols.append([x, x + w, false])
		x += w
	var rows := [0.0, 0.35, 0.95, 1.15, 1.75, VOLTA, 3.05, 3.5, 3.85, 4.15]
	for c in cols:
		for r in rows.size() - 1:
			var y0: float = rows[r]
			var y1: float = rows[r + 1]
			if c[2]:
				if r == 1 or r == 3:
					_loculo(xf, wb, c[0], c[1], y0, y1)
					continue
			elif r == 1:
				# fuori dai loculi le file 1-2-3 sono una faccia sola, più grande
				y1 = rows[4]
			elif r == 2 or r == 3:
				continue
			_facet(xf, wb, c[0], c[1], y0, y1)


## Una faccia di roccia della parete, inclinata a volta se è sopra VOLTA.
func _facet(xf: Transform3D, wb: Basis, s: float, e: float, y0: float, y1: float) -> void:
	var ym := (y0 + y1) / 2.0
	var t := clampf((ym - VOLTA) / W, 0.0, 0.95)
	var lean := W - sqrt(W * W - (t * W) * (t * W))     # quanto rientra la volta a questa altezza
	var tilt := -asin(t)
	var jitter := Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
	var b := wb * Basis(Vector3.RIGHT, tilt) * jitter
	var depth := rng.randf_range(0.35, 0.55)
	var pos := xf * Vector3((s + e) / 2.0, ym, W - lean + depth / 2.0 - rng.randf_range(0.0, 0.08))
	var size := Vector3((e - s) * rng.randf_range(1.0, 1.08), (y1 - y0) * 1.1 / cos(asin(t)), depth)
	lp.cbox(Transform3D(b, pos), size, 0.06, ROCCIA[rng.randi() % ROCCIA.size()])


## Loculo: nicchia rettangolare nella roccia, aperta (buia) o chiusa da una lastra.
func _loculo(xf: Transform3D, wb: Basis, s: float, e: float, y0: float, y1: float) -> void:
	var cx := (s + e) / 2.0
	var ym := (y0 + y1) / 2.0
	lp.cbox(Transform3D(wb, xf * Vector3(cx, ym, W + 0.62)), Vector3(e - s, y1 - y0, 0.08), 0.0, LOCULO_BUIO)
	# fondo e cielo della nicchia (si vedono di sbieco)
	lp.cbox(Transform3D(wb, xf * Vector3(cx, y0 + 0.03, W + 0.3)), Vector3(e - s, 0.06, 0.6), 0.02, ROCCIA[3])
	lp.cbox(Transform3D(wb, xf * Vector3(cx, y1 - 0.03, W + 0.3)), Vector3(e - s, 0.06, 0.6), 0.02, NUCLEO)
	if rng.randf() < 0.5:
		# chiuso da una lastra con una croce incisa
		lp.cbox(Transform3D(wb, xf * Vector3(cx, ym, W + 0.1)), Vector3(e - s - 0.08, y1 - y0 - 0.06, 0.06), 0.015, LAPIDE)
		lp.cbox(Transform3D(wb, xf * Vector3(cx, ym, W + 0.065)), Vector3(0.03, 0.26, 0.02), 0.0, NUCLEO)
		lp.cbox(Transform3D(wb, xf * Vector3(cx, ym + 0.04, W + 0.065)), Vector3(0.16, 0.03, 0.02), 0.0, NUCLEO)


## Massa di roccia in un angolo (dove si incontrano due pareti di cunicolo).
func _rock_mass(xf: Transform3D, pos: Vector3) -> void:
	var p := xf * pos
	lp.col_box(Transform3D(xf.basis, p + Vector3.UP * H / 2.0), Vector3(0.9, H, 0.9))
	var y := 0.0
	while y < H:
		var h := rng.randf_range(0.8, 1.3)
		var jb := xf.basis * Basis(Vector3.UP, rng.randf_range(-0.25, 0.25)) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06))
		var off := Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		lp.cbox(Transform3D(jb, p + off + Vector3.UP * (y + h / 2.0)), Vector3(1.0, h * 1.05, 1.0), 0.08, ROCCIA[rng.randi() % ROCCIA.size()])
		y += h


## Pilastro (o lesena) dal pavimento al soffitto, con base e capitello.
func _pillar(xf: Transform3D, pos: Vector3, size: Vector3) -> void:
	var p := xf * pos
	var b := xf.basis
	var body := Transform3D(b, p + Vector3.UP * size.y / 2.0)
	lp.cbox(body, size, 0.05, PIETRA)
	lp.col_box(body, size)
	lp.cbox(Transform3D(b, p + Vector3.UP * 0.15), size + Vector3(0.12, -size.y + 0.3, 0.12), 0.04, PIETRA.darkened(0.12))
	lp.cbox(Transform3D(b, p + Vector3.UP * (IMPOSTA - 0.1)), size + Vector3(0.12, -size.y + 0.2, 0.12), 0.04, PIETRA.darkened(0.12))


func _save(id: String) -> void:
	lp.save_glb(OUT + id + ".glb", id)
	lp.save_collision(OUT + id + "_collisione.res")
