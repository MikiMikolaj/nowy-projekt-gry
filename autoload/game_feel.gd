# GameFeel: owns Engine.time_scale for hitstop and slow-mo requests (spec section 5).
extends Node

const NORMAL_TIME_SCALE: float = 1.0
const HITSTOP_TIME_SCALE: float = 0.0

# End times are in real (unscaled) milliseconds so overlapping requests can be compared.
# Overlapping requests keep whichever ends last; they never stack.
var _hitstop_end_ms: int = 0
var _slow_mo_end_ms: int = 0
var _slow_mo_scale: float = NORMAL_TIME_SCALE


func _ready() -> void:
	# Must keep running while the tree is paused or time is frozen, or time would never be restored.
	process_mode = Node.PROCESS_MODE_ALWAYS


func hitstop(duration: float) -> void:
	var end_ms: int = _now_ms() + _to_ms(duration)
	if end_ms <= _hitstop_end_ms:
		return
	_hitstop_end_ms = end_ms
	_start_restore_timer(end_ms)
	_apply_time_scale()


func slow_mo(scale: float, duration: float) -> void:
	var end_ms: int = _now_ms() + _to_ms(duration)
	if end_ms <= _slow_mo_end_ms:
		return
	_slow_mo_end_ms = end_ms
	_slow_mo_scale = scale
	_start_restore_timer(end_ms)
	_apply_time_scale()


func is_hitstopped() -> bool:
	return _now_ms() < _hitstop_end_ms


func _start_restore_timer(end_ms: int) -> void:
	var duration: float = float(end_ms - _now_ms()) / 1000.0
	# ignore_time_scale = true: a timer driven by scaled time would never fire at time_scale 0.
	var timer: SceneTreeTimer = get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_on_restore_timer_timeout.bind(end_ms))


func _on_restore_timer_timeout(end_ms: int) -> void:
	# Frame timing and the millisecond clock can disagree slightly; if we woke early, wait the rest
	# instead of leaving time frozen forever.
	if _now_ms() < end_ms:
		_start_restore_timer(end_ms)
		return
	_apply_time_scale()


# Hitstop wins over slow-mo; when hitstop ends inside a slow-mo, time returns to the slow-mo scale.
func _apply_time_scale() -> void:
	var now: int = _now_ms()
	if now < _hitstop_end_ms:
		Engine.time_scale = HITSTOP_TIME_SCALE
	elif now < _slow_mo_end_ms:
		Engine.time_scale = _slow_mo_scale
	else:
		Engine.time_scale = NORMAL_TIME_SCALE


func _now_ms() -> int:
	return Time.get_ticks_msec()


func _to_ms(seconds: float) -> int:
	return int(seconds * 1000.0)
