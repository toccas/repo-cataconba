extends Node3D
## Griglia del pavimento per far camminare gli scheletri lavoratori (ricerca del percorso A*).
## Celle da 0,5 m sul pavimento della catacomba (y = PAV). Una cella è libera se è dentro
## una stanza o un corridoio, non c'è un muro o un mobile (letti una volta dalla fisica)
## e non c'è terra all'altezza del corpo (aggiornata ogni volta che si scava).
## La costruisce il server la prima volta che serve (costruisci()).

const CELLA := 0.5
const N := 128               # 128 x 128 celle = 64 x 64 m, come il terreno
const PAV := 2.0             # altezza del pavimento

var astar := AStarGrid2D.new()
var statico := PackedByteArray()   # 1 = muro, mobile o fuori dalla catacomba
var terra_cell := PackedByteArray() # 1 = c'è terra all'altezza del corpo
var pronto := false
var terra: Node


## Legge la catacomba: stanze e corridoi dal terreno, muri e mobili dalla fisica.
## esclusi: corpi da ignorare (il terreno, il giocatore).
func costruisci(terrain: Node, esclusi: Array[RID]) -> void:
	terra = terrain
	var layout: Dictionary = terrain.read_layout()
	var boxes: Array = layout["terra"] + layout["vuoti"]
	astar.region = Rect2i(0, 0, N, N)
	astar.cell_size = Vector2(CELLA, CELLA)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	statico.resize(N * N)
	terra_cell.resize(N * N)
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.34, 1.3, 0.34)
	q.shape = shape
	q.exclude = esclusi
	for j in N:
		for i in N:
			var c := centro(Vector2i(i, j))
			var dentro := false
			for b in boxes:
				var bc: Vector3 = b[0]
				var bh: Vector3 = b[1]
				if absf(c.x - bc.x) < bh.x and absf(c.z - bc.z) < bh.z and bc.y - bh.y <= PAV + 0.2:
					dentro = true
					break
			var bloccato := not dentro
			if dentro:
				q.transform = Transform3D(Basis(), Vector3(c.x, PAV + 1.0, c.z))
				for r in space.intersect_shape(q, 8):
					if not (r["collider"] is RigidBody3D):
						bloccato = true
						break
			statico[i + j * N] = 1 if bloccato else 0
			_aggiorna_cella(Vector2i(i, j))
	terrain.cambiata.connect(_on_terra_cambiata)
	pronto = true


func cella(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(p.x / CELLA), 0, N - 1), clampi(floori(p.z / CELLA), 0, N - 1))


func centro(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELLA, PAV, (c.y + 0.5) * CELLA)


func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


## Si può camminare qui?
func libera(c: Vector2i) -> bool:
	return dentro(c) and statico[c.x + c.y * N] == 0 and terra_cell[c.x + c.y * N] == 0


## C'è terra da scavare qui (e non un muro)?
func di_terra(c: Vector2i) -> bool:
	return dentro(c) and statico[c.x + c.y * N] == 0 and terra_cell[c.x + c.y * N] == 1


func _aggiorna_cella(c: Vector2i) -> void:
	var k := c.x + c.y * N
	var p := centro(c)
	var piena := 0
	if statico[k] == 0:
		for h in [0.35, 1.0, 1.6]:
			if terra.solida(p + Vector3(0, h, 0)):
				piena = 1
				break
	terra_cell[k] = piena
	astar.set_point_solid(c, statico[k] == 1 or piena == 1)


func _on_terra_cambiata(centro_scavo: Vector3, raggio: float) -> void:
	var a := cella(centro_scavo - Vector3(raggio + 0.5, 0, raggio + 0.5))
	var b := cella(centro_scavo + Vector3(raggio + 0.5, 0, raggio + 0.5))
	for j in range(a.y, b.y + 1):
		for i in range(a.x, b.x + 1):
			_aggiorna_cella(Vector2i(i, j))


## La cella libera più vicina a p (entro raggio metri), o (-1, -1).
func libera_vicina(p: Vector3, raggio := 2.0) -> Vector2i:
	var c := cella(p)
	if libera(c):
		return c
	var best := Vector2i(-1, -1)
	var best_d := INF
	var r := ceili(raggio / CELLA)
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			var n := c + Vector2i(di, dj)
			if libera(n):
				var d := centro(n).distance_to(Vector3(p.x, PAV, p.z))
				if d < best_d and d <= raggio:
					best_d = d
					best = n
	return best


## Percorso (punti sul pavimento) da da ad a. Vuoto se non ci si arriva.
func percorso(da: Vector3, a: Vector2i) -> PackedVector3Array:
	var out := PackedVector3Array()
	var s := libera_vicina(da, 1.5)
	if s.x < 0 or not libera(a):
		return out
	for c in astar.get_id_path(s, a):
		out.append(centro(c) + _scosta(c))
	return out


## Sposta il punto di una cella via dalle celle bloccate attorno (al centro dei corridoi).
func _scosta(c: Vector2i) -> Vector3:
	var off := Vector2.ZERO
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			if (di != 0 or dj != 0) and not libera(c + Vector2i(di, dj)):
				off -= Vector2(di, dj).normalized()
	if off.length() < 0.01:
		return Vector3.ZERO
	off = off.limit_length(1.0) * 0.18
	return Vector3(off.x, 0, off.y)


## Il fronte di terra più vicino raggiungibile da da: una cella di terra scavabile
## accanto a una cella libera. Restituisce [cella di terra, cella dove stare] o [].
## max_mat: materiale più duro che si sa scavare. saltate: celle da ignorare.
func fronte_vicino(da: Vector3, max_mat: int, saltate: Dictionary) -> Array:
	var s := libera_vicina(da, 1.5)
	if s.x < 0:
		return []
	var visti := {s: true}
	var coda: Array[Vector2i] = [s]
	var testa := 0
	while testa < coda.size() and testa < 6000:
		var c := coda[testa]
		testa += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not dentro(n) or visti.has(n):
				continue
			visti[n] = true
			if libera(n):
				coda.append(n)
			elif di_terra(n) and not saltate.has(n):
				if terra.material_at(centro(n) + Vector3(0, 0.6, 0)) <= max_mat:
					return [n, c]
	return []
