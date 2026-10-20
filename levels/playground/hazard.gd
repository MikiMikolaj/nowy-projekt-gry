# Hazard: an always-on enemy_attack hitbox (spikes, kill plane). Deals hazard damage, which sends the player
# back to the last safe ground. Nothing bounces off it.
class_name Hazard
extends Hitbox

const HAZARD_ATTACK: AttackData = preload("res://levels/playground/hazard_attack.tres")


func _ready() -> void:
	if attack_data == null:
		attack_data = HAZARD_ATTACK
	continuous = true
	enabled_on_ready = true
	super()
