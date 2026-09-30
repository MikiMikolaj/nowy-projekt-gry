# GameCamera: follows the player with facing look-ahead, plus trauma-based screen shake (spec section 8).
class_name GameCamera
extends Camera2D

## Leave empty to follow the first node in the "player" group.
@export var target: Player

@export_group("Look-ahead")
## How far ahead of the player (in facing direction) the camera looks, in px.
@export var look_ahead_distance: float = 120.0
## Seconds to ease from centred to full look-ahead.
@export var look_ahead_time: float = 0.3

@export_group("Shake")
## Offset at trauma 1.0; actual shake is trauma² × this.
@export var max_shake_offset: Vector2 = Vector2(48.0, 36.0)
## Trauma lost per real second.
@export var trauma_decay: float = 1.5
## How fast the noise is sampled; higher = more jittery shake.
@export var shake_noise_speed: float = 25.0

var _trauma: float = 0.0
var _look_ahead_x: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0
var _last_ticks_usec: int = 0


func _ready() -> void:
	# Shake must keep animating during hitstop, when the tree's scaled time is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = randi()
	_noise.frequency = 1.0
	_last_ticks_usec = Time.get_ticks_usec()
	Events.camera_shake_requested.connect(add_trauma)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Player
	if target != null:
		global_position = target.global_position
		reset_smoothing()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var look_ahead_speed: float = look_ahead_distance / look_ahead_time
	_look_ahead_x = move_toward(_look_ahead_x, target.facing * look_ahead_distance, look_ahead_speed * delta)
	# Look-ahead goes into the followed position (not `offset`) so the level limits still clamp it.
	global_position = target.global_position + Vector2(_look_ahead_x, 0.0)


func _process(_delta: float) -> void:
	# Real time, not the scaled delta, so hitstop (time_scale 0) doesn't freeze the shake.
	var now_usec: int = Time.get_ticks_usec()
	var real_delta: float = float(now_usec - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = now_usec

	if _trauma > 0.0:
		_trauma = maxf(_trauma - trauma_decay * real_delta, 0.0)
		_noise_time += real_delta * shake_noise_speed
		var strength: float = _trauma * _trauma
		_shake_offset = Vector2(
			max_shake_offset.x * strength * _noise.get_noise_2d(_noise_time, 0.0),
			max_shake_offset.y * strength * _noise.get_noise_2d(0.0, _noise_time),
		)
		offset = _shake_offset
	elif _shake_offset != Vector2.ZERO:
		_shake_offset = Vector2.ZERO
		offset = Vector2.ZERO


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
