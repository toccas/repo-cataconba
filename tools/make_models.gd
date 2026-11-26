extends SceneTree
## Crea i modelli low-poly delle mani e del piccone, nello stile dei pack Kenney
## (forme squadrate con spigoli smussati, colori pieni, ombreggiatura piatta:
## vedi tools/low_poly.gd),
## e li salva come GLB in res://modelli/.
## Uso: godot --headless --path . --script res://tools/make_models.gd

const OUT := "res://modelli/"

const PELLE := Color(0.93, 0.71, 0.55)
const PELLE_SCURA := Color(0.80, 0.56, 0.42)
const MANICA := Color(0.26, 0.23, 0.38)
const POLSINO := Color(0.42, 0.37, 0.56)
const LEGNO := Color(0.62, 0.40, 0.23)
const LEGNO_SCURO := Color(0.45, 0.27, 0.15)
const CUOIO := Color(0.30, 0.17, 0.11)
const FERRO := Color(0.36, 0.38, 0.45)
const ACCIAIO := Color(0.64, 0.68, 0.75)
const ACCIAIO_CHIARO := Color(0.82, 0.85, 0.90)
const LEGNO_CHIARO := Color(0.70, 0.48, 0.28)
const CORDA := Color(0.66, 0.55, 0.36)
const PIETRA := Color(0.55, 0.52, 0.47)
const ROSSO := Color(0.72, 0.16, 0.10)
const ORO := Color(0.95, 0.74, 0.24)
const CERAMICA := Color(0.42, 0.52, 0.62)
const VETRO := Color(0.33, 0.55, 0.36)
const SACCO := Color(0.74, 0.64, 0.44)
## Colore del mantello dei giocatori: giocatore_remoto.gd lo sostituisce col colore di ognuno.
const MANTELLO := Color(0.5, 0.5, 0.5)
const MANTELLO_SCURO := Color(0.35, 0.35, 0.35)
const PANTALONI := Color(0.24, 0.2, 0.18)
const BARBA := Color(0.36, 0.24, 0.16)
const LUCE := Color(1.0, 0.85, 0.45)

const LowPoly := preload("res://tools/low_poly.gd")

var lp := LowPoly.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_hand(false)
	lp.save_glb(OUT + "mano.glb", "mano", [FERRO, ACCIAIO, ACCIAIO_CHIARO])
	_hand(true)
	lp.save_glb(OUT + "pugno.glb", "pugno", [FERRO, ACCIAIO, ACCIAIO_CHIARO])
	_pickaxe()
	lp.save_glb(OUT + "piccone.glb", "piccone", [FERRO, ACCIAIO, ACCIAIO_CHIARO])
	_lift_frame()
	lp.save_glb(OUT + "montacarichi_castello.glb", "montacarichi_castello", [FERRO])
	_lift_platform()
	lp.save_glb(OUT + "montacarichi_piattaforma.glb", "montacarichi_piattaforma", [FERRO])
	_lever_base()
	lp.save_glb(OUT + "leva_base.glb", "leva_base", [FERRO])
	_lever_handle()
	lp.save_glb(OUT + "leva_manico.glb", "leva_manico", [FERRO])
	_shop()
	lp.save_glb(OUT + "negozio.glb", "negozio", [FERRO, ORO])
	_shovel()
	lp.save_glb(OUT + "pala.glb", "pala", [FERRO, ACCIAIO, ACCIAIO_CHIARO])
	_chest()
	lp.save_glb(OUT + "cassa.glb", "cassa", [FERRO, ORO])
	_tomb()
	lp.save_glb(OUT + "tomba.glb", "tomba", [])
	_beret()
	lp.save_glb(OUT + "berretto.glb", "berretto", [])
	_dynamite()
	lp.save_glb(OUT + "dinamite.glb", "dinamite", [])
	_digger_body()
	lp.save_glb(OUT + "becchino_corpo.glb", "becchino_corpo", [FERRO])
	_digger_head()
	lp.save_glb(OUT + "becchino_testa.glb", "becchino_testa", [FERRO])
	_digger_arm()
	lp.save_glb(OUT + "becchino_braccio.glb", "becchino_braccio", [])
	_digger_leg()
	lp.save_glb(OUT + "becchino_gamba.glb", "becchino_gamba", [])
	_cart_body()
	lp.save_glb(OUT + "vagone_cassone.glb", "vagone_cassone", [FERRO])
	_cart_base()
	lp.save_glb(OUT + "vagone_base.glb", "vagone_base", [FERRO])
	quit()


# --- modelli -------------------------------------------------------------------

