# AttackData: tunable numbers for one attack (spec 4.1b–4.2). Saved as .tres files per attack.
class_name AttackData
extends Resource

enum KnockbackDirection {
	## Push the target the way the attacker faces (sword swings).
	ATTACKER_FACING,
	## Push the target away from the attacker's position, whichever side it is on (slam impact).
	AWAY_FROM_ATTACKER,
}

@export var damage: int = 1
## Hazards (spikes, kill plane) send the player back to the last safe ground instead of knocking them back.
@export var is_hazard: bool = false

@export_group("Timing (seconds)")
## Wind-up: the sword pulls back.
@export var startup: float = 0.04
## The sweep: hitbox on, trail visible.
@export var active: float = 0.08
## Follow-through: the sword eases back to rest.
@export var recovery: float = 0.12

@export_group("Movement and impact")
## Forward distance the attacker moves during a ground attack, in px.
@export var lunge: float = 0.0
## Horizontal speed applied to the target, away from the attacker's position, in px/s.
@export var knockback: float = 0.0
## Upward speed applied to the target, in px/s (0 = purely sideways).
@export var knockback_lift: float = 0.0
@export var knockback_direction: KnockbackDirection = KnockbackDirection.ATTACKER_FACING
@export var hitstop: float = 0.045
## Camera trauma added on hit (0..1).
@export_range(0.0, 1.0) var shake: float = 0.12

@export_group("Swing")
## Sword angle where the sweep starts and ends, in degrees from the shoulder: 0 = straight ahead,
## -90 = straight up, +90 = straight down. from < to sweeps high→low; from > to sweeps low→high.
@export var swing_from_degrees: float = -100.0
@export var swing_to_degrees: float = 75.0
## How far the wind-up pulls the sword back past swing_from, in degrees.
@export var windup_degrees: float = 35.0
## Crescent size around the shoulder: forward reach and vertical radius, in px.
@export var reach: float = 180.0
@export var arc_height: float = 132.0


func total_duration() -> float:
	return startup + active + recovery


## Knockback for a target at target_pos. Uses the attacker's `facing` for ATTACKER_FACING; falls back to
## "away from the attacker" when the attacker has no facing (or for AWAY_FROM_ATTACKER).
func knockback_velocity(attacker: Node2D, target_pos: Vector2) -> Vector2:
	var direction: float = 1.0 if target_pos.x >= attacker.global_position.x else -1.0
	var attacker_facing: Variant = attacker.get(&"facing")
	if knockback_direction == KnockbackDirection.ATTACKER_FACING and attacker_facing != null:
		direction = signf(float(attacker_facing))
	return Vector2(direction * knockback, -knockback_lift)


## 1 for a high→low sweep, -1 for low→high.
func sweep_sign() -> float:
	return signf(swing_to_degrees - swing_from_degrees)


## Where the sword is at the end of the wind-up: pulled back against the sweep direction.
func windup_angle() -> float:
	return swing_from_degrees - windup_degrees * sweep_sign()
