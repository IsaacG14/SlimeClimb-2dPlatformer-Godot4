extends CharacterBody2D

# Added LANDING and REBUILDING states to pause input while animations play
enum State { IDLE, COMPRESSING, AIRBORNE, LANDING, REBUILDING }
var current_state: int = State.IDLE

@export var hud: CanvasLayer # We will drag the HUD node into this in the editor
var total_breaks: int = 0

var jump_charge_power: float = 0.0
var fall_time: float = 0.0 

var was_on_wall: bool = false
var is_long_fall: bool = false

const MAX_SAFE_FALL_TIME: float = 0.95 # Tweak this to adjust when the break animation triggers
const BOUNCE_FACTOR: float = 0.71 # Adjust this to change how bouncy the walls are
const MAX_CHARGE: float = 1130.0
const CHARGE_RATE: float = 1495.0
const GRAVITY: float = 1550.0
const MOVE_SPEED: float = 310.0 
const HORIZONTAL_MULTIPLIER: float = 0.485 # Lower this number to jump less horizontally, raise it to jump further

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
# --- SFX REFERENCES ---
@onready var sfx_move: AudioStreamPlayer = $SFX/MoveSound
@onready var sfx_charge: AudioStreamPlayer = $SFX/ChargeSound
@onready var sfx_bounce: AudioStreamPlayer = $SFX/BounceSound
@onready var sfx_land: AudioStreamPlayer = $SFX/LandSound
@onready var sfx_break: AudioStreamPlayer = $SFX/BreakSound
@onready var sfx_build: AudioStreamPlayer = $SFX/BuildSound

# --- VISUAL EFFECTS ---
@onready var charge_particles: GPUParticles2D = $ChargeParticles

func _ready() -> void:
	anim_sprite.animation_finished.connect(_on_animation_finished)
	# This prevents the camera from continuously following the player frame-by-frame
	camera.set_as_top_level(true)
	anim_sprite.frame_changed.connect(_on_frame_changed)
	# FORCE the camera to snap to the correct room on frame 1, before the game pauses!
	update_camera()

func _process(_delta: float) -> void:
	# We update the camera in _process so it renders the cut cleanly
	update_camera()

func update_camera() -> void:
	var screen_size := get_viewport_rect().size
	# We ONLY calculate the vertical room now
	var room_y := floori(global_position.y / screen_size.y)
	# Lock the X position to the exact center of your wide screen, 
	# and snap the Y position to the current vertical room.
	camera.global_position = Vector2(
		screen_size.x / 2.0,
		(room_y * screen_size.y) + (screen_size.y / 2.0)
	)
func _physics_process(delta: float) -> void:
	
	var pre_move_velocity_x := velocity.x
	match current_state:
		State.IDLE:
			handle_idle()
		State.COMPRESSING:
			handle_compressing(delta)
		State.AIRBORNE:
			handle_airborne(delta)
		State.LANDING:
			# Apply gravity just in case, but prevent horizontal movement
			velocity.x = 0
			velocity.y += GRAVITY * delta
		State.REBUILDING:
			# Same here, lock movement while breaking/building
			velocity.x = 0
			velocity.y += GRAVITY * delta
	
	move_and_slide()
	
	# 3. Check if we hit a wall while in the air
	if current_state == State.AIRBORNE and is_on_wall():
		# get_wall_normal().x returns -1 if we hit a right wall, and 1 if we hit a left wall
		var wall_normal := get_wall_normal()
		# Multiply the normal by our raw incoming speed to safely launch us AWAY from the wall
		velocity.x = wall_normal.x * abs(pre_move_velocity_x) * BOUNCE_FACTOR
		# Update the sprite immediately so it faces the new bounce direction
		if velocity.x != 0:
			anim_sprite.flip_h = velocity.x < 0

