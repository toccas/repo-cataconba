extends VBoxContainer
## Pannello delle impostazioni (usato dal menu principale e dal menu di pausa).
## Ogni modifica vale subito e si salva; "Indietro" emette "chiuso".

signal chiuso

const Tema := preload("res://scripts/tema.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size = Vector2(460, 0)
	add_child(Tema.titolo("Impostazioni", 26))
	var I := Impostazioni
	_cursore("Volume", 0.0, 1.0, 0.05, I.volume, func(v): I.volume = v, func(v): return "%d%%" % roundi(v * 100))
	_cursore("Sensibilità del mouse", 0.2, 3.0, 0.05, I.sensibilita, func(v): I.sensibilita = v, func(v): return "%.2f×" % v)
	_cursore("Campo visivo", 60.0, 110.0, 1.0, I.fov, func(v): I.fov = v, func(v): return "%d°" % roundi(v))
	_interruttore("Schermo intero", I.schermo_intero, func(v): I.schermo_intero = v)
	_interruttore("Sincronia verticale (V-Sync)", I.vsync, func(v): I.vsync = v)
	var indietro := Button.new()
	indietro.text = "Indietro"
	indietro.pressed.connect(func(): chiuso.emit())
	add_child(indietro)
	indietro.grab_focus.call_deferred()


func _cursore(nome: String, da: float, a: float, passo: float, valore: float, imposta: Callable, testo: Callable) -> void:
	var riga := HBoxContainer.new()
	var l := Label.new()
	l.text = nome
	l.custom_minimum_size = Vector2(210, 0)
	riga.add_child(l)
	var s := HSlider.new()
	s.min_value = da
	s.max_value = a
	s.step = passo
	s.value = valore
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	riga.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = testo.call(valore)
	riga.add_child(v)
	s.value_changed.connect(func(x: float):
		imposta.call(x)
		v.text = testo.call(x)
		Impostazioni.applica()
		Impostazioni.salva())
	add_child(riga)


func _interruttore(nome: String, valore: bool, imposta: Callable) -> void:
	var c := CheckButton.new()
	c.text = nome
	c.button_pressed = valore
	c.toggled.connect(func(on: bool):
		imposta.call(on)
		Impostazioni.applica()
		Impostazioni.salva())
	add_child(c)
