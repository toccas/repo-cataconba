extends Node
## Impostazioni (autoload "Impostazioni"): volume, sensibilità del mouse, campo visivo,
## schermo intero e sincronia verticale. Si salvano in user://impostazioni.cfg e valgono
## subito (il giocatore ascolta il segnale "cambiate").

signal cambiate

const CFG := "user://impostazioni.cfg"

var volume := 0.8            # 0..1
var sensibilita := 1.0       # moltiplica la sensibilità di base del mouse
var fov := 80.0              # gradi
var schermo_intero := false
var vsync := true


func _ready() -> void:
	vsync = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK:
		_applica_audio()
		return
	volume = cfg.get_value("audio", "volume", volume)
	sensibilita = cfg.get_value("controlli", "sensibilita", sensibilita)
	fov = cfg.get_value("video", "fov", fov)
	schermo_intero = cfg.get_value("video", "schermo_intero", schermo_intero)
	vsync = cfg.get_value("video", "vsync", vsync)
	applica()


func salva() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("controlli", "sensibilita", sensibilita)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "schermo_intero", schermo_intero)
	cfg.set_value("video", "vsync", vsync)
	cfg.save(CFG)


func applica() -> void:
	_applica_audio()
	if DisplayServer.get_name() != "headless":
		var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if schermo_intero else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != modo:
			DisplayServer.window_set_mode(modo)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	cambiate.emit()


func _applica_audio() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
