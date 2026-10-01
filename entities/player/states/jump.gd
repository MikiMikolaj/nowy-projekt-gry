# Jump: rising after a ground or wall jump. Releasing jump early cuts the rise (variable jump height).
extends PlayerState

var _was_cut: bool = false


func enter() -> void:
	_was_cut = false
	player.start_jump()


func physics_update(delta: float) -> void:
	if player.wants_dash():
		state_machine.transition_to(&"Dash")
		return
	if player.wants_attack():
		state_machine.transition_to(&"Attack")
		return
	# Wall jump while still rising (e.g. chaining up a shaft): re-enter this state for a fresh jump.
	if player.has_buffered_jump() and player.can_wall_jump():
		state_machine.transition_to(&"Jump")
		return

	# Checked every frame (not just on release) so a jump buffered and released before landing is still short.
	if not _was_cut and not Input.is_action_pressed(&"jump") and player.velocity.y < 0.0:
		player.velocity.y *= player.stats.jump_cut_multiplier
		_was_cut = true

	player.update_facing()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.stats.air_accel, player.stats.air_decel)
	player.move_and_slide()

	# Also covers bonking a ceiling, which zeroes velocity.y.
	if player.velocity.y >= 0.0:
		state_machine.transition_to(&"Fall")
