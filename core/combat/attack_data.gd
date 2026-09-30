# AttackData: tunable numbers for one attack (spec section 4). Saved as .tres files per attack.
class_name AttackData
extends Resource

enum Direction { FORWARD, UP, DOWN }

@export var direction: Direction = Direction.FORWARD
@export var damage: int = 1

@export_group("Timing (seconds)")
@export var startup: float = 0.03
@export var active: float = 0.07
@export var recovery: float = 0.10

@export_group("Movement and impact")
## Forward distance the attacker moves during the attack, in px.
@export var lunge: float = 0.0
## Speed applied to the target away from the attacker, in px/s.
@export var knockback: float = 0.0
@export var hitstop: float = 0.035
## Camera trauma added on hit (0..1).
@export_range(0.0, 1.0) var shake: float = 0.1


func total_duration() -> float:
	return startup + active + recovery
