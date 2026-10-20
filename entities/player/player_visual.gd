# PlayerVisual: the placeholder body. Handles the facing flip, squash & stretch, the hurt flicker, colour
# flashes and the perfect-dodge glow; never touches collision.
class_name PlayerVisual
extends Node2D

var _squash: Vector2 = Vector2.ONE
var _squash_tween: Tween
var _flash_tween: Tween
var _base_color: Color
var _glow_alpha: float = 1.0

@onready var _player: Player = owner as Player
@onready var _body: ColorRect = $Body
@onready var _glow: ColorRect = $EmpowerGlow


func _ready() -> void:
	_base_color = _body.color
	_glow_alpha = _glow.color.a
	_glow.visible = false


func _process(_delta: float) -> void:
	scale = Vector2(_squash.x * _player.facing, _squash.y)
	modulate.a = 1.0
	# Both use real time, so the blink and the pulse keep going through hitstop.
	var now_ms: float = float(Time.get_ticks_msec())
	if _player.damage.is_flickering():
		var interval_ms: float = _player.stats.hurt_flicker_interval * 1000.0
		if int(now_ms / interval_ms) % 2 == 1:
			modulate.a = _player.stats.hurt_flicker_alpha
	_glow.visible = _player.perfect_dodge.is_empowered()
	if _glow.visible:
		var pulse: float = 0.5 + 0.5 * sin(now_ms / 1000.0 * _player.stats.perfect_dodge_glow_pulse_speed)
		_glow.color.a = _glow_alpha * lerpf(0.4, 1.0, pulse)


# Snaps to `amount`, then eases back to normal over `return_time` seconds.
func squash(amount: Vector2, return_time: float) -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_squash = amount
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, ^"_squash", Vector2.ONE, return_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Turns the body `color` for `duration` seconds.
func flash(color: Color, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_body.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_interval(duration)
	_flash_tween.tween_callback(func() -> void: _body.color = _base_color)
