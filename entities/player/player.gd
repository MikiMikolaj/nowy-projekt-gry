# Player: CharacterBody2D with shared movement helpers and input timers. States decide *when*; this decides *how*.
class_name Player
extends CharacterBody2D

## Swap for another .tres to A/B test feel; defaults to the main tuning file.
@export var stats: PlayerStats = preload("res://entities/player/player_stats.tres")

## 1 = facing right, -1 = facing left.
var facing: int = 1:
	set(value):
		facing = value
		# Flipped here (not in _process) so hitboxes face the right way the instant an attack starts.
		if attack_pivot != null:
			attack_pivot.scale.x = value
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

## -1 = wall on the left, 1 = wall on the right. Only meaningful while wall_coyote_timer > 0.
var last_wall_dir: int = 0
var wall_coyote_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0

var dash_charges: int = 0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
## Wired to the Hurtbox in Stage 4.
var is_invincible: bool = false

var attack_buffer_timer: float = 0.0
var air_attack_cooldown_timer: float = 0.0

@onready var visual: PlayerVisual = $Visual
@onready var attack_pivot: Node2D = $AttackPivot
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight


func _ready() -> void:
	refresh_dash()


# Runs before the StateMachine child's physics, so states always see fresh timers.
func _physics_process(delta: float) -> void:
	var wall_dir: int = get_wall_dir()
	# velocity.y check: on the frame a jump starts we are still "on floor" but must not regain coyote time.
	var grounded: bool = is_on_floor() and velocity.y >= 0.0

	coyote_timer = stats.coyote_time if grounded else maxf(coyote_timer - delta, 0.0)
	wall_jump_lock_timer = 0.0 if grounded else maxf(wall_jump_lock_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = stats.jump_buffer
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_pressed(&"attack"):
		attack_buffer_timer = stats.attack_buffer_time
	else:
		attack_buffer_timer = maxf(attack_buffer_timer - delta, 0.0)
	air_attack_cooldown_timer = maxf(air_attack_cooldown_timer - delta, 0.0)

	# Not during the push-off lock, or the wall we just left would allow a second jump in mid-air.
	if not is_on_floor() and wall_dir != 0 and wall_jump_lock_timer <= 0.0:
		wall_coyote_timer = stats.wall_coyote_time
		last_wall_dir = wall_dir
	else:
		wall_coyote_timer = maxf(wall_coyote_timer - delta, 0.0)

	# Not while dashing, or a dash that starts next to a wall would be free.
	if not is_dashing and (grounded or wall_dir != 0):
		refresh_dash()


# --- Input -------------------------------------------------------------------

# Digital -1/0/1: a stick past the deadzone gives full speed, like a d-pad (precision platformer feel).
func get_input_x() -> float:
	return signf(Input.get_axis(&"move_left", &"move_right"))


func update_facing() -> void:
	if wall_jump_lock_timer > 0.0:
		return
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
	# After a wall jump, input is ignored briefly so holding toward the wall can't cancel the push-off.
	if wall_jump_lock_timer > 0.0:
		return
	var input_x: float = get_input_x()
	if input_x == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		return
	var rate: float = accel
	var is_reversing: bool = velocity.x != 0.0 and signf(velocity.x) != input_x
	if is_reversing and is_on_floor():
		rate = stats.turn_accel
	elif not is_reversing and absf(velocity.x) > stats.max_run_speed:
		# Over top speed (dash-jump): bleed off gently instead of braking at full accel.
		rate = decel
	velocity.x = move_toward(velocity.x, input_x * stats.max_run_speed, rate * delta)


# --- Walls ---------------------------------------------------------------------

func get_wall_dir() -> int:
	# Forced update: raycasts otherwise only refresh once per physics tick, after this node runs.
	wall_check_left.force_raycast_update()
	wall_check_right.force_raycast_update()
	if wall_check_right.is_colliding():
		return 1
	if wall_check_left.is_colliding():
		return -1
	return 0


func should_wall_slide() -> bool:
	var wall_dir: int = get_wall_dir()
	return not is_on_floor() and velocity.y > 0.0 and wall_dir != 0 and int(get_input_x()) == wall_dir


# --- Jump ----------------------------------------------------------------------

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0.0


func can_wall_jump() -> bool:
	return not is_on_floor() and wall_coyote_timer > 0.0


func has_buffered_jump() -> bool:
	return jump_buffer_timer > 0.0


func wants_jump() -> bool:
	return has_buffered_jump() and (can_jump() or can_wall_jump())


# Called by the Jump state; a ground (or coyote) jump takes priority over a wall jump.
func start_jump() -> void:
	if can_jump():
		jump()
	else:
		wall_jump()


func jump() -> void:
	velocity.y = -(stats.jump_velocity + _jump_step_correction())
	_consume_jump()


func wall_jump() -> void:
	velocity.x = -last_wall_dir * stats.wall_jump_velocity_x
	velocity.y = -(stats.jump_velocity * stats.wall_jump_velocity_y_multiplier + _jump_step_correction())
	facing = -last_wall_dir
	wall_jump_lock_timer = stats.wall_jump_input_lock
	_consume_jump()


func land() -> void:
	visual.squash(stats.land_squash, stats.squash_return_time)


# Consume every jump allowance so one press can never produce two jumps.
func _consume_jump() -> void:
	coyote_timer = 0.0
	wall_coyote_timer = 0.0
	jump_buffer_timer = 0.0
	visual.squash(stats.jump_stretch, stats.squash_return_time)


# Half a step of gravity: cancels the height lost to per-frame integration (~12 px at 60 Hz),
# so the real peak matches stats.jump_height.
func _jump_step_correction() -> float:
	return 0.5 * stats.gravity * get_physics_process_delta_time()


# --- Dash ----------------------------------------------------------------------

# The one place dash charges come back. Later stages also call this on a landed hit and on a pogo.
func refresh_dash() -> void:
	dash_charges = stats.air_dash_charges


# Ground dashes are limited by the cooldown, air dashes by charges.
func can_dash() -> bool:
	if is_on_floor():
		return dash_cooldown_timer <= 0.0
	return dash_charges > 0


func wants_dash() -> bool:
	return Input.is_action_just_pressed(&"dash") and can_dash()


# --- Combat --------------------------------------------------------------------

# Air attacks have a cooldown; ground attacks are only limited by their own recovery.
func wants_attack() -> bool:
	return attack_buffer_timer > 0.0 and (is_on_floor() or air_attack_cooldown_timer <= 0.0)


# Bounce off whatever a down slash hit. Not a jump: releasing the jump button doesn't cut it.
func pogo() -> void:
	velocity.y = -(stats.jump_velocity * stats.pogo_velocity_multiplier + _jump_step_correction())
	refresh_dash()
