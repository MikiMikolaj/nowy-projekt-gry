# Hurt: knocked back and stunned (spec 6.1). Contact damage stays on, so touching it is still risky.
extends WalkerState

var _time: float = 0.0


func enter() -> void:
	_time = 0.0
	walker.velocity = walker.pending_knockback


func physics_update(delta: float) -> void:
	if delta <= 0.0:
		return
	var stats: WalkerStats = walker.stats
	_time += delta
	walker.apply_gravity(delta)
	walker.velocity.x = move_toward(walker.velocity.x, 0.0, stats.hurt_friction * delta)
	walker.move_and_slide()
	if _time >= stats.hurt_stun_time:
		var aggro: bool = walker.is_player_within(stats.aggro_range, stats.aggro_height)
		state_machine.transition_to(&"Chase" if aggro else &"Patrol")
