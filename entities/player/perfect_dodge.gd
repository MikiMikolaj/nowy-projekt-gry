# PerfectDodge: spec 4.5.2. An enemy attack touching the player during the dash i-frames slows time, refunds
# the dash, flashes the player and empowers the next attack (+damage, finisher hitstop and shake) for a moment.
class_name PerfectDodge
extends Node

## "Finisher hitstop and shake" come from the combo finisher, so tuning it tunes this too.
const FINISHER: AttackData = preload("res://entities/player/attacks/combo_3.tres")

signal perfect_dodged

var empower_timer: float = 0.0
var _triggered_this_dash: bool = false
# The Dash state sets the ground cooldown when it ends, after the dodge; this clears it again then.
var _cooldown_refund_pending: bool = false

@onready var _player: Player = owner as Player


func _ready() -> void:
	(owner.get_node(^"Hurtbox") as Hurtbox).hit_evaded.connect(_on_hit_evaded)


func _physics_process(delta: float) -> void:
	empower_timer = maxf(empower_timer - delta, 0.0)
	if not _player.is_dashing:
		_triggered_this_dash = false
		if _cooldown_refund_pending:
			_player.dash_cooldown_timer = 0.0
			_cooldown_refund_pending = false


func is_empowered() -> bool:
	return empower_timer > 0.0


## If empowered, uses the empowerment up and returns a boosted copy of `data`; otherwise returns `data`.
func consume_empower(data: AttackData) -> AttackData:
	if not is_empowered():
		return data
	empower_timer = 0.0
	return boosted(data)


## A copy of `data` with the perfect-dodge bonus: extra damage, and at least the finisher's hitstop and shake.
func boosted(data: AttackData) -> AttackData:
	var copy: AttackData = data.duplicate() as AttackData
	copy.damage += _player.stats.perfect_dodge_bonus_damage
	copy.hitstop = maxf(copy.hitstop, FINISHER.hitstop)
	copy.shake = maxf(copy.shake, FINISHER.shake)
	return copy


func _on_hit_evaded(hitbox: Hitbox) -> void:
	var stats: PlayerStats = _player.stats
	# Only the dash i-frames count (not post-hurt invincibility), only enemy attacks (not spikes or the
	# kill plane), and only once per dash.
	if not stats.perfect_dodge_enabled or not _player.damage.dash_invincible or _triggered_this_dash:
		return
	if hitbox.attack_data == null or hitbox.attack_data.is_hazard:
		return
	_triggered_this_dash = true
	_cooldown_refund_pending = true
	_player.refresh_dash()
	empower_timer = stats.perfect_dodge_empower_time
	GameFeel.slow_mo(stats.perfect_dodge_slow_mo_scale, stats.perfect_dodge_slow_mo_time)
	_player.visual.flash(stats.perfect_dodge_flash_color, stats.perfect_dodge_flash_time)
	perfect_dodged.emit()
