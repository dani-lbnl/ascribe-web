## Displays one page of the bundle's story at a time, with Prev/Next navigation and a page
## counter. Story text is markdown, converted to BBCode via `MdToBBCode` before display. Emits
## `page_pinned(specimen_id)` whenever navigating to a page pins a specimen, so `main.gd` can
## stage it.
class_name StoryPanel
extends Control

signal page_pinned(specimen_id: String)

var _pages: Array = []
var _page_index: int = 0
var _base_url: String = ""


func _ready() -> void:
	$VBox/Buttons/Prev.pressed.connect(func(): show_page(_page_index - 1))
	$VBox/Buttons/Next.pressed.connect(func(): show_page(_page_index + 1))


## Loads `pages` (the manifest's `story` array) for display, resolving relative image paths in
## the markdown against `base_url`, and shows the first page.
func set_story(pages: Array, base_url: String) -> void:
	_pages = pages
	_base_url = base_url
	_page_index = 0
	if not _pages.is_empty():
		_render_page(0, false)


## Navigates to `index` (clamped to the valid range). Emits `page_pinned` if the destination page
## pins a specimen.
func show_page(index: int) -> void:
	_render_page(index, true)


func _render_page(index: int, emit_pin: bool) -> void:
	if _pages.is_empty():
		return
	_page_index = clampi(index, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_page_index]

	$VBox/Text.bbcode_text = MdToBBCode.convert(str(page.get("text", "")), _base_url)
	$VBox/Buttons/PageLabel.text = "%d / %d" % [_page_index + 1, _pages.size()]
	$VBox/Buttons/Prev.disabled = _page_index == 0
	$VBox/Buttons/Next.disabled = _page_index == _pages.size() - 1

	var specimen = page.get("specimen", null)
	if emit_pin and specimen != null:
		page_pinned.emit(str(specimen))
