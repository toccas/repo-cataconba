extends Node
## Stato della partita: monete, terra raccolta nell'attrezzo, secchi sul montacarichi,
## livelli dei potenziamenti comprati e oggetti consumabili (dinamite).
##
## La terra scavata va nell'attrezzo (in unità: 1 unità = 0,25 m³). Con 10 unità
## si riempie un secchio (tasto Q), che poi si lancia, si raccoglie e si posa sul
## montacarichi. I secchi sono infiniti. La terra nell'attrezzo è tenuta in m³ per
## materiale [terra, terra dura, roccia], perché i materiali valgono diversamente.
##
## Monete, livelli e consumabili sono della squadra (in co-op li decide il server).

const UNITA_M3 := 0.25
const UNITA_SECCHIO := 10
const VALORE := [1, 3, 8]            # monete per unità, per materiale
const BONUS_OGNI := 5                # bonus ogni 5 secchi mandati su insieme

## Negozio. tipo "livelli": si migliora a livelli (prezzi[i] = prezzo del livello i+1,
## desc[i] = cosa dà quel livello). tipo "consumabile": si compra un pezzo alla volta
## fino a "max" nell'inventario.
const NEGOZIO := [
	{"id": "pala", "cat": "Attrezzi", "nome": "Pala", "tipo": "livelli",
		"prezzi": [50, 150, 400, 900],
		"desc": ["Scava più veloce e più largo, anche la terra dura.", "Pala +25%: colpi più ampi.",
			"Pala +50%.", "Pala +75%: la migliore."]},
	{"id": "piccone", "cat": "Attrezzi", "nome": "Piccone", "tipo": "livelli",
		"prezzi": [300, 700, 1500, 3000],
		"desc": ["Scava tutto, anche la roccia.", "Piccone +25%.", "Piccone +50%.", "Piccone +75%: il migliore."]},
	{"id": "contenitore", "cat": "Capienza e trasporto", "nome": "Sacca", "tipo": "livelli",
		"prezzi": [80, 250, 600],
		"desc": ["Tieni 20 unità di terra: due secchi prima di fermarti.", "30 unità di terra.", "40 unità di terra."]},
	{"id": "gerla", "cat": "Capienza e trasporto", "nome": "Gerla", "tipo": "livelli",
		"prezzi": [200, 600],
		"desc": ["Porta 2 secchi insieme.", "Porta 3 secchi insieme."]},
	{"id": "braccia", "cat": "Capienza e trasporto", "nome": "Braccia forti", "tipo": "livelli",
		"prezzi": [100, 300],
		"desc": ["Lanci i secchi e le ossa più lontano.", "Lanci ancora più lontano."]},
	{"id": "piattaforma", "cat": "Montacarichi", "nome": "Piattaforma grande", "tipo": "livelli",
		"prezzi": [150, 450],
		"desc": ["Il montacarichi tiene 100 secchi.", "Il montacarichi tiene 125 secchi."]},
	{"id": "argano", "cat": "Montacarichi", "nome": "Argano", "tipo": "livelli",
		"prezzi": [200, 600, 1400],
		"desc": ["Bonus pila: +15% ogni 5 secchi.", "+20% ogni 5 secchi.", "+25% ogni 5 secchi."]},
	{"id": "scheletri", "cat": "Scheletri e carrello", "nome": "Scheletri instancabili", "tipo": "livelli",
		"prezzi": [300, 800, 2000],
		"desc": ["Gli scheletri lavoratori camminano e scavano il 30% più veloci.", "+60%.", "+90%: i migliori operai."]},
	{"id": "rotaie", "cat": "Scheletri e carrello", "nome": "Rotaie", "tipo": "consumabile",
		"prezzo": 60, "pacco": 10, "max": 200,
		"desc": "10 pezzi di rotaia: R guardando il pavimento per posarli, R su una rotaia per toglierla."},
	{"id": "vagone", "cat": "Scheletri e carrello", "nome": "Carrello", "tipo": "livelli",
		"prezzi": [250],
		"desc": ["Un carrello da miniera: compare sulle rotaie vicino al montacarichi. Ci metti fino a 6 secchi (E), lo spingi camminandoci contro e accanto al montacarichi si ribalta da solo."]},
	{"id": "dinamite", "cat": "Scheletri e carrello", "nome": "Dinamite", "tipo": "consumabile",
		"prezzo": 40, "max": 4,
		"desc": "Un candelotto: F per prenderlo in mano, tasto destro per lanciarlo. Esplode dopo 3 s."},
]

