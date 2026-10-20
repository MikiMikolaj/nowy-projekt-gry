# Hitbox: an Area2D that hits any Hurtbox it overlaps while enabled, once per target per enable().
class_name Hitbox
extends Area2D

## Emitted when this hitbox damages a hurtbox, so the attacker can react (dash refresh, recoil, hitstop).
signal hit_landed(hurtbox: Hurtbox)

## What this hit does. Leave empty for a hitbox that deals no damage yet.
@export var attack_data: AttackData
## The entity that owns this attack (used for knockback direction and damage source).
## Falls back to the scene owner when left empty.
@export var attacker: Node
## Player attacks start off and are enabled per swing; enemy contact hitboxes and hazards stay on.
@export var enabled_on_ready: bool = false

# Everything already hit since the last enable(), so one swing can't hit the same target twice.
var _hit_targets: Array[Area2D] = []


func _ready() -> void:
	if attacker == null:
		attacker = owner
	area_entered.connect(_on_area_entered)
	if enabled_on_ready:
		enable()
	else:
		disable()


# Starts a new swing: forgets previous targets and turns detection on.
func enable() -> void:
	_hit_targets.clear()
	# Deferred because toggling during a physics callback is not allowed.
	set_deferred(&"monitoring", true)
	set_deferred(&"monitorable", true)


func disable() -> void:
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox == null or attack_data == null or hurtbox in _hit_targets:
		return
	if hurtbox.receive_hit(self):
		_hit_targets.append(hurtbox)
		hit_landed.emit(hurtbox)
