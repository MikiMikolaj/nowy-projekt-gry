# Jump: rising after a jump. Releasing jump early cuts the rise (variable jump height).
extends PlayerState

var _was_cut: bool = false


func enter() -> void:
	_was_cut = false
	player.jump()


func physics_update(delta: float) -> void:
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
