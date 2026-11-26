extends CanvasLayer
## Interfaccia: informazioni in alto a sinistra, suggerimento per il tasto E,
## messaggi temporanei, avviso zaino pieno e finestra del negozio.
## I nodi sono nella scena hud.tscn; le righe del negozio si creano dai dati di GameState.

signal buy_requested(id: String)
signal shop_closed

@onready var info: Label = $Info
@onready var prompt: Label = $Suggerimento
@onready var message: Label = $Messaggio
@onready var warning: Label = $Avviso
@onready var debug: Label = $Debug
@onready var shop: PanelContainer = $Negozio
@onready var shop_list: VBoxContainer = $Negozio/Colonna/Scorri/Lista
@onready var shop_coins: Label = $Negozio/Colonna/Monete
@onready var shop_status: Label = $Negozio/Colonna/Stato
var message_time := 0.0


func _ready() -> void:
	$Negozio/Colonna/Chiudi.pressed.connect(func(): shop_closed.emit())
	shop.visible = false
	message.text = ""
	warning.text = ""
	prompt.text = ""
	# le righe del multigiocatore si aggiungono sotto: il testo cresce verso l'alto e va a capo
	debug.grow_vertical = Control.GROW_DIRECTION_BEGIN
	debug.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug.custom_minimum_size.x = 900


func show_message(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	message_time = 2.2


func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		message.modulate.a = clampf(message_time / 0.6, 0.0, 1.0)


func open_shop(state: Node) -> void:
	shop_status.text = ""
	refresh_shop(state)
	shop.visible = true


func close_shop() -> void:
	shop.visible = false


func refresh_shop(state: Node) -> void:
	shop_coins.text = "Monete: %d" % state.monete
	for c in shop_list.get_children():
		c.queue_free()
	var cat := ""
	for item in state.NEGOZIO:
		if item["cat"] != cat:
			cat = item["cat"]
			var h := Label.new()
			h.text = cat
			h.add_theme_font_size_override("font_size", 18)
			h.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
			shop_list.add_child(h)
		var id: String = item["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := Label.new()
		var prezzo: int = state.prezzo(id)
		if item["tipo"] == "livelli":
			var l: int = state.livello(id)
			var m: int = item["prezzi"].size()
			var desc: String = item["desc"][l] if l < m else "Al massimo."
			text.text = "%s   %s\n%s" % [item["nome"], "liv. %d / %d" % [l, m] if l > 0 else "", desc]
		else:
			text.text = "%s   %d / %d\n%s" % [item["nome"], state.pezzi(id), item["max"], item["desc"]]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(130, 0)
		if prezzo < 0:
			bt.text = "Massimo" if item["tipo"] == "livelli" else "Pieno"
			bt.disabled = true
		else:
			var verbo := "Compra" if item["tipo"] == "consumabile" or state.livello(id) == 0 else "Migliora"
			bt.text = "%s  %d" % [verbo, prezzo]
			bt.disabled = state.monete < prezzo
			bt.pressed.connect(func(): buy_requested.emit(id))
		row.add_child(bt)
		shop_list.add_child(row)


func set_shop_status(text: String) -> void:
	shop_status.text = text


# --- costruzione della scena ------------------------------------------------
## Usato solo da tools/build_scenes.gd per salvare hud.tscn.

func build_nodes() -> void:
	var l := _label("Info", 20)
	l.position = Vector2(16, 12)
	l.text = "Monete: 0\nZaino: 0 / 10 secchi\nAttrezzo: Mani"
	l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))

	var cross := _label("Mirino", 22)
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cross.grow_vertical = Control.GROW_DIRECTION_BOTH

	var p := _label("Suggerimento", 20)
	p.text = "E  apri il negozio"
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.offset_top = -90
	p.offset_bottom = -60

	var m := _label("Messaggio", 22)
	m.text = "+24 monete"
	m.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.grow_horizontal = Control.GROW_DIRECTION_BOTH
	m.offset_top = 40
	m.offset_bottom = 70
	m.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

	var w := _label("Avviso", 20)
	w.text = "Zaino pieno: porta la terra al montacarichi"
	w.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.grow_horizontal = Control.GROW_DIRECTION_BOTH
	w.offset_top = 20
	w.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))

	var d := _label("Debug", 13)
	d.text = "FPS 60   ricalcolo 0.0 ms"
	d.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	d.offset_top = -48
	d.offset_left = 12
	d.modulate = Color(1, 1, 1, 0.6)

	var panel := PanelContainer.new()
	panel.name = "Negozio"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.94)
	style.border_color = Color(0.55, 0.40, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Colonna"
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.name = "Titolo"
	title.text = "Negozio"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	box.add_child(title)
	var coins := Label.new()
	coins.name = "Monete"
	coins.text = "Monete: 0"
	box.add_child(coins)
	# l'elenco scorre: le voci del negozio sono tante
	var scroll := ScrollContainer.new()
	scroll.name = "Scorri"
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Lista"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var status := Label.new()
	status.name = "Stato"
	status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	box.add_child(status)
	var close := Button.new()
	close.name = "Chiudi"
	close.text = "Chiudi (E)"
	box.add_child(close)
	panel.visible = false


func _label(node_name: String, size: int) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(l)
	return l
