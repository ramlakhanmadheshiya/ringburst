# Ringburst: game design

## High concept
Ringburst is a portrait, one-touch arcade roguelite. You are a glowing core at the centre of the screen and simple neon shapes creep in from the edges. Hold anywhere to grow a ring from the core; release to fire it outward as a shockwave that damages everything it passes, out to the radius it had when you let go. A shape that touches the core costs a shield.

## Market references
- **Vampire Survivors, Survivor.io, Brotato:** short runs, enemies from every side, XP gems and pick-1-of-3 upgrades with synergies, meta-progression between runs.
- **Rhythm and timing games (Rhythm Heaven, Super Hexagon, Piano Tiles):** a single precise input, a visible timing window, a combo that turns into a melody.
- **One-touch hypercasual (Stack, Helix Jump):** learnable in seconds, fun in the first ten.

The twist is that a survivor-like is played with **one touch and no movement**: all the decisions live in *when* you let go.

## Player promise
You read the crowd, hold your nerve while it closes in, and let go at the exact moment a shape sits on the ring's edge: the screen flashes, time slows, sparks chain, and the combo climbs a note higher.

## Core loop (seconds)
1. Hold: the ring grows (280 px/s base) from the core to its full size (330 base). Soft ticks rise in pitch as it grows; the full reach is a faint dashed circle.
2. Watch: when a shape sits on the edge, the ring turns white, the shape gets a white halo and a blip plays.
3. Release: the wave flies out at 1,500 px/s and hits every shape whose near side is inside the ring (plus 6 px of slack). Hit shapes are shoved back 14 px.
4. PERFECT if a shape was on the edge: ×2 damage for the whole wave, a chain spark from up to three caught shapes to their nearest neighbours (50% damage), +1 combo, a 0.16 s slow-motion flash.
5. Gems drop and are pulled in by passing waves (or by Magnet); XP fills; a level-up pauses for an upgrade choice.

## Core loop (minutes)
A stage is one run of 70–100 s plus its boss. Coins from every run (win or lose) buy permanent Forge upgrades, ring types and starting perks, which make the next attempt stronger. Stars reward mastery (no hits, combo targets).

## Rules
| Rule | Detail |
|---|---|
| Timestep | Fixed 60 Hz. Slow motion and hit-stop change how many steps run per frame, never the steps. |
| Core | Radius 34. Contact costs a shield, destroys the shape, shoves everything within 170 px away, and gives 1.3 s of safety. |
| Shields | 3 (+2 from the Forge). Losing the last ends the run; one revive per run (video or 150 coins; free for Supporters). |
| Ring | Starts at 42, grows at `grow`, stops at `max_r`; a 0.12 s cooldown after each release. A tap shorter than a frame still fires. |
| PERFECT window | Ring radius between (shape distance − shape radius − band) and (distance + half its radius, capped, + half the band). Base band 9 px; Sharp Eye, Keen Eye and the Lens ring widen it. A perfect wave always reaches the shapes it caught. |
| Combo | +1 per perfect; reset by a hit on the core or by a release that hits nothing (unless Steady Hands). Score multiplier 1 + 0.1 × combo, capped at ×4. |
| Score | Shape value × multiplier; +10 × multiplier per perfect; 1,000 per boss; +250 per shield left at the end of a stage. |
| XP | Level n needs 6 + 5n XP. Gems: Drifter 1, most shapes 2–5, bosses 20. |
| Coins | score ÷ 200 (+20 for a win), times Fortune/Greed; +10 per new star; +150 per world boss (first time); daily reward 40 + 5 per streak day (cap +30). |

### Shapes
| Shape | Sides | HP | Speed | Behaviour |
|---|---|---|---|---|
| Drifter | 3 | 1 | 72 | straight in with a slight weave |
| Dasher | 4 | 1 | 48 | every 2.4 s: stops, flashes 0.6 s, dashes 330 px/s for 0.35 s |
| Warden | 4 | 2 | 46 | shielded: plain waves do nothing until a perfect breaks it (Pierce helps) |
| Splitter | 6 | 2 | 44 | bursts into 3 minis |
| Orbiter | circle | 1.5 | 36 | spirals: its distance changes slowly, easy to catch on the edge |
| Hatcher | 5 | 4 | 50 | parks at 300 px and hatches a mini every 3.4 s |
| Phantom | 7 | 1 | 64 | fades out (untouchable, faster) beyond 260 px |
| Brute | 8 | 3 | 32 | 30% armour against plain waves, 70% knockback resistance |
| Mini | 3 | 0.5 | 92 | from splitters, hatchers and bosses; stays fragile |

HP scales by 1 + 0.42 × difficulty and speed by 1 + 0.09 × difficulty (minis gain only 40% of the HP scaling).

