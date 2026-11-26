extends Node3D
## Scena principale del prototipo. Tutti gli elementi sono nodi della scena main.tscn:
## Catacomba (pezzi del Modular Cave Kit), Soffitto, Terra, Spawn (montacarichi, leva, negozio),
## Secchi (i secchi lanciati), Ossa (i pezzi di scheletro sepolti o lanciati), Player, HUD.
## Questo script collega le interazioni e aggiorna l'interfaccia.
##
## Ciclo: scavi -> la terra va nell'attrezzo -> Q riempie un secchio (10 unità) ->
## lo lanci (tasto destro) -> lo raccogli (E) -> lo posi sul montacarichi (E) ->
## leva: la pila sale e viene venduta -> negozio.
## Ossa: scavando si trovano pezzi di scheletro; si raccolgono (E), si lanciano (tasto
## destro) e si posano nella tomba dello spawn (E). Con tutti e 6 lo scheletro si alza.
##
## Multigiocatore (co-op online, vedi scripts/rete.gd): chi ospita è il server e decide
## su secchi e ossa a terra, montacarichi, tomba, monete e negozio (condivisi da tutta
## la squadra). Gli altri mandano richieste ("req_*") e ricevono il risultato.
## La terra nell'attrezzo e quello che si ha in mano sono di ogni giocatore.
## Lo scavo lo fa ognuno sul suo computer e lo manda a tutti; il server tiene l'elenco
## degli scavi per chi entra dopo. Da solo è uguale: il server sei tu.
##
## Avvio normale: menu (da solo / ospita / entra).
## Con "-- --bench": scava da solo per alcuni secondi, salva le misure in
## bench.txt e uno screenshot in shot.png, poi chiude.
## Con "-- --loop": prova automatica del ciclo dei secchi.
## Con "-- --host" o "-- --join <ip>" (e "--nome <nome>"): salta il menu.
## Con "-- --host --provarete" e "-- --join 127.0.0.1 --provarete": prova automatica in rete.

## Scena del secchio (creata da tools/build_scenes.gd), caricata all'avvio.
var secchio_scene: PackedScene
var osso_scene: PackedScene
var dinamite_scene: PackedScene
const RAGGIO_ESPLOSIONE := 2.3
const OssoScript := preload("res://scripts/osso.gd")
const Salvataggi := preload("res://scripts/salvataggi.gd")
const PausaScript := preload("res://scripts/pausa.gd")
const MENU := "res://scenes/menu_principale.tscn"
const RemotoScript := preload("res://scripts/giocatore_remoto.gd")
const PARTI := ["Testa", "Torace", "BraccioDestro", "BraccioSinistro", "GambaDestra", "GambaSinistra"]
const INVIO_S := 0.05        # ogni quanto si mandano posizioni di giocatori e oggetti

@onready var terrain: Node3D = $Terra
@onready var player: CharacterBody3D = $Player
@onready var state: Node = $GameState
@onready var spawn: Node3D = $Spawn
@onready var hud: CanvasLayer = $HUD
@onready var secchi: Node3D = $Secchi
@onready var ossa: Node3D = $Ossa
@onready var dinamiti: Node3D = $Dinamiti
@onready var griglia: Node3D = $Griglia
@onready var binari: Node3D = $Binari
var _spinta := 0.0                    # metri di spinta al carrello da mandare al server
var _spinta_dir := Vector3.ZERO
const LavoratoreScript := preload("res://scripts/lavoratore.gd")
@onready var lying: Node3D = $Spawn/ScheletroNellaTomba

var bench := false
var bench_frames := 0
var bench_samples := PackedFloat32Array()
var frame_ms := PackedFloat32Array()

# rete
var giocatori_node: Node3D           # i giocatori remoti (GiocatoreRemoto) per id
var remoti := {}                     # id -> nodo
var dig_log := PackedFloat32Array()  # solo server: tutti gli scavi, 6 valori ciascuno
var mondo_ricevuto := false
var _prossimo_oggetto := 0
var _invio_t := 0.0
var _in_gioco := false


func _ready() -> void:
	secchio_scene = load("res://scenes/secchio.tscn")
	osso_scene = load("res://scenes/osso.tscn")
	dinamite_scene = load("res://scenes/dinamite.tscn")
	var args := OS.get_cmdline_user_args()
	bench = "--bench" in args
	if bench:
		state.capienza = 100000
		state.attrezzi = [true, true, true]
	print("Terreno generato in %d ms" % terrain.gen_ms)

	giocatori_node = Node3D.new()
	giocatori_node.name = "Giocatori"
	add_child(giocatori_node)

	player.terrain = terrain
	player.state = state
	player.interact.connect(_on_interact)
	player.fill_requested.connect(_on_fill)
	player.dynamite_requested.connect(_on_dynamite)
	player.rail_requested.connect(_on_rail)
	player.throw_requested.connect(_on_throw)
	player.pausa_richiesta.connect(_apri_pausa)
	player.scavato.connect(_on_scavato)
	player.blocked.connect(func(reason: String): hud.show_message(reason))
	# la collisione della pietra (CSG) viene creata al primo frame: aspetto prima di attivare la gravità
	player.set_physics_process(false)

	hud.buy_requested.connect(_on_buy)
	hud.shop_closed.connect(_close_shop)

	Rete.connesso.connect(_on_connesso)
	Rete.giocatori_cambiati.connect(_aggiorna_remoti)
	Rete.stato_cambiato.connect(func(t: String):
		if _in_gioco:
			hud.show_message(t))
	Rete.disconnesso.connect(_on_disconnesso)

	var i := args.find("--nome")
	if i >= 0 and i + 1 < args.size():
		Rete.nome = args[i + 1]
	if bench or "--loop" in args:
		Rete.gioca_da_solo()
	elif "--host" in args:
		var err := Rete.ospita()
		if err != "":
			push_error(err)
			get_tree().quit(1)
	elif "--join" in args:
		var j := args.find("--join")
		Rete.entra(args[j + 1] if j + 1 < args.size() else "127.0.0.1")
	else:
		# quello che ha scelto il menu principale
		var modo := Rete.modalita
		Rete.modalita = ""
		if modo == "":
			# scena aperta direttamente (es. F6 nell'editor): da solo, nell'ultimo slot
			Salvataggi.migra()
			Rete.slot = maxi(Salvataggi.ultimo(), 1)
			modo = "solo"
		match modo:
			"solo":
				Rete.gioca_da_solo()
			"ospita":
				var err := Rete.ospita()
				if err != "":
					_torna_al_menu(err)
			"entra":
				player.ui_open = true
				Rete.slot = 0   # chi entra non salva: la partita è di chi ospita
				var err := Rete.entra(Rete.indirizzo)
				if err != "":
					_torna_al_menu(err)
				else:
					hud.show_message("Mi collego a %s..." % Rete.indirizzo)

	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_physics_process(true)
	if "--loop" in args:
		_loop_test()
	if "--provarete" in args:
		_prova_rete()


## La partita è pronta (da solo, ospitata o raggiunta).
func _on_connesso() -> void:
	_in_gioco = true
	player.ui_open = false
	if not bench:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if multiplayer.is_server():
		mondo_ricevuto = true
		if Rete.nuova_partita:
			Rete.nuova_partita = false
			salva()   # lo slot ora contiene la partita nuova
			hud.show_message("Nuova partita (slot %d)" % Rete.slot)
		elif not _prova_automatica() and carica():
			hud.show_message("Partita caricata: bentornato!")
	else:
		# due giocatori non partono nello stesso punto
		var a := randf() * TAU
		player.global_position += Vector3(cos(a), 0, sin(a)) * 1.2
		hud.show_message("Connesso! Ricevo la catacomba...")
		_chiedi_mondo.rpc_id(1)
	_aggiorna_remoti()


func _on_disconnesso(motivo: String) -> void:
	if not _in_gioco:
		_torna_al_menu(motivo)   # non è riuscito a collegarsi
		return
	_in_gioco = false
	hud.show_message(motivo)
	player.ui_open = true
	await get_tree().create_timer(2.5).timeout
	_torna_al_menu(motivo)


## Torna al menu principale mostrando msg (le prove automatiche invece si chiudono).
func _torna_al_menu(msg := "") -> void:
	if _prova_automatica() or bench:
		push_error(msg)
		get_tree().quit(1)
		return
	Rete.errore = msg
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(MENU)


