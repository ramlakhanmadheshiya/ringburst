extends Node
## All ad decisions live here so ads stay polite, like Single Shot:
## - a small banner at the bottom of every screen, with layout space reserved
##   so it never covers a button (it never shows during the action itself);
## - a rewarded video only when the player asks for one (a revive or a pack
##   trial);
## - no interstitials, ever.
## The banner loads a fresh ad when the player moves between screens, at most
## once every BANNER_REFRESH_SECONDS (AdMob asks for at least 30 s between
## refreshes). Supporters see no banners and get video rewards without videos.
## Providers: AdMob on Android (plugin), a visible mock on debug desktop builds,
## and nothing at all elsewhere (web, release desktop).

signal banner_changed(height: float)
signal rewarded_finished(ok: bool)

## Loaded lazily: it references plugin classes that only exist on Android.
const ADMOB_PROVIDER_PATH: String = "res://game/ads/providers/admob_provider.gd"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

const BANNER_REFRESH_SECONDS: float = 30.0

var provider: Node = null
var _last_banner_load_msec: int = -1000000
## Banner height in viewport units (0 when no banner is showing).
var banner_height: float = 0.0
var _banner_on: bool = false
var _suppressed: bool = false


func _ready() -> void:
	if Engine.has_singleton("PoingGodotAdMob"):
		use_provider((load(ADMOB_PROVIDER_PATH) as GDScript).new())
	elif OS.is_debug_build() and not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		use_provider(MockProvider.new())
	Profile.supporter_changed.connect(func(_on: bool) -> void: refresh_banner())


## Swaps the ad provider (tests use the mock in headless runs).
func use_provider(p: Node) -> void:
	if provider != null:
		provider.queue_free()
	_banner_on = false
	provider = p
	if provider != null:
		provider.name = "AdProvider"
		add_child(provider)
		provider.banner_resized.connect(_on_banner_resized)


func ads_enabled() -> bool:
	return provider != null and not Profile.is_supporter()


## Hides the banner while a run is being played (the arena needs the whole
## screen and a stray tap must never land on an ad), and brings it back after.
func suppress_banner(on: bool) -> void:
	_suppressed = on
	refresh_banner()


## Shows the bottom banner unless the player is a Supporter.
func refresh_banner() -> void:
	var want: bool = ads_enabled() and not _suppressed
	if want == _banner_on:
		return
	_banner_on = want
	if provider == null:
		return
	if want:
		_last_banner_load_msec = Time.get_ticks_msec()
		provider.show_banner()
	else:
		provider.hide_banner()
		_on_banner_resized(0.0)


func _on_banner_resized(height_px: float) -> void:
	# Convert device pixels to viewport units so layouts can reserve the space.
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	banner_height = height_px * (vp.y / maxf(1.0, win.y)) if height_px > 0.0 else 0.0
	banner_changed.emit(banner_height)


## Called on every screen change: shows a fresh banner ad if the last one has
## been up long enough.
func screen_changed() -> void:
	if not _banner_on or provider == null or not provider.has_method("reload_banner"):
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_banner_load_msec < int(BANNER_REFRESH_SECONDS * 1000.0):
		return
	_last_banner_load_msec = now
	provider.reload_banner()


## True when a video reward can be had: Supporters always (no video needed).
func rewarded_ready() -> bool:
	if Profile.is_supporter():
		return true
	return provider != null and provider.rewarded_ready()


## Plays a rewarded video; callback(ok) is true if the reward was earned.
## Supporters get the reward at once, without a video.
func show_rewarded(callback: Callable) -> void:
	if Profile.is_supporter():
		callback.call_deferred(true)
		return
	if not rewarded_ready():
		callback.call(false)
		return
	Audio.stop_music_briefly()
	provider.show_rewarded(func(ok: bool) -> void:
		rewarded_finished.emit(ok)
		callback.call(ok)
	)
