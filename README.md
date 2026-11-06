# Harrow's Wake — Free Demo (Godot 4.3)

PS1-style survival horror. Two survivors who can never meet, one bell-ringing stalker, and the town's old pneumatic mail tubes.

This is the **free, open-source demo**: one complete chapter (about 15-25 minutes) with a beginning, middle and end. The full game ($5.99) is coming soon.

## Play
- **Android:** grab `HarrowsWake.apk` from the newest Release, open it, and allow installs from your browser when asked. On-screen controls appear automatically; a Bluetooth controller works too. The picture fills wide phone screens (no black bars).
- **Windows:** download `HarrowsWake-Windows.zip`, extract it, and run `HarrowsWake.exe` (keep the `data_HarrowsWake_*` folder beside it; it holds the C# code). If SmartScreen warns, click More info, then Run anyway; it's unsigned.
- **Edit / other OS:** see "Build from source" below (needs the Godot 4.3 .NET edition).
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
| Settings (brightness, volume, controls, touch layout, CRT, shadows, FPS) | Title or pause menu | Title or pause menu (F1 tank/modern, F2 CRT) | Title or pause menu |

Settings are saved to `user://settings.cfg`. Movement is camera-relative ("modern") on phones by default, and it keeps the old camera's direction while you hold the stick through a camera cut. Tank controls are one toggle away. Prompts show the right button for the device you're using ("Tap A", "(A)", "[E]").

## Walkthrough (spoilers)
1. **Jenny** (orphanage): sneak to the **Playroom**, grab the **Fuse** from the toy chest. Avoid the Bellman: listen for his bell and heavy steps, walk (running is loud), keep your flashlight off near him (it lets him see you from further away), and hide in wardrobes if he didn't see you get in.
2. Go to the **Mail Room** (he never enters it), send the Fuse through the **tube**, then switch to Dana at the **typewriter**.
3. **Dana** (police station): collect the Fuse at the Records Room tube. Put down the Tallow-folk in the West Hall (3 shots), then slot the Fuse into the **fuse box**.
4. Take the **Tower Key** from the Evidence Room and tube it to Jenny. Switch back.
5. **Jenny**: collect the key, then reach the **Chapel** doors past the Bellman.

Six documents (memos, a field report, a ledger) are scattered around both buildings; the pause menu always shows your **current objective**, and ITEMS shows item descriptions and lets you re-read files. If you die, **Retry from last save** puts you back at your last typewriter save.

If he grabs you, mash A / E. The higher your Panic, the harder it gets. In a wardrobe, hold RUN to hold your breath when he's close; if you hold it too long Jenny gasps, and if Panic maxes out she screams.

## What's in the demo
- **Look:** animated low-poly characters (Quaternius CC0 mannequins with clothing painted on in code: Jenny, Dana, the tall coated Bellman, the waxy Tallow-folk), furnished rooms (Kenney CC0 furniture and graveyard kits: beds in the dormitory, pews/altar/coffin in the chapel, desks, cabinets and shelving in the station), Poly Haven CC0 textures at 128 px with nearest filtering, all through the PSX shader (vertex snap, affine warping, 15-bit dither, CRT, film grain).
- **Light:** dark rooms, per-room coloured fog, flickering bulbs, candles, a moonlit window, the TV left on, and a flashlight with shadows.
- **Sound:** CC0 recordings: footsteps per floor (wood, tile/concrete, carpet), a positional hand bell and heavy footsteps for the Bellman, door creaks, gunshot, zombie groans, drones per area, rain and music on the title, stingers, and a heartbeat that rises with panic.
- **Scares and pacing:** an intro beat (a shape between the beds, then the light dies); a music box that starts by itself in the Playroom; taking the fuse wakes the Bellman; a phone ringing in the Chief's office; a typewriter clacking by itself in the Mail Room; lights dying as the Bellman nears. Being spotted has a readable telegraph (he stops, raises the bell, it shrieks) before the chase. Grabs shake and tear the screen.
- **Hiding:** a wardrobe-slit view, hold-your-breath meter, heartbeat, breathing.
- **Polish:** title screen in the chapel fog with the bell; fades on room cuts and character switches; pause menu; first-time tutorial prompts; ranked ending (S to D).
- **Faces:** low-res painted faces on every character; the Bellman wears a cracked porcelain mask with a sewn mouth and glowing eyes.
- **Feel:** stride-matched walk/run animation (no foot sliding), turn-in-place, aim laser, muzzle flash + recoil, enemy hit reactions, item pickup flourish and banner, fade-and-creak door transitions, a wax-melt death for the Tallow-folk.
- **Settings:** brightness, master/music/SFX volume, tank or modern controls, invert stick, CRT, flashlight shadows, FPS counter, touch stick sensitivity and button size/opacity.
- **Phones:** renders at 320x240 internally (cheap fill), MSAA off, only the flashlight casts shadows (off by default on phones), and only the active survivor's building is drawn.
- Fixed RE-style cameras per room; smooth acceleration/turning and interpolated character motion (no jitter on high-refresh phones).
- Bellman stalker AI: sight cone (longer when your flashlight is on), hearing, chase, search, a "saw you hide" check, stun with a grace period.
- Tallow-folk enemy, auto-aim handgun, radio static that rises near monsters. Pneumatic tube item sharing, typewriter saves, character switching.

## License
- **Code:** GNU GPL v3 ([LICENSE](LICENSE)). Copyright (C) 2026 Tylerlikesps4, who remains the sole copyright owner.
- **Assets** keep their own licenses: every third-party model, texture and sound is CC0. See [CREDITS.md](CREDITS.md).
- The **"Harrow's Wake" name and logo are not licensed for reuse.** Forks must use a different name.

### Project scope: open demo, proprietary full game
This repository holds the open-source **demo** of Harrow's Wake. The **full game ($5.99) is a separate, proprietary commercial project** by Tylerlikesps4, released under its own EULA.
- **Open source (here):** the core mechanics, systems and demo content in this repository.
- **Proprietary (not here):** additional chapters and levels, story, art, audio and premium mechanics made for the full release.

Because Tylerlikesps4 is the sole copyright owner, the same core can be offered under the GPL here and under commercial terms in the full game (dual licensing).

## Contributing
Bug reports and pull requests are welcome. Keep the PSX look, keep `godot --headless -- --smoke` and `-- --flow` passing, and only add assets that are CC0 (credit them in CREDITS.md).

**Contributor agreement:** by submitting a contribution you agree that it is licensed to the project under the GPL v3 *and* that Tylerlikesps4 may relicense it under other terms (including in the commercial full game).

## Build from source
The project mixes **C#** and **GDScript**, so it needs the **Godot 4.3 .NET edition** (the plain build can't run the C# parts).
1. Install **Godot 4.3 .NET** (godotengine.org/download/archive/4.3-stable, the ".NET" download) and the **.NET 8 SDK** (dotnet.microsoft.com).
2. Clone this repo and run `dotnet build HarrowsWake.sln` once (or press Build in the editor).
3. Open Godot, **Import**, pick `project.godot`, press **F5**.
3. Tests: `godot --headless -- --smoke` (automated playthrough) and `godot --headless -- --flow` (title/settings/pause/hiding). Screenshots: `xvfb-run -s "-screen 0 1280x960x24" godot -- --shots`.
4. Export: install the 4.3 **.NET (mono)** export templates (Editor > Manage Export Templates), then Project > Export > Windows Desktop or Android. Android needs the Android SDK + a debug keystore set in Editor Settings.

## Install the APK
On your Android phone, open the newest [Release](https://github.com/Tylerlikesps4/Harrows-Wake/releases/latest), download `HarrowsWake.apk`, open it, and allow installs from your browser when asked (Settings > Apps > your browser > Install unknown apps). It's an arm64 debug-signed build; uninstall the old version first if Android refuses to update it.

## Code map
**C# (`csharp/`, project `HarrowsWake.csproj` / `HarrowsWake.sln`, Godot.NET.Sdk 4.3.0, net8.0):**
- `GameState.cs`: the `Game` autoload: game state, item/flag helpers, save/load (`user://harrows_wake_save.json`), settings (`user://settings.cfg`), audio buses, input map, device glyphs
- `Bellman.cs`: the Bellman stalker AI (sight, hearing, telegraph, chase, search, hide check, stun)
- `WaypointGraph.cs`: room-graph BFS pathfinding used by both enemies

C# members use snake_case names on purpose, so GDScript calls them directly (`Game.flag("power")`, `Game.state["inv"]`, `bellman.state == bellman.S.CHASE`); C# calls back into GDScript with `Call`/`Get`.

**GDScript (`scripts/`, `tests/`):**
- `scripts/main.gd`: level build, lighting, cameras, interactions, menus, title, tubes, panic, scripted scares, saves
- `scripts/actor_model.gd`: animated character models (clothing bake, animation, interpolation)
- `scripts/lib.gd`: PSX materials and prop placement
- `scripts/player.gd`, `zombie.gd`: survivors and the Tallow-folk. `touch.gd`: floating stick + buttons. `hud.gd`: HUD
- `scripts/synth.gd`: the two synthesised sounds (phone ring, music box). `shaders/`: PSX surface and post shaders
- `tests/smoke.gd`: automated playthrough (`godot --headless -- --smoke`); `tests/flow.gd`: title/intro/pause/flashlight/hiding (`godot --headless -- --flow`); `tests/shots.gd`: screenshot tour (`xvfb-run godot -- --shots`)

Full game (from the GDD): Elias and the cryo lab, the Otherworld bell shift, the raptor rift, more endings.

## Builds
Every push to `main` runs GitHub Actions on the Godot 4.3 .NET image: `dotnet build`, the automated playthrough and flow test, then a Windows .exe and an Android APK (debug-signed, arm64), published as a Release. (C# on Android is marked experimental by Godot 4.3.)
