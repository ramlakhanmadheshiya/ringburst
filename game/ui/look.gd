class_name Look
extends RefCounted
## The player's chosen look: a colour theme (sky, accent and shape colours for
## the whole app and the arena; Theme pack) and a ring style (how the ring and
## its waves are drawn; Ring styles pack). "worlds" and "classic" are free and
## keep each world's own neon palette. Appearance (Auto / Dark / Light) applies
## to the free palette; light mode turns every world into a daytime version.

const THEMES: Dictionary = {
	"synthwave": {"name": "Synthwave", "top": "#2B0F4A", "bottom": "#0C0418", "accent": "#FF4FD8", "core": "#FFE9FB",
		"enemies": ["#FFD23F", "#3DF5FF", "#FF7A4F", "#9DFF4F"]},
	"midnight": {"name": "Midnight", "top": "#1B1D2B", "bottom": "#0B0C12", "accent": "#7AA2F7", "core": "#E6E9F5",
		"enemies": ["#F7768E", "#E0AF68", "#9ECE6A", "#BB9AF7"]},
	"toxic": {"name": "Toxic", "top": "#0F2410", "bottom": "#040A04", "accent": "#B6FF3D", "core": "#F2FFE6",
		"enemies": ["#FF4FD8", "#3DF5FF", "#FFE14F", "#FF7A3D"]},
	"ocean": {"name": "Ocean", "top": "#0C3550", "bottom": "#040E18", "accent": "#4FC3F7", "core": "#E6F7FF",
		"enemies": ["#FF8A65", "#FFD54F", "#80CBC4", "#CE93D8"]},
	"sunset": {"name": "Sunset", "top": "#5A2347", "bottom": "#1E0E2C", "accent": "#FF8C61", "core": "#FFF0E6",
		"enemies": ["#FFD45C", "#4FE3FF", "#FF5C8A", "#B48CFF"]},
	"sakura": {"name": "Sakura", "top": "#4A2140", "bottom": "#160A14", "accent": "#FF9EC4", "core": "#FFF1F5",
		"enemies": ["#9EF0FF", "#FFE08A", "#C5FF9E", "#D9A6FF"]},
	"ember": {"name": "Ember", "top": "#3A1508", "bottom": "#0E0503", "accent": "#FF7A3D", "core": "#FFE9D6",
		"enemies": ["#FFD23F", "#4FD8FF", "#FF3D5E", "#B6FF4F"]},
	"royal": {"name": "Royal", "top": "#2E1766", "bottom": "#0A051C", "accent": "#FFD45C", "core": "#FFF6DC",
		"enemies": ["#FF5C8A", "#5CE1FF", "#9DFF5C", "#FF9F43"]},
	"mono": {"name": "Mono", "top": "#1A1A1E", "bottom": "#070708", "accent": "#F2F2F2", "core": "#FFFFFF",
		"enemies": ["#FF4F5E", "#BDBDBD", "#8A8A8A", "#E0E0E0"]},
	"paper": {"name": "Paper", "top": "#FBF6EC", "bottom": "#EADBC2", "accent": "#E8503F", "core": "#2D2A4A", "ink": "#2D2A4A", "light": true,
		"enemies": ["#2F80D9", "#D98E04", "#2E9E5B", "#8E44AD"]},
	"daylight": {"name": "Daylight", "top": "#E8F4FF", "bottom": "#B9D9F5", "accent": "#2F6FE0", "core": "#14284A", "ink": "#1E3A55", "light": true,
		"enemies": ["#E0457B", "#E08A00", "#1F9E6E", "#7B4FE0"]},
}

