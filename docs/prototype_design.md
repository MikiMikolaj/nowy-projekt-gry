# Prototype Design Spec — Combat Playground v0.1

> Source of truth for the prototype. Every number here is a **starting value**. All of them live in `.tres` resources so you can tune them in the Inspector. Expect to change most of them after playtesting; that is the point of the prototype.

## 1. Design pillars

1. **Responsive first.** The player never fights the controls. Input forgiveness (coyote time, buffering) is invisible but always there.
2. **Low commitment, high tempo.** Attacks are fast and commit you only briefly (Dead Cells pace). Dash and jump are escape hatches, and the dash can be cancelled into an attack.
3. **Aggression is rewarded.** Landing hits keeps you mobile: a hit refreshes the dash and a pogo refreshes the jump. Playing safe is allowed but slower.
4. **Every hit is felt.** Hitstop, knockback, shake, flash and particles fire on every successful hit, scaled by how important the hit is.
5. **Readable over flashy.** Enemies telegraph, and hitboxes match what you see.

**Prototype goal:** answer one question, *"Is it fun to move and fight in an empty room for 10 minutes?"*

## 2. Technical setup

| Setting | Value | Why |
|---|---|---|
| Base resolution | 1920×1080 | HD comic style (not pixel art) |
| Stretch mode / aspect | `canvas_items` / `expand` | Scales cleanly to any screen |
| Physics ticks | 60 | Default. Revisit only if needed |
| Physics interpolation | ON (Camera2D process callback = Physics) | Smooth motion on 120/144 Hz monitors |
| Grid unit | 64 px ("1 tile") | All level geometry snaps to this |
| Player collision | 44 × 96 px rectangle | About 1 × 1.5 tiles |

**Input map**

| Action | Keyboard | Gamepad |
|---|---|---|
| move_left / right / up / down | A D W S + Arrow keys | Left stick (deadzone 0.25) + D-pad |
| jump | Space, C | A / Cross |
| attack | J, X | X / Square |
| dash | K, Shift, Z | R1 / RB and R2 / RT |
| debug_reset | R | Select / Back |
| debug_overlay | F1 | — |

Attack direction uses a stricter threshold: vertical input counts as "aiming" only when |y| > 0.5. This stops accidental up/down slashes on a stick.

## 3. Movement

### 3.1 Run

| Param | Value |
|---|---|
| max_run_speed | 520 px/s |
| ground_accel | 6000 px/s² (full speed in under 0.1 s) |
| ground_decel | 6000 px/s² |
| turn_accel | 9000 px/s² (reversing direction is extra snappy) |
| air_accel / air_decel | 3600 / 2400 px/s² |

- Facing flips instantly with input. There is no turn-around animation lock.

### 3.2 Jump (height-and-time based, so it is designer-friendly)

| Param | Value |
|---|---|
| jump_height | 240 px (about 3.75 tiles) |
| time_to_apex | 0.34 s |
| → derived gravity | `2h / t²` ≈ 4150 px/s² |
| → derived jump_velocity | `2h / t` ≈ 1410 px/s |
| fall_gravity_multiplier | 1.7 (falls faster than it rises, for weight) |
| jump_cut_multiplier | 0.4 (releasing jump early multiplies upward velocity by this) |
| apex_hang_threshold / multiplier | when \|vy\| < 80 → gravity × 0.6 (brief float at the top, for air control) |
| max_fall_speed | 1300 px/s |
| coyote_time | 0.10 s (can still jump after leaving a ledge) |
| jump_buffer | 0.12 s (a jump pressed just before landing still fires) |

### 3.3 Wall slide and wall jump

- A wall slide starts when airborne, falling, touching a wall (RayCast2D check) **and** holding toward it.
- There is no wall climbing and no double jump.

| Param | Value |
|---|---|
| wall_slide_max_speed | 260 px/s |
| wall_jump_velocity | x 520 away from the wall, y = jump_velocity × 0.95 |
| wall_jump_input_lock | 0.14 s (holding toward the wall cannot cancel the push-off) |
| wall_coyote_time | 0.08 s |

### 3.4 Dash (combat dodge + mobility)

