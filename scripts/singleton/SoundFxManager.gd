class_name SoundFxManager
extends Node

enum Type {
	PlayerWalk,
	#PlayerThrow,
	PlayerTeleport,
	PlayerRetrieve,
	EnemyBloodHit,
	EnemyMechaHit,
	EnemyShield,
	#EnemyWalk,
	EnemyAttackThrow,
	#EnemyAttackBig,
	EnemyAttackSmall,
	#ProjectileHitBig,
	#ProjectileHitSmall,
	CastleHit,
	CastleDestroyed,
	BossEnter,
	BossWalk,
	BossDied,
}

@onready var ui_sound := AudioStreamPlayer.new()
var _players : Array[AudioStreamPlayer]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	ui_sound.bus = &"UI"
	ui_sound.stream = preload("res://assets/sounds/tuck.ogg")
	add_child(ui_sound)
	
	var do := func(r: AudioStream, db: float = 0.0, max_p := 3) -> AudioStreamPlayer:
		var asp := AudioStreamPlayer.new()
		var random := AudioStreamRandomizer.new()
		random.add_stream(0, r)
		random.random_pitch = 1.05
		random.random_volume_offset_db = 0.5
		asp.bus = &"SoundFx"
		asp.stream = random
		asp.volume_db = db
		asp.max_polyphony = max_p
		add_child(asp)
		return asp
	
	_players.resize(Type.size())
	_players[Type.PlayerWalk] = do.call(preload("res://assets/sounds/step_1.wav"), -15, 1)
	_players[Type.PlayerTeleport] = do.call(preload("res://assets/sounds/teleport.ogg"))
	_players[Type.PlayerRetrieve] = do.call(preload("res://assets/sounds/MiniHitNice.ogg"))
	_players[Type.EnemyBloodHit] = do.call(preload("res://assets/sounds/bloody_hit.ogg"))
	_players[Type.EnemyMechaHit] = do.call(preload("res://assets/sounds/mecha_hit.ogg"))
	_players[Type.EnemyShield] = do.call(preload("res://assets/sounds/ImpactOnSteelShield.ogg"), +3)
	_players[Type.EnemyAttackSmall] = do.call(preload("res://assets/sounds/swish.ogg"))
	_players[Type.EnemyAttackThrow] = do.call(preload("res://assets/sounds/miss.ogg"))
	_players[Type.CastleHit] = do.call(preload("res://assets/sounds/MiniHit.ogg"))
	_players[Type.CastleDestroyed] = do.call(preload("res://assets/sounds/FunkyExplosion.ogg"), +9)
	_players[Type.BossEnter] = do.call(preload("res://assets/sounds/grunt_01.ogg"), +9)
	_players[Type.BossWalk] = do.call(preload("res://assets/sounds/big_step.ogg"), +9)
	_players[Type.BossDied] = do.call(preload("res://assets/sounds/monster_07.ogg"), +9)

func play(type: Type) -> void:
	_players[type].play()

var _next_play_time := {}
func play_often(type: Type, min_delay: float, random_factor := 1.05) -> void:
	var t := _next_play_time.get(type, _time) as float
	if t <= _time:
		play(type)
		_next_play_time[type] = _time + (1 + (random_factor - 1) * randf()) * min_delay

var _time := 0.0
func _process(delta: float) -> void:
	_time += delta

func keep_until_finished(audio: Node) -> void: # AudioStreamPlayer[2D]
	audio.get_parent().remove_child(audio)
	add_child(audio)
	
	var asp := audio as AudioStreamPlayer
	if asp != null:
		asp.finished.connect(audio.queue_free)
		return
	var asp2d := audio as AudioStreamPlayer2D
	if asp2d != null:
		asp2d.finished.connect(audio.queue_free)
		return
	var asp3d := audio as AudioStreamPlayer3D
	if asp3d != null:
		asp3d.finished.connect(audio.queue_free)
		return

func connect_all_buttons(node: Node) -> void:
	if node is Button:
		connect_button(node as Button)
	if node is OptionButton:
		connect_option_button(node as OptionButton)
	for c in node.get_children():
		connect_all_buttons(c)

func connect_button(button: Button) -> void:
	button.pressed.connect(ui_sound.play)

func connect_option_button(button: OptionButton) -> void:
	button.item_selected.connect(ui_sound.play)
