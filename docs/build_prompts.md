# Build Prompts — Combat Playground Prototype

Paste **one stage at a time** into Claude Code. After each one:

1. playtest it;
2. commit to git;
3. only then move on.

If something feels wrong, fix it before moving on. Don't pile stages on a broken base.

---

## Stage 0 — Project foundation

```
Read CLAUDE.md and docs/prototype_design.md fully before doing anything.

We are starting Stage 0: project foundation. Do NOT build any gameplay yet.

1. Initialise git in the project root. Add a Godot 4 .gitignore that ignores .godot/ and keeps .import and .uid files. Make an initial commit.
2. Create the full folder structure from CLAUDE.md. Put a .gitkeep in any empty folder.
3. Project settings (use the MCP project-settings tools):
   - display: 1920x1080, stretch mode canvas_items, aspect expand
   - physics interpolation ON
   - 2D physics layer names exactly as in the CLAUDE.md table
   - the full input map from spec section 2, keyboard AND gamepad bindings, stick deadzone 0.25
4. Create the autoloads and register them:
   - autoload/events.gd (Events) with signals: camera_shake_requested(trauma: float), player_died, player_respawned, enemy_killed(enemy: Node)
   - autoload/game_feel.gd (GameFeel) with hitstop(duration) and slow_mo(scale, duration), implemented exactly as in spec section 5 (longest request wins, timers ignore time scale)
5. Create the core building blocks in core/ as scripts only (no scenes yet), each with class_name and typed code:
   - state_machine/state.gd and state_machine/state_machine.gd (node-based FSM: enter(), exit(), physics_update(delta), update(delta), handle_input(event), transition_to(state_name))
   - combat/attack_data.gd (Resource: damage, startup, active, recovery, lunge, knockback, hitstop, shake, direction enum)
   - combat/health_component.gd (max_hp, current_hp, invincible flag, signals damaged(amount, source) and died)
   - combat/hitbox.gd (Area2D, holds AttackData, owner reference, enable()/disable())
   - combat/hurtbox.gd (Area2D, forwards hits to a HealthComponent, emits hit_received(hitbox))
6. Move docs: make sure prototype_design.md and build_prompts.md are inside res://docs/.
7. Create an empty levels/playground/playground.tscn (Node2D root) and set it as the main scene.

Finish by running the project via MCP, reading errors, fixing them, and giving me a short plain-language summary. Suggest a commit message.
```

---

## Stage 1 — Core movement + greybox playground + camera

```
Read CLAUDE.md and docs/prototype_design.md sections 2, 3.1, 3.2, 7 and 8.

Stage 1: the player can run and jump in the greybox playground with a following camera.

1. entities/player/player_stats.gd: a PlayerStats Resource with EVERY movement value from spec 3.1–3.4 as @export vars, grouped with @export_group. Compute derived gravity and jump_velocity from jump_height and time_to_apex. Create player_stats.tres with the spec values.
2. entities/player/player.tscn (CharacterBody2D, layer player_body, mask world):
   Visual (Node2D, contains a 44x96 ColorRect placeholder plus a small "eye" rect showing facing), CollisionShape2D 44x96, StateMachine with states Idle, Run, Jump, Fall.
   player.gd holds shared helpers: apply_gravity(delta) (with fall multiplier, apex hang, max fall), apply_horizontal(delta, accel, decel), and the coyote and jump-buffer timers. The states call these.
   Implement variable jump height (jump cut), coyote time, jump buffer, and turn_accel exactly as specced.
   Add squash & stretch on the Visual node for jump and land (spec section 5).
3. camera/game_camera.tscn + .gd: follow the player with smoothing, facing look-ahead, vertical drag margin, and process callback Physics. Include the trauma-based shake (unscaled time) listening to Events.camera_shake_requested, even though nothing triggers it yet.
4. Build the playground greybox exactly as in spec section 7, using StaticBody2D + CollisionShape2D + ColorRect blocks on the 64 px grid. Make a reusable levels/playground/block.tscn with an exported size so blocks are easy to add and resize. Leave the spike pit, dummy and walkers as empty marker nodes (Marker2D) named for later stages. Add a PlayerSpawn Marker2D. Set camera limits to the level bounds.
5. Instance the player and camera in playground.tscn.

Run the playground, fix all errors, and summarise. Tell me exactly which values in player_stats.tres to tweak if the jump feels floaty or heavy.
```

---

## Stage 2 — Wall slide, wall jump, dash

```
Read CLAUDE.md and docs/prototype_design.md sections 3.3 and 3.4.

Stage 2: add wall mechanics and the dash to the player.

1. Add two RayCast2D wall checks (left/right) to the player. Add the states WallSlide and Dash.
2. Wall slide / wall jump exactly per spec 3.3, including the input lock and wall coyote time.
3. Dash per spec 3.4:
   - HORIZONTAL and EIGHT_WAY modes via a PlayerStats enum toggle; in HORIZONTAL mode, dash in the facing direction
   - no gravity during the dash, the exit speed clamp, and the ground cooldown
   - 1 air charge, refreshed on landing and on wall touch (make a single refresh_dash() method that later stages will also call)
   - invincibility for the first 0.12 s (for now just set a player flag is_invincible; the hurtbox arrives in Stage 3)
   - a jump cancel out of a ground dash that keeps horizontal speed
   - add a simple visual: 3 fading afterimage copies of the placeholder rect
4. Leave a clearly marked hook in Dash for "attack cancel after 0.04 s". The attack state is built in Stage 3.

Run, fix errors, and summarise. Tell me how to flip the dash direction mode to test both.
```