| Param | Value |
|---|---|
| dash_distance | 300 px |
| dash_duration | 0.16 s (speed ≈ 1875 px/s) |
| dash_direction_mode | `HORIZONTAL` (default) or `EIGHT_WAY`; a toggle in PlayerStats for A/B testing |
| air_dash_charges | 1 |
| ground_dash_cooldown | 0.22 s |
| invincibility window | first 0.12 s of the dash |
| gravity during dash | off (fixed height) |
| exit speed | clamped to max_run_speed in the dash direction (keeps momentum without being too fast) |
| attack cancel | allowed from 0.04 s into the dash |
| jump cancel (ground dash only) | allowed, and keeps horizontal dash speed for that jump ("dash-jump" tech) |

**The dash charge refreshes on:** landing, touching a wall, **landing any attack on an enemy**, and a pogo.

## 4. Combat

### 4.1 Attack directions

| Input when attack pressed | Grounded | Airborne |
|---|---|---|
| none / left / right | ground combo hit (forward) | air side slash |
| up | up slash | up slash |
| down | forward (ground combo) | **down slash → pogo** |

- Attack timing uses phases: startup → active (hitbox on) → recovery. In the prototype this is **driven by code from AttackData**, with no AnimationPlayer yet. A placeholder slash shape (Polygon2D arc) is visible during the active phase.
- Air attacks **do not stop momentum**. Ground attacks apply a small forward lunge.
- Facing can change between combo hits, but not during a hit.

### 4.2 Ground combo (3 hits)

| | dmg | startup | active | recovery | lunge | enemy knockback | hitstop | shake |
|---|---|---|---|---|---|---|---|---|
| Hit 1 | 1 | 0.03 | 0.07 | 0.10 | 70 px | 280 | 0.035 s | 0.10 |
| Hit 2 | 1 | 0.03 | 0.07 | 0.10 | 70 px | 280 | 0.035 s | 0.10 |
| Hit 3 (finisher) | 2 | 0.05 | 0.09 | 0.18 | 100 px | 520 | 0.06 s | 0.22 |

- An attack pressed during the active or recovery phase is **buffered** into the next hit.
- If no input arrives within 0.15 s after recovery ends, the combo resets (lenient, so combos flow while moving).
- Dash **and jump** can cancel **recovery** at any time. That is the escape hatch.
- Air attacks: dmg 1, startup 0.02, active 0.08, recovery 0.10, and 0.22 s between air attacks.

### 4.3 Hit reactions (positioning)

- **Attacker recoil:** a side hit on an enemy pushes the player back 120 px/s (light, so you stay in the fight), so the player has to keep re-engaging. An up-slash hit gives no recoil.
- **Pogo:** a down slash hitting an enemy or a hazard sets `velocity.y = -jump_velocity × 0.85` and refreshes the dash. Holding or releasing jump does not cut a pogo.

### 4.4 Player damage

| Param | Value |
|---|---|
| max_hp | 5 |
| contact damage from enemies/hazards | 1 |
| hurt knockback | x 340 away from the source, y −420 |
| hurt stun (no control) | 0.25 s |
| invincibility after hurt | 1.0 s (the sprite flickers) |
| hitstop / shake on hurt | 0.10 s / 0.5 |
| hazard (spikes) | 1 damage, then teleport to the last safe ground position |
| death | 0.4 s freeze → respawn at the spawn point with full HP, and enemies reset |

### 4.5 Risk/reward mechanics

1. **Hit-to-refresh (core, always on).** Any attack that connects restores the air dash. An aggressive player can chain *dash → slash → dash* in the air. A passive player lands to recharge.
2. **Perfect dodge (toggle: `perfect_dodge_enabled`).** If an enemy attack or contact hitbox overlaps the player during the dash's invincibility window:
   - 0.25 s of slow-mo (time_scale 0.3) plus a colour flash on the player;
   - the dash charge is refunded;
   - the next attack within 1.0 s deals **+1 damage** and uses finisher hitstop and shake.

   Risk: dashing *through* the enemy instead of away from it.

## 5. Game feel system (global)

