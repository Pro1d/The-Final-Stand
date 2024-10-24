extends Node2D

const ArcherPackedScene := preload("res://scenes/enemies/archer.tscn")
const HorsemanPackedScene := preload("res://scenes/enemies/horseman.tscn")
const ManAtArmsPackedScene := preload("res://scenes/enemies/man_at_arms.tscn")
const SiegePackedScene := preload("res://scenes/enemies/siege.tscn")
const GiantPackedScene := preload("res://scenes/enemies/giant.tscn")

enum State { LOGIN, PLAYING, ENDING, SCORE_SCREEN, MENU }

@export var troops_collection: Array[PackedScene]

var _state := State.LOGIN

@onready var _hud := %HUD as HUD
@onready var _menu := %Menu as Menu
@onready var _login := %LoginUI as LoginUI
@onready var _score_screen := %ScoreScreen as ScoreScreen
@onready var _camera_anim := %Camera2D/AnimationPlayer as AnimationPlayer
@onready var _castle := %Castle as Castle
@onready var _player := Config.player_node
@onready var _troops_spawner := %TroopsSpawner as TroopsSpawner

var _stage := 0
var _stage_time := 0.0
const LEVELS : Array[Array] = [
	[TroopsSpawner.Level.EASY],
	[TroopsSpawner.Level.EASY, TroopsSpawner.Level.MEDIUM],
	[TroopsSpawner.Level.MEDIUM],
	[TroopsSpawner.Level.MEDIUM, TroopsSpawner.Level.HARD],
	[TroopsSpawner.Level.HARD],
	[TroopsSpawner.Level.HARD, TroopsSpawner.Level.MAX],
	[TroopsSpawner.Level.MAX],
	[TroopsSpawner.Level.BOSS],
]
const MAX_ENEMIES : Array[int] = [
	30, 30,
	35, 35,
	40, 40,
	45,
	50
]

const STAGE_DURATION := 30.0

var _score := 0
var _enemies : Array[Enemy] = []
var _boss : Boss

func _ready() -> void:
	SoundFxManagerSingleton.connect_all_buttons($UILayer)
	assert (MAX_ENEMIES.size() == LEVELS.size())
	_menu.hide()
	_hud.hide()
	_score_screen.hide()
	MusicManagerSingleton.start_music()
	if true:
		_login.show()
		_login.play_pressed.connect(_start_menu)
	else:
		_login.queue_free()
		_start_menu()
	
	_castle.destroyed.connect(_on_castle_destroyed)
	_player.enemy_killed.connect(_on_player_killed_enemies)
	_player.combo_level_changed.connect(_on_player_combo_level_changed)
	_menu.play_clicked.connect(func() -> void:
		if _state == State.MENU:
			_start_game())
	_menu.ranking_clicked.connect(func() -> void:
		if _state == State.MENU:
			_start_score_screen(true))
	_score_screen.menu_clicked.connect(func() -> void:
		if _state == State.SCORE_SCREEN:
			_start_menu())

func _start_game() -> void:
	_state = State.PLAYING
	_castle.reset()
	_player.reset((%PlayerStartMarker2D as Node2D).global_position)
	_score = 0
	_hud.update_score(_score)
	_stage = 0
	_stage_time = 0.0
	_enemies.clear()
	_menu.hide()
	_hud.show()
	MusicManagerSingleton.switch_to_battle_music()

func _start_menu() -> void:
	_state = State.MENU
	_clear_world(Config.root_2d)
	_enemies.clear()
	_menu.show()
	_hud.hide()
	_score_screen.hide()

func _start_ending(victory: bool) -> void:
	_state = State.ENDING
	_player.can_attack = false
	var anim := %LabelAnimationPlayer as AnimationPlayer
	anim.play("victory" if victory else "defeat")
	await anim.animation_finished
	MusicManagerSingleton.switch_to_menu_music()
	_start_score_screen(false)

func _start_score_screen(ld_only: bool) -> void:
	_state = State.SCORE_SCREEN
	_menu.hide()
	_hud.hide()
	_score_screen.show()
	_score_screen.set_score(-1 if ld_only else _score)
	_score_screen.update_leaderboard(not ld_only)

