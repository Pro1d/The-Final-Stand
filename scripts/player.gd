class_name Player
extends CharacterBody2D

signal enemy_killed(
	count: int, spear_path_length: int,
	enemies_center: Vector2,
	target_pos: Vector2
)
signal combo_level_changed()

const SpearTrailFxPackedScene := preload("res://scenes/fx/spear_trail_fx.tscn")
const PlayerDecoyPackedScene := preload("res://scenes/player_decoy.tscn")

enum ActionState {
	MOVING,
	THROWING,
	TELEPORTING,
	RETRIEVING
}

const MAX_SPEED := 80.0  # px/s
const ACCEL := MAX_SPEED / 0.15  # px/s²
const THROW_DURATION := 0.25  # s
const BLINK_DURATION := 0.2  # s
const RETRIEVE_DURATION := 0.35  # s
const COMBO_THRESHOLD := 1.5

var _state := ActionState.MOVING
var _attack_button_hold := false
var _target_enemy_position := Vector2.ZERO
var _target_enemy : Enemy
var _has_move_target := false
var _target_move_position := Vector2.ZERO
var _facing := Vector2.RIGHT
var current_combo_level := 0
var _combo_countdown := 0.0
var can_attack := true

@onready var _target_marker := %TargetSprite2D as Node2D
@onready var _spear := %ThrowingSpear as ThrowingSpear
@onready var _body_sprite := %BodySprite as AnimatedSprite2D
@onready var _radius := (($CollisionShape2D as CollisionShape2D).shape as CircleShape2D).radius
@onready var _spear_handle : Array[Node2D] = [
	%SpearHandleRight, %SpearHandleDown, %SpearHandleLeft, %SpearHandleUp
]
func _enter_tree() -> void:
	Config.player_node = self

func _ready() -> void:
	_update_target_marker()

func reset(pos: Vector2) -> void:
	# FOR SAFETY DO NOT RESET
	_state = ActionState.MOVING
	can_attack = true
	_attack_button_hold = false
	_has_move_target = false
	_target_enemy = null
	_facing = Vector2.RIGHT
	current_combo_level = 0
	combo_level_changed.emit()
	global_position = pos

func _unhandled_input(event: InputEvent) -> void:
	var cursor_pos := Config.mouse_global_position() #viewport_to_global(get_viewport().get_mouse_position())
	var mm := event as InputEventMouseMotion
	if mm != null:
		match _state:
			ActionState.MOVING:
				get_viewport().set_input_as_handled()
				if mm.button_mask == MOUSE_BUTTON_LEFT and _has_move_target:
					_target_move_position = cursor_pos
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		match _state:
			ActionState.MOVING:
				if mb.pressed:
					var closest_enemy := Enemy.find_closest_enemy(cursor_pos, get_world_2d().direct_space_state)
					if closest_enemy != null and can_attack:
						_has_move_target = false
						if closest_enemy.aim_mode != Enemy.AimMode.NO_AIM:
							_attack_button_hold = true
							_target_move_position = global_position
							_throw_spear(closest_enemy)
					else:
						_target_move_position = cursor_pos
						_has_move_target = true
			ActionState.THROWING:
				if mb.pressed:
					_target_move_position = cursor_pos
					_has_move_target = true
					# TODO queue throwing
				else:
					_attack_button_hold = false
			ActionState.RETRIEVING, ActionState.TELEPORTING:
				pass
				#var closest_enemy := Enemy.find_closest_enemy(cursor_pos, get_world_2d().direct_space_state)
				#if closest_enemy == null:
					#_target_move_position = cursor_pos
					#_has_move_target = true
				# TODO queue throwing

