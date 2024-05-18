class_name Castle
extends StaticBody2D

signal destroyed

var hit_points := 0

@onready var _collision_shape := %CollisionShape2D as CollisionShape2D
@onready var _center := _collision_shape.global_position
@onready var _size := (_collision_shape.shape as RectangleShape2D).size
@onready var _fires : Array[CPUParticles2D] = [
	%FireCPUParticles2D, %FireCPUParticles2D2, %FireCPUParticles2D3
]
@onready var _explode_particles := %ExplodeCPUParticles2D as CPUParticles2D

func _enter_tree() -> void:
	Config.castle_node = self

func _ready() -> void:
	reset()

func reset() -> void:
	hit_points = Config.CASTLE_MAX_HP
	_fires.shuffle()
	for f in _fires:
		f.emitting = false
	_explode_particles.restart()
	_explode_particles.emitting = false

func take_hit(damage: int) -> void:
	if hit_points <= 0:
		return
	else:
		hit_points = max(hit_points - damage, 0)
		SoundFxManagerSingleton.play(SoundFxManager.Type.CastleHit)
		var damaged := (1 - float(hit_points) / Config.CASTLE_MAX_HP) ** 2
		for i in _fires.size():
			var f := _fires[i]
			var e := damaged > float(i + 1) / (_fires.size() + 1)
			if e != f.emitting:
				f.emitting = e
		if hit_points == 0:
			destroyed.emit()
			SoundFxManagerSingleton.play(SoundFxManager.Type.CastleDestroyed)
			_explode_particles.emitting = true

func distance_to(pos: Vector2) -> float:
	var delta := _center - pos
	return (delta.abs() - (_size / 2)).maxf(0.0).length()

func throw_direction(pos: Vector2) -> Vector2:
	var delta := _center - pos
	return ((delta.abs() - (_size / 2)).maxf(0.0) * delta.sign()).normalized()

func ensure_inside(pos: Vector2, radius: float) -> Vector2:
	var r := Rect2(_center - _size / 2, _size)
	if r.has_point(pos):
		return pos
	var R := minf(_size.x, _size.y) / 2 - 1.0 # 1 px margin
	return pos + ((pos - _center) / radius) * R
