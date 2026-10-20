# SwingHitbox: the player's one crescent hitbox plus its slash trail. Both use the same polygon, so what you
# see is exactly what hits.
class_name SwingHitbox
extends Hitbox

var _trail_tween: Tween

@onready var _shape: CollisionPolygon2D = $Shape
@onready var _trail: Polygon2D = $Trail


func _ready() -> void:
	super()
	_trail.visible = false


# Reshapes hitbox and trail for this attack. Call while disabled (before the active phase).
# feet_y: the player's feet in this node's local space; the crescent is cut off flat there.
func set_arc(data: AttackData, stats: PlayerStats, feet_y: float) -> void:
	var points: PackedVector2Array = Crescent.build(data.reach, data.arc_height,
			data.swing_from_degrees, data.swing_to_degrees,
			stats.crescent_inner_ratio, stats.crescent_taper_degrees, feet_y)
	_shape.polygon = points
	_trail.polygon = points


func show_trail(alpha: float) -> void:
	_kill_trail_tween()
	_trail.modulate.a = alpha
	_trail.visible = true


func fade_trail(duration: float) -> void:
	if not _trail.visible:
		return
	_kill_trail_tween()
	_trail_tween = create_tween()
	_trail_tween.tween_property(_trail, ^"modulate:a", 0.0, duration)
	_trail_tween.tween_callback(_trail.hide)


func _kill_trail_tween() -> void:
	if _trail_tween != null:
		_trail_tween.kill()
