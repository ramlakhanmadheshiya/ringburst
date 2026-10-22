class_name RunStats
extends RefCounted
## The ring's numbers. Every level is played with the same ring, so how hard
## a level is depends only on the level itself. RunSim reads only this.

const BASE_DAMAGE: float = 1.0
const BASE_GROW: float = 280.0
const BASE_MAX_R: float = 330.0
const BASE_BAND: float = 10.0
const BASE_WAVE_SPEED: float = 1500.0
const BASE_KNOCKBACK: float = 16.0
const BASE_LIVES: int = 3

var damage: float = BASE_DAMAGE
var grow: float = BASE_GROW
var max_r: float = BASE_MAX_R
var band: float = BASE_BAND
var wave_speed: float = BASE_WAVE_SPEED
var knockback: float = BASE_KNOCKBACK
var max_lives: int = BASE_LIVES
## Sparks a PERFECT sends to the nearest shapes, and how hard each one hits.
var chain: int = 1
var chain_damage: float = 0.5


static func make() -> RunStats:
	return RunStats.new()


## Band width added to a shape's radius when testing for a PERFECT.
func perfect_band() -> float:
	return band


func knockback_force() -> float:
	return knockback