func handle_idle() -> void:
	var input_dir := Input.get_axis("left", "right")
	
	# Deadzone fix
	if abs(input_dir) < 0.1:
		input_dir = 0.0
		
	velocity.x = input_dir * MOVE_SPEED
	
	if input_dir != 0:
		anim_sprite.play("move")
		anim_sprite.flip_h = input_dir < 0
	else:
		anim_sprite.play("idle")
		
	if not is_on_floor():
		fall_time = 0.0 
		is_long_fall = false
		current_state = State.AIRBORNE
		return
	if velocity.x != 0:
		anim_sprite.play("move")
		anim_sprite.flip_h = velocity.x < 0
		# Play the sound if it isn't already playing

	
	if Input.is_action_pressed("jump"):
		velocity.x = 0 
		current_state = State.COMPRESSING
		jump_charge_power = 0.0

func handle_compressing(delta: float) -> void:
	# Play the charge wind-up sound
	if not sfx_charge.playing:
		sfx_charge.play()
		# Turn on particles if they aren't already on
	if not charge_particles.emitting:
		charge_particles.emitting = true
		
	# Only call play if it isn't already the active animation
	if anim_sprite.animation != "chargejump":
		anim_sprite.play("chargejump")

	jump_charge_power += CHARGE_RATE * delta
	jump_charge_power = min(jump_charge_power, MAX_CHARGE)
	
	var input_dir := Input.get_axis("left", "right")
	
	if abs(input_dir) < 0.1:
		input_dir = 0.0
		
	if input_dir != 0:
		anim_sprite.flip_h = input_dir < 0
		
	if Input.is_action_just_released("jump"):
		sfx_charge.stop() # Cut the charge sound!
		charge_particles.emitting = false
		fall_time = 0.0 
		is_long_fall = false
		if hud:
			hud.add_jump()
		velocity.y = -jump_charge_power
		
		# Replace the hardcoded 0.6 with your new constant
		velocity.x = (jump_charge_power * HORIZONTAL_MULTIPLIER) * input_dir
		current_state = State.AIRBORNE

func handle_airborne(delta: float) -> void:
	velocity.y += GRAVITY * delta
	anim_sprite.play("jumping")
	sfx_move.stop()
	if velocity.y > 0: # The slime is moving downwards
		fall_time += delta
		
		
		# If we fall longer than our safe limit, flag it as a break
		if fall_time > MAX_SAFE_FALL_TIME:
			is_long_fall = true
			
	if velocity.x != 0:
		anim_sprite.flip_h = velocity.x < 0
	# --- NEW: WALL BOUNCE SOUND ---
	if is_on_wall() and not was_on_wall:
		# Add random pitch variation so repetitive wall kicks don't sound annoying
		sfx_bounce.pitch_scale = randf_range(0.9, 1.1)
		sfx_bounce.play()
		# (Your existing BOUNCE_FACTOR velocity reversal math should be here)
	was_on_wall = is_on_wall()
	if is_on_floor():
		velocity.x = 0
		was_on_wall = false
		if is_long_fall:
			current_state = State.REBUILDING
			anim_sprite.play("break")
			sfx_break.play() # PLAY SPLAT!
			total_breaks += 1 # Track the break punishment
		else:
			current_state = State.LANDING
			anim_sprite.play("land")
			sfx_land.play() # PLAY NORMAL LANDING

func _on_animation_finished() -> void:
	if current_state == State.LANDING and anim_sprite.animation == "land":
		current_state = State.IDLE
	elif current_state == State.REBUILDING:
		if anim_sprite.animation == "break":
			# Safely queues the next animation to prevent the 1-frame glitch
			anim_sprite.call_deferred("play", "build")
			sfx_build.play() # PLAY REFORMING SOUND
		elif anim_sprite.animation == "build":
			current_state = State.IDLE

func _on_frame_changed() -> void:
	# Only trigger if we are actively playing the move animation
	if anim_sprite.animation == "move":
		
		# Trigger the sound on frame 1 (and frame 3 if it's a longer animation)
		# Change these numbers to match the frames where your slime touches the ground!
		if anim_sprite.frame == 1 or anim_sprite.frame == 3:
			# Using pitch_scale adds a tiny bit of random pitch so the footsteps don't sound repetitive
			sfx_move.pitch_scale = randf_range(0.9, 1.1) 
			sfx_move.play()
