# Harrow's Wake — Vertical Slice (Godot 4.3)

PS1-style survival horror. Two survivors who can never meet, one bell-ringing stalker, and the town's old pneumatic mail tubes.

## Play
- **Android:** grab `HarrowsWake.apk` from the newest Release, open it, and allow installs from your browser when asked. On-screen controls appear automatically, and a Bluetooth controller works too.
- **Windows:** run `HarrowsWake.exe` (if SmartScreen warns, click More info, then Run anyway; it's unsigned).
- **Edit / other OS:** install Godot 4.3+ (godotengine.org), Import, pick `project.godot`, press F5.

## Controls
| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move | WASD / Arrows | Left stick / D-pad |
| Run | Shift | B |
| Act / Confirm / Struggle | E / Space / Enter | A |
| Quick-turn | Q (or Back + Run) | Y |
| Aim (Dana) | K / Right mouse | RB |
| Fire (Dana) | J / Left mouse | X |
| Items | Tab / I | Start |
| Cancel | Esc | Back |
| Tank / Modern controls | F1 | |
| CRT scanlines | F2 | |
| Touch controls on/off | F3 | (auto on phones) |

## Walkthrough (spoilers)
1. **Jenny** (orphanage): sneak to the **Playroom**, grab the **Fuse** from the toy chest. Avoid the Bellman: listen for his bell, walk (running makes noise), and hide in wardrobes if he hasn't seen you get in.
2. Go to the **Mail Room** (he never enters it), send the Fuse through the **tube**, then switch to Dana at the **typewriter**.
3. **Dana** (police station): collect the Fuse at the Records Room tube. Put down the Tallow-folk in the West Hall (3 shots), then slot the Fuse into the **fuse box**.
4. Take the **Tower Key** from the Evidence Room and tube it to Jenny. Switch back.
5. **Jenny**: collect the key, then reach the **Chapel** doors past the Bellman.

If he grabs you, mash E. The higher your Panic, the harder it gets. Panic too long in a wardrobe while he's close and Jenny screams.

## What's in the slice
- PSX shader: vertex jitter, affine texture warping, 320x240, 15-bit dithering, fog, CRT
- Fixed RE-style cameras per room, plus tank and modern controls
- Bellman stalker AI: sight cone, hearing, chase, search, a "saw you hide" check, stun
- Panic meter, struggle QTE, hiding spots
- Tallow-folk enemy, auto-aim handgun, radio static that rises near monsters
- Pneumatic tube item sharing between survivors, typewriter saves, character switching
- Ranked ending screen (S to D)
- All textures and sounds generated in code, with no external assets

## Code map
- `scripts/main.gd`: level build, cameras, interactions, menus, tubes, panic, saves
- `scripts/player.gd`, `bellman.gd`, `zombie.gd`: actors
- `scripts/synth.gd`: procedural audio. `shaders/`: PSX surface and post shaders
- `tests/smoke.gd`: automated playthrough (`godot --headless --fixed-fps 60 -- --smoke`)

Next milestone (from the GDD): Elias and the cryo lab, the Otherworld bell shift, the raptor rift, more endings.

## Builds
Every push to `main` runs GitHub Actions: an automated playthrough, then a Windows .exe and an Android APK (debug-signed, arm64), published as a Release.
