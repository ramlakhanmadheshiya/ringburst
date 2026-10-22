# Ringburst

*A one-touch hold-and-release arcade.* You are a glowing core at the centre of the screen and neon shapes creep in from every edge. Hold anywhere and a ring grows from the core; let go and it bursts outward as a shockwave that hits everything inside it. Catch a shape right on the ring's edge for a PERFECT.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; works with touch, mouse and keyboard.

**Play / download:** https://theramlakhan.com/ringburst/ (browser version and Android APK)
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

## The game

- **One touch.** Hold to grow the ring, release to burst it. A bigger ring reaches further, but while it grows you aren't attacking and the shapes get closer. A shape that touches the core breaks one of your three shields (a short safe moment and a shove follow); lose them all and the level is lost, with one revive on offer.
- **PERFECT.** Let go while a shape sits on the ring's edge (it lights up white, with a soft blip) and the burst is a critical: double damage, a spark to a nearby shape, a slow-motion flash, and +1 combo. The combo multiplies score (up to ×4); a burst that hits nothing breaks it, and so does a hit on the core. From Iron Bloom on, shapes take two plain hits or one PERFECT.
- **Level by level, one task each.** No upgrades to pick and nothing to manage: every level is prepared in advance and has one task, shown on its card before it starts: *Burst 12 shapes*, *Land 5 PERFECTs*, *Survive 30 seconds*, *Reach a combo of 6*, *Burst 6 Wardens* (hunting the world's new shape), *Beat Giant Splitter* (levels 10, 20 and 30 of each world) or *Beat Hydra* (level 40, the world's boss). Finish the task and the level is clear; the HUD shows it as a bar with a count, the seconds left, or the Giant's health. A level takes about 15–45 seconds.
- **8 worlds × 40 levels = 320 levels.** Levels open one at a time, and a world's boss opens the next world. Each world has its own palette, music loop and one new shape, shown on a card with a live demo before its first level:

  | # | World | New shape | Its trick | Boss |
  |---|---|---|---|---|
  | 1 | Neon Shore | Drifter | drifts straight in | Monolith (sheds minis) |
  | 2 | Pulse City | Dasher | stops, flashes, lunges | Lancer (telegraphed lunges) |
  | 3 | Iron Bloom | Warden | shield blocks plain waves: needs a PERFECT | Bastion (shield returns) |
  | 4 | Fracture | Splitter | bursts into three quick minis | Hydra (splits in two) |
  | 5 | Orbit Deep | Orbiter | spirals round the core | Carousel (orbits) |
  | 6 | The Hive | Hatcher | parks at long range and breeds minis | Hive Queen |
  | 7 | Phantom Rift | Phantom | fades in and out of reach | Wraith (phases, lunges) |
  | 8 | Event Horizon | Brute | armoured, hard to push | Eclipse (everything) |

  Difficulty climbs through each world (faster shapes, more of them) and from world to world; the level after each Giant eases off a little. Built in `Worlds.level_spec` from the world and level number, so every level is the same every time it's played.