### Bosses
Every stage ends with one. Stages 1–5: a **Guardian**, a giant of the world's shape (HP 12 + 3.5 × difficulty) that holds at 260 px and emits its shape. Stage 6: the **world boss**, each with a pattern built from: holding distance, orbiting, minion waves, telegraphed lunges (always stopping short of the core, since the player can't move), phasing, a returning shield, armour, or splitting in two (Hydra). Bosses resist knockback and are bumped back if they touch the core.

## The spawn director
Spawns come only from the stage spec and the director's own seeded RNG, never from the player, so a stage (or a day's Daily Run) brings the same shapes in the same order to everyone. A threat budget fills at

`rate = (r0 + (r1 − r0) · smoothstep(t / duration)) · (1 + 0.3 · sin(2πt / 20))`, with `r0 = 0.9 + 0.35d`, `r1 = 2 + 0.7d`,

and buys shapes at their threat cost (Drifter 1 … Brute 4) from the world's weighted mix (the new shape weighted ×3). Every 16 s a surge sends a pack from one edge. A world's first stage opens with its new shape alone. When the timer runs out the boss arrives and regular spawns drop to a trickle. Shapes enter just outside the visible 720 × 1120 arena; at most 110 are alive (extra spawns wait, so the order never changes).

Difficulty `d` = world + 0.18 × stage (0 … 7.9). Endless: 0.6 + t/40 with a boss every 2 minutes. Daily: 2.2 + 0.25 × weekday (Monday 0).

## Upgrades (30)
Regular (levels): Echo (2), Split (3), Frost Ring (3), Magnet (3), Thorns (3), Overcharge (3), Shield Regen (3), Chain Lightning (3), Pierce Armour (2), Sharp Eye (3), Afterglow (2), Quick Charge (3), Long Reach (3), Heavy Wave (4), Shove (2), Lifeline (2), Heartbeat (3), Greed (3), Scholar (3), Second Wind (1), Steady Hands (1), Static (2), Ember (3), Ricochet (2), Fast Wave (2), Satellites (3).
Synergies (offered with high weight once both parts are owned): Shatter (Frost + Static: slowed or stunned shapes take +60%), Resonance (Echo + Chain: echoes of a perfect are perfect), Supernova (Overcharge + Long Reach: a full overcharge reaches 35% further), Inferno (Ember + Afterglow: the lingering ring burns hard).

## Meta-progression
- **Forge** (9 upgrades, 41 levels): Extra Shield, Core Power, Quick Hands, Reach, Keen Eye, Pull, Study, Fortune, Reroll.
- **Ring types** (7): Classic; Twin (Echo, −10% damage); Glacier (Frost, −8% growth); Lens (wide perfect window, −8% reach); Nova (+25% growth, −15% reach); Cinder (Ember, less shove); Titan (+35% damage, −20% growth).
- **Starting perks** (10): one owned upgrade at the start of every run.

## Progression and pacing
- 8 worlds × 6 stages; stages open one at a time (across worlds). Endless opens after Neon Shore 3, the Daily after the first clear.
- Each world: a new shape, taught on a card with a live demo; stages climb 0.18 difficulty each; stage 6 is the boss.
- **Verified by bots** (`tests/balance_test.gd`): a precise player wins every stage without Forge upgrades; a sloppy player wins every stage with the Forge levels they'd plausibly own by then; without upgrades, a sloppy player is untouched in world 1 and overwhelmed in worlds 7–8. Intensity rises every stage.

## Onboarding
Neon Shore 1 runs a hands-on tutorial on a tutorial-only simulation: a drifter waits at 230 px while the hand shows how to hold; let go on it; then three shapes at different distances (one burst catches what's inside); then two that don't wait (the core). Then the real stage starts. Each later world opens with its new shape's card.

## Modes
- **Campaign:** stars, unlocks, bosses.
- **Endless:** best score and longest time.
- **Daily Run:** 110 s + a boss, one modifier, the same for everyone, a streak.

## Monetisation (as Single Shot / Word Lantern)
One-time packs (Complete, Supporter, Theme, Ring styles), coin bags, and a tip jar. A bottom banner on menus and results with reserved space (hidden during play), rewarded videos only when asked (revive, double coins, free coins, trials). No interstitials. Supporters: no ads, video rewards free.

## Audio
All generated (`tools/synth_audio.py`): 27 effects and 10 synthwave loops (menu, one per world in its own key, mode and tempo, and a boss loop). Perfects climb a major-pentatonic ladder with the combo.

## Visual style
Flat geometric shapes, neon on deep night blue (per-world palettes), with daytime versions in light mode and 11 themes. An additive glow layer, range rings, trauma shake, hit-stop, shards and rings on bursts, a pulse with every release. Everything is drawn with `_draw` (no textures besides one glow), particles are capped at 360 and shapes at 110 for low-end phones and the web.