| Feature | Implementation |
|---|---|
| Hitstop | `GameFeel.hitstop(duration)` sets `Engine.time_scale = 0`, restored by a timer that ignores time scale. Overlapping requests keep the **longest**; they do not stack. |
| Slow-mo | `GameFeel.slow_mo(scale, duration)`, same timer approach |
| Screen shake | Trauma-based: shake = trauma² × max_offset, using FastNoiseLite and decaying at about 1.5/s. Runs on **unscaled** time so it plays during hitstop. Requested via `Events.camera_shake_requested(trauma)` |
| Hit flash | Enemy modulate goes to pure white for 0.08 s |
| Hit sparks | CPUParticles2D one-shot at the hit point, pointed in the attack direction |
| Death burst | Larger CPUParticles2D burst plus a short squash of the rectangle before `queue_free` |
| Squash & stretch | Player visual scales to (0.8, 1.2) on jump and (1.2, 0.8) on land, easing back in 0.1 s. Visual node only, never the collision |

## 6. Enemies

### 6.1 Walker (red rectangle, 56 × 72 px)

States: **Patrol → Chase → Hurt → Dead**

| Param | Value |
|---|---|
| hp | 3 |
| patrol_speed / chase_speed | 90 / 160 px/s |
| aggro_range / lose_range | 520 / 800 px (horizontal distance, same rough height) |
| turns at ledges and walls | yes (RayCast2D ledge check) |
| contact damage | 1, and **stays active while stunned** (a risk to the player) |
| hurt | knockback per AttackData, 0.30 s stun, white flash |
| death | hitstop 0.08 s, shake 0.35, death burst, emits `Events.enemy_killed` |

### 6.2 Training dummy

- Infinite HP. It flashes, wobbles and shows the damage number briefly (a floating Label).
- It never deals damage. It is for testing combo timing and feel.

## 7. Playground layout (about 3 screens wide, 64 px grid)

```
 [Spawn] [Dummy]   [Stair platforms]  [Wall-jump shaft]  [Gap]  [Spike pit]   [Arena: 2 platforms, 3 walkers]
 ════════════════  ▄▄    ▄▄    ▄▄     ║     ║           ═══     ═▲▲▲▲═         ═══════════════════════════════
```

- **Start zone:** flat floor, player spawn, training dummy.
- **Stairs:** 3 one-tile-thick platforms at 2, 4 and 6 tiles high. These test jump height and variable jump.
- **Wall-jump shaft:** two walls 4 tiles apart, 10 tiles tall, with a ledge at the top.
- **Gap:** 7 tiles wide. It needs a jump plus the dash.
- **Spike pit:** 4 tiles of spikes. It tests the pogo and the hazard respawn.
- **Arena:** a flat area, 20 tiles wide, with 2 floating platforms and 3 walkers. `debug_reset` respawns the walkers.
- **Kill plane** below the whole map counts as a hazard.
- **Geometry:** StaticBody2D + CollisionShape2D + ColorRect for the greybox, with no TileMap yet. This is simpler for the MCP; switch to TileMapLayer later.

## 8. Camera

- Camera2D in its own scene. It follows the player with position smoothing (speed about 8).
- **Look-ahead:** offsets toward the facing direction by about 120 px, easing in over 0.3 s.
- A vertical drag margin stops small jumps from bobbing the camera.
- Shake is added on top as an offset.
- Level limits are set from the playground bounds.

## 9. Debug overlay (F1)

Shows the current player state, velocity, on_floor/on_wall, dash charges, HP, combo step, time_scale and FPS. It must be built **in code** as a VBoxContainer of Labels, with no complex UI layout.

## 10. Out of scope for this prototype

Final art, animation, sound (optional placeholder beeps at most), menus, saving, multiple rooms, ability unlocks, enemy variety, bosses, and a UI HUD beyond the debug overlay.

## 11. Open questions to decide after playtesting

1. Should the dash be **horizontal or 8-way**? Test both with the toggle.
2. Should enemy contact damage stay on during the enemy's stun?
3. Is the perfect dodge fun, or does it add noise?
4. Does hitstop still feel impactful at these short Dead Cells-style durations, or does it need to be longer?
5. Does this game want a resource (e.g. hits build "Edge" meter for a special)? Decide in the next phase.
