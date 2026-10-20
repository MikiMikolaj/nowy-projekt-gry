# Chase: run at the player. Stops at ledges and walls rather than falling off or pushing into them.
extends WalkerState


func physics_update(delta: float) -> void:
	if delta <= 0.0:
		return
	var stats: WalkerStats = walker.stats
	if not walker.is_player_within(stats.lose_range, stats.lose_height):
		state_machine.transition_to(&"Patrol")
		return
	var offset_x: float = walker.horizontal_offset_to_player()
	if absf(offset_x) > stats.chase_turn_deadzone:
		walker.set_facing(int(signf(offset_x)))
	if walker.is_on_floor() and walker.is_blocked_ahead():
		walker.velocity.x = 0.0
	else:
		walker.velocity.x = walker.facing * stats.chase_speed
	walker.apply_gravity(delta)
	walker.move_and_slide()