## Mano destra con manica. La mano punta verso -Z, il palmo guarda in basso (-Y),
## la manica va indietro verso +Z. fist = true: dita chiuse attorno a un manico
## che passa per l'origine lungo l'asse X.
func _hand(fist: bool) -> void:
	var palm_z := 0.05 if fist else 0.0
	# manica e polsino
	lp.prism(Vector3(0, -0.005, palm_z + 0.07), Vector3(0, -0.03, palm_z + (0.24 if fist else 0.3)), 0.052, 0.062, 8, MANICA, PI / 8)
	lp.prism(Vector3(0, -0.004, palm_z + 0.045), Vector3(0, -0.008, palm_z + 0.095), 0.064, 0.066, 8, POLSINO, PI / 8)
	# palmo
	lp.cbox(Transform3D(Basis(), Vector3(0, 0, palm_z)), Vector3(0.105, 0.048, 0.10), 0.014, PELLE)
	if fist:
		# dita chiuse: un rotolo di nocche davanti e sotto al manico
		lp.cbox(Transform3D(Basis(), Vector3(0, 0.002, 0.0)), Vector3(0.108, 0.05, 0.05), 0.016, PELLE)
		lp.cbox(Transform3D(Basis(), Vector3(0, -0.032, 0.012)), Vector3(0.10, 0.03, 0.05), 0.012, PELLE_SCURA)
		for i in 3:
			# solchi tra le dita
			lp.cbox(Transform3D(Basis(), Vector3(-0.027 + i * 0.027, 0.0, -0.026)), Vector3(0.004, 0.044, 0.004), 0.001, PELLE_SCURA)
		# pollice sopra il manico
		var tb := Basis(Vector3.UP, 0.35)
		lp.cbox(Transform3D(tb, Vector3(-0.035, 0.03, 0.012)), Vector3(0.03, 0.026, 0.06), 0.009, PELLE)
	else:
		# quattro dita leggermente piegate, a "rastrello"
		for i in 4:
			var x := -0.039 + i * 0.026
			var length := 0.046 if i in [1, 2] else 0.04
			var base := Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(x, -0.002, palm_z - 0.045))
			lp.cbox(base * Transform3D(Basis(), Vector3(0, 0, -length / 2.0)), Vector3(0.023, 0.026, length), 0.008, PELLE)
			var tip := base * Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, -0.002, -length + 0.004))
			lp.cbox(tip * Transform3D(Basis(), Vector3(0, 0, -0.017)), Vector3(0.021, 0.023, 0.036), 0.008, PELLE)
		# pollice, sul lato sinistro della mano destra
		var thumb := Transform3D(Basis(Vector3.UP, 0.75) * Basis(Vector3.RIGHT, -0.2), Vector3(-0.05, -0.006, palm_z - 0.005))
		lp.cbox(thumb * Transform3D(Basis(), Vector3(0, 0, -0.026)), Vector3(0.026, 0.026, 0.052), 0.009, PELLE)


## Piccone: manico lungo +Y con l'impugnatura vicino all'origine, testa in cima
## lungo l'asse Z (punta principale verso -Z, in avanti).
func _pickaxe() -> void:
	# manico
	lp.prism(Vector3(0, -0.16, 0), Vector3(0, 0.56, 0), 0.029, 0.025, 8, LEGNO, PI / 8)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.18, 0)), Vector3(0.07, 0.045, 0.07), 0.016, LEGNO_SCURO)
	# fasciatura di cuoio sull'impugnatura
	for i in 3:
		var y := -0.14 + i * 0.05
		lp.prism(Vector3(0, y, 0), Vector3(0, y + 0.036, 0), 0.034, 0.034, 8, CUOIO, PI / 8)
	# collare di ferro
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.53, 0)), Vector3(0.08, 0.105, 0.1), 0.018, FERRO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.592, 0)), Vector3(0.062, 0.024, 0.062), 0.008, FERRO)
	# punta principale (in avanti, curva verso il basso)
	lp.prism(Vector3(0, 0.535, -0.045), Vector3(0, 0.53, -0.16), 0.04, 0.032, 4, ACCIAIO, PI / 4)
	lp.prism(Vector3(0, 0.53, -0.16), Vector3(0, 0.49, -0.265), 0.032, 0.019, 4, ACCIAIO, PI / 4)
	lp.prism(Vector3(0, 0.49, -0.265), Vector3(0, 0.415, -0.335), 0.019, 0.002, 4, ACCIAIO_CHIARO, PI / 4)
	# lama piatta dietro (scalpello)
	lp.prism(Vector3(0, 0.535, 0.045), Vector3(0, 0.525, 0.14), 0.04, 0.03, 4, ACCIAIO, PI / 4)
	lp.cbox(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.505, 0.185)), Vector3(0.066, 0.026, 0.08), 0.008, ACCIAIO_CHIARO)


