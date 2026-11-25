extends CanvasLayer
## Menu iniziale: gioca da solo, ospita una partita online o entra in quella di un amico.
## Creato da main.gd all'avvio (non serve nella scena). Ricorda nome e indirizzo
## in user://rete.cfg.

signal scelto

const CFG := "user://rete.cfg"

var nome_edit: LineEdit
var ip_edit: LineEdit
var stato: Label
var bottoni: Array[Button] = []


func _ready() -> void:
	layer = 10
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.02, 0.03, 0.82)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	centro.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)

	var titolo := Label.new()
	titolo.text = "Scava Catacomba"
	titolo.add_theme_font_size_override("font_size", 30)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titolo)

	col.add_child(_etichetta("Il tuo nome"))
	nome_edit = LineEdit.new()
	nome_edit.max_length = 20
	col.add_child(nome_edit)

	col.add_child(_bottone("Gioca da solo", _da_solo))
	col.add_child(_bottone("Ospita una partita online (porta %d)" % Rete.PORTA, _ospita))

	col.add_child(_etichetta("Indirizzo di chi ospita (IP o nome)"))
	var riga := HBoxContainer.new()
	ip_edit = LineEdit.new()
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.placeholder_text = "es. 93.40.12.7"
	ip_edit.text_submitted.connect(func(_t): _entra())
	riga.add_child(ip_edit)
	riga.add_child(_bottone("Entra", _entra))
	col.add_child(riga)

	stato = Label.new()
	stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stato.custom_minimum_size = Vector2(400, 0)
	stato.modulate = Color(1, 0.8, 0.5)
	col.add_child(stato)

	var cfg := ConfigFile.new()
	cfg.load(CFG)
	nome_edit.text = cfg.get_value("rete", "nome", "Scavatore")
	ip_edit.text = cfg.get_value("rete", "ip", "127.0.0.1")

	Rete.stato_cambiato.connect(func(t: String): stato.text = t)
	Rete.connesso.connect(_chiudi)
	Rete.disconnesso.connect(func(m: String):
		stato.text = m
		_abilita(true))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _etichetta(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _bottone(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	bottoni.append(b)
	return b


func _abilita(on: bool) -> void:
	for b in bottoni:
		b.disabled = not on


func _salva() -> void:
	Rete.nome = nome_edit.text.strip_edges() if nome_edit.text.strip_edges() != "" else "Scavatore"
	var cfg := ConfigFile.new()
	cfg.set_value("rete", "nome", Rete.nome)
	cfg.set_value("rete", "ip", ip_edit.text.strip_edges())
	cfg.save(CFG)


func _da_solo() -> void:
	_salva()
	Rete.gioca_da_solo()


func _ospita() -> void:
	_salva()
	var err := Rete.ospita()
	if err != "":
		stato.text = err


func _entra() -> void:
	_salva()
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		stato.text = "Scrivi l'indirizzo di chi ospita"
		return
	var err := Rete.entra(ip)
	if err != "":
		stato.text = err
	else:
		_abilita(false)


func _chiudi() -> void:
	scelto.emit()
	queue_free()
