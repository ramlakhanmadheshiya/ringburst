class_name Economy
extends RefCounted
## Every coin amount and reward rule in one place.

const START_COINS: int = 100
## Paid for each star earned on a stage for the first time.
const STAR_REWARD: int = 10
## Beating a world's boss for the first time.
const WORLD_BONUS: int = 150
const DAILY_REWARD: int = 40
const STREAK_BONUS_PER_DAY: int = 5
const STREAK_BONUS_CAP_DAYS: int = 6
## Revive after losing all shields: a video, or this many coins (once a run).
const REVIVE_COINS: int = 150
## "Free coins" videos in the shop.
const VIDEO_COINS: int = 30
const VIDEO_COINS_PER_DAY: int = 5
## Cosmetic pack trial from a video.
const TRIAL_SECONDS: int = 3600


## Coins for finishing a Daily Run on day `streak` of a streak (streak >= 1).
static func daily_reward(streak: int) -> int:
	return DAILY_REWARD + STREAK_BONUS_PER_DAY * clampi(streak - 1, 0, STREAK_BONUS_CAP_DAYS)


static func star_count(mask: int) -> int:
	return (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1)
