extends RigidBody3D
## Un pezzo di scheletro (osso) da trovare nella terra, raccogliere (E), lanciare
## (tasto destro) e posare nella tomba dello spawn.
## Sepolto nella terra è bloccato (freeze); lanciato cade con la fisica.
## Il modello e la collisione vengono dal pezzo dello scheletro scelto in "parte".

const MODELLI := {
	"Testa": "res://modelli/scheletro/testa.glb",
	"Torace": "res://modelli/scheletro/torace.glb",
	"BraccioDestro": "res://modelli/scheletro/braccio.glb",
	"BraccioSinistro": "res://modelli/scheletro/braccio.glb",
	"GambaDestra": "res://modelli/scheletro/gamba.glb",
	"GambaSinistra": "res://modelli/scheletro/gamba.glb",
}
const NOMI := {
	"Testa": "Testa", "Torace": "Torace", "BraccioDestro": "Braccio destro",
	"BraccioSinistro": "Braccio sinistro", "GambaDestra": "Gamba destra", "GambaSinistra": "Gamba sinistra",
}

## Quale pezzo è (Testa, Torace, BraccioDestro, BraccioSinistro, GambaDestra, GambaSinistra).
@export_enum("Testa", "Torace", "BraccioDestro", "BraccioSinistro", "GambaDestra", "GambaSinistra")
var parte := "Testa"


func _ready() -> void:
	var m := modello(parte)
	add_child(m)
	var box := aabb(m)
	m.position = -box.get_center()
	var shape := BoxShape3D.new()
	shape.size = box.size
	($Collisione as CollisionShape3D).shape = shape


## Nome da mostrare a schermo.
static func nome(p: String) -> String:
	return NOMI.get(p, p)


## Il modello del pezzo (con l'origine nel suo perno).
static func modello(p: String) -> Node3D:
	var n: Node3D = (load(MODELLI[p]) as PackedScene).instantiate()
	n.name = "Modello"
	return n


## Ingombro delle mesh di un modello, nel suo spazio.
static func aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var n: Node = mi
		while n != root:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		box = t * mi.get_aabb() if first else box.merge(t * mi.get_aabb())
		first = false
	return box
