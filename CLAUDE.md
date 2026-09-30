# CLAUDE.md — Project rules for Claude Code

This file is read automatically at the start of every Claude Code session. Follow it strictly.

## Project

- **Game:** 2D action platformer. The mix is roughly 60% precision platforming plus melee combat, and 40% movement-first action. The feel is a hybrid of Celeste (snappy, precise) and Dead Cells (fast, aggressive combat).
- **Current phase:** combat-playground prototype. There is **no final art**; use placeholder shapes (ColorRect / Polygon2D) only.
- **Engine:** Godot **4.7.2**, **GDScript only**.
- **Design spec:** `docs/prototype_design.md` is the source of truth for all gameplay values and behaviour. If this file and the spec disagree, ask the user.
- **Developer:** new to Godot. Explain *what* you built and *where* it is in 3–6 plain sentences at the end of each task. Do not dump code in the summary.

## Tools: Godot MCP (tomyud1/godot-mcp)

- Use the Godot MCP tools to create scenes, add nodes, set properties, attach scripts, and run scenes.
- **Never hand-write or hand-edit `.tscn` / `.tres` files as raw text** unless an MCP tool cannot do it. If you must, tell the user first and run a filesystem rescan afterwards.
- The MCP is weak at complex UI layouts and deep scene composition. Therefore:
  - keep scene trees **shallow**, with at most about 3 levels;
  - prefer **small scenes instanced into bigger ones** over one giant scene;
  - if a layout or editor task is unreliable through MCP, stop and give the user short **manual editor steps** instead of guessing.
- If you are unsure an API exists in Godot 4.7, **query ClassDB through the MCP** instead of guessing from memory.
- **There is no undo.** Before any large change, remind the user to commit, or run `git add -A && git commit` yourself if they have allowed it.
- **After every task:** run the relevant scene through the MCP, read the Output/Debugger errors, fix them, and only then report done.

## Folder structure (feature-based)

```
res://
├── addons/godot_mcp/          # MCP plugin; never modify
├── autoload/                  # global singletons (keep tiny)
│   ├── events.gd              # Events: global signal bus
│   └── game_feel.gd           # GameFeel: hitstop + slow-mo requests
├── core/                      # reusable building blocks, no game-specific logic
│   ├── state_machine/         # state_machine.gd, state.gd
│   ├── combat/                # hitbox.gd, hurtbox.gd, health_component.gd, attack_data.gd
│   └── utils/
├── entities/
│   ├── player/
│   │   ├── player.tscn / player.gd
│   │   ├── player_stats.gd    # PlayerStats Resource class
│   │   ├── player_stats.tres  # all tunable numbers live HERE
│   │   ├── attacks/           # AttackData .tres files (combo_1, combo_2, ...)
│   │   └── states/            # one script per state
│   └── enemies/
│       ├── walker/            # walker.tscn, walker.gd, walker_stats.tres
│       └── training_dummy/
├── effects/                   # hit_spark.tscn, death_burst.tscn, ...
├── camera/                    # game_camera.tscn / .gd (follow, look-ahead, shake)
├── levels/
│   └── playground/            # playground.tscn (main scene for now)
├── ui/
│   └── debug_overlay/         # debug_overlay.tscn / .gd
├── art/                       # placeholder now, comic-style later
├── audio/
└── docs/                      # prototype_design.md and other design docs
```

## Code conventions

- Use **static typing everywhere**: `var speed: float = 0.0` and `func f(x: int) -> void:`.
- Files and folders are `snake_case`. Classes are `class_name PascalCase`. Constants are `UPPER_SNAKE`. Signals are past tense, e.g. `died` or `hit_landed`.
- **No magic numbers in gameplay code.** Every tunable value is an `@export` on a Resource (e.g. `PlayerStats`, `AttackData`, `WalkerStats`) so it can be tweaked in the Inspector.
- **Components over inheritance:** Health, Hitbox and Hurtbox are separate reusable nodes.
- **Communication:** children emit signals upward and parents call methods downward. Use the `Events` bus only for truly global things, such as `player_died`, `enemy_killed` or `camera_shake_requested`.
- **Player logic uses a node-based state machine**, with one state per script in `entities/player/states/`. Shared physics helpers (gravity, horizontal movement) live in `player.gd`, and states call them.
- Movement runs in `_physics_process`. Visual-only code runs in `_process`.
- Keep scripts under about 200 lines. Split them if they grow.
- Comment the *why*, not the *what*. Add a one-line header comment at the top of each script saying what it is.

## Collision layers (named in Project Settings → Layer Names → 2D Physics)

| # | Name | Used by |
|---|------|---------|
| 1 | world | TileMap/StaticBody floors, walls, platforms |
| 2 | player_body | Player CharacterBody2D |
| 3 | enemy_body | Enemy CharacterBody2D |
| 4 | player_hurtbox | Player Hurtbox (Area2D) |
| 5 | enemy_hurtbox | Enemy Hurtbox (Area2D) |
| 6 | player_attack | Player Hitboxes |
| 7 | enemy_attack | Enemy contact Hitboxes, hazards (spikes) |

- Player hitboxes are on layer 6 and mask layer 5 (plus 7 for pogo on hazards).
- Enemy/hazard hitboxes are on layer 7 and mask layer 4.
- Bodies mask `world` only. Player and enemies pass through each other; damage is handled by areas.

## Input actions (Project Settings → Input Map)

`move_left, move_right, move_up, move_down, jump, attack, dash, debug_reset, debug_overlay`.
All gameplay actions need a keyboard **and** a gamepad binding. See the spec for the exact keys.

## Workflow

1. Work on **one stage at a time** (see `docs/build_prompts.md`). Do not build ahead.
2. When a stage is done, run the playground, fix errors, and summarise. Then **wait** for the user to playtest.
3. Suggest a commit message at the end of each stage, e.g. `stage 2: wall jump + dash`.
