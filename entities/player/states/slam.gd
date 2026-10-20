# Slam: the ground slam (spec 4.3b). Freeze in the air with the sword raised, plunge straight down hitting
# anything below, then a two-way shockwave on landing and a committed landing recovery.
extends PlayerState

enum Phase { WINDUP, PLUNGE, RECOVERY }

## startup = the mid-air wind-up freeze.
@export var plunge_attack: AttackData = preload("res://entities/player/attacks/slam_plunge.tres")
## active = how long the shockwave hitbox stays on; recovery = landing recovery.
@export var impact_attack: AttackData = preload("res://entities/player/attacks/slam_impact.tres")

var _phase: Phase = Phase.WINDUP
# This slam's data: the exported resources, or boosted copies after a perfect dodge.
var _plunge_data: AttackData
var _impact_data: AttackData
var _phase_time: float = 0.0
var _dash_queued: bool = false
var _plunge_hitbox: Hitbox
var _impact_hitbox: Hitbox
var _sword: PlayerSword
# The player's feet relative to the player's origin: where the shockwave and the dust start.
var _feet_y: float = 0.0


func _ready() -> void:
	super()
	_plunge_hitbox = player.get_node(^"SlamPlungeHitbox") as Hitbox
	_impact_hitbox = player.get_node(^"SlamImpactHitbox") as Hitbox
	_sword = player.get_node(^"AttackPivot/Sword") as PlayerSword
	_plunge_hitbox.hit_landed.connect(_on_hit_landed.bind(false))
	_impact_hitbox.hit_landed.connect(_on_hit_landed.bind(true))
	var body: RectangleShape2D = (player.get_node(^"CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_feet_y = body.size.y * 0.5


func enter() -> void:
	player.attack_buffer_timer = 0.0
	player.velocity = Vector2.ZERO
	_dash_queued = false
	# A perfect-dodge empowerment is used up by the whole slam: both its hits get the bonus.
	var dodge: PerfectDodge = player.perfect_dodge
	var empowered: bool = dodge.is_empowered()
	dodge.consume_empower(plunge_attack)
	_plunge_data = dodge.boosted(plunge_attack) if empowered else plunge_attack
	_impact_data = dodge.boosted(impact_attack) if empowered else impact_attack
	_plunge_hitbox.attack_data = _plunge_data
	_impact_hitbox.attack_data = _impact_data
	_set_phase(Phase.WINDUP)


func exit() -> void:
	_plunge_hitbox.disable()
	_impact_hitbox.disable()
	_sword.settle(player.stats.sword_rest_degrees, player.stats.sword_settle_time)


func physics_update(delta: float) -> void:
	# Hitstop: physics still ticks, but with a zero time step. Nothing to simulate.
	if delta <= 0.0:
		return
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			# Frozen in mid-air: no gravity, no drift.
			player.velocity = Vector2.ZERO
			if _phase_time >= plunge_attack.startup:
				_set_phase(Phase.PLUNGE)
		Phase.PLUNGE:
			# No horizontal control and no cancel; over a pit this keeps going until the kill plane.
			player.velocity = Vector2(0.0, player.stats.slam_plunge_speed)
			player.move_and_slide()
			if player.is_on_floor():
				_impact()
		Phase.RECOVERY:
			_update_recovery(delta)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	match phase:
		Phase.WINDUP:
			_sword.settle(player.stats.slam_sword_raised_degrees, plunge_attack.startup)
		Phase.PLUNGE:
			_plunge_hitbox.enable()
			_sword.settle(player.stats.slam_sword_plunge_degrees, player.stats.slam_sword_turn_time)
		Phase.RECOVERY:
			_sword.settle(player.stats.sword_rest_degrees, impact_attack.recovery)


func _impact() -> void:
	_plunge_hitbox.disable()
	_impact_hitbox.enable()
	player.land()
	# Always, hit or miss: the slam must feel heavy even into empty floor.
	Events.camera_shake_requested.emit(_impact_data.shake)
	SlamDust.spawn(player.get_parent() as Node2D, player.global_position + Vector2(0.0, _feet_y))
	_set_phase(Phase.RECOVERY)


func _update_recovery(delta: float) -> void:
	if _phase_time >= impact_attack.active:
		_impact_hitbox.disable()
	player.velocity.x = 0.0
	player.apply_gravity(delta)
	player.move_and_slide()
	# The player can't act, except a dash once the first part of the recovery is over. A press slightly
	# too early is remembered rather than dropped.
	if Input.is_action_just_pressed(&"dash"):
		_dash_queued = true
	if _dash_queued and _phase_time >= player.stats.slam_dash_cancel_time and player.can_dash():
		state_machine.transition_to(&"Dash")
	elif _phase_time >= impact_attack.recovery:
		state_machine.transition_to(&"Run" if player.get_input_x() != 0.0 else &"Idle")


func _on_hit_landed(hurtbox: Hurtbox, is_impact: bool) -> void:
	var data: AttackData = _impact_data if is_impact else _plunge_data
	# A connected slam refreshes the dash, like any hit.
	player.refresh_dash()
	GameFeel.hitstop(data.hitstop)
	if not is_impact:
		# The impact already shook the camera on landing; only the plunge adds its own shake.
		Events.camera_shake_requested.emit(data.shake)
	var spark_direction: Vector2 = Vector2.DOWN
	if is_impact:
		spark_direction = data.knockback_velocity(player, hurtbox.global_position).normalized()
	HitSpark.spawn(player.get_parent() as Node2D, hurtbox.global_position, spark_direction)
