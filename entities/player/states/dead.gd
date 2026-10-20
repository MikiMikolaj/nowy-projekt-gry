# Dead: the player freezes in place for a moment (spec 4.4), then respawns at the spawn point.
extends PlayerState

var _time: float = 0.0


func enter() -> void:
	_time = 0.0
	player.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	_time += delta
	if _time >= player.stats.death_freeze_time:
		player.damage.respawn()