## Salva e torna al menu principale (dal menu di pausa).
func esci_al_menu() -> void:
	salva()
	_in_gioco = false
	Rete.esci()
	_torna_al_menu()


# --- menu di pausa ----------------------------------------------------------------

var _pausa: CanvasLayer


func _apri_pausa() -> void:
	if is_instance_valid(_pausa):
		return
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pausa = PausaScript.new()
	_pausa.main = self
	_pausa.chiusa.connect(_chiudi_pausa)
	add_child(_pausa)
	# da solo il gioco si ferma; in co-op gli altri continuano a giocare
	get_tree().paused = not Rete.online


func _chiudi_pausa() -> void:
	get_tree().paused = false
	player.ui_open = false
	if not bench:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _prova_automatica() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--loop" in args or "--provarete" in args or "--prova" in args


func _process(delta: float) -> void:
	if bench:
		_bench_step(delta)
	terrain.flush()
	if multiplayer.is_server():
		if terrain.last_remesh_chunks > 0:
			# la terra sotto i secchi può essere stata scavata: li sveglio perché ricadano
			for b in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
				(b as RigidBody3D).sleeping = false
		for b in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
			if b.global_position.y < -10.0:
				# caduto fuori dal mondo: torna vicino al montacarichi
				b.global_position = spawn.global_position + Vector3(0, 2.5, 0)
				b.linear_velocity = Vector3.ZERO
	else:
		_segui_oggetti(delta)
		_segui_lavoratori(delta)
	if bench and terrain.last_remesh_chunks > 0:
		bench_samples.append(terrain.last_remesh_ms)
		terrain.last_remesh_chunks = 0
	frame_ms.append(delta * 1000.0)
	if Rete.online and _in_gioco:
		_invio_t += delta
		if _invio_t >= INVIO_S:
			_invio_t = 0.0
			_manda_posizioni()
			if multiplayer.is_server():
				_manda_lavoratori()
				_manda_vagone()
			elif _spinta > 0.0:
				req_spingi.rpc_id(1, _spinta, _spinta_dir)
				_spinta = 0.0
	_spingi_vagone(delta)
	if multiplayer.is_server():
		_controlla_scarico()
		if _in_gioco:
			tempo_gioco += delta
			_autosalva_t += delta
			if _autosalva_t >= AUTOSALVA_S:
				_autosalva_t = 0.0
				salva()
	_update_hud()


# --- rete: aiuti --------------------------------------------------------------

## Chiama un metodo sul server (su di me se il server sono io).
func _server(metodo: String, args := []) -> void:
	if multiplayer.is_server():
		callv(metodo, args)
	else:
		callv("rpc_id", [1, metodo] + args)


## Chiama un metodo sul giocatore id (su di me se sono io).
func _a(id: int, metodo: String, args := []) -> void:
	if id == multiplayer.get_unique_id():
		callv(metodo, args)
	else:
		callv("rpc_id", [id, metodo] + args)


## Chiama un metodo qui e su tutti gli altri giocatori.
func _tutti(metodo: String, args := []) -> void:
	callv(metodo, args)
	if Rete.online:
		callv("rpc", [metodo] + args)


## Chi ha mandato la richiesta che sto eseguendo (io se l'ho chiamata da qui).
func _chi() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


## Il server manda a tutti monete, montacarichi e acquisti.
func _manda_stato() -> void:
	if multiplayer.is_server() and Rete.online:
		_stato.rpc(_stato_condiviso())


func _stato_condiviso() -> Dictionary:
	var d: Dictionary = state.esporta()
	d["binari"] = binari.esporta()
	d["cancello"] = cancello_aperto
	return d


@rpc("authority", "call_remote", "reliable")
func _stato(d: Dictionary) -> void:
	state.importa(d)
	if d.get("cancello", false) and not cancello_aperto:
		_apri_cancello(false)
	if d.has("binari") and not mondo_ricevuto:
		binari.importa(d["binari"])
	spawn.update_pile(state.pila_secchi())
	if hud.shop.visible:
		hud.refresh_shop(state)


## Messaggio a schermo mandato da un altro computer.
@rpc("authority", "call_remote", "reliable")
func _messaggio(t: String) -> void:
	hud.show_message(t)


@rpc("any_peer", "call_remote", "reliable")
func _suono(kind: String, pos: Vector3, db: float) -> void:
	player.sfx.play(kind, pos, db)


func _suono_tutti(kind: String, pos: Vector3, db := 0.0) -> void:
	_tutti("_suono", [kind, pos, db])


# --- rete: giocatori ------------------------------------------------------------