## Castello del montacarichi: quattro montanti attorno alla piattaforma (2,2 x 2,2 m),
## travi in cima, controventi a croce sui due lati verso il muro (-X e -Z), guide di
## ferro sui montanti. I lati +X e +Z restano liberi per caricare i secchi.
## Origine al pavimento, al centro del pozzo.
func _lift_frame() -> void:
	var h := 4.0
	var c := 1.3
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * c, 0, sz * c)
			_beam(p, p + Vector3(0, h, 0), 0.2, 0.2, LEGNO_SCURO)
			lp.cbox(Transform3D(Basis(), p + Vector3(0, 0.1, 0)), Vector3(0.34, 0.2, 0.34), 0.04, PIETRA)
			# guida di ferro sulla faccia interna del montante
			var inner := p - Vector3(sx, 0, sz).normalized() * 0.13
			lp.cbox(Transform3D(Basis(), inner + Vector3(0, h / 2.0, 0)), Vector3(0.05, h - 0.3, 0.05), 0.01, FERRO)
	# travi in cima
	for s in [-1.0, 1.0]:
		_beam(Vector3(-c - 0.15, h - 0.15, s * c), Vector3(c + 0.15, h - 0.15, s * c), 0.22, 0.2, LEGNO)
		_beam(Vector3(s * c, h - 0.35, -c - 0.15), Vector3(s * c, h - 0.35, c + 0.15), 0.22, 0.2, LEGNO)
	# lati verso il muro: traverso a metà e croci
	for side in ["x", "z"]:
		var a := Vector3(-c, 0, -c)
		var b := Vector3(-c, 0, c) if side == "x" else Vector3(c, 0, -c)
		_beam(a + Vector3(0, 1.9, 0), b + Vector3(0, 1.9, 0), 0.18, 0.16, LEGNO)
		_beam(a + Vector3(0, 0.3, 0), b + Vector3(0, 1.8, 0), 0.12, 0.12, LEGNO_CHIARO)
		_beam(b + Vector3(0, 0.3, 0), a + Vector3(0, 1.8, 0), 0.12, 0.12, LEGNO_CHIARO)
		_beam(a + Vector3(0, 2.0, 0), b + Vector3(0, 3.5, 0), 0.12, 0.12, LEGNO_CHIARO)
		_beam(b + Vector3(0, 2.0, 0), a + Vector3(0, 3.5, 0), 0.12, 0.12, LEGNO_CHIARO)
	# piastre di ferro negli incastri in alto
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			lp.cbox(Transform3D(Basis(), Vector3(sx * c, h - 0.25, sz * c)), Vector3(0.26, 0.3, 0.26), 0.02, FERRO)


## Piattaforma del montacarichi (2,2 x 2,2 m, faccia superiore a y = 0,12): travi sotto,
## tavole, angolari di ferro, sponde basse sui lati -X e -Z e quattro funi verticali
## agli angoli che salgono nel pozzo.
func _lift_platform() -> void:
	var half := 1.1
	for z in [-0.9, 0.0, 0.9]:
		lp.cbox(Transform3D(Basis(), Vector3(0, 0.03, z)), Vector3(2.2, 0.06, 0.14), 0.015, LEGNO_SCURO)
	var n := 7
	var w := 2.2 / n
	for i in n:
		var z := -half + w * (i + 0.5)
		lp.cbox(Transform3D(Basis(), Vector3(0, 0.09, z)), Vector3(2.2, 0.06, w - 0.02), 0.012, LEGNO if i % 2 == 0 else LEGNO_CHIARO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (half - 0.08), 0.0, sz * (half - 0.08))
			lp.cbox(Transform3D(Basis(), p + Vector3(0, 0.075, 0)), Vector3(0.2, 0.15, 0.2), 0.02, FERRO)
			# anello e fune verticale
			lp.cbox(Transform3D(Basis(), p + Vector3(0, 0.2, 0)), Vector3(0.07, 0.1, 0.02), 0.01, FERRO)
			lp.prism(p + Vector3(0, 0.22, 0), p + Vector3(0, 7.0, 0), 0.024, 0.024, 6, CORDA)
	# sponde basse sui lati -X e -Z
	for side in ["x", "z"]:
		var a := Vector3(-half + 0.06, 0.12, -half + 0.06)
		var b := Vector3(-half + 0.06, 0.12, half - 0.06) if side == "x" else Vector3(half - 0.06, 0.12, -half + 0.06)
		for t in [0.0, 0.5, 1.0]:
			var p := a.lerp(b, t)
			_beam(p, p + Vector3(0, 0.32, 0), 0.08, 0.08, LEGNO_SCURO)
		_beam(a + Vector3(0, 0.27, 0), b + Vector3(0, 0.27, 0), 0.07, 0.12, LEGNO)


## Base della leva: blocco di legno con piastra di ferro, due guance a settore
## con i denti e il perno. Il manico ruota attorno all'asse X a y = 0,7.
func _lever_base() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.27, 0)), Vector3(0.32, 0.54, 0.42), 0.04, LEGNO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.555, 0)), Vector3(0.36, 0.04, 0.46), 0.015, FERRO)
	for sx in [-0.06, 0.06]:
		lp.arch(Vector3(sx, 0.6, 0), Vector3.BACK, Vector3.RIGHT, 0.14, 0.24, 0.025, 6, FERRO, 0.008)
		for i in 5:
			var a := PI * (i + 0.5) / 5.0
			var d := Vector3(0, sin(a), cos(a))
			lp.cbox(Transform3D(Basis(Vector3.RIGHT, -a + PI / 2.0), Vector3(sx, 0.6, 0) + d * 0.255), Vector3(0.03, 0.03, 0.03), 0.005, FERRO)
	lp.prism(Vector3(-0.1, 0.7, 0), Vector3(0.1, 0.7, 0), 0.035, 0.035, 8, FERRO, PI / 8)


