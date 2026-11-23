extends Node3D
## Scena principale del prototipo. Tutti gli elementi sono nodi della scena main.tscn:
## Catacomba (pezzi del Modular Cave Kit), Soffitto, Terra, Spawn (montacarichi, leva, negozio), Player, HUD.
## Questo script collega le interazioni e aggiorna l'interfaccia.
##
## Avvio normale: si gioca.
## Con "-- --bench": scava da solo per alcuni secondi, salva le misure in
## bench.txt e uno screenshot in shot.png, poi chiude.
## Con "-- --loop": prova automatica del ciclo zaino -> pila -> vendita -> negozio.

@onready var terrain: Node3D = $Terra
@onready var player: CharacterBody3D = $Player
@onready var state: Node = $GameState
@onready var spawn: Node3D = $Spawn
@onready var hud: CanvasLayer = $HUD

var bench := false
var bench_frames := 0
var bench_samples := PackedFloat32Array()
var frame_ms := PackedFloat32Array()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	bench = "--bench" in args
	if bench:
		state.capienza = 100000
		state.attrezzi = [true, true, true]
	print("Terreno generato in %d ms" % terrain.gen_ms)

	player.terrain = terrain
	player.state = state
	player.interact.connect(_on_interact)
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
	if bench and terrain.last_remesh_chunks > 0:
		bench_samples.append(terrain.last_remesh_ms)
		terrain.last_remesh_chunks = 0
	frame_ms.append(delta * 1000.0)
	_update_hud()


# --- interazioni ---------------------------------------------------------------

func _on_interact(id: String) -> void:
	match id:
		"montacarichi":
			if spawn.busy:
				hud.show_message("Il montacarichi è in viaggio")
			elif state.zaino_secchi() < 1.0:
				hud.show_message("Lo zaino è vuoto")
			else:
				var n: float = state.impila()
				spawn.update_pile(state.pila_secchi())
				player.sfx.play("secchi", spawn.lift_sound_pos())
				hud.show_message("Impilati %d secchi" % floori(n))
		"leva":
			if spawn.busy:
				hud.show_message("Il montacarichi è in viaggio")
			elif state.pila_secchi() < 1.0:
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
	var pila: float = state.pila_secchi()
	var text := "Monete: %d\nZaino: %d / %d secchi\nAttrezzo: %s" % [
		state.monete, floori(state.zaino_secchi()), state.capienza, player.tool_name()]
	if pila >= 1.0:
		text += "\nPila: %d secchi (vale %d monete)" % [floori(pila), state.valore_pila()]
	hud.info.text = text

	hud.warning.text = "Zaino pieno: porta la terra al montacarichi" if player.zaino_pieno else ""

	var p := ""
	match player.look_target:
		"montacarichi":
			p = "E  impila la terra dello zaino" if not spawn.busy else "Il montacarichi è in viaggio"
		"leva":
			if spawn.busy:
				p = "Il montacarichi è in viaggio"
			elif pila >= 1.0:
				p = "E  manda su la pila: %d monete (bonus +%d%%)" % [state.valore_pila(), roundi(state.bonus_pila() * 100)]
			else:
				p = "La pila è vuota"
		"negozio":
			p = "E  apri il negozio"
	hud.prompt.text = p if not player.ui_open else ""

	hud.debug.text = "FPS %d   ricalcolo %.1f ms (picco %.1f)   attrezzi: 1 mani%s%s" % [
		Engine.get_frames_per_second(), terrain.last_remesh_ms, terrain.max_remesh_ms,
		"  2 pala" if state.attrezzi[1] else "", "  3 piccone" if state.attrezzi[2] else ""]


# --- prove automatiche ---------------------------------------------------------

## Prova del ciclo: riempie lo zaino, impila, vende, compra la pala. Stampa i passaggi.
func _loop_test() -> void:
	var out := []
	state.aggiungi_terra(Vector3(2.5, 0.0, 0.0))
	out.append("zaino=%.1f pieno=%s" % [state.zaino_secchi(), state.zaino_pieno()])
	_on_interact("montacarichi")
	out.append("pila=%.1f zaino=%.1f valore=%d" % [state.pila_secchi(), state.zaino_secchi(), state.valore_pila()])
	state.aggiungi_terra(Vector3(2.5, 0.0, 0.0))
	_on_interact("montacarichi")
	out.append("pila=%.1f valore=%d bonus=%.1f" % [state.pila_secchi(), state.valore_pila(), state.bonus_pila()])
	_on_interact("leva")
	await get_tree().create_timer(4.5).timeout
	out.append("monete=%d pila=%.1f busy=%s" % [state.monete, state.pila_secchi(), spawn.busy])
	state.monete += 40
	out.append("compra pala: '%s' monete=%d pala=%s" % [state.compra("pala"), state.monete, state.attrezzi[1]])
	out.append("compra piccone: '%s'" % state.compra("piccone"))
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
