extends PanelContainer

signal close_clicked

@onready var _players : Array[AnimationPlayer] = [
	%HelpMove/%AnimationPlayer, %HelpRetrieve/%AnimationPlayer, %HelpTeleport/%AnimationPlayer
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	(%CloseButton as Button).pressed.connect(close_clicked.emit)
	visibility_changed.connect(func() -> void:
		for p in _players:
			if visible:
				p.play(&"play")
			else:
				p.play(&"RESET"))