## Ring styles: how the charging ring and the waves look.
## mode: "solid" (one colour), "cycle" (hue drifts over time), "rainbow"
## (hue around the ring), "dual" (two colours alternating), "dash".
const STYLES: Dictionary = {
	"classic": {"name": "Classic", "mode": "solid", "width": 1.0, "glow": 1.0, "colors": []},
	"neon": {"name": "Neon", "mode": "dual", "width": 1.15, "glow": 1.6, "colors": ["#FF2E88", "#00E5FF"]},
	"plasma": {"name": "Plasma", "mode": "cycle", "width": 1.1, "glow": 1.3, "colors": ["#FF4FD8", "#7DA2FF", "#3DF5FF"]},
	"prism": {"name": "Prism", "mode": "rainbow", "width": 1.0, "glow": 1.1, "colors": []},
	"aurora": {"name": "Aurora", "mode": "cycle", "width": 1.2, "glow": 1.4, "colors": ["#5CFFB0", "#3DF5FF", "#B98CFF"]},
	"ember": {"name": "Ember", "mode": "dual", "width": 1.1, "glow": 1.5, "colors": ["#FF7A3D", "#FFD23F"]},
	"ghost": {"name": "Ghost", "mode": "dash", "width": 0.8, "glow": 0.7, "colors": ["#FFFFFF"]},
}


static func theme_id() -> String:
	var id: String = str(Profile.setting("theme", "worlds"))
	return id if THEMES.has(id) and Profile.owns("theme_pack") else "worlds"


static func style_id() -> String:
	var id: String = str(Profile.setting("ring_style", "classic"))
	return id if STYLES.has(id) and (id == "classic" or Profile.owns("style_pack")) else "classic"


## Sets every Style colour from the chosen theme ("Original" keeps the neon
## night palette). Called at start-up, on every screen change (so an ended
## trial reverts) and whenever the player picks a theme.
static func apply() -> void:
	var t: String = theme_id()
	if t == "worlds" and original_is_light():
		# Original colours in daylight: cool pale sky, dark text, deep accents.
		_set_palette(Color("F4F6FF"), Color("D9DEF5"), Color("2563EB"), false, Color("141A3C"))
		return
	if t == "worlds":
		_set_palette(Color("141A3C"), Color("070A1A"), Color("3DF5FF"), true, Color("F2F4FF"))
		Style.CARD = Color("1A2050")
		Style.SURFACE = Color("242B66")
		Style.PANEL = Color("171C47")
		Style.LIP = Color("0A0D26")
		Style.SHADOW_TILE = Color("10143A")
		Style.MUTED = Color("A9B0E0")
		Style.DIM = Color(0.02, 0.02, 0.08, 0.66)
		return
	var th: Dictionary = THEMES[t]
	var light: bool = bool(th.get("light", false))
	_set_palette(Color(th["top"]), Color(th["bottom"]), Color(th["accent"]), not light, Color(th["ink"]) if light else Color("F4F1FF"))


static func _set_palette(top: Color, bottom: Color, accent: Color, dark: bool, ink: Color) -> void:
	Style.DARK = dark
	Style.DEFAULT_SKY_TOP = top
	Style.DEFAULT_SKY_BOTTOM = bottom
	Style.AMBER = accent
	Style.INK = ink
	if dark:
		var mid: Color = top.lerp(bottom, 0.4)
		Style.MUTED = ink.lerp(top, 0.3)
		Style.CARD = mid.lightened(0.07)
		Style.SURFACE = mid.lightened(0.14)
		Style.PANEL = mid.lightened(0.04)
		Style.LIP = bottom.darkened(0.5)
		Style.SHADOW_TILE = bottom.lightened(0.04)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(1, 1, 1, 0.10)
		Style.DIM = Color(bottom.darkened(0.6), 0.66)
	else:
		Style.MUTED = ink.lerp(top, 0.42)
		Style.CARD = top.lerp(Color.WHITE, 0.55)
		Style.SURFACE = Color.WHITE
		Style.PANEL = top.lerp(Color.WHITE, 0.4)
		Style.LIP = bottom.darkened(0.22)
		Style.SHADOW_TILE = bottom.darkened(0.25)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(ink, 0.12)
		Style.DIM = Color(ink, 0.45)


