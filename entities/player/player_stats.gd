# PlayerStats: every tunable number for the player (movement spec 3.1–3.4, combat spec 4.1–4.3, squash spec 5).
class_name PlayerStats
extends Resource

enum DashDirectionMode { HORIZONTAL, EIGHT_WAY }

@export_group("Run")
@export var max_run_speed: float = 520.0
@export var ground_accel: float = 6000.0
@export var ground_decel: float = 6000.0
## Used instead of ground_accel when input points against current velocity.
@export var turn_accel: float = 9000.0
@export var air_accel: float = 3600.0
@export var air_decel: float = 2400.0

@export_group("Jump")
## Peak height of a full (held) jump, in px.
@export var jump_height: float = 240.0
## Seconds from takeoff to the peak of a full jump.
@export var time_to_apex: float = 0.34
@export var fall_gravity_multiplier: float = 1.7
## Releasing jump early multiplies upward velocity by this.
@export var jump_cut_multiplier: float = 0.4
## Below this |velocity.y| in the air, gravity is scaled by apex_hang_multiplier.
@export var apex_hang_threshold: float = 80.0
@export var apex_hang_multiplier: float = 0.6
@export var max_fall_speed: float = 1300.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12

@export_group("Wall")
@export var wall_slide_max_speed: float = 260.0
@export var wall_jump_velocity_x: float = 520.0
## Wall jump vertical speed = jump_velocity × this.
@export var wall_jump_velocity_y_multiplier: float = 0.95
@export var wall_jump_input_lock: float = 0.14
@export var wall_coyote_time: float = 0.08

@export_group("Dash")
@export var dash_distance: float = 300.0
@export var dash_duration: float = 0.16
@export var dash_direction_mode: DashDirectionMode = DashDirectionMode.HORIZONTAL
@export var air_dash_charges: int = 1
@export var ground_dash_cooldown: float = 0.22
## Invincible for this many seconds from the start of the dash.
@export var dash_invincibility_time: float = 0.12
## An attack may cancel the dash from this many seconds in.
@export var dash_attack_cancel_time: float = 0.04
## Ground dash can be jump-cancelled, keeping its horizontal speed ("dash-jump").
@export var dash_jump_enabled: bool = true

@export_group("Combat")
## Vertical input must exceed this to count as aiming an attack up or down.
@export var attack_aim_threshold: float = 0.5
## An attack pressed this long before it becomes possible still fires (e.g. just before a dash can be cancelled).
@export var attack_buffer_time: float = 0.12
## With no attack input for this long after recovery ends, the ground combo restarts from hit 1.
@export var combo_reset_time: float = 0.15
## Minimum time from the start of one air attack to the start of the next.
@export var air_attack_cooldown: float = 0.22
## Speed the player is pushed back when a side hit connects, in px/s.
@export var side_hit_recoil: float = 120.0
## Pogo bounce speed = jump_velocity × this.
@export var pogo_velocity_multiplier: float = 0.85

@export_group("Dash Afterimage")
@export var afterimage_count: int = 3
@export var afterimage_fade_time: float = 0.25
@export_range(0.0, 1.0) var afterimage_alpha: float = 0.5

@export_group("Squash & Stretch")
@export var jump_stretch: Vector2 = Vector2(0.8, 1.2)
@export var land_squash: Vector2 = Vector2(1.2, 0.8)
@export var squash_return_time: float = 0.1

# Derived values: designers tune height and time, physics needs gravity and velocity.
var gravity: float:
	get:
		return 2.0 * jump_height / (time_to_apex * time_to_apex)

var jump_velocity: float:
	get:
		return 2.0 * jump_height / time_to_apex

var dash_speed: float:
	get:
		return dash_distance / dash_duration
