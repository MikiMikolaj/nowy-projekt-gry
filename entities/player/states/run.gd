# Run: on the ground with horizontal input held.
extends PlayerState


func physics_update(delta: float) -> void:
	if player.wants_jump():
		state_machine.transition_to(&"Jump")
		return
	player.update_facing()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.stats.ground_accel, player.stats.ground_decel)
	player.move_and_slide()

	if not player.is_on_floor():
		# Walked off a ledge: coyote time lets Fall still accept a jump.
		state_machine.transition_to(&"Fall")
	elif player.get_input_x() == 0.0:
		state_machine.transition_to(&"Idle")
