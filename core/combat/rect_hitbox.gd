# RectHitbox: a Hitbox whose rectangular collision shape is built from `size`, so it can be resized in the
# Inspector without editing a shape resource.
class_name RectHitbox
extends Hitbox

## Width and height of the hitbox in px, centred on this node.
@export var size: Vector2 = Vector2(64.0, 64.0)


func _ready() -> void:
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)
	super()