---

## Stage 3 — Combat framework + directional attacks + training dummy

```
Read CLAUDE.md and docs/prototype_design.md sections 4.1–4.3, 5 and 6.2.

Stage 3: the player can attack in all directions with a 3-hit ground combo, and hit a training dummy.

1. Create AttackData .tres files in entities/player/attacks/ for combo_1, combo_2, combo_3, air_side, up, down, with the exact spec values.
2. Player scene additions: a Hurtbox (layer player_hurtbox), a HealthComponent, and an AttackPivot (Node2D, flips with facing) containing HitboxSide, HitboxUp and HitboxDown (layer player_attack, mask enemy_hurtbox + enemy_attack). Give each a placeholder arc/slash Polygon2D that is only visible during the active phase.
3. Attack state (one state, driven by AttackData):
   - direction choice per the spec 4.1 table (aim threshold 0.5)
   - code-timed startup/active/recovery phases that enable the hitbox only during active
   - ground combo with input buffering and the 0.15 s reset window
   - lunge on ground hits; air attacks keep momentum; the air attack cooldown
   - dash and jump can cancel recovery; wire up the Stage 2 hook so dash can be cancelled into an attack
4. On a successful hit (hitbox connects with a hurtbox):
   - call GameFeel.hitstop, emit camera shake, and spawn effects/hit_spark.tscn (CPUParticles2D one-shot) at the contact point
   - apply attacker recoil (side hits), and pogo (down hits: bounce + refresh_dash)
   - refresh_dash() on ANY connected hit (spec 4.5.1)
   - each hit should only register ONCE per target per swing
5. entities/enemies/training_dummy: StaticBody2D-like dummy with a Hurtbox, infinite HP, white flash, a small wobble, and a floating damage number. Place it at the dummy marker.
6. Add spikes to the spike pit as an enemy_attack Hitbox that is pogo-able (down slash bounces off it). Player hurt from spikes comes in Stage 4, so for now spikes only need to be pogo-able.

Run, fix errors, and summarise. Tell me how to test the combo buffer, the dash-cancel and the pogo.
```

---

## Stage 4 — Walker enemy + player damage, death and respawn

```
Read CLAUDE.md and docs/prototype_design.md sections 4.4 and 6.1.

Stage 4: the first real enemy and the player taking damage.

1. entities/enemies/walker: CharacterBody2D red rectangle (56x72) with its own small state machine (Patrol, Chase, Hurt, Dead), WalkerStats resource + .tres, a Hurtbox, a HealthComponent, a contact Hitbox (enemy_attack), and a RayCast2D ledge check plus a wall check. Behaviour exactly per spec 6.1, including knockback from the AttackData, the stun, the white flash, and the death sequence (hitstop, shake, effects/death_burst.tscn, squash, queue_free, Events.enemy_killed).
2. Player damage per spec 4.4: add Hurt and Dead states, knockback away from the source, stun, 1.0 s invincibility with flicker, hitstop and shake. Ignore hits while is_invincible (dash i-frames or post-hurt).
3. Hazards: spikes and the kill plane deal 1 damage and teleport the player to the last safe ground position. The player tracks this: the last position where they were on the floor and not near a hazard.
4. Death: freeze, then respawn at PlayerSpawn with full HP; emit Events.player_died / player_respawned.
5. Place 3 walkers in the arena. debug_reset (R / Select) respawns all walkers and resets the player. Build this with an EnemySpawner node that remembers the initial enemy positions.

Run, fix errors, and summarise. Tell me the three stats most worth tweaking on the walker.
```

---

## Stage 5 — Risk/reward + game feel polish

```
Read CLAUDE.md and docs/prototype_design.md sections 4.5 and 5.

Stage 5: perfect dodge and the feel pass.

1. Perfect dodge per spec 4.5.2, behind the perfect_dodge_enabled toggle in PlayerStats: detect an enemy_attack overlap during dash i-frames, then trigger GameFeel.slow_mo, refund the dash, flash the player (cyan), and empower the next attack within 1.0 s (+1 damage, finisher hitstop and shake). Show a visual on the player while empowered (e.g. a glowing outline rect).
2. Audit that every item in the spec section 5 table exists and triggers correctly: hitstop per attack, shake per event, hit flash, sparks aimed along the attack direction, death burst, squash & stretch.
3. Make sure hitstop does not break any timers (coyote, buffer, combo window, invincibility). They should pause during hitstop, not tick through it.

Run, fix errors, and summarise.
```

---

## Stage 6 — Debug overlay + tuning pass

```
Read CLAUDE.md and docs/prototype_design.md section 9.

Stage 6: debug tools for tuning.

1. ui/debug_overlay: built in code (CanvasLayer + VBoxContainer + Labels), toggled with F1, showing everything listed in spec section 9.
2. Add a "Tuning" note at the top of player_stats.tres, walker_stats.tres and each AttackData explaining in one line what each value does (use @export hints/tooltips via ## doc comments).
3. Write docs/tuning_guide.md: a short beginner guide explaining how to tweak values live using the running game's Remote scene tree in the editor, and which values control "floaty vs heavy", "slippery vs tight", and "light vs impactful hits".

Run, fix errors, and summarise. Then list 5 things I should specifically test during my first 10-minute playtest.
```
