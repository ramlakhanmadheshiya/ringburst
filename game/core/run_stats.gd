class_name RunStats
extends RefCounted
## Every number that shapes the ring during one run: the base values, then the
## Forge levels and ring type chosen before the run, then the upgrades picked
## during it. RunSim reads only this.

const BASE_DAMAGE: float = 1.0
const BASE_GROW: float = 280.0
const BASE_MAX_R: float = 330.0
const BASE_BAND: float = 9.0
const BASE_WAVE_SPEED: float = 1500.0
const BASE_KNOCKBACK: float = 14.0
const BASE_LIVES: int = 3

var damage: float = BASE_DAMAGE
var grow: float = BASE_GROW
var max_r: float = BASE_MAX_R
var band: float = BASE_BAND
var wave_speed: float = BASE_WAVE_SPEED
var knockback: float = BASE_KNOCKBACK
var max_lives: int = BASE_LIVES
var magnet_r: float = 0.0
var xp_mult: float = 1.0
var coin_mult: float = 1.0
var rerolls: int = 0
## Base chain sparks from a PERFECT (Chain Lightning adds more).
var chain: int = 1
var chain_damage: float = 0.5

## Upgrade levels picked during the run (id -> level).
var levels: Dictionary = {}

# Multipliers kept apart so upgrades and the Forge stack predictably.
var _damage_mult: float = 1.0
var _grow_mult: float = 1.0
var _reach_mult: float = 1.0


## Builds the stats for a run from the Forge levels, ring type and starting perk.
static func make(forge: Dictionary = {}, ring: String = "classic", perk: String = "") -> RunStats:
	var s: RunStats = RunStats.new()
	s.max_lives += int(forge.get("shield", 0))
	s._damage_mult += 0.08 * int(forge.get("power", 0))
	s._grow_mult += 0.05 * int(forge.get("charge", 0))
	s._reach_mult += 0.04 * int(forge.get("reach", 0))
	s.band += 2.0 * int(forge.get("eye", 0))
	var pull: int = int(forge.get("magnet", 0))
	s.magnet_r = 0.0 if pull == 0 else 70.0 + 30.0 * pull
	s.xp_mult += 0.08 * int(forge.get("scholar", 0))
	s.coin_mult += 0.10 * int(forge.get("fortune", 0))
	s.rerolls = int(forge.get("reroll", 0))
	match ring:
		"twin":
			s._damage_mult -= 0.10
		"glacier":
			s._grow_mult -= 0.08
		"lens":
			s.band += 7.0
			s._reach_mult -= 0.08
		"nova":
			s._grow_mult += 0.25
			s._reach_mult -= 0.15
		"cinder":
			s.knockback *= 0.7
		"titan":
			s._damage_mult += 0.35
			s._grow_mult -= 0.20
	s._recalc()
	var start: String = str(RingTypes.RINGS.get(ring, {}).get("start", ""))
	if not start.is_empty():
		s.add(start)
	if not perk.is_empty() and Upgrades.ALL.has(perk) and s.level(perk) < Upgrades.max_level(perk):
		s.add(perk)
	return s


func level(id: String) -> int:
	return int(levels.get(id, 0))


func has(id: String) -> bool:
	return level(id) > 0


## Takes one level of an upgrade.
func add(id: String) -> void:
	levels[id] = level(id) + 1
	_recalc()


func _recalc() -> void:
	damage = BASE_DAMAGE * (_damage_mult + 0.30 * level("heavy_wave"))
	grow = BASE_GROW * (_grow_mult + 0.15 * level("quick_charge"))
	max_r = BASE_MAX_R * (_reach_mult + 0.12 * level("long_reach"))
	wave_speed = BASE_WAVE_SPEED * (1.0 + 0.30 * level("fast_wave"))
	chain = 1 + 2 * level("chain")
	chain_damage = 0.5 + (0.25 if level("chain") >= 3 else 0.0)
	if level("magnet") > 0:
		magnet_r = maxf(magnet_r, 110.0 + 55.0 * level("magnet"))


## Band width added to an enemy's radius when testing for a PERFECT.
func perfect_band() -> float:
	return band + 6.0 * level("wide_band")


func knockback_force() -> float:
	return knockback * (1.0 + 0.8 * level("knockback"))


func xp_multiplier() -> float:
	return xp_mult + 0.2 * level("scholar")


func coin_multiplier() -> float:
	return coin_mult + 0.25 * level("greed")


func frost_time() -> float:
	return 0.0 if level("frost") == 0 else 1.5 + 0.5 * level("frost")


func frost_factor() -> float:
	return 1.0 - (0.4 + 0.1 * level("frost"))


func stun_time() -> float:
	return 0.0 if level("static") == 0 else 0.2 + 0.4 * level("static")


func burn_dps() -> float:
	return 0.0 if level("ember") == 0 else 0.25 + 0.25 * level("ember")


func regen_time() -> float:
	return [0.0, 18.0, 14.0, 10.0][clampi(level("regen"), 0, 3)]


func pulse_every() -> float:
	return [0.0, 6.0, 4.5, 3.0][clampi(level("pulse"), 0, 3)]


func lifeline_every() -> int:
	return [0, 12, 8][clampi(level("lifeline"), 0, 2)]


func overcharge_max() -> float:
	return 0.5 * level("overcharge")


func afterglow_time() -> float:
	return 0.5 * level("afterglow")


func echo_count() -> int:
	return level("echo")


func pierce_factor() -> float:
	return [0.0, 0.5, 1.0][clampi(level("pierce"), 0, 2)]


func thorns_damage() -> float:
	return 0.0 if level("thorns") == 0 else 0.5 + 0.5 * level("thorns")


func thorns_radius() -> float:
	return 70.0 + 12.0 * level("thorns")


func thorns_every() -> float:
	return 0.7 if level("thorns") < 3 else 0.5


func orbit_count() -> int:
	return level("orbit")


func split_reach() -> float:
	return 0.5 + (0.2 if level("split") >= 2 else 0.0)


func split_damage() -> float:
	return 1.0 if level("split") >= 3 else 0.6


func ricochet_damage() -> float:
	return 1.0 if level("ricochet") >= 2 else 0.5
