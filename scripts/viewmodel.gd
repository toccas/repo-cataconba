extends Node3D
## Attrezzi in mano (mani, pala, piccone) e le loro animazioni di scavo.
## Va messo come figlio della camera, nella sua origine.
##
## Ogni colpo è una sequenza di pose chiave (tempo 0..1, spostamento, rotazione, curva).
## Il momento del colpo è "impatto": lì step() restituisce true (suono, schegge, scossa).
## Le mani scavano alternate: un colpo la destra, il successivo la sinistra.

const MANO := "res://modelli/mano.glb"
const PUGNO := "res://modelli/pugno.glb"
const PICCONE := "res://modelli/piccone.glb"
const PALA := "res://modelli/pala.glb"
const BOTTE := "res://assetpack/kenney_mini-dungeon/Models/GLB format/barrel.glb"

## Indice del modello "secchio in mano" (dopo mani, pala, piccone).
const SECCHIO := 3
## Indice del modello "osso in mano".
const OSSO := 4
const OssoScript := preload("res://scripts/osso.gd")

## Posa di riposo della mano destra (la sinistra è speculare).
const HAND_POS := Vector3(0.15, -0.18, -0.34)
const HAND_ROT := Vector3(0.45, 0.3, -0.15)
## Posa di riposo di pala e piccone.
const TOOL_POS := Vector3(0.30, -0.34, -0.48)
const TOOL_ROT := Vector3(-0.35, 0.35, 0.0)

