extends Control

@onready var main_menu_container: MarginContainer = $MarginContainer
# Level Buttons
@onready var level_1_button: Button = $MarginContainer/MainVBox/ButtonVBox/Level1Button
@onready var level_2_button: Button = $MarginContainer/MainVBox/ButtonVBox/Level2Button
@onready var level_3_button: Button = $MarginContainer/MainVBox/ButtonVBox/Level3Button
@onready var controls_button: Button = $MarginContainer/MainVBox/ButtonVBox/ControlsButton
@onready var exit_button: Button = $MarginContainer/MainVBox/ButtonVBox/ExitButton


# Controls Popup UI
@onready var controls_popup: PanelContainer = $ControlsPopup
@onready var close_controls_btn: Button = $ControlsPopup/VBoxContainer/CloseButton

func _ready() -> void:
	# --- NEW: Ensure music restores when returning from a victory screen ---
	var music_bus_index := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music_bus_index, Global.disable_music)
	
	# Hide the popup immediately when the menu loads
	controls_popup.hide()
	
	# Connect Level Buttons
	level_1_button.pressed.connect(_on_level_1_pressed)
	level_2_button.pressed.connect(_on_level_2_pressed)
	level_3_button.pressed.connect(_on_level_3_pressed)
	
	# Connect Controls Buttons
	controls_button.pressed.connect(open_controls)
	close_controls_btn.pressed.connect(close_controls)
	
	# --- CONNECT THE EXIT BUTTON HERE ---
	exit_button.pressed.connect(quit_game)
	
	# Highlight the first button for keyboard/controller users
	level_1_button.grab_focus()
	
	

# Quit Game
func quit_game() -> void:
	# This command safely shuts down the entire Godot application
	get_tree().quit()

# --- SCENE SWITCHING ---

func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level_1.tscn")

func _on_level_2_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level_2.tscn")

func _on_level_3_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level_3.tscn")

# --- CONTROLS POPUP LOGIC ---

func open_controls() -> void:
	# Hide the main menu buttons and title
	main_menu_container.hide() 
	controls_popup.show()
	close_controls_btn.grab_focus()

func close_controls() -> void:
	controls_popup.hide()
	# Show the main menu buttons and title again
	main_menu_container.show() 
	controls_button.grab_focus()
