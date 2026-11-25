extends Node3D
## Scena principale del prototipo. Tutti gli elementi sono nodi della scena main.tscn:
## Catacomba (pezzi del Modular Cave Kit), Soffitto, Terra, Spawn (montacarichi, leva, negozio),
## Secchi (i secchi lanciati), Player, HUD.
## Questo script collega le interazioni e aggiorna l'interfaccia.
##
## Ciclo: scavi -> la terra va nell'attrezzo -> Q riempie un secchio (10 unità) ->
## lo lanci (tasto destro) -> lo raccogli (E) -> lo posi sul montacarichi (E) ->
## leva: la pila sale e viene venduta -> negozio.
##
## Avvio normale: si gioca.
## Con "-- --bench": scava da solo per alcuni secondi, salva le misure in
## bench.txt e uno screenshot in shot.png, poi chiude.
## Con "-- --loop": prova automatica del ciclo dei secchi.

## Scena del secchio (creata da tools/build_scenes.gd), caricata all'avvio.
var secchio_scene: PackedScene

@onready var terrain: Node3D = $Terra
@onready var player: CharacterBody3D = $Player
@onready var state: Node = $GameState
@onready var spawn: Node3D = $Spawn
@onready var hud: CanvasLayer = $HUD
@onready var secchi: Node3D = $Secchi

var bench := false
var bench_frames := 0
var bench_samples := PackedFloat32Array()
var frame_ms := PackedFloat32Array()


func _ready() -> void:
	secchio_scene = load("res://scenes/secchio.tscn")
	var args := OS.get_cmdline_user_args()
	bench = "--bench" in args
	if bench:
		state.capienza = 100000
		state.attrezzi = [true, true, true]
	print("Terreno generato in %d ms" % terrain.gen_ms)

	player.terrain = terrain
	player.state = state
	player.interact.connect(_on_interact)
	player.fill_requested.connect(_on_fill)
	player.throw_requested.connect(_on_throw)
	player.blocked.connect(func(reason: String): hud.show_message(reason))
	# la collisione della pietra (CSG) viene creata al primo frame: aspetto prima di attivare la gravità
	player.set_physics_process(false)

	hud.buy_requested.connect(_on_buy)
	hud.shop_closed.connect(_close_shop)

	if not bench:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_physics_process(true)
	if "--loop" in args:
		_loop_test()


func _process(delta: float) -> void:
	if bench:
		_bench_step(delta)
	terrain.flush()
	if terrain.last_remesh_chunks > 0:
		# la terra sotto i secchi può essere stata scavata: li sveglio perché ricadano
		for b in secchi.get_children():
			(b as RigidBody3D).sleeping = false
	for b in secchi.get_children():
		if b.global_position.y < -10.0:
			# caduto fuori dal mondo: torna vicino al montacarichi
			b.global_position = spawn.global_position + Vector3(0, 2.5, 0)
			b.linear_velocity = Vector3.ZERO
	if bench and terrain.last_remesh_chunks > 0:
		bench_samples.append(terrain.last_remesh_ms)
		terrain.last_remesh_chunks = 0
	frame_ms.append(delta * 1000.0)
	_update_hud()


# --- secchi --------------------------------------------------------------------

## Q: riempie un secchio con 10 unità di terra e lo mette in mano.
func _on_fill() -> void:
	if player.ui_open:
		return
	if player.carrying:
		hud.show_message("Hai già un secchio in mano: lancialo o posalo")
	elif not state.puo_riempire():
		hud.show_message("Servono %d unità di terra (ne hai %d)" % [state.UNITA_SECCHIO, floori(state.terra_unita())])
	else:
		player.carry(state.riempi_secchio())
		player.sfx.play("secchi", player.global_position + Vector3(0, 1.0, 0), -4.0)


## Tasto destro: lancia il secchio che hai in mano.
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
	var v := fwd * speed + Vector3(0, 1.8, 0) + player.velocity
	_spawn_bucket(player.carried_valore, start, v)
	player.drop_carry()
	player.sfx.play("dura", start, -8.0)


