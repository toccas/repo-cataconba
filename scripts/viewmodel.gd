extends Node3D
## Attrezzo in mano (forme provvisorie) e la sua animazione di scavo.
## Va messo come figlio della camera.

const REST_POS := Vector3(0.30, -0.34, -0.48)
const REST_ROT := Vector3(-0.35, 0.35, 0.0)
const IMPACT := 0.7   # punto del colpo nel ciclo 0..1

## Per ogni attrezzo: quanto si alza in carica, quanto scende nel colpo, quanto spinge in avanti.
const SWING := [
	{"su": 0.15, "giu": -0.35, "spinta": 0.28},   # mani
	{"su": 0.45, "giu": -0.75, "spinta": 0.12},   # pala
	{"su": 0.80, "giu": -0.95, "spinta": 0.08},   # piccone
]

var models := []
var cur := -1
var phase := 0.0
var weight := 0.0
var switch_t := 1.0
var bob_t := 0.0


func _ready() -> void:
	position = REST_POS
	models = [$Mani, $Pala, $Piccone]
	for m in models:
		m.visible = false


## Crea i modelli degli attrezzi. Usato solo da tools/build_scenes.gd per salvare la scena.
func build_nodes() -> void:
	position = REST_POS
	rotation = REST_ROT
	var names := ["Mani", "Pala", "Piccone"]
	var made := [_make_hands(), _make_shovel(), _make_pick()]
	for k in 3:
		made[k].name = names[k]
		add_child(made[k])
		for c in made[k].get_children():
			if c is MeshInstance3D:
				c.name = c.mesh.get_class().replace("Mesh", "") + str(c.get_index())


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
	var impact := false
	weight = move_toward(weight, 1.0 if digging else 0.0, delta * 6.0)
	if digging:
		var prev := phase
		phase += delta / period
		if prev < IMPACT and phase >= IMPACT:
			impact = true
		if phase >= 1.0:
			phase -= 1.0
	elif weight <= 0.0:
		phase = 0.0

	var s: Dictionary = SWING[cur]
	var angle := 0.0
	var push := 0.0
	if phase < 0.55:
		# carica lenta
		var k := _ease_out(phase / 0.55)
		angle = s["su"] * k
	elif phase < IMPACT:
		# colpo veloce
		var k := _ease_in((phase - 0.55) / (IMPACT - 0.55))
		angle = lerpf(s["su"], s["giu"], k)
		push = s["spinta"] * k
	else:
		# ritorno
		var k := _ease_out((phase - IMPACT) / (1.0 - IMPACT))
		angle = lerpf(s["giu"], 0.0, k)
		push = s["spinta"] * (1.0 - k)
	angle *= weight
	push *= weight

	switch_t = minf(switch_t + delta * 4.0, 1.0)
	var lower := (1.0 - _ease_out(switch_t)) * 0.35

	if move_speed > 0.1:
		bob_t += delta * move_speed * 2.4
	var bob := Vector3(cos(bob_t) * 0.012, absf(sin(bob_t)) * 0.016, 0.0) * (1.0 - weight)

	position = REST_POS + Vector3(0.0, -lower, -push) + bob
	rotation = REST_ROT + Vector3(angle, 0.0, 0.0)
	return impact


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func _ease_in(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.0)


# --- modelli provvisori -------------------------------------------------

func _mat(c: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.5 if metal > 0.0 else 0.9
	return m


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_hands() -> Node3D:
	var root := Node3D.new()
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 0.045
	sleeve.bottom_radius = 0.055
	sleeve.height = 0.32
	root.add_child(_part(sleeve, _mat(Color(0.12, 0.10, 0.14)), Vector3(0, 0, 0.12), Vector3(PI / 2, 0, 0)))
	var fist := BoxMesh.new()
	fist.size = Vector3(0.085, 0.08, 0.11)
	root.add_child(_part(fist, _mat(Color(0.62, 0.50, 0.42)), Vector3(0, 0.005, -0.08)))
	return root


## Pala: il modello "shovel" del Graveyard Kit, capovolto (lama in alto, come gli altri attrezzi).
func _make_shovel() -> Node3D:
	var root := Node3D.new()
	var model: Node3D = (load("res://assetpack/kenney_graveyard-kit_5.0/Models/GLB format/shovel.glb") as PackedScene).instantiate()
	model.name = "Modello"
	model.rotation = Vector3(PI, 0, 0)
	model.scale = Vector3.ONE * 1.1
	model.position = Vector3(0, 0.55, 0.03)
	root.add_child(model)
	return root


func _make_pick() -> Node3D:
	var root := Node3D.new()
	var handle := CylinderMesh.new()
	handle.top_radius = 0.018
	handle.bottom_radius = 0.02
	handle.height = 0.65
	root.add_child(_part(handle, _mat(Color(0.30, 0.19, 0.10)), Vector3(0, 0.18, 0)))
	var iron := _mat(Color(0.32, 0.32, 0.35), 0.7)
	var head := BoxMesh.new()
	head.size = Vector3(0.045, 0.05, 0.42)
	root.add_child(_part(head, iron, Vector3(0, 0.5, -0.04)))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.045, 0.1, 0.05)
	root.add_child(_part(tip, iron, Vector3(0, 0.5, -0.30), Vector3(-PI / 2, 0, 0)))
	return root
