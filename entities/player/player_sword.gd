# PlayerSword: the placeholder big sword, pivoting at the shoulder. The Attack state drives it through
# wind-up, sweep and follow-through; otherwise it rests angled down and back.
class_name PlayerSword
extends Node2D

var _tween: Tween
# Where the current tween ends, unwrapped (may be outside -180..180) so a sweep keeps its direction.
var _target: float = 0.0


func _ready() -> void:
	rotation_degrees = (owner as Player).stats.sword_rest_degrees
	_target = rotation_degrees


## Pull back to `angle` the short way round.
func wind_up(angle: float, duration: float) -> void:
	_tween_to(rotation_degrees + wrapf(angle - rotation_degrees, -180.0, 180.0), duration,
			Tween.TRANS_SINE, Tween.EASE_OUT)


## Sweep by `arc` degrees from where the wind-up ends. Signed, so arcs over 180° go the intended way.
func sweep(arc: float, duration: float) -> void:
	# Fast start, soft stop: the blade is at full speed while the hitbox is on.
	_tween_to(_target + arc, duration, Tween.TRANS_QUART, Tween.EASE_OUT)


## Ease back to `angle` the short way round (follow-through, or settling after a cancel).
func settle(angle: float, duration: float) -> void:
	_tween_to(rotation_degrees + wrapf(angle - rotation_degrees, -180.0, 180.0), duration,
			Tween.TRANS_SINE, Tween.EASE_IN_OUT)


func _tween_to(target: float, duration: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	if _tween != null:
		_tween.kill()
	_target = target
	_tween = create_tween()
	_tween.tween_property(self, ^"rotation_degrees", target, duration).set_trans(trans).set_ease(easing)
