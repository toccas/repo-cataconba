extends CanvasLayer
## Menu di pausa (Esc durante il gioco): Riprendi, Impostazioni, Salva partita,
## Menu principale, Esci dal gioco. Creato da main.gd.
## Da solo il gioco si ferma davvero; in co-op la partita continua per gli altri.

signal chiusa

const Tema := preload("res://scripts/tema.gd")
const PannelloImpostazioni := preload("res://scripts/pannello_impostazioni.gd")
const MENU := "res://scenes/menu_principale.tscn"

var main: Node
var pannello: PanelContainer
var avviso: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.theme = Tema.crea()
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	pannello = PanelContainer.new()
	centro.add_child(pannello)
	_principale()


func _principale() -> void:
	for c in pannello.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(340, 0)
	pannello.add_child(col)
	var t := Tema.titolo("In pausa" if not Rete.online else "Menu", 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var riprendi := _bottone("Riprendi", chiudi)
	col.add_child(riprendi)
	col.add_child(_bottone("Impostazioni", _impostazioni))
	if multiplayer.is_server():
		col.add_child(_bottone("Salva partita (slot %d)" % Rete.slot, _salva))
	col.add_child(_bottone("Menu principale", _menu))
	col.add_child(_bottone("Esci dal gioco", _esci))
	avviso = Label.new()
	avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avviso.modulate = Color(0.75, 0.95, 0.75)
	col.add_child(avviso)
	if multiplayer.is_server():
		avviso.text = "Si salva da sola ogni minuto e quando esci."
		avviso.modulate = Color(1, 1, 1, 0.55)
	riprendi.grab_focus.call_deferred()


func _bottone(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	return b


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if pannello.get_child(0) is VBoxContainer and pannello.get_child(0).get_child_count() == 1:
			_principale()   # dalle impostazioni si torna al menu di pausa
		else:
			chiudi()


func chiudi() -> void:
	chiusa.emit()
	queue_free()


func _impostazioni() -> void:
	for c in pannello.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	pannello.add_child(col)
	var p := PannelloImpostazioni.new()
	p.chiuso.connect(_principale)
	col.add_child(p)


func _salva() -> void:
	if main.salva():
		avviso.text = "Partita salvata nello slot %d" % Rete.slot
		avviso.modulate = Color(0.75, 0.95, 0.75)
	else:
		avviso.text = "Non sono riuscito a salvare"
		avviso.modulate = Color(1, 0.6, 0.5)


func _menu() -> void:
	main.esci_al_menu()


func _esci() -> void:
	main.salva()
	get_tree().quit()