## Manico della leva: perno nell'origine, asta di ferro verso +Y, impugnatura di legno
## e pomello rosso in cima.
func _lever_handle() -> void:
	lp.prism(Vector3(0, -0.04, 0), Vector3(0, 0.46, 0), 0.02, 0.018, 8, FERRO, PI / 8)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.05, 0.08, 0.06), 0.01, FERRO)
	lp.prism(Vector3(0, 0.40, 0), Vector3(0, 0.56, 0), 0.032, 0.03, 8, LEGNO, PI / 8)
	lp.prism(Vector3(0, 0.555, 0), Vector3(0, 0.6, 0), 0.05, 0.05, 8, ROSSO, PI / 8)
	lp.prism(Vector3(0, 0.6, 0), Vector3(0, 0.64, 0), 0.05, 0.03, 8, ROSSO, PI / 8)


## Trave (scatola smussata) da p0 a p1, sezione w x d.
func _beam(p0: Vector3, p1: Vector3, w: float, d: float, c: Color) -> void:
	var y := (p1 - p0).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	lp.cbox(Transform3D(Basis(x, y, z), (p0 + p1) / 2.0), Vector3(w, p0.distance_to(p1), d), 0.025, c)


## Negozio: banco di legno (fronte verso +Z) con fasce di ferro e pile di monete,
## dietro uno scaffale contro il muro con vasi, bottiglie, sacchi e cassette, e
## un'insegna di legno in cima allo scaffale. Origine al pavimento, al centro del banco.
func _shop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# --- banco ---
	for i in 10:
		var x := -1.3 + 0.26 * (i + 0.5)
		lp.cbox(Transform3D(Basis(), Vector3(x, 0.48, 0.37)), Vector3(0.245, 0.9, 0.06), 0.015, LEGNO if i % 2 == 0 else LEGNO_CHIARO)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * 1.27, 0.48, -0.02)), Vector3(0.07, 0.9, 0.8), 0.015, LEGNO_SCURO)
		for sz in [-1.0, 1.0]:
			_beam(Vector3(sx * 1.3, 0.0, sz * 0.4), Vector3(sx * 1.3, 0.95, sz * 0.4), 0.11, 0.11, LEGNO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.07, 0.36)), Vector3(2.66, 0.14, 0.1), 0.02, LEGNO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.98, 0.0)), Vector3(2.8, 0.07, 0.95), 0.025, LEGNO_SCURO)
	for y in [0.28, 0.72]:
		lp.cbox(Transform3D(Basis(), Vector3(0, y, 0.41)), Vector3(2.62, 0.05, 0.02), 0.005, FERRO)
		for x in [-1.1, -0.4, 0.4, 1.1]:
			lp.cbox(Transform3D(Basis(), Vector3(x, y, 0.425)), Vector3(0.03, 0.03, 0.02), 0.005, FERRO)
	# pile di monete sul piano
	for c in [Vector3(0.55, 0, 0.18), Vector3(0.78, 0, -0.05), Vector3(0.42, 0, -0.2), Vector3(0.95, 0, 0.22)]:
		var n := rng.randi_range(2, 6)
		for i in n:
			var p: Vector3 = c + Vector3(rng.randf_range(-0.01, 0.01), 1.015 + i * 0.022, rng.randf_range(-0.01, 0.01))
			lp.prism(p, p + Vector3(0, 0.018, 0), 0.055, 0.055, 8, ORO)
	# --- scaffale contro il muro ---
	var z0 := -1.5
	for sx in [-1.0, 1.0]:
		for dz in [-0.16, 0.16]:
			_beam(Vector3(sx * 1.22, 0.0, z0 + dz), Vector3(sx * 1.22, 2.6, z0 + dz), 0.08, 0.08, LEGNO_SCURO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 1.1, z0 - 0.19)), Vector3(2.5, 2.2, 0.03), 0.0, LEGNO_SCURO)
	for y in [0.45, 1.05, 1.65, 2.2]:
		lp.cbox(Transform3D(Basis(), Vector3(0, y, z0)), Vector3(2.52, 0.05, 0.42), 0.012, LEGNO)
	# merce sui ripiani (il ripiano in alto resta libero per gli attrezzi)
	for y in [0.475, 1.075]:
		var x := -1.08
		while x < 1.0:
			var kind := rng.randi() % 4
			var zz := z0 + rng.randf_range(-0.06, 0.06)
			match kind:
				0:  # vaso di ceramica
					var h := rng.randf_range(0.18, 0.28)
					lp.prism(Vector3(x, y, zz), Vector3(x, y + h, zz), 0.08, 0.06, 8, CERAMICA)
					lp.prism(Vector3(x, y + h, zz), Vector3(x, y + h + 0.03, zz), 0.045, 0.045, 8, CERAMICA.darkened(0.2))
					x += 0.22
				1:  # bottiglia
					lp.prism(Vector3(x, y, zz), Vector3(x, y + 0.2, zz), 0.045, 0.045, 6, VETRO)
					lp.prism(Vector3(x, y + 0.2, zz), Vector3(x, y + 0.3, zz), 0.018, 0.015, 6, VETRO)
					x += 0.14
				2:  # sacco
					lp.cbox(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(x + 0.08, y + 0.13, zz)),
						Vector3(0.26, 0.26, 0.24), 0.08, SACCO)
					x += 0.32
				3:  # cassetta
					lp.cbox(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), Vector3(x + 0.08, y + 0.11, zz)),
						Vector3(0.26, 0.22, 0.26), 0.02, LEGNO_CHIARO)
					x += 0.32
	# --- insegna ---
	lp.cbox(Transform3D(Basis(), Vector3(0, 2.5, z0 + 0.2)), Vector3(1.9, 0.5, 0.06), 0.02, LEGNO)
	for y in [2.27, 2.73]:
		lp.cbox(Transform3D(Basis(), Vector3(0, y, z0 + 0.22)), Vector3(1.96, 0.06, 0.07), 0.015, LEGNO_SCURO)
	for x in [-0.9, 0.9]:
		lp.cbox(Transform3D(Basis(), Vector3(x, 2.5, z0 + 0.22)), Vector3(0.06, 0.52, 0.07), 0.015, LEGNO_SCURO)
		lp.cbox(Transform3D(Basis(), Vector3(x, 2.5, z0 + 0.26)), Vector3(0.04, 0.04, 0.02), 0.005, FERRO)


