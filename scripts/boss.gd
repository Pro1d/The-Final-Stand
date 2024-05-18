class_name Boss
extends Enemy

func _ready() -> void:
	super()
	SoundFxManagerSingleton.play(SoundFxManager.Type.BossEnter)
	_body_sprite.frame_changed.connect(
		SoundFxManagerSingleton.play.bind(SoundFxManager.Type.BossWalk)
	)
	died.connect(SoundFxManagerSingleton.play.bind(SoundFxManager.Type.BossDied))
