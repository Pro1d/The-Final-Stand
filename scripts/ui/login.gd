class_name LoginUI
extends Control

signal play_pressed()

@onready var _loading := (%Loading as Control)
@onready var _initialized := (%Initialized as Control)
@onready var _hyplay_button := (%HyplayButton as Button)
@onready var _guest_button := (%GuestButton as Button)
@onready var _logout_button := (%LogoutButton as Button)
@onready var _continue_button := (%ContinueButton as Button)

var guest_login_in_progress := false
var _has_tried_to_connect_but_failed := false

func _ready() -> void:
	play_pressed.connect(queue_free)
	_hyplay_button.pressed.connect(_on_hyplay_pressed)
	_guest_button.pressed.connect(_on_guest_pressed)
	_logout_button.pressed.connect(_on_logout_pressed)
	_continue_button.pressed.connect(play_pressed.emit)
	(%AnimationPlayer as AnimationPlayer).play(&"loading")
	
	Hyplay.initialise(Config.hyplay["app-id"] as String)
	_update_ui()
	if !Hyplay.is_initialised:
		await Hyplay.initialised
	_update_ui()

func _update_ui() -> void:
	_initialized.visible = Hyplay.is_initialised and not guest_login_in_progress
	_loading.visible = not Hyplay.is_initialised or guest_login_in_progress
	(%LoggedIn as Control).visible = Hyplay.is_logged_in && !Hyplay.initialisation_failed
	(%LoggedOut as Control).visible = !Hyplay.is_logged_in && !Hyplay.initialisation_failed

	if Hyplay.is_initialised:
		if Hyplay.initialisation_failed:
			play_pressed.emit() # make sure we can start the game if hyplay is down

	if Hyplay.is_logged_in:
		(%NameLabel as Label).text = "Logged in as:\n" + Hyplay.user_details.username

func _on_hyplay_pressed() -> void:
	if guest_login_in_progress:
		return
	Hyplay.real_login()

func _on_guest_pressed() -> void:
	if guest_login_in_progress:
		return
	guest_login_in_progress = true
	_update_ui()
	await Hyplay.guest_login()
	await Hyplay.get_user_details()
	guest_login_in_progress = false
	
	if !Hyplay.is_logged_in:
		if _has_tried_to_connect_but_failed:
			play_pressed.emit() # make sure we can start the game if login has failed twice already
		_has_tried_to_connect_but_failed = true
	else:
		_has_tried_to_connect_but_failed = false
	_update_ui()

func _on_logout_pressed() -> void:
	if guest_login_in_progress:
		return

	Hyplay.logout()
	_has_tried_to_connect_but_failed = false
	_update_ui()
