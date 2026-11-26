extends RefCounted
## Slot di salvataggio: user://salvataggi/slot_N.dat (N da 1 a SLOT).
## Ogni file contiene prima un'intestazione piccola (quella che mostra il menu) e poi la
## partita intera. Il vecchio user://salvataggio.dat (quando c'era un solo salvataggio)
## viene copiato nello slot 1 la prima volta: l'originale resta dov'è.

const SLOT := 3
const CARTELLA := "user://salvataggi/"
const VECCHIO := "user://salvataggio.dat"


static func percorso(n: int) -> String:
	return CARTELLA + "slot_%d.dat" % n


static func esiste(n: int) -> bool:
	return FileAccess.file_exists(percorso(n))


## Intestazione dello slot n: monete, salvato_il (unix), tempo (secondi di gioco),
## scheletri, cancello. {} se lo slot è vuoto o illeggibile.
static func info(n: int) -> Dictionary:
	var f := FileAccess.open(percorso(n), FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	f.close()
	if not v is Dictionary:
		return {}
	if v.has("versione"):   # formato vecchio: la partita intera, senza intestazione
		return intestazione(v, FileAccess.get_modified_time(percorso(n)))
	return v


## L'intestazione di una partita d (quella che main.gd salva).
static func intestazione(d: Dictionary, quando: int) -> Dictionary:
	var stato: Dictionary = d.get("stato", {})
	return {
		"monete": stato.get("monete", 0),
		"salvato_il": quando,
		"tempo": d.get("tempo", 0.0),
		"scheletri": d.get("risorti", 0),
		"cancello": stato.get("cancello", false),
	}


## La partita intera dello slot n, o {} se non c'è.
static func leggi(n: int) -> Dictionary:
	var f := FileAccess.open(percorso(n), FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	if v is Dictionary and not v.has("versione"):
		v = f.get_var()
	f.close()
	return v if v is Dictionary else {}


## Scrive la partita d nello slot n (prima in un file temporaneo: se il gioco si chiude
## a metà il salvataggio vecchio resta buono).
static func scrivi(n: int, d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARTELLA))
	var tmp := percorso(n) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(intestazione(d, int(Time.get_unix_time_from_system())))
	f.store_var(d)
	f.close()
	var dest := ProjectSettings.globalize_path(percorso(n))
	if FileAccess.file_exists(percorso(n)):
		DirAccess.remove_absolute(dest)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), dest) == OK


static func elimina(n: int) -> void:
	if esiste(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(percorso(n)))


## Lo slot salvato più di recente (0 se non ce n'è nessuno).
static func ultimo() -> int:
	var best := 0
	var quando := -1
	for n in range(1, SLOT + 1):
		var i := info(n)
		if not i.is_empty() and int(i.get("salvato_il", 0)) > quando:
			quando = int(i.get("salvato_il", 0))
			best = n
	return best


## Il primo slot vuoto (0 se sono tutti pieni).
static func libero() -> int:
	for n in range(1, SLOT + 1):
		if not esiste(n):
			return n
	return 0


## Copia il vecchio salvataggio unico nello slot 1 (solo se gli slot sono tutti vuoti).
static func migra() -> void:
	if not FileAccess.file_exists(VECCHIO) or ultimo() != 0:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARTELLA))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(VECCHIO), ProjectSettings.globalize_path(percorso(1)))


## Testo di una riga per il menu: "120 monete · 2 scheletri · 1 h 05 min · 26/11 18:30".
static func descrivi(i: Dictionary) -> String:
	if i.is_empty():
		return "vuoto"
	var parti := ["%d monete" % int(i.get("monete", 0))]
	var sk := int(i.get("scheletri", 0))
	if sk > 0:
		parti.append("%d %s" % [sk, "scheletro" if sk == 1 else "scheletri"])
	var t := int(i.get("tempo", 0.0))
	if t > 0:
		parti.append("%d h %02d min" % [t / 3600, (t / 60) % 60] if t >= 3600 else "%d min" % maxi(t / 60, 1))
	var u := int(i.get("salvato_il", 0))
	if u > 0:
		var bias: int = Time.get_time_zone_from_system().get("bias", 0)
		var d := Time.get_datetime_dict_from_unix_time(u + bias * 60)
		parti.append("%02d/%02d %02d:%02d" % [d.day, d.month, d.hour, d.minute])
	return "  ·  ".join(parti)