## Manda la mia posizione a tutti; il server manda anche quella degli oggetti che si muovono.
func _manda_posizioni() -> void:
	var ogg: int = player.tool_i
	if player.carrying:
		ogg = 5 if player.carried_dinamite else 4 if player.carried_osso != "" else 3
	_pos_giocatore.rpc(player.global_position, player.rotation.y, player.cam.rotation.x, ogg, player.digging, player.carried_osso)
	if multiplayer.is_server() and mondo_ricevuto:
		var nomi := PackedStringArray()
		var dati := PackedFloat32Array()
		for b: RigidBody3D in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
			if b.freeze or b.sleeping:
				continue
			nomi.append(b.name)
			var p := b.global_position
			var q := b.global_transform.basis.get_rotation_quaternion()
			dati.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w])
		if nomi.size() > 0:
			_pos_oggetti.rpc(nomi, dati)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pos_giocatore(pos: Vector3, yaw: float, pitch: float, ogg: int, scava: bool, osso: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var r := _remoto(id)
	if r:
		if r.has_meta("osso") == false or r.get_meta("osso") != osso:
			r.set_meta("osso", osso)
			r.imposta_osso(osso)
		r.aggiorna(pos, yaw, pitch, ogg, scava)


func _remoto(id: int) -> Node3D:
	if remoti.has(id):
		return remoti[id]
	if not Rete.giocatori.has(id) or id == multiplayer.get_unique_id():
		return null
	var r: Node3D = RemotoScript.new()
	r.name = "G%d" % id
	giocatori_node.add_child(r)
	r.imposta_nome(Rete.nome_di(id))
	remoti[id] = r
	return r


## L'elenco dei giocatori è cambiato: tolgo chi è uscito, aggiorno i nomi.
func _aggiorna_remoti() -> void:
	for id in remoti.keys():
		if not Rete.giocatori.has(id):
			remoti[id].queue_free()
			remoti.erase(id)
		else:
			remoti[id].imposta_nome(Rete.nome_di(id))


# --- rete: scavo ----------------------------------------------------------------

## Ho scavato: lo mando a tutti (il server lo segna per chi entrerà dopo).
func _on_scavato(pos: Vector3, raggio: float, forza: float, max_mat: int, normale: Vector3) -> void:
	if multiplayer.is_server():
		dig_log.append_array([pos.x, pos.y, pos.z, raggio, forza, max_mat])
	if Rete.online:
		_scavo.rpc(pos, raggio, forza, max_mat, normale)


## Scava qui e su tutti (dev tool, prove).
func scava_rete(pos: Vector3, raggio: float, forza: float, max_mat: int) -> Vector3:
	var v: Vector3 = terrain.dig(pos, raggio, forza, max_mat)
	_on_scavato(pos, raggio, forza, max_mat, Vector3.UP)
	return v


## Un altro giocatore ha scavato: tolgo la stessa terra, con suono e schegge.
@rpc("any_peer", "call_remote", "reliable")
func _scavo(pos: Vector3, raggio: float, forza: float, max_mat: int, normale: Vector3) -> void:
	if multiplayer.is_server():
		dig_log.append_array([pos.x, pos.y, pos.z, raggio, forza, max_mat])
	var v: Vector3 = terrain.dig(pos, raggio, forza, max_mat)
	if v.x + v.y + v.z > 0.0002 and player.global_position.distance_to(pos) < 25.0:
		var m: int = terrain.material_at(pos - normale * 0.3)
		player.sfx.play(player.SOUND_BY_MAT[m], pos, -4.0)
		player._burst(pos, normale, terrain.MAT_COLOR[m], 12)


# --- rete: chi entra riceve la partita ---------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _chiedi_mondo() -> void:
	if not multiplayer.is_server():
		return
	var oggetti := []
	for b: RigidBody3D in secchi.get_children():
		oggetti.append([b.name, "s", b.valore, b.global_transform, b.freeze])
	for b: RigidBody3D in ossa.get_children():
		oggetti.append([b.name, "o", b.parte, b.global_transform, b.freeze])
	var tomba := []
	for p in PARTI:
		if lying.ha_parte(p):
			tomba.append(p)
	var risorti: int = spawn.get_node("ScheletriRiparati").get_child_count()
	_ricevi_mondo.rpc_id(multiplayer.get_remote_sender_id(), dig_log, oggetti, _stato_condiviso(), tomba, risorti)


@rpc("authority", "call_remote", "reliable")
func _ricevi_mondo(scavi: PackedFloat32Array, oggetti: Array, stato: Dictionary, tomba: Array, risorti: int) -> void:
	var t0 := Time.get_ticks_msec()
	for k in range(0, scavi.size() - 5, 6):
		terrain.dig(Vector3(scavi[k], scavi[k + 1], scavi[k + 2]), scavi[k + 3], scavi[k + 4], int(scavi[k + 5]))
	var nomi := {}
	for o in oggetti:
		nomi[o[0]] = true
	for b in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
		if not nomi.has(String(b.name)):
			_togli(b)
	for o in oggetti:
		var b: RigidBody3D = secchi.get_node_or_null(NodePath(o[0]))
		if b == null:
			b = ossa.get_node_or_null(NodePath(o[0]))
		if b == null:
			b = _crea_oggetto(o[0], o[1], o[2], (o[3] as Transform3D).origin, Vector3.ZERO, Vector3.ZERO)
		b.global_transform = o[3]
	_stato(stato)
	for p in PARTI:
		if p in tomba:
			lying.metti_parte(p)
		else:
			lying.togli_parte(p)
	for i in risorti:
		_alza_scheletro(false)
	mondo_ricevuto = true
	print("Mondo ricevuto: %d scavi, %d oggetti in %d ms" % [scavi.size() / 6, oggetti.size(), Time.get_ticks_msec() - t0])
	hud.show_message("Sei nella partita di %s" % Rete.nome_di(1))


# --- secchi e ossa: oggetti a terra ------------------------------------------

## Crea un secchio ("s", dato = valore) o un osso ("o", dato = parte) lanciato.
## Sul server cade con la fisica; sugli altri è fermo e segue le posizioni del server.
func _crea_oggetto(nome: String, tipo: String, dato: Variant, pos: Vector3, vel: Vector3, rot: Vector3) -> RigidBody3D:
	var b: RigidBody3D
	if tipo == "d":
		b = dinamite_scene.instantiate()
		b.esplodi.connect(_on_dinamite_esplode)
	elif tipo == "s":
		b = secchio_scene.instantiate()
		b.valore = dato
	else:
		b = osso_scene.instantiate()
		b.parte = dato
	b.name = nome
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.freeze = not multiplayer.is_server()
	(secchi if tipo == "s" else ossa if tipo == "o" else dinamiti).add_child(b)
	b.global_position = pos
	b.rotation = rot
	if multiplayer.is_server():
		b.linear_velocity = vel
		b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	# il giocatore ci passa attraverso, così i secchi a terra non bloccano i corridoi
	b.add_collision_exception_with(player)
	return b


@rpc("authority", "call_remote", "reliable")
func _crea_oggetto_rete(nome: String, tipo: String, dato: Variant, pos: Vector3, vel: Vector3, rot: Vector3) -> void:
	_crea_oggetto(nome, tipo, dato, pos, vel, rot)


## Toglie subito un oggetto (raccolto da qualcuno).
func _togli(b: Node) -> void:
	b.get_parent().remove_child(b)
	b.queue_free()


@rpc("authority", "call_remote", "reliable")
func _rimuovi_oggetto(nome: String) -> void:
	var b := _trova_oggetto(nome)
	if b:
		_togli(b)


@rpc("authority", "call_remote", "unreliable_ordered")
func _pos_oggetti(nomi: PackedStringArray, dati: PackedFloat32Array) -> void:
	for i in nomi.size():
		var b := _trova_oggetto(nomi[i])
		if b == null:
			continue
		var k := i * 7
		var q := Quaternion(dati[k + 3], dati[k + 4], dati[k + 5], dati[k + 6])
		b.set_meta("bersaglio", Transform3D(Basis(q), Vector3(dati[k], dati[k + 1], dati[k + 2])))


func _trova_oggetto(nome: String) -> Node:
	for c in [secchi, ossa, dinamiti]:
		var b: Node = c.get_node_or_null(NodePath(nome))
		if b:
			return b
	return null


## Sui client gli oggetti scivolano verso l'ultima posizione mandata dal server.
func _segui_oggetti(delta: float) -> void:
	var k := 1.0 - exp(-delta * 18.0)
	for b: Node3D in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
		if b.has_meta("bersaglio"):
			var t: Transform3D = b.get_meta("bersaglio")
			b.global_transform = b.global_transform.interpolate_with(t, k)


# --- dinamite ------------------------------------------------------------------

## F: prende in mano un candelotto (la dinamite è della squadra: passa dal server).
func _on_dynamite() -> void:
	if player.ui_open:
		return
	if player.carrying:
		hud.show_message("Hai già qualcosa in mano")
	elif state.pezzi("dinamite") <= 0:
		hud.show_message("Non hai dinamite: comprala al negozio")
	else:
		_server("req_dinamite")


@rpc("any_peer", "call_remote", "reliable")
func req_dinamite() -> void:
	if not multiplayer.is_server():
		return
	var chi := _chi()
	if not state.usa("dinamite"):
		_a(chi, "_messaggio", ["La dinamite è finita"])
		return
	_manda_stato()
	_a(chi, "_in_mano", ["d", 0, Vector3.ZERO])


## La miccia è finita: il server fa esplodere il candelotto per tutti.
func _on_dinamite_esplode(b: RigidBody3D) -> void:
	if not multiplayer.is_server() or not is_instance_valid(b):
		return
	var pos := b.global_position
	scava_rete(pos, RAGGIO_ESPLOSIONE, 60.0, 2)
	_tutti("_rimuovi_oggetto", [String(b.name)])
	_tutti("_boom", [pos])
	# l'onda d'urto spinge via secchi, ossa (non sepolte) e altri candelotti
	for o: RigidBody3D in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
		if o.freeze or o == b:
			continue
		var d := o.global_position - pos
		if d.length() < RAGGIO_ESPLOSIONE * 2.0:
			o.apply_central_impulse((d.normalized() + Vector3(0, 0.6, 0)) * o.mass * 5.0 * (1.0 - d.length() / (RAGGIO_ESPLOSIONE * 2.0)))


## Effetti dell'esplosione su ogni computer: boato, lampo, schegge, scossa.
@rpc("authority", "call_remote", "reliable")
func _boom(pos: Vector3) -> void:
	player.sfx.play("boom", pos, 8.0)
	player.sfx.play("roccia", pos, 2.0)
	for i in 4:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()
		player._burst(pos, dir, terrain.MAT_COLOR[i % 3], 40)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 12.0
	flash.omni_range = 12.0
	add_child(flash)
	flash.global_position = pos
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)
	var dist := player.global_position.distance_to(pos)
	player._add_trauma(clampf(1.3 - dist / 10.0, 0.0, 1.0))


# --- secchi --------------------------------------------------------------------

## Q: riempie un secchio con 10 unità di terra e lo mette in mano.
## La terra nell'attrezzo è di ogni giocatore: non passa dal server.
func _on_fill() -> void:
	if player.ui_open:
		return
	if not player.posso_prendere_secchio():
		hud.show_message("Hai già le mani piene: lancia o posa quello che porti")
	elif not state.puo_riempire():
		hud.show_message("Servono %d unità di terra (ne hai %d)" % [state.UNITA_SECCHIO, floori(state.terra_unita())])
	else:
		player.carry(state.riempi_secchio())
		player.sfx.play("secchi", player.global_position + Vector3(0, 1.0, 0), -4.0)


