# Ringburst

*A one-touch hold-and-release arcade.* You are a glowing core at the centre of the screen and neon shapes creep in from every edge. Hold anywhere and a ring grows from the core; let go and it bursts outward as a shockwave that hits everything inside it. Catch a shape right on the ring's edge for a PERFECT.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; works with touch, mouse and keyboard.

**Play / download:** https://theramlakhan.com/ringburst/ (browser version and Android APK)
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

## The game

- **One touch.** Hold to grow the ring, release to burst it. A bigger ring reaches further, but while it grows you aren't attacking and the shapes get closer. A shape that touches the core breaks one of your three shields (a short safe moment and a shove follow); lose them all and the run is over, with one revive on offer.
- **PERFECT.** Let go while a shape sits on the ring's edge (it lights up white, with a soft blip) and the burst is a critical: double damage, a chain spark to nearby shapes, a slow-motion flash, and +1 combo. The combo multiplies score (up to ×4); a burst that hits nothing breaks it, and so does a hit on the core.
- **Runs are roguelite.** Burst shapes drop XP gems that your waves pull in. Each level-up pauses for a choice of 1 of 3 upgrades from a pool of **30**: 26 upgrades (Echo, Split, Frost Ring, Magnet, Thorns, Overcharge, Shield Regen, Chain Lightning, Pierce Armour, Sharp Eye, Afterglow, Quick Charge, Long Reach, Heavy Wave, Shove, Lifeline, Heartbeat, Greed, Scholar, Second Wind, Steady Hands, Static, Ember, Ricochet, Fast Wave, Satellites) and **4 synergies** that only turn up once both halves are owned (Frost + Static = Shatter, Echo + Chain = Resonance, Overcharge + Long Reach = Supernova, Ember + Afterglow = Inferno).
- **8 worlds × 6 stages = 48 stages.** Each world has its own palette, music loop and one new shape, taught on a card with a live demo before its first stage:

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

  A stage lasts 70–100 seconds, then its boss arrives: stages 1–5 end with a Guardian (a giant of the world's shape), stage 6 with the world boss. Beating it clears the stage.
- **Stars**, each its own goal: clear the stage, take no hits, and reach the stage's combo target. Stars from different runs add up. Each new star pays 10 coins; a world's boss pays 150 the first time.
- **Meta-progression (the Forge):** every run pays coins, won or lost (score ÷ 200, +20 for a win). Spend them on 9 permanent upgrades (Extra Shield, Core Power, Quick Hands, Reach, Keen Eye, Pull, Study, Fortune, Reroll), 6 extra **ring types** (Twin, Glacier, Lens, Nova, Cinder, Titan: each changes how the ring plays) and 10 **starting perks**. Pick the ring and perk on the stage card before you play.
- **Endless** (opens after Neon Shore 3): every shape from the start, a boss every two minutes, and difficulty that never stops climbing. Best score and longest run are kept.
- **Daily Run:** built on the phone from the date (`Worlds.daily_spec`), with no server, so everyone gets the same run on the same day: the same seed, world, boss and one of 7 modifiers (Swarm, Glass Core, Cold Snap, Giants, Blitz, Echoes, Precision). Difficulty follows the week (Monday gentlest, Sunday hardest). The reward (40 coins + 5 per streak day, capped) is paid once a day; replays can still beat your best. A test pins one day's run so an accidental change is caught.
- **Achievements:** 32 awards plus one per world (40 in all), each paying coins once.
- **Feel:** trauma screen shake, hit-stop on boss hits and kills, slow motion on perfects, additive neon glow, shards and rings on every burst, a screen pulse with every release, rising ticks while the ring grows and a pentatonic chime ladder as the combo climbs, and haptics on release, perfects and hits. Screen shake and vibration can be turned off.
- **First play:** Neon Shore 1 starts with a hands-on tutorial with an animated hand (hold, let go on the shape, a group, the danger of the core). You can replay it from How to play.
- **Shop** (Single Shot's model; one-time packs plus consumables, all via Google Play):

  | Product | What it gives |
  |---|---|
  | Complete pack | Everything below, plus 1,500 coins |
  | Supporter pack | No banner ads; revive and double coins without watching a video |
  | Theme pack | 11 colour themes (9 dark, 2 light) for the whole app and the arena (1-hour trial from a video) |
  | Ring styles | 6 looks for the ring and waves: Neon, Plasma, Prism, Aurora, Ember, Ghost (1-hour trial from a video) |
  | Coin bags | 500 / 1,500 / 4,000 / 10,000 coins; plus free coins from a video (5 a day) |
  | Tip jar | Say thanks (₹10–₹1,000); unlocks nothing |

  Product ids and Play Console setup: [`store/PLAY_PRODUCTS.md`](store/PLAY_PRODUCTS.md). Debug desktop builds simulate purchases; the web build explains that purchases are in the Android app.
- **Ads (Android only, no interstitials):**
  - a bottom banner on menus and result cards, with its space reserved before the ad loads so the layout never jumps; it refreshes on screen changes at most every 30 s. It is hidden while a run is being played: the whole screen is the control, so a stray tap must never land on an ad (AdMob's accidental-click policy);
  - rewarded videos only when the player asks (revive, double a run's coins, free coins, a pack trial).
  - Supporters see no banner and get every video reward without a video.
- **Sharing:** after a run, Share makes a 1080×1350 picture (a frozen burst in the world's colours, score, combo, stars, the upgrades that made the run, link and QR code) and opens the phone's share sheet; Save puts it in the gallery (Pictures › Ringburst); Copy link copies the message. Android uses a small plugin (`plugins_src/ringburst_share`, built by CI), like Single Shot.
- **Appearance:** a thin Auto / Dark / Light slider in Settings; Auto follows the phone's dark mode. Light turns every world into a daytime version. Theme-pack themes keep their own colours.
- **Settings:** Music and Sound sliders, Vibration, Screen shake, Appearance, colour theme and ring style pickers, How to play, Shop, Awards, About, Credits, Ad privacy (when required), and Reset progress (tap once to arm, again to erase; hidden during a run; keeps settings, packs and bought coins).
- **Saving:** everything is saved locally with atomic writes and a backup; a corrupt save is recovered from the backup.

### Controls

| Input | Action |
|---|---|
| Hold and release (touch or mouse, anywhere) | Grow the ring, burst it |
| Space (hold and release) | The same |
| 1 / 2 / 3 | Pick an upgrade |
| Esc / Android Back | Pause during a run; Back elsewhere (run → stages → worlds → home) |

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
| `tests/logic_test.gd` | The deterministic core: the RNG (pinned sequence), ring growth and cooldown, wave reach, the PERFECT window and double damage, chain sparks, the core and shields, Warden shields and Pierce, splitting, every upgrade family (Echo, Frost, Thorns, Regen, Second Wind, Ricochet, Split, Satellites, Overcharge), offers (no repeats, synergies gated, maxed excluded), XP and level-ups, rerolls, combos and whiffs, bosses (Hydra splits), stars, identical replays, spawns that don't depend on the player, the director, and the Daily Run (pinned, a year valid, every modifier, Sunday harder than Monday, the same result twice). |
| `tests/balance_test.gd` | Bot-verified difficulty on all 48 stages: a precise bot with no Forge upgrades wins every stage; a sloppy bot (late, imprecise, never aims) with the Forge levels a player plausibly has by each world wins every stage; the same sloppy bot without upgrades is untouched in world 1 but is overwhelmed in worlds 7–8; the director's intensity rises every stage and every world; Endless lasts and ramps. |
| `tests/profile_test.tscn` | Coins and video limits, stage rewards (stars merge, paid once, world bonus once), unlocks, the Forge, ring types and perks feeding a run, the Daily streak and once-a-day reward, Endless bests, achievements (once), simulated purchases, trials, the Complete pack, Supporter perks, save/load, corrupt-save recovery, reset keeping purchases. |
| `tests/ui_flow.tscn` | The real app end to end with the mock ad provider: banner space, locked modes, worlds and stages, the stage card, the tutorial, a real run (HUD, upgrade choice, pause, win, double-coins video, share), a loss with a revive, the shop (coin bag, free coins, trial, Supporter removes the banner, restore), the Forge, settings, the Daily Run, Endless, Back, and an app restart. |
| Boot smoke | Runs the game for 300 frames and fails on any error or warning. |

Screenshots of every screen (needs a display; add `clean` to hide the test banner, `store` for the Play Store set):

```sh
godot --path . res://tests/capture.tscn -- /tmp/rb_shots 450 800
godot --path . res://tests/capture.tscn -- "$PWD/store/screenshots" 540 960 store
```

Balance lab (prints every stage as played by the bots):

```sh
godot --headless --path . -s res://tools/balance.gd          # all worlds
godot --headless --path . -s res://tools/balance.gd -- 3     # one world
```

## How it works

| Piece | File |
|---|---|
| Deterministic simulation (fixed 60 Hz, seeded): ring, waves, perfects, shapes, bosses, gems, upgrades, events | `game/core/run_sim.gd` |
| Spawn director: a threat budget on a smoothstep curve with 20 s swells and 16 s surges, from its own seeded RNG | `game/core/director.gd` |
| Worlds, stages, Endless and the date-built Daily Run | `game/core/worlds.gd` |
| Shapes and bosses / upgrades / run stats / ring types and the Forge | `game/core/enemies.gd`, `upgrades.gd`, `run_stats.gd`, `rings.gd` |
| The auto-player (tests, home demo) | `game/core/bot.gd` |
| Cross-platform RNG (xorshift32, integer-only) | `game/core/rng.gd` |
| Arena: fixed-step driving, input, neon drawing (additive glow layer), juice, sound and haptics from sim events | `game/arena/arena_view.gd` |
| App shell, screens, cards, design system and looks | `game/ui/` |
| Save data, profile and rewards, store, audio, haptics, sharing | `game/autoload/` |
| Ads (AdMob provider and a mock) | `game/ads/` |
| Audio synthesiser (all SFX and 10 music loops, no samples) | `tools/synth_audio.py` |
| Icons, splash and store art | `tools/render_icons.gd`, `tools/render_feature_graphic.tscn` |

**Determinism.** The simulation never touches the engine's clock, scene tree or random numbers: it steps at a fixed 1/60 s, and slow motion and hit-stop only change how many steps the arena runs per frame. The director, drops and upgrade offers each have their own seeded `Rng`, so what the player does never changes which shapes come next. That is what makes the Daily Run the same for everyone and lets the tests replay stages with bots.

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
| `game/core/` | Pure logic: simulation, director, worlds, shapes, upgrades, stats, rings and Forge, bot, economy, achievements |
| `game/arena/` | The arena view |
| `game/autoload/` | `save.gd`, `profile.gd`, `store.gd`, `audio.gd`, `haptics.gd`, `share_service.gd` |
| `game/ads/` | `ad_manager.gd` (banner and rewarded policy) and providers: AdMob (Android) and a mock (debug desktop, tests) |
| `game/ui/` | `app.gd` (screens, Back chain, overlays, toasts, splash), `screen.gd`, `overlay.gd`, `ui_kit.gd`, `style.gd`, `look.gd` (themes, ring styles, appearance), `splash.gd`, `tutorial.gd`, `screens/` (home, worlds, stages, play, forge, shop), `overlays/` (stage, upgrade, pause, revive, result, share, new shape, daily, settings, product, picker, coins, tips, how-to, about, credits, awards, messages), `widgets/` |
| `addons/` | Godot AdMob plugin (Poing Studios, MIT), Godot Google Play Billing (MIT), the share plugin's export hook |
| `plugins_src/` | The Android share plugin (Java), built by CI |
| `store/`, `web/`, `docs/` | Play Console docs and art, the website pages, the game design document |
| `tools/`, `tests/` | Synthesiser, renderers, balance lab; the test suites and screenshot capture |

## Decisions made while building it

- **Runs are single stages.** Upgrades last one stage (a ~2-minute run); coins carry over to the Forge. This keeps runs short on a phone and gives the campaign its roguelite shape.
- **Level-ups come from XP gems only** (not also every 15 s): the gem flow already lands a choice roughly every 10–15 s, and one source is easier to read.
- **The banner hides during play** (see Ads) and returns on results and menus.
- **Bosses never take a free hit:** lunges stop short of the core, because the player cannot move; only shapes that get through cost shields.
- **Campaign balance assumes some Forge progress** in the last worlds; the balance test proves the stages are beatable both by precise play without upgrades and by sloppy play with plausible upgrades.
- **The icon, art and music are original**, drawn and synthesised for this game; the coin, star and a few item icons are shared with Word Lantern.

## Credits

| Asset | Source | Licence |
|---|---|---|
| Engine: [Godot Engine](https://godotengine.org) 4.7.2 | Godot contributors | MIT |
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Fallback glyphs (★ ♥ ₹ ৳) | Noto Sans subsets | SIL OFL 1.1, `assets/fonts/OFL-Noto.txt` |
| UI icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Game icons and the app icon | Drawn for Ringburst (coin, star and some item art shared with Word Lantern) | Released with the project |
| Music and sound effects | Generated by `tools/synth_audio.py`, no samples | Released with the project (CC0) |
| QR code on the share card | Generated with [segno](https://github.com/heuer/segno) | Generated output |
| [Godot AdMob Plugin](https://github.com/poingstudios/godot-admob-plugin) | Poing Studios | MIT, `addons/admob/LICENSE` |
| [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | Godot contributors | MIT, `addons/GodotGooglePlayBilling/LICENSE` |

The game-dev agent skills used while building this are in `.claude/skills/`. They come from [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0) and [godot-skills](https://github.com/vl4dt/godot-skills) (MIT).

Game design and development: **Ramlakhan Madheshiya** — https://theramlakhan.com
