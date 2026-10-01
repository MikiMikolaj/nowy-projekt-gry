# PlayerVisual: the placeholder body. Handles the facing flip and squash & stretch; never touches collision.
class_name PlayerVisual
extends Node2D

var _squash: Vector2 = Vector2.ONE
var _squash_tween: Tween

@onready var _player: Player = owner as Player


func _process(_delta: float) -> void:
	scale = Vector2(_squash.x * _player.facing, _squash.y)


# Snaps to `amount`, then eases back to normal over `return_time` seconds.
func squash(amount: Vector2, return_time: float) -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_squash = amount
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, ^"_squash", Vector2.ONE, return_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