## Pala in piedi: origine sulla punta della lama, manico verso +Y (alta circa 0,95 m),
## lama nel piano XY. Lama d'acciaio a punta, collare di ferro, manico di legno e
## impugnatura a D.
func _shovel() -> void:
	# lama: corpo e punta a rombo
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.17, 0)), Vector3(0.21, 0.24, 0.022), 0.008, ACCIAIO)
	lp.cbox(Transform3D(Basis(Vector3.BACK, PI / 4.0), Vector3(0, 0.075, 0)), Vector3(0.105, 0.105, 0.02), 0.006, ACCIAIO_CHIARO)
	# bordo ripiegato in alto (dove si appoggia il piede) e nervatura centrale
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.295, -0.006)), Vector3(0.225, 0.025, 0.04), 0.008, FERRO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.2, 0.012)), Vector3(0.03, 0.2, 0.012), 0.004, ACCIAIO_CHIARO)
	# collare con due rivetti
	lp.prism(Vector3(0, 0.29, 0), Vector3(0, 0.42, 0), 0.032, 0.025, 8, FERRO, PI / 8)
	for y in [0.34, 0.39]:
		lp.cbox(Transform3D(Basis(), Vector3(0, y, 0.028)), Vector3(0.014, 0.014, 0.01), 0.003, ACCIAIO_CHIARO)
	# manico
	lp.prism(Vector3(0, 0.4, 0), Vector3(0, 0.86, 0), 0.022, 0.021, 8, LEGNO, PI / 8)
	# impugnatura a D
	for sx in [-1.0, 1.0]:
		_beam(Vector3(0, 0.85, 0), Vector3(sx * 0.065, 0.945, 0), 0.03, 0.035, LEGNO_SCURO)
	lp.prism(Vector3(-0.08, 0.955, 0), Vector3(0.08, 0.955, 0), 0.022, 0.022, 8, LEGNO_CHIARO, PI / 8)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.86, 0)), Vector3(0.05, 0.04, 0.05), 0.01, FERRO)


## Cassa (forziere): origine al pavimento al centro, fronte verso +Z, circa 0,9 x 0,7 x 0,6 m.
## Corpo a tavole, coperchio bombato, fasce e angolari di ferro, serratura d'oro.
func _chest() -> void:
	var w := 0.9
	var d := 0.56
	# corpo a tre corsi di tavole
	for i in 3:
		lp.cbox(Transform3D(Basis(), Vector3(0, 0.07 + i * 0.13, 0)), Vector3(w, 0.125, d), 0.015,
			LEGNO if i % 2 == 0 else LEGNO_CHIARO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(w - 0.04, 0.38, d - 0.04), 0.0, LEGNO_SCURO)
	# coperchio bombato
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3(w + 0.03, 0.05, d + 0.03), 0.015, LEGNO_SCURO)
	lp.arch(Vector3(0, 0.44, 0), Vector3.BACK, Vector3.RIGHT, 0.0, d / 2.0 + 0.01, w + 0.01, 6, LEGNO, 0.015)
	# fasce di ferro che girano attorno
	for x in [-0.3, 0.3]:
		lp.cbox(Transform3D(Basis(), Vector3(x, 0.22, d / 2.0 + 0.01)), Vector3(0.065, 0.44, 0.02), 0.006, FERRO)
		lp.cbox(Transform3D(Basis(), Vector3(x, 0.22, -d / 2.0 - 0.01)), Vector3(0.065, 0.44, 0.02), 0.006, FERRO)
		lp.arch(Vector3(x, 0.44, 0), Vector3.BACK, Vector3.RIGHT, d / 2.0 + 0.005, d / 2.0 + 0.03, 0.065, 6, FERRO, 0.006)
	# angolari
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [0.04, 0.4]:
				lp.cbox(Transform3D(Basis(), Vector3(sx * (w / 2.0 - 0.03), y, sz * (d / 2.0 - 0.03))), Vector3(0.09, 0.09, 0.09), 0.012, FERRO)
	# serratura
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.4, d / 2.0 + 0.025)), Vector3(0.13, 0.16, 0.03), 0.012, ORO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.39, d / 2.0 + 0.042)), Vector3(0.022, 0.05, 0.01), 0.0, CUOIO)
	# maniglie sui fianchi
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * (w / 2.0 + 0.03), 0.28, 0)), Vector3(0.03, 0.05, 0.18), 0.008, FERRO)


