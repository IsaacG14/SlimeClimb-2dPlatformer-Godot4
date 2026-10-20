extends CanvasLayer

@export var level_title: String = "Level Title"
@export var level_description: String = "Press SPACE to Play"
@onready var sfx_victory: AudioStreamPlayer = $VictorySound

# Add references to the text labels inside your StartPopup
@onready var level_text_label: Label = $StartPopup/VBoxContainer/LevelText
@onready var prompt_text_label: Label = $StartPopup/VBoxContainer/PromptText

@onready var start_popup: PanelContainer = $StartPopup
@onready var end_popup: PanelContainer = $EndPopup
@onready var in_game_hud: MarginContainer = $InGameHUD
@onready var time_label: Label = $InGameHUD/HBoxContainer/TimeLabel
@onready var jump_label: Label = $InGameHUD/HBoxContainer/JumpLabel
@onready var stats_text: Label = $EndPopup/VBoxContainer/StatsText

# Pause UI
@onready var pause_popup: PanelContainer = $PausePopup
@onready var resume_btn: Button = $PausePopup/VBoxContainer/ResumeButton
@onready var settings_btn: Button = $PausePopup/VBoxContainer/SettingsButton
@onready var restart_btn: Button = $PausePopup/VBoxContainer/RestartButton
@onready var main_menu_btn: Button = $PausePopup/VBoxContainer/MainMenuButton

# Settings UI
@onready var settings_popup: PanelContainer = $SettingsPopup
@onready var hide_hud_checkbox: CheckBox = $SettingsPopup/VBoxContainer/HideHudCheckbox
@onready var hide_music_checkbox: CheckBox = $SettingsPopup/VBoxContainer/HideMusicCheckbox
@onready var settings_back_btn: Button = $SettingsPopup/VBoxContainer/BackButton

var time_elapsed: float = 0.0
var timer_active: bool = false
var total_jumps: int = 0

func _ready() -> void:
	
	# Set the text to whatever you typed in the Inspector
	level_text_label.text = level_title
	prompt_text_label.text = level_description
	
	pause_popup.hide()
	end_popup.hide()
	settings_popup.hide()
	
	# Connect Pause Buttons
	resume_btn.pressed.connect(resume_game)
	restart_btn.pressed.connect(standard_restart)
	main_menu_btn.pressed.connect(go_to_main_menu)
	
	# Connect Settings Buttons
	settings_btn.pressed.connect(open_settings)
	settings_back_btn.pressed.connect(close_settings)
	hide_hud_checkbox.toggled.connect(_on_hud_checkbox_toggled)
	hide_music_checkbox.toggled.connect(_on_music_checkbox_toggled)

	# Sync the checkbox visually with our Global setting when the scene loads
	hide_hud_checkbox.button_pressed = Global.disable_hud
	hide_music_checkbox.button_pressed = Global.disable_music
	
	# Force the music bus to update immediately when the scene loads
	apply_music_setting()

	if Global.skip_start:
		start_popup.hide()
		refresh_hud_visibility() # Uses our new check instead of blindly showing
		get_tree().paused = false
		timer_active = true
		Global.skip_start = false 
	else:
		get_tree().paused = true
		start_popup.show()
		in_game_hud.hide()

func _process(delta: float) -> void:
	# 1. Start Prompt
	if start_popup.visible and Input.is_action_just_pressed("ui_accept"):
		start_popup.hide()
		refresh_hud_visibility() # Uses our new check
		get_tree().paused = false
		timer_active = true
		
	if end_popup.visible and Input.is_action_just_pressed("ui_accept"):
		go_to_main_menu()
		
	# 2. Pause Toggle (Block pause if Settings menu is open)
	if Input.is_action_just_pressed("ui_cancel") and not start_popup.visible and not end_popup.visible and not settings_popup.visible:
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

	# 3. Quick Restart
	if Input.is_action_just_pressed("quick_restart"):
		do_quick_restart()
		
	# 4. Timer Logic
	if timer_active:
		time_elapsed += delta
		update_timer_display()

# --- HUD VISIBILITY LOGIC ---

func refresh_hud_visibility() -> void:
	if Global.disable_hud:
		in_game_hud.hide()
	else:
		in_game_hud.show()

func _on_hud_checkbox_toggled(toggled_on: bool) -> void:
	Global.disable_hud = toggled_on
	refresh_hud_visibility()

# --- PAUSE & SETTINGS MENU LOGIC ---

func open_settings() -> void:
	pause_popup.hide()
	settings_popup.show()
	hide_hud_checkbox.grab_focus() # Good for keyboard navigation

func close_settings() -> void:
	settings_popup.hide()
	pause_popup.show()
	settings_btn.grab_focus()

func pause_game() -> void:
	get_tree().paused = true
	pause_popup.show()
	timer_active = false
	resume_btn.grab_focus() 

func resume_game() -> void:
	pause_popup.hide()
	get_tree().paused = false
	timer_active = true

# --- EXISTING FUNCTIONS ---

func update_timer_display() -> void:
	var minutes := int(time_elapsed / 60.0)
	var seconds := int(fmod(time_elapsed, 60.0))
	var milliseconds := int(fmod(time_elapsed, 1.0) * 100)
	time_label.text = "Time: %02d:%02d:%02d" % [minutes, seconds, milliseconds]

func add_jump() -> void:
	total_jumps += 1
	jump_label.text = "Jumps: " + str(total_jumps)

func trigger_end_screen(total_breaks: int) -> void:
	timer_active = false
	get_tree().paused = true
	in_game_hud.hide()
	
	# --- NEW: Mute the Music bus regardless of player settings ---
	var music_bus_index := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music_bus_index, true)
	
	# PLAY THE VICTORY JINGLE!
	sfx_victory.play()
	end_popup.show()
	var final_time := time_label.text
	stats_text.text = "%s\nTotal Jumps: %d\nLongfalls (Breaks): %d" % [final_time, total_jumps, total_breaks]

func standard_restart() -> void:
	get_tree().paused = false
	Global.skip_start = false 
	get_tree().reload_current_scene()

func do_quick_restart() -> void:
	get_tree().paused = false
	Global.skip_start = true 
	get_tree().reload_current_scene()

func go_to_main_menu() -> void:
	get_tree().paused = false
	Global.skip_start = false
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")
	
	# --- MUSIC LOGIC ---

func _on_music_checkbox_toggled(toggled_on: bool) -> void:
	Global.disable_music = toggled_on
	apply_music_setting()

func apply_music_setting() -> void:
	# Find the internal ID for our "Music" bus
	var music_bus_index := AudioServer.get_bus_index("Music")
	# Mute or unmute the bus based on our Global variable
	AudioServer.set_bus_mute(music_bus_index, Global.disable_music)
