extends Node3D
## Menu principale (scena di avvio): Continua partita, Carica partita, Nuova partita,
## Co-op, Impostazioni, Esci. Dietro c'è un angolo di cripta con il negoziante.
##
## I pulsanti e lo sfondo sono nodi della scena (scenes/menu_principale.tscn) e si
## possono spostare nell'editor; i pannelli (slot, co-op, impostazioni) li crea lo script
## dentro $UI/Radice/Pannello.
## Per partire si scrive in Rete cosa fare (modalita, slot, nuova_partita, ip) e si
## cambia scena: main.gd lo legge all'avvio.

const GIOCO := "res://scenes/main.tscn"
const Salvataggi := preload("res://scripts/salvataggi.gd")
const Tema := preload("res://scripts/tema.gd")
const PannelloImpostazioni := preload("res://scripts/pannello_impostazioni.gd")
const CFG_RETE := "user://rete.cfg"

@onready var radice: Control = $UI/Radice
@onready var bottoni: VBoxContainer = $UI/Radice/Bottoni
@onready var pannello: PanelContainer = $UI/Radice/Pannello
@onready var messaggio: Label = $UI/Radice/Messaggio
@onready var lanterna: OmniLight3D = $Lanterna
@onready var camera: Camera3D = $Camera3D

var _t := 0.0
var _cam_base: Transform3D
var _energia := 1.0


func _ready() -> void:
	# prove automatiche e partite da riga di comando: dritti al gioco
	var args := OS.get_cmdline_user_args()
	for a in ["--loop", "--bench", "--host", "--join", "--provarete", "--prova"]:
		if a in args:
			get_tree().change_scene_to_file.call_deferred(GIOCO)
			return
	get_tree().paused = false
	if Rete.online:
		Rete.esci()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Salvataggi.migra()
	radice.theme = Tema.crea()
	_cam_base = camera.transform
	_energia = lanterna.light_energy

	_collega("Continua", _continua)
	_collega("Carica", func(): _slot("carica"))
	_collega("Nuova", func(): _slot("nuova"))
	_collega("Coop", _coop)
	_collega("Impostazioni", _impostazioni)
	_collega("Esci", func(): get_tree().quit())
	pannello.visible = false
	_aggiorna()
	messaggio.text = Rete.errore
	Rete.errore = ""


func _collega(nome: String, f: Callable) -> void:
	(bottoni.get_node(nome) as Button).pressed.connect(f)


## Abilita Continua e Carica solo se c'è qualcosa da caricare.
func _aggiorna() -> void:
	var ultimo := Salvataggi.ultimo()
	var continua := bottoni.get_node("Continua") as Button
	continua.disabled = ultimo == 0
	continua.tooltip_text = "Slot %d: %s" % [ultimo, Salvataggi.descrivi(Salvataggi.info(ultimo))] if ultimo else ""
	(bottoni.get_node("Carica") as Button).disabled = ultimo == 0
	var primo := bottoni.get_node("Continua" if ultimo else "Nuova") as Button
	primo.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	# la fiamma della lanterna tremola, la camera respira appena
	lanterna.light_energy = _energia * (0.85 + 0.1 * sin(_t * 7.3) + 0.07 * sin(_t * 13.1) + 0.04 * randf())
	camera.transform = _cam_base.translated_local(Vector3(sin(_t * 0.31) * 0.06, sin(_t * 0.23) * 0.03, 0)) \
		.rotated_local(Vector3.UP, sin(_t * 0.19) * 0.015)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and pannello.visible:
		_chiudi_pannello()
		get_viewport().set_input_as_handled()


# --- pannelli ---------------------------------------------------------------------

## Svuota il pannello e lo mostra al posto dei pulsanti. Restituisce la colonna da riempire.
func _apri_pannello(titolo: String) -> VBoxContainer:
	for c in pannello.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(520, 0)
	pannello.add_child(col)
	if titolo != "":
		col.add_child(Tema.titolo(titolo, 26))
	bottoni.visible = false
	pannello.visible = true
	messaggio.text = ""
	return col


func _chiudi_pannello() -> void:
	for c in pannello.get_children():
		c.queue_free()
	pannello.visible = false
	bottoni.visible = true
	_aggiorna()


func _bottone(testo: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	if f.is_valid():
		b.pressed.connect(f)
	return b


func _indietro(col: VBoxContainer) -> Button:
	var b := _bottone("Indietro", _chiudi_pannello)
	col.add_child(HSeparator.new())
	col.add_child(b)
	return b


## Elenco degli slot. modo "carica": si sceglie una partita salvata (e si può eliminare);
## modo "nuova": si sceglie dove iniziare (se lo slot è pieno chiede conferma).
func _slot(modo: String) -> void:
	var col := _apri_pannello("Carica partita" if modo == "carica" else "Nuova partita")
	if modo == "nuova":
		var l := Label.new()
		l.text = "Scegli lo slot in cui salvare la nuova partita."
		l.modulate = Color(1, 1, 1, 0.7)
		col.add_child(l)
	var primo: Button = null
	for n in range(1, Salvataggi.SLOT + 1):
		var i := Salvataggi.info(n)
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 8)
		var b := _bottone("Slot %d\n%s" % [n, Salvataggi.descrivi(i)], Callable())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if modo == "carica":
			b.disabled = i.is_empty()
			b.pressed.connect(_gioca.bind("solo", n, false, ""))
		else:
			b.pressed.connect(_nuova_in.bind(n))
		riga.add_child(b)
		if modo == "carica" and not i.is_empty():
			var x := _bottone("Elimina", _chiedi_elimina.bind(n))
			x.size_flags_vertical = Control.SIZE_FILL
			riga.add_child(x)
		col.add_child(riga)
		if primo == null and not b.disabled:
			primo = b
	var ind := _indietro(col)
	(primo if primo else ind).grab_focus.call_deferred()


