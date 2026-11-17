# Prototype Design Spec — Combat Playground v0.3

> Source of truth for the prototype. Every number here is a **starting value**. All of them live in `.tres` resources so you can tune them in the Inspector. Expect to change most of them after playtesting; that is the point of the prototype.

## Changes since v0.2

v0.3 documents the prototype as built and tuned. Nothing here is a new request; it records what the game does now.

- **Movement retuned (3.1–3.4):** faster run (780), slower accelerations, higher jump (270 px, 0.29 s) with much heavier falling (×3.7), lower max fall speed (1300), longer dash (400 px over 0.18 s) that is invincible for its whole length.
- **Double jump added (3.2b):** one air jump, refreshed by landing or touching a wall.
- **Combat tuning (4.2, 4.3, 4.5):** air attacks 0.22 s apart (was 0.25), side-hit recoil 20 px/s (was 120), perfect-dodge slow-mo 0.413 (was 0.3).
- **Behaviour that v0.2 left open is now written down:** wall jump rules, ground dash cooldown vs air charges, swing angles, slam hit feel, hazards and safe ground, how hits interrupt actions, walker awareness, knockback directions.
- **Playground (7):** the first stair platform and the right shaft wall were moved by hand; their real positions are listed.
- **Debug overlay (9):** not built yet. F1 is bound but does nothing.

## 1. Design pillars

1. **Responsive first.** The player never fights the controls. Input forgiveness (coyote time, buffering) is invisible but always there.
2. **Low commitment, high tempo.** Attacks are fast and commit you only briefly (Dead Cells pace). Dash and jump are escape hatches, and the dash can be cancelled into an attack.
3. **Aggression is rewarded.** Landing hits keeps you mobile: a hit refreshes the dash. Playing safe is allowed but slower.
4. **Nimble hero, heavy sword.** The character moves light and fast; the sword carries the weight. Power comes from wide arcs, big knockback, hitstop, shake and particles, not from slow controls. Every hit is felt, scaled by how important it is.
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
| debug_overlay | F1 | — (not used yet, see 9) |

Attack aiming uses a stricter threshold: vertical input counts only when |y| > 0.5. In practice this only decides the slam (down + attack in the air).

## 3. Movement

### 3.1 Run

| Param | Value |
|---|---|
| max_run_speed | 780 px/s |
| ground_accel | 6000 px/s² (full speed in about 0.13 s) |
| ground_decel | 6000 px/s² |
| turn_accel | 9000 px/s² (used while reversing on the ground, until velocity crosses zero) |
| air_accel / air_decel | 3600 / 2400 px/s² |

- Facing flips instantly with input. There is no turn-around animation lock.
- Input is digital: a stick past the deadzone gives full speed.
- Above max_run_speed (e.g. after a dash-jump), holding forward bleeds speed off at the decel rate rather than braking hard.

### 3.2 Jump (height-and-time based, so it is designer-friendly)

| Param | Value |
|---|---|
| jump_height | 270 px (about 4.2 tiles) |
| time_to_apex | 0.29 s |
| → derived gravity | `2h / t²` ≈ 6420 px/s² |
| → derived jump_velocity | `2h / t` ≈ 1860 px/s (plus half a frame of gravity, so the real peak matches jump_height at 60 Hz) |
| fall_gravity_multiplier | 3.7 (falls much faster than it rises) |
| jump_cut_multiplier | 0.4 (releasing jump early multiplies upward velocity by this) |
| apex_hang_threshold / multiplier | when \|vy\| < 80 → gravity × 0.6 (brief float at the top, for air control) |
| max_fall_speed | 1300 px/s |
| coyote_time | 0.10 s (can still jump after leaving a ledge) |
| jump_buffer | 0.12 s (a jump pressed just before landing still fires) |

### 3.2b Double jump

| Param | Value |
|---|---|
| air_jumps | 1 (0 turns the double jump off) |
| double_jump_height | 220 px (launch speed `√(2·g·h)` ≈ 1680 px/s) |
| refreshes on | landing, or touching a wall (same rule as the air dash) |