func _process(_delta: float) -> void:
	match _state:
		State.PLAYING:
			_hud.update_health(_castle.hit_points)

var _delay := 0.0
func _physics_process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	_stage_time += delta
	if _stage_time > STAGE_DURATION:
		_stage_time -= STAGE_DURATION
		_stage = mini(_stage + 1, LEVELS.size() - 1)
	_delay -= delta
	if _delay < 0:
		_delay += 0.5
		if _enemies.size() < MAX_ENEMIES[_stage]:
			var level := LEVELS[_stage]
			if level.has(TroopsSpawner.Level.BOSS) and _boss != null:
				level = [TroopsSpawner.Level.MAX] # spawn only one boss, then spawn normal troops
			var new_enemies := _troops_spawner.make_troops(level)
			for e in new_enemies:
				_enemies.append(e)
				e.died.connect(_enemies.erase.bind(e))
				if e is Boss:
					_boss = e
					e.died.connect(_on_boss_died.bind(e))

func _on_boss_died(boss: Boss) -> void:
	for e in _enemies:
		if e == boss: continue
		var angle := boss.global_position.angle_to_point(e.global_position)
		var distance := boss.global_position.distance_to(e.global_position)
		var delay := minf((distance / (16.0 * 10)) ** .5, 1.0) * 0.3
		e.kill(angle, 5.0, delay)
	_score += Config.BOSS_SCORE
	_hud.update_score(_score)
	_start_ending(true)

func _on_castle_destroyed() -> void:
	match _state:
		State.PLAYING:
			_hud.update_health(_castle.hit_points)
			_camera_anim.play("shaking")
			_start_ending(false)

var _prev_combo_name := Config.combo_level_name[0]
func _on_player_combo_level_changed() -> void:
	_hud.update_combo(_player.current_combo_level)
	match _state:
		State.PLAYING:
			_hud.update_combo(_player.current_combo_level)
			var combo_index := Config.to_combo_index(_player.current_combo_level)
			var level_name := Config.combo_level_name[combo_index]
			if level_name != _prev_combo_name:
				TextFx.create(
					level_name,
					"", #"*%d" % [Config.combo_level_factor[combo_index]],
					Config.get_combo_color(_player.current_combo_level),
					_player.global_position + Vector2(0, 8)
				)
				_prev_combo_name = level_name

func _on_player_killed_enemies(
	kills: int, spear_path_length: float,
	enemies_center: Vector2, target_pos: Vector2) -> void:
	
	match _state:
		State.PLAYING:
			var kill_factor := [1,3,6][clampi(kills / 3, 0, 2)] as int # 0.x1 3.x3 6.x6
			var distance := floori(spear_path_length / 16)
			var distance_factor := 1 << clampi(distance / 4, 0, 2) # 0. x1 .4. x2 .8. x4
			var combo_index := Config.to_combo_index(_player.current_combo_level)
			var combo_factor := Config.combo_level_factor[combo_index]
			_score += kills * kill_factor * distance_factor * combo_factor
			_hud.update_score(_score)
			if kill_factor > 1:
				TextFx.create(
					"bloodshed" if kill_factor == 4 else "slaughter",
					"*%d" % [kill_factor],
					Color(0.951, 0.74, 0.454).lerp(
						Color(0.8, 0.173, 0.128), clampf(kills / 9., 0, 1)),
					enemies_center + Vector2(0, -12)
				)
			if distance_factor > 1:
				TextFx.create(
					"sniper" if distance_factor == 4 else "distant",
					"*%d" % [distance_factor],
					Color(0.501, 0.537, 0.954).lerp(
						Color(0.717, 0.059, 0.74), clampf(distance / 12., 0, 1)),
					target_pos + Vector2(0, -16)
				)
			TextFx.create(
				"kill",
				"+%d" % [kills],
				Color(0.974, 0.848, 0.435).lerp(
						Color(0.869, 0.57, 0), clampf(kills / 12., 0, 1)),
				_player.global_position + Vector2(0, -20)
			)

func _clear_world(node: Node) -> void:
	if node.is_in_group(&"game_unique"):
		node.queue_free()
	else:
		for c in node.get_children():
			_clear_world(c)
