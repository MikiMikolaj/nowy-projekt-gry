# PlayerDamage: everything about the player getting hurt (spec 4.4): invincibility, reacting to hits and
# hazards, tracking the last safe ground, death and respawn. Lives on a child node of the Player.
class_name PlayerDamage
extends Node

## Set by the Dash state for its i-frames. Post-hurt invincibility is the separate timer below.
var dash_invincible: bool = false:
	set(value):
		dash_invincible = value
		_sync_invincibility()
var invincibility_timer: float = 0.0
## Where the last hit came from, and whether it was a hazard. Read by the Hurt state.
var last_hit_position: Vector2 = Vector2.ZERO
var last_hit_was_hazard: bool = false
## Last spot where the player stood on the floor away from hazards. Hazards send the player back here.
var safe_position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO

# After a teleport the physics engine still reports the old overlaps for a frame or two (e.g. the walker
# that just killed you), so hits are ignored that long. A tick count, not a timer: it is about physics steps.
const TELEPORT_GRACE_TICKS: int = 2
## How far below the feet the safe-ground check looks for floor, in px.
const SAFE_FLOOR_PROBE: float = 8.0
var _teleport_grace: int = 0

@onready var _player: Player = owner as Player
@onready var _health: HealthComponent = owner.get_node(^"HealthComponent")
@onready var _hurtbox: Hurtbox = owner.get_node(^"Hurtbox")
@onready var _hazard_sensor: Area2D = owner.get_node(^"HazardSensor")
@onready var _state_machine: StateMachine = owner.get_node(^"StateMachine")


func _ready() -> void:
	_health.max_hp = _player.stats.max_hp
	_health.reset()
	_hurtbox.hit_received.connect(_on_hit_received)
	_health.died.connect(_on_died)
	var spawn: Node2D = get_tree().get_first_node_in_group(&"player_spawn") as Node2D
	spawn_position = spawn.global_position if spawn != null else _player.global_position
	safe_position = _player.global_position


func _physics_process(delta: float) -> void:
	invincibility_timer = maxf(invincibility_timer - delta, 0.0)
	# Counted in real physics steps only: during hitstop the engine still ticks, with a zero time step.
	if delta > 0.0:
		_teleport_grace = maxi(_teleport_grace - 1, 0)
	_sync_invincibility()
	if _player.is_on_floor() and not _health.is_dead() and _has_floor_under_center() and not _is_near_hazard():
		safe_position = _player.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reset"):
		respawn()


func is_invincible() -> bool:
	return dash_invincible or invincibility_timer > 0.0 or _teleport_grace > 0


## True while the post-hurt invincibility is running (the sprite flickers). Dash i-frames don't flicker.
func is_flickering() -> bool:
	return invincibility_timer > 0.0


## Back to the spawn point with full HP. Used after death and by debug_reset; enemies reset via the event.
func respawn() -> void:
	_teleport(spawn_position)
	safe_position = spawn_position
	_health.reset()
	invincibility_timer = 0.0
	dash_invincible = false
	_player.facing = 1
	_player.refresh_dash()
	_state_machine.transition_to(&"Idle")
	Events.player_respawned.emit()


func _on_hit_received(hitbox: Hitbox) -> void:
	# A killing blow is handled by _on_died (the Hurtbox applies damage before announcing the hit).
	if _health.is_dead():
		return
	_play_hurt_feel()
	invincibility_timer = _player.stats.hurt_invincibility_time
	_sync_invincibility()
	last_hit_position = hitbox.global_position
	last_hit_was_hazard = hitbox.attack_data.is_hazard
	if last_hit_was_hazard:
		_teleport(safe_position)
	# Overrides whatever the player was doing, including slam recovery.
	_state_machine.transition_to(&"Hurt")


func _on_died() -> void:
	_play_hurt_feel()
	Events.player_died.emit()
	_state_machine.transition_to(&"Dead")


func _play_hurt_feel() -> void:
	GameFeel.hitstop(_player.stats.hurt_hitstop)
	Events.camera_shake_requested.emit(_player.stats.hurt_shake)


func _teleport(target: Vector2) -> void:
	_player.global_position = target
	_player.velocity = Vector2.ZERO
	# Without this, physics interpolation would draw the player sliding across the level for a frame.
	_player.reset_physics_interpolation()
	_teleport_grace = TELEPORT_GRACE_TICKS
	_sync_invincibility()


# "On floor" is also true when only a corner of the body is on a ledge. A spot like that is no good to
# teleport back to (the player would fall straight off again), so the floor must be under the centre.
func _has_floor_under_center() -> bool:
	var body: RectangleShape2D = (owner.get_node(^"CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var from: Vector2 = _player.global_position
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, body.size.y * 0.5 + SAFE_FLOOR_PROBE), _player.collision_mask)
	return not _player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _is_near_hazard() -> bool:
	for area: Area2D in _hazard_sensor.get_overlapping_areas():
		var hitbox: Hitbox = area as Hitbox
		if hitbox != null and hitbox.attack_data != null and hitbox.attack_data.is_hazard:
			return true
	return false


func _sync_invincibility() -> void:
	if _health != null:
		_health.invincible = is_invincible()