## Pose chiave: [tempo, spostamento, rotazione, curva per arrivarci].
## Curve: "in" accelera (colpi), "out" rallenta (cariche), "smooth" morbida.
const ANIM := [
	{   # mani: alza la mano, artiglia la terra, tira indietro
		"impatto": 0.55,
		"pose": [
			[0.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
			[0.35, Vector3(0.0, 0.06, 0.04), Vector3(0.45, 0.0, -0.05), "out"],
			[0.55, Vector3(-0.03, -0.07, -0.16), Vector3(-0.95, 0.0, 0.05), "in"],
			[0.80, Vector3(0.0, -0.10, 0.04), Vector3(-0.55, 0.0, 0.0), "smooth"],
			[1.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
		],
	},
	{   # pala: carica, affonda, fa leva e lancia la terra
		"impatto": 0.5,
		"pose": [
			[0.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
			[0.30, Vector3(0.0, 0.07, 0.10), Vector3(0.30, 0.0, 0.05), "out"],
			[0.50, Vector3(-0.03, -0.13, -0.24), Vector3(-0.45, 0.0, 0.0), "in"],
			[0.62, Vector3(-0.02, -0.11, -0.20), Vector3(-0.25, 0.05, 0.10), "out"],
			[0.80, Vector3(0.02, 0.06, -0.06), Vector3(0.45, 0.15, 0.45), "smooth"],
			[1.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
		],
	},
	{   # piccone: carica sopra la spalla, attimo sospeso, colpo, rimbalzo
		"impatto": 0.62,
		"pose": [
			[0.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
			[0.50, Vector3(0.03, 0.13, 0.12), Vector3(1.05, 0.10, 0.25), "out"],
			[0.56, Vector3(0.035, 0.145, 0.13), Vector3(1.12, 0.11, 0.27), "smooth"],
			[0.62, Vector3(-0.02, -0.07, -0.20), Vector3(-0.80, -0.05, -0.05), "in"],
			[0.70, Vector3(-0.015, -0.05, -0.16), Vector3(-0.62, -0.04, -0.04), "out"],
			[1.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
		],
	},
	{   # secchio in mano: non scava
		"impatto": 2.0,
		"pose": [
			[0.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
			[1.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
		],
	},
	{   # osso in mano: non scava
		"impatto": 2.0,
		"pose": [
			[0.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
			[1.0, Vector3.ZERO, Vector3.ZERO, "smooth"],
		],
	},
]

var models := []
var rest_pos := []     # posa di riposo di ogni modello, letta dalla scena
var rest_rot := []
var hands := []        # [destra, sinistra]
var cur := -1
var phase := 0.0
var weight := 0.0
var switch_t := 1.0
var bob_t := 0.0
var idle_t := 0.0
var stroke := 0        # colpi fatti: con le mani decide quale mano scava
var kick := 0.0        # tremolio dopo il colpo
var sway := Vector2.ZERO
var last_cam_rot := Vector3.ZERO


func _ready() -> void:
	position = Vector3.ZERO
	models = [$Mani, $Pala, $Piccone, $Secchio, $Osso]
	hands = [$Mani/ManoDestra, $Mani/ManoSinistra]
	for m in models:
		m.visible = false
		rest_pos.append(m.position)
		rest_rot.append(m.rotation)
	# gli attrezzi in mano non fanno ombra (sarebbe strana sulla terra davanti)
	for mi in find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	last_cam_rot = _cam_rot()


## Mette in mano il pezzo di scheletro indicato (Testa, Torace, ...).
func set_bone(parte: String) -> void:
	var holder: Node3D = $Osso/Pezzo
	for c in holder.get_children():
		c.queue_free()
	var m := OssoScript.modello(parte)
	holder.add_child(m)
	var box := OssoScript.aabb(m)
	# i pezzi lunghi (gambe, braccia) si tengono di traverso
	var s := 0.55 if box.size.y > 0.6 else 0.45
	m.scale = Vector3.ONE * s
	m.position = -box.get_center() * s
	holder.rotation = Vector3(0.2, 0.0, PI / 2.0 - 0.25) if box.size.y > 0.6 else Vector3(-0.3, PI, 0.0)
	for mi in m.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_tool(i: int) -> void:
	if i == cur:
		return
	cur = i
	switch_t = 0.0
	phase = 0.0
	for k in models.size():
		models[k].visible = k == i


## Avanza l'animazione. Restituisce true nel momento del colpo.
func step(delta: float, digging: bool, period: float, move_speed: float) -> bool:
	var anim: Dictionary = ANIM[cur]
	var impact := false
	if digging:
		weight = 1.0
		var prev := phase
		phase += delta / period
		if prev < anim["impatto"] and phase >= anim["impatto"]:
			impact = true
			kick = 1.0
		if phase >= 1.0:
			phase -= 1.0
			stroke += 1
	else:
		weight = move_toward(weight, 0.0, delta * 5.0)
		if weight <= 0.0:
			phase = 0.0

	var pose := _sample(anim["pose"], phase)
	var off_p: Vector3 = pose[0] * weight
	var off_r: Vector3 = pose[1] * weight

	# tremolio dopo il colpo
	kick = move_toward(kick, 0.0, delta * 7.0)
	var k := kick * kick
	var shake_r := Vector3(sin(idle_t * 95.0), cos(idle_t * 83.0), sin(idle_t * 71.0)) * 0.035 * k

	# respiro da fermo e passo quando si cammina
	idle_t += delta
	var still := 1.0 - weight
	var breath := Vector3(0.0, sin(idle_t * 1.7) * 0.006, 0.0) * still
	if move_speed > 0.1:
		bob_t += delta * move_speed * 2.4
	var bob := Vector3(cos(bob_t) * 0.014, absf(sin(bob_t)) * 0.018, 0.0) * (1.0 - weight * 0.7)

	# oscillazione quando si muove la visuale (gli attrezzi restano un po' indietro)
	var cr := _cam_rot()
	var d := Vector2(angle_difference(last_cam_rot.y, cr.y), angle_difference(last_cam_rot.x, cr.x))
	last_cam_rot = cr
	sway = sway.lerp((d / maxf(delta, 0.001) * 0.012).limit_length(0.12), minf(delta * 10.0, 1.0))
	var sway_p := Vector3(-sway.x * 0.25, -sway.y * 0.25, 0.0)
	var sway_r := Vector3(sway.y, sway.x, sway.x * 0.5)

	# cambio attrezzo: scende e risale
	switch_t = minf(switch_t + delta * 4.0, 1.0)
	var lower := (1.0 - _ease("out", switch_t)) * 0.35
	var lower_p := Vector3(0.0, -lower, 0.0)
	var lower_r := Vector3(-lower * 1.5, 0.0, 0.0)

	var extra_p := breath + bob + sway_p + lower_p
	var extra_r := sway_r + lower_r + shake_r + Vector3(0.0, 0.0, cos(bob_t) * 0.012)

	if cur == 0:
		# mani alternate: una scava, l'altra si tiene un po' indietro
		var active := stroke % 2
		for h in 2:
			var side := 1.0 if h == 0 else -1.0
			var p := Vector3.ZERO
			var r := Vector3.ZERO
			if h == active:
				p = off_p
				r = off_r + shake_r
			else:
				p = Vector3(0.0, -0.025, 0.03) * weight
			p += extra_p
			r += extra_r - shake_r
			hands[h].transform = _hand_xf(HAND_POS + p, HAND_ROT + r, side)
	else:
		if cur == SECCHIO:
			# il secchio pesa: dondola di più camminando
			extra_p += bob * 0.8
		models[cur].position = rest_pos[cur] + off_p + extra_p
		models[cur].rotation = rest_rot[cur] + off_r + extra_r
	return impact


## Posa interpolata al tempo t: [spostamento, rotazione].
func _sample(keys: Array, t: float) -> Array:
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var u := _ease(b[3], (t - a[0]) / maxf(b[0] - a[0], 0.0001))
			return [(a[1] as Vector3).lerp(b[1], u), (a[2] as Vector3).lerp(b[2], u)]
	return [Vector3.ZERO, Vector3.ZERO]


func _ease(kind: String, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match kind:
		"in":
			return x * x * x
		"out":
			return 1.0 - pow(1.0 - x, 3.0)
	return x * x * (3.0 - 2.0 * x)


## Trasformazione di una mano: la sinistra è la destra specchiata sull'asse X.
## Si imposta la matrice intera perché, con la scala negativa, rotation e scale
## separati verrebbero reinterpretati da Godot come una rotazione di 180 gradi.
func _hand_xf(p: Vector3, r: Vector3, side: float) -> Transform3D:
	var b := Basis.from_euler(Vector3(r.x, r.y * side, r.z * side)) * Basis.from_scale(Vector3(side, 1.0, 1.0))
	return Transform3D(b, Vector3(p.x * side, p.y, p.z))


func _cam_rot() -> Vector3:
	var p := get_parent() as Node3D
	return p.global_rotation if p and p.is_inside_tree() else Vector3.ZERO


# --- costruzione della scena ---------------------------------------------------
## Usato solo da tools/build_scenes.gd per salvare player.tscn.

func build_nodes() -> void:
	var mani := Node3D.new()
	mani.name = "Mani"
	add_child(mani)
	for h in 2:
		var side := 1.0 if h == 0 else -1.0
		var hand := _inst(MANO, "ManoDestra" if h == 0 else "ManoSinistra")
		hand.transform = _hand_xf(HAND_POS, HAND_ROT, side)
		mani.add_child(hand)

	var pala := Node3D.new()
	pala.name = "Pala"
	pala.position = TOOL_POS
	pala.rotation = TOOL_ROT
	add_child(pala)
	var shovel := _inst(PALA, "Modello")
	shovel.rotation = Vector3(PI, 0, 0)   # lama in alto, come gli altri attrezzi
	shovel.scale = Vector3.ONE * 0.75
	shovel.position = Vector3(0, 0.55, 0.0)
	pala.add_child(shovel)
	var fist := _inst(PUGNO, "Mano")
	fist.position = Vector3(0, 0.02, 0.03)
	fist.rotation = Vector3(0, 0, PI / 2)
	pala.add_child(fist)

	var pick := Node3D.new()
	pick.name = "Piccone"
	pick.position = TOOL_POS
	pick.rotation = TOOL_ROT
	add_child(pick)
	pick.add_child(_inst(PICCONE, "Modello"))
	var fist2 := _inst(PUGNO, "Mano")
	fist2.position = Vector3(0, -0.07, 0)
	fist2.rotation = Vector3(0, 0, PI / 2)
	pick.add_child(fist2)

	# secchio pieno tenuto con due mani, in basso al centro
	var bucket := Node3D.new()
	bucket.name = "Secchio"
	bucket.position = Vector3(0.0, -0.44, -0.62)
	bucket.rotation = Vector3(0.25, 0.0, 0.0)
	add_child(bucket)
	var barrel := _inst(BOTTE, "Modello")
	barrel.scale = Vector3.ONE * 0.7
	bucket.add_child(barrel)
	bucket.add_child(dirt_disc())
	for h in 2:
		var side := 1.0 if h == 0 else -1.0
		var grip := _inst(PUGNO, "ManoDestra" if h == 0 else "ManoSinistra")
		grip.transform = _hand_xf(Vector3(0.2, 0.17, 0.02), Vector3(0.0, 0.0, PI / 2), side)
		bucket.add_child(grip)

	# osso (pezzo di scheletro) tenuto con due mani; il modello si mette con set_bone()
	var bone := Node3D.new()
	bone.name = "Osso"
	bone.position = Vector3(0.0, -0.33, -0.58)
	add_child(bone)
	var piece := Node3D.new()
	piece.name = "Pezzo"
	bone.add_child(piece)
	for h in 2:
		var side := 1.0 if h == 0 else -1.0
		var grip := _inst(PUGNO, "ManoDestra" if h == 0 else "ManoSinistra")
		grip.transform = _hand_xf(Vector3(0.16, -0.05, 0.03), Vector3(0.0, 0.0, PI / 2), side)
		bone.add_child(grip)


## Mucchietto di terra che sporge dalla botte (per far vedere che il secchio è pieno).
static func dirt_disc() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "Terra"
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.15
	c.height = 0.07
	c.radial_segments = 7
	c.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.36, 0.22)
	mat.roughness = 1.0
	c.material = mat
	m.mesh = c
	m.position = Vector3(0, 0.32, 0)
	return m


func _inst(path: String, node_name: String) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.name = node_name
	return n
