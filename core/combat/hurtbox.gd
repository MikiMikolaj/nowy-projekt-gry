# Hurtbox: an Area2D that can be hit by Hitboxes. Forwards damage to a HealthComponent if it has one.
class_name Hurtbox
extends Area2D

## A hit that counted. Listen to this for reactions (flash, knockback, wobble).
signal hit_received(hitbox: Hitbox)
## A hit that touched us while invincible (used later for the perfect dodge).
signal hit_evaded(hitbox: Hitbox)

## Leave empty to use a sibling HealthComponent. With none at all, hits still register (infinite HP).
@export var health: HealthComponent


func _ready() -> void:
	# Hitboxes do the detecting; a hurtbox only needs to be detectable.
	monitoring = false
	monitorable = true
	if health == null:
		for sibling: Node in get_parent().get_children():
			if sibling is HealthComponent:
				health = sibling as HealthComponent
				break


# Called by a Hitbox that overlaps us. Returns true if the hit counted.
func receive_hit(hitbox: Hitbox) -> bool:
	# Never hurt yourself with your own attack.
	if hitbox.attacker != null and hitbox.attacker == owner:
		return false
	if health != null and health.invincible:
		hit_evaded.emit(hitbox)
		return false
	hit_received.emit(hitbox)
	if health != null:
		health.take_damage(hitbox.attack_data.damage, hitbox.attacker)
	return true
