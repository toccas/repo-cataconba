extends Node3D
## Un altro giocatore della partita online, visto da qui: un corpo semplice col
## nome sopra la testa, la sua fiamma, l'attrezzo o il secchio in mano.
## Riceve posizione e stato ~20 volte al secondo (main.gd) e li segue morbidamente.

const BARILE := "res://assetpack/kenney_mini-dungeon/Models/GLB format/barrel.glb"

var target_pos := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var scava := false
var oggetto := 0            # 0 mani, 1 pala, 2 piccone, 3 secchio, 4 osso
var _primo := true
var _t := 0.0

var testa: Node3D
var braccio: Node3D
var attrezzi: Array[Node3D] = []
var etichetta: Label3D


func _ready() -> void:
	var stoffa := _mat(Color(0.22, 0.17, 0.13))
	var pelle := _mat(Color(0.78, 0.62, 0.48))
	var corpo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.35
	cap.material = stoffa
	corpo.mesh = cap
	corpo.position.y = 0.68
	add_child(corpo)

	testa = Node3D.new()
	testa.position.y = 1.5
	add_child(testa)
	var sfera := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.19
	sm.height = 0.38
	sm.material = pelle
	sfera.mesh = sm
	testa.add_child(sfera)
	var cappuccio := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.23
	cm.height = 0.3
	cm.material = stoffa
	cappuccio.mesh = cm
	cappuccio.position = Vector3(0, 0.17, 0.03)
	testa.add_child(cappuccio)
	for x in [-0.07, 0.07]:
		var occhio := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.03
		om.height = 0.06
		om.material = _mat(Color(0.05, 0.05, 0.05))
		occhio.mesh = om
		occhio.position = Vector3(x, 0.02, -0.17)
		testa.add_child(occhio)

	var fiamma := OmniLight3D.new()
	fiamma.light_color = Color(1.0, 0.62, 0.32)
	fiamma.light_energy = 1.2
	fiamma.omni_range = 8.0
	fiamma.position = Vector3(-0.35, 1.35, -0.3)
	add_child(fiamma)

	braccio = Node3D.new()
	braccio.position = Vector3(0.3, 1.2, -0.15)
	add_child(braccio)
	# 0 mani (niente), 1 pala, 2 piccone, 3 secchio, 4 osso
	attrezzi.append(Node3D.new())
	attrezzi.append(_attrezzo(Color(0.45, 0.45, 0.48), Vector3(0.22, 0.03, 0.3)))
	attrezzi.append(_attrezzo(Color(0.35, 0.36, 0.4), Vector3(0.5, 0.06, 0.06)))
	var secchio := Node3D.new()
	var barile: Node3D = (load(BARILE) as PackedScene).instantiate()
	barile.scale = Vector3.ONE * 0.7
	barile.position = Vector3(-0.3, -0.35, -0.25)
	secchio.add_child(barile)
	attrezzi.append(secchio)
	attrezzi.append(_attrezzo(Color(0.9, 0.86, 0.76), Vector3(0.12, 0.12, 0.3)))
	for a in attrezzi:
		braccio.add_child(a)

	etichetta = Label3D.new()
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.no_depth_test = true
	etichetta.fixed_size = true
	etichetta.pixel_size = 0.0012
	etichetta.font_size = 28
	etichetta.outline_size = 8
	etichetta.position.y = 2.05
	add_child(etichetta)


func imposta_nome(n: String) -> void:
	etichetta.text = n


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
	global_position = global_position.lerp(target_pos, k)
	rotation.y = lerp_angle(rotation.y, target_yaw, k)
	testa.rotation.x = lerpf(testa.rotation.x, target_pitch, k)
	for i in attrezzi.size():
		attrezzi[i].visible = i == oggetto
	_t += delta
	var colpo := sin(_t * 14.0) * 0.6 if scava and oggetto < 3 else 0.0
	braccio.rotation.x = target_pitch * 0.7 + colpo


func _attrezzo(c: Color, size: Vector3) -> Node3D:
	var n := Node3D.new()
	var manico := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.04, 0.04, 0.7)
	mm.material = _mat(Color(0.45, 0.3, 0.18))
	manico.mesh = mm
	manico.position.z = -0.3
	n.add_child(manico)
	var testa_attrezzo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(c)
	testa_attrezzo.mesh = bm
	testa_attrezzo.position.z = -0.65
	n.add_child(testa_attrezzo)
	return n


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m
