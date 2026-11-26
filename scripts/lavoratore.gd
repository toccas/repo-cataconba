extends Node
## Cervello di uno scheletro lavoratore (figlio di uno scheletro risorto). Gira solo sul
## server: gli altri computer ricevono posizione e animazione da main.gd.
##
## Cosa fa, in ordine:
## 1. se c'è un secchio a terra raggiungibile, va a prenderlo e lo porta al montacarichi;
## 2. altrimenti va al fronte di terra più vicino, scava finché riempie un secchio
##    e lo porta al montacarichi.
## Se il montacarichi è in viaggio o pieno aspetta lì accanto.

enum { DECIDI, VAI_SECCHIO, VAI_SCAVO, SCAVA, VAI_MONTACARICHI, ASPETTA }

const VEL := 1.5             # metri al secondo
const PERIODO := 0.8         # secondi tra un colpo e l'altro (come l'animazione "scava")
const MAX_MAT := 1           # scava terra e terra dura, non la roccia
const SECCHIO_M3 := 2.5      # 10 unità
const VICINO := 0.72         # distanza minima dalla superficie della terra quando scava
const LONTANO := 0.9         # oltre questa distanza si avvicina (per arrivarci con le mani)
const LARGO := 0.42          # spazio libero che vuole intorno a sé (spalle e braccia)

var main: Node
var sk: Node3D               # lo scheletro
var griglia: Node3D
var stato := DECIDI
var percorso := PackedVector3Array()
var secchio: RigidBody3D
var fronte := Vector2i(-1, -1)
var raccolta := Vector3.ZERO # m³ scavati per materiale
var valore := -1             # secchio in mano (monete), -1 = mani libere
var t := 0.0
var colpi_vuoti := 0
var colpo_alto := false
var saltate := {}
var _ostacolo := Vector3.INF


func _ready() -> void:
	sk = get_parent()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or sk.rising or not griglia.pronto:
		return
	var forza: float = main.state.forza_scheletri()
	t += delta
	match stato:
		DECIDI:
			if t > 0.4:
				t = 0.0
				_decidi()
		VAI_SECCHIO:
			if not is_instance_valid(secchio):
				stato = DECIDI
			elif _cammina(delta, forza) or _xz(secchio.global_position).distance_to(_xz(sk.global_position)) < 1.1:
				_prendi_secchio()
		VAI_SCAVO:
			if _cammina(delta, forza):
				stato = SCAVA
				t = 0.0
		SCAVA:
			_distanza(delta, forza)
			_guarda(griglia.centro(fronte))
			if t >= PERIODO / forza:
				t = 0.0
				_colpo(forza)
		VAI_MONTACARICHI:
			if _cammina(delta, forza) or _xz(main.lift_pos()).distance_to(_xz(sk.global_position)) < 2.0:
				_scarica()
		ASPETTA:
			if t > 1.0:
				t = 0.0
				if valore >= 0:
					_scarica()
				else:
					_decidi()
	_spazio(delta, forza)
	sk.azione = _animazione()
	sk.porta_secchio(valore >= 0)


func _animazione() -> String:
	match stato:
		SCAVA:
			return "scava"
		VAI_SECCHIO, VAI_SCAVO, VAI_MONTACARICHI:
			return "porta" if valore >= 0 else "cammina"
	return "porta_fermo" if valore >= 0 else "idle"


