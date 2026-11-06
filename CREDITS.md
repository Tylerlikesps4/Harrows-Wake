# Credits

Every third-party asset in Harrow's Wake is **CC0 1.0 (public domain)**. Assets were downscaled or trimmed for size; no other changes to their licensing.

## Characters and animation (`assets/models/`)
| File | Asset | Author | Source | License |
|---|---|---|---|---|
| `mannequin.glb` | Universal Animation Library (Standard) - mannequin + 16 of its animations (idle, walk, jog, sprint, death, pistol, hit, pickup, crouch, formal walk, torch idle, punch...) | Quaternius | https://opengameart.org/content/universal-animation-library | CC0 |
| `mannequin_zombie.glb` | Universal Animation Library 2 (Standard) - mannequin + zombie idle/walk/scratch, knockback, lantern idle | Quaternius | https://opengameart.org/content/universal-animation-library-2 | CC0 |

Unused animations were stripped from the .glb files to save space. Clothing (Jenny's nightgown, Dana's uniform, the Bellman's coat, the Tallow-folk's wax) is painted onto the mannequins in code (`scripts/actor_model.gd`); hats, bell, shears and pistol are simple code-made shapes.

## Props (`assets/props/`)
| Files | Asset | Author | Source | License |
|---|---|---|---|---|
| beds, bookcases, desk, chairs, cabinets, boxes, lamps, radio, TV, bear, rug, table, trashcan, plant, coat rack, pillow | Furniture Kit 2.0 | Kenney | https://kenney.nl/assets/furniture-kit | CC0 |
| `gy_*` (pews/benches, altar, candles, wooden cross, coffin, debris, lantern, urn) + `Textures/colormap.png` | Graveyard Kit | Kenney | https://kenney.nl/assets/graveyard-kit | CC0 |

## Textures (`assets/tex/`, downscaled to 128x128, 64 colours)
All from Poly Haven (https://polyhaven.com/license, CC0): old_wood_floor, decrepit_wallpaper, damaged_plaster, dirty_tiles, floor_tiles_06, rusty_metal_02, dirty_carpet, dark_wooden_planks, concrete_floor_worn_001, plastered_wall_02, painted_metal_shutter, blue_plaster_weathered, checkered_pavement_tiles. Each is at `https://polyhaven.com/a/<name>`.

## Sound (`assets/audio/`, converted to mono 22 kHz Ogg, trimmed/looped/pitched)
| File(s) | Source asset | Author | Source | License |
|---|---|---|---|---|
| `step_wood_*`, `step_concrete_*`, `step_carpet_*`, `bell_toll` (pitched impactBell_heavy), `splat` (impactPunch_heavy), `bulb_pop` (impactGlass_light) | Impact Sounds | Kenney | https://kenney.nl/assets/impact-sounds | CC0 |
| `creak`, `door`, `pickup` | RPG Audio | Kenney | https://kenney.nl/assets/rpg-audio | CC0 |
| `menu`, `glitch` | Interface Sounds | Kenney | https://kenney.nl/assets/interface-sounds | CC0 |
| `bell` (bell_03, pitched down), `tube` (machine_01), `unlock` (key_open_01), `flashlight` (switch_01), `slam` (slam_03), `static` (noise_01, looped) | 100 CC0 SFX | rubberduck | https://opengameart.org/content/100-cc0-sfx | CC0 |
| `bell_roar` (scream_02), `hurt` (hurt_02), `breath`, `zombie_die` (monster_03) | 80 CC0 creature SFX | rubberduck | https://opengameart.org/content/80-cc0-creature-sfx | CC0 |
| `gunshot` (22 Pistol) | Gunshots | kurt | https://opengameart.org/content/gunshots | CC0 |
| `groan_1..4` | Undead Moans | AntumDeluge | https://opengameart.org/content/undead-moans | CC0 |
| `heart` | Heartbeat Sounds | bart | https://opengameart.org/content/heartbeat-sounds | CC0 |
| `typewriter` | Typewriter Sounds | Cassie-OrbitGames | https://opengameart.org/content/typewriter-sounds | CC0 |
| `sting` | Excited horror sound | remaxim | https://opengameart.org/content/excited-horror-sound | CC0 |
| `scream` | Female Scream 1 | Nocturnal_Vanguard | https://opengameart.org/content/female-scream-1 | CC0 |
| `amb_orphanage` (drone53), `amb_station` (drone61) | Droning sound effects | bretbernhoft | https://opengameart.org/content/droning-sound-effects | CC0 |
| `amb_chapel` | Ambient Horror | techiew | https://opengameart.org/content/ambient-horror | CC0 |
| `amb_rain` | Amb rain loop 1 | Kresiek The Furry | https://opengameart.org/content/amb-rain-loop-1 | CC0 |
| `title_music` ("The Surreal Truth") | Ambience Pack 1: Sci-Fi Horror | Joth | https://opengameart.org/content/ambience-pack-1-sci-fi-horror | CC0 |

Synthesised in code (no suitable CC0 recording found): the telephone ring and the music box (`scripts/synth.gd`).

## Code
Game code, shaders and level layouts: Copyright (C) 2026 Tylerlikesps4, GNU GPL v3 (see LICENSE). Character faces are painted in code (`scripts/actor_model.gd`). Engine: Godot 4.3 (MIT).

Assets keep their own licenses (all CC0, above); the GPL applies to the code only.
