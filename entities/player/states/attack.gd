# Attack: one state for every attack. Picks an AttackData, then runs startup → active → recovery from its timings.
extends PlayerState

enum Phase { STARTUP, ACTIVE, RECOVERY }

@export var combo_attacks: Array[AttackData] = [
	preload("res://entities/player/attacks/combo_1.tres"),
	preload("res://entities/player/attacks/combo_2.tres"),
	preload("res://entities/player/attacks/combo_3.tres"),
]
@export var air_side_attack: AttackData = preload("res://entities/player/attacks/air_side.tres")
@export var up_attack: AttackData = preload("res://entities/player/attacks/up.tres")
@export var down_attack: AttackData = preload("res://entities/player/attacks/down.tres")

var _data: AttackData
var _hitbox: Hitbox
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
var _has_pogoed: bool = false
var _hitboxes: Dictionary[AttackData.Direction, Hitbox] = {}


func _ready() -> void:
	super()
	_hitboxes[AttackData.Direction.FORWARD] = player.get_node(^"AttackPivot/HitboxSide")
	_hitboxes[AttackData.Direction.UP] = player.get_node(^"AttackPivot/HitboxUp")
	_hitboxes[AttackData.Direction.DOWN] = player.get_node(^"AttackPivot/HitboxDown")
	for hitbox: Hitbox in _hitboxes.values():
		hitbox.hit_landed.connect(_on_hit_landed)
		hitbox.hazard_hit.connect(_on_hazard_hit)
		_set_slash_visible(hitbox, false)


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
	_set_slash_visible(_hitbox, false)
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
	_has_pogoed = false
	# Facing may change between hits, but is locked for the duration of one.
	player.update_facing()
	_is_ground_attack = player.is_on_floor()
	_data = _choose_attack()
	_lunge_remaining = _data.lunge if _is_ground_attack else 0.0
	if not _is_ground_attack:
		player.air_attack_cooldown_timer = player.stats.air_attack_cooldown
	_hitbox = _hitboxes[_data.direction]
	_hitbox.attack_data = _data
	_set_phase(Phase.STARTUP)


# Spec 4.1 table. Anything that isn't a ground combo hit also restarts the combo.
func _choose_attack() -> AttackData:
	var aim_y: float = Input.get_axis(&"move_up", &"move_down")
	var threshold: float = player.stats.attack_aim_threshold
	if aim_y < -threshold:
		_combo_step = 0
		return up_attack
	if not _is_ground_attack:
		_combo_step = 0
		return down_attack if aim_y > threshold else air_side_attack
	var data: AttackData = combo_attacks[_combo_step]
	_combo_step = (_combo_step + 1) % combo_attacks.size()
	return data


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	if phase == Phase.ACTIVE:
		_hitbox.enable()
		_set_slash_visible(_hitbox, true)
	elif phase == Phase.RECOVERY:
		_hitbox.disable()
		_set_slash_visible(_hitbox, false)


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


# --- Hit reactions ---------------------------------------------------------------

func _on_hit_landed(_hurtbox: Hurtbox) -> void:
	# Spec 4.5.1: any attack that connects gives the dash back.
	player.refresh_dash()
	_react_to_hit()


func _on_hazard_hit(_hazard: Hitbox) -> void:
	# Hazards (spikes, enemy contact hitboxes) can't be damaged; they only matter as something to pogo off.
	if _data.direction == AttackData.Direction.DOWN:
		_react_to_hit()


func _react_to_hit() -> void:
	GameFeel.hitstop(_data.hitstop)
	Events.camera_shake_requested.emit(_data.shake)
	HitSpark.spawn(player.get_parent() as Node2D, _hitbox.global_position, _attack_vector())
	match _data.direction:
		AttackData.Direction.FORWARD:
			if not _has_recoiled:
				_has_recoiled = true
				player.velocity.x = -player.facing * player.stats.side_hit_recoil
		AttackData.Direction.DOWN:
			if not _has_pogoed:
				_has_pogoed = true
				player.pogo()


func _attack_vector() -> Vector2:
	match _data.direction:
		AttackData.Direction.UP:
			return Vector2.UP
		AttackData.Direction.DOWN:
			return Vector2.DOWN
	return Vector2(player.facing, 0.0)


func _set_slash_visible(hitbox: Hitbox, is_visible: bool) -> void:
	(hitbox.get_node(^"Slash") as CanvasItem).visible = is_visible