func _decidi() -> void:
	if valore >= 0:
		_vai_al_montacarichi()
		return
	# 1. secchi a terra (non già presi da un altro scheletro)
	var migliore: RigidBody3D = null
	var best_path := PackedVector3Array()
	var best_d := INF
	for b: RigidBody3D in main.secchi.get_children():
		if b.has_meta("preso_da") and is_instance_valid(b.get_meta("preso_da")) and b.get_meta("preso_da") != sk:
			continue
		var d := b.global_position.distance_to(sk.global_position)
		if d >= best_d:
			continue
		var c: Vector2i = griglia.libera_vicina(b.global_position, 1.2)
		if c.x < 0:
			continue
		var p: PackedVector3Array = griglia.percorso(sk.global_position, c)
		if p.is_empty() and griglia.cella(sk.global_position) != c:
			continue
		migliore = b
		best_path = p
		best_d = d
	if migliore:
		secchio = migliore
		secchio.set_meta("preso_da", sk)
		percorso = best_path
		stato = VAI_SECCHIO
		return
	# 2. scavare
	var f: Array = griglia.fronte_vicino(sk.global_position, MAX_MAT, saltate)
	if f.is_empty():
		stato = ASPETTA
		return
	fronte = f[0]
	percorso = griglia.percorso(sk.global_position, f[1])
	colpi_vuoti = 0
	stato = VAI_SCAVO


## Avanza lungo il percorso. true quando è arrivato.
func _cammina(delta: float, forza: float) -> bool:
	if percorso.is_empty():
		return true
	var target := percorso[0]
	var pos := sk.global_position
	var d := _xz(target) - _xz(pos)
	var passo := VEL * forza * delta
	if d.length() <= passo:
		sk.global_position = Vector3(target.x, griglia.PAV, target.z)
		percorso.remove_at(0)
		return percorso.is_empty()
	var dir := d.normalized()
	sk.global_position = Vector3(pos.x + dir.x * passo, griglia.PAV, pos.z + dir.y * passo)
	_guarda(target)
	return false


## Direzione (sul piano) dallo scheletro al pezzo di terra da scavare.
func _dir_fronte() -> Vector2:
	var d := _xz(griglia.centro(fronte)) - _xz(sk.global_position)
	return d.normalized() if d.length() > 0.01 else Vector2(sin(sk.global_rotation.y), cos(sk.global_rotation.y))


## Quanto è lontana la terra vera in direzione dir, all'altezza h dal pavimento (INF = niente).
func _superficie(dir: Vector2, h: float, max_d := 1.6) -> float:
	var o := sk.global_position
	var d := 0.05
	while d <= max_d:
		if main.terrain.solida(Vector3(o.x + dir.x * d, griglia.PAV + h, o.z + dir.y * d)):
			return d
		d += 0.05
	return INF


## La terra più vicina davanti, nella fascia dove si muovono le braccia (al centro e a
## 0,22 m per parte) e a quattro altezze: piedi, pancia, petto, braccia alzate.
## Quello che è proprio accanto al corpo (meno di 0,2 m) è di lato: ci pensa _spazio().
## Il punto trovato resta in _ostacolo.
func _davanti(dir: Vector2) -> float:
	var o := sk.global_position
	var lato := Vector2(dir.y, -dir.x)
	var best := INF
	_ostacolo = Vector3.INF
	for l in [-0.22, 0.0, 0.22]:
		for h in [0.3, 0.9, 1.4, 1.9]:
			var d := 0.2
			while d <= minf(best - 0.01, 1.6):
				var q: Vector2 = Vector2(o.x, o.z) + dir * d + lato * l
				var p := Vector3(q.x, griglia.PAV + h, q.y)
				if main.terrain.solida(p):
					best = d
					_ostacolo = p
					break
				d += 0.05
	return best


## Si tiene tra VICINO e LONTANO dalla terra che sta scavando, muovendosi solo dove si
## può stare.
func _distanza(delta: float, forza: float) -> void:
	var dir := _dir_fronte()
	var s := _davanti(dir)
	var mossa := 0.0
	if s < VICINO:
		mossa = -(VICINO - s)
	elif s > LONTANO and s != INF:
		mossa = s - LONTANO
	if absf(mossa) < 0.01:
		return
	_sposta(dir * signf(mossa) * minf(absf(mossa), VEL * forza * delta))


