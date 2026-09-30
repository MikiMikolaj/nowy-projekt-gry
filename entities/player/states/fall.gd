# Fall: airborne and not rising. Handles coyote jumps and landing (with jump buffer).
extends PlayerState


func physics_update(delta: float) -> void:
	if player.wants_jump():
		state_machine.transition_to(&"Jump")
		return

	player.update_facing()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.stats.air_accel, player.stats.air_decel)
	player.move_and_slide()

	if player.is_on_floor():
		player.land()
		if player.has_buffered_jump():
			state_machine.transition_to(&"Jump")
		elif player.get_input_x() != 0.0:
			state_machine.transition_to(&"Run")
		else:
			state_machine.transition_to(&"Idle")
