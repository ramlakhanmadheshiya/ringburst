class_name DailyCard
extends Overlay
## Today's Daily Run: built from the date, the same for everyone. Shows the
## modifier, the boss, your best today and the streak; Play starts it.


func build() -> void:
	name = "DailyCard"
	var today: String = Profile.today_key()
	var spec: Dictionary = Worlds.daily_spec(today)
	var mod: Dictionary = Worlds.MODIFIERS[str(spec["modifier"])]
	var w: int = int(spec["world"])
	add_title("Daily Run")
	body.add_child(UIKit.caption(today, Style.PINK))
	body.add_child(UIKit.art_rect("calendar", 96))
	body.add_child(UIKit.label(str(mod["name"]), Style.SIZE_H2, Style.INK, 700))
	body.add_child(UIKit.para(str(mod["desc"]) + ".", Style.SIZE_SMALL + 1, Style.INK))
	body.add_child(UIKit.para("%d seconds in %s, then %s. Everyone plays the same run today." % [int(spec["duration"]), Worlds.world(w)["name"], EnemyTypes.BOSSES[w]["name"]], Style.SIZE_SMALL))
	var stats: HBoxContainer = UIKit.hbox(10)
	for s: Array in [["Best today", str(Profile.daily_best(today))], ["Streak", str(Profile.current_streak())], ["Reward", "+%d" % Economy.daily_reward(Profile.current_streak() + 1) if not Profile.daily_done(today) else "paid"]]:
		var col: VBoxContainer = UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(str(s[1]), Style.SIZE_H2 - 4, Style.INK, 800))
		col.add_child(UIKit.label(str(s[0]), Style.SIZE_CAPTION, Style.MUTED))
		stats.add_child(col)
	body.add_child(UIKit.panel(stats, Style.FIELD, 26, Vector2(12, 14)))
	var play: Button = UIKit.button("Replay" if Profile.daily_done(today) else "Play", "primary", Style.PINK, 96, 32, "play")
	play.name = "PlayDaily"
	play.pressed.connect(func() -> void:
		close()
		app.go("play", {"mode": "daily", "date": today})
	)
	body.add_child(play)
	body.add_child(UIKit.para("The reward is paid once a day; replays can still beat your best.", Style.SIZE_CAPTION))
