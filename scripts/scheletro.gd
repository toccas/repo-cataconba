extends Node3D
## Scheletro scomponibile in 6 pezzi: Testa, Torace, BraccioDestro, BraccioSinistro,
## GambaDestra, GambaSinistra (figli del nodo Corpo, ognuno nel suo perno).
## Braccia e gambe hanno i sotto-perni Avambraccio e Stinco (gomito e ginocchio).
## Le animazioni "idle" e "cammina" partono solo quando lo scheletro è completo;
## se manca un pezzo resta fermo nella posa di riposo.
## alzati() fa la sequenza di risveglio e uscita dalla tomba.
## Creato da tools/make_skeleton.gd. Guarda verso +Z.

const PARTI := ["Testa", "Torace", "BraccioDestro", "BraccioSinistro", "GambaDestra", "GambaSinistra"]
const ANCA := 0.9

## Azione dello scheletro lavoratore: "idle", "cammina", "porta" (cammina con un
## secchio in mano) o "scava". Ha la precedenza su "camminando".
var azione := "":
	set(v):
		if v == azione:
			return
		azione = v
		if is_node_ready():
			_aggiorna()

## Cammina (animazione "cammina") invece di stare fermo ("idle"), se è completo.
@export var camminando := false:
	set(v):
		camminando = v
		if is_node_ready():
			_aggiorna()

## Sveglio: occhi accesi quando è completo. Lo scheletro nella tomba dorme.
@export var sveglio := true:
	set(v):
		sveglio = v
		if is_node_ready():
			_aggiorna()

## Pezzi presenti all'avvio (per provare dall'Inspector).
@export var testa := true
@export var torace := true
@export var braccio_destro := true
@export var braccio_sinistro := true
@export var gamba_destra := true
@export var gamba_sinistra := true

@onready var anim: AnimationPlayer = $Animazioni
@onready var occhi: Node3D = $Corpo/Testa/Occhi
var eye_mat: StandardMaterial3D
var rising := false


func _ready() -> void:
	# materiale degli occhi proprio di questo scheletro (si accende e si spegne da solo)
	eye_mat = (occhi.get_node("OcchioDestro") as MeshInstance3D).mesh.material.duplicate()
	for e in [occhi.get_node("OcchioDestro"), occhi.get_node("OcchioSinistro")]:
		(e as MeshInstance3D).material_override = eye_mat
	var start := [testa, torace, braccio_destro, braccio_sinistro, gamba_destra, gamba_sinistra]
	for i in PARTI.size():
		_parte(PARTI[i]).visible = start[i]
	_aggiorna()


func _parte(nome: String) -> Node3D:
	return get_node("Corpo/" + nome)


func ha_parte(nome: String) -> bool:
	return _parte(nome).visible


func completo() -> bool:
	for p in PARTI:
		if not ha_parte(p):
			return false
	return true


## Stacca un pezzo (lo nasconde). Restituisce false se mancava già.
func togli_parte(nome: String) -> bool:
	if not ha_parte(nome):
		return false
	_parte(nome).visible = false
	_aggiorna()
	return true


## Rimette un pezzo. Restituisce false se c'era già.
func metti_parte(nome: String) -> bool:
	if ha_parte(nome):
		return false
	_parte(nome).visible = true
	_aggiorna()
	return true


func _aggiorna() -> void:
	if rising:
		return
	_eyes(1.0 if sveglio and completo() else 0.0)
	if completo() and sveglio:
		var a := azione if azione in ["idle", "cammina", "porta", "porta_fermo", "scava"] else ("cammina" if camminando else "idle")
		anim.play(a, 0.25)
	else:
		anim.play("RESET")
		anim.advance(0.0)
		anim.stop()


## Mostra o nasconde il secchio tenuto davanti al petto.
func porta_secchio(on: bool) -> void:
	var s := get_node_or_null("Corpo/SecchioInMano") as Node3D
	if s:
		s.visible = on


## Luminosità degli occhi (0 = spenti).
func _eyes(level: float) -> void:
	occhi.visible = level > 0.01
	eye_mat.emission_energy_multiplier = 4.0 * level
	eye_mat.albedo_color = Color(0.5, 1.0, 0.85).lerp(Color.BLACK, 1.0 - level)
	(occhi.get_node("Luce") as OmniLight3D).light_energy = 0.6 * level


## Trasformazione dello scheletro sdraiato sulla schiena, con l'anca in hip e la testa
## verso la direzione -Z ruotata di yaw (yaw = PI/2: testa verso -X).
static func lying_transform(hip: Vector3, yaw: float) -> Transform3D:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2.0)
	return Transform3D(b, hip - b * Vector3(0, ANCA, 0))


# --- risveglio e uscita dalla tomba ----------------------------------------------

## Sequenza di risveglio: lo scheletro (sdraiato con l'anca in hip, testa verso yaw)
## apre gli occhi, si mette seduto, si guarda intorno, salta fuori dalla tomba e
## atterra in dest (piedi) girato verso dest_yaw. Poi parte l'idle.
## Le posizioni sono nello spazio del nodo genitore.
func alzati(hip: Vector3, yaw: float, dest: Vector3, dest_yaw: float) -> void:
	rising = true
	anim.stop()
	var dest_hip := dest + Vector3(0, ANCA, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float): _rise_pose(t, hip, yaw, dest_hip, dest_yaw), 0.0, RISE_TIME, RISE_TIME)
	await tw.finished
	rising = false
	_aggiorna()


