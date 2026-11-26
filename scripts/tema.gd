extends RefCounted
## Tema dei menu (principale e pausa): pannelli scuri color terra con il bordo in ottone,
## pulsanti che si scaldano quando ci passa sopra il mouse.

const OTTONE := Color(0.82, 0.62, 0.3)
const TESTO := Color(0.95, 0.9, 0.8)


static func crea() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20

	var pannello := _box(Color(0.09, 0.07, 0.06, 0.92), OTTONE.darkened(0.35), 2, 10)
	pannello.content_margin_left = 26
	pannello.content_margin_right = 26
	pannello.content_margin_top = 20
	pannello.content_margin_bottom = 20
	t.set_stylebox("panel", "PanelContainer", pannello)

	var normale := _box(Color(0.16, 0.12, 0.09, 0.9), Color(0.35, 0.27, 0.18), 2, 6)
	var sopra := _box(Color(0.3, 0.2, 0.11, 0.95), OTTONE, 2, 6)
	var premuto := _box(Color(0.42, 0.28, 0.13, 1.0), OTTONE.lightened(0.2), 2, 6)
	var spento := _box(Color(0.1, 0.09, 0.08, 0.7), Color(0.2, 0.18, 0.16), 2, 6)
	for b in [normale, sopra, premuto, spento]:
		b.content_margin_left = 18
		b.content_margin_right = 18
		b.content_margin_top = 9
		b.content_margin_bottom = 9
	for tipo in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tipo, normale)
		t.set_stylebox("hover", tipo, sopra)
		t.set_stylebox("pressed", tipo, premuto)
		t.set_stylebox("focus", tipo, _box(Color(0, 0, 0, 0), OTTONE.lightened(0.1), 2, 6))
		t.set_stylebox("disabled", tipo, spento)
		t.set_color("font_color", tipo, TESTO)
		t.set_color("font_hover_color", tipo, Color(1, 0.92, 0.7))
		t.set_color("font_pressed_color", tipo, Color(1, 0.95, 0.8))
		t.set_color("font_focus_color", tipo, Color(1, 0.92, 0.7))
		t.set_color("font_disabled_color", tipo, Color(0.5, 0.46, 0.4))
	t.set_color("font_color", "Label", TESTO)
	t.set_color("font_color", "CheckButton", TESTO)
	t.set_color("font_hover_color", "CheckButton", Color(1, 0.92, 0.7))
	t.set_color("font_color", "CheckBox", TESTO)

	var campo := _box(Color(0.05, 0.04, 0.035, 0.95), Color(0.35, 0.27, 0.18), 2, 5)
	campo.content_margin_left = 10
	campo.content_margin_right = 10
	campo.content_margin_top = 6
	campo.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", campo)
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), OTTONE, 2, 5))

	var guida := StyleBoxFlat.new()
	guida.bg_color = Color(0.2, 0.15, 0.1)
	guida.content_margin_top = 3
	guida.content_margin_bottom = 3
	guida.set_corner_radius_all(3)
	t.set_stylebox("slider", "HSlider", guida)
	var pieno := guida.duplicate() as StyleBoxFlat
	pieno.bg_color = OTTONE.darkened(0.2)
	t.set_stylebox("grabber_area", "HSlider", pieno)
	t.set_stylebox("grabber_area_highlight", "HSlider", pieno)
	return t


static func _box(bg: Color, bordo: Color, spessore: int, raggio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	return s


## Un titolo grande in ottone.
static func titolo(testo: String, dimensione := 30) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", OTTONE.lightened(0.15))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	return l
