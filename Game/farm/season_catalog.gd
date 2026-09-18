extends RefCounted
## Persistent, repeatable courtyard moods; no calendar gates or farming modifiers.
const THEMES: Dictionary = {
	"daily": {"name":"九月日常", "icon":"res://art/ui/september.png"},
	"drying": {"name":"秋日晾晒", "icon":"res://art/ui/decorations/drying_rack.png"},
	"after_rain": {"name":"雨后院落", "icon":"res://art/ui/after_rain.png"},
}

static func valid(value: Variant) -> bool:
	return value is String and THEMES.has(value)
