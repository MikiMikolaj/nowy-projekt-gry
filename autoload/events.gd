# Events: global signal bus. Only for truly global things; everything else uses local signals.
extends Node

@warning_ignore("unused_signal")
signal camera_shake_requested(trauma: float)
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal player_respawned
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node)
