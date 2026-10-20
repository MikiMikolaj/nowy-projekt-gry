# Prototype Design Spec — Combat Playground v0.2

> Source of truth for the prototype. Every number here is a **starting value**. All of them live in `.tres` resources so you can tune them in the Inspector. Expect to change most of them after playtesting; that is the point of the prototype.

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
| debug_overlay | F1 | — |

Attack direction uses a stricter threshold: vertical input counts as "aiming" only when |y| > 0.5. This stops accidental up/down slashes on a stick.

## 3. Movement

### 3.1 Run

| Param | Value |
|---|---|
| max_run_speed | 580 px/s |
| ground_accel | 7500 px/s² (full speed in about 0.08 s) |
| ground_decel | 8000 px/s² |
| turn_accel | 10000 px/s² (reversing direction is extra snappy) |
| air_accel / air_decel | 4200 / 2800 px/s² |

- Facing flips instantly with input. There is no turn-around animation lock.

### 3.2 Jump (height-and-time based, so it is designer-friendly)

| Param | Value |
|---|---|
| jump_height | 240 px (about 3.75 tiles) |
| time_to_apex | 0.30 s (same height, reached faster, so the jump is snappier) |
| → derived gravity | `2h / t²` ≈ 5330 px/s² |
| → derived jump_velocity | `2h / t` ≈ 1600 px/s |
| fall_gravity_multiplier | 2.0 (falls much faster than it rises, so the character gets back to the ground quickly) |
| jump_cut_multiplier | 0.4 (releasing jump early multiplies upward velocity by this) |
| apex_hang_threshold / multiplier | when \|vy\| < 80 → gravity × 0.6 (brief float at the top, for air control) |
| max_fall_speed | 1500 px/s |
| coyote_time | 0.10 s (can still jump after leaving a ledge) |
| jump_buffer | 0.12 s (a jump pressed just before landing still fires) |

### 3.3 Wall slide and wall jump

- A wall slide starts when airborne, falling, touching a wall (RayCast2D check) **and** holding toward it.
- There is no wall climbing and no double jump.

| Param | Value |
|---|---|
| wall_slide_max_speed | 260 px/s |
| wall_jump_velocity | x 580 away from the wall, y = jump_velocity × 0.95 |
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

**The dash charge refreshes on:** landing, touching a wall, and **landing any attack on an enemy** (including the slam).

## 4. Combat

### 4.1 Attack directions

| Input when attack pressed | Grounded | Airborne |
|---|---|---|
| none / left / right | ground combo hit (forward) | air side slash |
| up | forward (ground combo); the wide arc already covers above the head | air side slash |
| down | forward (ground combo) | **ground slam** (see 4.3) |

There is **no separate up attack and no pogo.**

- Attack timing uses phases: startup → active (hitbox on) → recovery. In the prototype this is **driven by code from AttackData**, with no AnimationPlayer yet. A placeholder slash shape (Polygon2D arc) is visible during the active phase.
- Air attacks **do not stop momentum**. Ground attacks apply a forward lunge.

### 4.1b The big-sword swing

- **Placeholder sword:** a long rectangle (about 150 × 18 px) pivoting from the player's shoulder, visible at all times. While idle it rests angled down and back.
- **Swing phases** follow the AttackData timing:
  - *startup* = wind-up: the sword pulls back behind the player;
  - *active* = a fast sweep through the arc, with a crescent-shaped slash trail (Polygon2D) that fades over about 0.1 s;
  - *recovery* = follow-through: the sword eases back to rest.
- **Hitbox:** one wide crescent covering the whole arc, on only during *active*. It reaches about **180 px** in front of the player's centre. Vertically it covers from about **150 px above** the player's centre (well above the head, and slightly behind it) down to the player's feet. Hitbox shape must match the visible trail.
- **Combo swing directions** alternate so the combo looks like a heavy sword, not a stab:
  - Hit 1: diagonal slash from high to low;
  - Hit 2: rising return slash from low to high;
  - Hit 3 (finisher): a big overhead arc with a larger trail and slightly longer reach (about 210 px).
- Facing can change between combo hits, but not during a hit.

### 4.2 Ground combo (3 hits)

| | dmg | startup | active | recovery | lunge | enemy knockback | hitstop | shake |
|---|---|---|---|---|---|---|---|---|
| Hit 1 | 1 | 0.04 | 0.08 | 0.12 | 70 px | 340 | 0.045 s | 0.12 |
| Hit 2 | 1 | 0.04 | 0.08 | 0.12 | 70 px | 340 | 0.045 s | 0.12 |
| Hit 3 (finisher) | 2 | 0.08 | 0.10 | 0.22 | 110 px | 600 | 0.08 s | 0.30 |

- An attack pressed during the active or recovery phase is **buffered** into the next hit.
- If no input arrives within 0.15 s after recovery ends, the combo resets (lenient, so combos flow while moving).
- Dash **and jump** can cancel **recovery** at any time. That is the escape hatch.
- Air side slash: same wide arc as Hit 1. dmg 1, startup 0.03, active 0.09, recovery 0.12, and 0.25 s between air attacks.

### 4.3 Hit reactions (positioning)

- **Attacker recoil:** a side hit on an enemy pushes the player back 120 px/s (light, so you stay in the fight), so the player has to keep re-engaging. An up-slash hit gives no recoil.

### 4.3b Ground slam (down + attack while airborne)

A committed, powerful move. The reward is a hit in both directions; the risk is the landing recovery.

| Phase | Behaviour | Value |
|---|---|---|
| Wind-up | The player freezes in the air (velocity 0), with the sword raised overhead | 0.07 s |
| Plunge | Straight down at a fixed speed, with no horizontal control. A small hitbox under the player damages enemies it passes through | 1800 px/s, 1 dmg |
| Impact | On landing: a shockwave hitbox at the feet, extending both ways | about 360 × 80 px total (180 px each side), 2 dmg |
| Impact knockback | Enemies are pushed **away from the player** and slightly up | x 450, y −300 |
| Impact feel | Always: shake 0.35 plus a dust burst both ways, even if nothing is hit. On hit: hitstop 0.08 s | |
| Landing recovery | The player cannot act | 0.22 s; dash can cancel only after the first 0.12 s |

- The plunge cannot be cancelled. A slam over a pit keeps falling until the kill plane.
- No invincibility during the slam.
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
- **Spike pit:** 4 tiles of spikes. It tests jump/dash precision and the hazard respawn.
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
5. Does the slam's landing recovery feel fair, or punishing?
6. Does the wide arc make spacing too easy? If so, shrink the reach before adding enemies that punish it.
7. Does this game want a resource (e.g. hits build "Edge" meter for a special)? Decide in the next phase.