func _physics_process(delta: float) -> void:
	_update_combo(delta)
	match _state:
		ActionState.MOVING:
			#var screen_mouse_pos := get_viewport().get_mouse_position()
			#var mouse_pos := _viewport_to_global(screen_mouse_pos)
			if _has_move_target:
				var motion := _target_move_position - global_position
				var distance := motion.length()
				var direction := motion / distance
				var target_velocity := minf(sqrt(distance * 2 * ACCEL), MAX_SPEED)
				const reach_thr := 1.0  # px
				velocity = velocity.move_toward(
					direction * target_velocity if distance > reach_thr else motion / delta,
					ACCEL * delta
				)
				move_and_slide()
				if global_position.distance_to(_target_move_position) < reach_thr:
					velocity = Vector2.ZERO
				if not velocity.is_zero_approx():
					_facing = velocity.normalized()
					SoundFxManagerSingleton.play_often(SoundFxManager.Type.PlayerWalk, 0.22)
			else:
				velocity = Vector2.ZERO
		ActionState.THROWING:
			pass
		ActionState.TELEPORTING:
			pass
		ActionState.RETRIEVING:
			pass

func _process(_delta: float) -> void:
	# input
	var cursor_pos := Config.mouse_global_position() #_viewport_to_global(get_viewport().get_mouse_position())
	match _state:
		ActionState.MOVING:
			get_viewport().set_input_as_handled()
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _has_move_target:
				_target_move_position = cursor_pos
	# visual
	_update_target_marker()
	_update_direction_display()
	if _state == ActionState.MOVING and not velocity.is_zero_approx():
		_body_sprite.animation = &"running"
	else:
		_body_sprite.animation = &"idle"
	# aim
	_update_aimed_enemy()

var _aimed_enemy : Enemy = null
func _update_aimed_enemy() -> void:
	var cursor_pos := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	var new_aimed_enemy := Enemy.find_closest_enemy(cursor_pos, get_world_2d().direct_space_state)
	if _aimed_enemy != new_aimed_enemy:
		if _aimed_enemy != null:
			_aimed_enemy.set_aimed(false)
		if new_aimed_enemy != null:
			new_aimed_enemy.set_aimed(true)
		_aimed_enemy = new_aimed_enemy

func _start_moving() -> void:
	_state = ActionState.MOVING
	velocity = Vector2.ZERO

func _throw_spear(enemy: Enemy) -> void:
	_state = ActionState.THROWING
	
	var spear_from := global_position
	var spear_to := enemy.global_position
	var spear_path_length := spear_from.distance_to(spear_to)
	var throw_dir := spear_from.direction_to(spear_to)
	var throw_angle := throw_dir.angle()
	
	velocity = Vector2.ZERO
	_has_move_target = false
	_target_enemy_position = enemy.global_position
	_target_enemy = enemy
	_facing = throw_dir
	
	# Spear trail
	var spear_trail := SpearTrailFxPackedScene.instantiate() as SpearTrailFx
	get_parent().add_child(spear_trail)
	spear_trail.play(spear_from, spear_to, THROW_DURATION, true)
	
	# Spear blink
	_spear.direction = throw_angle
	_spear.stick_to(_target_enemy, _target_enemy.hit_anchor.position - _spear.peak_position())
	_spear.make_highlight(THROW_DURATION * 1.0)
	
	# Find hit enemies
	var params := PhysicsShapeQueryParameters2D.new()
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = Config.LAYER_ENEMY_HITBOX
	var shape := CapsuleShape2D.new()
	shape.height = spear_path_length
	shape.radius = 4  # px
	params.shape = shape
	params.transform = Transform2D(throw_angle + PI / 2, (spear_from + spear_to) / 2)
	var intersections := get_world_2d().direct_space_state.intersect_shape(params, 256)
	
	# Kill hit enemies
	var kill_count := 0
	var avg_position := Vector2.ZERO
	for inter: Dictionary in intersections:
		var e := Enemy.find_parent_enemy(inter["collider"] as Node2D)
		if e != null:
			if e.aim_mode == Enemy.AimMode.AIM_ONLY and e != _target_enemy:
				e.trigger_shield()
			else:
				var animation_delay_ratio := e.global_position.distance_to(spear_from) / spear_path_length
				animation_delay_ratio *= 0.2
				var hit_strength := 3.0 if e == _target_enemy else 1.0
				e.kill(throw_dir.angle(), hit_strength, animation_delay_ratio * THROW_DURATION)
				kill_count += 1
				avg_position += e.global_position
	avg_position /= kill_count
	_trigger_combo()
	enemy_killed.emit(kill_count, spear_path_length, avg_position, _target_enemy_position)
	
	await get_tree().create_timer(THROW_DURATION).timeout
	
	assert(_state == ActionState.THROWING)
	if _attack_button_hold:
		_teleport_to_spear()
	else:
		_retrieve_spear()

