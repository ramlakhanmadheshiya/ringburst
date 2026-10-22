class_name EnemyTypes
extends RefCounted
## Every shape that creeps in from the edges, and every boss. Pure data: the
## simulation (RunSim) reads these numbers, the arena draws the shapes.
##
## Distances are in arena units (the arena is 720 x 1120, the core sits at the
## centre), speeds in units per second, hp in hits of a plain wave (1.0).

enum { DRIFTER, DASHER, SHIELDED, SPLITTER, ORBITER, SPAWNER, PHASER, HEAVY, MINI }

## sides: 0 = circle, 3 = triangle, 4 = square/diamond...
## cost: threat points the spawn director pays for one.
const TYPES: Array[Dictionary] = [
	{"id": "drifter", "name": "Drifter", "sides": 3, "radius": 21.0, "hp": 1.0, "speed": 72.0, "cost": 1.0, "score": 10,
		"tip": "Drifts straight at your core. One wave pops it."},
	{"id": "dasher", "name": "Dasher", "sides": 4, "radius": 20.0, "hp": 1.0, "speed": 48.0, "cost": 1.6, "score": 15,
		"tip": "Stops, flashes, then dashes. Release as it lands on your ring."},
	{"id": "shielded", "name": "Warden", "sides": 4, "radius": 23.0, "hp": 2.0, "speed": 46.0, "cost": 2.3, "score": 25,
		"tip": "Its shield shrugs off plain waves. Break it with a PERFECT release."},
	{"id": "splitter", "name": "Splitter", "sides": 6, "radius": 26.0, "hp": 2.0, "speed": 44.0, "cost": 2.4, "score": 20,
		"tip": "Bursts into three quick minis. Keep a little reach in reserve."},
	{"id": "orbiter", "name": "Orbiter", "sides": 0, "radius": 19.0, "hp": 1.5, "speed": 36.0, "cost": 1.9, "score": 20,
		"tip": "Spirals around you as it closes in. Its distance barely changes: easy to catch on the edge."},
	{"id": "spawner", "name": "Hatcher", "sides": 5, "radius": 29.0, "hp": 4.0, "speed": 50.0, "cost": 3.2, "score": 40,
		"tip": "Parks at long range and hatches minis. Charge a big ring to reach it."},
	{"id": "phaser", "name": "Phantom", "sides": 7, "radius": 20.0, "hp": 1.0, "speed": 64.0, "cost": 2.0, "score": 25,
		"tip": "Fades in and out. Waves pass through it while it's faded."},
	{"id": "heavy", "name": "Brute", "sides": 8, "radius": 33.0, "hp": 3.0, "speed": 32.0, "cost": 4.0, "score": 60,
		"tip": "Armoured and hard to push back. A PERFECT cuts right through."},
	{"id": "mini", "name": "Mini", "sides": 3, "radius": 13.0, "hp": 0.5, "speed": 92.0, "cost": 0.5, "score": 4,
		"tip": "Small and quick."},
]

## Behaviour numbers.
const DASH_EVERY: float = 2.4
const DASH_WARN: float = 0.6
const DASH_TIME: float = 0.35
const DASH_SPEED: float = 330.0
const ORBIT_SPIN: float = 1.05
const SPAWNER_HOLD: float = 300.0
const SPAWNER_EVERY: float = 3.4
const PHASE_ON: float = 1.3
const PHASE_OFF: float = 0.9
## Phantoms stay solid once this close.
const PHASE_SOLID_R: float = 260.0
const HEAVY_ARMOUR: float = 0.3
const HEAVY_KB_RESIST: float = 0.7
const SPLIT_CHILDREN: int = 3

