extends AnimatableBody2D

# Export variables so you can change these in the editor for every platform!
@export var move_distance: float = 100.0
@export var speed: float = 2.0
@export var horizontal: bool = true # If false, it will move up and down instead

var start_position: Vector2
var time_passed: float = 0.0

func _ready() -> void:
	# Remember exactly where we placed it in the level
	start_position = global_position

func _physics_process(delta: float) -> void:
	time_passed += delta
	# sin() loops perfectly from -1 to 1 based on the time
	var offset = sin(time_passed * speed) * move_distance
	if horizontal:
		global_position.x = start_position.x + offset
	else:
		global_position.y = start_position.y + offset
