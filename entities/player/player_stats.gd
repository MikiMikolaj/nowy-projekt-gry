# PlayerStats: every tunable number for the player (movement spec 3.1–3.4, combat 4.1–4.4, squash spec 5).
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

@export_group("Damage")
@export var max_hp: int = 5
## Knockback when hurt: x away from the source, y upward (negative), in px/s.
@export var hurt_knockback: Vector2 = Vector2(340.0, -420.0)
## No control for this long after a hit.
@export var hurt_stun_time: float = 0.25
## Invincible (and flickering) for this long after a hit.
@export var hurt_invincibility_time: float = 1.0
@export var hurt_hitstop: float = 0.10
@export_range(0.0, 1.0) var hurt_shake: float = 0.5
## How fast the sprite blinks while invincible after a hit, in seconds per blink.
@export var hurt_flicker_interval: float = 0.06
## Opacity on the "off" blink of the flicker.
@export_range(0.0, 1.0) var hurt_flicker_alpha: float = 0.25
## Frozen this long after dying before respawning.
@export var death_freeze_time: float = 0.4

@export_group("Perfect Dodge")
## Spec 4.5.2 toggle: an enemy attack touching you during dash i-frames slows time and empowers your next attack.
@export var perfect_dodge_enabled: bool = true
@export_range(0.0, 1.0) var perfect_dodge_slow_mo_scale: float = 0.3
## Slow-mo length in real seconds.
@export var perfect_dodge_slow_mo_time: float = 0.25
## The next attack started within this window gets the bonus.
@export var perfect_dodge_empower_time: float = 1.0
@export var perfect_dodge_bonus_damage: int = 1
@export var perfect_dodge_flash_color: Color = Color(0.3, 1.0, 1.0)
@export var perfect_dodge_flash_time: float = 0.15
## How fast the empowered glow pulses (radians per real second).
@export var perfect_dodge_glow_pulse_speed: float = 14.0

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

@export_group("Slam")
## Plunge speed, straight down, in px/s. (Wind-up time is slam_plunge.tres startup; landing recovery is
## slam_impact.tres recovery; impact hitbox time is slam_impact.tres active.)
@export var slam_plunge_speed: float = 1800.0
## Landing recovery can only be dash-cancelled after this many seconds.
@export var slam_dash_cancel_time: float = 0.12
## Sword angle while winding up (raised overhead) and while plunging (pointing down), in degrees.
@export var slam_sword_raised_degrees: float = -90.0
@export var slam_sword_plunge_degrees: float = 90.0
## How fast the sword flips from overhead to pointing down when the plunge starts.
@export var slam_sword_turn_time: float = 0.05

@export_group("Sword")
## Resting sword angle in degrees (0 = ahead, 90 = straight down, 180 = straight back): down and back,
## shallow enough that the 150 px blade stays above the floor.
@export var sword_rest_degrees: float = 155.0
## How fast the sword returns to rest when an attack is cancelled.
@export var sword_settle_time: float = 0.1
## Slash trail: opacity while the hitbox is on, then fade-out time once it turns off.
@export_range(0.0, 1.0) var trail_alpha: float = 0.85
@export var trail_fade_time: float = 0.1
## Crescent shape: inner edge size relative to the outer edge (thicker crescent = smaller), and how much
## shorter the inner edge is at each end (makes the pointed tips), in degrees.
@export_range(0.0, 0.9) var crescent_inner_ratio: float = 0.25
@export var crescent_taper_degrees: float = 15.0

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
