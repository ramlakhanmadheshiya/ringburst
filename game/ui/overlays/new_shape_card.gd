class_name NewShapeCard
extends Overlay
## Shown before the first stage of a world: the world's new shape, a little
## demo of how it moves, and how to beat it. The run waits behind it.

var type: int = 1


func build() -> void:
	name = "NewShape"
	var info: Dictionary = EnemyTypes.info(type)
	var w: Dictionary = Worlds.world(type)
	body.add_child(UIKit.caption("New shape · %s" % w["name"], Color(w["accent"])))
	body.add_child(UIKit.label(str(info["name"]), Style.SIZE_H1, Style.INK, 700))
	var demo: ShapeDemo = ShapeDemo.new("shape", type)
	demo.accent = Look.accent(type)
	demo.colors = w["enemies"]
	demo.custom_minimum_size = Vector2(0, 280)
	body.add_child(demo)
	body.add_child(UIKit.para(str(info["tip"]), Style.SIZE_BODY - 2, Style.INK))
	var go: Button = UIKit.button("Got it", "primary", Look.accent(type), 92, 30)
	go.name = "GotIt"
	go.pressed.connect(close)
	body.add_child(go)
