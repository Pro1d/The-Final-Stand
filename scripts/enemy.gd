class_name Enemy
extends CharacterBody2D

signal died()

const ProjectilePackedScene := preload("res://scenes/projectile.tscn")

enum State { RUNNING, ATTACKING, DEAD }
enum AimMode { NORMAL, NO_AIM, AIM_ONLY, NONE }
enum Type { UNKNOWN=0, MAN_AT_ARMS, ARCHER, HORSEMAN, SIEGE, GIANT }

const ATTACK_COOLDOWN := 3.0  # s

@export var type := Type.UNKNOWN
@export var move_speed := Vector2.RIGHT * 10.0
@export var projectile := Projectile.Type.NONE
@export var attack_range := 16.0  # px
@export var damage := 1
@export var aim_mode := AimMode.NORMAL

@onready var _speed := move_speed.length()
@onready var _blood_fx := %BloodFx as BloodFx
@onready var _body_sprite := %BodySprite as AnimatedSprite2D
@onready var _weapon_axis := %Axis as Node2D
@onready var _weapon_sprite := %WeaponAnimatedSprite2D as AnimatedSprite2D
@onready var _shield_sprite := %ShieldSprite2D as Sprite2D
@onready var _aim_sprite := %AimAnimatedSprite2D as AnimatedSprite2D
@onready var _pick_area := %PickArea2D as Area2D
@onready var _hit_area := %HitArea2D as Area2D
@onready var hit_anchor := %HitMarker2D as Node2D

var _state := State.RUNNING
var _attack_timer := 0.0
var target_castle : Castle
var follow_offset := Vector2.ZERO

func _ready() -> void:
	_shield_sprite.hide()
	_aim_sprite.hide()
	match aim_mode:
		AimMode.NORMAL:
			_aim_sprite.animation = &"aim"
		AimMode.NO_AIM:
			_aim_sprite.animation = &"no_aim"
		AimMode.AIM_ONLY:
			_aim_sprite.animation = &"aim_only"
		AimMode.NONE:
			_aim_sprite.animation = &"none"
			_pick_area.collision_layer = 0
	match type:
		Type.SIEGE:
			_weapon_sprite.hide()

func _process(_delta: float) -> void:
	_update_display()

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_attack_timer -= delta
	match _state:
		State.RUNNING:
			if target_castle != null:
				var direction := global_position.direction_to(target_castle._center + follow_offset)
				velocity = direction * _speed
				var d := target_castle.distance_to(global_position)
				var move_distance := maxf(d - attack_range, 0)
				var max_vel := move_distance / delta
				if _speed > max_vel:
					velocity = direction * max_vel
					_state = State.ATTACKING
			else:
				velocity = move_speed
			move_and_slide()
			
		State.ATTACKING:
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_attack_timer = ATTACK_COOLDOWN
				_attack()
				_state = State.RUNNING

var _tween_shield : Tween
func trigger_shield() -> void:
	if _tween_shield != null:
		_tween_shield.kill()
	_shield_sprite.show()
	SoundFxManagerSingleton.play(SoundFxManager.Type.EnemyShield)
	_tween_shield = create_tween()
	_tween_shield.tween_interval(1.0)
	_tween_shield.tween_callback(_shield_sprite.hide)

func kill(hit_angle: float, hit_strength: float = 1.0, animation_delay: float = 0.0) -> void:
	if _state != State.DEAD:
		_state = State.DEAD
		($CollisionShape2D as CollisionShape2D).disabled = true
		_pick_area.collision_layer = 0
		_hit_area.collision_layer = 0
		_weapon_sprite.hide()
		_shield_sprite.hide()
		var tween := create_tween()
		const duration := 0.4  # s
		var knock_back_distance := hit_strength * 5  # px
		var knock_back_motion := Vector2.from_angle(hit_angle) * knock_back_distance
		tween.tween_interval(animation_delay)
		tween.tween_callback(_body_sprite.play.bind(&"die"))
		tween.tween_callback(_blood_fx.start.bind(hit_angle, type != Type.SIEGE))
		tween.tween_property(self, "global_position", global_position + knock_back_motion, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.parallel().tween_property(_body_sprite, "modulate", Color(0.75, 0.75, 0.75, 0.7), duration) \
			.from(Color.RED).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(died.emit)
		tween.tween_interval(3.0)
		tween.tween_property(self, "modulate:a", 0.0, 2.0) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(queue_free)

func _attack() -> void:
	if target_castle == null:
		return
		
	if _body_sprite.sprite_frames.has_animation(&"attack"):
		_body_sprite.play(&"attack")
		_body_sprite.play(&"default")
	if projectile != Projectile.Type.NONE:
		var proj := ProjectilePackedScene.instantiate() as Projectile
		Config.root_2d.add_child(proj)
		proj.global_position = global_position
		proj.type = projectile
		proj.direction = target_castle.throw_direction(global_position)
		proj.damage = damage
		SoundFxManagerSingleton.play(SoundFxManager.Type.EnemyAttackThrow)
	else:
		_weapon_axis.rotation = PI / 2
		target_castle.take_hit(damage) 
		SoundFxManagerSingleton.play(SoundFxManager.Type.EnemyAttackSmall)
		await get_tree().create_timer(0.5).timeout
		_weapon_axis.rotation = 0

func is_alive() -> bool:
	return _state != State.DEAD

func set_aimed(t: bool) -> void:
	_aim_sprite.visible = t

func _update_display() -> void:
	#_body_sprite.flip_h = velocity.x < 0
	match _state:
		State.RUNNING:
			if not velocity.is_zero_approx():
				_body_sprite.scale.x = -1 if velocity.x < 0.0 else 1
		State.ATTACKING:
			if target_castle != null:
				var dx := target_castle.global_position.x - global_position.x
				if abs(dx) > 1:  # hysteresis
					_body_sprite.scale.x = signf(dx)

static func find_parent_enemy(node: Node2D) -> Enemy:
	return node.get_parent() as Enemy

static func find_closest_enemy(global_pos: Vector2, space_state: PhysicsDirectSpaceState2D) -> Enemy:
	var point := PhysicsPointQueryParameters2D.new()
	point.collide_with_bodies = false
	point.collide_with_areas = true
	point.position = global_pos
	point.collision_mask = Config.LAYER_ENEMY_PICK
	
	var intersections := space_state.intersect_point(point)
	
	var closest_enemy : Enemy = null
	var closest_dist := INF
	for c: Dictionary in intersections:
		var collider := c["collider"] as CollisionObject2D
		var enemy := Enemy.find_parent_enemy(collider)
		if enemy != null and enemy.is_alive():
			var d := global_pos.distance_to(collider.global_position)
			if enemy.aim_mode == AimMode.AIM_ONLY:
				d *= 0.7  # higher priority to aim only enemies (make them easier to target)
			if d < closest_dist:
				closest_dist = d
				closest_enemy = enemy
	return closest_enemy
	