## Tasto destro: lancia il secchio che hai in mano (il server lo crea per tutti).
func _on_throw() -> void:
	if not player.carrying:
		return
	var cam: Camera3D = player.cam
	var fwd := -cam.global_transform.basis.z
	var start := cam.global_position + fwd * 0.6 + Vector3(0, -0.25, 0)
	var speed := 5.5
	# se davanti c'è una parete vicina, il secchio parte da lì e con poca forza
	var hit: Dictionary = player._aim()
	if not hit.is_empty():
		var d := cam.global_position.distance_to(hit.position)
		if d < 1.0:
			start = cam.global_position + fwd * maxf(d - 0.4, 0.15) + Vector3(0, -0.2, 0)
			speed = 1.5
	speed *= state.forza_lancio()
	var v := fwd * speed + Vector3(0, 1.8, 0) + player.velocity
	if player.carried_dinamite:
		_server("req_lancia", ["d", 0, start, v])
	elif player.carried_osso != "":
		_server("req_lancia", ["o", player.carried_osso, start, v])
	else:
		_server("req_lancia", ["s", player.carried_valore, start, v])
	player.drop_carry()
	_suono_tutti("dura", start, -8.0)


@rpc("any_peer", "call_remote", "reliable")
func req_lancia(tipo: String, dato: Variant, pos: Vector3, vel: Vector3) -> void:
	if not multiplayer.is_server() or not tipo in ["s", "o", "d"]:
		return
	if tipo == "o" and not (dato in PARTI or dato == "Chiave"):
		return
	_prossimo_oggetto += 1
	var nome := "N%d" % _prossimo_oggetto
	var rot := Vector3(randf() * TAU, randf() * TAU, 0.0)
	_tutti("_crea_oggetto_rete", [nome, tipo, dato, pos, vel, rot])


## E su un secchio o un osso a terra: chiede al server di prenderlo.
func _pick_bucket(b: RigidBody3D) -> void:
	if not player.posso_prendere_secchio():
		hud.show_message("Hai già le mani piene")
		return
	_server("req_raccogli", [String(b.name)])


func _pick_bone(b: RigidBody3D) -> void:
	if player.carrying:
		hud.show_message("Hai già qualcosa in mano")
		return
	_server("req_raccogli", [String(b.name)])


@rpc("any_peer", "call_remote", "reliable")
func req_raccogli(nome: String) -> void:
	if not multiplayer.is_server():
		return
	var chi := _chi()
	var b: RigidBody3D = secchi.get_node_or_null(NodePath(nome))
	if b == null:
		b = ossa.get_node_or_null(NodePath(nome))
	if b == null:
		_a(chi, "_messaggio", ["Qualcun altro l'ha già preso"])
		return
	var pos := b.global_position
	if b.is_in_group("ossa"):
		_a(chi, "_in_mano", ["o", b.parte, pos])
	else:
		_a(chi, "_in_mano", ["s", b.valore, pos])
	_tutti("_rimuovi_oggetto", [nome])


## Il server mi dà in mano quello che ho raccolto.
@rpc("authority", "call_remote", "reliable")
func _in_mano(tipo: String, dato: Variant, pos: Vector3) -> void:
	if tipo == "d":
		player.carry_dynamite()
		hud.show_message("Dinamite in mano: tasto destro per lanciarla")
	elif tipo == "o":
		player.carry_bone(dato)
		player.sfx.play("dura", pos, -6.0)
		hud.show_message("Hai trovato: %s" % OssoScript.nome(dato))
	else:
		player.carry(dato)
		player.sfx.play("secchi", pos, -6.0)


## Il server ha accettato quello che avevo in mano (montacarichi o tomba).
@rpc("authority", "call_remote", "reliable")
func _posato() -> void:
	player.drop_carry()


# --- tomba e scheletri ----------------------------------------------------------

## E sulla tomba: posa il pezzo che hai in mano nello scheletro sdraiato.
func _place_in_tomb() -> void:
	if not player.carrying:
		hud.show_message("Porta qui le ossa che trovi scavando")
		return
	if player.carried_osso == "":
		hud.show_message("Nella tomba vanno le ossa, la terra va al montacarichi")
		return
	if player.carried_osso == "Chiave":
		hud.show_message("La chiave apre il cancello della stanza est")
		return
	_server("req_tomba", [player.carried_osso])


@rpc("any_peer", "call_remote", "reliable")
func req_tomba(parte: String) -> void:
	if not multiplayer.is_server() or not parte in PARTI:
		return
	var chi := _chi()
	if lying.ha_parte(parte):
		_a(chi, "_messaggio", ["%s è già nella tomba" % OssoScript.nome(parte)])
		return
	_a(chi, "_posato")
	_tutti("_metti_in_tomba", [parte, Rete.nome_di(chi)])
	if _pezzi_in_tomba() >= PARTI.size():
		_tutti("_alza_scheletro", [true])


@rpc("authority", "call_remote", "reliable")
func _metti_in_tomba(parte: String, chi: String) -> void:
	lying.metti_parte(parte)
	player.sfx.play("dura", spawn.to_global(spawn.TOMB_POS) + Vector3(0, 0.6, 0), -4.0)
	var n := _pezzi_in_tomba()
	if n < PARTI.size():
		var testo := "%s nella tomba (%d / %d)" % [OssoScript.nome(parte), n, PARTI.size()]
		if Rete.online:
			testo = "%s: %s" % [chi, testo]
		hud.show_message(testo)


func _pezzi_in_tomba() -> int:
	var n := 0
	for p in PARTI:
		if lying.ha_parte(p):
			n += 1
	return n


## Scheletro completo: si alza dalla tomba e resta in piedi accanto, in idle.
## La tomba torna vuota per il prossimo scheletro.
@rpc("authority", "call_remote", "reliable")
func _alza_scheletro(con_suoni: bool) -> void:
	var risen: Node3D = load("res://scenes/scheletro.tscn").instantiate()
	var holder: Node3D = spawn.get_node("ScheletriRiparati")
	holder.add_child(risen)
	risen.transform = lying.transform
	for p in PARTI:
		lying.togli_parte(p)
	# atterra davanti alla tomba (verso il centro della stanza), uno accanto all'altro
	var n := holder.get_child_count() - 1
	var dest: Vector3 = spawn.TOMB_POS + Vector3(-0.6 + 0.9 * (n % 3), 0, -1.35 - 0.9 * (n / 3))
	risen.alzati(spawn.TOMB_HIP, spawn.TOMB_YAW, dest, PI - 0.25)
	# sul server lo scheletro diventa un lavoratore (dopo che si è alzato)
	if multiplayer.is_server():
		if not griglia.pronto:
			griglia.costruisci(terrain, [terrain.body.get_rid(), player.get_rid()] as Array[RID])
		var w: Node = LavoratoreScript.new()
		w.name = "Lavoratore"
		w.main = self
		w.griglia = griglia
		risen.add_child(w)
	if not con_suoni:
		return
	hud.show_message("Lo scheletro è completo!")
	player.sfx.play("dura", spawn.to_global(spawn.TOMB_POS), -6.0)
	get_tree().create_timer(1.0).timeout.connect(func(): player.sfx.play("pietra", spawn.to_global(spawn.TOMB_POS), -4.0))
	get_tree().create_timer(3.9).timeout.connect(func(): player.sfx.play("pietra", spawn.to_global(dest), -2.0))


# --- scheletri lavoratori (li comanda il server) --------------------------------

## Centro del montacarichi (globale).
func lift_pos() -> Vector3:
	return spawn.to_global(spawn.LIFT_POS)


## Uno scheletro raccoglie un secchio da terra.
func lavoratore_prende(b: RigidBody3D) -> void:
	_tutti("_rimuovi_oggetto", [String(b.name)])


## Uno scheletro posa un secchio sul montacarichi. false se è in viaggio o pieno.
func lavoratore_impila(valore: int) -> bool:
	if spawn.busy or not state.impila(valore):
		return false
	spawn.update_pile(state.pila_secchi())
	_manda_stato()
	_suono_tutti("secchi", spawn.lift_sound_pos(), -3.0)
	return true


## Suono e schegge di un colpo dello scheletro (qui; sugli altri li fa _scavo).
func lavoratore_suono(pos: Vector3, v: Vector3) -> void:
	if v.x + v.y + v.z > 0.002 and player.global_position.distance_to(pos) < 25.0:
		var m: int = terrain.material_at(pos)
		player.sfx.play(player.SOUND_BY_MAT[m], pos, -6.0)
		player._burst(pos, Vector3.UP, terrain.MAT_COLOR[m], 8)


