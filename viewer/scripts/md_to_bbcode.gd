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

const _IMG_PLACEHOLDER := "IMG"


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


## Converts `md` to BBCode. `base_url` is joined with image paths as `base_url + "/" + path`.
##
## Image markdown (`![alt](path)`) is itself bracket-syntax, so its targets are pulled out into
## placeholders *before* the literal-"[" escape runs (escaping first would corrupt the very
## brackets the image regex needs to match); the escape step still runs before every other
## markdown conversion, per spec.
static func convert(md: String, base_url: String) -> String:
	_ensure_compiled()

	var image_paths: Array[String] = []
	for m in _img_re.search_all(md):
		image_paths.append(m.get_string(1))
	var text := _img_re.sub(md, _IMG_PLACEHOLDER, true)

	text = text.replace("[", "[lb]")

	text = _h1_re.sub(text, "[font_size=24]$1[/font_size]", true)
	text = _h2_re.sub(text, "[font_size=20]$1[/font_size]", true)
	text = _bold_re.sub(text, "[b]$1[/b]", true)
	text = _italic_re.sub(text, "[i]$1[/i]", true)

	for path in image_paths:
		text = text.replace(_IMG_PLACEHOLDER, "[img]%s/%s[/img]" % [base_url, path])

	return text
