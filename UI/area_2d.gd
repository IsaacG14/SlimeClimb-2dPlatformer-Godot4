extends Area2D

@export var hud: CanvasLayer

func _on_body_entered(body: Node2D) -> void:
	# Check if the object entering is the player (we look for the total_breaks variable)
	if "total_breaks" in body and hud:
		hud.trigger_end_screen(body.total_breaks)
