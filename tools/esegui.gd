extends Node
## Lancia uno script di prova come scena (così gli autoload come Rete esistono).
## Uso: godot --path . res://tools/esegui.tscn -- --tool res://tools/<script>.gd
## Lo script deve estendere Node: viene aggiunto come figlio e fa quello che deve nel suo _ready().


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--tool")
	if i < 0 or i + 1 >= args.size():
		push_error("Manca --tool res://tools/<script>.gd")
		get_tree().quit(1)
		return
	var n: Node = load(args[i + 1]).new()
	n.name = "Prova"
	add_child(n)