## Il server manda a tutti dove sono gli scheletri risorti e cosa fanno.
func _manda_lavoratori() -> void:
	var dati := []
	for sk: Node3D in spawn.get_node("ScheletriRiparati").get_children():
		dati.append([sk.global_position, sk.global_rotation.y, sk.azione, sk.get_node("Corpo/SecchioInMano").visible])
	if not dati.is_empty():
		_pos_lavoratori.rpc(dati)


@rpc("authority", "call_remote", "unreliable_ordered")
func _pos_lavoratori(dati: Array) -> void:
	var lista := spawn.get_node("ScheletriRiparati").get_children()
	for i in mini(dati.size(), lista.size()):
		var sk: Node3D = lista[i]
		if sk.rising:
			continue
		sk.set_meta("bersaglio", [dati[i][0], dati[i][1]])
		sk.azione = dati[i][2]
		sk.porta_secchio(dati[i][3])


func _segui_lavoratori(delta: float) -> void:
	var k := 1.0 - exp(-delta * 12.0)
	for sk: Node3D in spawn.get_node("ScheletriRiparati").get_children():
		if sk.has_meta("bersaglio") and not sk.rising:
			var b: Array = sk.get_meta("bersaglio")
			sk.global_position = sk.global_position.lerp(b[0], k)
			sk.global_rotation.y = lerp_angle(sk.global_rotation.y, b[1], k)


# --- cancello della zona --------------------------------------------------------

var cancello_aperto := false

# --- salvataggio (solo chi ospita o gioca da solo) -------------------------------

const AUTOSALVA_S := 60.0
var _autosalva_t := 0.0
var tempo_gioco := 0.0       # secondi giocati in questa partita (si salvano)


## Salva la partita nello slot Rete.slot (scripts/salvataggi.gd): soldi e livelli, rotaie
## e carrello, cancello, tutta la terra scavata, secchi e ossa a terra, tomba, scheletri
## risorti, posizione del giocatore, tempo di gioco. true se ha salvato.
func salva() -> bool:
	if not multiplayer.is_server() or bench or Rete.slot <= 0:
		return false
	if _prova_automatica():
		return false   # le prove automatiche non toccano le partite salvate
	var oggetti := []
	for b: RigidBody3D in secchi.get_children():
		oggetti.append(["s", b.valore, b.global_transform, false, String(b.name)])
	for b: RigidBody3D in ossa.get_children():
		oggetti.append(["o", b.parte, b.global_transform, b.freeze, String(b.name)])
	var tomba := []
	for p in PARTI:
		if lying.ha_parte(p):
			tomba.append(p)
	var d := {
		"versione": 1,
		"stato": _stato_condiviso(),
		"scavi": dig_log,
		"oggetti": oggetti,
		"tomba": tomba,
		"risorti": spawn.get_node("ScheletriRiparati").get_child_count(),
		"giocatore": player.global_transform,
		"tempo": tempo_gioco,
	}
	return Salvataggi.scrivi(Rete.slot, d)


## Carica la partita dello slot Rete.slot (se c'è). Restituisce true se l'ha caricata.
func carica() -> bool:
	var d := Salvataggi.leggi(Rete.slot)
	if d.get("versione", 0) != 1:
		return false
	tempo_gioco = d.get("tempo", 0.0)
	dig_log = d["scavi"]
	for k in range(0, dig_log.size() - 5, 6):
		terrain.dig(Vector3(dig_log[k], dig_log[k + 1], dig_log[k + 2]), dig_log[k + 3], dig_log[k + 4], int(dig_log[k + 5]))
	for b in secchi.get_children() + ossa.get_children() + dinamiti.get_children():
		_togli(b)
	for o in d["oggetti"]:
		_prossimo_oggetto += 1
		var nome: String = o[4] if o.size() > 4 else "N%d" % _prossimo_oggetto
		var b := _crea_oggetto(nome, o[0], o[1], (o[2] as Transform3D).origin, Vector3.ZERO, Vector3.ZERO)
		b.global_transform = o[2]
		b.freeze = o[3]
	binari.importa(d["stato"].get("binari", {}))
	_stato(d["stato"])
	for p in PARTI:
		if p in d["tomba"]:
			lying.metti_parte(p)
	for i in d["risorti"]:
		_alza_scheletro(false)
	player.global_transform = d["giocatore"]
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		salva()


@rpc("any_peer", "call_remote", "reliable")
func req_cancello() -> void:
	if not multiplayer.is_server() or cancello_aperto:
		return
	_a(_chi(), "_posato")
	_tutti("_apri_cancello", [true])
	_manda_stato()


## Apre il cancello: le sbarre salgono e il passaggio si libera.
@rpc("authority", "call_remote", "reliable")
func _apri_cancello(animato: bool) -> void:
	cancello_aperto = true
	var g := get_node_or_null("Cancello")
	if g == null:
		return
	var bars := g.get_node("Sbarre") as Node3D
	(g.get_node("Blocco/Collisione") as CollisionShape3D).set_deferred("disabled", true)
	g.get_node("Blocco").remove_meta("interact")
	g.get_node("Scritta").text = "Prossima zona: in arrivo"
	if animato:
		var tw := create_tween()
		tw.tween_property(bars, "position:y", 3.0, 2.5).set_trans(Tween.TRANS_SINE)
		player.sfx.play("pietra", g.global_position + Vector3(0, 1, 0), 2.0)
		player.sfx.play("roccia", g.global_position + Vector3(0, 2, 0), 0.0)
		hud.show_message("Il cancello si apre!")
	else:
		bars.position.y = 3.0


# --- rotaie e carrello ----------------------------------------------------------

## R: posa una rotaia sul pavimento che guardi, o toglie quella che guardi.
func _on_rail() -> void:
	if player.ui_open:
		return
	var hit: Dictionary = player._aim()
	if hit.is_empty():
		return
	var c: Vector2i = binari.cella(hit.position)
	if binari.celle.has(c):
		_server("req_rotaia", [c, false])
	elif hit.position.y < binari.PAV + 0.35 and hit.normal.y > 0.7:
		if state.pezzi("rotaie") <= 0:
			hud.show_message("Non hai rotaie: comprale al negozio")
		else:
			_server("req_rotaia", [c, true])
	else:
		hud.show_message("Le rotaie vanno sul pavimento")


@rpc("any_peer", "call_remote", "reliable")
func req_rotaia(c: Vector2i, metti: bool) -> void:
	if not multiplayer.is_server():
		return
	if metti:
		if binari.celle.has(c) or not state.usa("rotaie"):
			return
		_tutti("_rotaia", [c, true])
		if state.livello("vagone") > 0 and binari.vagone == null:
			binari.crea_vagone(lift_pos())
			_manda_vagone()
	else:
		if not binari.celle.has(c):
			return
		if binari.vagone and (c == binari.a or c == binari.b):
			_a(_chi(), "_messaggio", ["C'è sopra il carrello"])
			return
		state.rendi("rotaie")
		_tutti("_rotaia", [c, false])
	_manda_stato()
	_suono_tutti("pietra", binari.centro(c), -8.0)


@rpc("authority", "call_remote", "reliable")
func _rotaia(c: Vector2i, metti: bool) -> void:
	if metti:
		binari.metti(c)
	else:
		binari.togli(c)


## Spinta: se cammino contro il carrello, lo spingo nella direzione in cui vado.
func _spingi_vagone(delta: float) -> void:
	if binari.vagone == null or player.dev_volo:
		return
	var v := Vector3(player.velocity.x, 0, player.velocity.z)
	if v.length() < 0.5:
		return
	var d: Vector3 = binari.vagone.global_position - player.global_position
	d.y = 0
	if d.length() > 1.1 or d.dot(v) <= 0.0:
		return
	var s := v.length() * delta
	if multiplayer.is_server():
		binari.spingi(s, v.normalized())
	else:
		_spinta += s
		_spinta_dir = v.normalized()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func req_spingi(s: float, dir: Vector3) -> void:
	if multiplayer.is_server():
		binari.spingi(clampf(s, 0.0, 1.0), dir)


