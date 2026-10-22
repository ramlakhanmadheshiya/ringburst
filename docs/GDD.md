# Ringburst: game design

## High concept
Ringburst is a portrait, one-touch arcade game of short levels. You are a glowing core at the centre of the screen and simple neon shapes creep in from the edges. Hold anywhere to grow a ring from the core; release to fire it outward as a shockwave that damages everything it passes, out to the radius it had when you let go. A shape that touches the core costs a shield. Every level has one clear task, shown before it starts.

## Market references
- **Level-based puzzle and arcade games (Candy Crush, Angry Birds, Cut the Rope):** hundreds of short levels, one clear goal each, three stars, a map that opens one level at a time.
- **Rhythm and timing games (Rhythm Heaven, Super Hexagon, Piano Tiles):** a single precise input, a visible timing window, a combo that turns into a melody.
- **One-touch hypercasual (Stack, Helix Jump):** learnable in seconds, fun in the first ten.

The twist is an arena shooter played with **one touch and no movement**: all the decisions live in *when* you let go.

## Player promise
You read the crowd, hold your nerve while it closes in, and let go at the exact moment a shape sits on the ring's edge: the screen flashes, time slows, a spark jumps, and the combo climbs a note higher.

## Core loop (seconds)
1. Hold: the ring grows (280 px/s) from the core to its full size (330). Soft ticks rise in pitch as it grows; the full reach is a faint dashed circle.
2. Watch: when a shape sits on the edge, the ring turns white, the shape gets a white halo and a blip plays.
3. Release: the wave flies out at 1,500 px/s and hits every shape whose near side is inside the ring (plus 6 px of slack). Hit shapes are shoved back 16 px.
4. PERFECT if a shape was on the edge: ×2 damage for the whole wave, a spark from up to three caught shapes to each one's nearest neighbour (50% damage), +1 combo, a 0.16 s slow-motion flash.
5. The task bar at the top fills (shapes, PERFECTs, seconds, combo, or the Giant's or boss's health).

## Core loop (minutes)
A level is one task and takes about 15–45 s. Clear it and the next level opens; the shields left are its stars. Lose all three shields and the level is lost ("Not this time"): try again straight away. Every player plays with the same ring, so a level's difficulty depends only on the level.

## Rules
| Rule | Detail |
|---|---|
| Timestep | Fixed 60 Hz. Slow motion and hit-stop change how many steps run per frame, never the steps. |
| Core | Radius 34. Contact costs a shield, destroys the shape, shoves everything within 170 px away, and gives 1.3 s of safety. |
| Shields | 3. Losing the last loses the level; one revive per level (a video; Supporters revive without one) brings back 2 shields with a blast, but the level then earns 1 star. |
| Ring | Starts at 42, grows at 280 px/s, stops at 330; a 0.12 s cooldown after each release. A tap shorter than a frame still fires. |
| PERFECT window | Ring radius between (shape distance − shape radius − band) and (distance + half its radius, capped, + half the band). Band 10 px. A perfect wave always reaches the shapes it caught. |
| Combo | +1 per perfect; reset by a hit on the core or by a release that hits nothing. Score multiplier 1 + 0.1 × combo, capped at ×4. |
| Score | Shape value × multiplier; +10 × multiplier per perfect; 1,000 per boss; +250 per shield left at the end of a level. |
| Stars | One per shield left when the task is done (1–3); 1 after a revive. A replay keeps the best. |

### Tasks
Each block of ten levels in a world runs: opener (burst shapes; in worlds 2–8 the first level hunts the new shape), then burst shapes, land PERFECTs, survive, hunt, reach a combo, burst shapes, land PERFECTs, survive, and a Giant (levels 10, 20, 30) or the world boss (level 40). Neon Shore has only drifters, so its hunts are plain "burst shapes" tasks.

| Task | Card text | Target (p = level ÷ 39, w = world 0–7) |
|---|---|---|
| Burst | Burst N shapes | 8 + ⌊16p⌋ + 2w |
| PERFECTs | Land N PERFECTs | 3 + ⌊6p⌋ + ⌊w/2⌋ |
| Survive | Survive N seconds | 20 + ⌊25p⌋ + 2w |
| Combo | Reach a combo of N | 3 + ⌊5p⌋ + ⌊w/3⌋ |
| Hunt | Burst N &lt;new shape&gt;s | 4 + ⌊6p⌋ + ⌊w/3⌋ |
| Giant | Beat Giant &lt;shape&gt; | arrives after 10 s |
| Boss | Beat &lt;boss&gt; | arrives after 12 s; opens the next world |

