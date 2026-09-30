# Hitbox: an Area2D that deals an AttackData's damage to any Hurtbox it overlaps while enabled.
class_name Hitbox
extends Area2D

## Emitted when this hitbox connects, so the attacker can react (dash refresh, pogo, recoil).
signal hit_landed(hurtbox: Hurtbox)

@export var attack_data: AttackData
## The entity that owns this attack (used for knockback direction and damage source).
## Falls back to the scene owner when left empty.
@export var attacker: Node
## Player attacks start off and are enabled per swing; enemy contact hitboxes stay on.
@export var enabled_on_ready: bool = false


func _ready() -> void:
	if attacker == null:
		attacker = owner
	# Hurtboxes do the detecting; a hitbox only needs to be detectable.
	monitoring = false
	if enabled_on_ready:
		enable()
	else:
		disable()


func enable() -> void:
	# Deferred because toggling during a physics callback is not allowed.
	set_deferred(&"monitorable", true)


func disable() -> void:
	set_deferred(&"monitorable", false)


func is_enabled() -> bool:
	return monitorable


# Called by the Hurtbox that got hit.
func register_hit(hurtbox: Hurtbox) -> void:
	hit_landed.emit(hurtbox)
