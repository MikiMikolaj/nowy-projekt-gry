# Player: CharacterBody2D with shared movement helpers and input timers. States decide *when*; this decides *how*.
class_name Player
extends CharacterBody2D

## Swap for another .tres to A/B test feel; defaults to the main tuning file.
@export var stats: PlayerStats = preload("res://entities/player/player_stats.tres")

## 1 = facing right, -1 = facing left.
var facing: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var _squash: Vector2 = Vector2.ONE
var _squash_tween: Tween

@onready var visual: Node2D = $Visual


# Runs before the StateMachine child's physics, so states always see fresh timers.
func _physics_process(delta: float) -> void:
	if is_on_floor():
		coyote_timer = stats.coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = stats.jump_buffer
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)


func _process(_delta: float) -> void:
	# Facing is a flip of the visual only; the collision box never changes.
	visual.scale = Vector2(_squash.x * facing, _squash.y)


# --- Input -------------------------------------------------------------------

# Digital -1/0/1: a stick past the deadzone gives full speed, like a d-pad (precision platformer feel).
func get_input_x() -> float:
	return signf(Input.get_axis(&"move_left", &"move_right"))


func update_facing() -> void:
	var input_x: float = get_input_x()
	if input_x != 0.0:
		facing = int(input_x)


# --- Physics helpers -----------------------------------------------------------

func apply_gravity(delta: float) -> void:
	var g: float = stats.gravity
	if not is_on_floor() and absf(velocity.y) < stats.apex_hang_threshold:
		# Brief float at the top of the arc for extra air control.
		g *= stats.apex_hang_multiplier
	elif velocity.y > 0.0:
		# Falling faster than rising gives the jump weight.
		g *= stats.fall_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, stats.max_fall_speed)


func apply_horizontal(delta: float, accel: float, decel: float) -> void:
	var input_x: float = get_input_x()
	if input_x == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		return
	var rate: float = accel
	var is_reversing: bool = velocity.x != 0.0 and signf(velocity.x) != input_x
	if is_reversing and is_on_floor():
		rate = stats.turn_accel
	velocity.x = move_toward(velocity.x, input_x * stats.max_run_speed, rate * delta)


# --- Jump ----------------------------------------------------------------------

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0.0


func has_buffered_jump() -> bool:
	return jump_buffer_timer > 0.0


func wants_jump() -> bool:
	return has_buffered_jump() and can_jump()


func jump() -> void:
	# The extra half-step of gravity cancels the height lost to per-frame integration (~12 px at 60 Hz),
	# so the real peak matches stats.jump_height.
	velocity.y = -(stats.jump_velocity + 0.5 * stats.gravity * get_physics_process_delta_time())
	# Consume both so one press can never produce two jumps.
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	squash(stats.jump_stretch)


func land() -> void:
	squash(stats.land_squash)


# --- Visual ----------------------------------------------------------------------

func squash(amount: Vector2) -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_squash = amount
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, ^"_squash", Vector2.ONE, stats.squash_return_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