var monete := 0
var terra := [0.0, 0.0, 0.0]         # m³ raccolti nell'attrezzo, per materiale
var pila: Array[int] = []            # valore in monete di ogni secchio sul montacarichi
var livelli := {}                    # id -> livello comprato (0 = niente)
var inventario := {}                 # id -> pezzi (consumabili)

# ricavati dai livelli (vedi _applica)
var capienza := 10                   # unità di terra che l'attrezzo può tenere
var attrezzi := [true, false, false] # mani, pala, piccone
var comprati := {}                   # id -> true se livello >= 1


func _init() -> void:
	_applica()


func livello(id: String) -> int:
	return livelli.get(id, 0)


func voce(id: String) -> Dictionary:
	for it in NEGOZIO:
		if it["id"] == id:
			return it
	return {}


func livello_max(id: String) -> int:
	var it := voce(id)
	return it["prezzi"].size() if it.get("tipo") == "livelli" else 0


func pezzi(id: String) -> int:
	return inventario.get(id, 0)


## Ricalcola i valori che dipendono dai livelli.
func _applica() -> void:
	capienza = 10 + 10 * livello("contenitore")
	attrezzi = [true, livello("pala") > 0, livello("piccone") > 0]
	comprati = {}
	for id in livelli:
		if livelli[id] > 0:
			comprati[id] = true


## Moltiplicatore di raggio e forza dell'attrezzo (0 mani, 1 pala, 2 piccone).
func forza_attrezzo(tool_i: int) -> float:
	var id: String = ["", "pala", "piccone"][tool_i]
	if id == "":
		return 1.0
	return 1.0 + 0.25 * maxi(livello(id) - 1, 0)


## Velocità di cammino e scavo degli scheletri lavoratori.
func forza_scheletri() -> float:
	return 1.0 + 0.3 * livello("scheletri")


## Quanti secchi si portano insieme.
func gerla() -> int:
	return 1 + livello("gerla")


## Moltiplicatore della velocità di lancio.
func forza_lancio() -> float:
	return 1.0 + 0.35 * livello("braccia")


func pila_max() -> int:
	return 75 + 25 * livello("piattaforma")


func bonus_passo() -> float:
	return 0.10 + 0.05 * livello("argano")


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
	if pila.size() >= pila_max():
		return false
	pila.append(valore)
	return true


func pila_secchi() -> int:
	return pila.size()


func bonus_pila() -> float:
	return floori(pila.size() / float(BONUS_OGNI)) * bonus_passo()


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


## Prezzo del prossimo acquisto di id (-1 se non si può: livello massimo o inventario pieno).
func prezzo(id: String) -> int:
	var it := voce(id)
	if it.is_empty():
		return -1
	if it["tipo"] == "consumabile":
		return it["prezzo"] if pezzi(id) + it.get("pacco", 1) <= it["max"] else -1
	var l := livello(id)
	return it["prezzi"][l] if l < it["prezzi"].size() else -1


## Compra il prossimo livello (o un pezzo) di id. Restituisce "" se riuscito, altrimenti il motivo.
func compra(id: String) -> String:
	var it := voce(id)
	if it.is_empty():
		return "Oggetto sconosciuto"
	var p := prezzo(id)
	if p < 0:
		return "Ne hai già %d (massimo)" % it["max"] if it["tipo"] == "consumabile" else "Già al livello massimo"
	if monete < p:
		return "Monete insufficienti"
	monete -= p
	if it["tipo"] == "consumabile":
		inventario[id] = pezzi(id) + it.get("pacco", 1)
	else:
		livelli[id] = livello(id) + 1
	_applica()
	return ""


## Restituisce un consumabile (es. una rotaia tolta).
func rendi(id: String) -> void:
	inventario[id] = pezzi(id) + 1


## Usa un consumabile. false se non ce n'è.
func usa(id: String) -> bool:
	if pezzi(id) <= 0:
		return false
	inventario[id] = pezzi(id) - 1
	return true


## Stato condiviso da mandare in rete / salvare.
func esporta() -> Dictionary:
	return {"monete": monete, "pila": pila.duplicate(), "livelli": livelli.duplicate(), "inventario": inventario.duplicate()}


func importa(d: Dictionary) -> void:
	monete = d.get("monete", 0)
	pila.assign(d.get("pila", []))
	livelli = d.get("livelli", {}).duplicate()
	inventario = d.get("inventario", {}).duplicate()
	_applica()
