extends RigidBody3D
## Candelotto di dinamite lanciato: la miccia brucia per MICCIA secondi, poi esplode.
## L'esplosione vera (terra tolta, effetti per tutti) la decide il server in main.gd:
## qui si emette solo il segnale "esplodi".

signal esplodi(candelotto: RigidBody3D)

const MICCIA := 3.0

var t := 0.0
var esploso := false
var _ultima := Vector3.INF


## Se in un passo della fisica il candelotto attraversa qualcosa (pavimento, terra),
## lo rimette sulla superficie che stava per passare.
func _physics_process(_delta: float) -> void:
	if freeze:
		return
	var p := global_position
	if _ultima != Vector3.INF and _ultima.distance_to(p) > 0.02:
		var q := PhysicsRayQueryParameters3D.create(_ultima, p + (p - _ultima).normalized() * 0.06)
		q.exclude = [get_rid()]
		q.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and not (hit.collider is RigidBody3D):
			global_position = hit.position + hit.normal * 0.07
			linear_velocity = linear_velocity.slide(hit.normal) * 0.3
			p = global_position
	# rete di sicurezza: mai sotto il pavimento della catacomba
	if p.y < 1.95:
		global_position.y = 2.08
		linear_velocity = Vector3.ZERO
		p = global_position
	_ultima = p


func _process(delta: float) -> void:
	t += delta
	# la miccia sfrigola: la luce tremola e diventa più forte verso la fine
	var luce := $Luce as OmniLight3D
	luce.light_energy = (0.6 + 0.8 * randf()) * (1.0 + t / MICCIA)
	if t >= MICCIA and not esploso:
		esploso = true
		esplodi.emit(self)