## Tomba aperta: sarcofago di pietra lungo X (2,3 x 1,0 m, alto 0,75), vuoto dentro
## (fondo coperto da un letto di terra a y = 0,42), con pannelli incisi sui fianchi e una croce sulla testata.
## Il coperchio è spostato e appoggiato di sbieco contro il fianco +Z.
## Origine al pavimento al centro della cassa.
func _tomb() -> void:
	var st := Color(0.66, 0.62, 0.55)
	var st_dark := Color(0.52, 0.49, 0.43)
	var st_light := Color(0.74, 0.70, 0.62)
	var inside := Color(0.30, 0.27, 0.23)
	var L := 2.3
	var W := 1.0
	var H := 0.75
	var t := 0.12
	# zoccolo e fondo
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(L + 0.12, 0.1, W + 0.12), 0.03, st_dark)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(L - 2 * t, 0.06, W - 2 * t), 0.0, inside)
	# pareti
	for sz in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(0, H / 2.0 + 0.05, sz * (W / 2.0 - t / 2.0))), Vector3(L, H - 0.1, t), 0.03, st)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * (L / 2.0 - t / 2.0), H / 2.0 + 0.05, 0)), Vector3(t, H - 0.1, W - 2 * t), 0.03, st)
	# bordo superiore
	for sz in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(0, H + 0.02, sz * (W / 2.0 - t / 2.0))), Vector3(L + 0.06, 0.06, t + 0.05), 0.02, st_light)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * (L / 2.0 - t / 2.0), H + 0.02, 0)), Vector3(t + 0.05, 0.06, W + 0.06), 0.02, st_light)
	# interno più scuro (pareti viste da dentro)
	for sz in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(0, H / 2.0 + 0.1, sz * (W / 2.0 - t - 0.005))), Vector3(L - 2 * t, H - 0.2, 0.01), 0.0, inside)
	# letto di terra dentro la tomba (lo scheletro ci si sdraia sopra, a y = 0,42)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.29, 0)), Vector3(L - 2 * t - 0.02, 0.26, W - 2 * t - 0.02), 0.04, Color(0.45, 0.32, 0.2))
	# pannelli incisi sui fianchi lunghi
	for sz in [-1.0, 1.0]:
		for x in [-0.65, 0.0, 0.65]:
			lp.cbox(Transform3D(Basis(), Vector3(x, 0.42, sz * (W / 2.0 + 0.005))), Vector3(0.5, 0.36, 0.02), 0.01, st_dark)
			lp.cbox(Transform3D(Basis(), Vector3(x, 0.42, sz * (W / 2.0 + 0.012))), Vector3(0.4, 0.26, 0.02), 0.01, st)
	# croce sulla testata (-X)
	lp.cbox(Transform3D(Basis(), Vector3(-L / 2.0 - 0.012, 0.42, 0)), Vector3(0.03, 0.4, 0.08), 0.008, st_light)
	lp.cbox(Transform3D(Basis(), Vector3(-L / 2.0 - 0.012, 0.5, 0)), Vector3(0.03, 0.08, 0.28), 0.008, st_light)
	# coperchio appoggiato di sbieco contro il fianco +Z
	var lid := Transform3D(Basis(Vector3.RIGHT, -1.15), Vector3(0.05, 0.47, W / 2.0 + 0.3))
	lp.cbox(lid, Vector3(L + 0.1, 0.12, W + 0.05), 0.03, st)
	lp.cbox(lid * Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(L - 0.2, 0.04, W - 0.25), 0.02, st_light)
	lp.cbox(lid * Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.9, 0.03, 0.1), 0.008, st_dark)
	lp.cbox(lid * Transform3D(Basis(), Vector3(-0.25, 0.1, 0)), Vector3(0.1, 0.03, 0.45), 0.008, st_dark)


## Berretto viola (basco) per il teschio dello scheletro: origine nel perno della testa
## (base del collo), così va messo come figlio del nodo Testa senza spostarlo.
## Una cupola che avvolge la cima del cranio, una fascia più scura sulla fronte,
## la parte morbida che ricade da un lato e il picciolo in cima.
func _beret() -> void:
	var viola := Color(0.47, 0.22, 0.62)
	var viola_chiaro := Color(0.57, 0.31, 0.72)
	var viola_scuro := Color(0.30, 0.12, 0.42)
	var tilt := Transform3D(Basis.from_euler(Vector3(-0.08, 0.0, 0.18)), Vector3(0.0, 0.0, 0.0))
	var c := Vector3(0, 0.36, -0.02)
	# fascia
	lp.prism(tilt * (c + Vector3(0, -0.005, 0)), tilt * (c + Vector3(0, 0.035, 0)), 0.2, 0.203, 14, viola_scuro)
	# cupola sopra il cranio (solo la metà di sopra dell'ellissoide)
	var dome := Transform3D(tilt.basis, tilt * (c + Vector3(0, 0.03, 0)))
	_ball_xf(dome, Vector3(0.208, 0.135, 0.208), 14, 5, viola, 0.0)
	# parte morbida che ricade da un lato
	var puff := tilt * (c + Vector3(0.07, 0.125, -0.005))
	lp.ball(puff, Vector3(0.2, 0.058, 0.19), 12, 6, viola_chiaro)
	# picciolo
	var top := tilt * (c + Vector3(0.03, 0.185, 0))
	lp.prism(top, top + Vector3(0.006, 0.04, 0), 0.016, 0.012, 6, viola_scuro)


