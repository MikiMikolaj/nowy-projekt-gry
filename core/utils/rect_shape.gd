# RectShape: a CollisionShape2D that builds its own rectangle from `size`, so shapes can be set and resized
# from the Inspector (and through the MCP) without creating a shape resource by hand.
@tool
class_name RectShape
extends CollisionShape2D

## Width and height in px, centred on this node.
@export var size: Vector2 = Vector2(64.0, 64.0):
	set(value):
		size = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	# A fresh resource per node: shapes must never be shared between instances that resize independently.
	var rect: RectangleShape2D = shape as RectangleShape2D
	if rect == null or not rect.resource_local_to_scene:
		rect = RectangleShape2D.new()
		rect.resource_local_to_scene = true
		shape = rect
	rect.size = size
