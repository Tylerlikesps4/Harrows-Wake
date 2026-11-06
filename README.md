# Harrow's Wake — Vertical Slice (Godot 4.3)

PS1-style survival horror. Two survivors who can never meet, one bell-ringing stalker, and the town's old pneumatic mail tubes.

## Play
- **Android:** grab `HarrowsWake.apk` from the newest Release, open it, and allow installs from your browser when asked. On-screen controls appear automatically; a Bluetooth controller works too. The picture fills wide phone screens (no black bars).
- **Windows:** run `HarrowsWake.exe` (if SmartScreen warns, click More info, then Run anyway; it's unsigned).
- **Edit / other OS:** install Godot 4.3+ (godotengine.org), Import, pick `project.godot`, press F5.
- Headphones recommended: the Bellman's bell and footsteps are positional, so you hear which way he's coming from.

## Controls
| Action | Touch | Keyboard / Mouse | Gamepad |
|---|---|---|---|
| Move | Floating stick (touch anywhere on the left half) | WASD / Arrows | Left stick / D-pad |
| Run (hold) / hold breath while hiding | RUN | Shift | B |
| Act / Confirm / Struggle | A | E / Space / Enter | A |
| Flashlight on/off | LIGHT | F | LB |
| Quick-turn | TURN | Q (or Back + Run in tank mode) | Y |
| Aim (Dana) | AIM (hold) | K / Right mouse | RB |
| Fire (Dana) | FIRE | J / Left mouse | X |
| Items | ITEMS | Tab / I | Back |
| Pause menu | II | Esc / P | Start |
| Cancel / close menu | BACK | Esc / Backspace | Back |
| Tank / Modern controls | Pause menu | F1 (or pause menu) | Pause menu |
| CRT scanlines | Pause menu | F2 | Pause menu |
| Touch controls on/off | Pause menu | F3 | |

Movement is camera-relative ("modern") on phones by default, and it keeps the old camera's direction while you hold the stick through a camera cut. Tank controls are one toggle away. Prompts show the right button for the device you're using ("Tap A", "(A)", "[E]").

## Walkthrough (spoilers)
1. **Jenny** (orphanage): sneak to the **Playroom**, grab the **Fuse** from the toy chest. Avoid the Bellman: listen for his bell and heavy steps, walk (running is loud), keep your flashlight off near him (it lets him see you from further away), and hide in wardrobes if he didn't see you get in.
2. Go to the **Mail Room** (he never enters it), send the Fuse through the **tube**, then switch to Dana at the **typewriter**.
3. **Dana** (police station): collect the Fuse at the Records Room tube. Put down the Tallow-folk in the West Hall (3 shots), then slot the Fuse into the **fuse box**.
4. Take the **Tower Key** from the Evidence Room and tube it to Jenny. Switch back.
5. **Jenny**: collect the key, then reach the **Chapel** doors past the Bellman.

If he grabs you, mash A / E. The higher your Panic, the harder it gets. In a wardrobe, hold RUN to hold your breath when he's close; if you hold it too long Jenny gasps, and if Panic maxes out she screams.

## What's in the slice
- **Look:** animated low-poly characters (Quaternius CC0 mannequins with clothing painted on in code: Jenny, Dana, the tall coated Bellman, the waxy Tallow-folk), furnished rooms (Kenney CC0 furniture and graveyard kits: beds in the dormitory, pews/altar/coffin in the chapel, desks, cabinets and shelving in the station), Poly Haven CC0 textures at 128 px with nearest filtering, all through the PSX shader (vertex snap, affine warping, 15-bit dither, CRT, film grain).
- **Light:** dark rooms, per-room coloured fog, flickering bulbs, candles, a moonlit window, the TV left on, and a flashlight with shadows.
- **Sound:** CC0 recordings: footsteps per floor (wood, tile/concrete, carpet), a positional hand bell and heavy footsteps for the Bellman, door creaks, gunshot, zombie groans, drones per area, rain and music on the title, stingers, and a heartbeat that rises with panic.
- **Scares and pacing:** an intro beat (a shape between the beds, then the light dies); a music box that starts by itself in the Playroom; taking the fuse wakes the Bellman; a phone ringing in the Chief's office; a typewriter clacking by itself in the Mail Room; lights dying as the Bellman nears. Being spotted has a readable telegraph (he stops, raises the bell, it shrieks) before the chase. Grabs shake and tear the screen.
- **Hiding:** a wardrobe-slit view, hold-your-breath meter, heartbeat, breathing.
- **Polish:** title screen in the chapel fog with the bell; fades on room cuts and character switches; pause menu; first-time tutorial prompts; ranked ending (S to D).
- Fixed RE-style cameras per room; smooth acceleration/turning and interpolated character motion (no jitter on high-refresh phones).
- Bellman stalker AI: sight cone (longer when your flashlight is on), hearing, chase, search, a "saw you hide" check, stun with a grace period.
- Tallow-folk enemy, auto-aim handgun, radio static that rises near monsters. Pneumatic tube item sharing, typewriter saves, character switching.

Asset credits and licenses: see [CREDITS.md](CREDITS.md). Everything is CC0.

## Code map
- `scripts/main.gd`: level build, lighting, cameras, interactions, menus, title, tubes, panic, scripted scares, saves
- `scripts/actor_model.gd`: animated character models (clothing bake, animation, interpolation)
- `scripts/lib.gd`: PSX materials and prop placement
- `scripts/player.gd`, `bellman.gd`, `zombie.gd`: actors. `touch.gd`: floating stick + buttons. `hud.gd`: HUD. `game.gd`: state, input map, glyphs, saves
- `scripts/synth.gd`: the two synthesised sounds (phone ring, music box). `shaders/`: PSX surface and post shaders
- `tests/smoke.gd`: automated playthrough (`godot --headless -- --smoke`); `tests/flow.gd`: title/intro/pause/flashlight/hiding (`godot --headless -- --flow`); `tests/shots.gd`: screenshot tour (`xvfb-run godot -- --shots`)

Next milestone (from the GDD): Elias and the cryo lab, the Otherworld bell shift, the raptor rift, more endings.

## Builds
Every push to `main` runs GitHub Actions: the automated playthrough and flow test, then a Windows .exe and an Android APK (debug-signed, arm64), published as a Release.
