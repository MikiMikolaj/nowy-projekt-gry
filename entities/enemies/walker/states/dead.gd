# Dead: the death sequence (spec 6.1/5): hitstop, shake, death burst, enemy_killed, then a short squash and
# the walker is removed.
extends WalkerState


func enter() -> void:
	var stats: WalkerStats = walker.stats
	walker.velocity = Vector2.ZERO
	# Harmless from here on: no more contact damage, no more hits.
	walker.contact_hitbox.disable()
	walker.hurtbox.set_deferred(&"monitorable", false)
	GameFeel.hitstop(stats.death_hitstop)
	Events.camera_shake_requested.emit(stats.death_shake)
	DeathBurst.spawn(walker.get_parent() as Node2D, walker.global_position, walker.get_base_color())
	Events.enemy_killed.emit(walker)
	var tween: Tween = walker.create_tween()
	tween.tween_property(walker.visual, ^"scale", Vector2(stats.death_squash.x * walker.facing, stats.death_squash.y),
			stats.death_squash_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(walker.queue_free)
