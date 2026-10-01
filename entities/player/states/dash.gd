# Dash: a short, fixed-distance burst with no gravity (spec 3.4). Invincible at the start; leaves afterimages.
extends PlayerState

var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
var _started_on_floor: bool = false
var _afterimages_spawned: int = 0
# Set by the jump cancel so exit() doesn't clamp the speed the dash-jump is meant to keep.
var _keep_speed_on_exit: bool = false


func enter() -> void:
	_elapsed = 0.0
	_afterimages_spawned = 0
	_keep_speed_on_exit = false
	_started_on_floor = player.is_on_floor()
	_direction = _pick_direction()
	if _direction.x != 0.0:
		player.facing = int(signf(_direction.x))

	if not _started_on_floor:
		player.dash_charges -= 1
	player.is_dashing = true
	player.is_invincible = true
	player.wall_jump_lock_timer = 0.0
	player.velocity = _direction * player.stats.dash_speed


func exit() -> void:
	player.is_dashing = false
	player.is_invincible = false
	if _started_on_floor:
		player.dash_cooldown_timer = player.stats.ground_dash_cooldown
	if not _keep_speed_on_exit:
		# Keep some momentum, but never more than run speed, so chained dashes don't snowball.
		player.velocity = _direction * minf(player.stats.dash_speed, player.stats.max_run_speed)


func physics_update(delta: float) -> void:
	var stats: PlayerStats = player.stats

	# Jump cancel (ground dash only): keeps the dash's horizontal speed for the jump ("dash-jump").
	if _started_on_floor and stats.dash_jump_enabled and player.has_buffered_jump() and player.can_jump():
		_keep_speed_on_exit = true
		state_machine.transition_to(&"Jump")
		return

	# Attack cancel: from dash_attack_cancel_time on, a (buffered) attack press ends the dash early.
	# exit() applies the normal speed clamp, so the attack starts at run speed.
	if _can_attack_cancel() and player.wants_attack():
		state_machine.transition_to(&"Attack")
		return

	# Hitstop: physics still ticks, but with a zero time step. Nothing to simulate (and no dividing by it).
	if delta <= 0.0:
		return

	_spawn_due_afterimages()

	# The last frame may be shorter than a full tick; scaling it keeps the distance exactly dash_distance.
	var step_time: float = minf(delta, stats.dash_duration - _elapsed)
	player.velocity = _direction * stats.dash_speed * (step_time / delta)
	player.move_and_slide()

	_elapsed += delta
	player.is_invincible = _elapsed < stats.dash_invincibility_time

	if _elapsed >= stats.dash_duration:
		if not player.is_on_floor():
			state_machine.transition_to(&"Fall")
		elif player.get_input_x() != 0.0:
			state_machine.transition_to(&"Run")
		else:
			state_machine.transition_to(&"Idle")


func _can_attack_cancel() -> bool:
	return _elapsed >= player.stats.dash_attack_cancel_time


func _pick_direction() -> Vector2:
	var dir: Vector2 = Vector2(player.facing, 0.0)
	var input_x: float = player.get_input_x()
	if input_x != 0.0:
		dir.x = input_x
	if player.stats.dash_direction_mode == PlayerStats.DashDirectionMode.EIGHT_WAY:
		var aim: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if aim != Vector2.ZERO:
			# Snap to the nearest of 8 directions so an imprecise stick still gives clean dashes.
			dir = Vector2.from_angle(snappedf(aim.angle(), PI / 4.0)).snappedf(0.001)
	if player.is_on_floor() and dir.y > 0.0:
		# Can't dash into the floor: slide along it instead.
		dir = Vector2(signf(dir.x) if dir.x != 0.0 else float(player.facing), 0.0)
	elif not player.is_on_floor() and dir.x != 0.0 and int(signf(dir.x)) == player.get_wall_dir():
		# Never waste an air dash into the wall we're touching (e.g. out of a wall slide): go away from it.
		dir.x = -dir.x
	return dir


# Spreads afterimage_count copies evenly across the dash.
func _spawn_due_afterimages() -> void:
	var stats: PlayerStats = player.stats
	var interval: float = stats.dash_duration / maxi(stats.afterimage_count, 1)
	while _afterimages_spawned < stats.afterimage_count and _elapsed >= _afterimages_spawned * interval:
		_spawn_afterimage()
		_afterimages_spawned += 1


# Leaves a fading copy of the placeholder visual behind in the world.
func _spawn_afterimage() -> void:
	# Flags 0: copy the shapes only, not the PlayerVisual script (the ghost must not follow the player).
	var ghost: Node2D = player.visual.duplicate(0) as Node2D
	var level: Node2D = player.get_parent() as Node2D
	# Position it BEFORE it enters the tree. Added first, it would exist for a moment at the level's
	# origin, and physics interpolation would draw it sliding from there to the dash path.
	ghost.transform = level.global_transform.affine_inverse() * player.visual.global_transform
	level.add_child(ghost)
	ghost.reset_physics_interpolation()
	ghost.z_index = -1
	ghost.modulate.a = player.stats.afterimage_alpha
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, ^"modulate:a", 0.0, player.stats.afterimage_fade_time)
	tween.tween_callback(ghost.queue_free)
