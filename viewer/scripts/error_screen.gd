## Full-screen, readable error display shown whenever a bundle fails to load — used so a load
## failure never presents as a black canvas.
class_name ErrorScreen
extends Control


func _ready() -> void:
	visible = false


## Shows the error screen with `message` as the primary text.
func show_error(message: String) -> void:
	$Message.text = message
	visible = true