func _teleport_to_spear() -> void:
	_state = ActionState.TELEPORTING
	
	# Decoy
	var player_decoy := PlayerDecoyPackedScene.instantiate() as PlayerDecoy
	get_parent().add_child(player_decoy)
	player_decoy.global_position = global_position
	player_decoy.set_facing(_facing)
	
	# Relocate spear
	_spear.unstick()
	_update_direction_display()
	
	# Teleport player
	global_position = _target_enemy_position
	move_and_collide(Vector2.ZERO)  # solve collisions
	SoundFxManagerSingleton.play(SoundFxManager.Type.PlayerTeleport)
	
	await get_tree().create_timer(BLINK_DURATION).timeout
	assert(_state == ActionState.TELEPORTING)
	_start_moving()


func _retrieve_spear() -> void:
	_state = ActionState.RETRIEVING
	const FX_DURATION := THROW_DURATION # RETRIEVE_DURATION - FX_DELAY # s
	const FX_DELAY := RETRIEVE_DURATION - FX_DURATION # 0.2  # s
	await get_tree().create_timer(FX_DELAY).timeout
	
	var spear_pos := _spear.global_position
	var spear_trail := SpearTrailFxPackedScene.instantiate() as SpearTrailFx
	get_parent().add_child(spear_trail)
	spear_trail.play(spear_pos, global_position, FX_DURATION, true, false)
	
	await get_tree().create_timer(RETRIEVE_DURATION - FX_DELAY).timeout
	assert(_state == ActionState.RETRIEVING)
	
	# Relocate spear
	_spear.unstick()
	_spear.make_highlight(0.25)
	SoundFxManagerSingleton.play(SoundFxManager.Type.PlayerRetrieve)
	_update_direction_display()
	
	_start_moving()

func _update_target_marker() -> void:
	if _has_move_target: # and _state == ActionState.MOVING:
		if _has_move_target and global_position.distance_to(_target_move_position) > 16:
			_target_marker.show()
			_target_marker.global_position = _target_move_position.round()
		else:
			_target_marker.hide()
	else:
		_target_marker.hide()

var _current_display_direction := 0
func _update_direction_display() -> void:
	var angle := _facing.angle()
	if abs(angle_difference(_current_display_direction * Quadrant.q4, angle)) > Quadrant.q4 / 2 * 1.05:
		_current_display_direction = Quadrant.angle_to_q4(angle)
	var q2 := 1 if _body_sprite.flip_h else 0
	if abs(angle_difference(q2 * Quadrant.q2, angle)) > Quadrant.q2 / 2 * 1.05:
		q2 = Quadrant.angle_to_q2(angle)
		_body_sprite.flip_h = (q2 == 1)
	if not _spear.is_sticked():
		_spear.direction = angle
		_spear.position = _spear_handle[q2 * 2].position
		
func distance_to(pos: Vector2) -> float:
	return maxf(pos.distance_to(global_position) - _radius, 0.0)

func _update_combo(delta: float) -> void:
	if _combo_countdown > 0:
		_combo_countdown -= delta
		if _combo_countdown <= 0 and current_combo_level > 0:
			_combo_countdown += COMBO_THRESHOLD
			current_combo_level = Config.downgrade_combo_level(current_combo_level)
			combo_level_changed.emit()

func _trigger_combo() -> void:
	_combo_countdown = COMBO_THRESHOLD
	if current_combo_level < Config.combo_max_level:
		current_combo_level += 1
		combo_level_changed.emit()
