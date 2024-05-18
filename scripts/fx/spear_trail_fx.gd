class_name SpearTrailFx
extends Node2D

#@export var from := Vector2(0, 0)
#@export var to := Vector2(100, 0)

@onready var _particles := %CPUParticles2D as CPUParticles2D
@onready var _path_line := %PathLine2D as Line2D
@onready var _default_path_width := _path_line.width

var _tween : Tween

func play(from: Vector2, to: Vector2, duration: float, auto_free: bool = false, with_line: bool = true) -> void:
	var motion := to - from
	
	show()
	global_position = from
	if with_line:
		var step := motion / (_path_line.get_point_count() - 1)
		for i in range(_path_line.get_point_count()):
			_path_line.set_point_position(i, i * step)
		_path_line.show()
		_path_line.width = _default_path_width
	else:
		_path_line.hide()
	_particles.emitting = true
	_particles.position = Vector2.ZERO
	
	if _tween != null:
		_tween.kill()
		
	_tween = create_tween()
	#_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_particles, "position", motion, duration)
	if with_line:
		_tween.parallel().tween_property(_path_line, "width", 0, duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_callback(_path_line.hide)
	_tween.tween_callback(_particles.set_emitting.bind(false))
	_tween.tween_interval(_particles.lifetime)
	_tween.tween_callback(hide)
	
	if auto_free:
		_tween.finished.connect(queue_free)
