extends Node
## Stato della partita: monete, zaino, pila sul montacarichi, attrezzi posseduti.
## Le quantità di terra sono in metri cubi per materiale [terra, terra dura, roccia].

const SECCHIO_M3 := 0.25
const VALORE := [1, 3, 8]            # monete per secchio, per materiale
const BONUS_OGNI := 10               # +10% ogni 10 secchi mandati su insieme

const NEGOZIO := [
	{"id": "pala", "nome": "Pala", "prezzo": 50, "desc": "Scava più veloce e più largo, anche la terra dura."},
	{"id": "zaino", "nome": "Zaino grande", "prezzo": 80, "desc": "Porta 20 secchi invece di 10."},
	{"id": "piccone", "nome": "Piccone", "prezzo": 300, "desc": "Scava tutto, anche la roccia."},
]

var monete := 0
var zaino := [0.0, 0.0, 0.0]
var pila := [0.0, 0.0, 0.0]
var capienza := 10
var attrezzi := [true, false, false]   # mani, pala, piccone
var comprati := {}


func _secchi(v: Array) -> float:
	return (v[0] + v[1] + v[2]) / SECCHIO_M3


func zaino_secchi() -> float:
	return _secchi(zaino)


func zaino_pieno() -> bool:
	return zaino_secchi() >= capienza


func pila_secchi() -> float:
	return _secchi(pila)


func aggiungi_terra(v: Vector3) -> void:
	zaino[0] += v.x
	zaino[1] += v.y
	zaino[2] += v.z


## Sposta tutto lo zaino sulla pila. Restituisce i secchi spostati.
func impila() -> float:
	var n := zaino_secchi()
	for m in 3:
		pila[m] += zaino[m]
		zaino[m] = 0.0
	return n


func bonus_pila() -> float:
	return floori(pila_secchi() / BONUS_OGNI) * 0.1


func valore_pila() -> int:
	var base := 0.0
	for m in 3:
		base += pila[m] / SECCHIO_M3 * VALORE[m]
	return int(round(base * (1.0 + bonus_pila())))


## Vende la pila. Restituisce le monete guadagnate.
func vendi_pila() -> int:
	var c := valore_pila()
	monete += c
	pila = [0.0, 0.0, 0.0]
	return c


## Compra un oggetto del negozio. Restituisce "" se riuscito, altrimenti il motivo.
func compra(id: String) -> String:
	if comprati.has(id):
		return "Già comprato"
	var item := {}
	for it in NEGOZIO:
		if it["id"] == id:
			item = it
	if item.is_empty():
		return "Oggetto sconosciuto"
	if monete < item["prezzo"]:
		return "Monete insufficienti"
	monete -= item["prezzo"]
	comprati[id] = true
	match id:
		"pala":
			attrezzi[1] = true
		"piccone":
			attrezzi[2] = true
		"zaino":
			capienza = 20
	return ""