## Ellissoide ruotato: ball() con l'orientamento di xf (centro = xf.origin).
func _ball_xf(xf: Transform3D, r: Vector3, segs: int, rings: int, col: Color, lat_min: float) -> void:
	var before := {}
	for k in lp.parts:
		before[k] = lp.parts[k].size()
	lp.ball(Vector3.ZERO, r, segs, rings, col, lat_min)
	# trasforma solo i vertici appena aggiunti
	var arr: PackedVector3Array = lp.parts[col]
	var nrm: PackedVector3Array = lp.normals[col]
	for i in range(before.get(col, 0), arr.size()):
		arr[i] = xf * arr[i]
		nrm[i] = (xf.basis * nrm[i]).normalized()
	lp.parts[col] = arr
	lp.normals[col] = nrm


## Candelotto di dinamite: cilindro rosso lungo Y (0,26 m) centrato nell'origine,
## fascia di carta con la scritta, tappi scuri e miccia in cima.
func _dynamite() -> void:
	var rosso := Color(0.78, 0.15, 0.10)
	var rosso_scuro := Color(0.55, 0.09, 0.06)
	var carta := Color(0.92, 0.86, 0.70)
	var nero := Color(0.12, 0.10, 0.09)
	lp.prism(Vector3(0, -0.13, 0), Vector3(0, 0.13, 0), 0.036, 0.036, 10, rosso)
	lp.prism(Vector3(0, -0.135, 0), Vector3(0, -0.12, 0), 0.038, 0.038, 10, rosso_scuro)
	lp.prism(Vector3(0, 0.12, 0), Vector3(0, 0.135, 0), 0.038, 0.038, 10, rosso_scuro)
	lp.prism(Vector3(0, -0.035, 0), Vector3(0, 0.035, 0), 0.039, 0.039, 10, carta)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0, 0.039)), Vector3(0.03, 0.03, 0.004), 0.0, nero)
	# miccia un po' piegata
	lp.prism(Vector3(0, 0.135, 0), Vector3(0.006, 0.17, 0.004), 0.006, 0.005, 5, nero)
	lp.prism(Vector3(0.006, 0.17, 0.004), Vector3(0.02, 0.195, 0.01), 0.005, 0.004, 5, nero)


## Cassone del carrello da miniera: origine sul perno di ribaltamento (bordo -X, in basso),
## il cassone si estende verso +X... centrato: lungo Z (direzione di marcia) 1,0 m,
## largo X 0,7 m, alto 0,45 m. Il perno è sul lato +X così si ribalta di lato.
func _cart_body() -> void:
	var o := Vector3(-0.35, 0, 0)   # il cassone sta a sinistra del perno
	lp.cbox(Transform3D(Basis(), o + Vector3(0, 0.03, 0)), Vector3(0.7, 0.06, 1.0), 0.02, LEGNO_SCURO)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), o + Vector3(sx * 0.33, 0.24, 0)), Vector3(0.05, 0.42, 1.0), 0.015, LEGNO)
	for sz in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), o + Vector3(0, 0.24, sz * 0.48)), Vector3(0.62, 0.42, 0.05), 0.015, LEGNO_CHIARO)
	# fasce e angolari di ferro
	for y in [0.1, 0.42]:
		for sx in [-1.0, 1.0]:
			lp.cbox(Transform3D(Basis(), o + Vector3(sx * 0.36, y, 0)), Vector3(0.02, 0.05, 1.02), 0.005, FERRO)
		for sz in [-1.0, 1.0]:
			lp.cbox(Transform3D(Basis(), o + Vector3(0, y, sz * 0.51)), Vector3(0.74, 0.05, 0.02), 0.005, FERRO)


## Telaio e ruote del carrello: origine al centro, sul piano dei binari (y = 0).
func _cart_base() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(0.6, 0.08, 0.95), 0.02, FERRO)
	for sz in [-0.32, 0.32]:
		lp.prism(Vector3(-0.3, 0.13, sz), Vector3(0.3, 0.13, sz), 0.025, 0.025, 6, FERRO)
		for sx in [-0.22, 0.22]:
			lp.prism(Vector3(sx - 0.03, 0.13, sz), Vector3(sx + 0.03, 0.13, sz), 0.12, 0.12, 10, CUOIO)
			lp.prism(Vector3(sx - 0.035, 0.13, sz), Vector3(sx + 0.035, 0.13, sz), 0.05, 0.05, 8, FERRO)
	# maniglia per spingere
	for sx in [-0.25, 0.25]:
		_beam(Vector3(sx, 0.25, -0.48), Vector3(sx, 0.62, -0.62), 0.04, 0.04, LEGNO_SCURO)
	lp.prism(Vector3(-0.3, 0.62, -0.62), Vector3(0.3, 0.62, -0.62), 0.025, 0.025, 8, LEGNO)


