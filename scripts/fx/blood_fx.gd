class_name BloodFx
extends Node2D


@onready var _blood_burst := %BloodBurstParticles as CPUParticles2D
@onready var _blood_fountain := %BloodFountainParticles as CPUParticles2D

func _ready() -> void:
	_blood_fountain.emitting = false

func start(burst_angle: float, with_blood := true) -> void:
	_blood_burst.emitting = true
	_blood_burst.global_rotation = burst_angle
	_blood_fountain.emitting = with_blood
	SoundFxManagerSingleton.play(SoundFxManager.Type.EnemyBloodHit if with_blood else SoundFxManager.Type.EnemyMechaHit)
	await get_tree().create_timer(1.5).timeout
	_blood_fountain.emitting = false
	#await _blood_fountain.finished
	#queue_free()

func stop() -> void:
	_blood_burst.emitting = false
	_blood_fountain.emitting = false
