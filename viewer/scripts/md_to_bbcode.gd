## Converts a small subset of markdown (as used in story pages) to BBCode for display in a
## RichTextLabel. Escapes BBCode-hostile input first so a literal "[" in story text never gets
## misinterpreted as a tag, then applies markdown conversions on top of the escaped text.
class_name MdToBBCode
extends RefCounted

static var _h1_re: RegEx
static var _h2_re: RegEx
static var _bold_re: RegEx
static var _italic_re: RegEx
static var _img_re: RegEx

## Placeholder markers are delimited by U+0001 (a control character that can never appear in
## story prose), so a literal run of text containing the word "IMG" is never mistaken for a
## placeholder, and each image gets its own index so replacing one never touches another.
const _PLACEHOLDER_DELIM := ""

## Public so callers (StoryPanel) can find placeholders in the returned text without duplicating
## the pattern. Capture group 1 is the image's index into the returned `images` array.
const IMG_PLACEHOLDER_PATTERN := "IMG(\\d+)"


static func _ensure_compiled() -> void:
	if _h1_re != null:
		return
	_h1_re = RegEx.new()
	_h1_re.compile("(?m)^# (.+)$")
	_h2_re = RegEx.new()
	_h2_re.compile("(?m)^## (.+)$")
	_bold_re = RegEx.new()
	_bold_re.compile("\\*\\*(.+?)\\*\\*")
	_italic_re = RegEx.new()
	_italic_re.compile("\\*(.+?)\\*")
	_img_re = RegEx.new()
	_img_re.compile("!\\[[^\\]]*\\]\\(([^)]+)\\)")


## Converts `md` to BBCode. Returns a Dictionary:
##   {"text": String, "images": PackedStringArray}
## `text` is the converted BBCode, with each image replaced by a unique indexed placeholder
## (matching `IMG_PLACEHOLDER_PATTERN`) instead of an `[img]` tag -- RichTextLabel's own `[img]`
## handling uses ResourceLoader, which cannot fetch http(s) URLs, so the caller (StoryPanel) is
## expected to fetch each URL in `images` itself and splice in the resulting texture via
## `RichTextLabel.add_image` at the placeholder's position. `images[i]` is `base_url + "/" + path`
## for the i-th placeholder found, in document order.
##
## Image markdown (`![alt](path)`) is itself bracket-syntax, so its targets are pulled out into
## placeholders *before* the literal-"[" escape runs (escaping first would corrupt the very
## brackets the image regex needs to match); the escape step still runs before every other
## markdown conversion, per spec.
static func convert(md: String, base_url: String) -> Dictionary:
	_ensure_compiled()

	var images := PackedStringArray()
	var text := ""
	var last_end := 0
	var idx := 0
	for m in _img_re.search_all(md):
		text += md.substr(last_end, m.get_start() - last_end)
		images.append(_join_url(base_url, m.get_string(1)))
		text += "%sIMG%d%s" % [_PLACEHOLDER_DELIM, idx, _PLACEHOLDER_DELIM]
		idx += 1
		last_end = m.get_end()
	text += md.substr(last_end)

	text = text.replace("[", "[lb]")

	text = _h1_re.sub(text, "[font_size=24]$1[/font_size]", true)
	text = _h2_re.sub(text, "[font_size=20]$1[/font_size]", true)
	text = _bold_re.sub(text, "[b]$1[/b]", true)
	text = _italic_re.sub(text, "[i]$1[/i]", true)

	return {"text": text, "images": images}


static func _join_url(base_url: String, path: String) -> String:
	if base_url.ends_with("/"):
		return base_url + path
	return base_url + "/" + path
