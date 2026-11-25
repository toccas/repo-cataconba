extends CanvasLayer
## Dev tool: pannello di comandi per provare il gioco. Si apre e si chiude con Ctrl+M
## (anche Esc lo chiude). Va messo come figlio della scena principale (main.tscn).
## I nodi sono nella scena dev_tool.tscn; ogni pulsante chiama la funzione "_do_<Nome>",
## ogni interruttore "_set_<Nome>", ogni cursore "_slide_<Nome>".

## [sezione, tipo, nome del nodo, testo]. tipo: "btn", "check", "slider", "option".
const COMANDI := [
	["Giocatore", "check", "Volo", "Volo senza collisioni (Spazio su, Shift giù)"],
	["Giocatore", "check", "ScavoPotente", "Scavo potente (anche la roccia)"],
	["Giocatore", "slider", "Velocita", "Velocità"],
	["Giocatore", "btn", "VaiSpawn", "Vai allo spawn"],
	["Risorse", "btn", "Monete100", "+100 monete"],
	["Risorse", "btn", "Monete1000", "+1000 monete"],
	["Risorse", "btn", "TuttiAttrezzi", "Dai tutti gli attrezzi"],
	["Risorse", "btn", "RiempiTerra", "Riempi l'attrezzo di terra"],
	["Risorse", "btn", "SecchioInMano", "Secchio pieno in mano"],
	["Risorse", "btn", "Montacarichi10", "+10 secchi sul montacarichi"],
	["Ossa", "option", "Parte", ""],
	["Ossa", "btn", "DaiOsso", "Osso scelto in mano"],
	["Ossa", "btn", "VaiOsso", "Vai all'osso scelto (lo scopre)"],
	["Ossa", "btn", "ScopriOssa", "Scopri tutte le ossa sepolte"],
	["Ossa", "btn", "CompletaTomba", "Completa lo scheletro nella tomba"],
	["Ossa", "btn", "SvuotaTomba", "Svuota la tomba"],
	["Mondo", "slider", "Tempo", "Velocità del tempo"],
	["Mondo", "btn", "RigeneraTerra", "Rigenera la terra"],
	["Mondo", "btn", "Ricomincia", "Ricomincia la partita"],
]
const PARTI := ["Testa", "Torace", "BraccioDestro", "BraccioSinistro", "GambaDestra", "GambaSinistra"]

var main: Node
var was_captured := false


func _ready() -> void:
	main = get_parent()
	$Pannello.visible = false
	for c in COMANDI:
		var n := find_child(c[2], true, false)
		match c[1]:
			"btn":
				n.pressed.connect(Callable(self, "_do_" + c[2]))
			"check":
				n.toggled.connect(Callable(self, "_set_" + c[2]))
			"slider":
				n.value_changed.connect(Callable(self, "_slide_" + c[2]))
	var opt: OptionButton = find_child("Parte", true, false)
	opt.clear()
	for p in PARTI:
		opt.add_item(p)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_M and event.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and is_open():
		toggle()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_E and is_open():
		# E chiuderebbe il "negozio" (il giocatore crede di avere un menu aperto)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return $Pannello.visible


func toggle() -> void:
	var player: Node = main.player
	if not is_open():
		if player.ui_open:
			return   # c'è già il negozio aperto
		was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		$Pannello.visible = true
		player.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		$Pannello.visible = false
		player.ui_open = false
		if was_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not is_open():
		return
	var p: Node3D = main.player
	var pos := p.global_position
	$Pannello/Scorri/Colonna/Info.text = "Posizione  %.1f  %.1f  %.1f\nFPS %d   ricalcolo terra %.1f ms\nTerra %.1f unità   monete %d\nOssa a terra %d   tomba %d / 6\nMira: %s" % [
		pos.x, pos.y, pos.z, Engine.get_frames_per_second(), main.terrain.last_remesh_ms,
		main.state.terra_unita(), main.state.monete, main.ossa.get_child_count(), main._pezzi_in_tomba(),
		p.look_target if p.look_target != "" else "-"]


func _msg(t: String) -> void:
	main.hud.show_message("[dev] " + t)


# --- giocatore ------------------------------------------------------------------

func _set_Volo(on: bool) -> void:
	main.player.set_volo(on)


func _set_ScavoPotente(on: bool) -> void:
	main.player.dev_scavo = on


func _slide_Velocita(v: float) -> void:
	main.player.dev_velocita = v
	$Pannello/Scorri/Colonna/VelocitaValore.text = "x%.1f" % v


func _do_VaiSpawn() -> void:
	main.player.global_position = main.spawn.global_position + Vector3(0, 2.1, 2.0)
	main.player.velocity = Vector3.ZERO


# --- risorse --------------------------------------------------------------------

func _do_Monete100() -> void:
	main._server("req_dev", ["monete100"])


func _do_Monete1000() -> void:
	main._server("req_dev", ["monete1000"])