- **Stars:** one for every shield still standing when the task is done (all three = ★★★). A revived level earns one star. The best stars and score per level are kept.
- **Awards:** 20 awards plus one per world (28 in all), as badges.
- **Feel:** trauma screen shake, hit-stop on boss hits and kills, slow motion on perfects, additive neon glow, shards and rings on every burst, a screen pulse with every release, rising ticks while the ring grows and a pentatonic chime ladder as the combo climbs, and haptics on release, perfects and hits. Screen shake and vibration can be turned off.
- **First play:** Neon Shore level 1 starts with a hands-on tutorial with an animated hand (hold, let go on the shape, a group, the danger of the core). You can replay it from How to play.
- **Shop** (Single Shot's model; one-time packs plus tips, all via Google Play):

  | Product | What it gives |
  |---|---|
  | Complete pack | Everything below in one pack |
  | Supporter pack | No banner ads; revive without watching a video |
  | Theme pack | 11 colour themes (9 dark, 2 light) for the whole app and the arena (1-hour trial from a video) |
  | Ring styles | 6 looks for the ring and waves: Neon, Plasma, Prism, Aurora, Ember, Ghost (1-hour trial from a video) |
  | Tip jar | Say thanks (190 amounts, ₹10–₹10,000 in Play's rupee prices); four quick amounts, or pick any with − / + and a slider. Every price is shown in the player's own currency; unlocks nothing |

  Prices always come from `Store.price(id)`: Google Play's localised price once it answers, otherwise a regional guess from the device locale (only India's shows ₹). The shop, every pack card and the tip jar carry a small line: "Purchases are made through Google Play. Sorry, we can't refund or undo a purchase."

  Product ids and Play Console setup: [`store/PLAY_PRODUCTS.md`](store/PLAY_PRODUCTS.md). Debug desktop builds simulate purchases; the web build explains that purchases are in the Android app.
- **Ads (Android only, no interstitials):**
  - a bottom banner on menus and result cards, with its space reserved before the ad loads so the layout never jumps; it refreshes on screen changes at most every 30 s. It is hidden while a run is being played: the whole screen is the control, so a stray tap must never land on an ad (AdMob's accidental-click policy);
  - rewarded videos only when the player asks (a revive, a pack trial).
  - Supporters see no banner and revive without a video.
- **Sharing:** after a level, Share makes a 1080×1350 picture (a frozen burst in the world's colours, the level, its task, score and stars, link and QR code) and opens the phone's share sheet; Save puts it in the gallery (Pictures › Ringburst); Copy link copies the message. Android uses a small plugin (`plugins_src/ringburst_share`, built by CI), like Single Shot.
- **Appearance:** a thin Auto / Dark / Light slider in Settings; Auto follows the phone's dark mode. Light turns every world into a daytime version. Theme-pack themes keep their own colours.
- **Settings:** Music and Sound sliders, Vibration, Screen shake, Appearance, colour theme and ring style pickers, How to play, Shop, Awards, About, Credits, Ad privacy (when required), and Reset progress (tap once to arm, again to erase; hidden during a level; keeps settings and packs).
- **Saving:** everything is saved locally with atomic writes and a backup; a corrupt save is recovered from the backup. A save from the first version (6 stages a world, coins, the Forge) keeps its settings and purchases; progress starts again.

### Controls

| Input | Action |
|---|---|
| Hold and release (touch or mouse, anywhere) | Grow the ring, burst it |
| Space (hold and release) | The same |
| Esc / Android Back | Pause during a level; Back elsewhere (level → its world's levels → worlds → home) |

## Run

```sh
./play.sh              # launches the game window directly (no editor)
```

Debug desktop runs show a test ad banner and simulate purchases, so every flow can be tried without a phone.

## Test

```sh
./tests/run_all.sh
```

| Suite | What it checks |
|---|---|
| `tests/logic_test.gd` | The deterministic core: the RNG (pinned sequence), ring growth and cooldown, wave reach, the PERFECT window and double damage, chain sparks, the core and shields, Warden shields, splitting, combos and whiffs, every kind of task (kills, PERFECTs, survive, combo, hunt, Giant, boss), Hydra splitting, stars from shields, all 320 levels (unique ids, a task each, the curve climbs), identical replays, spawns that don't depend on the player, and the director. |
| `tests/balance_test.gd` | Bot-verified difficulty on all 320 levels: a precise bot wins every level with nearly every star; a sloppy bot (human pauses, late, imprecise, never aims) breezes through world 1, wins nearly every level of worlds 2–6, and loses some in worlds 7–8; levels stay short; each world sends more threat than the last. |
| `tests/profile_test.tscn` | Levels opening one by one, stars (best kept), best scores, worlds opening after their boss, awards (once), simulated purchases, trials, the Complete pack, Supporter perks, save/load, corrupt-save recovery, reset keeping purchases, and moving a version-1 save over. |
| `tests/ui_flow.tscn` | The real app end to end with the mock ad provider: banner space, home, How to play, worlds and the level grid, the level card and its task, the tutorial, a real level (HUD and task bar, pause, win, stars, share), the next level, a loss with a revive, a Giant level, the shop (trial, Supporter removes the banner, restore), settings, Back, and an app restart. |
| Boot smoke | Runs the game for 300 frames and fails on any error or warning. |

Screenshots of every screen (needs a display; add `clean` to hide the test banner, `store` for the Play Store set):

```sh
godot --path . res://tests/capture.tscn -- /tmp/rb_shots 450 800
godot --path . res://tests/capture.tscn -- "$PWD/store/screenshots" 540 960 store
```

Balance lab (prints every level as played by the bots):

```sh
godot --headless --path . -s res://tools/balance.gd          # all worlds
godot --headless --path . -s res://tools/balance.gd -- 3     # one world
```

## How it works

| Piece | File |
|---|---|
| Deterministic simulation (fixed 60 Hz, seeded): ring, waves, perfects, shapes, bosses, the level's task, stars, events | `game/core/run_sim.gd` |
| Spawn director: a threat budget on a smoothstep curve with 20 s swells and 16 s surges, from its own seeded RNG | `game/core/director.gd` |
| Worlds and the 320 levels: tasks, targets and the difficulty curve | `game/core/worlds.gd` |
| Shapes and bosses / the ring's numbers | `game/core/enemies.gd`, `run_stats.gd` |
| The auto-player (tests, home demo) | `game/core/bot.gd` |
| Cross-platform RNG (xorshift32, integer-only) | `game/core/rng.gd` |
| Arena: fixed-step driving, input, neon drawing (additive glow layer), juice, sound and haptics from sim events | `game/arena/arena_view.gd` |
| App shell, screens, cards, design system and looks | `game/ui/` |
| Save data, progress, store, audio, haptics, sharing | `game/autoload/` |
| Ads (AdMob provider and a mock) | `game/ads/` |
| Audio synthesiser (all SFX and 10 music loops, no samples) | `tools/synth_audio.py` |
| Icons, splash and store art | `tools/render_icons.gd`, `tools/render_feature_graphic.tscn` |

**Determinism.** The simulation never touches the engine's clock, scene tree or random numbers: it steps at a fixed 1/60 s, and slow motion and hit-stop only change how many steps the arena runs per frame. The director has its own seeded `Rng`, so what the player does never changes which shapes come next. That is what makes a level the same every time and lets the tests replay all 320 with bots.

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`: the tests, a signed Android APK and App Bundle (Gradle build with the AdMob, Play Billing and share plugins), a web export, publishing to `gh-pages` (served at `https://theramlakhan.com/ringburst/` with `play/`, `help/`, `privacy/` and `ringburst.apk`), a GitHub release with the APK and AAB, and an optional upload to Google Play's internal track.

Repository secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEYSTORE_ALIAS` | Release signing (without them a throwaway key is used, and updates can't install over older builds) |
| `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_REWARDED_ID` | Real AdMob units (without them Google's test ads are used) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Optional: uploads the AAB to Play's internal testing track |

Play Console forms, listing text and products: `store/PLAY_CONSOLE.md`, `store/listing.md`, `store/PLAY_PRODUCTS.md`.

## Project structure

| Path | What it holds |
|---|---|
| `game/core/` | Pure logic: simulation, director, worlds and levels, shapes, the ring's stats, bot, awards |
| `game/arena/` | The arena view |
| `game/autoload/` | `save.gd`, `profile.gd`, `store.gd`, `audio.gd`, `haptics.gd`, `share_service.gd` |
| `game/ads/` | `ad_manager.gd` (banner and rewarded policy) and providers: AdMob (Android) and a mock (debug desktop, tests) |
| `game/ui/` | `app.gd` (screens, Back chain, overlays, toasts, splash), `screen.gd`, `overlay.gd`, `ui_kit.gd`, `style.gd`, `look.gd` (themes, ring styles, appearance), `splash.gd`, `tutorial.gd`, `screens/` (home, worlds, levels, play, shop), `overlays/` (level, pause, revive, result, share, new shape, settings, product, picker, tips, how-to, about, credits, awards, messages), `widgets/` |
| `addons/` | Godot AdMob plugin (Poing Studios, MIT), Godot Google Play Billing (MIT), the share plugin's export hook |
| `plugins_src/` | The Android share plugin (Java), built by CI |
| `store/`, `web/`, `docs/` | Play Console docs and art, the website pages, the game design document |
| `tools/`, `tests/` | Synthesiser, renderers, balance lab; the test suites and screenshot capture |

## Decisions made while building it

- **Level by level, no upgrades (version 2).** The first version was a roguelite (XP gems, 1-of-3 upgrade picks, the Forge, coins, Endless, a Daily Run). It played as too complicated, so every level is now prepared in advance with one task, played with the same ring, and stars count the shields left. Difficulty comes from the levels themselves; the balance test proves every level can be won.
- **The banner hides during play** (see Ads) and returns on results and menus.
- **Bosses never take a free hit:** lunges stop short of the core, because the player cannot move; only shapes that get through cost shields.
- **Shapes take two hits from world 3 on.** With no upgrades, one-hit shapes made every level trivial for a full-size ring; two plain hits (or one PERFECT) make timing matter, and the bots confirm the curve.
- **The icon, art and music are original**, drawn and synthesised for this game; the star and a few item icons are shared with Word Lantern.

## Credits

| Asset | Source | Licence |
|---|---|---|
| Engine: [Godot Engine](https://godotengine.org) 4.7.2 | Godot contributors | MIT |
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Fallback glyphs (★ ♥ ₹ ৳) | Noto Sans subsets | SIL OFL 1.1, `assets/fonts/OFL-Noto.txt` |
| UI icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Game icons and the app icon | Drawn for Ringburst (star and some item art shared with Word Lantern) | Released with the project |
| Music and sound effects | Generated by `tools/synth_audio.py`, no samples | Released with the project (CC0) |
| QR code on the share card | Generated with [segno](https://github.com/heuer/segno) | Generated output |
| [Godot AdMob Plugin](https://github.com/poingstudios/godot-admob-plugin) | Poing Studios | MIT, `addons/admob/LICENSE` |
| [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | Godot contributors | MIT, `addons/GodotGooglePlayBilling/LICENSE` |

The game-dev agent skills used while building this are in `.claude/skills/`. They come from [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0) and [godot-skills](https://github.com/vl4dt/godot-skills) (MIT).

Game design and development: **Ramlakhan Madheshiya** — https://theramlakhan.com