## Si allontana dalla terra che ha di lato o dietro (così non ci entra con le spalle).
func _spazio(delta: float, forza: float) -> void:
	var spinta := Vector2.ZERO
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(sin(a), cos(a))
		for h in [0.5, 1.2, 1.7]:
			var s := _superficie(d, h, LARGO)
			if s != INF:
				spinta -= d * (LARGO - s + 0.05)
				break
	if stato == SCAVA:
		# verso la terra da scavare ci pensa _distanza()
		var dir := _dir_fronte()
		spinta -= dir * minf(spinta.dot(dir), 0.0)
	if spinta.length() > 0.01:
		_sposta(spinta.limit_length(VEL * forza * delta * 0.6))


## Si sposta di v se nel punto nuovo non c'è terra all'altezza del corpo né un muro.
func _sposta(v: Vector2) -> void:
	var nuova := _xz(sk.global_position) + v
	var p := Vector3(nuova.x, griglia.PAV, nuova.y)
	var c: Vector2i = griglia.cella(p)
	if not griglia.dentro(c) or griglia.statico[c.x + c.y * griglia.N] == 1:
		return
	for h in [0.4, 1.0, 1.6]:
		if main.terrain.solida(p + Vector3(0, h, 0)):
			return
	sk.global_position = p


func _guarda(p: Vector3) -> void:
	var d := _xz(p) - _xz(sk.global_position)
	if d.length() > 0.05:
		sk.global_rotation.y = lerp_angle(sk.global_rotation.y, atan2(d.x, d.y), 0.2)


func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _prendi_secchio() -> void:
	if not is_instance_valid(secchio):
		stato = DECIDI
		return
	valore = secchio.valore
	main.lavoratore_prende(secchio)
	secchio = null
	_vai_al_montacarichi()


func _colpo(forza: float) -> void:
	var h := 1.25 if colpo_alto else 0.5
	colpo_alto = not colpo_alto
	var dir := _dir_fronte()
	var p: Vector3
	if _davanti(dir) < VICINO:
		# c'è terra dove passano le braccia: scava prima quella
		p = _ostacolo + Vector3(dir.x, 0, dir.y) * 0.25
	else:
		# colpisce la superficie vera della terra davanti a sé, poco dentro
		var s := _superficie(dir, h)
		if s == INF:
			s = _xz(griglia.centro(fronte)).distance_to(_xz(sk.global_position))
		var o := sk.global_position
		p = Vector3(o.x + dir.x * (s + 0.2), griglia.PAV + h, o.z + dir.y * (s + 0.2))
	var v: Vector3 = main.scava_rete(p, 0.7, 1.5 * forza, MAX_MAT)
	main.lavoratore_suono(p, v)
	raccolta += v
	colpi_vuoti = colpi_vuoti + 1 if v.x + v.y + v.z < 0.003 else 0
	var tot := raccolta.x + raccolta.y + raccolta.z
	if tot >= SECCHIO_M3:
		var f := SECCHIO_M3 / tot
		var vv: Array = main.state.VALORE
		valore = int(round((raccolta.x * vv[0] + raccolta.y * vv[1] + raccolta.z * vv[2]) * f / main.state.UNITA_M3))
		raccolta *= 1.0 - f
		_vai_al_montacarichi()
		return
	if colpi_vuoti >= 4:
		saltate[fronte] = true
	if colpi_vuoti >= 4 or griglia.libera(fronte):
		# questo pezzo è finito: il prossimo fronte (di solito subito accanto)
		var f2: Array = griglia.fronte_vicino(sk.global_position, MAX_MAT, saltate)
		if f2.is_empty():
			stato = ASPETTA
			return
		fronte = f2[0]
		colpi_vuoti = 0
		percorso = griglia.percorso(sk.global_position, f2[1])
		stato = VAI_SCAVO if not percorso.is_empty() else SCAVA


func _vai_al_montacarichi() -> void:
	var c: Vector2i = griglia.libera_vicina(main.lift_pos(), 2.5)
	percorso = griglia.percorso(sk.global_position, c) if c.x >= 0 else PackedVector3Array()
	stato = VAI_MONTACARICHI


func _scarica() -> void:
	if main.lavoratore_impila(valore):
		valore = -1
		stato = DECIDI
	else:
		stato = ASPETTA
	t = 0.0
