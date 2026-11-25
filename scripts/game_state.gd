extends Node
## Stato della partita: monete, terra raccolta nell'attrezzo, secchi sul montacarichi,
## attrezzi posseduti.
##
## La terra scavata va nell'attrezzo (in unità: 1 unità = 0,25 m³). Con 10 unità
## si riempie un secchio (tasto Q), che poi si lancia, si raccoglie e si posa sul
## montacarichi. I secchi sono infiniti. La terra nell'attrezzo è tenuta in m³ per
## materiale [terra, terra dura, roccia], perché i materiali valgono diversamente.

const UNITA_M3 := 0.25
const UNITA_SECCHIO := 10
const VALORE := [1, 3, 8]            # monete per unità, per materiale
const BONUS_OGNI := 5                # +10% ogni 5 secchi mandati su insieme
const PILA_MAX := 75                 # posti sul montacarichi (5 x 5, 3 strati)

const NEGOZIO := [
	{"id": "pala", "nome": "Pala", "prezzo": 50, "desc": "Scava più veloce e più largo, anche la terra dura."},
	{"id": "contenitore", "nome": "Sacca capiente", "prezzo": 80, "desc": "Tieni 20 unità di terra invece di 10: due secchi prima di fermarti."},
	{"id": "piccone", "nome": "Piccone", "prezzo": 300, "desc": "Scava tutto, anche la roccia."},
]

var monete := 0
var terra := [0.0, 0.0, 0.0]         # m³ raccolti nell'attrezzo, per materiale
var capienza := 10                   # unità di terra che l'attrezzo può tenere
var pila: Array[int] = []            # valore in monete di ogni secchio sul montacarichi
var attrezzi := [true, false, false] # mani, pala, piccone
var comprati := {}


func terra_unita() -> float:
	return (terra[0] + terra[1] + terra[2]) / UNITA_M3


func terra_piena() -> bool:
	return terra_unita() >= capienza


func aggiungi_terra(v: Vector3) -> void:
	terra[0] += v.x
	terra[1] += v.y
	terra[2] += v.z


func puo_riempire() -> bool:
	return terra_unita() >= UNITA_SECCHIO - 0.001


## Riempie un secchio con 10 unità di terra (in proporzione ai materiali raccolti).
## Restituisce il valore in monete del secchio, o -1 se non c'è abbastanza terra.
func riempi_secchio() -> int:
	if not puo_riempire():
		return -1
	var f := minf(UNITA_SECCHIO / terra_unita(), 1.0)
	var valore := 0.0
	for m in 3:
		valore += terra[m] * f / UNITA_M3 * VALORE[m]
		terra[m] *= 1.0 - f
	return int(round(valore))


## Posa un secchio sul montacarichi. false se è pieno.
func impila(valore: int) -> bool:
	if pila.size() >= PILA_MAX:
		return false
	pila.append(valore)
	return true


func pila_secchi() -> int:
	return pila.size()


func bonus_pila() -> float:
	return floori(pila.size() / float(BONUS_OGNI)) * 0.1


func valore_pila() -> int:
	var base := 0
	for v in pila:
		base += v
	return int(round(base * (1.0 + bonus_pila())))


## Vende la pila. Restituisce le monete guadagnate.
func vendi_pila() -> int:
	var c := valore_pila()
	monete += c
	pila.clear()
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
		"contenitore":
			capienza = 20
	return ""