func _manda_vagone() -> void:
	if Rete.online and binari.vagone:
		_pos_vagone.rpc(binari.a, binari.b, binari.u, binari.carico.size())


@rpc("authority", "call_remote", "unreliable_ordered")
func _pos_vagone(a: Vector2i, b: Vector2i, u: float, n: int) -> void:
	if binari.vagone == null:
		binari.vagone = (load("res://scenes/vagone.tscn") as PackedScene).instantiate()
		binari.add_child(binari.vagone)
	binari.a = a
	binari.b = b
	binari.u = u
	binari._posiziona()
	binari.mostra_carico(n)


@rpc("any_peer", "call_remote", "reliable")
func req_carica(valori: Array) -> void:
	if not multiplayer.is_server():
		return
	var chi := _chi()
	var n: int = binari.carica(valori.slice(0, 3))
	if n == 0:
		_a(chi, "_messaggio", ["Il carrello è pieno"])
		return
	for i in n:
		_a(chi, "_posato")
	_suono_tutti("secchi", binari.vagone.global_position, -4.0)
	_manda_vagone()


var _scarico_t := 0.0


## Carrello fermo accanto al montacarichi con dei secchi: si ribalta e li scarica.
func _controlla_scarico() -> void:
	if binari.vagone == null or binari.carico.is_empty() or binari.ribaltando > 0.0 or spawn.busy:
		return
	var d := Vector2(binari.vagone.global_position.x - lift_pos().x, binari.vagone.global_position.z - lift_pos().z)
	if d.length() > 2.6:
		_scarico_t = 0.0
		return
	_scarico_t += get_process_delta_time()
	if _scarico_t < 0.6:
		return
	_scarico_t = 0.0
	var n := 0
	while not binari.carico.is_empty() and state.impila(binari.carico[0]):
		binari.carico.remove_at(0)
		n += 1
	if n == 0:
		return
	_tutti("_ribalta")
	spawn.update_pile(state.pila_secchi())
	_manda_stato()
	_manda_vagone()
	get_tree().create_timer(0.6).timeout.connect(func(): binari.mostra_carico(binari.carico.size()))


@rpc("authority", "call_remote", "reliable")
func _ribalta() -> void:
	binari.ribalta()
	player.sfx.play("secchi", binari.vagone.global_position, 0.0)
	player.sfx.play("dura", binari.vagone.global_position, -4.0)


## Usato dal dev tool: completa la tomba (passa dal server).
func _skeleton_rises() -> void:
	_server("req_dev", ["completa_tomba"])


# --- interazioni ---------------------------------------------------------------

func _on_interact(id: String) -> void:
	match id:
		"secchio":
			if is_instance_valid(player.look_collider):
				_pick_bucket(player.look_collider)
		"osso":
			if is_instance_valid(player.look_collider):
				_pick_bone(player.look_collider)
		"tomba":
			_place_in_tomb()
		"montacarichi":
			if spawn.busy:
				hud.show_message("Il montacarichi è in viaggio")
			elif not player.carrying:
				hud.show_message("Porta qui un secchio pieno (Q per riempirlo)")
			elif player.carried_osso != "":
				hud.show_message("Le ossa vanno nella tomba")
			else:
				_server("req_impila_tutti", [player.secchi_in_mano.duplicate()])
		"leva":
			if spawn.busy:
				hud.show_message("Il montacarichi è in viaggio")
			elif state.pila_secchi() < 1:
				hud.show_message("Non c'è niente da mandare su")
			else:
				_server("req_leva")
		"cancello":
			if cancello_aperto:
				pass
			elif player.carried_osso == "Chiave":
				_server("req_cancello")
			else:
				hud.show_message("Il cancello è chiuso: serve la chiave. Scava per trovarla")
		"vagone":
			if not player.carrying or player.carried_osso != "" or player.carried_dinamite:
				hud.show_message("Metti nel carrello i secchi pieni (fino a %d)" % binari.CAPIENZA)
			else:
				_server("req_carica", [player.secchi_in_mano.duplicate()])
		"negozio":
			_open_shop()
		"chiudi":
			_close_shop()


@rpc("any_peer", "call_remote", "reliable")
func req_impila(valore: int) -> void:
	if not multiplayer.is_server():
		return
	var chi := _chi()
	if spawn.busy:
		_a(chi, "_messaggio", ["Il montacarichi è in viaggio"])
	elif not state.impila(clampi(valore, 0, 1000)):
		_a(chi, "_messaggio", ["Il montacarichi è pieno: tira la leva"])
	else:
		_a(chi, "_posato")
		spawn.update_pile(state.pila_secchi())
		_manda_stato()
		_suono_tutti("secchi", spawn.lift_sound_pos())


## Posa sul montacarichi tutti i secchi che il giocatore porta (finché c'è posto).
@rpc("any_peer", "call_remote", "reliable")
func req_impila_tutti(valori: Array) -> void:
	if not multiplayer.is_server():
		return
	var chi := _chi()
	if spawn.busy:
		_a(chi, "_messaggio", ["Il montacarichi è in viaggio"])
		return
	var n := 0
	for v in valori.slice(0, 3):
		if not state.impila(clampi(int(v), 0, 1000)):
			break
		n += 1
	if n == 0:
		_a(chi, "_messaggio", ["Il montacarichi è pieno: tira la leva"])
		return
	for i in n:
		_a(chi, "_posato")
	spawn.update_pile(state.pila_secchi())
	_manda_stato()
	_suono_tutti("secchi", spawn.lift_sound_pos())
	if n < valori.size():
		_a(chi, "_messaggio", ["Il montacarichi è pieno: tira la leva"])


@rpc("any_peer", "call_remote", "reliable")
func req_leva() -> void:
	if not multiplayer.is_server():
		return
	if spawn.busy:
		_a(_chi(), "_messaggio", ["Il montacarichi è in viaggio"])
	elif state.pila_secchi() < 1:
		_a(_chi(), "_messaggio", ["Non c'è niente da mandare su"])
	else:
		_tutti("_leva")


## Il montacarichi sale (su tutti i computer); in cima il server vende la pila.
@rpc("authority", "call_remote", "reliable")
func _leva() -> void:
	player.sfx.play("dura", spawn.lever_sound_pos(), -4.0)
	spawn.send(_on_lift_top)


func _on_lift_top() -> void:
	if not multiplayer.is_server():
		return
	var coins: int = state.vendi_pila()
	get_tree().create_timer(0.1).timeout.connect(salva)
	spawn.update_pile(0)
	_manda_stato()
	_tutti("_monete_guadagnate", [coins])


@rpc("authority", "call_remote", "reliable")
func _monete_guadagnate(coins: int) -> void:
	player.sfx.play("monete", player.global_position + Vector3(0, 1.5, 0))
	hud.show_message("+%d monete" % coins)


func _open_shop() -> void:
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_shop(state)


func _close_shop() -> void:
	player.ui_open = false
	hud.close_shop()
	if not bench:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Le monete sono della squadra: l'acquisto passa dal server e vale per tutti.
func _on_buy(id: String) -> void:
	_server("req_compra", [id])


@rpc("any_peer", "call_remote", "reliable")
func req_compra(id: String) -> void:
	if not multiplayer.is_server():
		return
	var chi := _chi()
	var err: String = state.compra(id)
	if err == "":
		if id == "vagone" and binari.vagone == null and binari.crea_vagone(lift_pos()):
			_manda_vagone()
		_manda_stato()
		if Rete.online:
			for altro in Rete.giocatori:
				if altro != chi:
					_a(altro, "_messaggio", ["%s ha comprato: %s" % [Rete.nome_di(chi), _nome_oggetto(id)]])
	_a(chi, "_esito_compra", [id, err])


func _nome_oggetto(id: String) -> String:
	var it: Dictionary = state.voce(id)
	if it.is_empty():
		return id
	if it["tipo"] == "livelli":
		return "%s (livello %d)" % [it["nome"], state.livello(id)]
	return it["nome"]


@rpc("authority", "call_remote", "reliable")
func _esito_compra(id: String, err: String) -> void:
	if err != "":
		hud.set_shop_status(err)
		return
	player.sfx.play("monete", player.global_position + Vector3(0, 1.5, 0), -3.0)
	if id == "pala" and state.livello("pala") == 1:
		player.tool_i = 1
	elif id == "piccone" and state.livello("piccone") == 1:
		player.tool_i = 2
	hud.set_shop_status("")
	hud.refresh_shop(state)