### Shapes
| Shape | Sides | HP | Speed | Behaviour |
|---|---|---|---|---|
| Drifter | 3 | 1 | 72 | straight in with a slight weave |
| Dasher | 4 | 1 | 48 | every 2.4 s: stops, flashes 0.6 s, dashes 330 px/s for 0.35 s |
| Warden | 4 | 2 | 46 | shielded: plain waves do nothing until a perfect breaks it |
| Splitter | 6 | 2 | 44 | bursts into 3 minis |
| Orbiter | circle | 1.5 | 36 | spirals: its distance changes slowly, easy to catch on the edge |
| Hatcher | 5 | 4 | 50 | parks at 300 px and hatches a mini every 3.4 s |
| Phantom | 7 | 1 | 64 | fades out (untouchable, faster) beyond 260 px |
| Brute | 8 | 3 | 32 | 30% armour against plain waves, 70% knockback resistance |
| Mini | 3 | 0.5 | 92 | from splitters, hatchers and bosses; stays fragile |

HP scales by 1 + 0.15 × (difficulty − 1.55) once difficulty passes 1.55 (from Iron Bloom on), so even a drifter then takes two plain hits or one PERFECT. Speed scales by 1.05 + 0.12 × difficulty (capped at 8).

### Giants and bosses
Levels 10, 20 and 30 of a world bring a **Giant**: the world's new shape at 2.1× size (HP 10 + 2.2 × difficulty) that holds at 260 px, emits its shape and keeps its trick (a Giant Dasher lunges, a Giant Warden's shield returns, a Giant Splitter splits, a Giant Phantom phases, a Giant Brute is armoured). Level 40 brings the **world boss**: Monolith, Lancer, Bastion, Hydra, Carousel, Hive Queen, Wraith, Eclipse, each with a pattern built from: holding distance, orbiting, minion waves, telegraphed lunges (always stopping short of the core, since the player can't move), phasing, a returning shield, armour, or splitting in two (Hydra). Bosses resist knockback and are bumped back if they touch the core.

## The spawn director
Spawns come only from the level spec and the director's own seeded RNG, never from the player, so a level brings the same shapes in the same order every time. After a 2 s grace, a threat budget fills at

`rate = (r0 + (r1 − r0) · smoothstep(t / length)) · (1 + 0.25 · sin(2πt / 20))`, with `r0 = 1.4 + 0.35d`, `r1 = 2.8 + 0.8d`,

where `length` is roughly how long the task takes (the survive time; 10 + 1.3n s for burst and hunt tasks; 15 + 4n s for PERFECT and combo tasks; 45 s for Giants and bosses). It buys shapes at their threat cost (Drifter 1 … Brute 4) from the level's weighted mix: every shape met so far, the world's new shape ×3, a hunted shape ×2, and a few minis after Neon Shore 15. Every 16 s a surge sends a pack from one edge. A world's first level opens with its new shape alone. Once the Giant or boss arrives, regular spawns drop to a trickle. Shapes enter just outside the visible 720 × 1120 arena; at most 110 are alive (extra spawns wait, so the order never changes).

Difficulty `d` = 0.8 × world + 1.1 × level ÷ 39 (0 … 6.7), eased by 0.25 on the level after each Giant.

## Progression and pacing
- 8 worlds × 40 levels = 320; levels open one at a time (across worlds). Beating a world's boss opens the next world.
- Each world: a new shape, taught on a card with a live demo before its first level; Giants at 10, 20, 30; the boss at 40.
- **Awards:** 28 badges (20 for milestones such as PERFECTs, combos, stars and flawless levels, plus one per world). They carry no rewards.
- **Verified by bots** (`tests/balance_test.gd`): a precise bot beats every level, nearly always with three stars; a sloppy bot (human pauses, late and imprecise, never aims for perfects) cruises through world 1, wins nearly every level of worlds 1–6 and loses some in the last two; each world sends more threat than the one before, and every task takes well under two minutes.
- **Old saves:** a save from the earlier stage-based version keeps only settings and purchases; level progress starts again.

## Onboarding
Neon Shore 1 runs a hands-on tutorial on a tutorial-only simulation: a drifter waits at 230 px while the hand shows how to hold; let go on it; then three shapes at different distances (one burst catches what's inside); then two that don't wait (the core). Then the real level starts. Each later world opens with its new shape's card, and every level opens with its task card.

## Monetisation (as Single Shot / Word Lantern)
One-time packs (Complete, Supporter, Theme, Ring styles) and a tip jar; no consumable currency. A bottom banner on menus and result cards with reserved space (never during a level), rewarded videos only when asked (a revive, or a one-hour trial of the Theme pack or Ring styles). No interstitials. Supporters: no banner, revive without a video.

## Audio
All generated (`tools/synth_audio.py`): 23 effects and 10 synthwave loops (menu, one per world in its own key, mode and tempo, and a boss loop). Perfects climb a major-pentatonic ladder with the combo.

## Visual style
Flat geometric shapes, neon on deep night blue (per-world palettes), with daytime versions in light mode and 11 themes. An additive glow layer, range rings, trauma shake, hit-stop, shards and rings on bursts, a pulse with every release. Everything is drawn with `_draw` (no textures besides one glow), particles are capped at 360 and shapes at 110 for low-end phones and the web.
