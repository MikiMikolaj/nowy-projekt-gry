# WallSlide: falling while holding toward a wall; fall speed is capped (spec 3.3). No climbing.
extends PlayerState


func physics_update(delta: float) -> void:
	if player.wants_dash():
		state_machine.transition_to(&"Dash")
		return
	if player.wants_jump():
		state_machine.transition_to(&"Jump")
		return

	player.update_facing()
	player.apply_gravity(delta)
	player.velocity.y = minf(player.velocity.y, player.stats.wall_slide_max_speed)
	player.apply_horizontal(delta, player.stats.air_accel, player.stats.air_decel)
	player.move_and_slide()

	if player.is_on_floor():
		player.land()
		state_machine.transition_to(&"Run" if player.get_input_x() != 0.0 else &"Idle")
	elif not player.should_wall_slide():
		# Let go of the wall or ran out of wall: wall coyote time still allows a wall jump from Fall.
		state_machine.transition_to(&"Fall")
