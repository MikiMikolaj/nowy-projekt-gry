# Walker: basic patrolling melee enemy (spec 6.1). Patrols, chases the player on the same level, and deals
# contact damage (even while stunned). Shared helpers live here; the states decide what to do.
class_name Walker
extends CharacterBody2D

const CONTACT_ATTACK: AttackData = preload("res://entities/enemies/walker/walker_contact.tres")

## Swap for another .tres to A/B test.
@export var stats: WalkerStats = preload("res://entities/enemies/walker/walker_stats.tres")
## Which way it walks first: 1 = right, -1 = left.
@export var start_facing: int = -1

var facing: int = -1
## Knockback from the latest hit, applied by the Hurt state.
var pending_knockback: Vector2 = Vector2.ZERO

var _base_color: Color
var _flash_tween: Tween
var _ledge_offset_x: float = 0.0
var _wall_reach: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body_rect: ColorRect = $Visual/Body
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var state_machine: StateMachine = $StateMachine
@onready var _ledge_check: RayCast2D = $LedgeCheck
@onready var _wall_check: RayCast2D = $WallCheck


func _ready() -> void:
	health.max_hp = stats.max_hp
	health.reset()
	contact_hitbox.attack_data = CONTACT_ATTACK
	_base_color = body_rect.color
	# The death squash is animated per rendered frame, so it must not also be physics-interpolated.
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ledge_offset_x = absf(_ledge_check.position.x)
	_wall_reach = absf(_wall_check.target_position.x)
	set_facing(start_facing)
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func set_facing(direction: int) -> void:
	facing = direction
	_ledge_check.position.x = _ledge_offset_x * direction
	_wall_check.target_position.x = _wall_reach * direction
	visual.scale.x = direction


func apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)


## A wall ahead, or (on the ground) no floor ahead: walking on would bump or fall.
func is_blocked_ahead() -> bool:
	_ledge_check.force_raycast_update()
	_wall_check.force_raycast_update()
	return _wall_check.is_colliding() or (is_on_floor() and not _ledge_check.is_colliding())


func get_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## Player within max_dx horizontally and max_dy vertically.
func is_player_within(max_dx: float, max_dy: float) -> bool:
	var player: Player = get_player()
	if player == null:
		return false
	var offset: Vector2 = player.global_position - global_position
	return absf(offset.x) <= max_dx and absf(offset.y) <= max_dy


func horizontal_offset_to_player() -> float:
	var player: Player = get_player()
	return player.global_position.x - global_position.x if player != null else 0.0


func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	body_rect.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_interval(stats.flash_time)
	_flash_tween.tween_callback(func() -> void: body_rect.color = _base_color)


func get_base_color() -> Color:
	return _base_color


func _on_hit_received(hitbox: Hitbox) -> void:
	# A killing blow goes to Dead via health.died instead (the Hurtbox applies damage before announcing).
	if health.is_dead():
		return
	pending_knockback = hitbox.attack_data.knockback_velocity(hitbox.attacker as Node2D, global_position)
	flash()
	# Re-entering Hurt restarts the stun, so a combo keeps it stunned.
	state_machine.transition_to(&"Hurt")


func _on_died() -> void:
	flash()
	state_machine.transition_to(&"Dead")
