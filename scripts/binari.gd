extends Node3D
## Rotaie e carrello. Le rotaie stanno su una griglia da 1 m sul pavimento (y = PAV):
## ogni pezzo si collega da solo ai vicini (dritti, curve, incroci).
## Il carrello corre sulle rotaie: lo si spinge camminandoci contro, ci si mettono
## i secchi (E) e quando arriva accanto al montacarichi si ribalta e li scarica.
## Lo stato vero (rotaie, posizione del carrello, secchi dentro) lo tiene il server;
## main.gd lo manda agli altri computer.

const PAV := 2.0
const CAPIENZA := 6
const LEGNO := Color(0.45, 0.29, 0.17)
const FERRO := Color(0.42, 0.43, 0.48)

var celle := {}                 # Vector2i -> true
var vagone: Node3D              # il carrello (null finché non c'è)
var a := Vector2i.ZERO          # cella da cui viene
var b := Vector2i.ZERO          # cella verso cui va
var u := 0.0                    # avanzamento da a a b (0..1)
var carico: Array[int] = []     # valore dei secchi nel carrello
var ribaltando := 0.0           # secondi di animazione di scarico rimasti
var _vis := {}                  # Vector2i -> Node3D (pezzo disegnato)
var _mat_legno: StandardMaterial3D
var _mat_ferro: StandardMaterial3D


func _ready() -> void:
	_mat_legno = _mat(LEGNO)
	_mat_ferro = _mat(FERRO)
	_mat_ferro.metallic = 0.5
	_mat_ferro.roughness = 0.5


static func cella(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


static func centro(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, PAV, c.y + 0.5)


func vicini(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if celle.has(c + d):
			out.append(c + d)
	return out


# --- rotaie ---------------------------------------------------------------------

func metti(c: Vector2i) -> void:
	celle[c] = true
	_ridisegna_intorno(c)


func togli(c: Vector2i) -> void:
	celle.erase(c)
	_ridisegna_intorno(c)


func imposta(lista: Array) -> void:
	celle.clear()
	for k in _vis:
		_vis[k].queue_free()
	_vis.clear()
	for c in lista:
		celle[c] = true
	for c in celle:
		_disegna(c)


func _ridisegna_intorno(c: Vector2i) -> void:
	for n in [c, c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
		if _vis.has(n):
			_vis[n].queue_free()
			_vis.erase(n)
		if celle.has(n):
			_disegna(n)


## Disegna un pezzo: traversine e due rotaie che vanno dal centro verso ogni vicino.
func _disegna(c: Vector2i) -> void:
	var n := Node3D.new()
	n.name = "Rotaia_%d_%d" % [c.x, c.y]
	n.position = centro(c)
	add_child(n)
	_vis[c] = n
	var dirs := vicini(c).map(func(v): return Vector2(v - c))
	if dirs.is_empty():
		dirs = [Vector2(1, 0)]
	for d: Vector2 in dirs:
		var dir := Vector3(d.x, 0, d.y)
		var side := Vector3(-d.y, 0, d.x)
		var yaw := atan2(dir.x, dir.z)
		# traversina a metà del mezzo pezzo
		_box(n, dir * 0.25 + Vector3(0, 0.03, 0), Vector3(0.75, 0.06, 0.14), yaw, _mat_legno)
		for s in [-0.22, 0.22]:
			_box(n, dir * 0.25 + side * s + Vector3(0, 0.09, 0), Vector3(0.05, 0.06, 0.52), yaw, _mat_ferro)
	# traversina centrale
	_box(n, Vector3(0, 0.03, 0), Vector3(0.75, 0.06, 0.16), atan2(dirs[0].x, dirs[0].y), _mat_legno)


func _box(parent: Node3D, pos: Vector3, size: Vector3, yaw: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	m.rotation.y = yaw
	parent.add_child(m)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


# --- carrello -------------------------------------------------------------------

## Crea il carrello sulla rotaia più vicina a vicino_a. false se non ci sono rotaie.
func crea_vagone(vicino_a: Vector3) -> bool:
	if celle.is_empty():
		return false
	var best := Vector2i.ZERO
	var bd := INF
	for c in celle:
		var d := centro(c).distance_to(vicino_a)
		if d < bd:
			bd = d
			best = c
	if vagone == null:
		vagone = (load("res://scenes/vagone.tscn") as PackedScene).instantiate()
		add_child(vagone)
	a = best
	var v := vicini(best)
	b = v[0] if not v.is_empty() else best
	u = 0.0
	_posiziona()
	return true


## Spinge il carrello di s metri nella direzione dir (orizzontale). Solo sul server.
func spingi(s: float, dir: Vector3) -> void:
	if vagone == null or ribaltando > 0.0 or not celle.has(a):
		return
	if not celle.has(b) or a == b:
		var v := vicini(a)
		if v.is_empty():
			return
		b = v[0]
	var tang := (centro(b) - centro(a)).normalized()
	var passo := s * signf(dir.dot(tang)) if absf(dir.dot(tang)) > 0.3 else 0.0
	if passo < 0.0:
		var t := a
		a = b
		b = t
		u = 1.0 - u
		passo = -passo
	u += passo
	while u >= 1.0:
		# arrivato in b: prosegue verso il vicino più dritto, oppure si ferma a fine binario
		var prima := a
		a = b
		var avanti := a + (a - prima)
		var nuovi := vicini(a).filter(func(x): return x != prima)
		if nuovi.is_empty():
			b = a
			u = 0.0
			break
		b = avanti if avanti in nuovi else nuovi[0]
		u -= 1.0
	_posiziona()


func _posiziona() -> void:
	if vagone == null:
		return
	var pa := centro(a)
	var pb := centro(b)
	vagone.position = pa.lerp(pb, u)
	if a != b:
		var d := pb - pa
		vagone.rotation.y = lerp_angle(vagone.rotation.y, atan2(d.x, d.z), 0.5)


## Mette dei secchi nel carrello. Restituisce quanti ne sono entrati.
func carica(valori: Array) -> int:
	var n := 0
	for v in valori:
		if carico.size() >= CAPIENZA:
			break
		carico.append(int(v))
		n += 1
	mostra_carico(carico.size())
	return n


func mostra_carico(n: int) -> void:
	if vagone:
		for i in CAPIENZA:
			(vagone.get_node("Cassone/Carico/Secchio%d" % i) as Node3D).visible = i < n


## Animazione di ribaltamento (su tutti i computer).
func ribalta() -> void:
	ribaltando = 1.2


func _process(delta: float) -> void:
	if vagone == null:
		return
	var cassone := vagone.get_node("Cassone") as Node3D
	if ribaltando > 0.0:
		ribaltando -= delta
		var k := sin(clampf(1.0 - ribaltando / 1.2, 0.0, 1.0) * PI)
		cassone.rotation.z = -1.0 * k
	else:
		cassone.rotation.z = 0.0


## Stato da mandare in rete / salvare.
func esporta() -> Dictionary:
	return {"celle": celle.keys(), "vagone": vagone != null, "a": a, "b": b, "u": u, "carico": carico.duplicate()}


func importa(d: Dictionary) -> void:
	imposta(d.get("celle", []))
	carico.assign(d.get("carico", []))
	if d.get("vagone", false):
		if vagone == null:
			vagone = (load("res://scenes/vagone.tscn") as PackedScene).instantiate()
			add_child(vagone)
		a = d["a"]
		b = d["b"]
		u = d["u"]
		_posiziona()
		mostra_carico(carico.size())
