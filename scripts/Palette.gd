class_name Palette

const BG := Color("#14101F")
const FLOOR := Color("#1B1630")
const MAGENTA := Color("#FF3D81")
const CYAN := Color("#34E5FF")
const SAND := Color("#F2E9DC")
const RIFT := Color("#9B4DFF")

static var _heavy: Font


static func heavy() -> Font:
	if _heavy == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Black", "Segoe UI Black", "Impact", "Arial"])
		f.font_weight = 900
		_heavy = f
	return _heavy