## Comandi del dev tool che cambiano la partita condivisa: li esegue il server.
@rpc("any_peer", "call_remote", "reliable")
func req_dev(cmd: String) -> void:
	if not multiplayer.is_server():
		return
	match cmd:
		"monete100":
			state.monete += 100
		"monete1000":
			state.monete += 1000
		"attrezzi":
			for id in ["pala", "piccone", "contenitore"]:
				state.livelli[id] = maxi(state.livello(id), 1)
			state._applica()
		"montacarichi10":
			for i in 10:
				state.impila(10)
			spawn.update_pile(state.pila_secchi())
		"completa_tomba":
			for p in PARTI:
				if not lying.ha_parte(p):
					_tutti("_metti_in_tomba", [p, "dev"])
			_tutti("_alza_scheletro", [true])
		"svuota_tomba":
			_tutti("_svuota_tomba")
	_manda_stato()


@rpc("authority", "call_remote", "reliable")
func _svuota_tomba() -> void:
	for p in PARTI:
		lying.togli_parte(p)


func _update_hud() -> void:
	var pila: int = state.pila_secchi()
	var text := "Monete: %d\nTerra: %d / %d unità\nAttrezzo: %s" % [
		state.monete, floori(state.terra_unita()), state.capienza, player.tool_name()]
	if state.pezzi("dinamite") > 0 or player.carried_dinamite:
		text += "\nDinamite: %d / 4" % state.pezzi("dinamite")
	if player.carried_dinamite:
		text += "\nIn mano: dinamite"
	elif player.carried_osso == "Chiave":
		text += "\nIn mano: la chiave (portala al cancello della stanza est)"
	elif player.carrying and player.carried_osso != "":
		text += "\nIn mano: %s (portalo nella tomba)" % OssoScript.nome(player.carried_osso)
	elif player.carrying:
		var tot := 0
		for v in player.secchi_in_mano:
			tot += v
		if player.secchi_in_mano.size() > 1:
			text += "\nSecchi in mano: %d / %d (valgono %d monete)" % [player.secchi_in_mano.size(), state.gerla(), tot]
		else:
			text += "\nSecchio in mano: vale %d monete" % player.carried_valore
	text += "\nScheletro: %d / %d pezzi nella tomba" % [_pezzi_in_tomba(), PARTI.size()]
	if pila >= 1:
		text += "\nMontacarichi: %d / %d secchi (vale %d monete)" % [pila, state.pila_max(), state.valore_pila()]
	hud.info.text = text

	var w := ""
	if player.terra_piena and not player.carrying:
		w = "Attrezzo pieno: premi Q per riempire un secchio"
	hud.warning.text = w

	var p := ""
	match player.look_target:
		"montacarichi":
			if spawn.busy:
				p = "Il montacarichi è in viaggio"
			elif player.carrying and player.carried_osso != "":
				p = "Le ossa vanno nella tomba"
			elif player.carrying:
				p = "E  posa %s (%d / %d)" % ["i secchi" if player.secchi_in_mano.size() > 1 else "il secchio", pila, state.pila_max()]
			else:
				p = "Porta qui i secchi pieni"
		"leva":
			if spawn.busy:
				p = "Il montacarichi è in viaggio"
			elif pila >= 1:
				p = "E  manda su %d secchi: %d monete (bonus +%d%%)" % [pila, state.valore_pila(), roundi(state.bonus_pila() * 100)]
			else:
				p = "Il montacarichi è vuoto"
		"secchio":
			p = "E  raccogli il secchio" if player.posso_prendere_secchio() else "Hai già le mani piene"
		"osso":
			if player.carrying:
				p = "Hai già qualcosa in mano"
			elif is_instance_valid(player.look_collider):
				p = "E  raccogli: %s" % OssoScript.nome(player.look_collider.parte)
		"tomba":
			if player.carrying and player.carried_osso != "":
				p = "E  metti nella tomba: %s (%d / %d)" % [OssoScript.nome(player.carried_osso), _pezzi_in_tomba(), PARTI.size()]
			else:
				p = "Tomba: %d / %d pezzi dello scheletro" % [_pezzi_in_tomba(), PARTI.size()]
		"negozio":
			p = "E  apri il negozio"
		"cancello":
			p = "E  apri il cancello con la chiave" if player.carried_osso == "Chiave" else "Cancello chiuso: serve la chiave"
		"vagone":
			if player.carrying and player.carried_osso == "" and not player.carried_dinamite:
				p = "E  metti i secchi nel carrello (%d / %d)" % [binari.carico.size(), binari.CAPIENZA]
			else:
				p = "Carrello: %d / %d secchi. Spingilo camminandoci contro" % [binari.carico.size(), binari.CAPIENZA]
		_:
			if player.carrying:
				p = "Tasto destro  lancia " + ("la dinamite (esplode dopo 3 s)" if player.carried_dinamite else "la chiave" if player.carried_osso == "Chiave" else "l'osso" if player.carried_osso != "" else "il secchio")
			elif state.puo_riempire():
				p = "Q  riempi un secchio"
			elif state.pezzi("dinamite") > 0:
				p = "F  prendi la dinamite"
			if p == "" and state.pezzi("rotaie") > 0:
				p = "R  posa una rotaia (%d)" % state.pezzi("rotaie")
			if player.carrying and player.carried_osso == "" and player.posso_prendere_secchio() and state.puo_riempire():
				p += "   Q  riempine un altro"
	hud.prompt.text = p if not player.ui_open else ""

	hud.debug.text = "FPS %d   ricalcolo %.1f ms (picco %.1f)   attrezzi: 1 mani%s%s" % [
		Engine.get_frames_per_second(), terrain.last_remesh_ms, terrain.max_remesh_ms,
		"  2 pala" if state.attrezzi[1] else "", "  3 piccone" if state.attrezzi[2] else ""]
	if Rete.online:
		var nomi := []
		for id in Rete.giocatori:
			nomi.append(Rete.nome_di(id) + (" (ospita)" if id == 1 else ""))
		hud.debug.text += "\nOnline: " + ", ".join(nomi)
		if multiplayer.is_server():
			hud.debug.text += "
" + (Rete.stato_upnp if Rete.stato_upnp != "" else "Cerco il router per aprire la porta UDP %d..." % Rete.PORTA)


# --- prove automatiche ---------------------------------------------------------

