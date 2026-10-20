# WalkerStats: every tunable number for the Walker enemy (spec 6.1).
class_name WalkerStats
extends Resource

@export var max_hp: int = 3

@export_group("Movement")
@export var patrol_speed: float = 90.0
@export var chase_speed: float = 160.0
@export var gravity: float = 4000.0
@export var max_fall_speed: float = 1500.0

@export_group("Awareness")
## Starts chasing when the player is this close horizontally...
@export var aggro_range: float = 520.0
## ...and within this vertical distance (roughly the same height).
@export var aggro_height: float = 120.0
## Gives up when the player is further than this horizontally, or further than lose_height vertically.
@export var lose_range: float = 800.0
@export var lose_height: float = 300.0
## While chasing, the walker only turns if the player is further than this horizontally, so it doesn't
## jitter while overlapping the player (they pass through each other).
@export var chase_turn_deadzone: float = 8.0

@export_group("Hurt")
## No control for this long after being hit. Contact damage stays on meanwhile.
@export var hurt_stun_time: float = 0.30
## How fast knockback slows down while stunned, in px/s².
@export var hurt_friction: float = 1400.0
@export var flash_time: float = 0.08

@export_group("Death")
@export var death_hitstop: float = 0.08
@export_range(0.0, 1.0) var death_shake: float = 0.35
## The body squashes to this scale before disappearing.
@export var death_squash: Vector2 = Vector2(1.5, 0.35)
@export var death_squash_time: float = 0.1