func _spawn_bucket(valore: int, pos: Vector3, vel: Vector3) -> RigidBody3D:
	var b: RigidBody3D = secchio_scene.instantiate()
	b.valore = valore
	secchi.add_child(b)
	b.global_position = pos
	b.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	b.linear_velocity = vel
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	# il giocatore ci passa attraverso, così i secchi a terra non bloccano i corridoi
	b.add_collision_exception_with(player)
	return b


func _pick_bucket(b: RigidBody3D) -> void:
	if player.carrying:
		hud.show_message("Hai già un secchio in mano")
		return
	player.carry(b.valore)
	player.sfx.play("secchi", b.global_position, -6.0)
	b.queue_free()


# --- interazioni ---------------------------------------------------------------

func _on_interact(id: String) -> void:
	match id:
		"secchio":
			if is_instance_valid(player.look_collider):
				_pick_bucket(player.look_collider)
		"montacarichi":
			if spawn.busy:
				hud.show_message("Il montacarichi è in viaggio")
			elif not player.carrying:
				hud.show_message("Porta qui un secchio pieno (Q per riempirlo)")
			elif not state.impila(player.carried_valore):
				hud.show_message("Il montacarichi è pieno: tira la leva")
			else:
				player.drop_carry()
				spawn.update_pile(state.pila_secchi())
				player.sfx.play("secchi", spawn.lift_sound_pos())
		"leva":
			if spawn.busy:
				hud.show_message("Il montacarichi è in viaggio")
			elif state.pila_secchi() < 1:
				hud.show_message("Non c'è niente da mandare su")
			else:
				player.sfx.play("dura", spawn.lever_sound_pos(), -4.0)
				spawn.send(_on_lift_top)
		"negozio":
			_open_shop()
		"chiudi":
			_close_shop()


func _on_lift_top() -> void:
	var coins: int = state.vendi_pila()
	spawn.update_pile(0)
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


func _on_buy(id: String) -> void:
	var err: String = state.compra(id)
	if err != "":
		hud.set_shop_status(err)
		return
	player.sfx.play("monete", player.global_position + Vector3(0, 1.5, 0), -3.0)
	if id == "pala":
		player.tool_i = 1
	elif id == "piccone":
		player.tool_i = 2
	hud.set_shop_status("")
	hud.refresh_shop(state)


func _update_hud() -> void:
	var pila: int = state.pila_secchi()
	var text := "Monete: %d\nTerra: %d / %d unità\nAttrezzo: %s" % [
		state.monete, floori(state.terra_unita()), state.capienza, player.tool_name()]
	if player.carrying:
		text += "\nSecchio in mano: vale %d monete" % player.carried_valore
	if pila >= 1:
		text += "\nMontacarichi: %d / %d secchi (vale %d monete)" % [pila, state.PILA_MAX, state.valore_pila()]
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
			elif player.carrying:
				p = "E  posa il secchio (%d / %d)" % [pila, state.PILA_MAX]
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
			p = "Hai già un secchio in mano" if player.carrying else "E  raccogli il secchio"
		"negozio":
			p = "E  apri il negozio"
		_:
			if player.carrying:
				p = "Tasto destro  lancia il secchio"
			elif state.puo_riempire():
				p = "Q  riempi un secchio"
	hud.prompt.text = p if not player.ui_open else ""

	hud.debug.text = "FPS %d   ricalcolo %.1f ms (picco %.1f)   attrezzi: 1 mani%s%s" % [
		Engine.get_frames_per_second(), terrain.last_remesh_ms, terrain.max_remesh_ms,
		"  2 pala" if state.attrezzi[1] else "", "  3 piccone" if state.attrezzi[2] else ""]


# --- prove automatiche ---------------------------------------------------------

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
	# qualche secchio lanciato e uno in mano, per lo screenshot
	player.set_physics_process(false)
	player.position = spawn.position + Vector3(1.5, 2.1, 2.5)
	player.rotation.y = 0.5
	player.cam.rotation.x = -0.35
	for i in 4:
		_spawn_bucket(10, spawn.position + Vector3(0.6 * i - 1.5, 3.2, 0.8), Vector3(0, 0, -1.0))
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