## Prova in rete: avviare prima "-- --host --provarete", poi "-- --join 127.0.0.1 --provarete".
## Il client lancia un secchio, lo raccoglie, lo posa, tira la leva, compra la pala e
## scava; il server aspetta e stampa quello che vede. Poi chiudono tutti e due.
func _prova_rete() -> void:
	var out := []
	if multiplayer.is_server():
		# uno scavo prima che entri il client: deve riceverlo con la partita
		var v0 := scava_rete(spawn.global_position + Vector3(0, 3.0, 7.5), 0.9, 3.0, 2)
		print("SERVER scavo iniziale %.3f m3" % (v0.x + v0.y + v0.z))
		var t0 := 0.0
		var visto := ""
		while t0 < 60.0 and (visto == "" or Rete.giocatori.size() > 1):
			await get_tree().create_timer(0.2).timeout
			t0 += 0.2
			for id in remoti:
				visto = "%s a %s" % [Rete.nome_di(id), remoti[id].global_position]
		out.append("SERVER ho visto: %s" % visto)
		out.append("SERVER monete=%d pila=%d pala=%s scavi_registrati=%d terra_rimossa=%.2f secchi_a_terra=%d tomba=%d" % [
			state.monete, state.pila_secchi(), state.attrezzi[1], dig_log.size() / 6, terrain.removed_volume,
			secchi.get_child_count(), _pezzi_in_tomba()])
		print("\n".join(out))
		get_tree().quit()
		return
	var t := 0.0
	while not mondo_ricevuto and t < 20.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	out.append("CLIENT connesso=%s mondo=%s id=%d giocatori=%s ossa=%d" % [Rete.online, mondo_ricevuto, multiplayer.get_unique_id(), Rete.giocatori.values(), ossa.get_child_count()])
	out.append("CLIENT terra già scavata dal server: %.3f m3" % terrain.removed_volume)
	state.aggiungi_terra(Vector3(2.5, 0.0, 0.0))
	_on_fill()
	_on_throw()
	await get_tree().create_timer(2.5).timeout
	out.append("CLIENT lanciato: in mano=%s secchi=%d" % [player.carrying, secchi.get_child_count()])
	if secchi.get_child_count() > 0:
		var b: RigidBody3D = secchi.get_child(0)
		out.append("CLIENT secchio %s a y=%.2f" % [b.name, b.global_position.y])
		_pick_bucket(b)
		await get_tree().create_timer(0.5).timeout
	out.append("CLIENT raccolto: in mano=%s valore=%d secchi=%d" % [player.carrying, player.carried_valore, secchi.get_child_count()])
	_on_interact("montacarichi")
	await get_tree().create_timer(0.5).timeout
	out.append("CLIENT posato: pila=%d in mano=%s" % [state.pila_secchi(), player.carrying])
	_on_interact("leva")
	await get_tree().create_timer(4.5).timeout
	out.append("CLIENT venduto: monete=%d pila=%d" % [state.monete, state.pila_secchi()])
	_server("req_dev", ["monete100"])
	await get_tree().create_timer(0.5).timeout
	_on_buy("pala")
	await get_tree().create_timer(0.5).timeout
	out.append("CLIENT pala=%s monete=%d attrezzo=%s" % [state.attrezzi[1], state.monete, player.tool_name()])
	# scava come farebbe il giocatore: un colpo davanti allo spawn
	var v := scava_rete(spawn.global_position + Vector3(7.5, 3.0, 0), 0.9, 3.0, 2)
	out.append("CLIENT scavato %.3f m3, totale qui %.2f" % [v.x + v.y + v.z, terrain.removed_volume])
	# porta un osso nella tomba
	_pick_bone(ossa.get_node("Testa"))
	await get_tree().create_timer(0.5).timeout
	_place_in_tomb()
	await get_tree().create_timer(0.5).timeout
	out.append("CLIENT tomba=%d in mano=%s ossa=%d" % [_pezzi_in_tomba(), player.carrying, ossa.get_child_count()])
	out.append("CLIENT remoti=%d  io a %s" % [remoti.size(), player.global_position])
	print("\n".join(out))
	get_tree().quit()


## Prova del ciclo: riempie un secchio, lo lancia, lo raccoglie, lo posa, impila,
## vende, compra la pala. Stampa i passaggi e salva uno screenshot in shot.png.
func _loop_test() -> void:
	var out := []
	state.aggiungi_terra(Vector3(2.5, 0.0, 0.0))
	out.append("terra=%.1f piena=%s puo_riempire=%s" % [state.terra_unita(), state.terra_piena(), state.puo_riempire()])
	_on_fill()
	out.append("in mano=%s valore=%d terra=%.1f" % [player.carrying, player.carried_valore, state.terra_unita()])
	_on_fill()   # già in mano: non deve crearne un altro
	_on_throw()
	out.append("lanciato: in mano=%s secchi a terra=%d" % [player.carrying, secchi.get_child_count()])
	await get_tree().create_timer(2.5).timeout
	var b: RigidBody3D = secchi.get_child(0)
	out.append("secchio a y=%.2f (pavimento 2.0) fermo=%s" % [b.global_position.y, b.linear_velocity.length() < 0.05])
	_pick_bucket(b)
	await get_tree().process_frame
	out.append("raccolto: in mano=%s secchi a terra=%d" % [player.carrying, secchi.get_child_count()])
	_on_interact("montacarichi")
	out.append("posato: pila=%d in mano=%s" % [state.pila_secchi(), player.carrying])
	for i in 9:
		state.aggiungi_terra(Vector3(2.5, 0.0, 0.0))
		_on_fill()
		_on_interact("montacarichi")
	out.append("pila=%d valore=%d bonus=%.1f" % [state.pila_secchi(), state.valore_pila(), state.bonus_pila()])
	_on_interact("leva")
	await get_tree().create_timer(4.5).timeout
	out.append("monete=%d pila=%d busy=%s" % [state.monete, state.pila_secchi(), spawn.busy])
	out.append("compra pala: '%s' monete=%d pala=%s" % [state.compra("pala"), state.monete, state.attrezzi[1]])
	out.append("compra piccone: '%s'" % state.compra("piccone"))
	# ossa: ce ne sono 6 sepolte; raccolgo la testa, la lancio, la riprendo e la poso
	out.append("ossa sepolte=%d tomba=%d" % [ossa.get_child_count(), _pezzi_in_tomba()])
	_pick_bone(ossa.get_node("Testa"))
	await get_tree().process_frame
	_on_interact("montacarichi")   # rifiutato: le ossa vanno nella tomba
	_on_throw()
	out.append("testa lanciata: in mano=%s ossa=%d" % [player.carrying, ossa.get_child_count()])
	await get_tree().create_timer(2.0).timeout
	_pick_bone(ossa.get_child(ossa.get_child_count() - 1))
	await get_tree().process_frame
	_place_in_tomb()
	out.append("testa posata: tomba=%d in mano=%s" % [_pezzi_in_tomba(), player.carrying])
	for ob in ossa.get_children():
		_pick_bone(ob)
		await get_tree().process_frame
		_place_in_tomb()
	out.append("tutte posate: scheletri in piedi=%d tomba=%d ossa a terra=%d" % [
		spawn.get_node("ScheletriRiparati").get_child_count(), _pezzi_in_tomba(), ossa.get_child_count()])
	await get_tree().create_timer(4.8).timeout
	var risen: Node3D = spawn.get_node("ScheletriRiparati").get_child(0)
	out.append("scheletro: completo=%s animazione=%s" % [risen.completo(), risen.anim.current_animation])
	# qualche secchio lanciato e uno in mano, per lo screenshot
	player.set_physics_process(false)
	player.position = spawn.position + Vector3(1.0, 2.1, 1.2)
	player.rotation.y = 1.0
	player.cam.rotation.x = -0.25
	for i in 4:
		req_lancia("s", 10, spawn.position + Vector3(0.6 * i - 1.5, 3.2, 0.8), Vector3(0, 0, -1.0))
	state.aggiungi_terra(Vector3(2.5, 0.0, 0.0))
	_on_fill()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shot.png"))
	print("\n".join(out))
	get_tree().quit()


## Prova di prestazioni: davanti al corridoio est, il giocatore scava la terra
## che lo riempie, prima con la pala poi col piccone, per 6 secondi in tutto.
func _bench_step(_delta: float) -> void:
	bench_frames += 1
	if bench_frames < 10:
		player.position = spawn.position + Vector3(4.5, 2.1, 0)
		player.rotation.y = -PI / 2.0
		return
	var t := (bench_frames - 10) / 60.0
	player.tool_i = 1 if t < 3.0 else 2
	player.rotation.y = -PI / 2.0 + 0.5 * sin(t * 1.5)
	player.cam.rotation.x = -0.1 + 0.25 * sin(t * 2.0)
	player.force_dig = true
	if t >= 6.0:
		_bench_finish()


func _bench_finish() -> void:
	bench = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(ProjectSettings.globalize_path("res://shot.png"))
	var s := bench_samples.duplicate()
	s.sort()
	var avg := 0.0
	for v in s:
		avg += v
	avg /= maxf(s.size(), 1)
	var f := frame_ms.duplicate()
	f.sort()
	var lines := [
		"generazione_ms=%d" % terrain.gen_ms,
		"ricalcoli=%d" % s.size(),
		"ricalcolo_medio_ms=%.2f" % avg,
		"ricalcolo_mediana_ms=%.2f" % (s[s.size() / 2] if s.size() > 0 else 0.0),
		"ricalcolo_max_ms=%.2f" % (s[-1] if s.size() > 0 else 0.0),
		"frame_mediana_ms=%.2f" % f[f.size() / 2],
		"frame_max_ms=%.2f" % f[-1],
		"terra_rimossa_m3=%.2f" % terrain.removed_volume,
		"chunk_con_mesh=%d" % terrain.chunk_nodes.size(),
	]
	var file := FileAccess.open(ProjectSettings.globalize_path("res://bench.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("\n".join(lines))
	get_tree().quit()
