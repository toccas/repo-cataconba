extends Node3D
## Un altro giocatore della partita online, visto da qui: il becchino (modelli/becchino_*)
## col mantello del suo colore, il nome sopra la testa, la lampada e la fiamma, e in mano
## l'attrezzo, il secchio, l'osso o la dinamite. Cammina muovendo gambe e braccia e scava
## colpendo con l'attrezzo.
## Riceve posizione e stato ~20 volte al secondo (main.gd) e li segue morbidamente.

const MODELLI := "res://modelli/"
const BARILE := "res://assetpack/kenney_mini-dungeon/Models/GLB format/barrel.glb"
const OssoScript := preload("res://scripts/osso.gd")
## Colori dei mantelli: ogni giocatore che entra prende il prossimo della lista.
const COLORI := [Color(0.62, 0.18, 0.16), Color(0.18, 0.38, 0.62), Color(0.2, 0.5, 0.25),
	Color(0.55, 0.3, 0.62), Color(0.72, 0.5, 0.12), Color(0.15, 0.5, 0.52)]
const ANCA := 0.85
const SPALLA := 1.42
const COLLO := 1.5

static var _prossimo_colore := 0

var target_pos := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var scava := false
var oggetto := 0            # 0 mani, 1 pala, 2 piccone, 3 secchio, 4 osso, 5 dinamite
var _primo := true
var _t := 0.0
var _passo := 0.0
var _vel := 0.0

var corpo: Node3D
var testa: Node3D
var braccio: Node3D         # braccio destro (tiene l'attrezzo)
var braccio_sx: Node3D
var gambe: Array[Node3D] = []
var attrezzi: Array[Node3D] = []
var etichetta: Label3D


func _ready() -> void:
	corpo = Node3D.new()
	corpo.name = "Corpo"
	add_child(corpo)
	var busto := _pezzo("becchino_corpo", Vector3(0, ANCA, 0), corpo)
	busto.name = "Busto"
	for sx in [-1.0, 1.0]:
		var g := _pezzo("becchino_gamba", Vector3(sx * 0.12, ANCA, 0), corpo)
		gambe.append(g)
	testa = _pezzo("becchino_testa", Vector3(0, COLLO, 0), corpo)
	braccio = _pezzo("becchino_braccio", Vector3(0.31, SPALLA, 0), corpo)
	braccio_sx = _pezzo("becchino_braccio", Vector3(-0.31, SPALLA, 0), corpo)

	# lampada da minatore sul cappuccio e fiamma della lanterna
	var lampada := SpotLight3D.new()
	lampada.light_color = Color(1.0, 0.85, 0.55)
	lampada.light_energy = 2.0
	lampada.spot_range = 10.0
	lampada.spot_angle = 30.0
	lampada.position = Vector3(0, 0.36, -0.2)
	testa.add_child(lampada)
	var fiamma := OmniLight3D.new()
	fiamma.light_color = Color(1.0, 0.62, 0.32)
	fiamma.light_energy = 1.0
	fiamma.omni_range = 6.0
	fiamma.position = Vector3(0.27, ANCA - 0.08, -0.04)
	corpo.add_child(fiamma)

	# oggetti in mano: appesi alla mano destra, puntati in avanti
	var mano := Node3D.new()
	mano.position = Vector3(0, -0.58, 0)
	mano.rotation.x = -PI / 2.0
	braccio.add_child(mano)
	attrezzi.append(Node3D.new())                                     # 0 mani
	attrezzi.append(_modello(MODELLI + "pala.glb", Vector3(0, 0.95, 0), Vector3(PI, 0, 0), 0.9))   # 1
	attrezzi.append(_modello(MODELLI + "piccone.glb", Vector3(0, -0.12, 0), Vector3.ZERO, 1.0))      # 2
	var secchio := _modello(BARILE, Vector3(-0.31, -0.25, -0.2), Vector3(-PI / 2.0, 0, 0), 0.7)    # 3
	attrezzi.append(secchio)
	attrezzi.append(Node3D.new())                                     # 4 osso (si sceglie in imposta_osso)
	attrezzi.append(_modello(MODELLI + "dinamite.glb", Vector3(0, 0.08, 0), Vector3.ZERO, 1.0))     # 5
	for a in attrezzi:
		mano.add_child(a)

	etichetta = Label3D.new()
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.no_depth_test = true
	etichetta.fixed_size = true
	etichetta.pixel_size = 0.0012
	etichetta.font_size = 28
	etichetta.outline_size = 8
	etichetta.position.y = 2.1
	add_child(etichetta)