- Jump priority: ground or coyote jump first, then wall jump, then the double jump. Coyote time and walls never use up the air jump.
- The jump cut applies to the double jump too.
- Hits do **not** refresh the air jump; only the dash refreshes on hit.

### 3.3 Wall slide and wall jump

- A wall slide starts when airborne, falling, touching a wall (RayCast2D check, 4 px beyond the body) **and** holding toward it.
- A wall jump works whenever the player is airborne and touching a wall (or within wall coyote time), not only while sliding. This lets the player chain wall jumps up a shaft while still rising.
- There is no wall climbing.

| Param | Value |
|---|---|
| wall_slide_max_speed | 260 px/s |
| wall_jump_velocity | x 580 away from the wall, y = jump_velocity × 0.95 |
| wall_jump_input_lock | 0.14 s (holding toward the wall cannot cancel the push-off) |
| wall_coyote_time | 0.08 s (not refreshed during the push-off lock, so one press can't wall jump twice) |

### 3.4 Dash (combat dodge + mobility)

| Param | Value |
|---|---|
| dash_distance | 400 px |
| dash_duration | 0.18 s (speed ≈ 2220 px/s) |
| dash_direction_mode | `HORIZONTAL` (default) or `EIGHT_WAY`; a toggle in PlayerStats for A/B testing |
| air_dash_charges | 1 |
| ground_dash_cooldown | 0.22 s |
| invincibility window | first 0.22 s of the dash, which is longer than the dash itself, so the whole dash is invincible |
| gravity during dash | off (fixed height) |
| exit speed | clamped to max_run_speed in the dash direction (keeps momentum without being too fast) |
| attack cancel | allowed from 0.04 s into the dash |
| jump cancel (ground dash only) | allowed, and keeps horizontal dash speed for that jump ("dash-jump" tech) |

- Ground dashes are limited only by the cooldown; only air dashes use the charge.
- `HORIZONTAL`: dashes the way the player holds, or faces. `EIGHT_WAY`: the stick direction snapped to 8 directions; down on the ground becomes a horizontal dash.
- An air dash aimed into a wall the player is touching flips away from the wall (useful out of a wall slide).
- Visual: 3 fading afterimages along the dash.

**The dash charge refreshes on:** landing, touching a wall, and **landing any attack on an enemy** (including the slam).

## 4. Combat

### 4.1 Attack directions

| Input when attack pressed | Grounded | Airborne |
|---|---|---|
| none / left / right | ground combo hit (forward) | air side slash |
| up | forward (ground combo); the wide arc already covers above the head | air side slash |
| down | forward (ground combo) | **ground slam** (see 4.3b) |

There is **no separate up attack and no pogo.**

- Attack timing uses phases: startup → active (hitbox on) → recovery. In the prototype this is **driven by code from AttackData**, with no AnimationPlayer yet.
- Air attacks **do not stop momentum**. Ground attacks apply a forward lunge and otherwise stand still (no walking during a ground attack).

### 4.1b The big-sword swing

- **Placeholder sword:** a 150 × 18 px rectangle pivoting from the shoulder (20 px above the player's centre), visible at all times. While idle it rests down and back (120°, where 0° = ahead and 90° = straight down).
- **Swing phases** follow the AttackData timing:
  - *startup* = wind-up: the sword pulls back 30–35° behind where the sweep starts;
  - *active* = a fast sweep through the arc, with a crescent-shaped slash trail (Polygon2D, 50 % opacity) that fades over 0.1 s after the active phase;
  - *recovery* = follow-through: the sword eases back to rest. A cancel settles it back in 0.1 s.
- **Hitbox:** one crescent covering the whole arc, on only during *active*. It is built from the same polygon as the trail, so it always matches what you see. It reaches **180 px** in front of the player's centre and about **150 px above** it (slightly behind the head), and is cut off flat at the player's feet.
- **Combo swing directions** (sword angle, 0° = ahead, −90° = up, +90° = down):
  - Hit 1: high → low, −100° to 75°;
  - Hit 2: low → high, 75° to −100°;
  - Hit 3 (finisher): big overhead arc, −135° to 75°, reach 210 px;
  - Air side slash: the same arc as Hit 1.
- Facing can change between combo hits, but not during a hit.

### 4.2 Ground combo (3 hits)

| | dmg | startup | active | recovery | lunge | enemy knockback | hitstop | shake |
|---|---|---|---|---|---|---|---|---|
| Hit 1 | 1 | 0.04 | 0.08 | 0.12 | 70 px | 340 | 0.045 s | 0.12 |
| Hit 2 | 1 | 0.04 | 0.08 | 0.12 | 70 px | 340 | 0.045 s | 0.12 |
| Hit 3 (finisher) | 2 | 0.08 | 0.10 | 0.22 | 110 px | 600 | 0.08 s | 0.30 |

- An attack pressed during the active or recovery phase is **buffered** into the next hit (presses during startup are ignored).
- A general attack buffer of 0.12 s also catches presses made just before an attack is possible (e.g. just before a dash can be attack-cancelled).
- If no input arrives within 0.15 s after recovery ends, the combo resets (lenient, so combos flow while moving).
- Dash **and jump** can cancel **recovery** at any time. That is the escape hatch. A dash pressed during startup or active fires as soon as recovery starts.
- Air side slash: dmg 1, startup 0.03, active 0.09, recovery 0.12, knockback 340, hitstop 0.045 s, shake 0.12, and 0.22 s between the starts of air attacks.
- Each swing hits a given target at most once.

### 4.3 Hit reactions (positioning)

- **Attacker recoil:** every sword hit that connects pushes the player back 20 px/s, so the player stays in the fight.
- **Knockback direction:** sword swings push the target in the player's **facing** direction. The slam impact pushes targets **away from the player's position**, whichever side they are on.

### 4.3b Ground slam (down + attack while airborne)

A committed, powerful move. The reward is a hit in both directions; the risk is the landing recovery.

| Phase | Behaviour | Value |
|---|---|---|
| Wind-up | The player freezes in the air (velocity 0), with the sword raised overhead | 0.07 s |
| Plunge | Straight down at a fixed speed, with no horizontal control. A 60 × 48 px hitbox under the player damages enemies it passes through; the sword points down | 1800 px/s, 1 dmg, no knockback, on hit: hitstop 0.045 s / shake 0.12 |
| Impact | On landing: a shockwave hitbox at the feet, extending both ways, on for 0.06 s | 360 × 80 px total (180 px each side), 2 dmg |
| Impact knockback | Enemies are pushed **away from the player** and slightly up | x 450, y −300 |
| Impact feel | Always: shake 0.35 plus a dust burst both ways, even if nothing is hit. On hit: hitstop 0.08 s | |
| Landing recovery | The player cannot act | 0.22 s; dash can cancel only after the first 0.12 s (a press slightly earlier is remembered) |

- The plunge cannot be cancelled by the player. A slam over a pit keeps falling until the kill plane.
- No invincibility during the slam. Taking a hit interrupts the slam at any phase (see 4.4).
- Each target can take at most one plunge hit and one impact hit per slam.
- A connected slam refreshes the dash, like any hit.
- Spikes are a hazard only; nothing bounces off them.

### 4.4 Player damage

| Param | Value |
|---|---|
| max_hp | 5 |
| contact damage from enemies/hazards | 1 |
| hurt knockback | x 340 away from the source, y −420 |
| hurt stun (no control) | 0.25 s |
| invincibility after hurt | 1.0 s (the sprite flickers) |
| hitstop / shake on hurt | 0.10 s / 0.5 |
| hazards (spikes, kill plane) | 1 damage, then teleport to the last safe ground position, with no knockback |
| death | 0.4 s freeze → respawn at the spawn point with full HP, and enemies reset |

- Getting hurt interrupts whatever the player is doing (attack, slam, wall slide…).
- Contact damage and hazards keep hurting while you overlap them; only invincibility protects you, so standing inside an enemy hurts again when the 1.0 s runs out.
- **Safe ground** is the last spot where the player stood with floor directly under their centre and no hazard within about 86 px sideways (or below the feet, e.g. a spike pit).
- After any teleport (hazard or respawn) the player ignores hits for 2 physics frames, so stale overlaps from the old position can't hurt them.
- `debug_reset` (R) respawns the player and resets all enemies.

### 4.5 Risk/reward mechanics

1. **Hit-to-refresh (core, always on).** Any attack that connects restores the air dash. An aggressive player can chain *dash → slash → dash* in the air. A passive player lands to recharge.
2. **Perfect dodge (toggle: `perfect_dodge_enabled`, on).** If an enemy attack or contact hitbox overlaps the player during the dash's invincibility window:
   - 0.25 s (real time) of slow-mo at time_scale 0.413, plus a cyan flash on the player (0.15 s);
   - the dash charge is refunded, and the ground dash cooldown is cleared;
   - the next attack within 1.0 s deals **+1 damage** and uses finisher hitstop and shake (taken from combo Hit 3). A slam uses the bonus on both its hits. A pulsing cyan outline shows while the bonus is ready.
   - It triggers at most once per dash, and never from hazards (spikes, kill plane) or post-hurt invincibility.

   Risk: dashing *through* the enemy instead of away from it.

## 5. Game feel system (global)

| Feature | Implementation |
|---|---|
| Hitstop | `GameFeel.hitstop(duration)` sets `Engine.time_scale = 0`, restored by a timer that ignores time scale. Overlapping requests keep the **longest**; they do not stack. All gameplay timers (coyote, buffers, cooldowns, combo window, invincibility) pause during hitstop. |
| Slow-mo | `GameFeel.slow_mo(scale, duration)`, same timer approach. Hitstop wins over slow-mo while both are active. |
| Screen shake | Trauma-based: shake = trauma² × max_offset (48 × 36 px), using FastNoiseLite and decaying at 1.5/s. Runs on **unscaled** time so it plays during hitstop. Requested via `Events.camera_shake_requested(trauma)` |
| Hit flash | Enemy body turns pure white for 0.08 s (held through hitstop) |
| Hit sparks | CPUParticles2D one-shot on the target, aimed along the swing (forward and down for high→low swings, forward and up for low→high, outward for the slam impact, down for the plunge) |
| Death burst | Larger CPUParticles2D burst in the enemy's colour, plus a squash of the rectangle to (1.5, 0.35) over 0.1 s before `queue_free` |
| Squash & stretch | Player visual scales to (0.8, 1.2) on any jump (ground, wall, double) and (1.2, 0.8) on landing, easing back in 0.1 s. Visual node only, never the collision |

## 6. Enemies

### 6.1 Walker (red rectangle, 56 × 72 px)

States: **Patrol → Chase → Hurt → Dead**

| Param | Value |
|---|---|
| hp | 3 |
| patrol_speed / chase_speed | 90 / 160 px/s |
| aggro_range / aggro_height | starts chasing within 520 px horizontally and 120 px vertically |
| lose_range / lose_height | gives up beyond 800 px horizontally or 300 px vertically |
| turns at ledges and walls | yes while patrolling (RayCast2D ledge and wall checks); while chasing it stops at a ledge or wall instead |
| contact damage | 1 (contact box 48 × 64 px), and **stays active while stunned** (a risk to the player) |
| hurt | knockback per AttackData (see 4.3), 0.30 s stun (each new hit restarts it), white flash, knockback slows at 1400 px/s² |
| death | hitstop 0.08 s, shake 0.35, death burst, emits `Events.enemy_killed`, squash, removed |
| gravity / max fall speed | 4000 px/s² / 1500 px/s |

- Walkers are placed under an EnemySpawner node, which rebuilds them at their starting positions whenever the player respawns.

### 6.2 Training dummy

- Infinite HP. It flashes, wobbles and shows the damage number briefly (a floating Label).
- It never deals damage. It is for testing combo timing and feel.

## 7. Playground layout (about 3 screens wide, 64 px grid)

```
 [Spawn] [Dummy]   [Stair platforms]  [Wall-jump shaft]  [Gap]  [Spike pit]   [Arena: 2 platforms, 3 walkers]
 ════════════════  ▄▄    ▄▄    ▄▄     ║     ║           ═══     ═▲▲▲▲═         ═══════════════════════════════
```

The floor surface is at y = 0; heights below are above the floor.

- **Start zone:** flat floor, player spawn (x 192), training dummy (x 704).
- **Stairs:** 3 one-tile-thick platforms, 3 tiles wide. Platform 1 has been moved by hand: x 1052–1244 at about 3.6 tiles high (228 px), off the grid. Platforms 2 and 3 are at 4 and 6 tiles high (x 1472 and 1792).
- **Wall-jump shaft:** left wall x 2176–2240, from 3 to 10 tiles high (you walk in underneath). The right wall has been moved by hand: x 2490–2618, from about 195 px to 835 px high. It no longer reaches the floor, so the shaft can be walked through underneath. A ledge sits at x 2624–2816, 10 tiles high.
- **Gap:** 7 tiles wide (x 2944–3392). It needs a jump plus the dash.
- **Spike pit:** 4 tiles of spikes (x 3584–3840), one tile below the floor. It tests jump/dash precision and the hazard respawn.
- **Arena:** floor x 3840–5376, 2 floating platforms 3 tiles high (x 4288 and 4928, 4 tiles wide), 3 walkers (x 4160, 4736, 5248). `debug_reset` respawns the walkers.
- **Kill plane** at y = 512 below the whole map counts as a hazard.
- **Geometry:** StaticBody2D + CollisionShape2D + ColorRect for the greybox, with no TileMap yet. This is simpler for the MCP; switch to TileMapLayer later.

## 8. Camera

- Camera2D in its own scene. It follows the player with position smoothing (speed 8).
- **Look-ahead:** about 120 px toward the facing direction, easing in over 0.3 s. It is part of the followed position, so the level limits still clamp it.
- A vertical drag margin (top 0.3, bottom 0.1) stops small jumps from bobbing the camera while falls are followed quickly.
- Shake is added on top as an offset.
- Level limits: x −128 to 5504, y −1024 to 384.
- On respawn the camera cuts to the player instead of panning.

## 9. Debug overlay (F1) — not built yet

Planned: shows the current player state, velocity, on_floor/on_wall, dash charges, HP, combo step, time_scale and FPS. It must be built **in code** as a VBoxContainer of Labels, with no complex UI layout. The F1 action exists in the input map but nothing uses it yet.

## 10. Out of scope for this prototype

Final art, animation, sound (optional placeholder beeps at most), menus, saving, multiple rooms, ability unlocks, enemy variety, bosses, and a UI HUD beyond the debug overlay.

## 11. Open questions to decide after playtesting

1. Should the dash be **horizontal or 8-way**? Test both with the toggle.
2. Should enemy contact damage stay on during the enemy's stun?
3. Is the perfect dodge fun, or does it add noise?
4. Does hitstop still feel impactful at these short Dead Cells-style durations, or does it need to be longer?
5. Does the slam's landing recovery feel fair, or punishing?
6. Does the wide arc make spacing too easy? If so, shrink the reach before adding enemies that punish it.
7. Does this game want a resource (e.g. hits build "Edge" meter for a special)? Decide in the next phase.
8. With the dash now invincible for its whole length (0.22 s window vs 0.18 s dash), is the perfect dodge too easy to trigger?
9. Does the double jump make the stairs, gap and shaft too easy? They were designed without it.
