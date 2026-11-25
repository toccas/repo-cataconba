extends Node3D
## Scheletro scomponibile in 6 pezzi: Testa, Torace, BraccioDestro, BraccioSinistro,
## GambaDestra, GambaSinistra (figli del nodo Corpo, ognuno nel suo perno).
## Le animazioni "idle" e "cammina" partono solo quando lo scheletro è completo;
## se manca un pezzo resta fermo nella posa di riposo.
## Creato da tools/make_skeleton.gd. Guarda verso +Z.

const PARTI := ["Testa", "Torace", "BraccioDestro", "BraccioSinistro", "GambaDestra", "GambaSinistra"]

## Cammina (animazione "cammina") invece di stare fermo ("idle"), se è completo.
@export var camminando := false:
	set(v):
		camminando = v
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


func _ready() -> void:
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
	if completo():
		anim.play("cammina" if camminando else "idle", 0.3)
	else:
		anim.play("RESET")
		anim.advance(0.0)
		anim.stop()
