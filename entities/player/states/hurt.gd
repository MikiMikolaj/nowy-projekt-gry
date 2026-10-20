# Hurt: knocked back and stunned after a hit (spec 4.4). No control until the stun ends.
# After a hazard the player has already been teleported to safe ground, so there is no knockback.
extends PlayerState

var _time: float = 0.0


func enter() -> void:
	_time = 0.0
	var damage: PlayerDamage = player.damage
	if damage.last_hit_was_hazard:
		player.velocity = Vector2.ZERO
		return
	var away: float = 1.0 if player.global_position.x >= damage.last_hit_position.x else -1.0
	player.velocity = Vector2(away * player.stats.hurt_knockback.x, player.stats.hurt_knockback.y)


func physics_update(delta: float) -> void:
	# Hitstop: physics still ticks, but with a zero time step.
	if delta <= 0.0:
		return
	_time += delta
	var was_on_floor: bool = player.is_on_floor()
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.stats.air_decel * delta)
	player.move_and_slide()
	if not was_on_floor and player.is_on_floor():
		player.land()
	if _time < player.stats.hurt_stun_time:
		return
	if not player.is_on_floor():
		state_machine.transition_to(&"Fall")
	elif player.get_input_x() != 0.0:
		state_machine.transition_to(&"Run")
	else:
		state_machine.transition_to(&"Idle")