func _do_TuttiAttrezzi() -> void:
	main._server("req_dev", ["attrezzi"])
	_msg("mani, pala, piccone e sacca capiente (tasti 1 2 3)")


func _do_RiempiTerra() -> void:
	var manca: float = main.state.capienza - main.state.terra_unita()
	if manca > 0.0:
		main.state.aggiungi_terra(Vector3(manca * main.state.UNITA_M3, 0, 0))


func _do_SecchioInMano() -> void:
	if main.player.carrying:
		_msg("hai già qualcosa in mano")
		return
	main.player.carry(10)


func _do_Montacarichi10() -> void:
	main._server("req_dev", ["montacarichi10"])


# --- ossa -----------------------------------------------------------------------

func _parte() -> String:
	return PARTI[(find_child("Parte", true, false) as OptionButton).selected]


func _do_DaiOsso() -> void:
	if main.player.carrying:
		_msg("hai già qualcosa in mano")
		return
	main.player.carry_bone(_parte())


func _do_VaiOsso() -> void:
	for b in main.ossa.get_children():
		if b.parte == _parte():
			main.scava_rete(b.global_position, 1.6, 50.0, 2)
			var target: Vector3 = b.global_position + Vector3(1.3, 0, 0)
			target.y = 2.1
			main.scava_rete(target + Vector3(0, 0.9, 0), 1.4, 50.0, 2)
			main.player.global_position = target
			main.player.velocity = Vector3.ZERO
			return
	_msg("%s non è a terra (forse è già nella tomba)" % _parte())


func _do_ScopriOssa() -> void:
	for b in main.ossa.get_children():
		main.scava_rete(b.global_position, 1.2, 50.0, 2)
	_msg("%d ossa scoperte" % main.ossa.get_child_count())


func _do_CompletaTomba() -> void:
	main._server("req_dev", ["completa_tomba"])


func _do_SvuotaTomba() -> void:
	main._server("req_dev", ["svuota_tomba"])


# --- mondo ----------------------------------------------------------------------

func _slide_Tempo(v: float) -> void:
	Engine.time_scale = v
	$Pannello/Scorri/Colonna/TempoValore.text = "x%.2f" % v


func _do_RigeneraTerra() -> void:
	if Rete.online:
		_msg("non disponibile in una partita online")
		return
	main.terrain.rebuild()
	_msg("terra rigenerata")


func _do_Ricomincia() -> void:
	if Rete.online:
		_msg("non disponibile in una partita online")
		return
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# --- costruzione della scena ---------------------------------------------------
## Usato solo da tools/build_scenes.gd per salvare dev_tool.tscn.

func build_nodes() -> void:
	layer = 10
	var panel := PanelContainer.new()
	panel.name = "Pannello"
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -360
	panel.offset_top = 10
	panel.offset_bottom = -10
	panel.offset_right = -10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	style.border_color = Color(0.35, 0.75, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "Scorri"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "Colonna"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	var title := Label.new()
	title.name = "Titolo"
	title.text = "Dev tool   (Ctrl+M / Esc per chiudere)"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.65))
	col.add_child(title)
	var info := Label.new()
	info.name = "Info"
	info.text = "Posizione ..."
	info.add_theme_font_size_override("font_size", 13)
	info.modulate = Color(1, 1, 1, 0.8)
	col.add_child(info)

	var section := ""
	for c in COMANDI:
		if c[0] != section:
			section = c[0]
			var h := Label.new()
			h.name = "Sezione" + section
			h.text = section
			h.add_theme_font_size_override("font_size", 16)
			h.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
			col.add_child(h)
		match c[1]:
			"btn":
				var b := Button.new()
				b.name = c[2]
				b.text = c[3]
				b.focus_mode = Control.FOCUS_NONE
				col.add_child(b)
			"check":
				var b := CheckButton.new()
				b.name = c[2]
				b.text = c[3]
				b.focus_mode = Control.FOCUS_NONE
				col.add_child(b)
			"option":
				var o := OptionButton.new()
				o.name = c[2]
				o.focus_mode = Control.FOCUS_NONE
				for p in PARTI:
					o.add_item(p)
				col.add_child(o)
			"slider":
				var row := HBoxContainer.new()
				row.name = "Riga" + c[2]
				col.add_child(row)
				var l := Label.new()
				l.name = "Etichetta"
				l.text = c[3]
				l.custom_minimum_size = Vector2(130, 0)
				row.add_child(l)
				var s := HSlider.new()
				s.name = c[2]
				s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				s.focus_mode = Control.FOCUS_NONE
				if c[2] == "Tempo":
					s.min_value = 0.1
					s.max_value = 3.0
					s.step = 0.05
				else:
					s.min_value = 0.5
					s.max_value = 5.0
					s.step = 0.5
				s.value = 1.0
				row.add_child(s)
				# il valore va in una label sotto la riga, con nome fisso
				var v := Label.new()
				v.name = c[2] + "Valore"
				v.text = "x1.0"
				v.modulate = Color(1, 1, 1, 0.7)
				col.add_child(v)
	panel.visible = false
