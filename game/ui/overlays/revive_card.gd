class_name ReviveCard
extends Overlay
## Shields down: revive once (a short video, or coins), or end the run.
## Supporters revive without a video.

var play: Node
var _status: Label


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Revive"
	body.add_child(UIKit.art_rect("shield", 110))
	body.add_child(UIKit.label("Shields down!", Style.SIZE_H1, Style.INK, 700))
	body.add_child(UIKit.para("Revive once with two shields and a blast that clears the space around your core.", Style.SIZE_SMALL))
	body.add_child(UIKit.label("%s points · %d combo" % [play._thousands(play.sim.score), play.sim.best_combo], Style.SIZE_SMALL, Style.MUTED, 600))
	var supporter: bool = Profile.is_supporter()
	var video: Button = UIKit.button("Revive (Supporter)" if supporter else "Revive · watch a video", "primary", Style.AMBER, 96, 28, "art:watch")
	video.name = "ReviveVideo"
	video.pressed.connect(func() -> void:
		if not AdManager.rewarded_ready():
			_status.text = "No video available right now." if AdManager.provider != null else "Videos are available in the Android app. You can revive with coins."
			return
		AdManager.show_rewarded(func(ok: bool) -> void:
			if not is_inside_tree():
				return
			if ok:
				_revive()
			else:
				_status.text = "The video was closed early, so no revive this time."
		)
	)
	body.add_child(video)
	var coins: Button = UIKit.button("Revive · %d coins" % Economy.REVIVE_COINS, "soft", Style.AMBER, 84, 25, "art:coin")
	coins.name = "ReviveCoins"
	coins.disabled = Profile.coins() < Economy.REVIVE_COINS
	coins.pressed.connect(func() -> void:
		if Profile.spend(Economy.REVIVE_COINS):
			_revive()
	)
	body.add_child(coins)
	var give_up: Button = UIKit.button("End run", "ghost", Style.AMBER, 72, 23)
	give_up.name = "EndRun"
	give_up.pressed.connect(func() -> void:
		close()
		play._finish(false)
	)
	body.add_child(give_up)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)


func _revive() -> void:
	Audio.play("shield", 1.2, -2.0)
	Haptics.success()
	close()
	play.revive()


func on_back() -> void:
	close()
	play._finish(false)