## Nuova partita nello slot n (se è pieno chiede prima conferma).
func _nuova_in(n: int) -> void:
	var i := Salvataggi.info(n)
	if i.is_empty():
		_gioca("solo", n, true)
		return
	_conferma("Lo slot %d ha già una partita (%s).\nIniziare da capo e sovrascriverla?" % [n, Salvataggi.descrivi(i)],
		"Sì, ricomincia", _gioca.bind("solo", n, true, ""), _slot.bind("nuova"))


func _chiedi_elimina(n: int) -> void:
	_conferma("Eliminare per sempre la partita dello slot %d?\n%s" % [n, Salvataggi.descrivi(Salvataggi.info(n))],
		"Elimina", _elimina.bind(n), _slot.bind("carica"))


func _elimina(n: int) -> void:
	Salvataggi.elimina(n)
	if Salvataggi.ultimo() == 0:
		_chiudi_pannello()
	else:
		_slot("carica")


## Domanda sì/no dentro il pannello.
func _conferma(domanda: String, si: String, f_si: Callable, f_no: Callable) -> void:
	var col := _apri_pannello("")
	var l := Label.new()
	l.text = domanda
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	col.add_child(l)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 10)
	riga.alignment = BoxContainer.ALIGNMENT_END
	var no := _bottone("Annulla", f_no)
	riga.add_child(no)
	riga.add_child(_bottone(si, f_si))
	col.add_child(riga)
	no.grab_focus.call_deferred()


## Co-op: il nome, ospitare (scegliendo lo slot da usare) o entrare in una partita.
func _coop() -> void:
	var col := _apri_pannello("Co-op online")
	col.add_theme_constant_override("separation", 6)
	var cfg := ConfigFile.new()
	cfg.load(CFG_RETE)

	col.add_child(_etichetta("Il tuo nome"))
	var nome := LineEdit.new()
	nome.max_length = 20
	nome.text = cfg.get_value("rete", "nome", "Scavatore")
	col.add_child(nome)

	col.add_child(_spazio())
	col.add_child(_etichetta("Ospita una partita (gli amici entrano con il tuo indirizzo)"))
	var slot := OptionButton.new()
	for n in range(1, Salvataggi.SLOT + 1):
		var i := Salvataggi.info(n)
		slot.add_item("Slot %d: %s" % [n, "nuova partita" if i.is_empty() else Salvataggi.descrivi(i)], n)
	var ultimo := Salvataggi.ultimo()
	slot.select(maxi(ultimo, 1) - 1)
	col.add_child(slot)
	var da_capo := CheckBox.new()
	da_capo.text = "Ricomincia da capo in questo slot"
	col.add_child(da_capo)
	var vedi_da_capo := func(_x = 0): da_capo.visible = Salvataggi.esiste(slot.get_selected_id())
	slot.item_selected.connect(vedi_da_capo)
	vedi_da_capo.call()
	col.add_child(_bottone("Ospita partita (porta %d)" % Rete.PORTA, func():
		_ricorda(nome.text, cfg.get_value("rete", "ip", ""))
		_gioca("ospita", slot.get_selected_id(), da_capo.visible and da_capo.button_pressed)))

	col.add_child(_spazio())
	col.add_child(_etichetta("Entra nella partita di un amico (IP o nome)"))
	var riga := HBoxContainer.new()
	var ip := LineEdit.new()
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip.placeholder_text = "es. 93.40.12.7"
	ip.text = cfg.get_value("rete", "ip", "127.0.0.1")
	riga.add_child(ip)
	var entra := func(_t = ""):
		var dove := ip.text.strip_edges()
		if dove == "":
			messaggio.text = "Scrivi l'indirizzo di chi ospita"
			return
		_ricorda(nome.text, dove)
		_gioca("entra", 0, false, dove)
	ip.text_submitted.connect(entra)
	riga.add_child(_bottone("Entra", entra))
	col.add_child(riga)
	_indietro(col)
	nome.grab_focus.call_deferred()


func _spazio() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 8)
	return c


func _etichetta(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.modulate = Color(1, 1, 1, 0.75)
	return l


func _ricorda(nome: String, ip: String) -> void:
	Rete.nome = nome.strip_edges() if nome.strip_edges() != "" else "Scavatore"
	var cfg := ConfigFile.new()
	cfg.set_value("rete", "nome", Rete.nome)
	cfg.set_value("rete", "ip", ip)
	cfg.save(CFG_RETE)


func _impostazioni() -> void:
	var col := _apri_pannello("")
	var p := PannelloImpostazioni.new()
	p.chiuso.connect(_chiudi_pannello)
	col.add_child(p)


func _continua() -> void:
	var n := Salvataggi.ultimo()
	if n:
		_gioca("solo", n, false)


## Parte: scrive in Rete cosa fare e passa alla scena del gioco.
func _gioca(modalita: String, slot: int, nuova: bool, ip := "") -> void:
	if modalita == "solo":
		var cfg := ConfigFile.new()
		cfg.load(CFG_RETE)
		Rete.nome = cfg.get_value("rete", "nome", "Scavatore")
	Rete.modalita = modalita
	Rete.slot = slot
	Rete.nuova_partita = nuova
	Rete.indirizzo = ip
	bottoni.visible = false
	var col := _apri_pannello("")
	var l := Tema.titolo("Scendo nella catacomba...", 24)
	col.add_child(l)
	# un paio di frame per far vedere la scritta: la catacomba ci mette un secondo a nascere
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GIOCO)
