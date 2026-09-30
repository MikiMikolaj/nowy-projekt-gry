# Block: greybox wall/floor piece. Origin is the top-left corner; set `size` in px (keep it a multiple of 64).
@tool
class_name Block
extends StaticBody2D

@export var size: Vector2 = Vector2(64.0, 64.0):
	set(value):
		size = value
		_apply()

@export var color: Color = Color(0.33, 0.35, 0.4):
	set(value):
		color = value
		_apply()


func _ready() -> void:
	_apply()


# Also runs from the setters in the editor, so resizing in the Inspector updates the block live.
func _apply() -> void:
	if not is_node_ready():
		return
	var collision: CollisionShape2D = $CollisionShape2D
	var rect: ColorRect = $ColorRect
	# The shape is local-to-scene, so every Block instance owns its own copy.
	(collision.shape as RectangleShape2D).size = size
	collision.position = size / 2.0
	rect.size = size
	rect.color = color
