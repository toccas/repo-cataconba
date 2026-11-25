extends Node
## Rete (autoload "Rete"): crea o raggiunge una partita co-op online con ENet.
##
## Chi ospita è il server: tiene la partita vera (monete, montacarichi, secchi e ossa
## a terra, tomba) e la manda agli altri. Lo scavo invece lo fa ogni giocatore sul
## suo computer e lo manda a tutti (togliere terra è commutativo: l'ordine non conta).
##
## Per giocare via internet chi ospita deve aprire la porta UDP PORTA sul router:
## all'avvio si prova da soli con UPnP; se il router non lo permette serve
## aprirla a mano oppure usare una VPN come Tailscale, ZeroTier o Radmin VPN.

signal stato_cambiato(testo: String)
signal giocatori_cambiati
signal connesso            # partita pronta (anche da solo)
signal disconnesso(motivo: String)

const PORTA := 7777
const MAX_GIOCATORI := 4

var nome := "Scavatore"
var giocatori := {}        # id -> nome (compreso me)
var online := false
var ip_pubblico := ""
var _upnp_thread: Thread


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func mio_id() -> int:
	return multiplayer.get_unique_id()


func sono_server() -> bool:
	return multiplayer.is_server()


func nome_di(id: int) -> String:
	return giocatori.get(id, "Giocatore %d" % id)


## Partita da solo: nessuna rete, tutto locale.
func gioca_da_solo() -> void:
	online = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	giocatori = {1: nome}
	connesso.emit()


## Ospita una partita sulla porta PORTA. Restituisce "" se va, altrimenti l'errore.
func ospita(porta := PORTA) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(porta, MAX_GIOCATORI - 1)
	if err != OK:
		return "Non riesco ad aprire la porta %d (%s)" % [porta, error_string(err)]
	multiplayer.multiplayer_peer = peer
	online = true
	giocatori = {1: nome}
	stato_cambiato.emit("Partita ospitata sulla porta %d" % porta)
	_upnp_thread = Thread.new()
	_upnp_thread.start(_apri_porta.bind(porta))
	connesso.emit()
	return ""


## Entra nella partita di un altro giocatore.
func entra(indirizzo: String, porta := PORTA) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(indirizzo, porta)
	if err != OK:
		return "Indirizzo non valido (%s)" % error_string(err)
	multiplayer.multiplayer_peer = peer
	online = true
	stato_cambiato.emit("Mi collego a %s:%d..." % [indirizzo, porta])
	return ""


func esci() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	giocatori.clear()


## UPnP (in un thread, la ricerca del router richiede qualche secondo).
func _apri_porta(porta: int) -> void:
	var upnp := UPNP.new()
	var testo := ""
	if upnp.discover(2000, 2) != UPNP.UPNP_RESULT_SUCCESS or upnp.get_device_count() == 0 or not upnp.get_gateway() or not upnp.get_gateway().is_valid_gateway():
		testo = "UPnP non disponibile: apri a mano la porta UDP %d sul router o usate una VPN" % porta
	elif upnp.add_port_mapping(porta, porta, "Scava Catacomba", "UDP") != UPNP.UPNP_RESULT_SUCCESS:
		testo = "Il router non ha aperto la porta %d: aprila a mano o usate una VPN" % porta
	else:
		var ip := upnp.query_external_address()
		testo = "Porta aperta. Gli amici si collegano a  %s" % ip
		call_deferred("set", "ip_pubblico", ip)
	call_deferred("emit_signal", "stato_cambiato", testo)


func _exit_tree() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()


# --- elenco dei giocatori -------------------------------------------------------

func _on_connected() -> void:
	giocatori[mio_id()] = nome
	_presentati.rpc_id(1, nome)


func _on_failed() -> void:
	esci()
	disconnesso.emit("Connessione non riuscita")


func _on_server_gone() -> void:
	esci()
	disconnesso.emit("La partita è stata chiusa da chi la ospitava")


func _on_peer_connected(_id: int) -> void:
	pass   # aspetto che si presenti col nome


func _on_peer_disconnected(id: int) -> void:
	if giocatori.has(id):
		var n: String = giocatori[id]
		giocatori.erase(id)
		stato_cambiato.emit("%s è uscito" % n)
		giocatori_cambiati.emit()
		if sono_server():
			_elenco.rpc(giocatori)


## Un nuovo giocatore manda il suo nome al server.
@rpc("any_peer", "reliable")
func _presentati(n: String) -> void:
	if not sono_server():
		return
	var id := multiplayer.get_remote_sender_id()
	n = n.strip_edges().left(20)
	if n == "":
		n = "Giocatore %d" % id
	giocatori[id] = n
	_elenco.rpc(giocatori)
	stato_cambiato.emit("%s è entrato" % n)
	giocatori_cambiati.emit()


## Il server manda a tutti l'elenco aggiornato.
@rpc("authority", "reliable")
func _elenco(g: Dictionary) -> void:
	var nuovo := not giocatori.has(1)
	giocatori = g
	giocatori_cambiati.emit()
	if nuovo:
		connesso.emit()
