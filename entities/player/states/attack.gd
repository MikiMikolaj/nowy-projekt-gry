# Attack: one state for every sword swing. Picks an AttackData, then runs wind-up (startup) → sweep (active)
# → follow-through (recovery) from its timings, driving the sword, the crescent hitbox and the trail.
extends PlayerState

enum Phase { STARTUP, ACTIVE, RECOVERY }

@export var combo_attacks: Array[AttackData] = [
	preload("res://entities/player/attacks/combo_1.tres"),
	preload("res://entities/player/attacks/combo_2.tres"),
	preload("res://entities/player/attacks/combo_3.tres"),
]
@export var air_side_attack: AttackData = preload("res://entities/player/attacks/air_side.tres")

var _data: AttackData
var _phase: Phase = Phase.STARTUP
var _phase_time: float = 0.0
# Index of the next ground combo hit, and the countdown until it falls back to hit 1.
var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _is_ground_attack: bool = false
var _lunge_remaining: float = 0.0
var _next_queued: bool = false
var _dash_queued: bool = false
var _has_recoiled: bool = false

var _hitbox: SwingHitbox
var _sword: PlayerSword
# The player's feet relative to the swing hitbox: the crescent covers down to here, never into the floor.
var _feet_y: float = 0.0


func _ready() -> void:
	super()
	# Looked up here, not with @onready: `player` is only set by super() above.
	_hitbox = player.get_node(^"AttackPivot/SwingHitbox") as SwingHitbox
	_sword = player.get_node(^"AttackPivot/Sword") as PlayerSword
	var body: RectangleShape2D = (player.get_node(^"CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_feet_y = body.size.y * 0.5 - _hitbox.position.y
	_hitbox.hit_landed.connect(_on_hit_landed)


# Runs even when another state is active: the combo memory must expire while the player runs around.
func _physics_process(delta: float) -> void:
	if state_machine.current_state == self or _combo_reset_timer <= 0.0:
		return
	_combo_reset_timer -= delta
	if _combo_reset_timer <= 0.0:
		_combo_step = 0


func enter() -> void:
	_start_attack()


func exit() -> void:
	_hitbox.disable()
	_hitbox.fade_trail(player.stats.trail_fade_time)
	# A cancel can leave the sword mid-swing; a finished swing is already at rest, so this is a no-op then.
	_sword.settle(player.stats.sword_rest_degrees, player.stats.sword_settle_time)
	_combo_reset_timer = player.stats.combo_reset_time


func physics_update(delta: float) -> void:
	# Spec 4.2: only a press during active or recovery is buffered into the next hit.
	if _phase == Phase.STARTUP:
		player.attack_buffer_timer = 0.0
	elif player.attack_buffer_timer > 0.0:
		_next_queued = true
		player.attack_buffer_timer = 0.0
	if Input.is_action_just_pressed(&"dash"):
		_dash_queued = true

	# Escape hatch: dash and jump cancel recovery (never startup or active).
	if _phase == Phase.RECOVERY:
		if _dash_queued and player.can_dash():
			state_machine.transition_to(&"Dash")
			return
		if player.wants_jump():
			state_machine.transition_to(&"Jump")
			return

	_move(delta)

	_phase_time += delta
	match _phase:
		Phase.STARTUP:
			if _phase_time >= _data.startup:
				_set_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			if _phase_time >= _data.active:
				_set_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			if _phase_time >= _data.recovery:
				_finish()


func _start_attack() -> void:
	player.attack_buffer_timer = 0.0
	_next_queued = false
	_dash_queued = false
	_has_recoiled = false
	# Facing may change between hits, but is locked for the duration of one.
	player.update_facing()
	_is_ground_attack = player.is_on_floor()
	_data = _choose_attack()
	_lunge_remaining = _data.lunge if _is_ground_attack else 0.0
	if not _is_ground_attack:
		player.air_attack_cooldown_timer = player.stats.air_attack_cooldown
	_hitbox.attack_data = _data
	_hitbox.set_arc(_data, player.stats, _feet_y)
	_set_phase(Phase.STARTUP)


# Spec 4.1 table: on the ground every direction is a combo hit (the wide arc already covers overhead);
# in the air, up or neutral is the side slash and down is the slam.
func _choose_attack() -> AttackData:
	if not _is_ground_attack:
		_combo_step = 0
		var aim_y: float = Input.get_axis(&"move_up", &"move_down")
		if aim_y > player.stats.attack_aim_threshold:
			# ┌─ SLAM HOOK ──────────────────────────────────────────────────────────────────────┐
			# │ Down + attack in the air is the ground slam (spec 4.3b), built in the next step. │
			# │ It will be its own state: Fall/Jump/etc. route here, and this becomes            │
			# │     state_machine.transition_to(&"Slam")                                         │
			# │ Until then it falls through to the air side slash so the button still does       │
			# │ something.                                                                       │
			# └──────────────────────────────────────────────────────────────────────────────────┘
			pass
		return air_side_attack
	var data: AttackData = combo_attacks[_combo_step]
	_combo_step = (_combo_step + 1) % combo_attacks.size()
	return data


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	match phase:
		Phase.STARTUP:
			_sword.wind_up(_data.windup_angle(), _data.startup)
		Phase.ACTIVE:
			_hitbox.enable()
			_hitbox.show_trail(player.stats.trail_alpha)
			_sword.sweep(_data.swing_to_degrees - _data.windup_angle(), _data.active)
		Phase.RECOVERY:
			_hitbox.disable()
			_hitbox.fade_trail(player.stats.trail_fade_time)
			_sword.settle(player.stats.sword_rest_degrees, _data.recovery)


func _move(delta: float) -> void:
	# Hitstop: physics still ticks, but with a zero time step. Nothing to simulate (and no dividing by it).
	if delta <= 0.0:
		return
	var was_on_floor: bool = player.is_on_floor()
	player.apply_gravity(delta)
	if not _is_ground_attack:
		# Air attacks never stop momentum: normal air control.
		player.apply_horizontal(delta, player.stats.air_accel, player.stats.air_decel)
	elif _has_recoiled:
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.stats.ground_decel * delta)
	elif _lunge_remaining > 0.0 and _phase != Phase.RECOVERY:
		# Spread the lunge over startup + active, and stop exactly at the lunge distance.
		var lunge_speed: float = _data.lunge / (_data.startup + _data.active)
		var step: float = minf(lunge_speed * delta, _lunge_remaining)
		_lunge_remaining -= step
		player.velocity.x = player.facing * step / delta
	else:
		# Committed: no walking during a ground attack.
		player.velocity.x = 0.0
	player.move_and_slide()
	if not was_on_floor and player.is_on_floor():
		player.land()


func _finish() -> void:
	if _next_queued:
		if player.is_on_floor() or player.air_attack_cooldown_timer <= 0.0:
			_start_attack()
			return
		# Air cooldown not over yet: hand the press back to the buffer so Fall fires it in a moment.
		player.attack_buffer_timer = player.stats.attack_buffer_time
	if not player.is_on_floor():
		state_machine.transition_to(&"Fall")
	elif player.get_input_x() != 0.0:
		state_machine.transition_to(&"Run")
	else:
		state_machine.transition_to(&"Idle")


func _on_hit_landed(hurtbox: Hurtbox) -> void:
	# Spec 3.4 / 4.5.1: any attack that connects gives the dash back.
	player.refresh_dash()
	GameFeel.hitstop(_data.hitstop)
	Events.camera_shake_requested.emit(_data.shake)
	# Sparks fly along the blade's path: forward, and down or up depending on the sweep.
	var spark_direction: Vector2 = Vector2(player.facing, 0.6 * _data.sweep_sign()).normalized()
	HitSpark.spawn(player.get_parent() as Node2D, hurtbox.global_position, spark_direction)
	if not _has_recoiled:
		_has_recoiled = true
		player.velocity.x = -player.facing * player.stats.side_hit_recoil
