extends Node3D
## Suoni di scavo. Per ora sono provvisori, generati da codice e salvati in res://audio/.
## Ogni tipo ha qualche variante: per usare file audio veri basta trascinarli
## nelle liste dell'Inspector del nodo Sfx.

const RATE := 22050
const KINDS := ["terra", "dura", "roccia", "pietra", "monete", "secchi", "boom"]

## Varianti di ogni suono. Si possono sostituire trascinando file audio veri nell'Inspector.
@export var terra: Array[AudioStream] = []
@export var dura: Array[AudioStream] = []
@export var roccia: Array[AudioStream] = []
@export var pietra: Array[AudioStream] = []
@export var monete: Array[AudioStream] = []
@export var secchi: Array[AudioStream] = []
@export var boom: Array[AudioStream] = []

var players := []
var next_player := 0


func _ready() -> void:
	for c in get_children():
		if c is AudioStreamPlayer3D:
			players.append(c)
	# se mancano dei suoni (scena non generata), li crea al volo
	var gen := {}
	for k in KINDS:
		if (get(k) as Array).is_empty():
			if gen.is_empty():
				gen = generate_banks()
			set(k, gen[k])


## Crea le voci audio. Usato solo da tools/build_scenes.gd per salvare la scena.
func build_nodes() -> void:
	for i in 6:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voce%d" % (i + 1)
		p.unit_size = 4.0
		p.max_db = 3.0
		add_child(p)


## Genera i suoni provvisori: per ogni tipo, un Array[AudioStream] di 4 varianti.
func generate_banks() -> Dictionary:
	# durata, decadimento, filtro (0..1, più alto = più acuto), granuli, tono metallico, quantità tono
	return {
		"terra": _variants(0.22, 14.0, 0.16, 0.004, 0.0, 0.0, 10),
		"dura": _variants(0.20, 18.0, 0.28, 0.007, 0.0, 0.0, 20),
		"roccia": _variants(0.24, 22.0, 0.50, 0.012, 1700.0, 0.18, 30),
		"pietra": _variants(0.18, 30.0, 0.60, 0.010, 2600.0, 0.30, 40),
		"monete": _variants(0.35, 9.0, 0.75, 0.02, 2300.0, 0.55, 50),
		"secchi": _variants(0.30, 10.0, 0.12, 0.010, 0.0, 0.0, 60),
		"boom": _variants(1.4, 3.2, 0.05, 0.03, 0.0, 0.0, 70),
	}


func play(kind: String, pos: Vector3, volume_db := 0.0) -> void:
	var p: AudioStreamPlayer3D = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = (get(kind) as Array).pick_random()
	p.global_position = pos
	p.pitch_scale = randf_range(0.88, 1.12)
	p.volume_db = volume_db
	p.play()


func _variants(length: float, decay: float, cutoff: float, grains: float, ring_hz: float, ring_amt: float, rseed: int) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for v in 4:
		out.append(_make(length, decay, cutoff, grains, ring_hz * (1.0 + 0.07 * v), ring_amt, rseed + v))
	return out


## Rumore filtrato con inviluppo che decade e piccoli "granuli" che lo rendono scricchiolante.
func _make(length: float, decay: float, cutoff: float, grains: float, ring_hz: float, ring_amt: float, rseed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var grain := 0.0
	var peak := 0.0001
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay) * minf(t * 500.0, 1.0)
		if rng.randf() < grains:
			grain = rng.randf_range(0.6, 1.0)
		grain *= 0.994
		var noise := rng.randf_range(-1.0, 1.0)
		lp += cutoff * (noise - lp)
		lp2 += cutoff * (lp - lp2)
		var s := lp2 * env * (0.35 + 0.65 * grain)
		buf[i] = s
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := buf[i] / peak * 0.8
		if ring_amt > 0.0:
			s += sin(TAU * ring_hz * t) * exp(-t * 28.0) * ring_amt
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
