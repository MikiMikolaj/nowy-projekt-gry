# Patrol: walk back and forth, turning at walls and ledges, until the player comes close.
extends WalkerState


func physics_update(delta: float) -> void:
	if delta <= 0.0:
		return
	var stats: WalkerStats = walker.stats
	if walker.is_player_within(stats.aggro_range, stats.aggro_height):
		state_machine.transition_to(&"Chase")
		return
	if walker.is_on_floor() and walker.is_blocked_ahead():
		walker.set_facing(-walker.facing)
	walker.velocity.x = walker.facing * stats.patrol_speed
	walker.apply_gravity(delta)
	walker.move_and_slide()
