extends Node
## Short vibrations on phones, if the player allows them.


func tick() -> void:
	_buzz(10)


func tap() -> void:
	_buzz(18)


func success() -> void:
	_buzz(32)


func heavy() -> void:
	_buzz(70)


func error() -> void:
	_buzz(55)


func _buzz(ms: int) -> void:
	if not bool(Profile.setting("haptics", true)):
		return
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		Input.vibrate_handheld(ms)