## Settings › Appearance for the Original colours: "auto" follows the phone's
## dark mode, "dark" is the neon night look, "light" the daytime look.
static func appearance() -> String:
	var a: String = str(Profile.setting("appearance", "auto"))
	return a if a in ["auto", "dark", "light"] else "auto"


static func original_is_light() -> bool:
	match appearance():
		"light":
			return true
		"dark":
			return false
	return DisplayServer.is_dark_mode_supported() and not DisplayServer.is_dark_mode()


static func theme_ids() -> Array:
	return ["worlds"] + THEMES.keys()


static func style_ids() -> Array:
	return STYLES.keys()


static func theme_name(id: String) -> String:
	return "Original" if id == "worlds" else str(THEMES.get(id, {}).get("name", id))


static func style_name(id: String) -> String:
	return str(STYLES.get(id, {}).get("name", id))


## Everything the arena needs to draw world `w` in the current look:
## top/bottom sky, accent (ring), core, four shape colours, gem colour, and
## whether it is a light palette.
static func arena(w: int) -> Dictionary:
	var t: String = theme_id()
	if t != "worlds":
		var th: Dictionary = THEMES[t]
		var en: Array = []
		for c: String in th["enemies"]:
			en.append(Color(c))
		var light_t: bool = bool(th.get("light", false))
		return {"top": Color(th["top"]), "bottom": Color(th["bottom"]), "accent": Color(th["accent"]), "core": Color(th["core"]),
			"enemies": en, "gem": Color(th["accent"]).lerp(Color.WHITE, 0.0 if light_t else 0.35), "light": light_t}
	var wd: Dictionary = Worlds.world(w)
	var enemies: Array = []
	for c: String in wd["enemies"]:
		enemies.append(Color(c))
	if original_is_light():
		var acc: Color = Color(wd["accent"])
		var deep: Array = []
		for c: Color in enemies:
			deep.append(c.darkened(0.25))
		return {"top": acc.lerp(Color.WHITE, 0.9), "bottom": acc.lerp(Color.WHITE, 0.74), "accent": acc.darkened(0.42),
			"core": Color("141A3C"), "enemies": deep, "gem": Color(wd["gem"]).darkened(0.45), "light": true}
	return {"top": Color(wd["top"]), "bottom": Color(wd["bottom"]), "accent": Color(wd["accent"]), "core": Color(wd["core"]),
		"enemies": enemies, "gem": Color(wd["gem"]), "light": false}


## Sky colours for a world (or the home colours when w < 0).
static func sky(w: int = -1) -> Array[Color]:
	if w < 0:
		return [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM]
	var a: Dictionary = arena(w)
	return [a["top"], a["bottom"]]


static func accent(w: int = -1) -> Color:
	if w < 0:
		return Style.AMBER
	return arena(w)["accent"]


## The ring colour at angle `ang` (radians) and time `t` for a style, given
## the world's accent as the base colour.
static func ring_color(style: String, base: Color, ang: float, t: float) -> Color:
	var s: Dictionary = STYLES.get(style, STYLES["classic"])
	var cols: Array = s["colors"]
	match str(s["mode"]):
		"dual":
			var k: float = 0.5 + 0.5 * sin(ang * 3.0 + t * 2.0)
			return Color(cols[0]).lerp(Color(cols[1]), k)
		"cycle":
			var u: float = fposmod(t * 0.35 + ang / TAU * 0.5, 1.0) * float(cols.size())
			var i: int = int(u) % cols.size()
			return Color(cols[i]).lerp(Color(cols[(i + 1) % cols.size()]), u - floorf(u))
		"rainbow":
			return Color.from_hsv(fposmod(ang / TAU + t * 0.12, 1.0), 0.7, 1.0)
		"dash":
			return Color(cols[0])
	return base


static func ring_width(style: String) -> float:
	return float(STYLES.get(style, STYLES["classic"])["width"])


static func ring_glow(style: String) -> float:
	return float(STYLES.get(style, STYLES["classic"])["glow"])


static func ring_dashed(style: String) -> bool:
	return str(STYLES.get(style, STYLES["classic"])["mode"]) == "dash"