func _pezzo(file: String, pos: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var m: Node3D = (load(MODELLI + file + ".glb") as PackedScene).instantiate()
	pivot.add_child(m)
	return pivot


func _modello(path: String, pos: Vector3, rot: Vector3, scala: float) -> Node3D:
	var n := Node3D.new()
	var m: Node3D = (load(path) as PackedScene).instantiate()
	m.position = pos
	m.rotation = rot
	m.scale = Vector3.ONE * scala
	n.add_child(m)
	return n


func imposta_nome(n: String) -> void:
	etichetta.text = n
	if not has_meta("colore"):
		set_meta("colore", _prossimo_colore)
		_colora(COLORI[_prossimo_colore % COLORI.size()])
		_prossimo_colore += 1


## Mette il colore c a tutte le parti del mantello (nei modelli sono grigie).
func _colora(c: Color) -> void:
	for mi: MeshInstance3D in corpo.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var a := mat.albedo_color
			if is_equal_approx(a.r, a.g) and is_equal_approx(a.g, a.b) and (absf(a.r - 0.5) < 0.02 or absf(a.r - 0.35) < 0.02):
				var m2 := mat.duplicate() as StandardMaterial3D
				m2.albedo_color = c if a.r > 0.4 else c.darkened(0.35)
				mi.set_surface_override_material(s, m2)


## Quale pezzo di scheletro (o la chiave) ha in mano.
func imposta_osso(parte: String) -> void:
	var holder := attrezzi[4]
	for c in holder.get_children():
		c.queue_free()
	if parte == "":
		return
	var m := OssoScript.modello(parte)
	var box := OssoScript.aabb(m)
	m.scale = Vector3.ONE * (0.6 if box.size.y > 0.6 else 0.8)
	m.position = -box.get_center() * m.scale.x + Vector3(0, -0.15, 0)
	holder.add_child(m)


## Nuovo stato ricevuto dalla rete.
func aggiorna(pos: Vector3, yaw: float, pitch: float, ogg: int, sta_scavando: bool) -> void:
	target_pos = pos
	target_yaw = yaw
	target_pitch = pitch
	oggetto = ogg
	scava = sta_scavando
	if _primo:
		_primo = false
		global_position = pos
		rotation.y = yaw


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 15.0)
	var prima := global_position
	global_position = global_position.lerp(target_pos, k)
	var v := Vector2(global_position.x - prima.x, global_position.z - prima.z).length() / maxf(delta, 0.001)
	_vel = lerpf(_vel, v, minf(delta * 8.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, k)
	testa.rotation.x = lerpf(testa.rotation.x, target_pitch * 0.6, k)
	for i in attrezzi.size():
		attrezzi[i].visible = i == oggetto
	_t += delta

	# camminata: gambe e braccio sinistro oscillano, il corpo sobbalza
	var cammina := clampf(_vel / 4.0, 0.0, 1.0)
	_passo += delta * (2.0 + _vel * 2.2)
	var s := sin(_passo) * 0.6 * cammina
	gambe[0].rotation.x = s
	gambe[1].rotation.x = -s
	braccio_sx.rotation.x = s * 0.8
	corpo.position.y = absf(cos(_passo)) * 0.04 * cammina

	# braccio destro: segue lo sguardo, colpisce quando scava, avanti quando porta qualcosa
	var porta := oggetto >= 3
	var colpo := 0.0
	if scava and oggetto < 3:
		var f := fmod(_t * 1.6, 1.0)
		colpo = -1.6 * (1.0 - f) if f < 0.7 else -1.6 * ((f - 0.7) / 0.3)
	var base := -0.9 if porta else -0.35 - s * 0.5
	braccio.rotation.x = lerpf(braccio.rotation.x, base + target_pitch * 0.5 + colpo, minf(delta * 18.0, 1.0))
	if porta:
		braccio_sx.rotation.x = lerpf(braccio_sx.rotation.x, -0.9, minf(delta * 10.0, 1.0))