const RISE_TIME := 4.4


## Posa della sequenza al tempo t (secondi).
func _rise_pose(t: float, hip: Vector3, yaw: float, dest_hip: Vector3, dest_yaw: float) -> void:
	var phi := -PI / 2.0     # inclinazione del corpo: -90° sdraiato, 0 in piedi
	var y := yaw
	var h := hip
	var legs := 0.0
	var knees := 0.0
	var arms := Vector3(0, 0, 0.1)   # x avanti/indietro, z apertura
	var elbows := -0.15
	var head := Vector3.ZERO
	var body_y := 0.0
	var eyes := 0.0

	if t < 0.9:
		# risveglio: gli occhi tremolano e si accendono, le dita fremono
		var u := t / 0.9
		eyes = clampf((u - 0.2) / 0.6, 0.0, 1.0) * (0.6 + 0.4 * absf(sin(t * 37.0)))
		elbows = -0.15 - 0.25 * absf(sin(t * 19.0)) * u
		head = Vector3(-0.15 * u, 0.15 * sin(t * 9.0) * u, 0)
	elif t < 1.9:
		# si mette seduto (con un piccolo scatto oltre la verticale)
		var u := _back((t - 0.9) / 1.0)
		eyes = 1.0
		phi = lerpf(-PI / 2.0, 0.08, u)
		legs = -(phi + PI / 2.0)          # le gambe restano distese nella tomba
		arms = Vector3(lerpf(0.0, -0.7, u), 0, 0.1)
		elbows = lerpf(-0.15, -0.5, u)
		head = Vector3(lerpf(-0.15, 0.2, u), 0, 0)
	elif t < 2.9:
		# seduto, si guarda intorno
		var u := (t - 1.9) / 1.0
		eyes = 1.0
		phi = 0.08
		legs = -(phi + PI / 2.0)
		arms = Vector3(lerpf(-0.7, -0.35, u), 0, 0.15)
		elbows = -0.5
		head = Vector3(0.05, 0.6 * sin(u * TAU), 0.1 * sin(u * TAU))
	elif t < 3.9:
		# salta fuori: gambe raccolte, braccia in alto, arco verso la destinazione
		var u := (t - 2.9) / 1.0
		var s := u * u * (3.0 - 2.0 * u)
		var arc := sin(PI * u)
		eyes = 1.0
		var top := Vector3((hip.x + dest_hip.x) / 2.0, maxf(hip.y, dest_hip.y) + 0.7, (hip.z + dest_hip.z) / 2.0)
		h = hip.lerp(top, s).lerp(top.lerp(dest_hip, s), s)
		y = lerp_angle(yaw, dest_yaw, s)
		phi = 0.08 + 0.3 * arc
		legs = lerpf(-(0.08 + PI / 2.0), 0.0, s) - 0.5 * arc
		knees = 1.4 * arc
		arms = Vector3(-0.35 - 1.6 * arc, 0, 0.15 + 0.4 * arc)
		elbows = -0.5 - 0.4 * arc
		head = Vector3(-0.2 * arc, 0, 0)
	else:
		# atterraggio: ginocchia piegate, corpo che si abbassa e torna su
		var u := clampf((t - 3.9) / 0.5, 0.0, 1.0)
		var arc := sin(PI * u)
		eyes = 1.0
		h = dest_hip
		y = dest_yaw
		phi = 0.2 * arc
		body_y = -0.14 * arc
		# gambe e ginocchia piegate quanto basta a tenere i piedi a terra
		legs = -0.6 * arc
		knees = 1.2 * arc
		arms = Vector3(-0.2 * arc, 0, 0.1 + 0.5 * arc)
		elbows = -0.15 - 0.3 * arc
		head = Vector3(0.15 * arc, 0, 0)

	var b := Basis(Vector3.UP, y) * Basis(Vector3.RIGHT, phi)
	transform = Transform3D(b, h - b * Vector3(0, ANCA, 0))
	for side in ["Destra", "Sinistra"]:
		(get_node("Corpo/Gamba" + side) as Node3D).rotation = Vector3(legs, 0, 0)
		(get_node("Corpo/Gamba%s/Stinco" % side) as Node3D).rotation = Vector3(knees, 0, 0)
	$Corpo/BraccioDestro.rotation = Vector3(arms.x, 0, -arms.z)
	$Corpo/BraccioSinistro.rotation = Vector3(arms.x, 0, arms.z)
	for side in ["Destro", "Sinistro"]:
		(get_node("Corpo/Braccio%s/Avambraccio" % side) as Node3D).rotation = Vector3(elbows, 0, 0)
	$Corpo/Testa.rotation = head
	$Corpo/Testa/Mascella.rotation = Vector3.ZERO
	$Corpo.position = Vector3(0, body_y, 0)
	$Corpo/Torace.rotation = Vector3.ZERO
	_eyes(eyes)


## Curva con un piccolo rimbalzo oltre la fine (ease out back).
func _back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c := 1.4
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)
