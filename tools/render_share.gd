extends Node
## Renders a sample share picture to /tmp for review:
##   godot --path . res://tools/render_share.tscn -- /tmp/share.png [daily|endless]


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/ringburst_share.png"
	var mode: String = a[1] if a.size() > 1 else "stage"
	var info: Dictionary = {"mode": mode, "id": "fracture-4", "date": "2026-10-19", "won": true, "where": "Fracture · Stage 4",
		"world": 3, "score": 30726, "combo": 93, "kills": 439, "perfects": 93, "stars": 3, "mask": 7, "time": 214.0,
		"time_text": "3:34", "upgrades": {"heavy_wave": 2, "echo": 1, "frost": 1, "static": 1, "shatter": 1, "regen": 1}, "modifier": "precision"}
	ShareImage.render(self, info, func(img: Image) -> void:
		img.save_png(out)
		print("wrote ", out)
		get_tree().quit()
	)
