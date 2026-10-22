extends Node
## Renders a sample share picture to /tmp for review:
##   godot --path . res://tools/render_share.tscn -- /tmp/share.png


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/ringburst_share.png"
	var info: Dictionary = {"id": "fracture-24", "won": true, "where": "Fracture · Level 24", "task": "Survive 34 seconds",
		"world": 3, "level": 23, "score": 12840, "combo": 18, "kills": 96, "perfects": 31, "stars": 3, "time": 34.0, "time_text": "0:34"}
	ShareImage.render(self, info, func(img: Image) -> void:
		img.save_png(out)
		print("wrote ", out)
		get_tree().quit()
	)