## World bosses (one per world, its last level). Levels 10, 20 and 30 of a
## world end with a Giant: a big version of the world's new shape.
## hold: distance at which the boss stops and fights; orbit: angular speed while
## holding; lunge: [every, speed] (it lunges in, then backs off); phase: phases
## like a Phantom; shield: a shield (needs a perfect) that returns every N s;
## emit: [type, every, count]; split: hp of each of the two halves (0 = none).
const BOSSES: Array[Dictionary] = [
	{"name": "Monolith", "sides": 3, "radius": 56.0, "hp": 34.0, "speed": 30.0, "hold": 250.0, "orbit": 0.0,
		"emit": [MINI, 3.6, 6], "lunge": [0.0, 0.0], "phase": false, "shield": 0.0, "split": 0.0, "armour": 0.0},
	{"name": "Lancer", "sides": 4, "radius": 48.0, "hp": 40.0, "speed": 36.0, "hold": 290.0, "orbit": 0.35,
		"emit": [DASHER, 5.0, 2], "lunge": [4.5, 360.0], "phase": false, "shield": 0.0, "split": 0.0, "armour": 0.0},
	{"name": "Bastion", "sides": 4, "radius": 54.0, "hp": 44.0, "speed": 28.0, "hold": 270.0, "orbit": 0.0,
		"emit": [SHIELDED, 5.5, 2], "lunge": [0.0, 0.0], "phase": false, "shield": 7.0, "split": 0.0, "armour": 0.0},
	{"name": "Hydra", "sides": 6, "radius": 56.0, "hp": 36.0, "speed": 30.0, "hold": 260.0, "orbit": 0.2,
		"emit": [SPLITTER, 6.0, 1], "lunge": [0.0, 0.0], "phase": false, "shield": 0.0, "split": 16.0, "armour": 0.0},
	{"name": "Carousel", "sides": 0, "radius": 46.0, "hp": 46.0, "speed": 34.0, "hold": 280.0, "orbit": 0.7,
		"emit": [ORBITER, 4.0, 2], "lunge": [0.0, 0.0], "phase": false, "shield": 0.0, "split": 0.0, "armour": 0.0},
	{"name": "Hive Queen", "sides": 5, "radius": 58.0, "hp": 54.0, "speed": 30.0, "hold": 300.0, "orbit": 0.12,
		"emit": [MINI, 2.2, 3], "lunge": [0.0, 0.0], "phase": false, "shield": 0.0, "split": 0.0, "armour": 0.0},
	{"name": "Wraith", "sides": 7, "radius": 50.0, "hp": 48.0, "speed": 40.0, "hold": 270.0, "orbit": 0.45,
		"emit": [PHASER, 4.5, 2], "lunge": [5.5, 320.0], "phase": true, "shield": 0.0, "split": 0.0, "armour": 0.0},
	{"name": "Eclipse", "sides": 8, "radius": 64.0, "hp": 80.0, "speed": 26.0, "hold": 280.0, "orbit": 0.3,
		"emit": [HEAVY, 6.0, 1], "lunge": [6.0, 300.0], "phase": false, "shield": 9.0, "split": 0.0, "armour": 0.25},
]


static func info(type: int) -> Dictionary:
	return TYPES[clampi(type, 0, TYPES.size() - 1)]


## The Giant of levels 10, 20 and 30: the world's new shape, grown up.
static func guardian(world: int, difficulty: float) -> Dictionary:
	var t: Dictionary = info(world)
	var lunge: Array = [3.8, 330.0] if world == DASHER else [0.0, 0.0]
	return {
		"name": "Giant " + str(t["name"]), "sides": int(t["sides"]), "radius": float(t["radius"]) * 2.1,
		"hp": 10.0 + 2.2 * difficulty, "speed": 34.0, "hold": 260.0, "orbit": ORBIT_SPIN * 0.5 if world == ORBITER else 0.0,
		"emit": [world if world != SPAWNER else MINI, 5.0 - minf(2.0, difficulty * 0.25), 2 if world != SPAWNER else 3],
		"lunge": lunge, "phase": world == PHASER, "shield": 6.0 if world == SHIELDED else 0.0,
		"split": 6.0 + difficulty if world == SPLITTER else 0.0, "armour": 0.3 if world == HEAVY else 0.0,
		"guardian": true,
	}


## The world boss, scaled a little with how deep the level is.
static func boss(world: int, difficulty: float) -> Dictionary:
	var b: Dictionary = BOSSES[clampi(world, 0, BOSSES.size() - 1)].duplicate(true)
	b["hp"] = float(b["hp"]) * 0.7 * (1.0 + 0.05 * difficulty)
	b["guardian"] = false
	return b
