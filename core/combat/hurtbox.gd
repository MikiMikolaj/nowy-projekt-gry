# Hurtbox: an Area2D that receives hits from Hitboxes and forwards the damage to a HealthComponent.
class_name Hurtbox
extends Area2D

signal hit_received(hitbox: Hitbox)

@export var health: HealthComponent


func _ready() -> void:
	# Hurtboxes detect hitboxes, not the other way around, so each hit is resolved in one place.
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var hitbox: Hitbox = area as Hitbox
	if hitbox == null or hitbox.attack_data == null:
		return
	# Never hurt yourself with your own attack.
	if hitbox.attacker != null and hitbox.attacker == owner:
		return
	# Reactions (flash, knockback) listen to this; emitted even while invincible so perfect dodge can see it.
	hit_received.emit(hitbox)
	if health != null and not health.invincible:
		health.take_damage(hitbox.attack_data.damage, hitbox.attacker)
		hitbox.register_hit(self)
