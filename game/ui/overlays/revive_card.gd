class_name ReviveCard
extends Overlay
## Shields down: revive once with a short video (a revived level is worth one
## star), or stop. Supporters revive without a video.

var play: Node
var _status: Label


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Revive"
	body.add_child(UIKit.art_rect("shield", 100))
	body.add_child(UIKit.label("Shields down!", Style.SIZE_H1, Style.INK, 600))
	body.add_child(UIKit.para("Carry on with two shields and a blast that clears the space around your core. A revived level earns one star.", Style.SIZE_SMALL))
	var task: Label = UIKit.label("%s · %d%% done" % [play.task_text(), int(round(play.sim.goal_progress() * 100.0))], Style.SIZE_SMALL, Style.MUTED, 600)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(task)
	body.add_child(UIKit.gap(4))
	var supporter: bool = Profile.is_supporter()
	var video: Button = UIKit.button("Revive (Supporter)" if supporter else "Revive · watch a video", "primary", Style.AMBER, 96, 28, "art:watch")
	video.name = "ReviveVideo"
	video.pressed.connect(func() -> void:
		if not AdManager.rewarded_ready():
			_status.text = "No video available right now." if AdManager.provider != null else "Revives are available in the Android app."
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
	var give_up: Button = UIKit.button("No thanks", "ghost", Style.AMBER, 72, 23)
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