# --- becchino (i giocatori visti dagli altri in co-op) ----------------------------
# Guarda verso -Z. Perni: anca a y 0,85 (corpo e gambe), spalle a y 1,42, collo a y 1,5.

## Corpo: origine all'anca. Busto, mantello che scende fino alle ginocchia, cintura
## con fibbia e lanterna appesa al fianco.
func _digger_body() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.33, 0)), Vector3(0.46, 0.6, 0.3), 0.08, MANTELLO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.58, 0)), Vector3(0.52, 0.12, 0.32), 0.05, MANTELLO_SCURO)
	# gonna del mantello (aperta davanti)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(Vector3.BACK, sx * 0.08), Vector3(sx * 0.13, -0.16, 0.02)), Vector3(0.24, 0.42, 0.32), 0.05, MANTELLO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.16, 0.1)), Vector3(0.44, 0.42, 0.12), 0.04, MANTELLO_SCURO)
	# cintura e fibbia
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.5, 0.08, 0.34), 0.02, CUOIO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.05, -0.175)), Vector3(0.09, 0.08, 0.02), 0.01, ORO)
	# lanterna al fianco destro
	var lx := 0.27
	lp.cbox(Transform3D(Basis(), Vector3(lx, -0.08, -0.04)), Vector3(0.11, 0.15, 0.11), 0.015, FERRO)
	lp.cbox(Transform3D(Basis(), Vector3(lx, -0.08, -0.04)), Vector3(0.08, 0.1, 0.12), 0.0, LUCE)
	lp.cbox(Transform3D(Basis(), Vector3(lx, 0.01, -0.04)), Vector3(0.03, 0.06, 0.03), 0.005, FERRO)


## Testa: origine al collo. Faccia, barba, naso, occhi, cappuccio del mantello
## e lampada da minatore sul davanti del cappuccio.
func _digger_head() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(0.12, 0.08, 0.12), 0.02, PELLE_SCURA)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.17, 0)), Vector3(0.26, 0.26, 0.25), 0.07, PELLE)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.15, -0.135)), Vector3(0.05, 0.06, 0.04), 0.012, PELLE_SCURA)
	for sx in [-1.0, 1.0]:
		lp.cbox(Transform3D(Basis(), Vector3(sx * 0.06, 0.2, -0.127)), Vector3(0.035, 0.04, 0.01), 0.005, Color(0.08, 0.06, 0.05))
	# barba
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.07, -0.1)), Vector3(0.24, 0.12, 0.1), 0.04, BARBA)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.02, -0.12)), Vector3(0.14, 0.08, 0.06), 0.03, BARBA)
	# cappuccio: calotta e bordo, aperto davanti
	lp.ball(Vector3(0, 0.22, 0.025), Vector3(0.18, 0.17, 0.18), 10, 5, MANTELLO, -0.25)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.12, 0.08)), Vector3(0.34, 0.24, 0.16), 0.06, MANTELLO)
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.36, -0.1)), Vector3(0.28, 0.05, 0.08), 0.02, MANTELLO_SCURO)
	# lampada da minatore
	lp.cbox(Transform3D(Basis(), Vector3(0, 0.36, -0.155)), Vector3(0.08, 0.07, 0.04), 0.012, FERRO)
	lp.prism(Vector3(0, 0.36, -0.17), Vector3(0, 0.36, -0.185), 0.028, 0.028, 8, LUCE)


## Braccio: origine alla spalla, scende lungo -Y. Manica del mantello, guanto.
## La mano è a y -0,6 (lì si attaccano gli attrezzi).
func _digger_arm() -> void:
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.02, 0)), Vector3(0.15, 0.14, 0.15), 0.05, MANTELLO_SCURO)
	lp.prism(Vector3(0, -0.04, 0), Vector3(0, -0.46, 0), 0.065, 0.075, 8, MANTELLO, PI / 8)
	lp.prism(Vector3(0, -0.44, 0), Vector3(0, -0.5, 0), 0.08, 0.08, 8, MANTELLO_SCURO, PI / 8)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.57, 0)), Vector3(0.1, 0.13, 0.11), 0.03, CUOIO)


## Gamba: origine all'anca, scende fino a terra (y -0,85). Pantaloni e stivale verso -Z.
func _digger_leg() -> void:
	lp.prism(Vector3(0, 0, 0), Vector3(0, -0.6, 0), 0.085, 0.075, 8, PANTALONI, PI / 8)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.68, 0.0)), Vector3(0.16, 0.2, 0.17), 0.04, CUOIO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.8, -0.06)), Vector3(0.16, 0.1, 0.27), 0.035, CUOIO)
	lp.cbox(Transform3D(Basis(), Vector3(0, -0.6, 0)), Vector3(0.19, 0.05, 0.19), 0.02, LEGNO_SCURO)
